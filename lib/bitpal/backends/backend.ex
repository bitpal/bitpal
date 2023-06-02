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
  require Logger

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
  Assign an address to the invoice.
  """
  @callback assign_address(pid(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}

  @doc """
  Assign the payment uri.
  Should use the descripton from the invoice and the recipent name from the associated store.
  """
  @callback assign_payment_uri(pid(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}

  @doc """
  Start watching the invoice for transaction updates.
  """
  @callback watch_invoice(pid(), Invoice.t()) :: :ok | {:error, term}

  @doc """
  Update information about an invoice.
  Should issue updates of all transactions to that address.
  """
  @callback update_address(pid(), Invoice.t()) :: :ok | {:error, term}

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

      @currency_id Keyword.fetch!(unquote(params), :currency_id)

      @doc false
      def start_link(opts) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      defoverridable start_link: 1

      @doc false
      def child_spec(opts) do
        opts =
          opts
          |> Keyword.put(:currency_id, @currency_id)

        %{
          id: @currency_id,
          start: {__MODULE__, :start_link, [opts]},
          restart: opts[:restart] || :transient
        }
      end

      defoverridable child_spec: 1

      @doc false
      @impl GenServer
      def init(opts) do
        Registry.register(
          ProcessRegistry,
          Backend.via_tuple(@currency_id),
          __MODULE__
        )

        if log_level = opts[:log_level] do
          Logger.put_process_level(self(), log_level)
        end

        BackendStatusSupervisor.set_starting(@currency_id)

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
        {:ok, @currency_id}
      end

      defoverridable supported_currency: 1

      # Helpers to make status updates easier
      def set_starting, do: BackendStatusSupervisor.set_starting(@currency_id)
      def set_ready, do: BackendStatusSupervisor.set_ready(@currency_id)
      def set_recovering(state), do: BackendStatusSupervisor.set_recovering(@currency_id, state)
      def set_syncing(state), do: BackendStatusSupervisor.set_syncing(@currency_id, state)
      def set_stopped(reason), do: BackendStatusSupervisor.set_stopped(@currency_id, reason)
      def sync_done, do: BackendStatusSupervisor.sync_done(@currency_id)
    end
  end

  # Forwarding functions

  @spec register_invoice(backend_ref(), Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register_invoice(ref, invoice) do
    with {:ok, invoice} <- assign_address(ref, invoice),
         {:ok, invoice} <- assign_payment_uri(ref, invoice),
         :ok <- watch_invoice(ref, invoice) do
      {:ok, invoice}
    else
      err ->
        Logger.alert("Failed to register invoice: #{invoice.id}")
        err
    end
  end

  defp assign_address(ref, invoice), do: call(ref, :assign_address, [invoice])
  defp assign_payment_uri(ref, invoice), do: call(ref, :assign_payment_uri, [invoice])
  defp watch_invoice(ref, invoice), do: call(ref, :watch_invoice, [invoice])

  @spec update_address(backend_ref(), Invoice.t()) :: :ok | {:error, term}
  def update_address(ref, invoice), do: call(ref, :update_address, [invoice])

  @spec supported_currency(backend_ref()) :: {:ok, Currency.id()} | {:error, :not_found}
  def supported_currency(ref), do: call(ref, :supported_currency, [])

  @spec info(backend_ref()) :: {:ok, backend_info | nil} | {:error, term}
  def info(ref), do: call(ref, :info, [])

  @spec refresh_info(backend_ref()) :: :ok | {:error, term}
  def refresh_info(ref), do: call(ref, :refresh_info, [])

  @spec configure(backend_ref(), keyword()) :: :ok | {:error, term}
  def configure(ref, opts), do: call(ref, :configure, [opts])

  defp call({pid, backend}, fun, params) do
    try do
      apply(backend, fun, [pid | params])
    catch
      :exit, reason ->
        Logger.debug("Exit from backend call: #{inspect(reason)}")
        {:error, :not_found}
    end
  end

  @spec via_tuple(Currency.id()) :: {:via, Registry, any}
  def via_tuple(currency_id) do
    ProcessRegistry.via_tuple({__MODULE__, currency_id})
  end
end
