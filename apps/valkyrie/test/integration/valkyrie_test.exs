defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo

  alias SmartCity.TestDataGenerator, as: TDG

  @messages [
              %{
                payload: %{name: "Jack Sparrow", alignment: "chaotic", age: "32"},
                operational: %{ship: "Black Pearl", timing: []},
                dataset_id: "pirates",
                _metadata: %{}
              },
              %{
                payload: %{name: "Blackbeard"},
                operational: %{ship: "Queen Anne's Revenge", timing: []},
                dataset_id: "pirates",
                _metadata: %{}
              },
              %{
                payload: %{name: "Will Turner", alignment: "good", age: "25"},
                operational: %{ship: "Black Pearl", timing: []},
                dataset_id: "pirates",
                _metadata: %{}
              },
              %{
                payload: %{name: "Barbosa", alignment: "evil", age: "100"},
                operational: %{ship: "Dead Jerks", timing: []},
                dataset_id: "pirates",
                _metadata: %{}
              }
            ]
            |> Enum.map(&Jason.encode!/1)

  @endpoints Application.get_env(:valkyrie, :brod_brokers)

  setup_all do
    dataset =
      TDG.create_dataset(
        id: "pirates",
        technical: %{
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      )

    SmartCity.Dataset.write(dataset)

    Patiently.wait_for(
      fn -> Valkyrie.TopicManager.is_topic_ready?("raw-pirates") end,
      dwell: 500,
      max_tries: 100
    )

    SmartCity.KafkaHelper.send_to_kafka(@messages, "raw-pirates")
    :ok
  end

  test "valkyrie updates the operational struct" do
    assert any_messages_where("validated", fn message ->
             Enum.any?(message.operational.timing, &(&1.app == "valkyrie"))
           end)
  end

  test "valkyrie does not change the content of the messages processed" do
    assert messages_as_expected(
             "validated",
             ["Jack Sparrow", "Will Turner", "Barbosa"],
             & &1.payload.name
           )
  end

  test "valkyrie sends invalid data messages to the dlq" do
    Patiently.wait_for!(
      fn ->
        data_messages = fetch_and_unwrap("dead-letters")

        Enum.any?(data_messages, fn data_message ->
          assert String.contains?(data_message.reason, "The following fields were invalid: alignment")
          assert String.contains?(data_message.reason, "The following fields were invalid: alignment, age")
          assert data_message.app == "Valkyrie"
          assert String.contains?(inspect(data_message.original_message), "Blackbeard")
        end)
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp any_messages_where(topic, callback) do
    :ok ==
      Patiently.wait_for!(
        fn ->
          topic
          |> fetch_and_unwrap()
          |> Enum.any?(callback)
        end,
        dwell: 1000,
        max_tries: 10
      )
  end

  defp messages_as_expected(topic, expected, callback) do
    Patiently.wait_for!(
      fn ->
        actual =
          topic
          |> fetch_and_unwrap()
          |> Enum.map(callback)

        IO.puts("Waiting for actual #{inspect(actual)} to match expected #{inspect(expected)}")

        actual == expected
      end,
      dwell: 1000,
      max_tries: 10
    )
  end

  defp fetch_and_unwrap(topic) do
    {:ok, {_, messages}} = :brod.fetch(@endpoints, topic, 0, 0)

    messages
    |> Enum.map(fn {:kafka_message, _int, key, body, _, _, _} ->
      {key, body}
    end)
    |> Enum.map(fn {_key, body} -> Jason.decode!(body, keys: :atoms) end)
  end
end
