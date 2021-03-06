defmodule AndiWeb.Router do
  use AndiWeb, :router
  require Ueberauth

  @csp "default-src 'self';" <>
         "style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;" <>
         "script-src 'self' 'unsafe-inline' 'unsafe-eval';" <>
         "font-src https://fonts.gstatic.com data: 'self';" <>
         "img-src 'self' data:;"

  pipeline :browser do
    plug Plug.Logger
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  end

  pipeline :auth do
    plug Andi.Auth.Pipeline
  end

  pipeline :curator do
    plug Guardian.Plug.EnsureAuthenticated, claims: %{"https://andi.smartcolumbusos.com/roles" => ["Curator"]}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  end

  scope "/", AndiWeb do
    pipe_through [:browser, :auth]

    get "/", Redirect, to: "/datasets"
    live "/datasets", DatasetLiveView, layout: {AndiWeb.LayoutView, :root}, session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}
    get "/datasets/:id", EditController, :show_dataset
  end

  scope "/", AndiWeb do
    pipe_through [:browser, :auth, :curator]

    live "/organizations", OrganizationLiveView, layout: {AndiWeb.LayoutView, :root}
    get "/organizations/:id", EditController, :show_organization
  end

  scope "/api", AndiWeb.API do
    pipe_through :api

    get "/v1/datasets", DatasetController, :get_all
    get "/v1/dataset/:dataset_id", DatasetController, :get
    put "/v1/dataset", DatasetController, :create
    post "/v1/dataset/disable", DatasetController, :disable
    post "/v1/dataset/delete", DatasetController, :delete
    get "/v1/organizations", OrganizationController, :get_all
    post "/v1/organization/:org_id/users/add", OrganizationController, :add_users_to_organization
    post "/v1/organization", OrganizationController, :create
  end

  scope "/auth", AndiWeb do
    pipe_through :browser

    get "/auth0", AuthController, :request
    get "/auth0/callback", AuthController, :callback
  end

  scope "/", AndiWeb do
    get "/healthcheck", HealthCheckController, :index
  end
end
