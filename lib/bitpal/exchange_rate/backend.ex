defmodule BitPal.ExchangeRate.Backend do
  alias BitPal.ExchangeRate

  @callback name() :: String.t()
  @callback supported_pairs() :: [ExchangeRate.pair()]
  @callback compute(ExchangeRate.pair(), keyword()) ::
              {:ok, BitPal.ExchangeRateSupervisor.Result.t()}

  @spec compute(atom | pid, ExchangeRate.pair(), keyword) ::
          {:ok, BitPal.ExchangeRateSupervisor.Result.t()}
          | {:error, :not_supported}
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
