#!/bin/sh

bitcoind -datadir=$HOME/.bchn -rpcpassword=password -rpcuser=username -alertnotify="$HOME/bitpal/ext/notify.sh 'bch:alert-notify' %s" -blocknotify="$HOME/bitpal/ext/notify.sh 'bch:block-notify' %s" -walletnotify="$HOME/bitpal/ext/notify.sh 'bch:wallet-notify' %w %s"
