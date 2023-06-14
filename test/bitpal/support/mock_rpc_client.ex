defmodule BitPal.MockRPCClient do
  use GenServer
  import ExUnit.Assertions
  import ExUnit.Callbacks
  alias Mox

  def init_mock(name, opts \\ []) do
    client = start_supervised!({__MODULE__, Keyword.merge(opts, [{:name, name}])})

    name
    |> Mox.stub(:call, fn _url, method, params ->
      call(client, method, params)
    end)
  end

  def expect(c, method, n \\ 1, fun) do
    GenServer.call(c, {:expect, method, n, fun})
  end

  def stub(c, method, fun) do
    GenServer.call(c, {:stub, method, fun})
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
  def init(opts) do
    {:ok, %{calls: [], expected: %{}, stubs: %{}, missing_call_reply: opts[:missing_call_reply]}}
  end

  @impl GenServer
  def handle_call({:call, method, params}, _pid, state) do
    method_expected = Map.get(state.expected, method)

    cond do
      method_expected && Enum.any?(method_expected) ->
        [call_fun | rest] = method_expected
        expected = Map.put(state.expected, method, rest)
        calls = [{method, params} | state.calls]
        response = call_fun.(params)

        {:reply, response, %{state | expected: expected, calls: calls}}

      stub = Map.get(state.stubs, method) ->
        calls = [{method, params} | state.calls]

        response = stub.(params)

        {:reply, response, %{state | calls: calls}}

      reply = state[:missing_call_reply] ->
        {:reply, reply, state}

      true ->
        raise "Missing response for call: #{method} #{inspect(params)}"
    end
  end

  @impl GenServer
  def handle_call(:verify!, _, state) do
    for {method, calls} <- state.expected do
      assert Enum.empty?(calls), "unused expected: #{method} #{inspect(calls)}"
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:expect, method, n, fun}, _, state) do
    new_funs = Enum.map(1..n, fn _ -> fun end)

    state =
      state
      |> Map.update!(:expected, fn expected ->
        Map.update(expected, method, new_funs, fn method_expected ->
          # credo:disable-for-next-line
          method_expected ++ new_funs
        end)
      end)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:stub, method, fun}, _, state) do
    state =
      state
      |> Map.update!(:stubs, fn stubs ->
        Map.put(stubs, method, fun)
      end)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:calls, _, state) do
    {:reply, state.calls, state}
  end
end
