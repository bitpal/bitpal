defmodule BitPalApi.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BitPalApi.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  import Plug.BasicAuth
  import Plug.Conn
  import Phoenix.ConnTest
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BitPalApi.ConnCase

      alias BitPalApi.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BitPalApi.Endpoint
    end
  end

  setup tags do
    start_supervised(BitPal.Repo)
    :ok = Sandbox.checkout(BitPal.Repo)

    unless tags[:async] do
      Sandbox.mode(BitPal.Repo, {:shared, self()})
    end

    start_supervised!(BitPalApi.Endpoint)
    BitPal.Currencies.register!([:XMR, :BCH, :DGC])

    conn =
      build_conn()
      |> auth(tags)

    {:ok, conn: conn}
  end

  defp auth(conn, %{auth: false}), do: conn

  defp auth(conn, tags) do
    put_req_header(
      conn,
      "authorization",
      encode_basic_auth(tags[:user] || "user", tags[:pass] || "")
    )
  end
end
