defmodule Pipeline.Writer.TableWriterTest do
  use ExUnit.Case
  use Divo

  alias Pipeline.Writer.TableWriter
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper, only: [eventually: 1]

  describe "init/1" do
    test "creates table with correct name and schema" do
      expected = [
        %{"Column" => "one", "Comment" => "", "Extra" => "", "Type" => "array(varchar)"},
        %{"Column" => "two", "Comment" => "", "Extra" => "", "Type" => "row(three decimal(18,3))"},
        %{"Column" => "four", "Comment" => "", "Extra" => "", "Type" => "array(row(five integer))"}
      ]

      schema = [
        %{name: "one", type: "list", itemType: "string"},
        %{name: "two", type: "map", subSchema: [%{name: "three", type: "decimal(18,3)"}]},
        %{name: "four", type: "list", itemType: "map", subSchema: [%{name: "five", type: "integer"}]}
      ]

      dataset = TDG.create_dataset(%{technical: %{systemName: "org_name__dataset_name", schema: schema}})

      TableWriter.init(name: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table =
          "describe hive.default.org_name__dataset_name"
          |> Prestige.execute(rows_as_maps: true)
          |> Prestige.prefetch()

        assert table == expected
      end)
    end

    test "escapes invalid column names" do
      expected = [%{"Column" => "on", "Comment" => "", "Extra" => "", "Type" => "boolean"}]
      schema = [%{name: "on", type: "boolean"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo", schema: schema}})
      TableWriter.init(name: dataset.technical.systemName, schema: dataset.technical.schema)

      eventually(fn ->
        table =
          "describe hive.default.foo"
          |> Prestige.execute(rows_as_maps: true)
          |> Prestige.prefetch()

        assert table == expected
      end)
    end
  end

  describe "write/2" do
    test "inserts records" do
      schema = [%{name: "one", type: "string"}, %{name: "two", type: "integer"}]
      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__bar", schema: schema}})

      TableWriter.init(name: dataset.technical.systemName, schema: schema)

      datum1 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"one" => "hello", "two" => 42}})
      datum2 = TDG.create_data(%{dataset_id: dataset.id, payload: %{"one" => "goodbye", "two" => 9001}})

      TableWriter.write([datum1, datum2], table: dataset.technical.systemName, schema: schema)

      eventually(fn ->
        result =
          "select * from foo__bar"
          |> Prestige.execute()
          |> Prestige.prefetch()

        assert result == [["hello", 42], ["goodbye", 9001]]
      end)
    end

    test "inserts heavily nested records" do
      schema = [
        %{name: "first_name", type: "string"},
        %{name: "age", type: "long"},
        %{name: "friend_names", type: "list", itemType: "string"},
        %{
          name: "friends",
          type: "list",
          itemType: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "pet", type: "string"}
          ]
        },
        %{
          name: "spouse",
          type: "map",
          subSchema: [
            %{name: "first_name", type: "string"},
            %{name: "gender", type: "string"},
            %{
              name: "next_of_kin",
              type: "map",
              subSchema: [
                %{name: "first_name", type: "string"},
                %{name: "date_of_birth", type: "string"}
              ]
            }
          ]
        }
      ]

      payload = %{
        "first_name" => "Joe",
        "age" => 10,
        "friend_names" => ["bob", "sally"],
        "friends" => [
          %{"first_name" => "Bill", "pet" => "Bunco"},
          %{"first_name" => "Sally", "pet" => "Bosco"}
        ],
        "spouse" => %{
          "first_name" => "Susan",
          "gender" => "female",
          "next_of_kin" => %{
            "first_name" => "Joel",
            "date_of_birth" => "1941-07-12"
          }
        }
      }

      dataset = TDG.create_dataset(%{technical: %{systemName: "foo__baz", schema: schema}})
      TableWriter.init(name: dataset.technical.systemName, schema: schema)

      datum = TDG.create_data(dataset_id: dataset.id, payload: payload)

      expected = [
        "Joe",
        10,
        ["bob", "sally"],
        [["Bill", "Bunco"], ["Sally", "Bosco"]],
        ["Susan", "female", ["Joel", "1941-07-12"]]
      ]

      assert :ok = TableWriter.write([datum], table: dataset.technical.systemName, schema: schema)

      eventually(fn ->
        result =
          "select * from foo__baz"
          |> Prestige.execute()
          |> Prestige.prefetch()

        assert result == [expected]
      end)
    end
  end
end
