defmodule BitPalWeb.ServerSetupAdminController do
  use BitPalWeb, :controller

  alias BitPal.Accounts
  alias BitPalSchemas.User
  alias BitPalWeb.UserAuth
  alias BitPalWeb.Router.Helpers, as: Routes
  alias BitPal.ServerSetup

  def show(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :edit, &1)
          )

        ServerSetup.next_state()

        conn
        |> Plug.Conn.put_session(:user_return_to, Routes.server_setup_path(conn, :wizard))
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
