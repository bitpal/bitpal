defmodule BitPalWeb.UserLiveAuth do
  import Phoenix.LiveView
  alias BitPal.Accounts

  def on_mount(:default, _params, %{"user_token" => user_token}, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      with_user_token(user_token, socket)
    end
  end

  defp with_user_token(user_token, socket) do
    user = user_token && Accounts.get_user_by_session_token(user_token)

    if user do
      {:cont, assign(socket, :current_user, user)}
    else
      {:halt, redirect(socket, to: "/users/log_in")}
    end
  end
end
