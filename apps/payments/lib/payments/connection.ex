defmodule Payments.Connection do
  def connect() do
    # According to the doc, we should be able to give it some kind of string....
    connect({127, 0, 0, 1}, 1235)
  end
  def connect(host, port) do
    # Would be nice if we could get a packet in little endian mode. Now, we need to handle that ourselves...
    opts = [:binary, {:packet, 0}, {:active, false}]
    {:ok, connection} = :gen_tcp.connect(host, port, opts)
    connection
  end

  def send(connection, message) do
    size = byte_size(message) + 2
    size_msg = << rem(size, 256), div(size, 256) >>
    :gen_tcp.send(connection, size_msg <> message)
  end

  def recv(connection) do
    case :gen_tcp.recv(connection, 2) do
      {:ok, << size_low, size_high >>} ->
        size = size_high * 256 + size_low
        {:ok, data} = :gen_tcp.recv(connection, size - 2)
        data
      {:error, msg} ->
        msg
    end
  end

  def close(connection) do
    :gen_tcp.close(connection)
  end
end
