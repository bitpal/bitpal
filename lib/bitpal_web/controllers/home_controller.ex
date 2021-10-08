defmodule BitPalWeb.HomeController do
  use BitPalWeb, :controller

  def index(conn, _params) do
    conn
    |> redirect(to: "/doc")
  end
end
