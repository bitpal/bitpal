#!/usr/bin/env bash

# Starts a system command and monitor stdin and then close the command.
# Used to shut down external processes if the beam vm closes.
# See: https://hexdocs.pm/elixir/Port.html#module-zombie-os-processes

# Start the program in the background
exec "$@" &
pid1=$!

# Silence warnings from here on
exec >/dev/null 2>&1

# Read from stdin in the background and
# kill running program when stdin closes
exec 0<&0 $(
  while read; do :; done
  kill -KILL $pid1
) &
pid2=$!

# Clean up
wait $pid1
ret=$?
kill -KILL $pid2
exit $ret
