defmodule Andi.Services.UrlTest do
  @moduledoc """
  Tests urls with a head request, returning the time to execute and status.
  """
  use Tesla

  require Logger

  plug Tesla.Middleware.JSON

  def test(url, options \\ []) do
    query_params = Keyword.get(options, :query_params, [])
    headers = Keyword.get(options, :headers, [])

    case :timer.tc(&head/2, [url, [query: query_params, headers: headers]]) do
      {time, {:ok, %{status: status}}} ->
        timed_status(time, status)

      {time, {:error, :nxdomain}} ->
        timed_status(time, "Domain not found")

      {time, error} ->
        Logger.debug("Could not complete request : #{inspect(error)}")
        timed_status(time, "Could not complete request")
    end
  end

  defp timed_status(time, status) do
    %{time: time / 1000, status: status}
  end
end
