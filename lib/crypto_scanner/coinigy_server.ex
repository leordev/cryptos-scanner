defmodule CryptoScanner.CoinigyServer do
  use GenServer

  require Logger

  # alias CryptoScanner.Exchange
  # alias CryptoScanner.Coin
  # alias CryptoScanner.Coinigy
  alias CryptoScanner.CoinigyClient

  def start_link(options) do

    [name: name] = options
    GenServer.start_link __MODULE__, name, options
  end

  def init(name) do
    Logger.info("Starting Coinigy Server #{name}")

    {:ok, ws_client} =
      CoinigyClient.start_link()

    state = %{
      name: name,
      status: :active,
      last_check: System.os_time,
      coins: [],
      prices: [],
      ws_client: ws_client,
      ws_token: nil,
      ws_channels: [],
      ws_subscriptions: [],
      tick: 0
    }

    #schedule_coins()
    Process.send_after(self(), :ws_auth, 1_000)
    Process.send_after(self(), :ws_ticker, 30_000)

    {:ok, state}
  end

  def handle_info(:ws_auth, state) do
    CoinigyClient.auth(state.ws_client, System.get_env("COINIGY_API_KEY"), System.get_env("COINIGY_API_SECRET"))
    {:noreply, state}
  end

  def handle_info(:ws_ticker, state) do
    CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"coins" => state.coins})

    Process.send_after(self(), :ws_ticker, 10_000)
    {:noreply, state}
  end

  def subscribe_to_channels(pid, exch, base) do
    GenServer.call(pid, {:subscribe_to_channels, exch, base})
  end

  def get_coins(pid) do
    GenServer.call(pid, :get_coins)
  end

  # def get_hot(period, percentage) do
  #   GenServer.call(:coinigy, {:get_hot, period, percentage})
  # end

  def pong_ws_client(pid, ping) do
    GenServer.cast(pid, {:pong_ws_client, ping})
  end

  def set_auth_ws_client(pid, token) do
    GenServer.cast(pid, {:set_auth_ws_client, token})
  end

  def set_ws_channels(pid, channels) do
    GenServer.cast(pid, {:set_ws_channels, channels})
  end

  def tick_price(pid, data) do
    GenServer.cast(pid, {:tick_price, data})
  end

  def tick_orders(pid, data) do
    GenServer.cast(pid, {:tick_orders, data})
  end

  def handle_call(:get_coins, _from, state) do
    {:reply, {:ok, state.coins}, state}
  end

  # def handle_call({:get_hot, period, value}, _from, state) do
  #   coins =
  #     state.coins
  #     |> Enum.filter(fn c ->
  #       percent = c["period_" <> period]["percentage"]
  #       (value < 0 && percent <= value) || (value > 0 && percent >= value)
  #     end)
  #     |> Enum.map(fn c ->
  #       period = c["period_" <> period]
  #
  #       [ base, quote ] = String.split(c["label"])
  #
  #       %Coin{
  #         exchange: c["exchange"],
  #         symbol: c["label"],
  #         base: base,
  #         quote: quote,
  #         volume: c["volume_btc"],
  #         bidPrice: c["bid_price"],
  #         askPrice: c["ask_price"],
  #         from: period["max"],
  #         to: period["min"],
  #         percentage: period["percentage"]
  #       }
  #     end)
  #
  #   {:reply, {:ok, coins}, state}
  # end

  def handle_cast({:pong_ws_client, ping}, state) do
    CoinigyClient.pong(state.ws_client, ping)
    {:noreply, state}
  end

  def handle_cast({:set_ws_channels, channels}, state) do
    Logger.info("setting ws channels")
    {:noreply, %{state | ws_channels: channels}}
  end

  def handle_cast({:set_auth_ws_client, token}, state) do
    Logger.info("Saving Coinigy WS Auth Token")
    CoinigyClient.available_channels(state.ws_client, nil)
    {:noreply, %{ state | ws_token: token }}
  end

  def handle_cast({:tick_price, data}, state) do
    coin = state.coins
      |> Enum.find(nil, fn i -> compare_coin(i, data) end)

    raw_price = %{"price" => data["price"], "time" => data["time"]}
    # Logger.info("New Trade to add: #{inspect(raw_price)}")

    new_state =
      if coin != nil do

        new_prices = [ raw_price | coin["prices"] ]

        updated_coin = %{ coin |
          "last_price" => raw_price["price"],
          "last_trade_time" => System.os_time,
          "prices" => new_prices
        } |> calc_prices_percentages

        updated_coins = state.coins
          |> Enum.map(fn i -> if compare_coin(i, data) do
              updated_coin
            else
              i
            end
          end )

        %{ state | coins: updated_coins }

      else
        new_coin = %{
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

        Logger.info("Adding new Coin #{inspect(new_coin)}")

        %{ state | coins: [new_coin | state.coins] }
      end

    # CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"coins" => new_state.coins})

    {:noreply, new_state}
  end

  def handle_cast({:tick_orders, data}, state) do
    coin = state.coins
      |> Enum.find(nil, fn i -> compare_coin(i, data) end)

    # Logger.info("New OrderBook to add: #{inspect(data)}")

    new_state =
      if coin != nil do

        updated_coin = %{ coin |
          "bid_price" => data["bid_price"],
          "bid_quantity" => data["bid_quantity"],
          "ask_price" => data["ask_price"],
          "ask_quantity" => data["ask_quantity"],
          "last_bid_ask_time" => System.os_time,
        }

        updated_coins = state.coins
          |> Enum.map(fn i -> if compare_coin(i, data) do
              updated_coin
            else
              i
            end
          end )

        %{ state | coins: updated_coins }

      else
        new_coin = %{
          "exchange" => data["exchange"],
          "label" => data["label"],
          "bid_price" => data["bid_price"],
          "bid_quantity" => data["bid_quantity"],
          "ask_price" => data["ask_price"],
          "ask_quantity" => data["ask_quantity"],
          "last_bid_ask_time" => System.os_time,
          "last_price" => data["price"],
          "last_trade_time" => 0,
          "prices" => [],
          "volume_btc" => 0,
          "volume" => 0
        } |> calc_prices_percentages

        Logger.info("Adding new Coin #{inspect(new_coin)}")

        %{ state | coins: [new_coin | state.coins] }
      end

    {:noreply, new_state}
  end

  defp compare_coin(a, b) do
    a["exchange"] == b["exchange"] && a["label"] == b["label"]
  end

  # CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, "PLNX", "NXT")
  def handle_call({:subscribe_to_channels, exch, base}, _from, state) do
    channels =
      state.ws_channels
      |> Enum.filter(fn i -> String.contains?(i["channel"], exch) && String.contains?(i["channel"], base) end)

    subscribed_channels = for channel <- channels do
      CoinigyClient.subscribe_channel(state.ws_client, channel)
      channel
    end

    {:reply, :ok, %{state | ws_subscriptions: [ subscribed_channels | state.ws_subscriptions ] } }
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
    time = div(System.os_time - (time * 60 * 1000 * 1_000_000), 1_000_000)

    prices = coin["prices"]
      |> Enum.filter(&(&1["time"] >= time))
      |> Enum.map(&(&1["price"]))

    if Enum.count(prices) > 0 do
      prices_max = prices |> Enum.max
      prices_min = prices |> Enum.min
      prices_diff = (prices_max - prices_min) * -1
      prices_percentage = if abs(prices_diff) > 0 do
        ((prices_min / prices_max) - 1) * 100
      else
        0
      end

      res = %{
        "min" => prices_min,
        "max" => prices_max,
        "diff" => prices_diff,
        "percentage" => prices_percentage
      }

      # Logger.info("Price #{coin["symbol"]} - #{inspect(res)}")

      res
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
