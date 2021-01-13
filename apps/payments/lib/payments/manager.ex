defmodule Payments.Manager do
  alias Payments.Handler

  def wait_for_tx(pid, _address) do
    :timer.send_after(2000, pid, :tx_seen)
  end

  def get_handler() do
    Handler.start_link()
  end

  def subscribe(listener, request) do
    get_handler()
    |> Handler.subscribe(listener, request)
  end

  # def start_handler(listener, request) do
  #   # FIXME We should use a Registry to find a process to handle our entire request?
  #   Payments.Handler.start_link(listener: listener, request: request)
  # end
end

