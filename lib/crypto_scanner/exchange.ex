defmodule CryptoScanner.Exchange do
  defstruct [
    :name,
    :status,
    :last_check,
    :exchange_time_diff,
    :exchange_info,
    :coins,
    :exchange_client,
    :tick
  ]
end
