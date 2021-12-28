defmodule BitPal.Backend do
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice

  @type backend_ref() :: {pid(), module()}

  @callback register(pid(), Invoice.t()) :: Invoice.t()
  @callback supported_currencies(pid()) :: [atom()]
  @callback configure(pid(), map()) :: :ok

  # Check if the backend is ready. (Note: We could make a pub/sub for this if needed)
  @callback ready?(pid()) :: boolean()

  @spec register(backend_ref(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register({pid, backend}, invoice) do
    try do
      backend.register(pid, invoice)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec supported_currencies(backend_ref()) :: [Currency.id()]
  def supported_currencies({pid, backend}) do
    try do
      backend.supported_currencies(pid)
    catch
      :exit, _reason ->
        []
    end
  end

  @spec configure(backend_ref(), keyword()) :: :ok | {:error, term}
  def configure({pid, backend}, opts) do
    try do
      backend.configure(pid, opts)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec supported_currency?(list | atom, list) :: boolean
  def supported_currency?(supported, specified) when is_list(supported) do
    supported =
      supported
      |> Enum.into(%{}, fn x -> {x, 1} end)

    specified
    |> Enum.all?(&Map.has_key?(supported, &1))
  end

  def supported_currency?(supported, specified) do
    Enum.member?(specified, supported)
  end

  @spec via_tuple(Currency.id()) :: {:via, Registry, any}
  def via_tuple(currency_id) do
    ProcessRegistry.via_tuple({__MODULE__, currency_id})
  end
end
