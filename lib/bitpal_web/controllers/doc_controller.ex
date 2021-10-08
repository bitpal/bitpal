defmodule BitPalWeb.DocController do
  use BitPalWeb, :controller

  alias BitPalDoc.Entries

  def index(conn, _params) do
    show(conn, %{"id" => "index"})
  end

  def show(conn, %{"id" => id}) do
    render(conn, "show.html", entry: Entries.get_entry_by_id!(id), entries: Entries.all_entries())
  end

  def toc(conn, _params) do
    render(conn, "toc.html", entries: Entries.all_entries())
  end
end
