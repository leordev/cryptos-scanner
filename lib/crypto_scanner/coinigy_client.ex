defmodule CryptoScanner.CoinigyClient do
  use WebSockex
  require Logger

  alias CryptoScanner.CoinigyServer
  alias CryptoScanner.CoinigyChannelServer

  def start_link(opts \\ []) do
    url = "wss://sc-02.coinigy.com/socketcluster/"
    {:ok, pid} = WebSockex.start_link(url, __MODULE__, opts)
    Logger.info("Coinigy WS PID #{inspect(pid)}")

    handshake(pid)

    {:ok, pid}
  end

  def handshake(pid) do
    Logger.info("Sending Coinigy Handshake")
    emit(pid, "#handshake", %{ "authToken" => nil })
  end

  # def auth(pid, key, secret) do
  #   Logger.info("Authenticating to Coinigy SocketCluster")
  #   emit(pid, "auth", %{"apiKey" => key, "apiSecret" => secret})
  # end

  def pong(pid, ping) do
    Logger.info("Ping Reply to Coinigy SocketCluster")
    WebSockex.send_frame(pid, {:text, "##{String.to_integer(ping) + 1}"})
  end

  def available_channels(pid, exch \\ nil) do
    Logger.info("Getting Coinigy Available Channels for #{exch || "ALL"}")
    emit(pid, "channels", exch)
  end

  def subscribe_channel(pid, channel) do
    Logger.info("Subscribing to Coinigy Channel #{inspect(channel)}")
    emit(pid, "#subscribe", channel)
  end

  def handle_connect(_conn, state) do
    Logger.info("Coinigy Client Connected \n #{inspect(state)}")

    {:ok, state}
  end

  def handle_info(info, state) do
     Logger.info(">>>>> CoinigyWS INFO >>> \n #{inspect(info)}")
     {:ok, state}
  end

  def emit(pid, msg, data \\ nil) do
    frame = Poison.encode!(%{"event" => msg, "cid" => System.os_time, "data" => data})

    Logger.info("Coinigy Emit submitting \n #{inspect(frame)}")

    WebSockex.send_frame(pid, {:text, frame})

    {:ok, pid}
  end

  def reply_emit(msg, data \\ nil, state) do
    frame = Poison.encode!(%{"event" => msg, "cid" => System.os_time, "data" => data})

    Logger.info("Coinigy Replying Emit \n #{inspect(frame)}")

    {:reply, {:text, frame}, state}
  end

  def handle_cast(msg, state) do
    Logger.info("Unrecognized Coinigy Cast received: #{inspect(msg)}")
    {:ok, state}
  end

  def handle_frame({:text, "#" <> pingNum}, state) do
    Logger.info("Coinigy Ping ##{pingNum} Received")
    # CoinigyServer.pong_ws_client(:coinigy, pingNum)
    pong = String.to_integer(pingNum) + 1
    Logger.info("Ping Reply to Coinigy SocketCluster ##{pong}")
    {:reply, {:text, "##{pong}"}, state}
  end

  def handle_frame({:text, msg}, state) do
    case Poison.decode(msg) do
      {:error, error} ->
        Logger.info("Coinigy Msg fail to decode #{inspect(error)}")
        Logger.info("Coinigy Msg >>> #{msg}")
        {:ok, state}
      {:ok, %{ "event" => event, "data" => data }} ->
        case event do
          "#setAuthToken" ->
            CoinigyServer.set_auth_ws_client(:coinigy, data["token"])
          "#publish" ->
            handle_publish(data)
          unknown_event ->
            Logger.info("Unknown Coinigy Ws event: #{unknown_event}")
            Logger.info("Coinigy Msg >>> #{msg}")
        end
        {:ok, state}
      {:ok, %{ "data" => [data, _meta]}} ->

        # channels
        if String.length(hd(data)["channel"]) > 0  do
            CoinigyServer.set_ws_channels(data)
        end

        {:ok, state}

      {:ok, %{ "data" => %{ "isAuthenticated" => false}}} ->
        api_key = System.get_env("COINIGY_API_KEY")
        api_secret = System.get_env("COINIGY_API_SECRET")
        reply_emit("auth", %{"apiKey" => api_key, "apiSecret" => api_secret}, state)

      {:ok, _} ->
          Logger.info("Message not relevant")
          Logger.info("Coinigy Msg >>> #{msg}")

          {:ok, state}
    end
  end

  def handle_publish(res) do

    case res["channel"] do
      "TRADE-" <> trade_channel ->
        trade = res["data"]

        CoinigyChannelServer.add_transaction(String.to_atom(trade_channel),
          %{
            "exchange" => trade["exchange"],
            "label" => trade["label"],
            "price" => trade["price"],
            "quantity" => trade["quantity"],
            "time" => System.os_time,
          })

          # GenServer.whereis(String.to_atom("PLNX--USDT--XRP"))
        # CoinigyServer.tick_price(%{
        #     "exchange" => trade["exchange"],
        #     "label" => trade["label"],
        #     "price" => trade["price"],
        #     "quantity" => trade["quantity"],
        #     "time" => System.os_time,
        #   })
        # Logger.info(">>> Trade Received >>> #{trade_channel}")
      "ORDER-" <> order_channel ->
        # Logger.info(">>> OrderBook Received >>> #{order_channel}")

        order = hd(res["data"])

        [ alt_exchange, alt_base, alt_quote | _ ]
          = order_channel |> String.split("--")

        # Logger.info("First Order data #{inspect(order)}")

        {bid_price, bid_quantity, ask_price, ask_quantity} =
          res["data"]
          |> Enum.reduce({0.0, 0.0, 0.0, 0.0},
            fn (i, {bp, bq, ap, aq}) ->
              case i["ordertype"] do
                "Sell" ->
                  if ap == 0 || i["price"] < ap do
                    {bp, bq, i["price"], i["quantity"]}
                  else
                    {bp, bq, ap, aq}
                  end
                "Buy"  ->
                  if bp == 0 || i["price"] > bp do
                    {i["price"], i["quantity"], ap, aq}
                  else
                    {bp, bq, ap, aq}
                  end
                _ ->
                    {bp, bq, ap, aq}
              end
            end)

        # CoinigyServer.tick_orders(%{
        #     "exchange" => order["exchange"] || alt_exchange,
        #     "label" => order["label"] || (alt_base <> "/" <> alt_quote),
        #     "bid_price" => bid_price,
        #     "bid_quantity" => bid_quantity,
        #     "ask_price" => ask_price,
        #     "ask_quantity" => ask_quantity,
        #     "time" => System.os_time,
        #   })

        CoinigyChannelServer.update_orders(String.to_atom(order_channel),
          %{
            "exchange" => order["exchange"] || alt_exchange,
            "label" => order["label"] || (alt_base <> "/" <> alt_quote),
            "bid_price" => bid_price,
            "bid_quantity" => bid_quantity,
            "ask_price" => ask_price,
            "ask_quantity" => ask_quantity,
            "time" => System.os_time,
          })

      unknown ->
        Logger.info(">>> Unknown publish #{unknown}")
    end

  end

  def terminate(reason, state) do
    Logger.info("Coinigy Ws Terminating: \n#{inspect reason}\n\n#{inspect state}\n")
    CoinigyServer.ws_connect()
    exit(:normal)
  end


end
