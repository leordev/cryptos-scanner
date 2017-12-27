defmodule CryptoScannerWeb.Router do
  use CryptoScannerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CryptoScannerWeb do
    pipe_through :api

    get "/binance", BinanceController, :get
  end
end
