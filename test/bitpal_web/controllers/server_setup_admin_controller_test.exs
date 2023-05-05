defmodule BitPalWeb.ServerSetupAdminControllerTest do
  use BitPalWeb.ConnCase, async: true
  import Mox

  setup :verify_on_exit!

  describe "GET new" do
    @tag server_setup_state: :create_server_admin
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/server/setup/server_admin")
      response = html_response(conn, 200)
      assert response =~ "Create server admin"
    end
  end

  describe "POST create" do
    @tag server_setup_state: :create_server_admin
    test "creates admin and logs the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, ~p"/server/setup/server_admin", %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/server/setup/wizard"
    end

    @tag server_setup_state: :create_server_admin
    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/server/setup/server_admin", %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Create server admin"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
