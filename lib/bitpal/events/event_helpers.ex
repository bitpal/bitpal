defmodule BitPal.EventHelpers do
  alias Phoenix.PubSub
  require Logger

  @pubsub BitPal.PubSub

  @spec subscribe(String.t()) :: :ok | {:error, term}
  def subscribe(topic) do
    Logger.debug("subscribing to #{topic} #{inspect(self())}")
    PubSub.subscribe(@pubsub, topic)
  end

  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(topic) do
    Logger.debug("unsubscribing from #{topic} #{inspect(self())}")
    PubSub.unsubscribe(@pubsub, topic)
  end

  @spec broadcast(String.t(), term) :: :ok | {:error, term}
  def broadcast(topic, msg) do
    Logger.debug("broadcasting #{inspect(msg)} to #{topic}")
    PubSub.broadcast(@pubsub, topic, msg)
  end
end
