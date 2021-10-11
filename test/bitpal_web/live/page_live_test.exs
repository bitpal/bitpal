defmodule BitPalWeb.PageLiveTest do
  use BitPalWeb.ConnCase

  import Phoenix.LiveViewTest

  test "home redirection", %{conn: conn} do
    {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, "/")
  end
end
