defmodule BitPal.ServerSetup do
  import Ecto.Changeset
  alias BitPal.Repo
  alias BitPalSchemas.SetupState

  @spec setup_state :: SetupState.state()
  def setup_state do
    if state = Repo.one(SetupState) do
      state.state
    else
      :create_server_admin
    end
  end

  @spec setup_completed? :: boolean
  def setup_completed? do
    setup_state() == :completed
  end

  @spec set_setup_state(SetupState.state()) :: SetupState.state()
  def set_setup_state(state) do
    # We should only have one state at a time
    res =
      case Repo.one(SetupState) do
        nil -> %SetupState{}
        state -> state
      end
      |> change(state: state)
      |> Repo.insert_or_update!()

    res.state
  end

  @spec next_state :: SetupState.state()
  def next_state do
    case setup_state() do
      :create_server_admin -> :enable_backends
      :enable_backends -> :create_store
      :create_store -> :completed
      :completed -> :completed
    end
    |> set_setup_state()
  end
end
