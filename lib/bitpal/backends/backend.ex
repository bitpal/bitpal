defmodule BitPal.Backend do
  alias BitPal.Blocks
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice

  @type backend_ref() :: {pid(), module()}
  @type backend_status ::
          :initializing
          | {:recovering, Blocks.height(), Blocks.height()}
          | {:syncing, float}
          | {:error, term}
          | :ready
          | :stopped
          | :not_found
  @type backend_info :: map()

  @callback register(pid(), Invoice.t()) :: Invoice.t()
  @callback supported_currency(pid()) :: Currency.id()
  @callback status(pid()) :: backend_status()
  @callback info(pid()) :: backend_info()
  @callback poll_info(pid()) :: backend_info()
  @callback start(pid()) :: :ok
  @callback stop(pid()) :: :ok
  @callback configure(pid(), map()) :: :ok

  @spec register(backend_ref(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def register({pid, backend}, invoice) do
    try do
      backend.register(pid, invoice)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec supported_currency(backend_ref()) :: {:ok, Currency.id()} | {:error, :not_found}
  def supported_currency({pid, backend}) do
    try do
      {:ok, backend.supported_currency(pid)}
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec status(backend_ref()) :: backend_status()
  def status({pid, backend}) do
    try do
      backend.status(pid)
    catch
      :exit, _reason -> :not_found
    end
  end

  @spec info(backend_ref()) :: backend_status()
  def info({pid, backend}) do
    try do
      backend.info(pid)
    catch
      :exit, _reason -> :not_found
    end
  end

  @spec poll_info(backend_ref()) :: :ok | :not_found
  def poll_info({pid, backend}) do
    try do
      backend.poll_info(pid)
    catch
      :exit, _reason -> :not_found
    end
  end

  @spec start(backend_ref()) :: backend_status()
  def start({pid, backend}) do
    try do
      backend.start(pid)
    catch
      :exit, _reason -> :not_found
    end
  end

  @spec stop(backend_ref()) :: backend_status()
  def stop({pid, backend}) do
    try do
      backend.stop(pid)
    catch
      :exit, _reason -> :not_found
    end
  end

  @spec configure(backend_ref(), keyword()) :: :ok | {:error, :not_found}
  def configure({pid, backend}, opts) do
    try do
      backend.configure(pid, opts)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec via_tuple(Currency.id()) :: {:via, Registry, any}
  def via_tuple(currency_id) do
    ProcessRegistry.via_tuple({__MODULE__, currency_id})
  end
end
