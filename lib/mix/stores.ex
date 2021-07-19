defmodule Mix.Tasks.Bitpal.Stores do
  use Mix.Task
  import BitPalCli.Tasks

  @dialyzer :no_undefined_callbacks

  def run(_args) do
    show_stores()
  end
end
