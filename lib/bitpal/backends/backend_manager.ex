defmodule BitPal.BackendManager do
  use GenServer
  alias BitPal.Backend
  alias BitPal.BackendEvents
  alias BitPal.BackendStatusSupervisor
  alias BitPal.ProcessRegistry
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSettings.BackendSettings
  alias Ecto.Adapters.SQL.Sandbox
  require Logger

  @type server_name :: atom | {:via, term, term} | pid
  @type backend_spec :: Supervisor.child_spec() | {module, term} | module
  @type backend_name :: atom

  def start_link(opts) do
    opts = Enum.into(opts, %{})
    name = Map.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  # Invoices

  @spec register_invoice(server_name, Invoice.t()) :: {:ok, Invoice.t()} | {:error, term}
  def register_invoice(server \\ __MODULE__, invoice) do
    case fetch_backend(server, invoice.payment_currency_id) do
      {:ok, ref} -> Backend.register_invoice(ref, invoice)
      error -> error
    end
  end

  @spec update_address(server_name, Invoice.t()) :: :ok | {:error, term}
  def update_address(server \\ __MODULE__, invoice) do
    case fetch_backend(server, invoice.payment_currency_id) do
      {:ok, ref} -> Backend.update_address(ref, invoice)
      error -> error
    end
  end

  # Backends

  @spec fetch_backend(server_name, Currency.id()) ::
          {:ok, Backend.backend_ref()}
          | {:error, :plugin_not_found}
          | {:error, :stopped}
          | {:error, :starting}
  def fetch_backend(server \\ __MODULE__, currency_id) do
    case ProcessRegistry.get_process_value(Backend.via_tuple(currency_id)) do
      {:ok, ref} ->
        {:ok, ref}

      {:error, :not_found} ->
        Enum.find_value(Supervisor.which_children(backend_supervisor(server)), fn
          {^currency_id, :undefined, _worker, _params} ->
            {:error, :stopped}

          {^currency_id, :restarting, _worker, _params} ->
            {:error, :starting}

          _ ->
            false
        end) || {:error, :plugin_not_found}
    end
  end

  @spec fetch_backend_module(server_name, Currency.id()) ::
          {:ok, module} | {:error, :plugin_not_found}
  def fetch_backend_module(server \\ __MODULE__, currency_id) do
    case ProcessRegistry.get_process_value(Backend.via_tuple(currency_id)) do
      {:ok, {_pid, module}} ->
        {:ok, module}

      {:error, :not_found} ->
        Enum.find_value(Supervisor.which_children(backend_supervisor(server)), fn
          {^currency_id, _status, _worker, [module | _rest]} ->
            {:ok, module}

          _ ->
            false
        end) || {:error, :plugin_not_found}
    end
  end

  @spec fetch_backend_pid(server_name, Currency.id()) ::
          {:ok, pid}
          | {:error, :plugin_not_found}
          | {:error, :stopped}
          | {:error, :starting}
  def fetch_backend_pid(server \\ __MODULE__, currency_id) do
    case fetch_backend(server, currency_id) do
      {:ok, {pid, _}} -> {:ok, pid}
      err -> err
    end
  end

  @spec restart_backend(server_name, Currency.id()) :: {:ok, pid} | {:error, term}
  def restart_backend(server \\ __MODULE__, currency_id) do
    case Supervisor.restart_child(backend_supervisor(server), currency_id) do
      {:ok, pid} ->
        monitor_backend(server, pid, currency_id)
        {:ok, pid}

      error ->
        error
    end
  end

  @spec stop_backend(server_name, Currency.id()) :: :ok | {:error, :not_found}
  def stop_backend(server \\ __MODULE__, currency_id) do
    Supervisor.terminate_child(backend_supervisor(server), currency_id)
  end

  @spec enable_backend(server_name, Currency.id()) :: :ok | {:error, term}
  def enable_backend(server \\ __MODULE__, currency_id) do
    BackendSettings.enable(currency_id)
    set_enabled(currency_id, true)
    restart_backend(server, currency_id)
  end

  @spec disable_backend(server_name, Currency.id()) :: :ok | {:error, :not_found}
  def disable_backend(server \\ __MODULE__, currency_id) do
    BackendSettings.disable(currency_id)
    set_enabled(currency_id, false)
    stop_backend(server, currency_id)
  end

  defp set_enabled(server \\ __MODULE__, currency_id, is_enabled) do
    BackendEvents.broadcast(
      {{:backend, :set_enabled}, %{currency_id: currency_id, is_enabled: is_enabled}}
    )

    GenServer.call(server, {:set_enabled, currency_id, is_enabled})
  end

  @spec add_or_update_backend(server_name, backend_spec | module, keyword) ::
          {:ok, Backend.backend_ref()} | {:error, term}
  def add_or_update_backend(server \\ __MODULE__, backend, opts)

  def add_or_update_backend(server, backend, opts) when is_atom(backend) do
    add_or_update_backend(server, {backend, []}, opts)
  end

  def add_or_update_backend(server, spec = {backend, backend_opts}, opts) do
    case Supervisor.start_child(backend_supervisor(server), spec) do
      {:error, {:already_started, pid}} when is_pid(pid) ->
        Backend.configure({pid, backend}, backend_opts)
        {:ok, {pid, backend}}

      {:ok, pid} when is_pid(pid) ->
        try do
          {:ok, currency_id} = backend.supported_currency(pid)

          GenServer.call(
            server,
            {:backend_added, pid, currency_id, Enum.into(opts, %{})}
          )

          {:ok, {pid, backend}}
        catch
          :exit, reason ->
            Logger.error("Failed to add backend #{inspect(reason)}")
            {:error, reason}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  @spec remove_currency_backends(server_name, [Currency.id()]) :: :ok
  def remove_currency_backends(server \\ __MODULE__, currencies) when is_list(currencies) do
    Enum.each(currencies, fn id ->
      remove_backend(server, id)
    end)
  end

  @spec remove_backends(server_name) :: :ok
  def remove_backends(server \\ __MODULE__) do
    Enum.each(currencies(server), fn {id, _} ->
      remove_backend(server, id)
    end)
  end

  defp remove_backend(server, currency_id) do
    supervisor = backend_supervisor(server)

    # Manually stop the GenServer before removal to avoid Repo sandbox errors during testing.
    # They're not critical, but in some rare cases they may cause cascading test errors
    # which is super annoying to debug.
    # This shouldn't be necessary in general when stopping a backend outside that particular
    # case I don't think.
    case fetch_backend_pid(server, currency_id) do
      {:ok, pid} ->
        try do
          GenServer.stop(pid)
        catch
          :exit, err ->
            Logger.debug("Error when stopping backend: #{inspect(err)}")
        end

      _ ->
        nil
    end

    Supervisor.terminate_child(supervisor, currency_id)
    Supervisor.delete_child(supervisor, currency_id)
  end

  # Supervised backends

  @spec backends(server_name) :: [{backend_name(), Backend.backend_ref()}]
  def backends(server \\ __MODULE__) do
    Supervisor.which_children(backend_supervisor(server))
    |> Enum.map(fn {name, pid, _worker, [backend]} ->
      {name, {pid, backend}}
    end)
  end

  @spec currencies(server_name) :: [{Currency.id(), Backend.backend_ref()}]
  def currencies(server \\ __MODULE__) do
    backends(server)
    |> Enum.flat_map(fn {_name, ref} ->
      case Backend.supported_currency(ref) do
        {:ok, currency_id} -> [{currency_id, ref}]
        _ -> []
      end
    end)
  end

  @spec currency_list(server_name) :: [Currency.id()]
  def currency_list(server \\ __MODULE__) do
    currencies(server)
    |> Enum.reduce([], fn {currency, _}, acc -> [currency | acc] end)
    |> Enum.sort()
  end

  @spec status_list(server_name) :: [
          {Currency.id(), Backend.backend_ref(), Backend.backend_status()}
        ]
  def status_list(server \\ __MODULE__) do
    Supervisor.which_children(backend_supervisor(server))
    |> Enum.map(fn
      {currency_id, :undefined, _worker, [backend]} ->
        {currency_id, {:undefined, backend}, :stopped}

      {currency_id, :restarting, _worker, [backend]} ->
        {currency_id, {:restarting, backend}, :starting}

      {currency_id, pid, _worker, [backend]} ->
        {currency_id, {pid, backend}, BackendStatusSupervisor.get_status(currency_id)}
    end)
  end

  # Status

  @doc """
  Fetch the backend status. Always succeeds.
  """
  @spec status(server_name, Currency.id()) :: Backend.backend_status()
  def status(server \\ __MODULE__, currency_id) do
    case fetch_backend(server, currency_id) do
      {:ok, _backend} ->
        BackendStatusSupervisor.get_status(currency_id)

      # Should check status supervisor here again, as sometimes
      # the backend has stopped/crashed and can't be found by the supervisor
      # but the status handler holds the stopped error status.
      {:error, :plugin_not_found} ->
        case BackendStatusSupervisor.get_status(currency_id) do
          :unknown -> :plugin_not_found
          status -> status
        end

      {:error, status} ->
        status
    end
  end

  @spec is_ready(Currency.id()) :: boolean
  def is_ready(currency_id) do
    :ready == BackendStatusSupervisor.get_status(currency_id)
  end

  # Configuration

  @spec config_change(server_name, keyword, keyword, keyword) :: :ok
  def config_change(name \\ __MODULE__, changed, _new, _removed) do
    config_change(name, changed)
  end

  @spec config_change(server_name, keyword) :: :ok
  def config_change(name \\ __MODULE__, changed) do
    if backends = Keyword.get(changed, :backends), do: update_backends(name, backends)
  end

  @spec update_backends(server_name, backend_spec) :: :ok
  defp update_backends(server, backends) do
    to_keep =
      backends
      |> Enum.flat_map(fn backend ->
        case add_or_update_backend(server, backend, []) do
          {:ok, ref} -> [ref]
          {:error, _} -> []
        end
      end)
      |> Enum.reduce(MapSet.new(), fn {pid, _}, acc -> MapSet.put(acc, pid) end)

    supervisor = backend_supervisor(server)

    Supervisor.which_children(supervisor)
    |> Enum.each(fn {child_id, pid, _, _} ->
      if !MapSet.member?(to_keep, pid) do
        remove_backend(server, child_id)
      end
    end)
  end

  # Testing

  def add_extra_backend_opts(backends, opts) when is_list(backends) do
    Enum.map(backends, fn backend -> add_extra_backend_opts(backend, opts) end)
  end

  def add_extra_backend_opts(backend, opts) when is_atom(backend) do
    {backend, opts}
  end

  def add_extra_backend_opts({backend, existing_opts}, new_opts)
      when is_atom(backend) and is_list(existing_opts) and is_list(new_opts) do
    {backend, existing_opts ++ new_opts}
  end

  # Genserver interface

  def backend_supervisor(server \\ __MODULE__) do
    GenServer.call(server, :backend_supervisor)
  end

  def monitor_backend(server \\ __MODULE__, backend, currency_id) when is_pid(backend) do
    GenServer.call(server, {:monitor_backend, backend, currency_id})
  end

  @impl true
  def handle_call(:backend_supervisor, _from, state) do
    {:reply, state.backend_supervisor, state}
  end

  @impl true
  def handle_call({:backend_added, pid, currency_id, opts}, _from, state) do
    {:reply, :ok, backend_added(pid, currency_id, state, opts)}
  end

  @impl true
  def handle_call({:monitor_backend, pid, currency_id}, _from, state) do
    {:reply, :ok, monitor(pid, currency_id, state)}
  end

  @impl true
  def handle_call({:set_enabled, currency_id, is_enabled}, _from, state) do
    {:reply, :ok, store_enabled(state, currency_id, is_enabled)}
  end

  @impl true
  def handle_info({:restart_backend_if_enabled, currency_id}, state) do
    # Note that in tests this might crash if the test process has already finished.
    if is_enabled(currency_id, state) do
      case Supervisor.restart_child(state.backend_supervisor, currency_id) do
        {:ok, pid} ->
          {:noreply, monitor(pid, currency_id, state)}

        err ->
          Logger.debug("Error when restarting backend: #{inspect(err)}")
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :normal}, state) do
    # The backend got shut down by itself normally.
    # No restart needed.
    {:noreply, handle_down(state, ref, :normal)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, :shutdown}, state) do
    # The backend got shut down, either stopped by the manager or by itself.
    # No restart needed.
    {:noreply, handle_down(state, ref, :shutdown)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason = {:shutdown, _}}, state) do
    # Controlled shut down due to some error after init is successful, probably a connection error.
    # Because it's some connection error, we'll reconnect after a timeout.
    {:noreply, handle_down(state, ref, reason, delayed_restart: true, log_error: true)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason = {:error, _error}}, state) do
    # We crashed but handled it manually. The supervisor will restart directly.
    {:noreply, handle_down(state, ref, reason, delayed_restart: true, log_error: true)}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    # An unhandled crash, the supervisor will restart it directly.
    Logger.error("unhandled backend crash: #{inspect(reason)}")

    error_reason = if is_atom(reason), do: reason, else: :unknown

    {:noreply,
     handle_down(state, ref, {:error, error_reason}, delayed_restart: true, log_error: true)}
  end

  @impl true
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.error("unhandled backend EXIT: #{inspect(reason)}")
    {:noreply, state}
  end

  defp handle_down(state, ref, reason, opts \\ []) do
    currency_id = monitored_currency_id(ref, state)

    if opts[:log_error] do
      Logger.critical("Backend for #{currency_id} crashed with code #{inspect(reason)}")
    end

    if currency_id != :unknown do
      BackendStatusSupervisor.set_down(currency_id, reason)

      if opts[:delayed_restart] do
        Process.send_after(
          self(),
          {:restart_backend_if_enabled, currency_id},
          BackendSettings.restart_timeout()
        )
      end
    end

    Map.delete(state, ref)
  end

  defp monitored_currency_id(ref, state) do
    state[ref] || :unknown
  end

  @impl true
  def init(opts) do
    {:ok, opts, {:continue, :init}}
  end

  @impl true
  def handle_continue(:init, opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    if log_level = opts[:log_level] do
      Logger.put_process_level(self(), log_level)
    end

    backends = Map.get(opts, :backends, BackendSettings.backends())

    {:ok, backend_supervisor} =
      Supervisor.start_link(backends, strategy: :one_for_one, max_restarts: 50, max_seconds: 5)

    state = %{backend_supervisor: backend_supervisor}

    added_opts =
      case Map.get(opts, :init_enabled, :not_found) do
        :not_found ->
          %{}

        enabled ->
          %{enabled: enabled}
      end

    state =
      Supervisor.which_children(backend_supervisor)
      |> Enum.reduce(
        state,
        fn
          {currency_id, pid, _, _}, acc when is_pid(pid) ->
            backend_added(pid, currency_id, acc, added_opts)

          _, acc ->
            acc
        end
      )

    {:noreply, state}
  end

  defp backend_added(pid, currency_id, state, %{enabled: is_enabled}) when is_pid(pid) do
    backend_added(pid, currency_id, store_enabled(state, currency_id, is_enabled))
  end

  defp backend_added(pid, currency_id, state, _) when is_pid(pid) do
    backend_added(pid, currency_id, state)
  end

  defp backend_added(pid, currency_id, state) when is_pid(pid) do
    if is_enabled(currency_id, state) do
      monitor(pid, currency_id, state)
    else
      # Hack to prevent a disabled backend from starting, by starting it and killing it!
      # Maybe there's another way of adding a child_spec to a supervisor without starting it?
      :ok = Supervisor.terminate_child(state.backend_supervisor, currency_id)
      state
    end
  end

  defp is_enabled(currency_id, %{enabled_state: enabled_state}) do
    # Avoid db accesses if possible, to allow a single manager to drive most tests.
    Map.get_lazy(enabled_state, currency_id, fn -> BackendSettings.is_enabled(currency_id) end)
  end

  defp is_enabled(currency_id, _state) do
    BackendSettings.is_enabled(currency_id)
  end

  defp store_enabled(state = %{enabled_state: _}, currency_id, is_enabled) do
    put_in(state, [:enabled_state, currency_id], is_enabled)
  end

  defp store_enabled(state, currency_id, is_enabled) do
    Map.put(state, :enabled_state, %{currency_id => is_enabled})
  end

  defp monitor(pid, currency_id, state) when is_pid(pid) do
    Map.put(state, Process.monitor(pid), currency_id)
  end
end
