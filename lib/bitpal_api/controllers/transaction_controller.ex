defmodule BitPalApi.TransactionController do
  use BitPalApi, :controller

  def index(conn, _params) do
    render(conn, "index.json")
  end
end
