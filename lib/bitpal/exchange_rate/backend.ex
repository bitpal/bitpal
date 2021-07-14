defmodule BitPal.ExchangeRate.Backend do
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor.Result
  alias BitPalSchemas.Currency

  @callback name() :: String.t()
  @callback supported() :: %{Currrency.id() => [Currency.id()]}
  @callback compute(ExchangeRate.pair(), keyword()) :: {:ok, Result.t()}

  @spec compute(atom | pid, ExchangeRate.pair(), keyword) ::
          {:ok, Result.t()} | {:error, :not_supported}
  def compute(backend, pair, opts \\ []) do
    if supported?(backend.supported(), pair) do
      backend.compute(pair, opts)
    else
      {:error, :not_supported}
    end
  rescue
    RuntimeError -> {:error, RuntimeError}
  end

  defp supported?(map, {from, to}) do
    if list = Map.get(map, from, nil) do
      Enum.member?(list, to)
    else
      false
    end
  end
end
