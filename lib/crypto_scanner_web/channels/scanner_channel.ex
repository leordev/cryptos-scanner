defmodule CryptoScannerWeb.ScannerChannel do
  use Phoenix.Channel

  alias CryptoScanner.ExchangeServer

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

  def handle_out("tick_alert", %{"exchange" => exchange}, socket) do
    %{
      "period" => period,
      "percentage" => percentage
    } = socket.assigns[:filter]

    {:ok, coins} = ExchangeServer.get_hot(exchange, period, percentage)

    coins = %{coins: coins}

    push socket, "tick_alert", coins

    {:noreply, socket}
  end


end
