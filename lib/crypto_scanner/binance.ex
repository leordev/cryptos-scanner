defmodule CryptoScanner.Binance do

  @url "https://api.binance.com/api"

  def get_time() do
    url = "#{@url}/v1/time"

    response = HTTPotion.get url

    body = Poison.decode!(response.body)

    os_time = Integer.floor_div(System.os_time, 1000000)
    body["serverTime"] - os_time
  end

  def get_prices() do
    IO.puts(">>>>> Binance getting prices tick")

    url = "#{@url}/v3/ticker/price"

    response = HTTPotion.get url

    Poison.decode!(response.body)
  end

  def get_24h_stats() do
    IO.puts(">>>>> Binance getting 24hs stats")

    url = "#{@url}/v1/ticker/24hr"

    response = HTTPotion.get url

    Poison.decode!(response.body)
  end

  def get_coins(coins, check_stats) do
    IO.puts(">>>>> Binance coins routine")

    new_coins = if check_stats do
      update_coins(coins)
    else
      coins
    end

    prices = get_prices()

    IO.puts(">>>>> Binance Finished with #{Enum.count(prices)} Prices obtained")

    new_coins
     |> Enum.map(fn(coin) ->

        current_prices = coin["prices"] || []

        coin_prices = prices
          |> Enum.filter(&(&1["symbol"] == coin["symbol"]))
          |> Enum.map(&(%{"price" => &1["price"], "time" => System.os_time}))

        Map.put(coin, "prices", (current_prices ++ coin_prices))
    end)
  end

  defp update_coins(coins) do
    stats = get_24h_stats()

    updated_coins = coins
      |> Enum.map(fn c ->
          new_stat = Enum.find(stats, nil, fn s ->
              s["symbol"] == c["symbol"]
          end)

          coin = new_stat || c

          Map.put(coin, "prices", c["prices"])
        end)

    new_coins = stats
      |> Enum.filter(fn c ->
        total = updated_coins
          |> Enum.filter(fn o -> o["symbol"] == c["symbol"] end)
          |> Enum.count
        total < 1
      end)

    IO.puts('>>>>> Binance: #{Enum.count(updated_coins)} coins updated and #{Enum.count(new_coins)} new coins added')

    updated_coins ++ new_coins
  end
end
