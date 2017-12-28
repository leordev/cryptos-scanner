defmodule CryptoScannerWeb.ScannerChannel do
  use Phoenix.Channel

  alias CryptoScanner.ExchangeServer

  intercept ["tick_alert"]

  @initial_filter %{"period" => "3m", "value" => -9}

  def join("scanner:alerts", _msg, socket) do
    socket = assign(socket, :filter, @initial_filter)

    {:ok, socket}
  end

  def handle_in("set_filter", body, socket) do
    socket = assign(socket, :filter, body)

    {:noreply, socket}
  end

  def handle_out("tick_alert", %{"exchange" => exchange}, socket) do
    %{"period" => period, "value" => value} = socket.assigns[:filter]

    {:ok, coins} = ExchangeServer.get_hot(exchange, period, value)

    coins = %{coins: coins}

    push socket, "tick_alert", coins

    {:noreply, socket}
  end


end
