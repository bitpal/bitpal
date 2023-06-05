defmodule BitPalApi.StatusJSON do
  use BitPalApi, :json

  def show_status(%{status_map: map}) do
    Enum.map(map, fn {currency_id, status} ->
      show_status(%{currency_id: currency_id, status: status})
    end)
  end

  def show_status(%{status: status, currency_id: currency_id}) do
    %{status: status, currency: currency_id}
  end
end
