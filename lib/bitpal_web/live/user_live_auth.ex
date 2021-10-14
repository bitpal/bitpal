defmodule BitPalWeb.UserLiveAuth do
  import Phoenix.LiveView
  alias BitPal.Accounts

  def mount(_params, %{"user_token" => user_token}, socket) do
    user = user_token && Accounts.get_user_by_session_token(user_token)

    if user do
      socket =
        assign_new(socket, :current_user, fn ->
          user
        end)

      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/users/log_in")}
    end
  end
end
