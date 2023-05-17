defmodule BitPal.MockRPCClient do
  use GenServer
  import ExUnit.Assertions
  import ExUnit.Callbacks
  import Mox

  def init_mock(name) do
    client = start_supervised!({__MODULE__, name: name})

    name
    |> stub(:call, fn _url, method, params ->
      call(client, method, params)
    end)
  end

  def expect(c, method, fun) do
    GenServer.call(c, {:expect, method, fun})
  end

  def verify!(c) do
    GenServer.call(c, :verify!)
  end

  def calls(c) do
    GenServer.call(c, :calls)
  end

  def first_call(c) do
    List.last(calls(c))
  end

  def last_call(c) do
    List.first(calls(c))
  end

  def call(c, method, params) do
    GenServer.call(c, {:call, method, params})
  end

  # Internal API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{calls: [], responses: %{}}}
  end

  @impl GenServer
  def handle_call({:call, method, params}, _pid, state) do
    method_responses = Map.get(state.responses, method)

    if !method_responses || Enum.empty?(method_responses) do
      raise "Missing response for call: #{method} #{inspect(params)}"
    end

    [call_fun | rest] = method_responses
    responses = Map.put(state.responses, method, rest)
    calls = [{method, params} | state.calls]
    response = call_fun.(params)

    {:reply, response, %{state | responses: responses, calls: calls}}
  end

  @impl GenServer
  def handle_call(:verify!, _, state) do
    assert Enum.empty?(state.responses), "unused responses: #{inspect(state.responses)}"
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:expect, method, fun}, _, state) do
    state =
      state
      |> Map.update!(:responses, fn responses ->
        Map.update(responses, method, [fun], fn method_responses ->
          method_responses ++ [fun]
        end)
      end)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:calls, _, state) do
    {:reply, state.calls, state}
  end
end
