defmodule BitPal.Backend do
  alias BitPal.Invoice

  @type backend_ref() :: {pid(), module()}

  @callback register(pid(), Invoice.t()) :: Invoice.t()
  @callback supported_currencies(pid()) :: [atom()]
  @callback configure(pid(), map()) :: :ok

  @spec register(backend_ref(), Invoice.t()) :: Invoice.t()
  def register({pid, backend}, invoice) do
    backend.register(pid, invoice)
  end

  @spec supported_currencies(backend_ref()) :: [atom()]
  def supported_currencies({pid, backend}) do
    backend.supported_currencies(pid)
  end

  @spec configure(backend_ref(), keyword()) :: :ok
  def configure({pid, backend}, opts) do
    backend.configure(pid, opts)
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
