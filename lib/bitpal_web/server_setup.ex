defmodule BitPalWeb.ServerSetup do
  import BitPal.ServerSetup
  import Phoenix.Controller
  import Plug.Conn
  alias BitPalWeb.Router.Helpers, as: Routes

  @doc """
  Redirects to server setup pages unless setup has been completed.
  """
  def server_setup_redirect(conn, _opts) do
    redirect_lazy(conn, setup_path(conn))
  end

  @doc """
  Redirects away from server setup pages once setup has been completed.
  """
  def redirect_if_setup_completed(conn, _opts) do
    if setup_completed?() do
      redirect_lazy(conn, Routes.server_setup_path(conn, :info))
    else
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
      |> halt()
    else
      conn
    end
  end

  defp setup_path(conn) do
    case setup_stage() do
      :none -> Routes.server_setup_path(conn, :register_admin)
      :completed -> nil
    end
  end
end
