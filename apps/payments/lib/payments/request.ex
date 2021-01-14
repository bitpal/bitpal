defmodule Payments.Request do
  defstruct [:address, :amount, :email, :required_confirmations]
end

