defmodule BitPal.TestHelpers do
  import ExUnit.Assertions
  alias BitPal.Authentication
  alias BitPal.Stores
  alias BitPalSchemas.Store
  alias Ecto.UUID

  # Creation helpers

  def generate_txid do
    "txid:#{UUID.generate()}"
  end

  def generate_address_id do
    "address:#{UUID.generate()}"
  end

  @spec create_store :: Store.t()
  def create_store do
    Stores.create!()
  end

  def create_auth do
    store = create_store()
    token = Authentication.create_token!(store).data

    %{
      store_id: store.id,
      token: token
    }
  end

  # Test helpers

  def eventually(func) do
    if func.() do
      true
    else
      Process.sleep(10)
      eventually(func)
    end
  end

  def assert_shutdown(pid) do
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
