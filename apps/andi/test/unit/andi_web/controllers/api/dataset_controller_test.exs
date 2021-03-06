defmodule AndiWeb.API.DatasetControllerTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo

  @route "/api/v1/dataset"
  @get_datasets_route "/api/v1/datasets"
  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.Services.DatasetStore

  import SmartCity.Event, only: [dataset_disable: 0, dataset_delete: 0]

  @instance_name Andi.instance_name()

  setup do
    example_dataset_1 = TDG.create_dataset(%{})

    example_dataset_1 =
      example_dataset_1
      |> struct_to_map_with_string_keys()

    example_dataset_2 = TDG.create_dataset(%{})

    example_dataset_2 =
      example_dataset_2
      |> struct_to_map_with_string_keys()

    example_datasets = [example_dataset_1, example_dataset_2]

    allow(DatasetStore.get_all(),
      return: {:ok, [example_dataset_1, example_dataset_2]},
      meck_options: [:passthrough]
    )

    allow(Brook.Event.send(@instance_name, any(), :andi, any()), return: :ok, meck_options: [:passthrough])

    uuid = Faker.UUID.v4()

    request = %{
      "id" => uuid,
      "technical" => %{
        "dataName" => "dataset",
        "orgId" => "org-123-456",
        "orgName" => "org",
        "stream" => false,
        "sourceUrl" => "https://example.com",
        "sourceType" => "stream",
        "sourceFormat" => "gtfs",
        "cadence" => "9000",
        "schema" => [%{name: "billy", type: "writer"}],
        "private" => false,
        "headers" => %{
          "accepts" => "application/foobar"
        },
        "sourceQueryParams" => %{
          "apiKey" => "foobar"
        },
        "systemName" => "org__dataset",
        "transformations" => [],
        "validations" => []
      },
      "business" => %{
        "benefitRating" => 0.5,
        "dataTitle" => "dataset title",
        "description" => "description",
        "modifiedDate" => "",
        "orgTitle" => "org title",
        "contactName" => "contact name",
        "contactEmail" => "contact@email.com",
        "license" => "https://www.test.net",
        "rights" => "rights information",
        "homepage" => "",
        "keywords" => [],
        "issuedDate" => "2020-01-01T00:00:00Z",
        "publishFrequency" => "all day, ey'r day",
        "riskRating" => 1.0
      },
      "_metadata" => %{
        "intendedUse" => [],
        "expectedBenefit" => []
      }
    }

    message =
      request
      |> SmartCity.Helpers.to_atom_keys()
      |> TDG.create_dataset()
      |> struct_to_map_with_string_keys()

    {:ok, request: request, message: message, example_datasets: example_datasets}
  end

  describe "POST /dataset/disable" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:disable event", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(200)

      assert_called(Brook.Event.send(@instance_name, dataset_disable(), :andi, dataset))
    end

    @tag capture_log: true
    test "does not send dataset:disable event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      allow(DatasetStore.get(any()), return: {:ok, nil})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(404)

      refute_called(Brook.Event.send(@instance_name, dataset_disable(), :andi, dataset))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: {:error, "Mistakes were made"})

      post(conn, "#{@route}/disable", %{id: dataset.id})
      |> json_response(500)
    end
  end

  describe "POST /dataset/delete" do
    setup %{} do
      dataset = TDG.create_dataset(%{})
      [dataset: dataset]
    end

    test "should send dataset:delete event", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(200)

      assert_called(Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset))
    end

    @tag capture_log: true
    test "does not send dataset:delete event if dataset does not exist", %{
      conn: conn,
      dataset: dataset
    } do
      allow(DatasetStore.get(any()), return: {:ok, nil})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: :ok)

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(404)

      refute_called(Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset))
    end

    @tag capture_log: true
    test "handles error", %{conn: conn, dataset: dataset} do
      allow(DatasetStore.get(any()), return: {:ok, dataset})
      allow(Brook.Event.send(@instance_name, any(), any(), any()), return: {:error, "Mistakes were made"})

      post(conn, "#{@route}/delete", %{id: dataset.id})
      |> json_response(500)
    end
  end

  @tag capture_log: true
  test "PUT /api/ without data returns 500", %{conn: conn} do
    conn = put(conn, @route)
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  @tag capture_log: true
  test "PUT /api/ with improperly shaped data returns 500", %{conn: conn} do
    conn = put(conn, @route, %{"id" => 5, "operational" => 2})
    assert json_response(conn, 500) =~ "Unable to process your request"
  end

  describe "GET dataset definitions from /api/dataset/" do
    setup %{conn: conn} do
      [conn: get(conn, @get_datasets_route)]
    end

    @tag capture_log: true
    test "returns a 200", %{conn: conn, example_datasets: example_datasets} do
      actual_datasets =
        conn
        |> json_response(200)

      assert MapSet.new(example_datasets) == MapSet.new(actual_datasets)
    end
  end

  describe "GET /api/dataset/:dataset_id" do
    test "should return a given dataset when it exists", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      allow(DatasetStore.get(dataset.id), return: {:ok, dataset})

      conn = get(conn, "/api/v1/dataset/#{dataset.id}")

      response = conn |> json_response(200)
      assert Map.get(response, "id") == dataset.id
    end

    test "should return a 404 when requested dataset does not exist", %{conn: conn} do
      allow(DatasetStore.get(any()), return: {:ok, nil})

      conn = get(conn, "/api/v1/dataset/123")

      assert 404 == conn.status
    end
  end

  defp struct_to_map_with_string_keys(dataset) do
    dataset
    |> Jason.encode!()
    |> Jason.decode!()
  end
end
