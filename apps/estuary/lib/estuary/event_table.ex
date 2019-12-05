defmodule Estuary.EventTable do
  @moduledoc """
  This module will create event_stream table and insert data in the table
  """

  def create_table do
    "CREATE TABLE IF NOT EXISTS #{table_name()} (author varchar, create_ts bigint, data varchar, type varchar)"
    |> Prestige.execute()
    |> Prestige.prefetch()
  end

  defp table_name do
    Application.get_env(:estuary, :event_stream_table_name)
  end
end