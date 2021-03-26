defmodule BitPal.Backend do
  @type backend_ref() :: {pid(), module()}

  @callback register(pid(), BitPal.Request, BitPal.Watcher) :: BitPal.BCH.Satoshi
  @callback supported_currencies(pid()) :: [atom()]

  @spec register(backend_ref(), BitPal.Request, BitPal.Watcher) :: BitPal.BCH.Satoshi
  def register({pid, backend}, request, watcher) do
    backend.register(pid, request, watcher)
  end

  @spec supported_currencies(backend_ref()) :: [atom()]
  def supported_currencies({pid, backend}) do
    backend.supported_currencies(pid)
  end

  def supported_currency?(supported, specified) when is_list(supported) do
    supported =
      supported
      |> Enum.into(%{}, fn x -> {x, 1} end)

    specified
    |> Enum.all?(&Map.has_key?(supported, &1))
  end

  def supported_currency?(supported, specified) when is_atom(supported) do
    Enum.member?(specified, supported)
  end
end
