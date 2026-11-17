#!/bin/bash
# One-command installer for the arrow-key / red-ESC keyboard mod.
#
#   wget -qO- https://raw.githubusercontent.com/eliasggs/droidian-osk-arrow-keys/main/install.sh | bash
#
# It checks the prerequisites, installs the G_RESOURCE_OVERLAYS wrapper
# (dpkg-divert, needs sudo), generates the layouts and stylesheet under
# ~/.local/share/phosh-osk-stub and restarts the on-screen keyboard.
#
# It is safe to run again: it refreshes the files and the wrapper.
set -e

REPO="eliasggs/droidian-osk-arrow-keys"
REF="${OSK_REF:-main}"
BASE="https://raw.githubusercontent.com/$REPO/$REF"
DEST="$HOME/.local/share/phosh-osk-stub"
FILES="generate_layouts.py install_wrapper.sh restore-stock-osk.sh"

die() { echo "error: $*" >&2; exit 1; }

echo "== phosh-osk-stub arrow keys + red ESC: installer =="

# The layouts must be generated as the user whose session runs the keyboard.
if [ "$(id -u)" -eq 0 ]; then
    die "run this as your normal user, not as root (it calls sudo where needed)"
fi

for bin in python3 gresource; do
    command -v "$bin" >/dev/null 2>&1 ||
        die "'$bin' not found. Install it with: sudo apt install python3 libglib2.0-bin"
done
[ -x /usr/bin/phosh-osk-stub ] ||
    die "phosh-osk-stub is not installed (expected /usr/bin/phosh-osk-stub)"

# Use the files next to this script when running from a checkout, otherwise
# download them from the repository.
SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
SRC_DIR=
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/generate_layouts.py" ] &&
   [ -f "$SELF_DIR/install_wrapper.sh" ]; then
    echo "source: local checkout $SELF_DIR"
    SRC_DIR=$SELF_DIR
else
    echo "source: $BASE"
fi

fetch() {  # url dest
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$1" -o "$2"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$2" "$1"
    else
        die "need curl or wget to download the scripts"
    fi
}

mkdir -p "$DEST"
for f in $FILES; do
    if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$f" ]; then
        cp "$SRC_DIR/$f" "$DEST/$f"
    else
        fetch "$BASE/$f" "$DEST/$f"
    fi
done
chmod +x "$DEST"/*.py "$DEST"/*.sh 2>/dev/null || true
echo "scripts installed in $DEST"

echo
echo "== Installing the keyboard wrapper (sudo) =="
sudo bash "$DEST/install_wrapper.sh"

echo
echo "== Generating layouts and stylesheet =="
python3 "$DEST/generate_layouts.py"

echo
echo "== Restarting the on-screen keyboard =="
OSK_PATTERN='^/usr/bin/phosh-osk-(stub|stevia)'
OSK_LOG="${TMPDIR:-/tmp}/phosh-osk-stub-install.log"

# phosh normally restarts the keyboard, but it can take a while.  Owning the
# DBus name is the real test that the keyboard is usable again.
name_owner() {
    gdbus call --session --dest org.freedesktop.DBus \
        --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.GetNameOwner sm.puri.OSK0 2>/dev/null |
        sed -n "s/.*'\([^']*\)'.*/\1/p"
}

wait_osk() {  # seconds
    _left=$1
    while [ "$_left" -gt 0 ]; do
        [ -n "$(name_owner)" ] && return 0
        sleep 1
        _left=$((_left - 1))
    done
    [ -n "$(name_owner)" ]
}

pkill -f "$OSK_PATTERN" 2>/dev/null || true

# Let the old instance drop the DBus name before looking for the new one,
# otherwise we would mistake the dying process for the restarted keyboard.
_left=5
while [ "$_left" -gt 0 ] && [ -n "$(name_owner)" ]; do
    sleep 1
    _left=$((_left - 1))
done

if wait_osk 20; then
    echo "keyboard restarted"
else
    echo "phosh did not restart it, starting it manually"
    setsid /usr/bin/phosh-osk-stub --allow-replacement >"$OSK_LOG" 2>&1 </dev/null &
    if wait_osk 10; then
        echo "keyboard started manually"
    else
        echo "--- $OSK_LOG ---" >&2
        tail -n 20 "$OSK_LOG" >&2 2>/dev/null || true
        die "the keyboard did not come back; reboot the phone"
    fi
fi

echo
echo "== Done =="
echo "Layouts: $(ls "$DEST/layouts" | wc -l) files in $DEST/layouts"
echo "Open a terminal (Console) in the phone: a red ESC key is the first key of"
echo "the arrow row, and the arrows move the cursor."
