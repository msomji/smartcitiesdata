use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :andi, AndiWeb.Endpoint,
  http: [port: 4002],
  server: false,
  live_view: [
    signing_salt: "CHANGEME?"
  ]

# Print only warnings and errors during test
config :logger, level: :warn

config :andi, :brook,
  instance: :andi,
  driver: [
    module: Brook.Driver.Default,
    init_arg: []
  ],
  handlers: [Andi.Event.EventHandler],
  storage: [
    module: Brook.Storage.Ets,
    init_arg: []
  ]

config :andi,
  dead_letter_topic: "dead-letters",
  hsts_enabled: false

config :andi, AndiWeb.Auth.TokenHandler,
  issuer: "https://smartcolumbusos-demo.auth0.com/",
  allowed_algos: ["RS256"],
  verify_issuer: false,
  allowed_drift: 3_000_000_000_000

config :guardian, Guardian.DB, repo: Andi.Repo
