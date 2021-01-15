Installing Flowee
=================

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
