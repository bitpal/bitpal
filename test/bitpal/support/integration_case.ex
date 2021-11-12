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
  alias BitPal.Currencies
  alias BitPal.InvoiceManager

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
      alias BitPal.InvoiceManager
      alias BitPal.HandlerSubscriberCollector

      alias BitPalSchemas.Invoice
    end
  end

  setup tags do
    setup_integration(tags)
  end

  def setup_integration(tags \\ []) do
    repo_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(BitPal.Repo, shared: not tags[:async])

    res = setup_backends(tags[:backends] || [BackendMock])

    test_pid = self()

    on_exit(fn ->
      if tags[:async] do
        Ecto.Adapters.SQL.Sandbox.allow(BitPal.Repo, test_pid, self())
      end

      # Shut down in order to prevent race conditions
      remove_invoice_handlers(res.currencies)
      remove_backends(res.backends)
      Ecto.Adapters.SQL.Sandbox.stop_owner(repo_pid)
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
    for invoice_id <- Currencies.invoice_ids(currencies) do
      case InvoiceManager.fetch_handler(invoice_id) do
        {:ok, handler} ->
          InvoiceManager.terminate_handler(handler)

        _ ->
          nil
      end
    end
  end

  defp remove_backends(backends) do
    BackendManager.terminate_backends(backends)
  end
end
