defmodule BitPalWeb.ViewHelpers do
  alias Phoenix.HTML.Link
  import Phoenix.LiveView.Helpers
  require Logger

  # credo:disable-for-next-line
  @commit System.cmd("git", ["log", "-1", "HEAD", "--pretty=format:%h"])

  def commit_link(opts) do
    class = Keyword.get(opts, :class, "commit")
    {commit, 0} = @commit

    Link.link(commit,
      to: "https://github.com/bitpal/bitpal/tree/" <> commit,
      class: class
    )
  end

  @version Mix.Project.config()[:version]
  def version, do: @version

  @doc """
  Creates a live redirect that adds the "active" class if :match == :from.
  If :match doesn't exist, it defaults to :to.
  """
  def active_live_link(opts) do
    to = Keyword.fetch!(opts, :to)
    match = Keyword.get(opts, :match, to)
    from = Keyword.fetch!(opts, :from)
    label = Keyword.fetch!(opts, :label)
    patch = Keyword.get(opts, :patch)

    class =
      if String.starts_with?(URI.parse(from).path, URI.parse(match).path) do
        "active"
      else
        nil
      end

    if patch do
      live_patch(label, to: to, class: class)
    else
      live_redirect(label, to: to, class: class)
    end
  end
end
