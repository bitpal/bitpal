defmodule BitPalWeb.ServerSetup do
  import Phoenix.Controller
  alias Plug.Conn
  alias BitPal.ServerSetup
  alias BitPalWeb.Router.Helpers, as: Routes

  @doc """
  Redirects to server setup pages unless setup has been completed.
  """
  def redirect_unless_server_setup(conn, _opts) do
    case ServerSetup.current_state(server_setup_name(conn)) do
      :completed ->
        conn

      :create_server_admin ->
        redirect_lazy(conn, Routes.server_setup_admin_path(conn, :show))

      _ ->
        if conn.assigns[:current_user] do
          # Only redirect to wizard if we're logged in.
          redirect_lazy(conn, Routes.server_setup_path(conn, :wizard))
        else
          redirect_lazy(conn, Routes.user_session_path(conn, :new))
        end
    end
  end

  @doc """
  Redirects to setup wizard if server admin has been created.
  """
  def redirect_if_server_admin_created(conn, _opts) do
    cond do
      # If we're logged in we can continue with the setup wizard.
      conn.assigns[:current_user] ->
        redirect_lazy(conn, Routes.server_setup_path(conn, :wizard))

      # If there's an admin created, we need to login first.
      ServerSetup.server_admin_created?(server_setup_name(conn)) ->
        redirect_lazy(conn, Routes.user_session_path(conn, :new))

      # Otherwise continue as is.
      true ->
        conn
    end
  end

  @doc """
  Redirect, but only if the request path doesn't match the target.
  """
  def redirect_lazy(conn, path) do
    if path && path != conn.request_path do
      conn
      |> redirect(to: path)
      |> Conn.halt()
    else
      conn
    end
  end

  def server_setup_name(%Conn{assigns: %{test_server_setup: name}}) do
    name
  end

  def server_setup_name(%{"test_server_setup" => name}) do
    name
  end

  def server_setup_name(_), do: BitPal.ServerSetup
end
