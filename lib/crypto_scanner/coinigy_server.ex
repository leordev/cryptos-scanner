defmodule CryptoScanner.CoinigyServer do
  use GenServer

  require Logger

  # alias CryptoScanner.Exchange
  # alias CryptoScanner.Coin
  # alias CryptoScanner.Coinigy
  alias CryptoScanner.CoinigyClient
  alias CryptoScanner.CryptoCompare
  alias CryptoScanner.CoinigyChannelServer

  def start_link(options) do

    [name: name] = options
    GenServer.start_link __MODULE__, name, options
  end

  def init(name) do
    Logger.info("Starting Coinigy Server #{name}")

    state = %{
      name: name,
      status: :active,
      last_check: System.os_time,
      coins_channels: [],
      coins: [],
      prices: [],
      ws_client: nil,
      ws_token: nil,
      ws_channels: [],
      ws_subscriptions: [],
      btc_price: 15000.0,
      eth_price: 1000.0,
      tick: 0
    }

    Process.send_after(self(), :update_base_prices, 500)
    Process.send_after(self(), :ws_connect, 500)
    Process.send_after(self(), :ws_ticker, 30_000)

    {:ok, state}
  end

  def handle_info(:ws_connect, state) do
    {:ok, ws_client} = CoinigyClient.start_link()
    {:noreply, %{ state | ws_client: ws_client }}
  end

  def handle_info(:update_base_prices, state) do
    {btc, eth} = case CryptoCompare.get_prices() do
      {:ok, b, e} ->
        Logger.info(">>>>> Updated BTC Price: #{b}")
        Logger.info(">>>>> Updated ETH Price: #{e}")
        {b, e}
      {:error, _any} ->
        Logger.info(">>>>> Fail to read BTC/ETH price, do not change")
        {state.btc_price, state.eth_price}
    end

    # update prices every 5 minutes
    Process.send_after(self(), :update_base_prices, 1000 * 60 * 5)

    {:noreply, %{ state | btc_price: btc, eth_price: eth } }
  end

  def handle_info(:ws_ticker, state) do
    coins = for channel <- state.coins_channels do
      {:ok, coin} = CoinigyChannelServer.get_data(String.to_atom(channel))
      coin
    end

    CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"coins" => coins, "btc_price" => state.btc_price, "eth_price" => state.eth_price})

    Process.send_after(self(), :ws_ticker, 6_000)
    {:noreply, state}
  end

  def subscribe_to_channels(exch, base) do
    GenServer.call(:coinigy, {:subscribe_to_channels, exch, base})
  end

  def ws_connect() do
    GenServer.call(:coinigy, :ws_connect)
  end

  def get_coins() do
    GenServer.call(:coinigy, :get_coins, 15_000)
  end

  def get_coin(exch, market) do
    GenServer.call(:coinigy, {:get_coin, exch, market}, 15_000)
  end

  def get_subscriptions() do
    GenServer.call(:coinigy, :get_ws_subscriptions)
  end

  def get_available_channels() do
    GenServer.call(:coinigy, :get_available_channels)
  end

  def set_auth_ws_client(pid, token) do
    GenServer.cast(pid, {:set_auth_ws_client, token})
  end

  def set_ws_channels(channels) do
    GenServer.call(:coinigy, {:set_ws_channels, channels})
    setup_default_subs()
  end

  def setup_default_subs() do
    # TODO: create an option in UI to set this up
    spawn fn ->
      # GenServer.call(:coinigy, {:subscribe_to_channels, "PLNX", "USD"})
      GenServer.call(:coinigy, {:subscribe_to_channels, "HITB", "USD"})
      GenServer.call(:coinigy, {:subscribe_to_channels, "HITB", "ETH"})
      GenServer.call(:coinigy, {:subscribe_to_channels, "BINA", "ETH"})
      GenServer.call(:coinigy, {:subscribe_to_channels, "BINA", "BTC"})
      #GenServer.call(:coinigy, {:subscribe_to_channels, "BITF", "BTC"})
      #GenServer.call(:coinigy, {:subscribe_to_channels, "BITF", "ETH"})
      #GenServer.call(:coinigy, {:subscribe_to_channels, "BITF", "USD"})
    end
  end

  def tick_price(data) do
    GenServer.cast(:coinigy, {:tick_price, data})
  end

  def tick_orders(data) do
    GenServer.cast(:coinigy, {:tick_orders, data})
  end

  def handle_call(:ws_connect, _from, state) do
    {:ok, ws_client} = CoinigyClient.start_link()
    {:reply, :ok, %{state | ws_client: ws_client}}
  end

  def handle_call(:get_coins, _from, state) do
    {:reply, {:ok, state.coins_channels}, state}
  end

  def handle_call({:get_coin, exch, market}, _from, state) do
    channel = state.coins_channels
      |> Enum.find(nil, fn c ->
        [c_exch, c_base, c_quote] = String.split(c, "--")

        c_exch == exch && (c_base <> "/" <> c_quote) == market
      end)

    {:ok, coin} = CoinigyChannelServer.get_data(String.to_atom(channel))

    {:reply, {:ok, coin}, state}
  end

  def handle_call(:get_ws_subscriptions, _from, state) do
    {:reply, {:ok, state.ws_subscriptions}, state}
  end

  def handle_call(:get_available_channels, _from, state) do
    {:reply, {:ok, state.ws_channels}, state}
  end

  def handle_call({:set_ws_channels, channels}, _from, state) do
    Logger.info("setting ws channels")
    {:reply, {:ok, channels}, %{state | ws_channels: channels}}
  end

  def handle_call({:subscribe_to_channels, exch, base}, _from, state) do
    channels = channels_for_exchange_base(state.ws_channels, exch, base)

    subscribed_channels = for channel <- channels do
      CoinigyClient.subscribe_channel(state.ws_client, channel)

      case channel["channel"] do
        "TRADE-" <> trade_channel ->
            case CoinigyChannelServer.start_link([name: String.to_atom(trade_channel)]) do
              {:error, error} ->
                Logger.error("An error happened while subscribing to #{exch} #{base} \n #{inspect(error)}")
              {:ok, pid} ->
                Logger.info("Subscription succeeded #{inspect(pid)}")
            end

            trade_channel
        _any ->
          # ignore
          nil
      end
    end |> Enum.filter(fn i -> i != nil end)

    {:reply, :ok, %{state |
      coins_channels: Enum.concat(subscribed_channels, state.coins_channels),
      ws_subscriptions: Enum.concat(channels, state.ws_subscriptions) } }
  end

  def channels_for_exchange_base(channels, exch, base) do
    channels
    |> Enum.filter(fn i ->
      String.contains?(i["channel"], exch) &&
      String.contains?(i["channel"], base)
    end)
  end

  def handle_cast({:pong_ws_client, ping}, state) do
    CoinigyClient.pong(state.ws_client, ping)
    {:noreply, state}
  end

  def handle_cast({:set_auth_ws_client, token}, state) do
    Logger.info("Saving Coinigy WS Auth Token")
    CoinigyClient.available_channels(state.ws_client, nil)
    {:noreply, %{ state | ws_token: token }}
  end

  # def handle_cast({:tick_price, data}, state) do
  #   coin = state.coins
  #     |> Enum.find(nil, fn i -> compare_coin(i, data) end)
  #
  #   raw_price = %{
  #     "price" => data["price"],
  #     "quantity" => data["quantity"],
  #     "time" => data["time"]
  #   }
  #   # Logger.info("New Trade to add: #{inspect(raw_price)}")
  #
  #   new_state =
  #     if coin != nil do
  #
  #       last_30m = System.os_time - (30 * 60 * 1000 * 1_000_000)
  #
  #       # keeps only 30m of price data
  #       current_prices = coin["prices"]
  #         |> Enum.filter(fn i -> i["time"] >= last_30m end)
  #       # TODO: should I aggregate data as candle
  #
  #       new_prices = [ raw_price | current_prices ]
  #
  #       updated_coin = %{ coin |
  #         "last_price" => raw_price["price"],
  #         "last_trade_time" => System.os_time,
  #         "prices" => new_prices
  #       } |> calc_prices_percentages
  #
  #       updated_coins = state.coins
  #         |> Enum.map(fn i -> if compare_coin(i, data) do
  #             updated_coin
  #           else
  #             i
  #           end
  #         end )
  #
  #       %{ state | coins: updated_coins }
  #
  #     else
  #       new_coin = %{
  #         "exchange" => data["exchange"],
  #         "label" => data["label"],
  #         "last_price" => data["price"],
  #         "last_trade_time" => System.os_time,
  #         "prices" => [ raw_price ],
  #         "bid_price" => 0.0,
  #         "bid_quantity" => 0.0,
  #         "ask_price" => 0.0,
  #         "ask_quantity" => 0.0,
  #         "last_bid_ask_time" => 0,
  #         "volume_btc" => 0,
  #         "volume" => 0
  #       } |> calc_prices_percentages
  #
  #       # Logger.info("Adding new Coin #{inspect(new_coin)}")
  #
  #       %{ state | coins: [new_coin | state.coins] }
  #     end
  #
  #   # CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"coins" => new_state.coins})
  #
  #   {:noreply, new_state}
  # end
  #
  # def handle_cast({:tick_orders, data}, state) do
  #   coin = state.coins
  #     |> Enum.find(nil, fn i -> compare_coin(i, data) end)
  #
  #   # Logger.info("New OrderBook to add: #{inspect(data)}")
  #
  #   new_state =
  #     if coin != nil do
  #
  #       updated_coin = %{ coin |
  #         "bid_price" => data["bid_price"],
  #         "bid_quantity" => data["bid_quantity"],
  #         "ask_price" => data["ask_price"],
  #         "ask_quantity" => data["ask_quantity"],
  #         "last_bid_ask_time" => System.os_time,
  #       }
  #
  #       updated_coins = state.coins
  #         |> Enum.map(fn i -> if compare_coin(i, data) do
  #             updated_coin
  #           else
  #             i
  #           end
  #         end )
  #
  #       %{ state | coins: updated_coins }
  #
  #     else
  #       new_coin = %{
  #         "exchange" => data["exchange"],
  #         "label" => data["label"],
  #         "bid_price" => data["bid_price"],
  #         "bid_quantity" => data["bid_quantity"],
  #         "ask_price" => data["ask_price"],
  #         "ask_quantity" => data["ask_quantity"],
  #         "last_bid_ask_time" => System.os_time,
  #         "last_price" => data["price"],
  #         "last_trade_time" => 0,
  #         "prices" => [],
  #         "volume_btc" => 0,
  #         "volume" => 0
  #       } |> calc_prices_percentages
  #
  #       # Logger.info("Adding new Coin #{inspect(new_coin)}")
  #
  #       %{ state | coins: [new_coin | state.coins] }
  #     end
  #
  #   {:noreply, new_state}
  # end

  # defp compare_coin(a, b) do
  #   a["exchange"] == b["exchange"] && a["label"] == b["label"]
  # end
  #
  # def calc_prices_percentages(coin) do
  #   coin
  #     |> Map.put("period_3m", calc_price_percentage_time(coin, 3))
  #     |> Map.put("period_5m", calc_price_percentage_time(coin, 5))
  #     |> Map.put("period_10m", calc_price_percentage_time(coin, 10))
  #     |> Map.put("period_15m", calc_price_percentage_time(coin, 15))
  #     |> Map.put("period_30m", calc_price_percentage_time(coin, 30))
  #     |> Map.put("period_1h", calc_price_percentage_time(coin, 60))
  # end
  #
  # defp calc_price_percentage_time(coin, time) do
  #   time = System.os_time - (time * 60 * 1000 * 1_000_000)
  #
  #   {min_price, min_time, max_price, max_time, volume} = coin["prices"]
  #     |> Enum.filter(&(&1["time"] >= time))
  #     |> Enum.reduce({0.0, 0, 0.0, 0, 0},
  #       fn (i, {min_price, min_time, max_price, max_time, vol}) ->
  #         %{"price" => price, "time" => time, "quantity" => qty} = i
  #
  #         vol = vol + (price * qty)
  #
  #         cond do
  #           min_price == 0.0 -> {price, time, price, time, vol}
  #           price <= min_price -> {price, time, max_price, max_time, vol}
  #           price >= max_price -> {min_price, min_time, price, time, vol}
  #           true -> {min_price, min_time, max_price, max_time, vol}
  #         end
  #       end
  #     )
  #
  #     prices_diff = max_price - min_price
  #
  #     prices_percentage = if abs(prices_diff) > 0 do
  #       p = ((min_price / max_price) - 1) * 100
  #
  #       if max_time > min_time do
  #         p * -1
  #       else
  #         p
  #       end
  #     else
  #       0
  #     end
  #
  #
  #
  #     %{
  #       "min" => min_price,
  #       "min_time" => min_time,
  #       "max" => max_price,
  #       "max_time" => min_time,
  #       "diff" => prices_diff,
  #       "percentage" => prices_percentage,
  #       "volume" => volume
  #     }
  # end
end
