defmodule BitPalFactory.Accounts do
  alias BitPalSchemas.User
  import BitPalFactory

  def unique_user_email, do: ExMachina.sequence(:email, &"#{&1}#{Faker.Internet.email()}")
  def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))

  @spec valid_user_attributes(map | keyword) :: map
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def with_store(user = %User{}) do
    insert(:store, users: [user])
    user
  end
end
