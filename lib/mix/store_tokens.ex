defmodule Mix.Tasks.Bitpal.Store.Tokens do
  use Mix.Task
  import BitPalCli.Tasks
  @dialyzer :no_undefined_callbacks

  def run([store_id]) do
    show_store_tokens(store_id)
  end
end
