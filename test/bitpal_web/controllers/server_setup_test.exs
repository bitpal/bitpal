defmodule BitPalWeb.ServerSetupTest do
  use BitPalWeb.ConnCase, async: true

  setup tags = %{conn: conn} do
    if tags[:login] do
      admin = create_user()
      Map.merge(tags, %{admin: admin, conn: log_in_user(conn, admin)})
    else
      tags
    end
  end

  describe "routing setup nothing done" do
    @tag server_setup_state: :create_server_admin
    test "protected routes", %{conn: conn} do
      protected_routes = [
        ~p"/",
        ~p"/server/dashboard",
        ~p"/users/register",
        ~p"/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == ~p"/server/setup/server_admin"
      end
    end

    @tag server_setup_state: :create_server_admin
    test "allowed routes", %{conn: conn} do
      allowed_routes = [
        ~p"/doc",
        ~p"/server/setup/server_admin"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end
  end

  describe "routing server admin created but setup not completed" do
    @tag server_setup_state: :enable_backends
    test "protected routes when not logged in", %{conn: conn} do
      protected_routes = [
        ~p"/",
        ~p"/server/dashboard",
        ~p"/users/register",
        ~p"/server/setup/server_admin",
        ~p"/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/users/log_in"
      end
    end

    @tag server_setup_state: :enable_backends
    test "allowed routes when not logged in", %{conn: conn} do
      allowed_routes = [
        ~p"/users/log_in",
        ~p"/doc"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end

    @tag server_setup_state: :enable_backends, login: true
    test "protected routes when logged in", %{conn: conn} do
      protected_routes = [
        ~p"/",
        ~p"/server/dashboard",
        ~p"/users/log_in",
        ~p"/users/register",
        ~p"/server/setup/server_admin"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == ~p"/server/setup/wizard"
      end
    end

    @tag server_setup_state: :enable_backends, login: true
    test "allowed routes when logged in", %{conn: conn} do
      allowed_routes = [
        ~p"/doc",
        ~p"/server/setup/wizard"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted
      end
    end
  end

  describe "routing setup completed" do
    @tag server_setup_state: :completed
    test "protected routes when not logged in", %{conn: conn} do
      protected_routes = [
        ~p"/",
        ~p"/server/dashboard",
        ~p"/server/setup/server_admin",
        ~p"/server/setup/wizard"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == "/users/log_in"
      end
    end

    @tag server_setup_state: :completed
    @tag do: true
    test "allowed routes when not logged in", %{conn: conn} do
      allowed_routes = [
        ~p"/users/log_in",
        ~p"/doc"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end

    @tag server_setup_state: :completed, login: true
    test "protected routes when logged in", %{conn: conn} do
      protected_routes = [
        ~p"/server/setup/server_admin"
      ]

      for route <- protected_routes do
        conn = get(conn, route)
        assert redirected_to(conn) == ~p"/server/setup/wizard"
      end
    end

    @tag server_setup_state: :completed, login: true
    test "allowed routes when logged in", %{conn: conn} do
      allowed_routes = [
        ~p"/",
        ~p"/server/setup/wizard"
      ]

      for route <- allowed_routes do
        conn = get(conn, route)
        refute conn.halted, "halted #{route}"
      end
    end
  end
end
