defmodule Mix.Tasks.Bitpal.Create.AccessToken do
  use Mix.Task
  import BitPalCli.Tasks
  @dialyzer :no_undefined_callbacks

  def run([store_id]) do
    create_access_token(store_id)
  end
end
