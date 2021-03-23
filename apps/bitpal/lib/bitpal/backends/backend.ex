defmodule BitPal.Backend do
  @type process() :: pid() | module()

  @callback register(process(), BitPal.Request, BitPal.Watcher) :: BitPal.BCH.Satoshi
  @callback supported_currencies(process()) :: [atom()]

  def supported_currencies(backend, process) do
    backend.supported_currencies(process)
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
