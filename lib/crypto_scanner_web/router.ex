defmodule CryptoScannerWeb.Router do
  use CryptoScannerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CryptoScannerWeb do
    pipe_through :api

    get "/binance", BinanceController, :get
    get "/binance/charts/:symbol", BinanceController, :charts
    get "/binance/hot/:period/:value", BinanceController, :hot
  end
end
