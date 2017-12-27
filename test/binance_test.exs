defmodule CryptoScanner.BinanceTest do
  use ExUnit.Case

  alias CryptoScanner.ExchangeServer

  test "initialize binance server" do
    assert {:ok, :active} = ExchangeServer.get_status(:binance)
  end

  test "exchange time diff must be less than 12h" do

    os_time = Integer.floor_div(System.os_time, 1000000)

    {:ok, exchange_time} = ExchangeServer.get_time(:binance)

    IO.puts("server time")
    IO.inspect(os_time)

    IO.puts("exchange time diff")
    IO.inspect(exchange_time)

    assert exchange_time <= (1000 * 60 * 60 * 12)
  end

  test "get a coin" do
    symbol = "ETHBTC"

    {:ok, coin_data} = ExchangeServer.get_coin(:binance, symbol)

    assert coin_data["symbol"] == "ETHBTC"
    assert coin_data["count"] > 0
  end
end
