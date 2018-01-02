defmodule CryptoScannerWeb.ScannerChannel do
  use Phoenix.Channel

  # alias CryptoScanner.CoinigyServer
  alias CryptoScanner.Coin
  require Logger

  intercept ["tick_alert"]

  @initial_filter %{"period" => "3m", "percentage" => -4, "volume" => 5}

  def join("scanner:alerts", _msg, socket) do
    socket = assign(socket, :filter, @initial_filter)

    {:ok, socket}
  end

  def handle_in("set_filter", body, socket) do
    socket = assign(socket, :filter, body)

    {:noreply, socket}
  end

  def handle_out("tick_alert", %{"coins" => coins, "btc_price" => btc_price, "eth_price" => eth_price}, socket) do
    %{
      "period" => period,
      "percentage" => percentage,
      "volume" => volume
    } = socket.assigns[:filter]

    Logger.info(">>>>> Scanner Alert Tick <<<<<")

    if coins != [] do
      push socket, "tick_alert", %{coins: calc_hot(coins, period, percentage, volume, btc_price, eth_price)}
    end

    {:noreply, socket}
  end

  def calc_hot(coins, period_flag, value, volume, btc_price, eth_price) do
    coins
      |> Enum.reduce([], fn (c, res) ->
        period = c["period_" <> period_flag]

        [ base, quote ] = String.split(c["label"], "/")

        btc_volume =
          case quote do
            "BTC" -> period["volume"]
            "USD" -> period["volume"] / btc_price
            "ETH" -> (period["volume"] * eth_price) / btc_price
            _any -> 0
          end

        percent = if period do period["percentage"] else 0 end

        if ((value < 0 && percent <= value) || (value > 0 && percent >= value)) && btc_volume >= volume do

          { from, to, time } =
            if period["max"] > period["min"] do
              { period["max"], period["min"], period["min_time"] }
            else
              { period["min"], period["max"], period["max_time"] }
            end

          Logger.info("Current coin #{c["label"]} went from #{from} to #{to} and has a BTC volume of #{btc_volume} for the current period of #{period_flag} -- Last Price: #{c["last_price"]}")

          [ %Coin{
            exchange: c["exchange"],
            symbol: c["label"],
            base: base,
            quote: quote,
            volume: period["volume"],
            bidPrice: c["bid_price"],
            askPrice: c["ask_price"],
            from: from,
            to: to,
            lastPrice: c["last_price"],
            time: time,
            percentage: percent,
            period3m: c["period_3m"],
            period5m: c["period_5m"],
            period10m: c["period_10m"],
            period15m: c["period_15m"],
            period30m: c["period_30m"]
          } | res ]

        else
          res
        end
      end)
  end


end
