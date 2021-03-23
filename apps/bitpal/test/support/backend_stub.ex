defmodule BitPal.BackendStub do
  use GenServer
  require Logger
  alias BitPal.Backend

  @behaviour Backend

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name) || __MODULE__
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Backend
  def register(backend, request, watcher) do
    GenServer.call(backend, {:register, request, watcher})
  end

  @impl Backend
  def supported_currencies(backend) do
    GenServer.call(backend, :supported_currencies)
  end

  def child_spec(arg) do
    id = Keyword.get(arg, :name) || __MODULE__

    %{
      id: id,
      start: {BitPal.BackendStub, :start_link, [arg]}
    }
  end

  # Server API

  @impl true
  def init(opts) do
    currencies = Keyword.get(opts, :currencies, [:bch])

    {:ok, %{currencies: currencies}}
  end

  @impl true
  def handle_call(:supported_currencies, _, state = %{currencies: currencies}) do
    {:reply, currencies, state}
  end
end
