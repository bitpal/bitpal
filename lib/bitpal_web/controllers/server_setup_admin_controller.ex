defmodule BitPalWeb.ServerSetupAdminController do
  use BitPalWeb, :controller

  use BitPalWeb, :verified_routes
  import BitPalWeb.ServerSetup, only: [server_setup_name: 1]
  alias BitPal.Accounts
  alias BitPal.ServerSetup
  alias BitPalSchemas.User
  alias BitPalWeb.UserAuth

  def show(conn, _params) do
    changeset = Accounts.change_user_registration(%User{})
    render(conn, :new, changeset: changeset)
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        ServerSetup.set_next(server_setup_name(conn))

        conn
        |> Plug.Conn.put_session(:user_return_to, ~p"/server/setup/wizard")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
