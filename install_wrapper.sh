#!/bin/bash
# Install a wrapper at the keyboard binary path that points G_RESOURCE_OVERLAYS
# at the locally generated layouts and stylesheet.  The real binary is kept as
# <binary>.distrib via dpkg-divert, so package upgrades still land and the
# wrapper keeps working.
#
# Works with both names of the keyboard:
#   /usr/bin/phosh-osk-stub     (phosh-osk-stub, <= 0.47)
#   /usr/bin/phosh-osk-stevia   (phosh-osk-stevia, >= 0.48)
#
# Run from a checkout:  sudo bash install_wrapper.sh
set -e

BIN=/usr/bin/phosh-osk-stub
if [ -x /usr/bin/phosh-osk-stevia ]; then
    BIN=/usr/bin/phosh-osk-stevia
fi
echo "keyboard binary: $BIN"
[ -x "$BIN" ] || { echo "error: $BIN not found" >&2; exit 1; }

cat > /tmp/phosh-osk-stub-wrapper <<'WRAP'
#!/bin/sh
# Local wrapper: load the tweaked layouts and stylesheet for the on-screen
# keyboard.  Installed via dpkg-divert; the real binary is <binary>.distrib.
BASE="${HOME:-/home/droidian}/.local/share/phosh-osk-stub"
OVERLAY="/mobi/phosh/stevia/layouts=$BASE/layouts"
OVERLAY="$OVERLAY:/mobi/phosh/stevia/stylesheet=$BASE/stylesheet"
OVERLAY="$OVERLAY:/mobi/phosh/osk-stub/layouts=$BASE/layouts"
OVERLAY="$OVERLAY:/mobi/phosh/osk-stub/stylesheet=$BASE/stylesheet"
if [ -n "$G_RESOURCE_OVERLAYS" ]; then
    G_RESOURCE_OVERLAYS="$G_RESOURCE_OVERLAYS:$OVERLAY"
else
    G_RESOURCE_OVERLAYS="$OVERLAY"
fi
export G_RESOURCE_OVERLAYS
exec __BIN__.distrib "$@"
WRAP
sed -i "s|__BIN__|$BIN|" /tmp/phosh-osk-stub-wrapper
chmod 755 /tmp/phosh-osk-stub-wrapper

# Only divert on first install; later runs just refresh the wrapper.
if ! dpkg-divert --list | grep -q "^diversion of $BIN "; then
    sudo dpkg-divert --local --rename --add "$BIN"
fi
sudo cp /tmp/phosh-osk-stub-wrapper "$BIN"
sudo chmod 755 "$BIN"

ls -la "$BIN"*
echo ---
head -20 "$BIN"
echo ---
dpkg-divert --list | grep phosh-osk || true
