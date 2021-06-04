BitPal is a self-hosted payment processor.

It's currently in the expiremental development phase.

# Contribution

We enforce checks at CI level. They can be run locally with `mix quality.ci` and it includes:

- Formating checks
- Credo checks
- Dialyzer checks.

  If you encounter an error that you want to silence, add the output of `mix dialyzer --format short` to `.dialyzer_ignore.exs`.

  This can be very time consuming the first time you run it.

See `lib/mix/ci.ex` for details.
