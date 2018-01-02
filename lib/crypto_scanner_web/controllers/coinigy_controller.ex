defmodule CryptoScannerWeb.CoinigyController do
  use CryptoScannerWeb, :controller
  alias CryptoScanner.CoinigyServer

  require Logger

  @url "https://api.coinigy.com/api"

  defp auth_headers() do
    [ "X-API-KEY": System.get_env("COINIGY_API_KEY"),
      "X-API-SECRET": System.get_env("COINIGY_API_SECRET") ]
  end

  def get(conn, _params) do
    {:ok, coins} = CoinigyServer.get_coins()
    json conn, coins
  end

  def get_coin(conn,
    %{"exchange" => exch, "base" => base, "quote" => quote}) do
    {:ok, coin} = CoinigyServer.get_coin(exch, base <> "/" <> quote)
    json conn, coin
  end

  def get_exchanges(conn, _params) do
    url = "#{@url}/v1/exchanges"
    Logger.info(">>> Coinigy Listing exchanges")

    response = case HTTPotion.post url, [headers: auth_headers(), timeout: 10_000] do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info("Fail to read exchanges: " <> message)
        message
      %{body: body} ->
        Poison.decode!(body)
    end

    json conn, response
  end

  def get_markets(conn, _params) do
    url = "#{@url}/v1/userWatchList"
    Logger.info(">>> Coinigy Listing Favorite Markets")

    response = case HTTPotion.post url, [headers: auth_headers(), timeout: 10_000] do
      %HTTPotion.ErrorResponse{message: message} ->
        Logger.info("Fail to read favorite markets: " <> message)
        message
      %{body: body} ->
        Poison.decode!(body)
    end

    # if markets = response["data"] do
    #   for market <- markets do
    #     CryptoScanner.CoinigyServer.subscribe_to_channels(:coinigy, market["exch_code"], String.split(market["mkt_name"], "/") |> tl)
    #   end
    # end

    json conn, response
  end

  def get_subscriptions(conn, _params) do
    {:ok, subscriptions} = CoinigyServer.get_subscriptions()
    json conn, subscriptions
  end

  def get_available_channels(conn, _params) do
    {:ok, subscriptions} = CoinigyServer.get_available_channels()
    json conn, subscriptions
  end
end
