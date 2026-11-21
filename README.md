# Clips

Browse the Omarchy clipboard history and copy an entry back, from a quiet,
refined window that stays out of the way.

![Clips showing a clipboard history](screenshot.png)

Clips reads the history the Omarchy shell already keeps at
`~/.local/state/omarchy/clipboard-history.json` — newest first, text and
images — and copies the highlighted entry back to the clipboard. It is
read-only: the shell owns the file, so Clips never writes to it.

## Shortcuts

| Key            | Action                              |
| -------------- | ----------------------------------- |
| `↑` `↓` / `J` `K` | Move the selection               |
| `g` / `G`      | Jump to the first / last entry      |
| `Space`        | Copy the highlighted entry          |
| `Enter`        | Open the highlighted entry          |
| `/` / `Ctrl+F` | Search                              |
| `Esc`          | Clear the search                    |
| `?`            | Show every shortcut                 |
| `Q`            | Quit                                |

Copy and Open are on screen next to the search box, each with its key shown on
the button; on a narrow window the keycaps step aside so search keeps its room.
The footer keeps the common keys visible, and `?` opens a grouped shortcut
sheet. Actions confirm in a floating pill, with errors in a different colour.

Copying a text entry puts it back on the clipboard with `wl-copy`; copying an
image puts the image back. Opening an entry hands it to Omarchy's own opener
(`omarchy-clipboard-open`), so a URL opens in the browser, text opens in the
editor, and an image opens in the snapshot viewer.

## Install

```sh
bin/install-user   # into ~/.local, no password
bin/install        # a system-wide Arch package, from a terminal
```

`bin/install-user` puts the binary in `~/.local/bin`, the icon in
`~/.local/share/icons`, and the launcher entry in
`~/.local/share/applications`, so Clips shows up in the Omarchy launcher
(`Super + Space`) without a password. `bin/install` builds the package in
`pkgbuild/` and installs it with `makepkg -fsi`, which needs root.

## Build and test

```sh
bin/build   # qmake6 + make into build/clips
bin/test    # the Qt Test binary, run offscreen
```

The window follows the Omarchy accent and Hyprland's window rounding live, and
the strings follow the language picked under Setup > Language (`src/i18n/`).

`clips --history <path>` reads another history file, which is handy for looking
at a snapshot without touching the live one.

## License

MIT. The project layout and the theme and translator classes follow Omacut and
Monologue (MIT, David Heinemeier Hansson), the templates Omarchy's
`omarchy-app` skill ships.
