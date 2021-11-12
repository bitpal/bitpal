defmodule BitPalFactory.AccountFactory do
  def unique_user_email, do: Faker.Internet.email()
  def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))

  @spec valid_user_attributes(map | keyword) :: map
  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  @spec create_user(map | keyword) :: User.t()
  def create_user(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> BitPal.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
