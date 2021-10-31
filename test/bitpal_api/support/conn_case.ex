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
  use BitPalFixtures
  import Plug.BasicAuth
  import Plug.Conn
  import Phoenix.ConnTest
  alias BitPal.IntegrationCase

  using do
    quote do
      use BitPalFixtures
      import Plug.Conn
      import Phoenix.ConnTest
      import BitPalApi.ConnCase
      import BitPal.TestHelpers
      import BitPal.ConnTestHelpers
      alias BitPalApi.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint BitPalApi.Endpoint
    end
  end

  setup tags do
    res = IntegrationCase.setup_integration(tags)

    conn =
      build_conn()
      |> auth(tags)

    {:ok, Map.put(res, :conn, conn)}
  end

  defp auth(conn, %{auth: false}), do: conn

  defp auth(conn, %{token: token}) do
    put_auth(conn, token)
  end

  defp auth(conn, _tags) do
    %{store_id: _store_id, token: token} = AuthFixtures.auth_fixture()
    put_auth(conn, token)
  end

  defp put_auth(conn, token) do
    put_req_header(conn, "authorization", encode_basic_auth(token, ""))
  end
end
