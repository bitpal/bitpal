defmodule BitPal.MixProject do
  use Mix.Project

  def project do
    [
      app: :bitpal,
      version: "0.1.0",
      elixir: "~> 1.14.3",
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
      "test/bitpal_doc/support"
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:ecto_sql, "~> 3.7"},
      {:eqrcode, "~> 0.1.7"},
      {:httpoison, "~> 2.1.0"},
      {:jason, "~> 1.0"},
      {:libsecp256k1, "~> 0.1.9"},
      {:money, "~> 1.8"},
      {:mox, "~> 1.0"},
      {:postgrex, ">= 0.0.0"},
      {:typed_ecto_schema, "~> 0.2"},
      {:scribe, "~> 0.10"},
      {:con_cache, "~> 1.0"},
      {:faker, "~> 0.16"},
      {:timex, "~> 3.0"},
      {:recase, "~> 0.7"},

      # Server docs
      # FIXME lock at git hash
      {:nimble_publisher, git: "https://github.com/treeman/nimble_publisher.git"},
      {:makeup_elixir, ">= 0.0.0"},
      {:floki, "~> 0.34.2"},

      # Phoenix and web
      {:gettext, "~> 0.11"},
      {:master_proxy, "~> 0.1"},
      {:phoenix, "~> 1.7.2"},
      {:phoenix_ecto, "~> 4.4.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.18.18"},
      {:phoenix_pubsub, "~> 2.0"},
      {:plug_cowboy, "~> 2.5"},
      {:argon2_elixir, "~> 3.1"},
      {:swoosh, "~> 1.0"},
      {:hackney, "~> 1.0"},
      {:dart_sass, "~> 0.2", runtime: Mix.env() == :dev},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0.0"},

      # CI and tests
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.11", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.0", only: [:dev, :test], runtime: false},

      # Elixir docsdefstruct
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "phx.routes": "phx.routes BitPalWeb.Router",
      setup: ["deps.get", "ecto.setup"],
      "ecto.dev_reset": ["ecto.reset", "run priv/repo/dev_seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      check: [
        "compile --warnings-as-errors --all-warnings",
        "format --check-formatted --dry-run",
        "credo --all --strict",
        "sobelow --skip --exit",
        "deps.audit",
        "hex.audit",
        "deps.unlock --check-unused",
        "dialyzer --format short"
      ],
      "assets.setup": ["esbuild.install --if-missing"],
      "assets.build": ["esbuild default"],
      "assets.deploy": [
        "sass default --no-source-map --style=compressed",
        "esbuild default --minify",
        "copy-static-assets.sh"
      ]
    ]
  end
end
