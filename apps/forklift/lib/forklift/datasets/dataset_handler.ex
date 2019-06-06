defmodule Forklift.Datasets.DatasetHandler do
  @moduledoc """
  Subscribe to SmartCity Registry and pass new and updated datasets to a persistance/caching mechanism.
  """
  use SmartCity.Registry.MessageHandler
  alias Forklift.Datasets.DatasetRegistryServer
  alias Forklift.TopicManager
  require Logger

  def handle_dataset(%SmartCity.Dataset{technical: %{sourceType: "remote"}}) do
    :ok
  end

  def handle_dataset(%SmartCity.Dataset{} = dataset) do
    DatasetRegistryServer.send_message(dataset)
    TopicManager.create_and_subscribe(topic_name(dataset))
  rescue
    error -> Logger.error("Error creating topic for dataset #{dataset.id}: #{inspect(error)}")
  end

  defp topic_name(dataset) do
    topic_prefix = Application.get_env(:forklift, :data_topic_prefix)
    "#{topic_prefix}-#{dataset.id}"
  end
end
