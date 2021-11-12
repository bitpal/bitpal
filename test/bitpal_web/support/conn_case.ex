defmodule BitPalWeb.ConnCase do
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
  by setting `use BitPalWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use BitPalFixtures
  import Phoenix.LiveViewTest
  import BitPal.TestHelpers
  alias BitPal.Accounts
  alias BitPal.DataCase
  alias BitPal.IntegrationCase
  alias BitPal.HandlerSubscriberCollector

  defmacro __using__(params) do
    quote do
      use ExUnit.Case, unquote(params)
      use BitPal.CaseHelpers

      import BitPalWeb.ConnCase
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import Plug.Conn

      alias BitPalWeb.Router.Helpers, as: Routes
      alias BitPal.HandlerSubscriberCollector

      # The default endpoint for testing
      @endpoint BitPalWeb.Endpoint

      @integration Keyword.get(unquote(params), :integration)

      setup tags do
        res =
          if @integration do
            IntegrationCase.setup_integration(tags)
          else
            DataCase.setup_db(tags)
            %{}
          end
          |> Map.put(:conn, Phoenix.ConnTest.build_conn())

        {:ok, res}
      end
    end
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(tags = %{conn: conn}) do
    password = BitPalFactory.valid_user_password()
    user = BitPalFactory.insert(:user, password: password)
    Map.merge(tags, %{conn: log_in_user(conn, user), user: user, password: password})
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  # FIXME remove
  def create_store(tags = %{user: user}, attrs \\ %{}) do
    Enum.into(tags, %{
      store: insert(:store, attrs) |> assoc_user(user),
      label: "My 'ss'&"
    })
  end

  # FIXME remove
  def create_open_invoice(tags = %{store: store, currency_id: currency_id}, attrs \\ %{}) do
    {:ok, invoice, _stub, _handler} =
      HandlerSubscriberCollector.create_invoice(
        Enum.into(attrs, %{
          store_id: store.id,
          currency_id: currency_id
        })
      )

    Enum.into(tags, %{
      invoice: invoice
    })
  end

  def render_eventually(view, match) do
    eventually(fn -> render(view) =~ match end)
  end
end
