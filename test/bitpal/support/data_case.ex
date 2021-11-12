defmodule BitPal.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BitPal.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  use BitPalFixtures

  using do
    quote do
      use BitPal.CaseHelpers
      alias BitPal.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import BitPal.DataCase

      alias BitPal.Addresses
      alias BitPal.Currencies
      alias BitPal.ExchangeRate
      alias BitPal.Invoices
      alias BitPal.Repo
      alias BitPal.Stores
      alias BitPal.Transactions

      import BitPalFactory
    end
  end

  setup tags do
    setup_db(tags)
    :ok
  end

  def setup_db(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(BitPal.Repo, shared: not tags[:async])

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)
  end
end
