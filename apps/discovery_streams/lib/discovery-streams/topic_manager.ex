defmodule DiscoveryStreams.TopicManager do
  @moduledoc """
  Create Topics in kafka using the Elsa library.
  """
  use Retry

  @initial_delay Application.get_env(:discovery_streams, :retry_initial_delay, 500)
  @retries Application.get_env(:discovery_streams, :retry_count, 5)

  @spec setup_topics(%SmartCity.Dataset{}) :: %{input_topic: String.t()}
  def setup_topics(dataset) do
    input_topic = input_topic(dataset.id)

    Elsa.create_topic(endpoints(), input_topic)
    wait_for_topic(input_topic)

    %{input_topic: input_topic}
  end

  def delete_topics(dataset_id) do
    input_topic = input_topic(dataset_id)
    Elsa.delete_topic(endpoints(), input_topic)
  end

  def wait_for_topic(topic) do
    retry with: @initial_delay |> exponential_backoff() |> Stream.take(@retries), atoms: [false] do
      Elsa.topic?(endpoints(), topic)
    after
      true ->
        nil
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end

  defp endpoints(), do: Application.get_env(:discovery_streams, :elsa_brokers)
  defp input_topic_prefix(), do: Application.get_env(:discovery_streams, :topic_prefix)
  defp input_topic(dataset_id), do: "#{input_topic_prefix()}#{dataset_id}"
end
