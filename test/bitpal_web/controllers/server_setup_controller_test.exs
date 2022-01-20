defmodule BitPalWeb.ServerSetupControllerTest do
  use BitPalWeb.ConnCase, async: false

  describe "GET register_admin" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, Routes.server_setup_path(conn, :register_admin))
      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
    end
  end

  describe "POST create_admin" do
    test "creates account and logs the user in", %{conn: conn} do
      email = unique_user_email()

      conn =
        post(conn, Routes.server_setup_path(conn, :create_admin), %{
          "user" => valid_user_attributes(email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == Routes.server_setup_path(conn, :info)

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, Routes.server_setup_path(conn, :create_admin), %{
          "user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Register</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end

  describe "GET info" do
    test "renders info", %{conn: conn} do
      complete_server_setup()

      conn = get(conn, Routes.server_setup_path(conn, :info))
      response = html_response(conn, 200)
      assert response =~ "Setup completed"
    end
  end
end
