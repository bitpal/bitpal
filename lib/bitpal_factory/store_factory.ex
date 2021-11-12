defmodule BitPalFactory.StoreFactory do
  defmacro __using__(_opts) do
    quote do
      alias BitPal.Stores
      alias BitPalSchemas.Store

      def store_factory do
        label = sequence(:store, &"#{Faker.Company.name()} #{&1}")
        slug = Stores.slugified_label(label)

        %Store{
          label: label,
          slug: slug
        }
      end
    end
  end
end
