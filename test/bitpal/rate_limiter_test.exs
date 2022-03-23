defmodule BitPal.RateLimiterTest do
  use ExUnit.Case, async: true
  import BitPal.TestHelpers
  alias BitPal.RateLimiter

  defmodule Handler do
    use GenServer

    def start_link(opts) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    @impl true
    def init(_opts) do
      {:ok, %{responses: [], requests: []}}
    end

    def request(server, arg) do
      case GenServer.call(server, {:request, arg}) do
        :ok -> arg
        :fail -> raise("BOOM!")
      end
    end

    def response(server, res) do
      GenServer.call(server, {:response, res})
    end

    def responses(server) do
      GenServer.call(server, :responses)
    end

    def requests(server) do
      GenServer.call(server, :requests)
    end

    def clear_responses(server) do
      GenServer.call(server, :clear_responses)
    end

    def fail_next_request(server) do
      GenServer.call(server, :fail_next_request)
    end

    @impl true
    def handle_call({:request, arg}, _from, state) do
      state =
        state
        |> Map.update!(:requests, fn existing ->
          [arg | existing]
        end)

      if state[:fail_next_request] do
        {:reply, :fail, Map.delete(state, :fail_next_request)}
      else
        {:reply, :ok, state}
      end
    end

    @impl true
    def handle_call({:response, res}, _from, state) do
      {:reply, :ok,
       Map.update!(state, :responses, fn existing ->
         [res | existing]
       end)}
    end

    @impl true
    def handle_call(:responses, _from, state) do
      {:reply, Enum.reverse(state.responses), state}
    end

    @impl true
    def handle_call(:requests, _from, state) do
      {:reply, Enum.reverse(state.requests), state}
    end

    @impl true
    def handle_call(:clear_responses, _from, state) do
      {:reply, :ok, %{state | responses: []}}
    end

    @impl true
    def handle_call(:fail_next_request, _from, state) do
      {:reply, :ok, Map.put(state, :fail_next_request, true)}
    end
  end

  def create_request(rate_limiter, handler, arg) do
    RateLimiter.make_request(
      rate_limiter,
      {Handler, :request, [handler, arg]},
      {Handler, :response, [handler]}
    )
  end

  def create_requests(rate_limiter, handler, n) do
    1..n
    |> Enum.each(fn i ->
      create_request(rate_limiter, handler, i)
    end)
  end

  setup tags do
    limiter =
      start_supervised!(
        {RateLimiter,
         timeframe: 100,
         timeframe_max_requests: 5,
         timeframe_unit: :milliseconds,
         retry_timeout: Map.get(tags, :retry_timeout, 1_000)}
      )

    handler = start_supervised!(Handler)

    %{limiter: limiter, handler: handler}
  end

  test "rate limited requests", %{limiter: limiter, handler: handler} do
    create_requests(limiter, handler, 10)

    assert eventually(fn ->
             Handler.responses(handler) == 1..5 |> Enum.into([])
           end)

    # There must be a delay here, so we have time to make this call.
    Handler.clear_responses(handler)

    assert eventually(fn ->
             Handler.responses(handler) == 6..10 |> Enum.into([])
           end)

    Process.sleep(20)
  end

  @tag retry_timeout: 50
  test "retries request", %{limiter: limiter, handler: handler} do
    Handler.fail_next_request(handler)
    create_request(limiter, handler, :arg)

    # First fails, but we will retry it
    assert eventually(
             fn ->
               Handler.requests(handler) == [:arg] &&
                 Handler.responses(handler) == []
             end,
             20
           )

    assert eventually(fn ->
             Handler.requests(handler) == [:arg, :arg] &&
               Handler.responses(handler) == [:arg]
           end)
  end
end
