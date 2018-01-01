defmodule CryptoScanner.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    # Define workers and child supervisors to be supervised
    children = [
      # Start the endpoint when the application starts
      supervisor(CryptoScannerWeb.Endpoint, []),
      # Start your own worker by calling: CryptoScanner.Worker.start_link(arg1, arg2, arg3)
      # worker(CryptoScanner.Worker, [arg1, arg2, arg3]),
      # worker(CryptoScanner.ExchangeServer, [[name: :binance]])
      worker(CryptoScanner.CoinigyServer, [[name: :coinigy]])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CryptoScanner.Supervisor]
    response = Supervisor.start_link(children, opts)

    response
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CryptoScannerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
