defmodule Mix.Tasks.Dev do
  use Mix.Task

  def run(_) do
    c = Payments.Connection.connect()
    Payments.Connection.send(c, Payments.Protocol.version_request())
    IO.inspect(Payments.Connection.recv(c))
    Payments.Connection.close(c)
    IO.puts("Done!")
  end
end
