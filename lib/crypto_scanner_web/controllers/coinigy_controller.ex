defmodule CryptoScannerWeb.CoinigyController do
  use CryptoScannerWeb, :controller
  alias CryptoScanner.CoinigyServer

  def get(conn, _params) do
    CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "PLNX", "USD")
    CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "HITB", "USD")
    CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "HITB", "ETH")
    CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "LIQU", "BTC")
    CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "BINA", "BTC")
    {:ok, coins} = CoinigyServer.get_coins(:coinigy)
    json conn, coins
  end

  def hot(conn, %{"period" => period, "value" => value}) do
    num = String.to_integer(value)
    {:ok, data} = ExchangeServer.get_hot(:binance, period, num)
    json conn, data
  end
end
