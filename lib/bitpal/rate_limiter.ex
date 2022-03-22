defmodule BitPal.RateLimiter do
  @moduledoc """
  A token bucket rate limiter.

  Will allow burst requests until the max requests in a timeframe is consumed.

  Adapted from: https://akoutmos.com/post/rate-limiting-with-genservers/
  """
  use GenServer

  @type settings :: [
          timeframe: non_neg_integer,
          timeframe_max_requests: non_neg_integer,
          timeframe_unit: :hours | :minutes | :seconds | :milliseconds,
          retry_timeout: non_neg_integer
        ]

  @type request_handler :: {module, atom, list}
  @type response_handler :: {module, atom, list}

  @spec start_link(settings) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec make_request(term, request_handler, response_handler) :: :ok
  def make_request(server, request_handler, response_handler) do
    GenServer.call(server, {:make_request, request_handler, response_handler})
  end

  @impl true
  def init(opts) do
    opts = Enum.into(opts, %{})

    # Use an internal task supervisor to shut down any tasks
    # directly if the rate limiter exits for some reason.
    # Makes tests much cleaner and shouldn't affect production use
    # as the rate limiter should only exit if there's a bad bug.
    {:ok, task_supervisor} = Task.Supervisor.start_link()

    state =
      %{
        requests_per_timeframe: opts.timeframe_max_requests,
        available_tokens: opts.timeframe_max_requests,
        token_refresh_rate:
          calculate_refresh_rate(
            opts.timeframe_max_requests,
            opts.timeframe,
            opts.timeframe_unit
          ),
        retry_timeout: opts.retry_timeout,
        task_supervisor: task_supervisor,
        request_queue: :queue.new(),
        request_queue_size: 0
      }
      |> schedule_refresh()

    {:ok, state}
  end

  @impl true
  def handle_call({:make_request, request_handler, response_handler}, _from, state) do
    {:reply, :ok, handle_request(request_handler, response_handler, state)}
  end

  @impl true
  def handle_info(:token_refresh, state = %{request_queue_size: 0}) do
    state =
      state
      |> schedule_refresh()
      |> Map.update!(:available_tokens, fn curr ->
        min(state.requests_per_timeframe, curr + 1)
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info(:token_refresh, state) do
    {{:value, {request_handler, response_handler}}, updated_queue} =
      :queue.out(state.request_queue)

    state =
      state
      |> async_request(request_handler, response_handler)
      |> schedule_refresh()
      |> Map.replace!(:request_queue, updated_queue)
      |> Map.update!(:request_queue_size, &(&1 - 1))

    {:noreply, state}
  end

  @impl true
  def handle_info({:retry_request, {request_handler, response_handler}}, state) do
    {:noreply, handle_request(request_handler, response_handler, state)}
  end

  @impl true
  def handle_info({:DOWN, ref, _, _, _reason}, state) do
    # Request failed, retry it.
    if args = Map.get(state, ref) do
      Process.send_after(self(), {:retry_request, args}, state.retry_timeout)
      {:noreply, Map.delete(state, ref)}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({ref, _res}, state) do
    # Discard the DOWN message if a response is successfull.
    Process.demonitor(ref, [:flush])
    {:noreply, Map.delete(state, ref)}
  end

  defp handle_request(request_handler, response_handler, state = %{available_tokens: 0}) do
    updated_queue = :queue.in({request_handler, response_handler}, state.request_queue)

    state
    |> Map.replace!(:request_queue, updated_queue)
    |> Map.update!(:request_queue_size, &(&1 + 1))
  end

  defp handle_request(request_handler, response_handler, state) do
    state
    |> async_request(request_handler, response_handler)
    |> Map.update!(:available_tokens, &(&1 - 1))
  end

  defp schedule_refresh(state) do
    Process.send_after(self(), :token_refresh, state.token_refresh_rate)
    state
  end

  defp async_request(state, request_handler, response_handler) do
    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        {req_module, req_function, req_args} = request_handler

        {resp_module, resp_function, resp_args} = response_handler

        response = apply(req_module, req_function, req_args)
        apply(resp_module, resp_function, Enum.reverse([response | resp_args]))
      end)

    Map.put(state, task.ref, {request_handler, response_handler})
  end

  def calculate_refresh_rate(num_requests, time, timeframe_units) do
    floor(convert_time_to_milliseconds(timeframe_units, time) / num_requests)
  end

  def convert_time_to_milliseconds(:hours, time), do: :timer.hours(time)
  def convert_time_to_milliseconds(:minutes, time), do: :timer.minutes(time)
  def convert_time_to_milliseconds(:seconds, time), do: :timer.seconds(time)
  def convert_time_to_milliseconds(:milliseconds, milliseconds), do: milliseconds
end
