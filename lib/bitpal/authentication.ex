defmodule BitPal.Authentication do
  @moduledoc false

  def authenticate(login, pass) do
    Plug.Crypto.secure_compare(login, "user") && Plug.Crypto.secure_compare(pass, "")
  end
end
