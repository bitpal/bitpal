defmodule BitPalWeb.ServerSetupAdminController do
  use BitPalWeb, :controller

  import BitPalWeb.ServerSetup, only: [server_setup_name: 1]
  alias BitPal.Accounts
  alias BitPal.ServerSetup
  alias BitPalSchemas.User
  alias BitPalWeb.Router.Helpers, as: Routes
  alias BitPalWeb.UserAuth

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

        ServerSetup.set_next(server_setup_name(conn))

        conn
        |> Plug.Conn.put_session(:user_return_to, Routes.server_setup_path(conn, :wizard))
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
