#!/bin/bash
# Install a wrapper at /usr/bin/phosh-osk-stub that points G_RESOURCE_OVERLAYS
# at the locally generated layouts and stylesheet.  The real binary is kept as
# /usr/bin/phosh-osk-stub.distrib via dpkg-divert, so package upgrades still
# land and the wrapper keeps working.
#
# Run from a checkout:  sudo bash install_wrapper.sh
set -e

cat > /tmp/phosh-osk-stub-wrapper <<'WRAP'
#!/bin/sh
# Local wrapper: load the tweaked layouts and stylesheet for phosh-osk-stub.
# Installed via dpkg-divert; the real binary is phosh-osk-stub.distrib.
BASE="${HOME:-/home/droidian}/.local/share/phosh-osk-stub"
OVERLAY="/mobi/phosh/osk-stub/layouts=$BASE/layouts:/mobi/phosh/osk-stub/stylesheet=$BASE/stylesheet"
if [ -n "$G_RESOURCE_OVERLAYS" ]; then
    G_RESOURCE_OVERLAYS="$G_RESOURCE_OVERLAYS:$OVERLAY"
else
    G_RESOURCE_OVERLAYS="$OVERLAY"
fi
export G_RESOURCE_OVERLAYS
exec /usr/bin/phosh-osk-stub.distrib "$@"
WRAP
chmod 755 /tmp/phosh-osk-stub-wrapper

# Only divert on first install; later runs just refresh the wrapper.
if ! dpkg-divert --list | grep -q '^diversion of /usr/bin/phosh-osk-stub '; then
    sudo dpkg-divert --local --rename --add /usr/bin/phosh-osk-stub
fi
sudo cp /tmp/phosh-osk-stub-wrapper /usr/bin/phosh-osk-stub
sudo chmod 755 /usr/bin/phosh-osk-stub

ls -la /usr/bin/phosh-osk-stub*
echo ---
head -20 /usr/bin/phosh-osk-stub
echo ---
dpkg-divert --list | grep phosh-osk || true
