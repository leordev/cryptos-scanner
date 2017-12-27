defmodule CryptoScannerWeb.BinanceController do
  use CryptoScannerWeb, :controller
  alias CryptoScanner.ExchangeServer

  def get(conn, _params) do
    {:ok, coins} = ExchangeServer.get_coins(:binance)
    json conn, coins
  end
end
