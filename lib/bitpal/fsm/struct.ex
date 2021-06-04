defmodule BitPal.FSM.Config do
  defmacro __using__(opts) do
    quote do
      def __fsm__(opt), do: Keyword.fetch!(unquote(opts), opt)
    end
  end
end
