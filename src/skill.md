---
name: clips
description: >
  Read and drive the Omarchy clipboard history with the clips command. Use when
  asked to find something copied earlier, put a clip back on the clipboard,
  open a copied link or image, inspect a saved history snapshot, or work with
  the clipboard from a script or agent. No window is opened and the history
  file is only ever read.
  Triggers: clipboard, copied, clip, paste, clipboard history, find a link,
  find an image, Omarchy clipboard.
---

# Clips

Clips is the read-only viewer for Omarchy's clipboard history at
`~/.local/state/omarchy/clipboard-history.json`. The same binary has a headless
interface: every command below exits immediately, opens no window, and never
writes to the history file. The Omarchy shell owns that file.

## Install

```sh
git clone https://github.com/benfoos-code/clips.git
cd clips
./bin/install          # Arch package, installed with sudo
# or: ./bin/install-user  # user-only install

clips skill install    # writes ~/.agents/skills/clips/SKILL.md
                       # and links ~/.claude/skills/clips when ~/.claude exists
```

`clips skill` prints this manual without installing it. `clips help` lists the
commands, and `clips help <command>` prints that command's options.

## Commands

```sh
clips list [--limit N] [--json]   # newest first; text and images
clips search <query> [--json]     # same list, filtered
clips latest [--json]             # just the newest clip
clips copy <index>                # put the clip back with wl-copy
clips open <index>                # open with omarchy-clipboard-open
```

`--history <path>` works with every command, before or after the command:

```sh
clips --history /tmp/snapshot.json list --json
clips list --history /tmp/snapshot.json --json
```

Indices come from `list`, `search`, or `latest` and are the positions in the
history file. Copy and open print what they acted on. Success exits 0; failure
prints one line to stderr and exits non-zero.

### JSON

`list`, `search`, and `latest --json` always return the same shape:

```json
{
  "count": 2,
  "entries": [
    {
      "index": 0,
      "time": "",
      "type": "text",
      "preview": "https://omarchy.org — a beautiful, fun, agentic Arch Linux distribution"
    },
    {
      "index": 2,
      "time": "Friday 18:04",
      "type": "image",
      "preview": "/home/benfoos/Pictures/shot.png"
    }
  ]
}
```

`count` is the number of returned entries. `time`, `type`, and `preview` are
always present as strings; `index` is always an integer. Text previews have
whitespace collapsed and are capped at 120 characters; image previews are the
image path. Omarchy stores `capturedAt` only for images, so `time` is `""` for
text clips (shown as `—` in human output). Entries are always newest first;
that order is the only chronology available for text clips.

Search matches the clip text, plus the words `image`, the MIME type, and the
captured time for images. Queries are case-insensitive.

## Worked example: find a link copied yesterday and put it back

Text clips have no stored timestamp, so search by a distinctive word in the
link rather than by date; the newest-first order tells you which of several
matches was copied last.

```sh
# Show matching links as JSON, then pick the right index from the previews.
clips search "omarchy.org" --json

# Or scan recent previews if you only remember part of the address.
clips list --limit 100 --json | jq -r '.entries[] | [.index, .preview] | @tsv'

# Put that link back on the clipboard.
clips copy 3
```

## Worked example: pull the newest image

```sh
# Images are searchable by the word "image"; the first result is the newest.
clips search image --json

INDEX=$(clips search image --json | jq -r '.entries[0].index')
clips copy "$INDEX"   # image bytes + MIME type go to wl-copy
clips open "$INDEX"   # opens in Omarchy's own image viewer
```

`clips latest` returns the newest clip overall, which may be text; use
`clips search image` when you specifically need an image.
