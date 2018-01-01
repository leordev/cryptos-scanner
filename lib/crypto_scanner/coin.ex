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
    :percentage,
    :period3m,
    :period5m,
    :period10m,
    :period15m,
    :period30m
  ]
end
