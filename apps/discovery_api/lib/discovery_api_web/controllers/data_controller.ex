defmodule DiscoveryApiWeb.DataController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Plugs.{GetModel, Restrictor, RecordMetrics}
  alias DiscoveryApiWeb.DataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApiWeb.Utilities.HmacToken
  require Logger

  plug(GetModel)
  plug(:conditional_accepts, DataView.accepted_formats() when action in [:fetch_file])
  plug(:accepts, DataView.accepted_formats() when action in [:query])
  plug(:accepts, DataView.accepted_preview_formats() when action in [:fetch_preview])
  plug(Restrictor)
  plug(RecordMetrics, query: "queries")

  defp conditional_accepts(conn, formats) do
    if conn.assigns.model.sourceType == "host" do
      DiscoveryApiWeb.Plugs.Acceptor.call(conn, [])
    else
      Phoenix.Controller.accepts(conn, formats)
    end
  end

  def fetch_preview(conn, _params) do
    session = DiscoveryApi.prestige_opts() |> Prestige.new_session()
    dataset_name = conn.assigns.model.systemName
    columns = PrestoService.preview_columns(session, dataset_name)
    schema = conn.assigns.model.schema
    rows = PrestoService.preview(session, dataset_name)

    render(conn, :data, %{
      rows: rows,
      columns: columns,
      dataset_name: dataset_name,
      schema: schema
    })
  rescue
    Prestige.Error -> render(conn, :data, %{rows: [], columns: [], schema: []})
  end

  def download_presigned_url(conn, params) do
    ## Potential issue
    expires_in_seconds = Application.get_env(:discovery_api, :download_link_expire_seconds)
    expires = DateTime.utc_now() |> DateTime.add(expires_in_seconds, :second) |> DateTime.to_unix()
    hmac_token = HmacToken.create_hmac_token(params["dataset_id"], expires)
    scheme = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:scheme]
    host = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:host]
    base_url = scheme <> "://" <> host

    json(
      conn,
      base_url <> "/api/v1/dataset/#{params["dataset_id"]}/download?key=#{hmac_token}&expires=#{expires}"
    )
  end

  def query(conn, params) do
    format = get_format(conn)
    dataset_name = conn.assigns.model.systemName
    dataset_id = conn.assigns.model.id
    current_user = conn.assigns.current_user
    schema = conn.assigns.model.schema
    session = DiscoveryApi.prestige_opts() |> Prestige.new_session()

    with {:ok, columns} <- PrestoService.get_column_names(session, dataset_name, Map.get(params, "columns")),
         {:ok, query} <- PrestoService.build_query(params, dataset_name),
         true <- QueryAccessUtils.authorized_to_query?(query, current_user) do
      data_stream =
        session
        |> Prestige.stream!(query)
        |> Stream.flat_map(&Prestige.Result.as_maps/1)

      rendered_data_stream =
        DataView.render_as_stream(:data, format, %{stream: data_stream, columns: columns, dataset_name: dataset_name, schema: schema})

      resp_as_stream(conn, rendered_data_stream, format, dataset_id)
    else
      {:error, error} ->
        render_error(conn, 404, error)

      _ ->
        render_error(conn, 400, "Bad Request")
    end
  end
end
