# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :crypto_scanner, CryptoScanner.CoinigyServer,
  coinigy_api_key: System.get_env("COINIGY_API_KEY"),
  coinigy_api_secret: System.get_env("COINIGY_API_SECRET")

# Configures the endpoint
config :crypto_scanner, CryptoScannerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "at0uLGYIdAPW6O5r9cYXeupGa8pqoofdrV5yGIHNjPHi+/leBYF9dJuHmzJ3gOip",
  render_errors: [view: CryptoScannerWeb.ErrorView, accepts: ~w(json)],
  pubsub: [name: CryptoScanner.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
