defmodule AndiWeb.Views.Options do
  @moduledoc false

  def ratings() do
    %{
      0.0 => "Low",
      0.5 => "Medium",
      1.0 => "High"
    }
  end

  def language() do
    %{
      "english" => "English",
      "spanish" => "Spanish"
    }
  end

  def level_of_access() do
    %{
      "" => "Please select level of access",
      "true" => "Private",
      "false" => "Public"
    }
  end

  def items() do
    %{
      "" => "",
      "string" => "String",
      "map" => "Map",
      "boolean" => "Boolean",
      "date" => "Date",
      "timestamp" => "Timestamp",
      "integer" => "Integer",
      "float" => "Float",
      "list" => "List",
      "json" => "JSON"
    }
  end

  def pii() do
    %{
      "" => "",
      "none" => "None",
      "direct" => "Direct",
      "indirect" => "Indirect"
    }
  end

  def demographic_traits() do
    %{
      "" => "",
      "none" => "None",
      "gender" => "Gender",
      "race" => "Race",
      "age" => "Age",
      "income" => "Income",
      "other" => "Other"
    }
  end

  def biased() do
    %{
      "" => "",
      "no" => "No",
      "yes" => "Yes"
    }
  end

  def masked() do
    %{
      "" => "",
      "n/a" => "N/A",
      "yes" => "Yes",
      "no" => "No"
    }
  end

  def source_format() do
    [
      {"", ""},
      {"CSV", "text/csv"},
      {"JSON", "application/json"},
      {"XML", "text/xml"},
      {"GeoJSON", "application/geo+json"},
      {"Zip Archive", "application/zip"},
      {"GTFS Protobuf", "application/gtfs+protobuf"}
    ]
  end

  def source_format_extended() do
    source_format() ++
      [
        {"Binary Data", "application/octet-stream"},
        {"KML", "application/vnd.google-earth.kml+xml"},
        {"Other", "other"}
      ]
  end

  def source_type() do
    %{
      "" => "",
      "ingest" => "Ingest",
      "stream" => "Stream",
      "host" => "Host",
      "remote" => "Remote"
    }
  end

  def http_method() do
    %{
      # "" => "",
      "GET" => "GET"
      # "POST" => "POST"
    }
  end

  def extract_step_type() do
    %{
      "HTTP" => "HTTP"
    }
  end

  def organizations(stored_organizations) do
    case stored_organizations do
      {:ok, organizations} ->
        org_options =
          organizations
          |> Enum.sort_by(&Map.get(&1, :orgTitle))
          |> Enum.map(&{&1.orgTitle, &1.id})

        [{"Please select an organization", ""}] ++ org_options

      {:error, _} ->
        []
    end
  end
end
