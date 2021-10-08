defmodule BitPalWeb.PageLiveTest do
  use BitPalWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirect home", %{conn: conn} do
    {:error, {:redirect, %{to: "/doc"}}} = live(conn, "/")
  end
end
