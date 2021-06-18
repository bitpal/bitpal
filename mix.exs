defmodule BitPal.MixProject do
  use Mix.Project

  def project do
    [
      app: :bitpal,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {BitPal.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test) do
    [
      "lib",
      "test/bitpal/fixtures",
      "test/bitpal/support",
      "test/bitpal_api/support",
      "test/bitpal_web/support",
      "test/bitpal_web/support"
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ecto_sql, "~> 3.6"},
      {:eqrcode, "~> 0.1.7"},
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.0"},
      {:libsecp256k1, "~> 0.1.9"},
      {:money, "~> 1.8"},
      {:mox, "~> 1.0"},
      {:poison, "~> 4.0"},
      {:postgrex, ">= 0.0.0"},
      {:typed_ecto_schema, "~> 0.2"},

      # Phoenix and web
      {:gettext, "~> 0.11"},
      {:master_proxy, "~> 0.1"},
      {:phoenix, "~> 1.5.9"},
      {:phoenix_ecto, "~> 4.1"},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:phoenix_live_dashboard, "~> 0.4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.15.7"},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},

      # CI and tests
      {:ci, "~> 0.1.0", only: [:dev, :test]},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.8", only: [:dev, :test], runtime: false},

      # Docs
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      ci: ["bitpal.ci"],
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test --no-start"]
    ]
  end
end
