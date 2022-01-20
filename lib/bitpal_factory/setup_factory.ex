defmodule BitPalFactory.SetupFactory do
  alias BitPalSchemas.User
  alias BitPalFactory.AccountFactory

  @spec complete_server_setup :: User.t()
  def complete_server_setup() do
    AccountFactory.create_user()
  end
end
