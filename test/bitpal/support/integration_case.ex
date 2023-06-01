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

    init_currencies(res.currencies, tags)

    on_exit(fn ->
      # Shut down in order to prevent race conditions if we kill the Repo owner
      # but we have some processes lying around that wants db access.
      remove_invoice_handlers(res.currencies)

      if tags[:local_manager] do
        remove_local_manager(res)
      else
        remove_global_backends(res.currencies)
      end

      BackendStatusSupervisor.remove_status_handlers(res.currencies)

      Sandbox.stop_owner(repo_pid)
    end)

    res
  end

  defp setup_local_integration(tags) do
    backends = backends_with_opts(tags)

    manager = CaseHelpers.unique_server_name()

    {:ok, pid} =
      DynamicSupervisor.start_child(
        BitPal.TestSupervisor,
        {
          BackendManager,
          init_enabled: !tags[:disable],
          backends: backends,
          parent: self(),
          name: manager,
          log_level: :alert
        }
      )

    currencies = BackendManager.currency_list(manager)

    %{currencies: currencies, manager: manager, manager_pid: pid}
    |> add_state_convenience()
  end

  defp setup_global_integration(tags) do
    backends = backends_with_opts(tags)

    backend_refs =
      Enum.flat_map(backends, fn backend ->
        case BackendManager.add_or_update_backend(backend, enabled: !tags[:disable]) do
          {:ok, ref} -> [ref]
          _ -> []
        end
      end)

    currencies =
      Enum.map(backend_refs, fn {pid, backend} ->
        {:ok, currency_id} = backend.supported_currency(pid)
        currency_id
      end)

    %{
      currencies: currencies,
      backends: backend_refs
    }
    |> add_state_convenience()
  end

  defp backends_with_opts(tags) do
    backends_to_start(tags[:backends])
    |> Enum.map(fn backend ->
      BackendManager.add_extra_backend_opts(
        backend,
        extra_backend_opts(backend)
      )
    end)
  end

  defp extra_backend_opts(backend) do
    general = [parent: self()]

    if is_mock?(backend) do
      currency_id = unique_currency_id()
      BackendStatusSupervisor.allow_parent(currency_id, self())

      general
      |> Keyword.put(:currency_id, currency_id)
    else
      general
    end
  end

  defp is_mock?(BackendMock), do: true
  defp is_mock?({BackendMock, _}), do: true
  defp is_mock?(_), do: false

  defp init_currencies(currencies, tags) do
    for currency_id <- currencies do
      init_currency(currency_id, tags)
    end
  end

  defp init_currency(currency_id, tags) do
    if tags[:init_rates] do
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
    end

    if tags[:subscribe] do
      BackendEvents.subscribe(currency_id)
    end

    if tags[:disable] do
      BackendSettings.disable(currency_id)
    end
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

  defp remove_local_manager(%{manager: manager, manager_pid: pid}) do
    BackendManager.remove_backends(manager)
    DynamicSupervisor.terminate_child(BitPal.TestSupervisor, pid)
  end

  defp remove_global_backends(currencies) do
    BackendManager.remove_currency_backends(currencies)
  end

  def remove_status_handlers(currencies) do
    BackendStatusSupervisor.remove_status_handlers(currencies)
  end
end
