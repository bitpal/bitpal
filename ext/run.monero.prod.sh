#!/bin/sh

# As we currently initiate nodes outside of BitPal, this is an example on how that can be done.
# Note that notify cmds need to be presented in this particular way.

monerod --prune-blockchain --block-notify="$HOME/bitpal/ext/notify.sh 'monero:block-notify' %s" --reorg-notify="$HOME/bitpal/ext/notify.sh 'monero:reorg-notify' %h %s"
