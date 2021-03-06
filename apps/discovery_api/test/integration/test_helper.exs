alias DiscoveryApi.Test.Helper

Auth.Application.disable()
Divo.Suite.start()
# good old umbrella and high level configs
Application.put_env(:guardian, Guardian.DB, repo: DiscoveryApi.Repo)
Helper.wait_for_brook_to_be_ready()
Faker.start()
ExUnit.start()

defmodule URLResolver do
  def resolve_url(url) do
    "./test/integration/schemas/#{url}"
    |> String.split("#")
    |> List.last()
    |> File.read!()
    |> Jason.decode!()
    |> remove_urls()
  end

  def remove_urls(map) do
    Map.put(map, "id", "./test/integration/schemas/")
  end
end
