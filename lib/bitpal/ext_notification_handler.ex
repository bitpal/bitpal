defmodule BitPal.ExtNotificationHandler do
  use GenServer
  alias Phoenix.PubSub
  alias BitPal.Files
  require Logger

  @notify_name :beam_notify
  @pubsub BitPal.PubSub

  @spec subscribe(binary) :: :ok
  def subscribe(event) do
    PubSub.subscribe(@pubsub, topic(event))
  end

  @spec unsubscribe(binary) :: :ok
  def unsubscribe(event) do
    PubSub.unsubscribe(@pubsub, topic(event))
  end

  def beam_notify_env do
    BEAMNotify.env(@notify_name)
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, _pid} =
      BEAMNotify.start_link(
        name: @notify_name,
        path: Files.notify_socket(),
        dispatcher: &send(__MODULE__, {:notify, &1, &2})
      )

    {:ok, %{}}
  end

  @impl true
  def handle_info({:notify, msg, _rest}, state) do
    Logger.notice("notify received: #{inspect(msg)}")

    case parse_message(msg) do
      {:ok, event, params} ->
        broadcast(event, params)

      _ ->
        Logger.warn("unknown notify msg: #{inspect(msg)}")
    end

    {:noreply, state}
  end

  @spec broadcast(binary, term) :: :ok | {:error, term}
  def broadcast(event, msg) do
    PubSub.broadcast(@pubsub, topic(event), {:notify, event, msg})
  end

  def parse_message(msg) do
    # We should normally receive a message with an event followed by some porams, 
    # but it's somehow possible to get sent the extra options as well.
    # Just filter them out.
    msg
    |> strip_notify_opts()
    |> split_event()
  end

  defp strip_notify_opts(["-p", _] ++ rest), do: strip_notify_opts(rest)
  defp strip_notify_opts(["--" | rest]), do: rest
  defp strip_notify_opts(msg), do: msg

  defp split_event([event | params]), do: {:ok, event, params}
  defp split_event(_), do: :error

  defp topic(event) do
    Atom.to_string(__MODULE__) <> event
  end
end
