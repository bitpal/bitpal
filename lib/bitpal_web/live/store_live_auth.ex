defmodule BitPalWeb.StoreLiveAuth do
  use BitPalWeb, :live_auth
  alias BitPal.Accounts.Users

  def on_mount(:default, %{"store" => store_slug}, _session, socket) do
    if socket.assigns[:store] do
      {:cont, socket}
    else
      case Users.fetch_store(socket.assigns.current_user, store_slug) do
        {:ok, store} -> {:cont, assign(socket, store: store)}
        _ -> {:halt, redirect(socket, to: "/")}
      end
    end
  end
end
