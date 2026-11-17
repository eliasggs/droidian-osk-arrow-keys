# Arrow keys (and a red ESC) for the Droidian on-screen keyboard

Droidian's on-screen keyboard is **phosh-osk-stub**, renamed **phosh-osk-stevia**
in 0.48 (upstream: [World/Phosh/stevia](https://gitlab.gnome.org/World/Phosh/stevia)).
Its layouts are JSON files compiled into the binary as GResource data, and it
ships without cursor keys — painful when editing a command line on a phone.

This adds a row of arrow keys to **every** layout:

```
←  ↑  ↓  →
```

and, in the **terminal** layout, moves the layout's own `ESC` key out of the
second row into that row, at the left and painted red:

```
ESC  ←  ↑  ↓  →
```

![Terminal layout with the red ESC key left of the arrows](screenshots/terminal-esc.png)

## Install

### One command

Open the terminal on the phone (GNOME Console, or any terminal app) and
copy-paste this single line:

```sh
wget -qO- https://raw.githubusercontent.com/eliasggs/droidian-osk-arrow-keys/main/install.sh | bash
```

It checks the prerequisites, asks for your password once (for `sudo`), installs
the wrapper, generates the layouts and stylesheet and restarts the keyboard.
If you have `curl` instead of `wget`, `curl -fsSL <same url> | bash` works too.
Running it again is safe: it refreshes everything.

### Step by step

On the phone, from a checkout:

```sh
git clone https://github.com/eliasggs/droidian-osk-arrow-keys
cd droidian-osk-arrow-keys
sudo bash install_wrapper.sh     # dpkg-divert + G_RESOURCE_OVERLAYS wrapper
python3 generate_layouts.py      # writes ~/.local/share/phosh-osk-stub/{layouts,stylesheet}
pkill -f 'phosh-osk-stub|phosh-osk-stevia'   # phosh restarts the keyboard
```

`generate_layouts.py` must run as the **user** (it writes under `$HOME`), the
wrapper install must run as **root**. The keyboard comes back on its own when
phosh restarts it; otherwise log out/in or reboot.

Both scripts detect the keyboard that is installed:

| Package | Binary | Resources |
| --- | --- | --- |
| `phosh-osk-stub` ≤ 0.47 | `/usr/bin/phosh-osk-stub` | `/mobi/phosh/osk-stub/…` |
| `phosh-osk-stevia` ≥ 0.48 | `/usr/bin/phosh-osk-stevia` | `/mobi/phosh/stevia/…` |

To remove it again:

```sh
bash restore-stock-osk.sh
```

## How it works

1. `generate_layouts.py` reads every layout embedded in the real binary with
   `gresource extract`, inserts the arrow row at the **top of every level**
   (default, shift, symbols, symbols+shift) and writes the modified JSON to
   `~/.local/share/phosh-osk-stub/layouts/`.

   The row goes to the top on purpose: the keyboard appends its shift/backspace
   row and its `123`/globe/space/enter row to the **last two** rows of every
   level, so inserting anywhere else breaks those special rows.

   For `terminal.json` the script first removes the layout's `KEY_ESC` key from
   its old position (end of the second row) and re-adds it as the first key of
   the arrow row, with the same width as the arrows and the style class `esc`.

2. `~/.local/share/phosh-osk-stub/stylesheet/common.css` is a copy of the
   stylesheet compiled into the binary with one block appended:

   ```css
   pos-key.esc {
     background: #c01c28;
     color: #ffffff;
   }
   ```

   The keyboard only knows the CSS classes compiled into it (`sys`, `toggle`,
   `return`), so a local class is needed for the red key. The block is appended
   so it wins over the stock `pos-key` and `pos-key.pressed` rules.

3. The real binary is replaced by a small wrapper; it is kept next to it as
   `<binary>.distrib` via `dpkg-divert`. The wrapper appends the overlay
   prefixes (both the `stevia` and the `osk-stub` resource paths, so the same
   files work with either package) to `G_RESOURCE_OVERLAYS`. A package upgrade
   lands the new binary at `.distrib` and the wrapper keeps working.

   GResource overlays fall back to the built-in resource when a file is missing
   from the overlay directory, so only `common.css` is generated: the stock
   theme files (`adwaita-dark.css`, `adwaita-hc-light.css`) keep being used and
   both of them `@import` `common.css`, which keeps the red key correct in the
   dark and the high-contrast themes.

## Customising

* **Colour** — edit `ESC_CSS` at the top of `generate_layouts.py`, then re-run it
  and restart the keyboard.
* **Which layouts get the arrow row** — the script adds it to every layout; drop
  the insert from the loop if you only want a few.
* **Arrow size** — `arrow_width()` picks 1, 1.5 or 2 key widths depending on how
  wide the layout is.
* **ESC position/width** — `esc_key()` in the terminal branch.

## Notes

* Tested on Droidian 101 (Xiaomi "fog", aarch64) with `phosh` 0.49.0 and
  `phosh-osk-stevia` 0.49.0 (built from `droidian/phosh-osk-stub`,
  `group/next/phosh-0.49`), and earlier with `phosh-osk-stub` 0.47.0.
* After a keyboard package upgrade, re-run `python3 generate_layouts.py` so the
  overlay matches the new layouts and stylesheet.
* Upstream 0.56 added cursor keys as buttons in the terminal *shortcuts bar* and
  0.57 moved `tab`/`esc` to the completion bar; this mod keeps a full arrow row
  on every layout instead. If you run those versions the ESC branch finds no
  `KEY_ESC` and only adds the arrows (it prints a warning).
* The arrow keys talk the normal virtual-keyboard protocol (`KEY_LEFT`,
  `KEY_UP`, `KEY_DOWN`, `KEY_RIGHT`), and the moved ESC still sends `KEY_ESC` —
  the modification only changes the JSON layout, never the key codes.

## License

GPL-3.0-or-later, the same license as the keyboard: the generated layouts are
derived from the layout resources shipped in its binary.
