defmodule CryptoScanner.CryptoCompare do
  use WebSockex
  require Logger

  def get_prices() do
    Logger.info(">>>>> CryptoCompare - Updating btc and eth prices")
    url = "https://min-api.cryptocompare.com/data/pricemulti?fsyms=ETH,BTC&tsyms=USD"

    case HTTPotion.get url do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info("Fail to read prices: " <> message)
        {:error, message}

      %{body: body} ->
        Logger.info("Received body: #{inspect(body)}")
        {:ok, %{"BTC" => %{"USD" => btc}, "ETH" => %{"USD" => eth}}} = Poison.decode(body)
        {:ok, btc, eth}
      _ ->
        {:error, "Unknown update price error"}
    end
  end

end
