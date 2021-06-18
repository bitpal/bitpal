BitPal is a self-hosted payment processor.

It's currently in the expiremental development phase.

# Getting started

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

And then visit:

- [`api.localhost:4000`](http://api.localhost:4000) for API endpoint
- [`localhost:4000`](http://localhost:4000) for the web

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

# Contribution

We enforce checks at CI level. They can be run locally with `mix quality.ci` and it includes:

- Formating checks
- Credo checks
- Dialyzer checks.

  If you encounter an error that you want to silence, add the output of `mix dialyzer --format short` to `.dialyzer_ignore.exs`.

  This can be very time consuming the first time you run it.

See `lib/mix/ci.ex` for details.
