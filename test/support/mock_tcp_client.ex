defmodule BitPal.MockTCPClient do
  use GenServer
  import ExUnit.Assertions
  import ExUnit.Callbacks
  import Mox

  def init_mock(name) do
    client = start_supervised!({BitPal.MockTCPClient, name: name})

    name
    |> stub(:connect, fn _, _, _ -> {:ok, client} end)
    |> stub(:recv, fn id, size ->
      {:ok, next_response(id, size)}
    end)
    |> stub(:send, fn id, msg -> {:ok, log_send(id, msg)} end)
  end

  def response(c, msgs) when is_list(msgs) do
    GenServer.call(c, {:response, msgs})
  end

  def response(c, msg) when is_bitstring(msg) do
    GenServer.call(c, {:response, msg})
  end

  def verify!(c) do
    GenServer.call(c, :verify!)
  end

  def sent(c) do
    GenServer.call(c, :sent)
  end

  def last_sent(c) do
    List.first(sent(c))
  end

  # Internal API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def log_send(c, msg) do
    GenServer.call(c, {:log_send, msg})
  end

  def next_response(c, size) do
    GenServer.call(c, {:next_response, size})
  end

  def close(c) do
    GenServer.call(c, :close)
  end

  @impl GenServer
  def init(_args) do
    {:ok, %{sent: [], responses: [], waiting: []}}
  end

  @impl GenServer
  def handle_call({:log_send, msg}, _, state) do
    {:reply, :ok, %{state | sent: [msg | state.sent]}}
  end

  @impl GenServer
  def handle_call({:next_response, size}, pid, state) do
    state =
      state
      |> Map.update!(:waiting, fn waiting ->
        Enum.reverse([{pid, size} | waiting])
      end)
      |> enqueue_reply

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:verify!, _, state) do
    assert Enum.empty?(state.responses), "unused responses: #{inspect(state.responses)}"
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:response, msgs}, _, state) when is_list(msgs) do
    state =
      state
      |> Map.update!(:responses, fn responses ->
        responses ++ msgs
      end)
      |> enqueue_reply

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:response, msg}, _, state) do
    state =
      state
      |> Map.update!(:responses, fn responses ->
        Enum.reverse([msg | responses])
      end)
      |> enqueue_reply

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(:sent, _, state) do
    {:reply, state.sent, state}
  end

  @impl GenServer
  def handle_info(
        :reply,
        state = %{
          waiting: [{pid, size} | rest_waiting],
          responses: [response | rest_responses]
        }
      ) do
    assert byte_size(response) == size,
           "mismatched size of response, got #{inspect(response)} expected #{size}"

    GenServer.reply(pid, response)
    {:noreply, %{state | waiting: rest_waiting, responses: rest_responses}}
  end

  def handle_info(:reply, state) do
    {:noreply, state}
  end

  defp enqueue_reply(state) do
    if !Enum.empty?(state.responses) do
      send(self(), :reply)
    end

    state
  end
end
