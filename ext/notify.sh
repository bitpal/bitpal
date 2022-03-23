#!/bin/sh

BEAM_NOTIFY=$(ls $(dirname $0)/../_build/dev/lib/beam_notify/priv/beam_notify)
$BEAM_NOTIFY -p /tmp/bitpal_notify_socket -- $@
