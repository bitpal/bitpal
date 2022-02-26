defmodule BitPal.Backend do
  @moduledoc """
  The backend behaviour that all backend plugins must implement.

  # Init

  It's important to not block `init`, so `handle_continue` should be used and
  registering the process with ProcessRegistry (using `Backend.via_tuple(currency_id)`)
  is the only thing that should be done in `init`.

  # Child spec

  The `id` should represent the currency the plugin handles, and `restart` should use `:transient`.

  # Restart behaviour

  During startup or shutdown the backend will be restarted depending on the return values
  (the process should specify `restart: :transient`):

  :normal or :shutdown      Don't restart
  {:shutdown, reason}       Delayed restart (use when we want to reconnect after a short delay)
  {:error, error}           Immediate restart
  crash or other return     Immediate restart
  """

  alias BitPal.Blocks
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice

  @type backend_ref() :: {pid(), module()}
  @type stopped_reason ::
          :normal
          | :shutdown
          | {:shutdown, term}
          | {:error, term}

  @type backend_status ::
          :starting
          | {:recovering, Blocks.height(), Blocks.height()}
          | {:syncing, float}
          | :ready
          | {:stopped, stopped_reason}
          | :unknown
          | :plugin_not_found
  @type backend_info :: map()

  @callback supported_currency(pid()) :: Currency.id()
  @callback register(pid(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  @callback info(pid()) :: {:ok, backend_info()} | {:error, term}
  @callback poll_info(pid()) :: :ok | {:error, term}
  @callback configure(pid(), map()) :: :ok | {:error, term}

  @spec supported_currency(backend_ref()) :: {:ok, Currency.id()} | {:error, :not_found}
  def supported_currency({pid, backend}) do
    try do
      {:ok, backend.supported_currency(pid)}
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec register(backend_ref(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register({pid, backend}, invoice) do
    try do
      backend.register(pid, invoice)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec info(backend_ref()) :: {:ok, backend_info} | {:error, term}
  def info({pid, backend}) do
    try do
      backend.info(pid)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec poll_info(backend_ref()) :: :ok | {:error, term}
  def poll_info({pid, backend}) do
    try do
      backend.poll_info(pid)
    catch
      :exit, _reason -> {:error, :not_found}
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

  @spec via_tuple(Currency.id()) :: {:via, Registry, any}
  def via_tuple(currency_id) do
    ProcessRegistry.via_tuple({__MODULE__, currency_id})
  end
end
