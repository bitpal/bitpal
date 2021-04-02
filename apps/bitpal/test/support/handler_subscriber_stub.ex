defmodule HandlerSubscriberStub do
  use GenServer
  alias BitPal.InvoiceManager

  # Client API

  def create_invoice(invoice) do
    {:ok, pid} = start_link(nil)
    GenServer.call(pid, {:create_invoice, invoice})
    {:ok, pid}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def received(handler) do
    GenServer.call(handler, :received)
    |> Enum.reverse()
  end

  def await_state_change(handler, state) do
    await_msg(handler, {:state_changed, state})
  end

  def await_msg(handler, msg) do
    task = Task.async(HandlerSubscriberStub, :sleep_until_msg, [handler, msg])
    Task.await(task, 50)
    {:ok, received(handler)}
  end

  def sleep_until_msg(handler, msg) do
    if contains_msg?(handler, msg) do
      :ok
    else
      Process.sleep(10)
      sleep_until_msg(handler, msg)
    end
  end

  def contains_msg?(handler, msg) do
    received(handler)
    |> Enum.any?(fn
      ^msg -> true
      _ -> false
    end)
  end

  # Server API

  @impl true
  def init(_init_args) do
    {:ok, %{received: []}}
  end

  @impl true
  def handle_call({:create_invoice, invoice}, _, state) do
    invoice = InvoiceManager.create_invoice(invoice)
    {:reply, :ok, Map.put(state, :invoice, invoice)}
  end

  @impl true
  def handle_call(:received, _, state = %{received: received}) do
    {:reply, received, state}
  end

  @impl true
  def handle_info(info, state = %{received: received}) do
    {:noreply, %{state | received: [info | received]}}
  end
end
