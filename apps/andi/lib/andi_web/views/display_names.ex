defmodule AndiWeb.Views.DisplayNames do
  @moduledoc false

  @display_names %{
    benefitRating: "Benefit",
    cadence: "Cadence",
    contactEmail: "Maintainer Email",
    contactName: "Maintainer Name",
    dataJsonUrl: "Data JSON URL",
    dataName: "Data Name",
    dataTitle: "Dataset Title",
    date: "Date",
    day: "Day",
    description: "Description",
    format: "Format",
    homepage: "Homepage URL",
    hour: "Hour",
    id: "ID",
    issuedDate: "Release Date",
    itemType: "Item Type",
    keywords: "Keywords",
    language: "Language",
    license: "License",
    logoUrl: "Logo URL",
    method: "Method",
    minute: "Minute",
    modifiedDate: "Last Updated",
    month: "Month",
    name: "Name",
    orgId: "Organization",
    orgName: "Organization Name",
    orgTitle: "Organization Title",
    private: "Level of Access",
    publishFrequency: "Update Frequency",
    riskRating: "Risk",
    schema: "Schema",
    second: "Second",
    selector: "Selector",
    sourceFormat: "Source Format",
    sourceHeaders: "Headers",
    sourceQueryParams: "Query Parameters",
    sourceType: "Source Type",
    sourceUrl: "Base URL",
    spatial: "Spatial Boundaries",
    temporal: "Temporal Boundaries",
    time: "Time",
    topLevelSelector: "Top Level Selector",
    type: "Type",
    url: "URL",
    week: "Week",
    year: "Year"
  }

  def get(field_key) do
    Map.get(@display_names, field_key)
  end
end
