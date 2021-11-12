defmodule BitPalFactory.InvoiceFactory do
  defmacro __using__(_opts) do
    quote do
      def assign_address(invoice = %Invoice{}, address = %Address{}) do
        {:ok, _} = Invoices.assign_address(invoice, address)
        invoice
      end

      def invoice_factory do
        %Invoice{
          # FIXME does this work??
          store: fn -> build(:store) end,
          amount: rand_pos_float(),
          exchange_rate: rand_pos_float(),
          currency_id: BitPalFactory.unique_currency_id() |> Atom.to_string(),
          fiat_currency: BitPalFactory.unique_fiat(),
          description: Faker.Commerce.product_name(),
          email: Faker.Internet.email()
        }
      end
    end
  end
end
