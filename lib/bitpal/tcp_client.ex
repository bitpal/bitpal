defmodule BitPal.TCPClient do
  @behaviour BitPal.TCPClientAPI

  @impl true
  def connect(host, port, opts \\ []) do
    :gen_tcp.connect(host, port, opts)
  end

  @spec send(any, binary) :: :ok | {:error, term}
  @impl true
  def send(c, msg) do
    :gen_tcp.send(c, msg)
  end

  @spec recv(any, non_neg_integer) :: {:ok, binary} | {:error, term}
  @impl true
  def recv(c, size) do
    :gen_tcp.recv(c, size)
  end

  @impl true
  def close(c) do
    :gen_tcp.close(c)
  end
end
