defmodule BitPal.BackendStatusSupervisor do
  use DynamicSupervisor
  alias BitPal.Backend
  alias BitPal.BackendStatusHandler
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  require Logger

  @spec get_status(Currency.id()) :: Backend.backend_status()
  def get_status(currency_id) do
    # Note that stopped is managed by BackendManager,
    # so calls should go via BackendManager instead.
    case fetch_status_handler(currency_id) do
      {:ok, handler} ->
        BackendStatusHandler.status(handler)

      _ ->
        # This might happen if the backend is started but hasn't registered it's status yet.
        :unknown
    end
  end

  @spec set_starting(Currency.id()) :: :ok
  def set_starting(currency_id) do
    set_status(currency_id, :starting)
  end

  @spec set_ready(Currency.id()) :: :ok
  def set_ready(currency_id) do
    set_status(currency_id, :ready)
  end

  @spec set_recovering(Currency.id(), {non_neg_integer, non_neg_integer}) :: :ok
  def set_recovering(currency_id, {processed_height, target_height}) do
    set_status(
      currency_id,
      {:recovering, {processed_height, target_height}}
    )
  end

  @spec set_syncing(Currency.id(), float | {non_neg_integer, non_neg_integer}) :: :ok
  def set_syncing(currency_id, sync_status) do
    set_status(currency_id, {:syncing, sync_status})
  end

  @spec set_stopped(Currency.id(), Backend.stopped_reason()) :: :ok
  def set_stopped(currency_id, reason) do
    set_status(currency_id, {:stopped, reason})
  end

  @spec set_status(Currency.id(), Backend.backend_status()) :: :ok
  def set_status(currency_id, new_status) do
    # Note that stopped is managed by BackendManager
    get_or_create_status_handler(currency_id)
    |> BackendStatusHandler.set_status(new_status)
  end

  @spec set_down(Currency.id(), Backend.stopped_reason()) :: :ok | {:error, :not_found}
  def set_down(currency_id, reason) do
    try do
      case fetch_status_handler(currency_id) do
        {:ok, handler} ->
          BackendStatusHandler.set_status(handler, {:stopped, reason})

        _ ->
          nil
      end
    catch
      # There might be a race condition when closing status handlers during tests.
      :exit, _reason ->
        {:error, :not_found}
    end
  end

  @spec sync_done(Currency.id()) :: :ok
  def sync_done(currency_id) do
    get_or_create_status_handler(currency_id)
    |> BackendStatusHandler.sync_done()
  end

  @spec configure_status_handler(Currency.id(), map) :: :ok
  def configure_status_handler(currency_id, opts) do
    get_or_create_status_handler(currency_id)
    |> BackendStatusHandler.configure(opts)
  end

  @spec allow_parent(Currency.id(), pid) :: :ok
  def allow_parent(currency_id, parent) do
    get_or_create_status_handler(currency_id)
    |> BackendStatusHandler.allow_parent(parent)
  end

  def remove_status_handlers(currencies) do
    for currency_id <- currencies do
      case fetch_status_handler(currency_id) do
        {:ok, handler} ->
          GenServer.stop(handler)
          DynamicSupervisor.terminate_child(__MODULE__, handler)

        _ ->
          nil
      end
    end
  end

  defp fetch_status_handler(currency_id) do
    ProcessRegistry.get_process(BackendStatusHandler.via_tuple(currency_id))
  end

  defp get_or_create_status_handler(currency_id) do
    case ProcessRegistry.get_process(BackendStatusHandler.via_tuple(currency_id)) do
      {:ok, pid} ->
        pid

      {:error, :not_found} ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            __MODULE__,
            {BackendStatusHandler, currency_id: currency_id}
          )

        pid
    end
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
