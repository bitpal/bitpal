defmodule BitPalApi.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BitPalWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  defmacro __using__(params) do
    quote do
      use ExUnit.Case, unquote(params)
      use BitPal.CaseHelpers
      use BitPalFactory
      import Phoenix.ChannelTest
      import BitPalApi.ChannelCase
      import BitPal.TestHelpers
      alias BitPal.DataCase
      alias BitPal.IntegrationCase

      # The default endpoint for testing
      @endpoint BitPalApi.Endpoint

      @integration Keyword.get(unquote(params), :integration)

      setup tags do
        {:ok, setup_integration(tags)}
      end

      defp setup_integration(tags) do
        if @integration do
          IntegrationCase.setup_integration(tags)
        else
          DataCase.setup_db(tags)
          tags
        end
      end
    end
  end
end
