defmodule BitPal.BackendCase do
  use ExUnit.CaseTemplate

  alias BitPal.Invoice
  alias BitPal.InvoiceManager
  alias BitPal.BackendManager
  alias BitPal.BackendStub
  alias BitPal.Transactions

  using do
    quote do
      alias BitPal.Invoice
      alias BitPal.InvoiceManager
      alias BitPal.BackendManager
      alias BitPal.BackendStub
      alias BitPal.Transactions

      import BitPal.BackendCase
    end
  end

  def assert_shutdown(pid) do
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
  end

  def invoice(args \\ []) do
    amount = Decimal.from_float(Keyword.get(args, :amount, 1.3))
    exchange_rate = Decimal.from_float(Keyword.get(args, :exchange_rate, 2.0))
    fiat_amount = Decimal.mult(amount, exchange_rate)

    %Invoice{
      address: "bitcoincash:qqpkcce4wlzdc8guam5jfys9prfyhr90seqzakyv4tu",
      amount: amount,
      exchange_rate: exchange_rate,
      fiat_amount: fiat_amount,
      email: "test@bitpal.dev"
    }
  end

  setup tags do
    if tags[:dry] do
      :ok
    else
      setup_backend(tags)
    end
  end

  defp setup_backend(tags) do
    # Only start backend if explicitly told to
    backend_manager =
      if backends = backends(tags) do
        start_supervised!({BackendManager, backends})
      end

    invoice_manager = start_supervised!(InvoiceManager)
    transactions = start_supervised!(Transactions)

    %{
      backend_manager: backend_manager,
      invoice_manager: invoice_manager,
      transactions: transactions
    }
  end

  defp backends(%{backends: backends}), do: backends
  defp backends(%{backend: true}), do: [BackendStub]
  defp backends(_), do: nil
end
