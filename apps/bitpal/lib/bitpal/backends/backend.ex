defmodule BitPal.Backend do
  @callback start_link(term) :: term
  @callback register(BitPal.Request, BitPal.Watcher) :: BitPal.BCH.Satoshi
end
