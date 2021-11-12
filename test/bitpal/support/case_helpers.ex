defmodule BitPal.CaseHelpers do
  alias BitPal.ProcessRegistry

  defmacro __using__(_) do
    quote do
      use BitPalFactory
      import BitPal.TestHelpers
      import BitPal.CaseHelpers
    end
  end

  def unique_server_name do
    ProcessRegistry.via_tuple({:unique_server_name, Faker.UUID.v4()})
  end
end
