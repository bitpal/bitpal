defmodule BitPal.IntegrationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  to the application's backend services, such as currency
  backends or database.
  """

  use ExUnit.CaseTemplate
  alias BitPal.Backend
  alias BitPal.BackendSupervisor
  alias BitPal.BackendMock
  alias BitPal.InvoiceSupervisor
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

      alias BitPal.BackendSupervisor
      alias BitPal.BackendMock
      alias BitPal.HandlerSubscriberCollector
      alias BitPal.InvoiceSupervisor

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
        |> BackendSupervisor.add_allow_parent_opt(parent: self())
        |> BackendSupervisor.start_backend()
      end)

    currencies =
      Enum.flat_map(backends, fn backend ->
        case Backend.supported_currency(backend) do
          {:ok, currency_id} ->
            [currency_id]

          {:error, :not_found} ->
            []
        end
      end)

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
    # Convenient to refer to currency_id if there's only a single backend being tested.
    |> then(fn opts ->
      if Enum.count(backends) == 1 do
        Map.put(opts, :backend, hd(backends))
      else
        opts
      end
    end)
  end

  def remove_invoice_handlers(currencies) do
    currencies_to_remove = MapSet.new(currencies)

    # Alternative way, to avoid db accesses.
    for invoice <- InvoiceSupervisor.tracked_invoices() do
      if invoice.currency_id in currencies_to_remove do
        case InvoiceSupervisor.fetch_handler(invoice.id) do
          {:ok, handler} ->
            InvoiceSupervisor.terminate_handler(handler)

          _ ->
            nil
        end
      end
    end
  end

  defp remove_backends(backends) do
    BackendSupervisor.terminate_backends(backends)
  end
end
