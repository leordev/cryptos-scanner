defmodule CryptoScannerWeb.Router do
  use CryptoScannerWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", CryptoScannerWeb do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CryptoScannerWeb do
    pipe_through :api

    get "/coinigy", CoinigyController, :get
    get "/coinigy/exchanges", CoinigyController, :get_exchanges
    get "/coinigy/my-markets", CoinigyController, :get_markets
    # get "/binance", BinanceController, :get
    # get "/binance/charts/:symbol", BinanceController, :charts
    # get "/binance/hot/:period/:value", BinanceController, :hot
  end
end
