defmodule CryptoScanner.BinanceClient do
  use WebSockex
  require Logger

  alias CryptoScanner.ExchangeServer

  def start_link(opts \\ []) do
    url = "wss://stream.binance.com:9443/ws/!ticker@arr"
    WebSockex.start_link(url, __MODULE__, opts)
  end

  def handle_connect(_conn, state) do
    Logger.info("Binance Client Connected!")
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    body = Poison.decode!(msg)

    coins = for item <- body do
      %{
        "symbol" => item["s"],
        "time" => item["E"],
        "price" => Float.parse(item["c"]) |> elem(0),
        "bidPrice" => Float.parse(item["b"]) |> elem(0),
        "askPrice" => Float.parse(item["a"]) |> elem(0),
        "baseVolume" => Float.parse(item["v"]) |> elem(0),
        "quoteVolume" => Float.parse(item["q"]) |> elem(0)
      }
    end

    ExchangeServer.coins_tick(:binance, coins)

    {:ok, state}
  end

end
