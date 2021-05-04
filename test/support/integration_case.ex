defmodule BitPal.IntegrationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  to the application's backend services, such as currency
  backends or database.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import BitPal.IntegrationCase

      alias BitPal.BackendManager
      alias BitPal.BackendMock
      alias BitPal.InvoiceManager
      alias BitPal.Invoices
      alias BitPal.Repo
      alias BitPal.Transactions
      alias BitPalSchemas.Invoice
    end
  end

  setup tags do
    start_supervised!({Phoenix.PubSub, name: BitPal.PubSub})
    start_supervised!(BitPal.ProcessRegistry)

    setup_db(tags)

    if tags[:backends] do
      setup_backends(tags)
    end

    :ok
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

  defp setup_db(tags) do
    start_supervised!(BitPal.Repo)
    :ok = Sandbox.checkout(BitPal.Repo)

    unless tags[:async] do
      Sandbox.mode(BitPal.Repo, {:shared, self()})
    end
  end

  defp setup_backends(tags) do
    # Only start backend if explicitly told to
    backend_manager =
      if backends = backends(tags) do
        start_supervised!({BitPal.BackendManager, backends: backends})
      end

    invoice_manager =
      start_supervised!(
        {BitPal.InvoiceManager, double_spend_timeout: Map.get(tags, :double_spend_timeout, 100)}
      )

    transactions = start_supervised!(BitPal.Transactions)

    %{
      backend_manager: backend_manager,
      invoice_manager: invoice_manager,
      transactions: transactions
    }
  end

  defp backends(%{backends: true}), do: [BitPal.BackendMock]
  defp backends(%{backends: backends}), do: backends
  defp backends(_), do: nil
end
