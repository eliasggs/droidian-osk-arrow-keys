#!/bin/bash
# Restore the stock phosh-osk-stub (removes the arrow-key wrapper).
# Run on the phone:  bash restore-stock-osk.sh
set -e
sudo rm -f /usr/bin/phosh-osk-stub
sudo dpkg-divert --local --rename --remove /usr/bin/phosh-osk-stub
ls -la /usr/bin/phosh-osk-stub*
echo "Stock binary restored. Modified layouts remain in ~/.local/share/phosh-osk-stub/layouts."
