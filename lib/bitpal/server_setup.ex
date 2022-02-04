defmodule BitPal.ServerSetup do
  use GenServer
  import Ecto.Changeset
  alias BitPal.Accounts
  alias BitPal.Repo
  alias BitPalSchemas.SetupState
  alias Ecto.Adapters.SQL.Sandbox

  def start_link(opts \\ []) do
    name = opts[:name] || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec current_state(module) :: SetupState.state()
  def current_state(name \\ __MODULE__) do
    GenServer.call(name, :current_state)
  end

  @spec completed?(module) :: boolean
  def completed?(name \\ __MODULE__) do
    current_state(name) == :completed
  end

  @spec server_admin_created?(module) :: boolean
  def server_admin_created?(name \\ __MODULE__) do
    # Check current state first to avoid db access if possible.
    case current_state(name) do
      :create_server_admin -> Accounts.any_user()
      _ -> true
    end
  end

  @spec set_state(module, SetupState.state()) :: SetupState.state()
  def set_state(name \\ __MODULE__, state) do
    GenServer.call(name, {:set_state, state})
  end

  @spec set_next(module) :: SetupState.state()
  def set_next(name \\ __MODULE__) do
    GenServer.call(name, :set_next)
  end

  @impl true
  def init(opts) do
    if parent = opts[:parent] do
      Sandbox.allow(BitPal.Repo, parent, self())
    end

    # State and id can be overridden for tests.
    {:ok, %{state: opts[:state] || load_state(), id: opts[:id] || 0}}
  end

  @impl true
  def handle_call(:current_state, _from, data = %{state: state}) do
    {:reply, state, data}
  end

  @impl true
  def handle_call({:set_state, next_state}, _from, data = %{id: id}) do
    store_state(id, next_state)
    {:reply, next_state, %{data | state: next_state}}
  end

  @impl true
  def handle_call(:set_next, _from, data = %{id: id, state: state}) do
    next = next_state(state)
    store_state(id, next)
    {:reply, next, %{data | state: next}}
  end

  defp load_state do
    if state = Repo.one(SetupState) do
      state.state
    else
      :create_server_admin
    end
  end

  def store_state(id, state) do
    case Repo.get(SetupState, id) do
      nil -> %SetupState{id: id}
      state -> state
    end
    |> change(state: state)
    |> Repo.insert_or_update!()
  end

  defp next_state(current_state) do
    case current_state do
      :create_server_admin -> :enable_backends
      :enable_backends -> :create_store
      :create_store -> :completed
      :completed -> :completed
    end
  end
end
