defmodule BitPalApi.Authentication.BasicAuth do
  import Plug.Conn
  alias BitPal.Authentication.Tokens
  alias BitPalApi.UnauthorizedError

  def init(opts), do: opts

  def call(conn, _opts) do
    case parse(conn) do
      {:ok, store_id} ->
        assign(conn, :current_store, store_id)

      _ ->
        raise UnauthorizedError
    end
  end

  def parse(conn) do
    with {token, _} <- Plug.BasicAuth.parse_basic_auth(conn),
         {:ok, store_id} <- Tokens.authenticate_token(token) do
      {:ok, store_id}
    else
      err -> err
    end
  end
end
