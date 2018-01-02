defmodule CryptoScannerWeb.ScannerChannel do
  use Phoenix.Channel

  # alias CryptoScanner.CoinigyServer
  alias CryptoScanner.Coin

  intercept ["tick_alert"]

  @initial_filter %{"period" => "3m", "percentage" => -9, "volume" => 10}

  def join("scanner:alerts", _msg, socket) do
    socket = assign(socket, :filter, @initial_filter)

    {:ok, socket}
  end

  def handle_in("set_filter", body, socket) do
    socket = assign(socket, :filter, body)

    {:noreply, socket}
  end

  def handle_out("tick_alert", %{"coins" => coins}, socket) do
    %{
      "period" => period,
      "percentage" => percentage
    } = socket.assigns[:filter]

    if coins != [] do
      push socket, "tick_alert", %{coins: calc_hot(coins, period, percentage)}
    end

    {:noreply, socket}
  end

  def calc_hot(coins, period, value) do
    coins
      |> Enum.filter(fn c ->
        percent = c["period_" <> period]["percentage"]
        (value < 0 && percent <= value) || (value > 0 && percent >= value)
      end)
      |> Enum.map(fn c ->
        period = c["period_" <> period]

        [ base, quote ] = String.split(c["label"], "/")

        { from, to, time } =
          if period["max"] > period["min"] do
            { period["max"], period["min"], period["min_time"] }
          else
            { period["min"], period["max"], period["max_time"] }
          end

        %Coin{
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
          percentage: period["percentage"],
          period3m: c["period_3m"],
          period5m: c["period_5m"],
          period10m: c["period_10m"],
          period15m: c["period_15m"],
          period30m: c["period_30m"]
        }
      end)
  end


end
