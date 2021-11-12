defmodule BitPalFactory.AccountFactory do
  defmacro __using__(_opts) do
    quote do
      alias BitPal.Accounts.Users

      def unique_user_email, do: sequence(:email, &"#{Faker.Internet.email()} #{&1}")
      def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))

      def user_factory do
        %User{
          email: sequence(:email, unique_user_email()),
          password: valid_user_password()
        }
        |> Users.registration_changeset([])
        |> Ecto.Changeset.apply_changes()
      end

      def with_store(user = %User{}) do
        insert_pair(:store, user: user)
        user
      end
    end
  end
end
