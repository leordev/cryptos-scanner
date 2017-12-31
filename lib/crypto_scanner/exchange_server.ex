defmodule CryptoScanner.ExchangeServer do
  use GenServer

  require Logger

  alias CryptoScanner.Exchange
  alias CryptoScanner.Coin
  alias CryptoScanner.Binance
  alias CryptoScanner.BinanceClient

  def start_link(options) do

    [name: name] = options
    GenServer.start_link __MODULE__, name, options
  end

  def init(name) do
    Logger.info(">>>>> Starting Exchange Server #{name}")
    {exchange_info, exchange_time, exchange_client } =      #coins} =
      case name do
        :binance ->
          exchange_info = Binance.get_info()
          {:ok, exchange_client} = BinanceClient.start_link()
          {
            exchange_info,
            Binance.get_time(exchange_info),
            # Binance.get_coins([], true, exchange_info),
            exchange_client
          }
      end



    exchange = %Exchange{
      name: name,
      status: :active,
      last_check: System.os_time,
      exchange_time_diff: exchange_time,
      exchange_info: exchange_info,
      coins: [],
      exchange_client: exchange_client,
      tick: 0
    }


    #schedule_coins()

    {:ok, exchange}
  end

  # def schedule_coins() do
  #   Process.send_after(self(), :perform_update_coins, 15_000)
  # end

  # def handle_info(:perform_update_coins, state) do
  #   state = update_coins(state)
  #   # schedule_coins()
  #   {:noreply, state}
  # end

  def coins_tick(pid, coins) do
    GenServer.call(pid, {:coins_tick, coins})

    CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"exchange" => pid})
  end

  def get_status(pid) do
    GenServer.call(pid, :get_status)
  end

  def get_time(pid) do
    GenServer.call(pid, :get_time)
  end

  def get_coin(pid, symbol) do
    GenServer.call(pid, {:get_coin, symbol})
  end

  def get_hot(pid, period, value \\ -9) do
    GenServer.call(pid, {:get_hot, period, value})
  end

  def get_coins(pid) do
    GenServer.call(pid, :get_coins)
  end

  def handle_call(:get_coins, _from, state) do
    {:reply, {:ok, state.coins}, state}
  end

  def handle_call({:get_coin, symbol}, _from, state) do
    coin = state.coins
      |> Enum.filter(&(&1["symbol"] == symbol))
      |> hd

    {:reply, {:ok, coin}, state}
  end

  def handle_call({:get_hot, period, value}, _from, state) do
    {:reply, {:ok, calc_hot(state, period, value)}, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  def handle_call(:get_time, _from, state) do
    {:reply, {:ok, state.exchange_time_diff}, state}
  end

  def handle_call({:coins_tick, coins}, _from, state) do
    old_info = state.exchange_info

    new_symbols = old_info["symbols"]
      |> Enum.map(fn c ->

        new_coin = Enum.find(coins, nil,
          fn i -> i["symbol"] == c["symbol"] end)

        last_price = try do
          hd(c["prices"])
        rescue
          _ -> %{"price" => nil}
        end

        if new_coin != nil && last_price["price"] !== new_coin["price"] do

          Logger.info("Adding a new price #{inspect(new_coin)} over #{inspect(last_price)}")

          prices = [new_coin | (c["prices"] || [])]
            |> Enum.take(60*60*2)

          c
            |> Map.put("prices", prices)
            |> Binance.calc_prices_percentages
        else
          c
        end
      end)

    # TODO: What if the coin does not exist?
    new_info = %{ old_info | "symbols" => new_symbols }

    {:reply, :ok, %{ state | exchange_info: new_info}}

  end

  # defp update_coins(state) do
  #   tick = state.tick + 1
  #
  #   Logger.info(">>>>> Preparing for Binance coins routine on tick #{tick}")
  #
  #   exchange_info = if Integer.mod(tick, 240) == 0 do
  #     Logger.info(">>>>> updating exchange info")
  #
  #     case state.name do
  #       :binance ->
  #         Binance.get_info()
  #     end
  #   else
  #     state.exchange_info
  #   end
  #
  #   check_stats = Integer.mod(tick, 4) == 0
  #
  #   coins =
  #     case state.name do
  #       :binance ->
  #         Binance.get_coins(state.coins, check_stats, exchange_info)
  #     end
  #
  #   CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"exchange" => state.name})
  #
  #   %{ state | coins: coins, tick: tick, exchange_info: exchange_info }
  # end

  def calc_hot(state, period, value) do
    state.exchange_info["symbols"]
      |> Enum.filter(fn c ->
        percent = c["period_" <> period]["percentage"]
        (value < 0 && percent <= value) || (value > 0 && percent >= value)
      end)
      |> Enum.map(fn c ->
        period = c["period_" <> period]
        last_tick = hd(c["prices"])
        %Coin{
          exchange: "BINA",
          symbol: c["symbol"],
          base: c["baseAsset"],
          quote: c["quoteAsset"],
          volume: last_tick["quoteVolume"],
          bidPrice: last_tick["bidPrice"],
          askPrice: last_tick["askPrice"],
          from: period["max"],
          to: period["min"],
          percentage: period["percentage"]
        }
      end)
  end

end
