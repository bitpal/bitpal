defmodule BitPalApi.InvoiceChannelFinalizeTest do
  use BitPalApi.ChannelCase, async: false, integration: true
  alias BitPalFactory.InvoiceFactory

  # Finalizing an invoice is a weird one.
  # It is done by InvoiceHandler, but that handler needs to have access to
  # the invoice we create in the Repo. But this is blocked by the Repo sandbox
  # and it's difficult to pass the parent pid() for allowance,
  # so these tests are instead run with async: false.

  describe "draft actions" do
    setup [:setup_draft]

    test "finalize", %{socket: socket, invoice: invoice} do
      ref = push(socket, "finalize", %{})
      id = invoice.id

      assert_reply(ref, :ok, %{})

      assert_broadcast("finalized", %{
        id: ^id,
        status: :open
      })
    end
  end

  defp setup_draft(context) do
    invoice =
      InvoiceFactory.create_invoice(
        status: :draft,
        payment_currency_id: Map.fetch!(context, :currency_id)
      )

    # Bypasses socket `connect`, which is fine for these tests
    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket(nil, %{store_id: invoice.store_id})
      |> subscribe_and_join(BitPalApi.InvoiceChannel, "invoice:" <> invoice.id)

    %{invoice: invoice, socket: socket}
  end
end
