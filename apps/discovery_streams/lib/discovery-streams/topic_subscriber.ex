defmodule DiscoveryStreams.TopicSubscriber do
  @moduledoc """
  Dynamically subscribes to Kafka topics.
  """
  use GenServer
  require Logger

  alias DiscoveryStreams.CachexSupervisor

  @interval Application.get_env(:discovery_streams, :topic_subscriber_interval, 120_000)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_args) do
    :timer.send_interval(@interval, :subscribe)
    {:ok, [], {:continue, :subscribe}}
  end

  def handle_continue(:subscribe, state) do
    check_for_new_topics_and_subscribe()
    {:noreply, state}
  end

  def handle_info(:subscribe, state) do
    check_for_new_topics_and_subscribe()
    {:noreply, state}
  end

  defp check_for_new_topics_and_subscribe() do
    topics_we_should_be_consuming()
    |> subscribe()
  end

  defp topics_we_should_be_consuming() do
    case Brook.get_all_values(:discovery_streams, :streaming_datasets) do
      {:ok, datasets} ->
        datasets

      {:error, _} ->
        Logger.warn("Unable to get values from Brook")
        []
    end
  end

  defp subscribe([]), do: nil

  # sobelow_skip ["DOS.StringToAtom"]
  defp subscribe(datasets) do
    Logger.info("Subscribing to public datasets: #{inspect(datasets)}")

    datasets
    |> Enum.map(fn dataset ->
      DiscoveryStreams.DatasetProcessor.start(dataset)
      dataset
    end)
    |> Enum.map(fn dataset -> dataset.id end)
    |> Enum.map(&String.to_atom/1)
    |> Enum.each(&CachexSupervisor.create_cache/1)
  end
end
