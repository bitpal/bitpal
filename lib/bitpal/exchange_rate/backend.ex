defmodule BitPal.ExchangeRate.Backend do
  alias BitPal.ExchangeRate

  @callback name() :: String.t()
  @callback supported_pairs() :: [ExchangeRate.pair()]
  @callback compute(ExchangeRate.pair(), keyword()) :: {:ok, BitPal.ExchangeRate.Result.t()}

  def compute(backend, pair, opts \\ []) do
    if Enum.member?(backend.supported_pairs, pair) do
      backend.compute(pair, opts)
    else
      {:error, :not_supported}
    end
  rescue
    RuntimeError -> {:error, RuntimeError}
  end
end
