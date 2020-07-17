defmodule DiscoveryStreams.DatasetSupervisor do
  @moduledoc """
  Supervisor for each dataset that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor

  def name(id), do: :"#{id}_supervisor"

  def ensure_started(start_options) do
    dataset = Keyword.fetch!(start_options, :dataset)
    stop_dataset_supervisor(dataset.id)
    start_options |> IO.inspect(label: "dataset_supervisor.ex:12")

    {:ok, _pid} =
      DynamicSupervisor.start_child(DiscoveryStreams.Dynamic.Supervisor, {DiscoveryStreams.DatasetSupervisor, start_options})
  end

  def ensure_stopped(dataset_id), do: stop_dataset_supervisor(dataset_id)

  def child_spec(args) do
    dataset = Keyword.fetch!(args, :dataset)

    super(args)
    |> Map.put(:id, name(dataset.id))
  end

  def start_link(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    Supervisor.start_link(__MODULE__, opts, name: name(dataset.id))
  end

  defp stop_dataset_supervisor(dataset_id) do
    name = name(dataset_id)

    case Process.whereis(name) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(DiscoveryStreams.Dynamic.Supervisor, pid)
    end
  end

  @impl Supervisor
  def init(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    input_topic = Keyword.fetch!(opts, :input_topic) |> IO.inspect(label: "dataset_supervisor.ex:43")
    producer = :"#{dataset.id}_producer"

    children = [
      broadway(dataset, input_topic, producer)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_producer(dataset, topic, producer) do
    Supervisor.child_spec({Elsa.Supervisor, endpoints: endpoints(), connection: producer, producer: [topic: topic]},
      id: :"#{dataset.id}_elsa_producer"
    )
  end

  defp broadway(dataset, input_topic, producer) do
    config = [
      dataset: dataset,
      input: [
        connection: :"#{dataset.id}_elsa_consumer",
        endpoints: endpoints(),
        group_consumer: [
          group: "discovery-streams-#{input_topic}",
          topics: [input_topic],
          config: Application.get_env(:discovery_streams, :topic_subscriber_config)
        ]
      ]
    ]

    {DiscoveryStreams.Broadway, config}
  end

  defp endpoints(), do: Application.get_env(:discovery_streams, :elsa_brokers)
end
