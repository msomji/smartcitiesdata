defmodule Pipeline.Writer.S3Writer.CompactionTest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias Pipeline.Writer.S3Writer
  alias Pipeline.Writer.TableWriter
  alias Pipeline.Writer.S3Writer.Compaction
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper, only: [eventually: 1]

  setup do
    session = PrestigeHelper.create_session()
    [session: session]
  end

  describe "compact/1" do
    test "compacts a table without changing data", %{session: session} do
      sub = [%{name: "three", type: "boolean"}]
      schema = [%{name: "one", type: "list", itemType: "decimal"}, %{name: "two", type: "map", subSchema: sub}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema}})
      table_name = dataset.technical.systemName

      S3Writer.init(table: table_name, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"one" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        S3Writer.write([datum], table: table_name, schema: schema, bucket: "kdp-cloud-storage")
      end)

      Enum.each(1..5, fn n ->
        payload = %{"one" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: table_name, schema: schema)
      end)

      eventually(fn ->
        orc_query = "select count(1) from #{table_name}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{table_name}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[15]]
      end)

      assert :ok == S3Writer.compact(table: dataset.technical.systemName)

      eventually(fn ->
        orc_query = "select count(1) from #{table_name}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[20]]

        json_query = "select count(1) from #{table_name}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)
    end

    test "skips compaction (and tells you that it skipped it) for empty json table", %{session: session} do
      sub = [%{name: "three", type: "boolean"}]
      schema = [%{name: "one", type: "list", itemType: "decimal"}, %{name: "two", type: "map", subSchema: sub}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema}})
      table_name = dataset.technical.systemName

      S3Writer.init(table: table_name, schema: schema)

      Enum.each(1..5, fn n ->
        payload = %{"one" => [n], "two" => %{"three" => false}}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        TableWriter.write([datum], table: table_name, schema: schema)
      end)

      eventually(fn ->
        orc_query = "select count(1) from #{table_name}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{table_name}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)

      assert :skipped == S3Writer.compact(table: dataset.technical.systemName)

      eventually(fn ->
        orc_query = "select count(1) from #{table_name}"

        orc_query_result =
          session
          |> Prestige.query!(orc_query)

        assert orc_query_result.rows == [[5]]

        json_query = "select count(1) from #{table_name}__json"

        json_query_result =
          session
          |> Prestige.query!(json_query)

        assert json_query_result.rows == [[0]]
      end)
    end

    test "skips compaction (and tells you that it skipped it) for missing json table" do
      dataset = TDG.create_dataset(%{})
      table_name = dataset.technical.systemName

      assert :skipped == S3Writer.compact(table: table_name)
    end

    test "fails without altering state if it was going to change data", %{session: session} do
      allow Compaction.measure(any(), any()), return: {6, 10}, meck_options: [:passthrough]

      schema = [%{name: "abc", type: "string"}]
      dataset = TDG.create_dataset(%{technical: %{schema: schema}})
      table_name = dataset.technical.systemName

      S3Writer.init(table: table_name, schema: schema)

      Enum.each(1..15, fn n ->
        payload = %{"abc" => "#{n}"}
        datum = TDG.create_data(%{dataset_id: dataset.id, payload: payload})
        S3Writer.write([datum], table: table_name, schema: schema, bucket: "kdp-cloud-storage")
      end)

      assert {:error, _} = S3Writer.compact(table: table_name)

      eventually(fn ->
        query = "select count(1) from #{table_name}__json"

        result =
          session
          |> Prestige.query!(query)

        assert result.rows == [[15]]
      end)
    end
  end
end
