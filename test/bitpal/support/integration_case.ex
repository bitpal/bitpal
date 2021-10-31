defmodule BitPal.IntegrationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  to the application's backend services, such as currency
  backends or database.
  """

  use ExUnit.CaseTemplate
  use BitPalFixtures
  alias BitPal.DataCase

  using do
    quote do
      use BitPalFixtures
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import BitPal.CreationHelpers
      import BitPal.IntegrationCase
      import BitPal.TestHelpers
      import BitPal.IntegrationCase, only: [setup_integration: 0, setup_integration: 1]

      alias BitPal.Addresses
      alias BitPal.BackendManager
      alias BitPal.BackendMock
      alias BitPal.Currencies
      alias BitPal.ExchangeRate
      alias BitPal.InvoiceManager
      alias BitPal.Invoices
      alias BitPal.HandlerSubscriberCollector
      alias BitPal.Repo
      alias BitPal.Stores
      alias BitPal.Transactions
      alias BitPalSchemas.Invoice
    end
  end

  setup tags do
    setup_integration(tags)
  end

  def setup_integration(tags \\ []) do
    start_supervised!({Phoenix.PubSub, name: BitPal.PubSub})
    start_supervised!(BitPal.ProcessRegistry)
    start_supervised!({Task.Supervisor, name: BitPal.TaskSupervisor})

    DataCase.setup_db(tags)

    if tags[:backends] do
      setup_backends(tags)
    end

    :ok
  end

  defp setup_backends(tags) do
    # Only start backend if explicitly told to
    backend_manager =
      if backends = backends(tags) do
        if !Enum.empty?(backends) do
          start_supervised!({BitPal.BackendManager, backends: backends})
        end
      end

    invoice_manager =
      start_supervised!(
        {BitPal.InvoiceManager, double_spend_timeout: Map.get(tags, :double_spend_timeout, 100)}
      )

    %{
      backend_manager: backend_manager,
      invoice_manager: invoice_manager
    }
  end

  defp backends(%{backends: true}), do: [BitPal.BackendMock]
  defp backends(%{backends: backends}), do: backends
  defp backends(_), do: nil
end
