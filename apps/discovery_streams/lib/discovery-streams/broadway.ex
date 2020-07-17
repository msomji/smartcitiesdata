defmodule DiscoveryStreams.Broadway do
  @moduledoc """
  Broadway implementation for DiscoveryStreams
  """
  @producer_module Application.get_env(:discovery_streams, :broadway_producer_module, OffBroadway.Kafka.Producer)
  use Broadway

  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_standardization_end: 0]

  alias Broadway.Message
  alias SmartCity.Data
  @app_name "DiscoveryStreams"
  @instance DiscoveryStreams.Application.instance()

  def start_link(opts) do
    Broadway.start_link(__MODULE__, broadway_config(opts))
  end

  defp broadway_config(opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    input = Keyword.fetch!(opts, :input)

    [
      name: :"#{dataset.id}_broadway",
      producers: [
        default: [
          module: {@producer_module, input},
          stages: 1
        ]
      ],
      processors: [
        default: [
          stages: processor_stages()
        ]
      ],
      batchers: [
        default: [
          stages: batch_stages(),
          batch_size: batch_size(),
          batch_timeout: batch_timeout()
        ]
      ],
      context: %{
        dataset: dataset
      }
    ]
  end

  def handle_message(_processor, %Message{data: message_data} = message, %{dataset: dataset}) do
    message_data |> IO.inspect(label: "broadway.ex:59")
    DiscoveryStreams.MessageHandler.handle_messages([message_data])
    message
  end

  def handle_batch(_batch, messages, _batch_info, context) do
    data_messages = messages |> Enum.map(fn message -> message.data end)
    DiscoveryStreams.MessageHandler.handle_messages(data_messages)
    messages
  end

  defp processor_stages(), do: Application.get_env(:discovery_streams, :processor_stages, 1)
  defp batch_stages(), do: Application.get_env(:discovery_streams, :batch_stages, 1)
  defp batch_size(), do: Application.get_env(:discovery_streams, :batch_size, 1_000)
  defp batch_timeout(), do: Application.get_env(:discovery_streams, :batch_timeout, 2_000)
end
