#!/bin/bash
# Restore the stock on-screen keyboard (removes the layout wrapper).
# Run on the phone:  bash restore-stock-osk.sh
set -e
BIN=/usr/bin/phosh-osk-stub
if [ -e /usr/bin/phosh-osk-stevia ] || [ -e /usr/bin/phosh-osk-stevia.distrib ]; then
    BIN=/usr/bin/phosh-osk-stevia
fi
sudo rm -f "$BIN"
sudo dpkg-divert --local --rename --remove "$BIN"
ls -la "$BIN"*
echo "Stock binary restored. Modified layouts remain in ~/.local/share/phosh-osk-stub/layouts."
