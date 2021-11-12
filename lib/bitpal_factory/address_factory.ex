defmodule BitPalFactory.AddressFactory do
  defmacro __using__(_opts) do
    quote do
      # Note that in the future we might generate addresses that look real.
      # This is good enough for now...
      @spec unique_address_id(atom | String.t()) :: String.t()
      def unique_address_id(prefix \\ "address")

      def unique_address_id(prefix) when is_atom(prefix) do
        unique_address_id(Atom.to_string(prefix))
      end

      def unique_address_id(prefix) when is_binary(prefix) do
        String.downcase(prefix) <> ":" <> Faker.UUID.v4()
      end

      def address_factory do
      end
    end
  end
end
