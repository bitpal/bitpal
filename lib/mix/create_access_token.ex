defmodule Mix.Tasks.Bitpal.Create.Store do
  use Mix.Task
  import BitPalCli.Tasks

  @dialyzer :no_undefined_callbacks

  def run([label]) do
    create_store(label)
  end
end
