defmodule BitPalWeb.ViewHelpers do
  alias Phoenix.HTML.Link
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
end
