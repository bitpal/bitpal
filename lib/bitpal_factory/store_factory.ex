defmodule BitPalFactory.StoreFactory do
  defmacro __using__(_opts) do
    quote do
      alias BitPal.Stores
      alias BitPalSchemas.Store
      alias BitPalSchemas.User

      def store_factory do
        label = sequence(:store, &"#{Faker.Company.name()} #{&1}")
        slug = Stores.slugified_label(label)

        %Store{
          label: label,
          slug: slug
        }
      end

      def assoc_user(store = %Store{}, user = %User{}) do
        Stores.assoc_user(store, user)
      end
    end
  end
end
