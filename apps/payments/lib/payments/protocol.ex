defmodule Payments.Protocol do
  use Bitwise

  # Varios constants from the header files.
  defmodule HeaderTags do
    def headerEnd() do
      0
    end

    def serviceId() do
      1
    end

    def messageId() do
      2
    end

    # an int-value of the total body size
    def sequenceStart() do
      3
    end

    # bool. If present indicates it is part of a sequence. If true, last in sequence.
    def lastInSequence() do
      4
    end

    def ping() do
      5
    end

    def pong() do
      6
    end
  end

  # Create a version request message.
  def version_request() do
    # Note: The docs says "MessageId" is 1, but it is really 0.
    [{HeaderTags.serviceId(), 0}, {HeaderTags.messageId(), 0}, {HeaderTags.headerEnd(), true}]
  end
end
