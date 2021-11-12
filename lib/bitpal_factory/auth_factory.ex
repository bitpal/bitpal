defmodule BitPalFactory.AuthFactory do
  defmacro __using__(_opts) do
    quote do
      def generate_auth(attrs \\ %{}) do
        store = get_or_insert_store(attrs)
        token = insert_token(store)

        %{
          store_id: store.id,
          token: token.data
        }
      end
    end
  end
end
