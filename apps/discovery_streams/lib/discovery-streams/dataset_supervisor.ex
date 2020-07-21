defmodule DiscoveryStreams.DatasetSupervisor do
  @moduledoc """
  Supervisor for each dataset that supervises the elsa producer and broadway pipeline.
  """
  use Supervisor

  def name(id), do: :"discovery_streams_#{id}_supervisor"

  def ensure_started(start_options) do
    dataset = Keyword.fetch!(start_options, :dataset)
    stop_dataset_supervisor(dataset.id) |> IO.inspect(label: "dataset_supervisor.ex:11")

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        DiscoveryStreams.Dynamic.Supervisor,
        {DiscoveryStreams.DatasetSupervisor, start_options}
      )
  end

  def ensure_stopped(dataset_id), do: stop_dataset_supervisor(dataset_id)

  def child_spec(args) do
    dataset = Keyword.fetch!(args, :dataset)

    super(args)
    |> Map.put(:id, name(dataset.id))
  end

  def start_link(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    Supervisor.start_link(__MODULE__, opts, name: name(dataset.id)) |> IO.inspect(label: "dataset_supervisor.ex:29")
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
    input_topic = Keyword.fetch!(opts, :input_topic)

    children = [
      elsa_producer(dataset)
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp elsa_producer(dataset) do
    Supervisor.child_spec({Elsa.Supervisor, worker_config(dataset)},
      id: :"discovery_streams_#{dataset.id}_elsa_producer"
    )
  end

  defp worker_config(dataset) do
    [
      endpoints: endpoints(),
      connection: :"discovery_streams_#{dataset.id}_connection",
      registry: DiscoveryStreams.Registry,
      group_consumer: [
        group: :"#{dataset.id}_elsa_consumer",
        topics: ["transformed-#{dataset.id}"],
        handler: DiscoveryStreams.MessageHandler,
        handler_init_args: [],
        config: Application.get_env(:discovery_streams, :topic_subscriber_config)
      ]
    ]
  end

  # defp broadway(dataset, input_topic, producer) do
  #   config = [
  #     dataset: dataset,
  #     input: [
  #       connection: :"#{dataset.id}_elsa_consumer",
  #       endpoints: endpoints(),
  #       group_consumer: [
  #         group: "discovery-streams-#{input_topic}",
  #         topics: [input_topic],
  #         config: Application.get_env(:discovery_streams, :topic_subscriber_config)
  #       ]
  #     ]
  #   ]

  #   {DiscoveryStreams.Broadway, config}
  # end

  defp endpoints(), do: Application.get_env(:discovery_streams, :elsa_brokers)
end
