defmodule BitPalConfig do
  alias BitPal.BackendManager
  alias BitPal.InvoiceManager

  @spec config_change(keyword, keyword, keyword) :: :ok
  def config_change(changed, new, _removed) do
    update_config(changed)
    update_config(new)
  end

  defp update_config(opts) do
    # update_opt(opts, :double_spend_timeout, fn key, val ->
    if double_spend_timeout = Keyword.get(opts, :double_spend_timeout) do
      InvoiceManager.configure(double_spend_timeout: double_spend_timeout)
    end

    if backends = Keyword.get(opts, :backends) do
      BackendManager.configure(backends: backends)
    end

    # NOTE we want to handle this in a more general way later
    if conf = Keyword.get(opts, :required_confirmations) do
      Application.put_env(:bitpal, :required_confirmations, conf)
    end
  end
end
