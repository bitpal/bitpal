#!/bin/sh

# Script to send messages to a running Beam application.
# See BEAMNotify docs for more info:
# https://hexdocs.pm/beam_notify/readme.html

# BEAM_NOTIFY and BEAM_NOTIFY_OPTIONS needs to be set for this to work.
# BitPal will try to set the variables on startup, however
# Monero notify commands won't keep the environment so this doesn't work.
# $BEAM_NOTIFY $@
#
# We might be able to do this if we can't set environment variables.
# If installation path changes then this won't work of course, but it's fine
# during development and manually deploying from source.

BEAM_NOTIFY=$(ls $(dirname $0)/../_build/${MIX_ENV:-dev}/lib/beam_notify/priv/beam_notify)
$BEAM_NOTIFY -p /tmp/bitpal_notify_socket -- $@
