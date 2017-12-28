defmodule CryptoScanner.ExchangeServer do
  use GenServer

  require Logger

  alias CryptoScanner.Exchange
  alias CryptoScanner.Binance

  def start_link(options) do

    [name: name] = options
    GenServer.start_link __MODULE__, name, options
  end

  def init(name) do
    Logger.info(">>>>> Starting Exchange Server #{name}")
    {exchange_time, coins} =
      case name do
        :binance ->
          {Binance.get_time(), Binance.get_coins([], true)}
      end

    exchange = %Exchange{
      name: name,
      status: :active,
      last_check: System.os_time,
      exchange_time_diff: exchange_time,
      coins: coins,
      tick: 0
    }

    schedule_coins()

    {:ok, exchange}
  end

  def schedule_coins() do
    Process.send_after(self(), :perform_update_coins, 15_000)
  end

  def handle_info(:perform_update_coins, state) do
    GenServer.cast({state.name, node()}, :update_coins)
    schedule_coins()
    {:noreply, state}
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
    {:reply, {:ok, calc_hot(state.coins, period, value)}, state}
  end

  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  def handle_call(:get_time, _from, state) do
    {:reply, {:ok, state.exchange_time_diff}, state}
  end

  def handle_cast(:update_coins, state) do
    tick = state.tick + 1

    Logger.info(">>>>> Preparing for Binance coins routine on tick #{tick}")

    check_stats = Integer.mod(tick, 4) == 0

    coins =
      case state.name do
        :binance ->
          Binance.get_coins(state.coins, check_stats)
      end

    CryptoScannerWeb.Endpoint.broadcast("scanner:alerts", "tick_alert", %{"exchange" => state.name})

    {:noreply, %{ state | coins: coins, tick: tick }}
  end

  def calc_hot(coins, period, value) do
    coins
      |> Enum.filter(fn c ->
        percent = c["period_" <> period]["percentage"]
        (value < 0 && percent <= value) || (value > 0 && percent >= value)
      end)
  end

end
