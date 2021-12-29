defmodule BitPal.IntegrationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  to the application's backend services, such as currency
  backends or database.
  """

  use ExUnit.CaseTemplate
  alias BitPal.Backend
  alias BitPal.BackendManager
  alias BitPal.BackendMock
  alias BitPal.InvoiceManager
  alias BitPal.Repo
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      use BitPal.CaseHelpers
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import BitPal.IntegrationCase

      alias BitPal.Addresses
      alias BitPal.Currencies
      alias BitPal.ExchangeRate
      alias BitPal.Invoices
      alias BitPal.Repo
      alias BitPal.Stores
      alias BitPal.Transactions

      alias BitPal.BackendManager
      alias BitPal.BackendMock
      alias BitPal.HandlerSubscriberCollector
      alias BitPal.InvoiceManager

      alias BitPalSchemas.Invoice
    end
  end

  setup tags do
    setup_integration(tags)
  end

  def setup_integration(tags \\ []) do
    repo_pid = Sandbox.start_owner!(Repo, shared: not tags[:async])

    res = setup_backends(tags[:backends] || [BackendMock])

    test_pid = self()

    on_exit(fn ->
      if tags[:async] do
        Sandbox.allow(Repo, test_pid, self())
      end

      # Shut down in order to prevent race conditions
      remove_invoice_handlers(res.currencies)
      remove_backends(res.backends)
      Sandbox.stop_owner(repo_pid)
    end)

    res
  end

  defp setup_backends(backends) when is_list(backends) do
    backends =
      Enum.map(backends, fn backend ->
        backend
        |> BackendManager.add_allow_parent_opt(parent: self())
        |> BackendManager.start_backend()
      end)

    currencies = Enum.flat_map(backends, &Backend.supported_currencies/1)

    %{
      currencies: currencies,
      backends: backends
    }
    # Convenient to refer to currency_id if there's only a single currency being tested.
    |> then(fn opts ->
      if Enum.count(currencies) == 1 do
        Map.put(opts, :currency_id, hd(currencies))
      else
        opts
      end
    end)
  end

  def remove_invoice_handlers(currencies) do
    currencies_to_remove = MapSet.new(currencies)

    # Alternative way, to avoid db accesses.
    for invoice <- InvoiceManager.tracked_invoices() do
      if invoice.currency_id in currencies_to_remove do
        case InvoiceManager.fetch_handler(invoice.id) do
          {:ok, handler} ->
            InvoiceManager.terminate_handler(handler)

          _ ->
            nil
        end
      end
    end
  end

  defp remove_backends(backends) do
    BackendManager.terminate_backends(backends)
  end
end
