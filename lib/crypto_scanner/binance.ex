defmodule CryptoScanner.Binance do

  require Logger

  @url "https://api.binance.com/api"

  def get_time() do
    url = "#{@url}/v1/time"

    response = HTTPotion.get url

    body = Poison.decode!(response.body)

    os_time = Integer.floor_div(System.os_time, 1000000)
    body["serverTime"] - os_time
  end

  def get_prices() do
    Logger.info(">>>>> Binance getting prices tick")

    url = "#{@url}/v3/ticker/price"

    case HTTPotion.get url do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info(">>>> Binance fail to get prices tick")
        Logger.info(message)
        []
      %{body: body} ->
        Poison.decode!(body)
    end
  end

  def get_klines(symbol) do
    url = "#{@url}/v1/klines?symbol=#{symbol}&interval=1m&limit=120"

    case HTTPotion.get url do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info(">>>> Binance fail to get klines for #{symbol}")
        Logger.info(message)
        {:error, "Fail to get Charts for #{symbol}"}
      %{body: body} ->
        {:ok, Poison.decode!(body)}
    end
  end

  def get_24h_stats() do
    Logger.info(">>>>> Binance getting 24hs stats")

    url = "#{@url}/v1/ticker/24hr"

    case HTTPotion.get url do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info(">>>> Binance fail to get 24hs stats")
        Logger.info(message)
        []
      %{body: body} ->
        Poison.decode!(body)
    end
  end

  def get_coins(coins, check_stats) do
    Logger.info(">>>>> Binance coins routine")

    new_coins = if check_stats do
      update_coins(coins)
    else
      coins
    end

    prices = get_prices()

    Logger.info(">>>>> Binance updating prices and calculating")

    final = new_coins
     |> Enum.map(fn(coin) ->

        current_prices = coin["prices"] || []

        coin_prices = prices
          |> Enum.filter(&(&1["symbol"] == coin["symbol"]))
          |> Enum.map(&(%{"price" => &1["price"], "time" => System.os_time}))

        last_prices = coin_prices ++ current_prices
          |> Enum.take(500)

        new_prices = case Enum.count(last_prices) do
          0 ->
            [%{"price" => "0.000", "time" => System.os_time}]
          _ ->
            last_prices
        end

        last_price = new_prices
          |> hd
          |> Map.get("price")

        updated_coin =  coin
          |> Map.put("prices", new_prices)
          |> Map.put("last_price", last_price)

        calc_prices_percentages(updated_coin)
    end)

    Logger.info(">>>>> Binance Finished with #{Enum.count(prices)} Prices obtained")

    final
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

    Logger.info('>>>>> Binance: #{Enum.count(updated_coins)} coins updated and #{Enum.count(new_coins)} new coins added')

    updated_coins ++ new_coins
  end

  def calc_prices_percentages(coin) do
    coin
      |> Map.put("period_3m", calc_price_percentage_time(coin, 3))
      |> Map.put("period_5m", calc_price_percentage_time(coin, 5))
      |> Map.put("period_30m", calc_price_percentage_time(coin, 30))
      |> Map.put("period_1h", calc_price_percentage_time(coin, 60))
  end

  defp calc_price_percentage_time(coin, time) do
    time = System.os_time - (time * 60 * 1000 * 1_000_000)

    prices = coin["prices"]
      |> Enum.filter(&(&1["time"] >= time))
      |> Enum.map(&(Float.parse(&1["price"]) |> elem(0)))

    if Enum.count(prices) > 0 do
      prices_max = prices |> Enum.max
      prices_min = prices |> Enum.min
      prices_diff = (prices_max - prices_min) * -1
      prices_percentage = if abs(prices_diff) > 0 do
        ((prices_min / prices_max) - 1) * 100
      else
        0
      end

      %{
        "min" => prices_min,
        "max" => prices_max,
        "diff" => prices_diff,
        "percentage" => prices_percentage
      }
    else
      %{
        "min" => 0,
        "max" => 0,
        "diff" => 0,
        "percentage" => 0
      }
    end
  end
end
