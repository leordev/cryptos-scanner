defmodule CryptoScanner.BinanceTest do
  use ExUnit.Case

  require Logger

  alias CryptoScanner.ExchangeServer
  alias CryptoScanner.Binance

  test "initialize binance server" do
    assert {:ok, :active} = ExchangeServer.get_status(:binance)
  end

  test "exchange time diff must be less than 12h" do

    os_time = Integer.floor_div(System.os_time, 1000000)

    {:ok, exchange_time} = ExchangeServer.get_time(:binance)

    Logger.info("server time")
    Logger.info(os_time)

    Logger.info("exchange time diff")
    Logger.info(exchange_time)

    assert exchange_time <= (1000 * 60 * 60 * 12)
  end

  test "get a coin" do
    symbol = "ETHBTC"

    {:ok, coin_data} = ExchangeServer.get_coin(:binance, symbol)

    assert coin_data["symbol"] == "ETHBTC"
    assert coin_data["count"] > 0
  end

  test "calc coin percentages 3m" do
    minute = 60 * 1000 * 1_000_000

    prices = [
      %{"price" => "7", "time" => System.os_time },
      %{"price" => "11", "time" => System.os_time - ( 2 * minute ) },
      %{"price" => "10", "time" => System.os_time - ( 3 * minute ) },
      %{"price" => "13.5", "time" => System.os_time - ( 4 * minute ) },
      %{"price" => "10.25", "time" => System.os_time - ( 5 * minute ) },
      %{"price" => "19.5", "time" => System.os_time - ( 29 * minute ) },
      %{"price" => "29", "time" => System.os_time - ( 59 * minute ) }
    ]

    coin = %{"symbol" => "LEOBTC", "prices" => prices}
      |> Binance.calc_prices_percentages

    assert (((7 / 11) - 1) * 100) == coin["period_3m"]["percentage"]
    assert (((7 / 13.5) - 1) * 100) == coin["period_5m"]["percentage"]
    assert (((7 / 19.5) - 1) * 100) == coin["period_30m"]["percentage"]
    assert (((7 / 29) - 1) * 100) == coin["period_1h"]["percentage"]
  end
end
