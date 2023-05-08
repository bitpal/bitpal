defmodule BitPal.ExtNotificationHandler do
  use GenServer
  alias Phoenix.PubSub
  alias BitPal.Files
  require Logger

  @pubsub BitPal.PubSub

  @spec subscribe(binary) :: :ok
  def subscribe(event) do
    PubSub.subscribe(@pubsub, topic(event))
  end

  @spec unsubscribe(binary) :: :ok
  def unsubscribe(event) do
    PubSub.unsubscribe(@pubsub, topic(event))
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    BEAMNotify.start_link(
      path: Files.notify_socket(),
      dispatcher: &send(__MODULE__, {:notify, &1, &2})
    )
  end

  @impl true
  def handle_info({:notify, msg, _}, state) do
    Logger.debug("notify received: #{inspect(msg)}")

    case msg do
      [event | msg] ->
        broadcast(event, msg)

      _ ->
        Logger.warn("unknown notify msg: #{inspect(msg)}")
    end

    {:noreply, state}
  end

  @spec broadcast(binary, term) :: :ok | {:error, term}
  def broadcast(event, msg) do
    PubSub.broadcast(@pubsub, topic(event), {:notify, event, msg})
  end

  defp topic(event) do
    Atom.to_string(__MODULE__) <> event
  end
end
