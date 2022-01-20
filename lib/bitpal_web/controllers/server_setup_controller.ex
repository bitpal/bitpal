defmodule BitPalWeb.ServerSetupController do
  use BitPalWeb, :controller

  alias BitPal.Accounts
  alias BitPalSchemas.User
  alias BitPalWeb.UserAuth
  alias BitPalWeb.Router.Helpers, as: Routes

  def register_admin(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, "register_admin.html", changeset: changeset)
  end

  def create_admin(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &Routes.user_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "Admin created successfully.")
        |> Plug.Conn.put_session(:user_return_to, Routes.server_setup_path(conn, :info))
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "register_admin.html", changeset: changeset)
    end
  end

  def info(conn, _params) do
    render(conn, "info.html")
  end
end
