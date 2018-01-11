port module Main exposing (..)

import Date.Distance as Distance
import Date
import Html exposing (..)
import Html.Attributes exposing (attribute, class, defaultValue, href, placeholder, target, type_, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Encode as JE
import Json.Decode as JD
import Json.Decode.Pipeline as JDP
import FormatNumber
import FormatNumber.Locales exposing (usLocale)
import Time


init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        model =
            initModel flags

        cmd =
            if not (String.isEmpty model.user.id) then
                ( { model | isLoading = True }
                , Cmd.batch [ listExchanges model ]
                  --, getWatchList model ]
                )
            else
                ( model, Cmd.none )
    in
        cmd


initialModel : Model
initialModel =
    { coins = []
    , history = []
    , watchMarkets = []
    , filter = initialFilter
    , oldFilter = Nothing
    , showFilter = False
    , setupStep = None
    , isMuted = False
    , isLoading = False
    , user = User "" "" "" "" "" ""
    , exchanges = []
    , availableExchanges = []
    , error = Nothing
    , content = DaytradeScanner
    , coinigySocketsConnected = False
    , transactionsBook = []
    , orderBook = []
    , currentTime = 0
    }


initModel : Flags -> Model
initModel flags =
    let
        loggedIn =
            not (String.isEmpty flags.user.id)
    in
        { initialModel
            | setupStep = None
            , user = flags.user
        }


initialFilter : Filter
initialFilter =
    { volume = 1, period = Period5m, percentage = -10 }


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }



-- Model


type NotificationType
    = Success
    | Error


type SetupStep
    = UserSetup
    | ExchangesSetup
    | None


type Content
    = DaytradeScanner
    | BaseCracker
    | ActiveTrades
    | MyReports
    | MarketWatch


type PeriodType
    = Period3m
    | Period5m
    | Period10m
    | Period15m
    | Period30m


type alias Flags =
    { user : User
    , exchanges : List Exchange
    }


type alias User =
    { id : String
    , email : String
    , name : String
    , apiKey : String
    , apiSecret : String
    , apiChannelKey : String
    }


type alias Exchange =
    { id : String
    , code : String
    , name : String
    }


type alias Model =
    { filter : Filter
    , oldFilter : Maybe Filter
    , watchMarkets : List Coin
    , coins : List Coin
    , history : List Coin
    , showFilter : Bool
    , setupStep : SetupStep
    , exchanges : List Exchange -- TODO: probably remove, not needed if we use watch market (favorites from coinigy)
    , availableExchanges : List Exchange
    , isMuted : Bool
    , isLoading : Bool
    , user : User
    , error : Maybe String
    , content : Content
    , coinigySocketsConnected : Bool
    , transactionsBook : List Transaction
    , orderBook : List Order
    , currentTime : Time.Time
    }


type alias Filter =
    { volume : Int
    , period : PeriodType
    , percentage : Int
    }


type alias Coin =
    { exchange : String
    , marketId : String
    , base : String
    , quote : String
    , market : String
    , from : Float
    , to : Float
    , lastPrice : Float
    , volume : Float
    , btcVolume : Float
    , bidPrice : Float
    , askPrice : Float
    , percentage : Float
    , time : Time.Time
    , period3m : Maybe Period
    , period5m : Maybe Period
    , period10m : Maybe Period
    , period15m : Maybe Period
    , period30m : Maybe Period
    }


type alias Period =
    { min : Float
    , max : Float
    , diff : Float
    , percentage : Float
    }


type TradeType
    = Buy
    | Sell


type alias Transaction =
    { id : String
    , tradeType : TradeType
    , price : Float
    , quantity : Float
    , time : String
    , marketId : String
    }


type alias Order =
    { tradeType : TradeType
    , price : Float
    , quantity : Float
    , time : String
    , marketId : String
    }



-- Ports


port saveUser : User -> Cmd msg


port saveExchanges : Flags -> Cmd msg


port deleteUser : () -> Cmd msg


port alarmAudio : () -> Cmd msg


port startSockets : { user : User, exchanges : List Coin } -> Cmd msg


port setTitle : String -> Cmd msg


port notifySound : String -> Cmd msg


port setFilter : JD.Value -> Cmd msg


port newAlert : (List Coin -> msg) -> Sub msg



-- port newFavorite : (JD.Value -> msg) -> Sub msg


port receiveFavorites : (JD.Value -> msg) -> Sub msg


port receiveTrade : (JD.Value -> msg) -> Sub msg


port receiveOrder : (( String, JD.Value ) -> msg) -> Sub msg


port coinigySocketConnection : (Bool -> msg) -> Sub msg



-- Subscriptions
-- type CoinigyFavoriteMsgType
--     = Price
--     | H24
--
--
-- type alias CoinigyFavoriteMsg =
--     { dataType : CoinigyFavoriteMsgType
--     , exchangeCode : String
--     , market : String
--     , lastPrice : Float
--     , volume : Float
--     }


getMarketId : Model -> String -> String -> Maybe String
getMarketId model exchange market =
    model.watchMarkets
        |> List.filter
            (\i -> i.market == market && i.exchange == exchange)
        |> List.map (\i -> i.marketId)
        |> List.head


parseTradeType : String -> TradeType
parseTradeType tradeTypeTxt =
    if tradeTypeTxt == "Sell" then
        Sell
    else
        Buy



-- handleTrade : Model -> JD.Value -> Msg
-- handleTrade model val =
--     let
--         toDecoder exchange market price quantity tradeTypeTxt time id =
--             case (getMarketId model exchange market) of
--                 Just marketId ->
--                     JD.succeed
--                         (Transaction id
--                             (parseTradeType tradeTypeTxt)
--                             price
--                             quantity
--                             time
--                             marketId
--                         )
--
--                 Nothing ->
--                     JD.fail
--                         ("Trade - Invalid exchange Id for "
--                             ++ exchange
--                             ++ "-"
--                             ++ market
--                         )
--
--         transaction =
--             JD.decodeValue
--                 (JDP.decode toDecoder
--                     |> JDP.required "exchange" JD.string
--                     |> JDP.required "label" JD.string
--                     |> JDP.required "price" JD.float
--                     |> JDP.required "quantity" JD.float
--                     |> JDP.required "type" JD.string
--                     |> JDP.required "time" JD.string
--                     |> JDP.required "tradeid" JD.string
--                     |> JDP.resolve
--                 )
--                 val
--     in
--         case transaction of
--             Ok t ->
--                 TransactionReceived t
--
--             Err failed ->
--                 CoinigyFailReceived
--                     (Debug.log "transaction receive fail" failed)
-- handleOrder : Model -> ( String, JD.Value ) -> Msg
-- handleOrder model ( marketId, val ) =
--     let
--         toDecoder price quantity tradeTypeTxt time =
--             JD.succeed
--                 (Order
--                     (parseTradeType tradeTypeTxt)
--                     price
--                     quantity
--                     time
--                     marketId
--                 )
--
--         orders =
--             JD.decodeValue
--                 (JD.list
--                     (JD.oneOf
--                         [ (JDP.decode toDecoder
--                             |> JDP.required "price" JD.float
--                             |> JDP.required "quantity" JD.float
--                             |> JDP.required "ordertype" JD.string
--                             |> JDP.optional "timestamp" JD.string ""
--                             |> JDP.resolve
--                           )
--                         , JD.null (Order Buy 0.0 0.0 "" "")
--                         ]
--                     )
--                 )
--                 val
--     in
--         case orders of
--             Ok o ->
--                 OrdersReceived o
--
--             Err failed ->
--                 CoinigyFailReceived
--                     (Debug.log "order receive fail" failed)


subscriptions : Model -> Sub Msg
subscriptions model =
    if not (String.isEmpty model.user.id) then
        Sub.batch
            [ --Time.every (60 * Time.second) UpdateWatchMarket
              coinigySocketConnection CoinigySocketConnection

            -- , receiveTrade (handleTrade model)
            -- , receiveOrder (handleOrder model)
            , newAlert AlertReceived
            , Time.every Time.second Tick
            ]
    else
        Sub.none



-- update


type Msg
    = AlertReceived (List Coin)
    | CoinigyFailReceived String
    | UpdateVolume String
    | UpdatePercentage String
    | UpdatePeriod String
    | SetFilter
    | ShowFilter
    | ToggleSetup SetupStep
    | UpdateCoinigyKey String
    | UpdateCoinigySecret String
    | UpdateCoinigyChannelKey String
    | UpdateUserSetup
    | ExchangesResponse (Result Http.Error (List Exchange))
    | UserKeysResponse (Result Http.Error User)
      -- | WatchListResponse (Result Http.Error (List Coin))
    | CoinigySocketConnection Bool
    | ResetFilter
    | DeleteError
    | ToggleSound
    | Tick Time.Time
    | SetContent Content
    | Logout



-- | UpdateWatchMarket Time.Time


removeNewCoins : List Coin -> Coin -> Bool
removeNewCoins oldCoins newCoin =
    oldCoins
        |> List.map .market
        |> List.member newCoin.market


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick time ->
            ( { model | currentTime = time }, Cmd.none )

        CoinigySocketConnection isConnected ->
            ( { model | coinigySocketsConnected = isConnected }, Cmd.none )

        SetContent content ->
            ( { model | content = content }, Cmd.none )

        Logout ->
            ( initialModel, deleteUser () )

        DeleteError ->
            ( { model | error = Nothing }, Cmd.none )

        CoinigyFailReceived error ->
            ( { model
                | error =
                    Just (Debug.log "coinigy received error!" error)
              }
            , Cmd.none
            )

        AlertReceived coins ->
            let
                -- oldCoins =
                --     model.coins
                --         |> List.filter (removeNewCoins model.coins)
                --
                -- updatedCoins =
                --     coins ++ oldCoins
                oldCoins =
                    coins
                        |> List.filter
                            (\i ->
                                model.coins
                                    |> List.filter (\o -> o.exchange == i.exchange && o.market == i.market)
                                    |> List.length
                                    |> (<) 0
                            )

                history =
                    model.history
                        |> List.map
                            (\i ->
                                oldCoins
                                    |> List.filter (\o -> o.exchange == i.exchange && o.market == i.market)
                                    |> List.head
                                    |> Maybe.withDefault i
                            )

                newHistory =
                    oldCoins
                        |> List.filter
                            (\i ->
                                history
                                    |> List.filter (\o -> o.exchange == i.exchange && o.market == i.market)
                                    |> List.length
                                    |> (==) 0
                            )
                        |> flip (++) history

                updatedCoins =
                    coins

                playAlarm =
                    not model.isMuted
                        && (updatedCoins
                                |> List.filter
                                    (\i ->
                                        i.time
                                            >= (model.currentTime
                                                    - Time.second
                                                    * 11
                                               )
                                    )
                                |> List.length
                                |> (<) 0
                           )

                countCoins =
                    updatedCoins |> List.length

                title =
                    "CryptoTradingBuddy"

                newTitle =
                    if countCoins > 0 then
                        "(" ++ (countCoins |> toString) ++ ") " ++ title
                    else
                        title

                cmd =
                    if playAlarm then
                        Cmd.batch [ setTitle newTitle, alarmAudio () ]
                    else
                        setTitle newTitle
            in
                ( { model | coins = updatedCoins, history = newHistory }, cmd )

        UpdatePeriod period ->
            let
                filter =
                    model.filter

                newFilter =
                    { filter | period = (stringToPeriod period) }
            in
                ( { model | filter = newFilter }, Cmd.none )

        UpdateVolume volume ->
            let
                filter =
                    model.filter

                newVolume =
                    Result.withDefault
                        filter.volume
                        (String.toInt volume)

                newFilter =
                    { filter | volume = newVolume }
            in
                ( { model | filter = newFilter }, Cmd.none )

        UpdatePercentage percent ->
            let
                filter =
                    model.filter

                newPercentage =
                    Result.withDefault
                        filter.percentage
                        (String.toInt percent)

                newFilter =
                    { filter | percentage = newPercentage }
            in
                ( { model | filter = newFilter }, Cmd.none )

        ShowFilter ->
            ( { model
                | showFilter = True
                , oldFilter = Just model.filter
              }
            , Cmd.none
            )

        ToggleSetup step ->
            ( { model | setupStep = step }, Cmd.none )

        ResetFilter ->
            ( { model
                | oldFilter = Nothing
                , filter = (Maybe.withDefault initialFilter model.oldFilter)
                , showFilter = False
              }
            , Cmd.none
            )

        SetFilter ->
            let
                filter =
                    model.filter

                filterObj =
                    JE.object
                        [ ( "period", JE.string (periodToString filter.period) )
                        , ( "percentage", JE.int filter.percentage )
                        , ( "volume", JE.int filter.volume )
                        ]
            in
                ( { model | oldFilter = Nothing, showFilter = False }
                , setFilter filterObj
                )

        ToggleSound ->
            ( { model | isMuted = not model.isMuted }, Cmd.none )

        UpdateUserSetup ->
            updateUserSetup model

        -- UpdateWatchMarket _ ->
        --     ( { model | isLoading = True }, getWatchList model )
        UserKeysResponse (Ok user) ->
            let
                newUser =
                    { user
                        | apiKey = model.user.apiKey
                        , apiSecret = model.user.apiSecret
                        , apiChannelKey = model.user.apiChannelKey
                    }

                newModel =
                    { model
                        | user = newUser
                        , error = Nothing
                        , isLoading = True
                    }
            in
                ( newModel
                , Cmd.batch [ saveUser newUser ]
                  --, getWatchList newModel ]
                )

        UserKeysResponse (Err err) ->
            handleResponseErrors model err "Fail to get user data"

        ExchangesResponse (Ok exchanges) ->
            ( { model | availableExchanges = exchanges, isLoading = False }
            , Cmd.none
            )

        ExchangesResponse (Err err) ->
            handleResponseErrors model err "Fail to list exchanges"

        -- WatchListResponse (Ok res) ->
        --     let
        --         setupStep =
        --             if List.length res > 0 then
        --                 None
        --             else
        --                 ExchangesSetup
        --
        --         cmd =
        --             if not model.coinigySocketsConnected then
        --                 startSockets { user = model.user, exchanges = res }
        --             else
        --                 Cmd.none
        --
        --         oldMarkets =
        --             model.watchMarkets
        --                 |> List.map
        --                     (\m ->
        --                         let
        --                             newMarket =
        --                                 res
        --                                     |> List.filter (\r -> r.marketId == m.marketId)
        --                                     |> List.head
        --                         in
        --                             case newMarket of
        --                                 Just nm ->
        --                                     { nm | askPrice = m.askPrice, bidPrice = m.bidPrice }
        --
        --                                 Nothing ->
        --                                     m
        --                     )
        --
        --         newMarkets =
        --             res
        --                 |> List.filter
        --                     (\r ->
        --                         List.length (List.filter (\m -> m.marketId == r.marketId) model.watchMarkets) == 0
        --                     )
        --
        --         finalMarkets =
        --             calcPercentages
        --                 (newMarkets ++ oldMarkets)
        --                 model.history
        --     in
        --         ( { model
        --             | watchMarkets = finalMarkets
        --             , isLoading = False
        --             , setupStep = setupStep
        --           }
        --         , cmd
        --         )
        --
        -- WatchListResponse (Err err) ->
        --     handleResponseErrors model err "Fail to get watched coins"
        UpdateCoinigyKey key ->
            let
                user =
                    model.user

                newUser =
                    { user | apiKey = key }
            in
                ( { model | user = newUser }, Cmd.none )

        UpdateCoinigyChannelKey key ->
            let
                user =
                    model.user

                newUser =
                    { user | apiChannelKey = key }
            in
                ( { model | user = newUser }, Cmd.none )

        UpdateCoinigySecret secret ->
            let
                user =
                    model.user

                newUser =
                    { user | apiSecret = secret }
            in
                ( { model | user = newUser }, Cmd.none )


periodToString : PeriodType -> String
periodToString period =
    case period of
        Period3m ->
            "3m"

        Period5m ->
            "5m"

        Period10m ->
            "10m"

        Period15m ->
            "15m"

        Period30m ->
            "30m"


stringToPeriod : String -> PeriodType
stringToPeriod period =
    case period of
        "3m" ->
            Period3m

        "5m" ->
            Period5m

        "10m" ->
            Period10m

        "15m" ->
            Period15m

        "30m" ->
            Period30m

        _ ->
            Period5m



-- calcPercentages : List Coin -> List Coin -> List Coin
-- calcPercentages coins history =
--     List.map
--         (\coin ->
--             let
--                 currentDate =
--                     case Date.fromString coin.time of
--                         Ok date ->
--                             Date.toTime date
--
--                         Err _ ->
--                             0
--
--                 calcPeriod period =
--                     let
--                         pastCoins =
--                             history
--                                 |> List.filter
--                                     (\oldCoin ->
--                                         let
--                                             oldDate =
--                                                 case Date.fromString oldCoin.time of
--                                                     Ok date ->
--                                                         Date.toTime date
--
--                                                     Err _ ->
--                                                         0
--                                         in
--                                             oldCoin.marketId == coin.marketId && (currentDate - oldDate) <= period
--                                     )
--
--                         minPrice =
--                             (coin :: pastCoins)
--                                 |> List.map .to
--                                 |> List.minimum
--                                 |> Maybe.withDefault 0
--
--                         maxPrice =
--                             (coin :: pastCoins)
--                                 |> List.map .to
--                                 |> List.maximum
--                                 |> Maybe.withDefault 0
--
--                         diffPrices =
--                             (maxPrice - minPrice) * -1
--
--                         percentagePrices =
--                             if abs (diffPrices) > 0 then
--                                 ((minPrice / maxPrice) - 1) * 100
--                             else
--                                 0
--                     in
--                         Just (Period minPrice maxPrice diffPrices percentagePrices)
--             in
--                 { coin
--                     | period3m = calcPeriod (3 * Time.minute)
--                     , period5m = calcPeriod (5 * Time.minute)
--                     , period10m = calcPeriod (10 * Time.minute)
--                     , period15m = calcPeriod (15 * Time.minute)
--                     , period30m = calcPeriod (30 * Time.minute)
--                 }
--         )
--         coins


handleResponseErrors : Model -> Http.Error -> String -> ( Model, Cmd Msg )
handleResponseErrors model err msg =
    let
        _ =
            Debug.log msg err

        error =
            case err of
                Http.BadStatus res ->
                    (toString res.status.code) ++ " - " ++ (toString res.body)

                Http.BadPayload msg _ ->
                    msg

                _ ->
                    "Fail to get Coinigy Exchanges list"
    in
        ( { model | error = Just error, isLoading = False }, Cmd.none )


userDecoder : JD.Decoder User
userDecoder =
    JD.field "data"
        (JDP.decode User
            |> JDP.required "pref_referral_code" JD.string
            |> JDP.required "email" JD.string
            |> JDP.required "chat_nick" JD.string
            |> JDP.hardcoded ""
            |> JDP.hardcoded ""
            |> JDP.hardcoded ""
        )


exchangesDecoder : JD.Decoder (List Exchange)
exchangesDecoder =
    JD.field "data"
        (JD.list
            (JDP.decode Exchange
                |> JDP.required "exch_id" JD.string
                |> JDP.required "exch_code" JD.string
                |> JDP.required "exch_name" JD.string
            )
        )


watchListCoinDecoder : JD.Decoder (List Coin)
watchListCoinDecoder =
    let
        toDecoder exchangeCode exchangeId market from to volume btcVolume serverTime =
            let
                ( base, quote ) =
                    case (String.split "/" market) of
                        [ txt1, txt2 ] ->
                            ( txt1, txt2 )

                        _ ->
                            ( "", "" )
            in
                JD.succeed
                    (Coin
                        exchangeCode
                        exchangeId
                        base
                        quote
                        market
                        (Result.withDefault 0.0 (String.toFloat from))
                        (Result.withDefault 0.0 (String.toFloat to))
                        (Result.withDefault 0.0 (String.toFloat volume))
                        (Result.withDefault 0.0 (String.toFloat btcVolume))
                        0.0
                        0.0
                        0.0
                        0.0
                        serverTime
                        Nothing
                        Nothing
                        Nothing
                        Nothing
                        Nothing
                    )
    in
        JD.field "data"
            (JD.list
                (JDP.decode toDecoder
                    |> JDP.required "exch_code" JD.string
                    |> JDP.required "exchmkt_id" JD.string
                    |> JDP.required "mkt_name" JD.string
                    |> JDP.required "prev_price" JD.string
                    |> JDP.required "last_price" JD.string
                    |> JDP.required "current_volume" JD.string
                    |> JDP.required "btc_volume" JD.string
                    |> JDP.required "server_time" JD.float
                    |> JDP.resolve
                )
            )



-- proxyUrl : String
-- proxyUrl =
--     "http://localhost:3031"
-- getWatchList : Model -> Cmd Msg
-- getWatchList model =
--     let
--         apiKey =
--             Http.header "X-API-KEY" model.user.apiKey
--
--         apiSecret =
--             Http.header "X-API-SECRET" model.user.apiSecret
--
--         url =
--             "/api/coinigy/my-markets"
--
--         request =
--             Http.request
--                 { method = "GET"
--                 , headers = [ apiKey, apiSecret ]
--                 , url = url
--                 , body = Http.emptyBody
--                 , expect = Http.expectJson watchListCoinDecoder
--                 , timeout = Nothing
--                 , withCredentials = False
--                 }
--
--         cmd =
--             Http.send WatchListResponse request
--     in
--         cmd


listExchanges : Model -> Cmd Msg
listExchanges model =
    let
        apiKey =
            Http.header "X-API-KEY" model.user.apiKey

        apiSecret =
            Http.header "X-API-SECRET" model.user.apiSecret

        url =
            "/api/coinigy/exchanges"

        request =
            Http.request
                { method = "GET"
                , headers = [ apiKey, apiSecret ]
                , url = url
                , body = Http.emptyBody
                , expect = Http.expectJson exchangesDecoder
                , timeout = Nothing
                , withCredentials = False
                }

        cmd =
            Http.send ExchangesResponse request
    in
        cmd


updateUserSetup : Model -> ( Model, Cmd Msg )
updateUserSetup model =
    if
        String.isEmpty model.user.apiKey
            || String.isEmpty model.user.apiSecret
    then
        ( { model | error = Just "Please fill API Key and API Secret" }, Cmd.none )
    else
        let
            apiKey =
                Http.header "X-API-KEY" model.user.apiKey

            apiSecret =
                Http.header "X-API-SECRET" model.user.apiSecret

            url =
                "/api/coinigy/userInfo"

            request =
                Http.request
                    { method = "POST"
                    , headers = [ apiKey, apiSecret ]
                    , url = url
                    , body = Http.emptyBody
                    , expect = Http.expectJson userDecoder
                    , timeout = Nothing
                    , withCredentials = False
                    }

            cmd =
                Http.send UserKeysResponse request
        in
            ( { model | error = Nothing, isLoading = True }, cmd )



-- reusable components


icon : String -> Bool -> Bool -> Html Msg
icon icon spin isLeft =
    let
        spinner =
            if spin then
                " fa-spin"
            else
                ""

        className =
            "fa" ++ spinner ++ " fa-" ++ icon

        classIcon =
            if isLeft then
                "icon is-left"
            else
                "icon"
    in
        span [ class classIcon ]
            [ i [ class className ]
                []
            ]


loadingIcon : Model -> Html Msg
loadingIcon model =
    if model.isLoading then
        icon "spinner" True False
    else
        text ""


disabledAttribute : Bool -> Attribute msg
disabledAttribute isDisabled =
    if isDisabled then
        attribute "disabled" "true"
    else
        attribute "data-empty" ""


fieldInput : Model -> String -> String -> String -> String -> (String -> Msg) -> Html Msg
fieldInput model fieldLabel fieldValue fieldPlaceHolder fieldIcon fieldMsg =
    let
        loadingClass =
            if model.isLoading then
                " is-loading"
            else
                ""
    in
        div [ class "field" ]
            [ label [ class "label is-large" ]
                [ text fieldLabel ]
            , div
                [ class
                    ("control has-icons-left has-icons-right"
                        ++ loadingClass
                    )
                ]
                [ input
                    [ class "input is-large"
                    , placeholder fieldPlaceHolder
                    , type_ "text"
                    , defaultValue fieldValue
                    , onInput fieldMsg
                    ]
                    []
                , icon fieldIcon False True

                -- , span [ class "icon is-small is-right" ]
                --     [ i [ class "fa fa-check" ]
                --         []
                --     ]
                ]
            ]


selectInput : Model -> List ( String, String ) -> String -> String -> String -> (String -> Msg) -> Html Msg
selectInput model optionsType fieldLabel fieldValue fieldIcon fieldMsg =
    let
        options =
            optionsType
                |> List.map
                    (\( optVal, optText ) ->
                        option [ value optVal ] [ text optText ]
                    )

        loadingClass =
            if model.isLoading then
                " is-loading"
            else
                ""
    in
        div [ class "field" ]
            [ label [ class "label is-large" ]
                [ text fieldLabel ]
            , div [ class ("control has-icons-left" ++ loadingClass) ]
                [ div [ class "select is-large is-fullwidth" ]
                    [ select [ onInput fieldMsg, disabledAttribute model.isLoading ] options ]
                , icon fieldIcon False True
                ]
            ]


modalCard : Model -> String -> Msg -> List (Html Msg) -> Maybe ( String, Msg ) -> Maybe ( String, Msg ) -> Html Msg
modalCard model title close body ok cancel =
    let
        loadingClass =
            if model.isLoading then
                " is-loading"
            else
                ""

        okButton =
            case ok of
                Just ( txt, msg ) ->
                    button
                        [ class ("button is-success" ++ loadingClass)
                        , onClick msg
                        , disabledAttribute model.isLoading
                        ]
                        [ text txt ]

                Nothing ->
                    text ""

        cancelButton =
            case cancel of
                Just ( txt, msg ) ->
                    button
                        [ class ("button is-light" ++ loadingClass)
                        , onClick msg
                        , disabledAttribute model.isLoading
                        ]
                        [ text txt ]

                Nothing ->
                    text ""
    in
        div [ class "modal is-active" ]
            [ div [ class "modal-background" ] []
            , div [ class "modal-card" ]
                [ header [ class "modal-card-head" ]
                    [ p [ class "modal-card-title" ]
                        [ loadingIcon model, text title ]
                    , button
                        [ class "delete"
                        , attribute "aria-label" "close"
                        , onClick close
                        ]
                        []
                    ]
                , section [ class "modal-card-body" ]
                    body
                , footer [ class "modal-card-foot" ]
                    [ okButton
                    , cancelButton
                    ]
                ]
            ]


notification : String -> NotificationType -> Maybe Msg -> Html Msg
notification txt notifType closeMsg =
    let
        notifClass =
            case notifType of
                Success ->
                    "is-success"

                Error ->
                    "is-danger"

        closeButton =
            case closeMsg of
                Just msg ->
                    button [ class "delete", onClick msg ]
                        [ text "" ]

                Nothing ->
                    text ""
    in
        div [ class ("notification " ++ notifClass) ]
            [ closeButton
            , text txt
            ]


message : String -> NotificationType -> Html Msg
message txt messageType =
    let
        messageClass =
            case messageType of
                Success ->
                    "is-success"

                Error ->
                    "is-danger"
    in
        article [ class ("message " ++ messageClass) ]
            [ div [ class "message-body" ]
                [ text txt ]
            ]



-- view


errorAlert : Model -> Html Msg
errorAlert model =
    case model.error of
        Just txt ->
            message txt Error

        Nothing ->
            text ""


filterModal : Model -> Html Msg
filterModal model =
    let
        periodOptions =
            [ ( "3m", "3 Minutes Period" )
            , ( "5m", "5 Minutes Period" )
            , ( "10m", "10 Minutes Period" )
            , ( "15m", "15 Minutes Period" )
            , ( "30m", "30 Minutes Period" )
            ]

        modalClass =
            if model.showFilter then
                "modal is-active"
            else
                "modal"

        filterData =
            model.filter

        percentage =
            (toString filterData.percentage)

        period =
            filterData.period

        volume =
            (toString filterData.volume)
    in
        modalCard model
            "Update Scanner Filter"
            ResetFilter
            [ form []
                [ selectInput
                    model
                    periodOptions
                    "Period"
                    (periodToString period)
                    "clock-o"
                    UpdatePeriod
                , fieldInput
                    model
                    "Percentage"
                    percentage
                    "-9"
                    "percent"
                    UpdatePercentage
                , fieldInput
                    model
                    "Current Period Volume (BTC)"
                    volume
                    "50000"
                    "btc"
                    UpdateVolume
                ]
            ]
            (Just ( "Submit", SetFilter ))
            (Just ( "Cancel", ResetFilter ))



-- exchangesSelector : Model -> List (Html Msg)
-- exchangesSelector model =
--     List.map
--         (\item ->
--             let
--                 isSelected =
--                     List.member item model.exchanges
--
--                 ( iconClass, selectedClass ) =
--                     if isSelected then
--                         ( "check fa-lg", " selected" )
--                     else
--                         ( "times fa-lg", "" )
--
--                 selectorClass =
--                     "box exchange-selector has-text-centered"
--                         ++ selectedClass
--             in
--                 div [ class "column is-one-third" ]
--                     [ div [ class selectorClass, onClick (SelectExchange item) ]
--                         [ p [] [ icon iconClass False False ]
--                         , text item.name
--                         ]
--                     ]
--         )
--         model.availableExchanges


setupModal : Model -> Html Msg
setupModal model =
    let
        userData =
            model.user

        -- submitMsg =
        --     if String.isEmpty userData.id then
        --         UpdateUserSetup
        --     else
        --         UpdateExchangeSetup
        ( formContent, submitButton, cancelButton ) =
            case model.setupStep of
                UserSetup ->
                    ( [ fieldInput model
                            "Coinigy Key"
                            userData.apiKey
                            "Your Coinigy API Key"
                            "key"
                            UpdateCoinigyKey
                      , fieldInput model
                            "Coinigy Secret"
                            userData.apiSecret
                            "Your Coinigy API Secret"
                            "lock"
                            UpdateCoinigySecret

                      -- , fieldInput model
                      --       "Coinigy Private Channel ID"
                      --       userData.apiChannelKey
                      --       "Your Coinigy Private Channel ID (Websocket API)"
                      --       "lock"
                      --       UpdateCoinigyChannelKey
                      ]
                    , (Just ( "Submit", UpdateUserSetup ))
                    , (Just ( "Cancel", (ToggleSetup None) ))
                    )

                ExchangesSetup ->
                    ( [ div [ class "content" ]
                            [ h2 [ class "title" ]
                                [ text
                                    ("Welcome "
                                        ++ userData.name
                                        ++ "!"
                                    )
                                ]
                            , p [] [ text "Looks like you don't have any Favorited Market on Coinigy. Please add them inside coinigy and refresh the page!" ]
                            ]

                      -- , div [ class "columns is-multiline" ]
                      --     (exchangesSelector model)
                      ]
                    , Nothing
                    , Nothing
                    )

                None ->
                    ( [ text "Ooops... Something is wrong here!" ], Nothing, Nothing )
    in
        modalCard model
            "Setup CryptoTradingBuddy"
            (ToggleSetup None)
            [ form [] formContent
            , div [] [ errorAlert model ]
            ]
            submitButton
            cancelButton


exchangeUrl : Coin -> String
exchangeUrl coin =
    case coin.exchange of
        "BINA" ->
            "https://www.binance.com/trade.html?symbol="
                ++ (coin.market
                        |> String.split "/"
                        |> String.join "_"
                   )

        "HITB" ->
            "https://www.hitbtc.com/exchange/" ++ coin.base ++ "-to-" ++ coin.quote

        "PLNX" ->
            "https://poloniex.com/exchange#"
                ++ (coin.market
                        |> String.split "/"
                        |> String.join "_"
                   )

        "LIQU" ->
            "https://liqui.io/#/exchange/"
                ++ (coin.market
                        |> String.split "/"
                        |> String.join "_"
                   )

        _ ->
            "#"


coinigyUrl : Coin -> String
coinigyUrl coin =
    "https://www.coinigy.com/main/markets/"
        ++ coin.exchange
        ++ "/"
        ++ coin.base
        ++ "/"
        ++ coin.quote


cryptoCompareUrl : Coin -> String
cryptoCompareUrl coin =
    "https://www.cryptocompare.com/coins/" ++ (String.toLower coin.base) ++ "/forum/" ++ coin.quote


calcTimeDiff : Time.Time -> Time.Time -> String
calcTimeDiff timeOld timeNew =
    let
        defaultConfig =
            Distance.defaultConfig

        config =
            { defaultConfig | includeSeconds = True }

        inWords =
            config
                |> Distance.inWordsWithConfig
    in
        inWords (Date.fromTime timeOld) (Date.fromTime timeNew)


coinCard : Coin -> Filter -> Time.Time -> Html Msg
coinCard coin filter currentTime =
    let
        pairName =
            coin.base ++ "/" ++ coin.quote

        exchangeName =
            "@ " ++ coin.exchange

        percentage =
            toString coin.percentage ++ "% "

        ( titleColor, percentIcon ) =
            if coin.percentage < 0 then
                ( "has-text-danger"
                , span [ class "icon" ]
                    [ i [ class "fa fa-caret-down" ] [] ]
                )
            else
                ( "has-text-success"
                , span [ class "icon" ]
                    [ i [ class "fa fa-caret-up" ] [] ]
                )
    in
        div [ class "column coin-column" ]
            [ div [ class "card" ]
                [ div [ class "card-content" ]
                    [ div
                        [ class "content" ]
                        [ nav [ class "level" ]
                            [ div [ class "level-left" ]
                                [ div [ class "level-item" ]
                                    [ h3
                                        [ class ("title is-3 " ++ titleColor) ]
                                        [ text percentage, percentIcon ]
                                    ]
                                , div [ class "level-item" ]
                                    [ strong [] [ text pairName ]
                                    ]
                                , div [ class "level-item" ]
                                    [ small [] [ text exchangeName ] ]
                                ]
                            , div [ class "level-right" ]
                                [ div [ class "level-item" ]
                                    [ small [ class "is-pulled-right" ] [ text (calcTimeDiff coin.time currentTime) ] ]
                                ]
                            ]
                        , nav [ class "level" ]
                            [ div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ] [ text "From" ]
                                    , p [ class "title is-5" ]
                                        [ text (toString coin.from) ]
                                    ]
                                ]
                            , div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ] [ text "To" ]
                                    , p [ class "title is-5" ]
                                        [ text (toString coin.to) ]
                                    ]
                                ]
                            , div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ] [ text "Last Price" ]
                                    , p [ class "title is-5" ]
                                        [ text (toString coin.lastPrice) ]
                                    ]
                                ]
                            ]
                        , nav [ class "level" ]
                            [ div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ] [ text "Bid" ]
                                    , p [ class "title is-5" ]
                                        [ text (toString coin.bidPrice) ]
                                    ]
                                ]
                            , div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ] [ text "Ask" ]
                                    , p [ class "title is-5" ]
                                        [ text (toString coin.askPrice) ]
                                    ]
                                ]
                            , div [ class "level-item has-text-centered" ]
                                [ div []
                                    [ p [ class "heading" ]
                                        [ text
                                            (coin.quote
                                                ++ " Volume ("
                                                ++ (periodToString filter.period)
                                                ++ ")"
                                            )
                                        ]
                                    , p [ class "title is-5" ]
                                        [ text (FormatNumber.format usLocale coin.volume) ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                , footer [ class "card-footer" ]
                    [ a
                        [ href (exchangeUrl coin)
                        , target "_blank"
                        , class "card-footer-item"
                        ]
                        [ text "Exchange"
                        , icon "exchange" False False
                        ]
                    , a
                        [ href (coinigyUrl coin)
                        , target "_blank"
                        , class "card-footer-item"
                        ]
                        [ text "Coinigy"
                        , icon "bar-chart" False False
                        ]
                    , a
                        [ href (cryptoCompareUrl coin)
                        , target "_blank"
                        , class "card-footer-item"
                        ]
                        [ text "CryptoCompare"
                        , icon "comments" False False
                        ]
                    ]
                ]
            ]


topMenu : Model -> Html Msg
topMenu model =
    let
        loggedOut =
            String.isEmpty model.user.id

        content =
            if loggedOut then
                [ p [ class "navbar-item" ] [ loadingIcon model ]
                , a [ class "navbar-item", onClick (ToggleSetup UserSetup) ]
                    [ text "Login" ]
                ]
            else
                let
                    soundIcon =
                        "fa fa-2x "
                            ++ if model.isMuted then
                                "fa-volume-off has-text-danger"
                               else
                                "fa-volume-up has-text-success"
                in
                    [ p [ class "navbar-item" ]
                        [ loadingIcon model

                        -- , text ("Hello, " ++ model.user.name)
                        ]

                    -- , a
                    --     [ class "navbar-item"
                    --     , onClick Logout
                    --     ]
                    --     [ icon "sign-out" False False
                    --     , text "Logout"
                    --     ]
                    , a
                        [ class "navbar-item"
                        , onClick ToggleSound
                        ]
                        [ span [ class "navbar-item icon is-small" ]
                            [ i [ class soundIcon ] [] ]
                        ]
                    ]
    in
        nav
            [ attribute "aria-label" "main navigation"
            , class "navbar"
            , attribute "role" "navigation"
            ]
            [ div [ class "navbar-brand logo" ]
                [ text "CryptoTradingBuddy" ]
            , div [ class "navbar-menu" ]
                [ div [ class "navbar-end" ]
                    content
                ]
            ]


mainContent : Model -> Html Msg
mainContent model =
    if String.isEmpty model.user.id then
        section [ class "hero is-info is-large" ]
            [ div [ class "hero-body" ]
                [ div [ class "container" ]
                    [ h2 [ class "subtitle" ]
                        [ text "Not just a Scanner or Market Aggregator..." ]
                    , h1 [ class "title logo" ]
                        [ text "I'm going to be your BEST buddy in your tradings :)" ]
                    ]
                ]
            ]
    else
        let
            menu =
                div [ class "tabs" ]
                    [ ul []
                        [ li
                            [ class
                                (if model.content == DaytradeScanner then
                                    "is-active"
                                 else
                                    ""
                                )
                            ]
                            [ a [ onClick (SetContent DaytradeScanner) ]
                                [ icon "bullhorn" False False
                                , text
                                    ("Daytrade Scanner ("
                                        ++ (toString (List.length model.coins))
                                        ++ ")"
                                    )
                                ]
                            ]
                        , li
                            [ class
                                (if model.content == BaseCracker then
                                    "is-active"
                                 else
                                    ""
                                )
                            ]
                            [ a [ onClick (SetContent BaseCracker) ]
                                [ icon "line-chart" False False
                                , text "Base Cracker"
                                ]
                            ]
                        , li
                            [ class
                                (if model.content == ActiveTrades then
                                    "is-active"
                                 else
                                    ""
                                )
                            ]
                            [ a [ onClick (SetContent ActiveTrades) ]
                                [ icon "exchange" False False
                                , text "Active Trades"
                                ]
                            ]
                        , li
                            [ class
                                (if model.content == MyReports then
                                    "is-active"
                                 else
                                    ""
                                )
                            ]
                            [ a [ onClick (SetContent MyReports) ]
                                [ icon "book" False False
                                , text "My Reports"
                                ]
                            ]

                        -- , li
                        --     [ class
                        --         (if model.content == MarketWatch then
                        --             "is-active"
                        --          else
                        --             ""
                        --         )
                        --     ]
                        --     [ a [ onClick (SetContent MarketWatch) ]
                        --         [ icon "star" False False
                        --         , text "Favorites"
                        --         ]
                        --     ]
                        ]
                    ]

            content =
                case model.content of
                    MarketWatch ->
                        watchListContent model

                    DaytradeScanner ->
                        scannerContent model

                    BaseCracker ->
                        p []
                            [ text "Here we are going to automate/manage the AWESOME base cracker scanner created by Nathan Smith - For now, run it manually from "
                            , a [ href "https://github.com/highmindedlowlife/trading-scripts" ]
                                [ text "his Github repository." ]
                            ]

                    ActiveTrades ->
                        p [] [ text "Here we will keep track of our current active trades, where to layer in from the base and calculate break-even percentages of them" ]

                    MyReports ->
                        p [] [ text "Here we summarize all of our trades in all exchanges, see the profit and loss to keep track of our gains" ]
        in
            section [ class "section" ]
                [ div [ class "container" ]
                    [ menu
                    , content
                    ]
                ]


reversedComparison a b =
    case compare a b of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT


historyContent : Model -> Html Msg
historyContent model =
    table [ class "table is-striped is-hoverable is-fullwidth" ]
        [ thead []
            [ tr []
                [ th [] [ text "Market" ]
                , th [] [ text "Volume" ]
                , th [] [ text "Last Price" ]
                , th [] [ text "Current Bid" ]
                , th [] [ text "Current Ask" ]
                , th [] [ text ("From -> To (%)") ]
                , th [] [ icon "clock" False False ]
                ]
            ]
        , tbody []
            (model.history
                |> List.sortWith (\a b -> reversedComparison a.time b.time)
                |> List.map
                    (\item ->
                        tr []
                            [ td []
                                [ text ("[" ++ item.exchange ++ "] " ++ item.market)
                                , a
                                    [ href (exchangeUrl item)
                                    , target "_blank"
                                    ]
                                    [ icon "exchange" False False ]
                                , a
                                    [ href (coinigyUrl item)
                                    , target "_blank"
                                    ]
                                    [ icon "bar-chart" False False ]
                                , a
                                    [ href (cryptoCompareUrl item)
                                    , target "_blank"
                                    ]
                                    [ icon "comments" False False ]
                                ]
                            , td [] [ text (FormatNumber.format usLocale (abs item.btcVolume)) ]
                            , td [] [ text (toString item.to) ]
                            , td [] [ text (toString item.bidPrice) ]
                            , td [] [ text (toString item.askPrice) ]
                            , td []
                                [ text ((toString item.from) ++ " -> " ++ (toString item.to) ++ " ")
                                , small [] [ text ("(" ++ (FormatNumber.format usLocale item.percentage) ++ "%)") ]
                                ]
                            , td [] [ text (calcTimeDiff item.time model.currentTime) ]
                            ]
                    )
            )
        ]


watchListContent : Model -> Html Msg
watchListContent model =
    table [ class "table is-striped is-hoverable is-fullwidth" ]
        [ thead []
            [ tr []
                [ th [] [ text "Exchange" ]
                , th [] [ text "Market" ]
                , th [] [ text "BTC Volume (24h)" ]
                , th [] [ text "Last Price" ]
                , th [] [ text "Current Bid" ]
                , th [] [ text "Current Ask" ]
                , th [] [ text ("% (" ++ (periodToString model.filter.period) ++ ")") ]
                ]
            ]
        , tbody []
            (model.watchMarkets
                |> List.sortWith
                    (\a b ->
                        case compare a.exchange b.exchange of
                            EQ ->
                                case compare a.quote b.quote of
                                    EQ ->
                                        compare a.base b.base

                                    res ->
                                        res

                            res ->
                                res
                    )
                |> List.map
                    (\item ->
                        let
                            percentage =
                                case model.filter.period of
                                    Period3m ->
                                        Maybe.withDefault 0
                                            (Maybe.map .percentage item.period3m)

                                    Period5m ->
                                        Maybe.withDefault 0
                                            (Maybe.map .percentage item.period5m)

                                    Period10m ->
                                        Maybe.withDefault 0
                                            (Maybe.map .percentage item.period10m)

                                    Period15m ->
                                        Maybe.withDefault 0
                                            (Maybe.map .percentage item.period15m)

                                    Period30m ->
                                        Maybe.withDefault 0
                                            (Maybe.map .percentage item.period30m)
                        in
                            tr []
                                [ td [] [ text item.exchange ]
                                , td [] [ text item.market ]
                                , td [] [ text (FormatNumber.format usLocale (abs item.btcVolume)) ]
                                , td [] [ text (toString item.to) ]
                                , td [] [ text (toString item.bidPrice) ]
                                , td [] [ text (toString item.askPrice) ]
                                , td [] [ text ((FormatNumber.format usLocale percentage) ++ "%") ]
                                ]
                    )
            )
        ]


scannerContent : Model -> Html Msg
scannerContent model =
    let
        filter =
            model.filter

        filtering =
            "Scanning "
                ++ (toString filter.percentage)
                ++ "%, "
                ++ (periodToString filter.period)
                ++ ", "
                ++ (toString filter.volume)
                ++ "+ BTC Vol"

        content =
            if List.length model.coins > 0 then
                div
                    [ class "columns is-multiline" ]
                    (model.coins
                        |> List.sortWith (\a b -> reversedComparison a.time b.time)
                        |> List.map
                            (\c -> coinCard c filter model.currentTime)
                    )
            else
                p [] [ text "Go relax man! No scanner alerts... at least for now!" ]

        history =
            if List.length model.history > 0 then
                div [ class "m-t-lg" ]
                    [ h2 [ class "title is-3" ] [ text "History" ]
                    , historyContent model
                    ]
            else
                text ""
    in
        div []
            [ div [ class "has-text-right filter-link" ]
                [ a
                    [ onClick ShowFilter ]
                    [ text filtering, icon "cog" False False ]
                ]
            , content
            , history
            ]


view : Model -> Html Msg
view model =
    let
        modal =
            if model.showFilter then
                filterModal model
            else if model.setupStep /= None then
                setupModal model
            else
                text ""
    in
        div []
            [ topMenu model
            , mainContent model
            , footer [ class "footer" ]
                [ div [ class "container" ]
                    [ div [ class "content has-text-centered" ]
                        [ p []
                            [ strong []
                                [ text "CryptoTradingBuddy" ]
                            , text " by "
                            , a [ href "http://leordev.github.io" ]
                                [ text "Leo Ribeiro" ]
                            , text ". The source code is licensed "
                            , a [ href "http://opensource.org/licenses/mit-license.php" ]
                                [ text "MIT" ]
                            , text "."
                            ]
                        ]
                    ]
                ]
            , modal
            ]
