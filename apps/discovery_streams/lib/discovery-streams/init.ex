defmodule DiscoveryStreams.Init do
  @moduledoc false
  use DiscoveryStreams.Application.Initializer

  @instance DiscoveryStreams.Application.instance()

  def do_init(_opts) do
    Brook.get_all_values!(@instance, :datasets)
    |> Enum.each(&DiscoveryStreams.DatasetProcessor.start/1)
  end
end
