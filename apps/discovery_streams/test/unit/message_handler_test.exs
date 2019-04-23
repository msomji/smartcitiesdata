defmodule DiscoveryStreams.MessageHandlerTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  import Checkov
  import ExUnit.CaptureLog

  alias StreamingMetrics.ConsoleMetricCollector, as: MetricCollector
  alias DiscoveryStreams.{CachexSupervisor, MessageHandler, TopicSubscriber}

  @outbound_records "records"

  setup do
    CachexSupervisor.create_cache(:cota__cota_vehicle_positions)
    CachexSupervisor.create_cache(:"shuttle-position")
    Cachex.clear(:cota__cota_vehicle_positions)
    Cachex.clear(:"shuttle-position")
    allow TopicSubscriber.list_subscribed_topics(), return: ["shuttle-position", "cota__cota_vehicle_positions"]
    :ok
  end

  data_test "broadcasts data from a kafka topic (#{topic}) to a websocket channel #{channel}" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, channel)

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: topic)
    ])

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)

    where([
      [:channel, :topic],
      ["vehicle_position", "cota__cota_vehicle_positions"],
      ["streaming:cota-vehicle-positions", "cota__cota_vehicle_positions"],
      ["streaming:shuttle-position", "shuttle-position"]
    ])
  end

  test "unparsable messages are logged to the console without disruption" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:shuttle-position")

    assert capture_log([level: :warn], fn ->
             MessageHandler.handle_messages([
               create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "shuttle-position"),
               # <- Badly formatted JSON
               create_message(~s({"vehicle":{"vehicle":{"id:""11604"}}}), topic: "shuttle-position"),
               create_message(~s({"vehicle":{"vehicle":{"id":"11605"}}}), topic: "shuttle-position")
             ])
           end) =~ ~S(Poison parse error: {:invalid, "\"", 28)

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11605"}}})

    leave(socket)
  end

  test "metrics are sent for a count of the uncached entities" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "vehicle_position")

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota__cota_vehicle_positions"),
      create_message(~s({"vehicle_id": 34095, "description": "Some Description"}), topic: "shuttle-position")
    ])

    assert_called MetricCollector.record_metrics(any(), "cota__cota_vehicle_positions"), once()
    assert_called MetricCollector.record_metrics(any(), "shuttle_position"), once()

    leave(socket)
  end

  test "metrics fail to send" do
    allow MetricCollector.record_metrics(any(), any()),
      return: {:error, {:http_error, "reason"}},
      meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "vehicle_position")

    assert capture_log([level: :warn], fn ->
             MessageHandler.handle_messages([
               create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota__cota_vehicle_positions")
             ])
           end) =~ "Unable to write application metrics: {:http_error, \"reason\"}"

    leave(socket)
  end

  test "caches data from a kafka topic" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "vehicle_position")

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"10000"}}}), key: "11604"),
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), key: "11604"),
      create_message(~s({"vehicle":{"vehicle":{"id":"99999"}}}), key: "11604")
    ])

    Process.sleep(100)

    cache_record_created = fn ->
      Cachex.count(:cota__cota_vehicle_positions) |> IO.inspect(label: "CACHE SIZE FOR COTA")

      Cachex.stream!(:cota__cota_vehicle_positions)
      |> Enum.to_list()
      |> Enum.map(fn {:entry, _key, _create_ts, _ttl, vehicle} -> vehicle end)
      |> Enum.member?(%{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    end

    Patiently.wait_for!(
      cache_record_created,
      dwell: 10,
      max_tries: 200
    )

    leave(socket)
  end

  test "returns :ok after processing" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]
    assert MessageHandler.handle_messages([]) == :ok
  end

  describe("integration") do
    test "Consumer properly invokes the \"count metric\" library function" do
      actual =
        capture_log(fn ->
          MessageHandler.handle_messages([
            create_message(~s({"vehicle":{"vehicle":{"id":"11605"}}})),
            create_message(~s({"vehicle":{"vehicle":{"id":"11608"}}}))
          ])
        end)

      expected_outputs = [
        "metric_name: \"#{@outbound_records}\"",
        "value: 2",
        "unit: \"Count\"",
        ~r/dimensions: \[{\"PodHostname\", \"*\"/
      ]

      Enum.each(expected_outputs, fn x -> assert actual =~ x end)
    end
  end

  defp create_message(data, opts \\ []) do
    %{
      key: Keyword.get(opts, :key, "some key"),
      topic: Keyword.get(opts, :topic, "cota__cota_vehicle_positions"),
      value: data
    }
  end
end
