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

  use ExUnit.CaseTemplate
  alias BitPal.IntegrationCase

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import BitPalApi.ChannelCase
      import BitPal.CreationHelpers
      import BitPal.TestHelpers
      import BitPal.CreationHelpers

      # The default endpoint for testing
      @endpoint BitPalApi.Endpoint
    end
  end

  setup tags do
    IntegrationCase.setup_integration(tags)

    start_supervised!({BitPal.ExchangeRateSupervisor, ttl: tags[:cache_clear_interval]})

    start_supervised!({Phoenix.PubSub, name: BitPalApi.PubSub}, id: BitPalApi.PubSub)
    start_supervised!(BitPalApi.Endpoint)

    :ok
  end
end
