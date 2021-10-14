defmodule BitPalWeb.StoreSettingsController do
  use BitPalWeb, :controller

  def show(conn, _params) do
    render(conn, "show.html")
  end
end
