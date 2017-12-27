defmodule CryptoScanner.Exchange do
  defstruct [:name, :status, :last_check, :exchange_time_diff, :coins, :tick]
end
