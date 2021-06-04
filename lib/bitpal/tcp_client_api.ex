defmodule BitPal.TCPClientAPI do
  @callback connect(:inet.socket_address() | :inet.hostname(), :inet.port_number(), keyword) ::
              {:ok, any}
  @callback send(any, binary) :: :ok | {:error, term}
  @callback recv(any, non_neg_integer) :: {:ok, binary} | {:error, term}
  @callback close(any) :: :ok
end
