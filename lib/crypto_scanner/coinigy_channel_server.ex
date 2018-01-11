defmodule CryptoScanner.CoinigyChannelServer do
  use GenServer

  require Logger

  # alias CryptoScanner.Exchange
  # alias CryptoScanner.Coin
  # alias CryptoScanner.Coinigy
  # alias CryptoScanner.CoinigyClient

  def start_link(options) do
    [name: name] = options
    GenServer.start_link __MODULE__, name, options
  end

  def init(name) do
    Logger.info("***** Starting Channel Subscription #{name}")

    [ exchange, base, quote ] = String.split(to_string(name), "--")

    state = %{
      "name" => name,
      "exchange" => exchange,
      "label" => base <> "/" <> quote,
      "last_price" => 0,
      "last_trade_time" => 0,
      "prices" => [],
      "bid_price" => 0.0,
      "bid_quantity" => 0.0,
      "ask_price" => 0.0,
      "ask_quantity" => 0.0,
      "last_bid_ask_time" => 0,
      "volume_btc" => 0,
      "volume" => 0
    }

    {:ok, state}
  end

  def get_data(channel) do
    GenServer.call(channel, :get_data)
  end

  def add_transaction(channel, transaction) do
    GenServer.cast(channel, {:add_transaction, transaction})
  end

  def update_orders(channel, orders) do
    GenServer.cast(channel, {:update_orders, orders})
  end

  def handle_call(:get_data, _from, state) do
    {:reply, {:ok, state}, state}
  end

  def handle_cast({:add_transaction, data}, state) do
    coin = state

    raw_price = %{
      "price" => data["price"],
      "quantity" => data["quantity"],
      "time" => data["time"]
    }
    # Logger.info("New Trade to add: #{inspect(raw_price)}")

    new_state =
      if coin["label"] != nil do

        last_30m = System.os_time - (30 * 60 * 1000 * 1_000_000)

        # keeps only 30m of price data
        current_prices = coin["prices"]
          |> Enum.filter(fn i -> i["time"] >= last_30m end)
        # TODO: should I aggregate data as candle

        new_prices = [ raw_price | current_prices ]

        %{ coin |
          "last_price" => raw_price["price"],
          "last_trade_time" => System.os_time,
          "prices" => new_prices
        } |> calc_prices_percentages

      else
        %{ state |
          "exchange" => data["exchange"],
          "label" => data["label"],
          "last_price" => data["price"],
          "last_trade_time" => System.os_time,
          "prices" => [ raw_price ],
          "bid_price" => 0.0,
          "bid_quantity" => 0.0,
          "ask_price" => 0.0,
          "ask_quantity" => 0.0,
          "last_bid_ask_time" => 0,
          "volume_btc" => 0,
          "volume" => 0
        } |> calc_prices_percentages
      end

    {:noreply, new_state}
  end

  def handle_cast({:update_orders, data}, state) do

    new_state =
      if state["label"] != nil do

        %{ state |
          "bid_price" => data["bid_price"],
          "bid_quantity" => data["bid_quantity"],
          "ask_price" => data["ask_price"],
          "ask_quantity" => data["ask_quantity"],
          "last_bid_ask_time" => System.os_time,
        }

      else
        %{ state |
          "exchange" => data["exchange"],
          "label" => data["label"],
          "bid_price" => data["bid_price"],
          "bid_quantity" => data["bid_quantity"],
          "ask_price" => data["ask_price"],
          "ask_quantity" => data["ask_quantity"],
          "last_bid_ask_time" => System.os_time,
          "last_trade_time" => 0,
          "prices" => [],
          "volume_btc" => 0,
          "volume" => 0
        } |> calc_prices_percentages
      end

    {:noreply, new_state}
  end

  def calc_prices_percentages(coin) do
    coin
      |> Map.put("period_3m", calc_price_percentage_time(coin, 3))
      |> Map.put("period_5m", calc_price_percentage_time(coin, 5))
      |> Map.put("period_10m", calc_price_percentage_time(coin, 10))
      |> Map.put("period_15m", calc_price_percentage_time(coin, 15))
      |> Map.put("period_30m", calc_price_percentage_time(coin, 30))
      |> Map.put("period_1h", calc_price_percentage_time(coin, 60))
  end

  defp calc_price_percentage_time(coin, time) do
    time = System.os_time - (time * 60 * 1000 * 1_000_000)

    {min_price, min_time, max_price, max_time, volume} = coin["prices"]
      |> Enum.filter(&(&1["time"] >= time))
      |> Enum.reduce({0.0, 0, 0.0, 0, 0},
        fn (i, {min_price, min_time, max_price, max_time, vol}) ->
          %{"price" => price, "time" => time, "quantity" => qty} = i

          vol = vol + (price * qty)

          cond do
            min_price == 0.0 -> {price, time, price, time, vol}
            price <= min_price -> {price, time, max_price, max_time, vol}
            price >= max_price -> {min_price, min_time, price, time, vol}
            true -> {min_price, min_time, max_price, max_time, vol}
          end
        end
      )

      prices_diff = max_price - min_price

      prices_percentage = if abs(prices_diff) > 0 do
        p = ((min_price / max_price) - 1) * 100

        if max_time > min_time do
          p * -1
        else
          p
        end
      else
        0
      end

      %{
        "min" => min_price,
        "min_time" => min_time,
        "max" => max_price,
        "max_time" => min_time,
        "diff" => prices_diff,
        "percentage" => prices_percentage,
        "volume" => volume
      }
  end
end
