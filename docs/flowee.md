# Installing Flowee

Just some quick instructions to get started.

## Arch Linux

These are installation instructions for Arch Linux.

Download the PKGBUILD: https://aur.archlinux.org/packages/flowee/

- wget https://aur.archlinux.org/cgit/aur.git/snapshot/flowee.tar.gz
- tar xvzf flowee.tar.gz
- cd flowee/
- sudo pacman -S libevent
- makepkg
- Add the line `#define GIT_COMMIT_ID "x"` to the file src/build/include/build.h
- `sudo pacman -U flowee-2020.08.2-1-x86_64.pkg.tar.zst`
- Data will be in /var/lib/flowee - make sure you have lots of disk space for that. Recommended is 250 GB
- If you create it, make sure the user "flowee" can write to it.
- sudo systemctl enable thehub.service
- sudo systemctl start thehub.service

For the indexer:
- sudo systemctl enable indexer.service
- sudo systemctl start indexer.service

Enable address indexing (so that we can quickly recover transactions for our account):
- edit /etc/flowee/indexer.conf
- Under the [addressdb] section, set "db_driver" to "true" and add a database as suitable.
- I have tried QSQLITE. That one does not require any additional settings. It is stored in /var/lib/flowee/addresses/
- The SQLite DB will be one or two gigabytes

To speed up indexing and reduce disk space, it might be beneficial to disable "spentdb" and maybe "txdb". We don't use those.

## Void linux

```
sudo xbps-install -Su libevent-devel boost-devel
```

(Maybe something else that I've already installed previously)

## Ubuntu

Sometimes we also need to do:

```
apt-get install erlang-xmerl
```
