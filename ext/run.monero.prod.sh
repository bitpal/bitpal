#!/bin/sh

monerod --prune-blockchain --block-notify="$HOME/bitpal/ext/notify.sh 'monero:block-notify' %s" --reorg-notify="$HOME/bitpal/ext/notify.sh 'monero:reorg-notify' %h %s"
