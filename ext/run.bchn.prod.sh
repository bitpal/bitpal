#!/bin/sh

bitcoind -datadir=$HOME/.bchn -rpcpassword=password -rpcuser=username -alertnotify="$HOME/code/bitpal/ext/notify.sh 'bch:alert-notify' %s" -blocknotify="$HOME/code/bitpal/ext/notify.sh 'bch:block-notify' %s" -walletnotify="$HOME/code/bitpal/ext/notify.sh 'bch:wallet-notify' %w %s"
