BitPal is a self-hosted payment processor.

It's currently in the expiremental development phase.

# Getting started

BitPal is a regular Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

And then visit:

- [`api.localhost:4000`](http://api.localhost:4000) for API endpoint
- [`localhost:4000`](http://localhost:4000) for the web

Ready to run in production? Please [check out the Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

# Contribution

We enforce checks at CI level. They can be run locally with `mix bitpal.ci` and it includes:

- Formating checks (using `mix format`)
- Credo checks (`mix credo --all --strict`)
- Dialyzer checks (`mix dialyzer --format short`)

  If you encounter an error that you want to silence, add the output of `mix dialyzer --format short` to `.dialyzer_ignore.exs` or add a `@dialyzer` attribute in the file.

  Running dialyzer can be very time consuming the first time you run it.

See `lib/mix/ci.ex` for details.
