defmodule BitPalWeb.ServerSetupTest do
  use BitPalWeb.ConnCase, async: false
  import BitPalWeb.ServerSetup
  alias BitPalWeb.UserAuth

  describe "routing setup not completed" do
    test "protected routes", %{conn: conn} do
      protected_routes = [
        "/",
        "/dashboard",
        "/users/register",
        "/server/setup/info"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/server/setup/register_admin"
      end
    end

    test "allowed routes", %{conn: conn} do
      allowed_routes = [
        "/doc",
        "/server/setup/register_admin"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end
  end

  describe "routing setup completed" do
    setup tags do
      Map.put(tags, :user, complete_server_setup())
    end

    test "protected routes", %{conn: conn} do
      protected_routes = [
        "/server/setup/register_admin"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/server/setup/info"
      end
    end

    test "allowed routes", %{conn: conn} do
      allowed_routes = [
        "/doc",
        "/server/setup/info"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end

    test "allowed routes when logged in", %{conn: conn, user: user} do
      conn = log_in_user(conn, user)

      allowed_routes = [
        "/",
        "/dashboard",
        "/server/setup/info"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end
  end
end
