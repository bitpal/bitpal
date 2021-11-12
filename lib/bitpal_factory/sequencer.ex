defmodule BitPalFactory.Sequencer do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec next(term, (integer -> term)) :: term
  def next(name, formatter) do
    count = GenServer.call(__MODULE__, {:next, name})
    formatter.(count)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:next, name}, _, state = %{name: count}) do
    next = count + 1
    {:reply, next, Map.put(state, name, next)}
  end

  @impl true
  def handle_call({:next, name}, _, state) do
    next = 0
    {:reply, next, Map.put(state, name, next)}
  end
end
