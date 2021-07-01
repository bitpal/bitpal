defmodule BitPalApi.TransactionView do
  use BitPalApi, :view

  def render("index.json", _) do
    %{id: "1315"}
  end
end
