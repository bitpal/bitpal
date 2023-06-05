defmodule BitPalApi.StoreSocket do
  use Phoenix.Socket
  alias BitPal.Authentication.Tokens
  require Logger

  ## Channels
  channel("invoices", BitPalApi.InvoiceChannel)
  channel("invoice:*", BitPalApi.InvoiceChannel)
  channel("exchange_rates", BitPalApi.ExchangeRateChannel)
  channel("status", BitPalApi.StatusChannel)

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Tokens.authenticate_token(token) do
      {:ok, store_id} ->
        {:ok, assign(socket, :store_id, store_id)}

      err ->
        Logger.debug("Failed token auth: #{inspect(err)}")
        :error
    end
  end

  @impl true
  def connect(_params, socket, %{x_headers: x_headers}) do
    with {:ok, token} <- find_token(x_headers),
         {:ok, store_id} <- Tokens.authenticate_token(token) do
      {:ok, assign(socket, :store_id, store_id)}
    else
      _ ->
        :error
    end
  end

  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  defp find_token(x_headers) do
    Enum.find_value(x_headers, :error, fn {k, v} -> k == "x-access-token" && {:ok, v} end)
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     BitPalApi.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "store_socket:#{socket.assigns.store_id}"
end
