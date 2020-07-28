defmodule ProtocolDestination.MixProject do
  use Mix.Project

  def project do
    [
      app: :protocol_destination,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:definition_dictionary, in_umbrella: true},
      {:credo, "~> 1.0", only: [:dev]}
    ]
  end
end
