defmodule BitPal.Backend do
  @moduledoc """
  The backend behavior that all backend plugins must implement.

  # Init

  It's important to not block `init`, so `handle_continue` should be used and
  registering the process with ProcessRegistry (using `Backend.via_tuple(currency_id)`)
  is the only thing that should be done in `init`.

  # Child spec

  The `id` should represent the currency the plugin handles, and `restart` should use `:transient`.

  # Restart behavior

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
          | {:recovering, {Blocks.height(), Blocks.height()}}
          | {:syncing, float}
          | {:syncing, {Blocks.height(), Blocks.height()}}
          | :ready
          | {:stopped, stopped_reason}
          | :unknown
          | :plugin_not_found
  @type backend_info :: map()
  @type backend_opts :: map()

  @doc """
  Get the supported currency of the backend.
  """
  @callback supported_currency(pid()) :: {:ok, Currency.id()} | {:error, term}

  @doc """
  Register a finalized invoice for the backend to track.

  The backend is responsible for:
  - Adding an address to the invoice.
  - Start tracking the address and notify via `Transctions.seen()`, `Transactions.confirmed()`
    and `Transactions.double_spent().
  """
  @callback register_invoice(pid(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}

  @doc """
  Get the stored info of the backend.
  """
  @callback info(pid()) :: {:ok, backend_info()} | {:error, term}

  @doc """
  Refresh backend info.

  The refresh may be an async call, so no direct response is made here.
  Instead the backend is expected to broadcast a {:backend, :info} event
  when the info is updated.
  """
  @callback refresh_info(pid()) :: :ok | {:error, term}

  @doc """
  Send configuration options to the backend.
  """
  @callback configure(pid(), backend_opts()) :: :ok | {:error, term}

  defmacro __using__(params) do
    quote do
      @behaviour BitPal.Backend
      use GenServer
      alias BitPal.Backend
      alias BitPal.BackendEvents
      alias BitPal.BackendStatusSupervisor
      alias BitPal.ProcessRegistry

      @currency_id Keyword.get(unquote(params), :currency_id)

      @doc false
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      defoverridable start_link: 1

      @doc false
      def child_spec(opts) do
        currency_id =
          @currency_id || raise("currency_id is nil, then we must override child_spec/1")

        opts =
          opts
          |> Keyword.put(:currency_id, currency_id)

        %{
          id: currency_id,
          start: {__MODULE__, :start_link, [opts]},
          restart: :transient
        }
      end

      defoverridable child_spec: 1

      @doc false
      @impl GenServer
      def init(opts) do
        currency_id = Keyword.fetch!(opts, :currency_id)

        Registry.register(
          ProcessRegistry,
          Backend.via_tuple(currency_id),
          __MODULE__
        )

        # FIXME would be nice to just do this...
        # BackendStatusSupervisor.set_starting(currency_id)

        # Customization and enhancements should be done via continue
        # so we don't block init().
        {:ok, opts, {:continue, :init}}
      end

      defoverridable init: 1

      @doc false
      @impl Backend
      def configure(_pid, _opts), do: :ok

      defoverridable configure: 2

      @doc false
      @impl Backend
      def supported_currency(_backend) do
        {:ok,
         @currency_id || raise("currency_id is nil, then we must override supported_currency/1")}
      end

      defoverridable supported_currency: 1
    end
  end

  # FIXME implement these with macros?
  # It's just a repeat of calling all callbacks and wrapping it in :not_found

  @spec supported_currency(backend_ref()) :: {:ok, Currency.id()} | {:error, :not_found}
  def supported_currency({pid, backend}) do
    try do
      backend.supported_currency(pid)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec register_invoice(backend_ref(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register_invoice({pid, backend}, invoice) do
    try do
      backend.register_invoice(pid, invoice)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec info(backend_ref()) :: {:ok, backend_info | nil} | {:error, term}
  def info({pid, backend}) do
    try do
      backend.info(pid)
    catch
      :exit, _reason -> {:error, :not_found}
    end
  end

  @spec refresh_info(backend_ref()) :: :ok | {:error, term}
  def refresh_info({pid, backend}) do
    try do
      backend.refresh_info(pid)
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

  # BackendMacro.def_call(:configure, :opts)
end
