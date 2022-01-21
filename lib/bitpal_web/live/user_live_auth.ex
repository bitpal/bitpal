defmodule BitPalWeb.UserLiveAuth do
  import Phoenix.LiveView
  alias BitPal.Accounts
  alias BitPal.ServerSetup

  def on_mount(:default, _params, %{"user_token" => user_token}, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      with_user_token(user_token, socket)
    end
  end

  def on_mount(:allow_create_admin_state, _params, session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      state = ServerSetup.setup_state()
      socket = assign(socket, state: state)

      if state == :create_admin && !Accounts.any_user() do
        {:cont, socket}
      else
        with_user_token(session["user_token"], socket)
      end
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
