defmodule BitPalWeb.StoreLiveAuth do
  import Phoenix.LiveView
  alias BitPal.Accounts.Users

  def mount(%{"id" => store_id}, _session, socket) do
    if socket.assigns[:store] do
      {:cont, socket}
    else
      case Users.fetch_store(socket.assigns.current_user, store_id) do
        {:ok, store} -> {:cont, assign(socket, store: store)}
        _ -> {:halt, redirect(socket, to: "/")}
      end
    end
  end
end
