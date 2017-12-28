defmodule CryptoScannerWeb.BinanceController do
  use CryptoScannerWeb, :controller
  alias CryptoScanner.ExchangeServer
  alias CryptoScanner.Binance

  def get(conn, _params) do
    {:ok, coins} = ExchangeServer.get_coins(:binance)
    json conn, coins
  end

  def charts(conn, %{"symbol" => symbol}) do
    data = case Binance.get_klines(symbol) do
      {:ok, data} -> data
      {:error, msg} -> msg
    end

    json conn, data
  end

  def hot(conn, %{"period" => period, "value" => value}) do
    num = String.to_integer(value)
    {:ok, data} = ExchangeServer.get_hot(:binance, period, num)
    json conn, data
  end
end
