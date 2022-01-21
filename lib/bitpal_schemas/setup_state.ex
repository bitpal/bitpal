defmodule BitPalSchemas.SetupState do
  use TypedEctoSchema

  @type state :: :create_server_admin | :enable_backends | :create_store | :completed

  typed_schema "setup_state" do
    field(:state, Ecto.Enum,
      values: [:create_server_admin, :enable_backends, :create_store, :completed],
      default: :create_server_admin
    ) :: state
  end
end
