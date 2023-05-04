defmodule BitPal.IntegrationCase do
  @moduledoc """
  This module defines the setup for tests requiring
  to the application's backend services, such as currency
  backends or database.
  """

  use ExUnit.CaseTemplate
  use BitPalFactory
  alias BitPal.BackendEvents
  alias BitPal.BackendManager
  alias BitPal.BackendMock
  alias BitPal.BackendStatusSupervisor
  alias BitPal.CaseHelpers
  alias BitPal.InvoiceSupervisor
  alias BitPal.Repo
  alias BitPalFactory.ExchangeRateFactory
  alias BitPalSchemas.ExchangeRate
  alias BitPalSettings.BackendSettings
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
      alias BitPal.InvoiceSupervisor

      alias BitPalSchemas.Invoice
    end
  end

  setup tags do
    setup_integration(tags)
  end

  def setup_integration(tags \\ []) do
    repo_pid = Sandbox.start_owner!(Repo, shared: not tags[:async])

    res =
      if tags[:local_manager] do
        setup_local_integration(tags)
      else
        setup_global_integration(tags)
      end

    on_exit(fn ->
      # Shut down in order to prevent race conditions if we kill the Repo owner
      # but we have some processes lying around that wants db access.
      remove_invoice_handlers(res.currencies)

      # It would be best if we could shut down the local manager after removing invoice handlers,
      # but maybe it's fine to have the local manager only for cases without invoices?
      if !tags[:local_manager] do
        remove_backends(res.currencies)
      end

      remove_status_handlers(res.currencies)

      Sandbox.stop_owner(repo_pid)
    end)

    res
  end

  defp setup_local_integration(tags) do
    {currencies, backends} = backends_and_currencies(tags)

    enabled_state =
      currencies
      |> Enum.map(fn currency_id ->
        {currency_id, !tags[:disable]}
      end)
      |> Enum.into(%{})

    manager = CaseHelpers.unique_server_name()

    start_supervised!(
      {BackendManager,
       backends: backends, parent: self(), name: manager, enabled_state: enabled_state}
    )

    %{currencies: currencies, manager: manager}
    |> add_state_convenience()
  end

  defp setup_global_integration(tags) do
    {currencies, backends} = backends_and_currencies(tags)

    backend_refs =
      Enum.flat_map(backends, fn backend ->
        case BackendManager.add_or_update_backend(backend, enabled: !tags[:disable]) do
          {:ok, ref} -> [ref]
          _ -> []
        end
      end)

    %{
      currencies: currencies,
      backends: backend_refs
    }
    |> add_state_convenience()
  end

  defp backends_and_currencies(tags) do
    backends = backends_to_start(tags[:backends])
    currencies = Enum.map(backends, fn _ -> unique_currency_id() end)

    for currency_id <- currencies do
      for fiat_id <- [:USD, :EUR, :SEK] do
        %ExchangeRate{
          base: currency_id,
          quote: fiat_id,
          rate: ExchangeRateFactory.random_rate(),
          source: currency_id,
          prio: 10
        }
        |> Repo.insert!()
      end

      if tags[:subscribe] do
        BackendEvents.subscribe(currency_id)
      end

      if tags[:disable] do
        BackendSettings.disable(currency_id)
      end

      BackendStatusSupervisor.allow_parent(currency_id, self())
    end

    backends =
      Enum.zip([backends, currencies])
      |> Enum.map(fn {backend, currency_id} ->
        BackendManager.add_extra_backend_opts(backend,
          currency_id: currency_id,
          parent: self()
        )
      end)

    {currencies, backends}
  end

  defp backends_to_start([]), do: []
  defp backends_to_start(backends) when is_list(backends), do: backends

  defp backends_to_start(count) when is_integer(count) and count > 0 do
    Enum.map(0..(count - 1), fn _ -> BackendMock end)
  end

  defp backends_to_start(nil), do: [BackendMock]

  defp add_state_convenience(state) do
    # Convenient referrals if there's only a single currency/backend being tested.
    state
    |> add_currency_convenience()
    |> add_backend_convenience()
  end

  defp add_currency_convenience(state = %{currencies: [currency_id]}) do
    Map.put(state, :currency_id, currency_id)
  end

  defp add_currency_convenience(state) do
    state
  end

  defp add_backend_convenience(state = %{backends: [backend]}) do
    Map.put(state, :backend, backend)
  end

  defp add_backend_convenience(state) do
    state
  end

  def remove_invoice_handlers(currencies) do
    currencies_to_remove = MapSet.new(currencies)

    # Alternative way, to avoid db accesses.
    for invoice <- InvoiceSupervisor.tracked_invoices() do
      if invoice.payment_currency_id in currencies_to_remove do
        case InvoiceSupervisor.fetch_handler(invoice.id) do
          {:ok, handler} ->
            InvoiceSupervisor.terminate_handler(handler)

          _ ->
            nil
        end
      end
    end
  end

  defp remove_backends(currencies) do
    BackendManager.remove_currency_backends(currencies)
  end

  def remove_status_handlers(currencies) do
    BackendStatusSupervisor.remove_status_handlers(currencies)
  end
end
