use Mix.Config

host =
  case System.get_env("HOST_IP") do
    nil -> "127.0.0.1"
    defined -> defined
  end

config :flair,
  window_unit: :millisecond,
  window_length: 1

config :kaffe,
  producer: [
    endpoints: [localhost: 9094],
    topics: ["validated"]
  ]

config :kafka_ex,
  brokers: [
    {"localhost", 9094}
  ]

config :flair,
  divo: [
    zookeeper: %{
      image: "wurstmeister/zookeeper",
      ports: [
        {2181, 2181},
        {9094, 9094}
      ]
    },
    kafka: %{
      image: "wurstmeister/kafka:latest",
      env: [
        kafka_advertised_listeners: "INSIDE://:9092,OUTSIDE://#{host}:9094",
        kafka_listener_security_protocol_map: "INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT",
        kafka_listeners: "INSIDE://:9092,OUTSIDE://:9094",
        kafka_inter_broker_listener_name: "INSIDE",
        kafka_create_topics: "streaming-validated:1:1",
        kafka_zookeeper_connect: "localhost:2181"
      ],
      wait_for: %{log: "Previous Leader Epoch was: -1", dwell: 1000, max_retries: 30},
      net: "flair-zookeeper"
    }
    # minio: %{
    #   image: "minio/minio",
    #   ports: [{9000, 9000}],
    #   volumes: [
    #     {"/tmp/data", "/data"},
    #     {"/tmp/", "/root/.minio"}
    #   ],
    #   env: [
    #     minio_access_key: "admin",
    #     minio_secret_key: "password"
    #   ],
    #   command: "server /data",
    #   wait_for: %{log: "Object API (Amazon S3 compatible):"}
    # }
  ]
