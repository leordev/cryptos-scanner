defmodule CryptoScanner.Coin do
  defstruct [
    :exchange,
    :symbol,
    :base,
    :quote,
    :from,
    :to,
    :volume,
    :bidPrice,
    :askPrice,
    :percentage
  ]
end
