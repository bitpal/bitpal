#!/bin/sh

# As we currently initiate nodes outside of BitPal, this is an example on how that can be done.
# Note that notify cmds need to be presented in this particular way.

bitcoind -datadir=$HOME/.bchn -rpcpassword=password -rpcuser=username -alertnotify="$HOME/bitpal/ext/notify.sh 'bch:alert-notify' %s" -blocknotify="$HOME/bitpal/ext/notify.sh 'bch:block-notify' %s" -walletnotify="$HOME/bitpal/ext/notify.sh 'bch:wallet-notify' %w %s"
