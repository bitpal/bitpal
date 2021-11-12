defmodule BitPalFactory.AccountFactory do
  defmacro __using__(_opts) do
    quote do
      alias BitPal.Accounts.Users
      alias BitPalSchemas.User

      def unique_user_email, do: sequence(:email, &"#{&1}#{Faker.Internet.email()}")
      def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))

      @spec valid_user_attributes(map | keyword) :: map
      def valid_user_attributes(attrs \\ %{}) do
        Enum.into(attrs, %{
          email: unique_user_email(),
          password: valid_user_password()
        })
      end

      def user_factory(attrs) do
        attrs = valid_user_attributes(attrs)

        %User{}
        |> Users.registration_changeset(attrs)
        |> Ecto.Changeset.apply_changes()
      end

      def with_store(user = %User{}) do
        insert(:store, users: [user])
        user
      end
    end
  end
end
