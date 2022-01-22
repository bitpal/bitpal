defmodule BitPalFactory.SetupFactory do
  alias BitPal.Repo
  alias BitPal.ServerSetup
  alias BitPalFactory.AccountFactory
  alias BitPalSchemas.SetupState
  alias BitPalSchemas.User

  @spec complete_server_setup :: User.t()
  def complete_server_setup do
    server_setup_state(:completed)
  end

  @spec register_server_admin :: User.t()
  def register_server_admin do
    server_setup_state(:enable_backends)
  end

  @spec server_setup_state(SetupState.state()) :: User.t() | nil
  def server_setup_state(state) do
    ServerSetup.set_setup_state(state)

    case state do
      :create_server_admin ->
        nil

      _ ->
        if user = Repo.one(User) do
          user
        else
          AccountFactory.create_user()
        end
    end
  end
end
