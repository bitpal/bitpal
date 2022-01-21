defmodule BitPalWeb.ServerSetupTest do
  use BitPalWeb.ConnCase, async: false
  import BitPalWeb.ServerSetup
  alias BitPalWeb.UserAuth

  setup tags = %{conn: conn} do
    if state = tags[:state] do
      admin = server_setup_state(state)

      tags =
        if tags[:login] do
          %{tags | conn: log_in_user(conn, admin)}
        else
          tags
        end

      Map.put(tags, :admin, admin)
    else
      tags
    end
  end

  describe "routing setup nothing done" do
    test "protected routes", %{conn: conn} do
      protected_routes = [
        "/",
        "/server/dashboard",
        "/users/register",
        "/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/server/setup/server_admin"
      end
    end

    test "allowed routes", %{conn: conn} do
      allowed_routes = [
        "/doc",
        "/server/setup/server_admin"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end
  end

  describe "routing server admin created but setup not completed" do
    @tag state: :enable_backends
    test "protected routes when not logged in", %{conn: conn} do
      protected_routes = [
        "/",
        "/server/dashboard",
        "/users/register",
        "/server/setup/server_admin",
        "/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/users/log_in"
      end
    end

    @tag state: :enable_backends
    test "allowed routes when not logged in", %{conn: conn} do
      allowed_routes = [
        "/users/log_in",
        "/doc"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end

    @tag state: :enable_backends, login: true
    test "protected routes when logged in", %{conn: conn} do
      protected_routes = [
        "/",
        "/server/dashboard",
        "/users/log_in",
        "/users/register",
        "/server/setup/server_admin"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/server/setup/wizard"
      end
    end

    @tag state: :enable_backends, login: true
    test "allowed routes when logged in", %{conn: conn} do
      allowed_routes = [
        "/doc",
        "/server/setup/wizard"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end
  end

  describe "routing setup completed" do
    @tag state: :completed
    test "protected routes when not logged in", %{conn: conn} do
      protected_routes = [
        "/",
        "/server/dashboard",
        "/server/setup/server_admin",
        "/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/users/log_in"
      end
    end

    @tag state: :completed
    test "allowed routes when not logged in", %{conn: conn} do
      allowed_routes = [
        "/users/log_in",
        "/doc"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end

    @tag state: :completed, login: true
    test "protected routes when logged in", %{conn: conn} do
      protected_routes = [
        "/server/setup/server_admin"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/server/setup/wizard"
      end
    end

    @tag state: :completed, login: true
    test "allowed routes when logged in", %{conn: conn} do
      allowed_routes = [
        "/",
        "/server/setup/wizard"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end
  end
end
