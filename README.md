# DEN

**D**eployable **E**verywhere **N**oticeboard is a single-file, easily deployable project management site with vimkeys support, and JSON output.

    index.html    the whole app -- markup, styles, script
    board.json    your project cards

Open `index.html` and read the instructions on the page to see the shortcuts

Editing happens in your browser's local storage. Visitors can toggle Edit too;
it only changes their own copy (local storage) and never gets uploaded. The
published board reads from `board.json`, which you'll have to update out-of-channel.

![Screenshot of the interface](screenshot.jpg?raw=true "Board")

## Deploying

**Cloudflare Pages** — direct upload, once:

    npx wrangler login
    npx wrangler pages project create den --production-branch main

then `./publish.sh` for every publish after that. It validates the JSON, keeps
the previous board as `board.bak.json`, and uploads `index.html`, `board.json`
and `_headers` out of a staging directory — nothing else in the folder can ride
along. Hand it a fresh export to take that first:

    ./publish.sh ~/Downloads/board.json
    ./publish.sh -n                       # check and stage, don't deploy

Connecting the repo to Pages' git builds instead would deploy the app *without*
a board: `board.json` is data and is deliberately gitignored.

**A custom domain** — Pages project → Custom domains → `den.example.com`. The
CNAME is created for you when the zone is on the same account. If the zone
already has a redirect rule (an apex that forwards elsewhere, say), check its
expression matches only the hostnames you meant — a rule written against
`http.host contains "example.com"` will swallow the new subdomain too.

**Any VPS** — it's static files. With Caddy:

    board.example.com {
        root * /srv/board
        file_server
    }

Then `scp index.html board.json vps:/srv/board/` after each export.

There is no `board.json` in this repo. The board renders empty until you deploy
one next to `index.html`.

## The data

```json
{
  "schema": "kanban.v1",
  "title": "Workshop",
  "lanes": [{
    "id": "l-building",
    "name": "Building",
    "tone": "hot",
    "cards": [{
      "id": "c-board",
      "title": "Public project board",
      "note": "Optional detail.",
      "tags": ["web"],
      "link": "https://example.com",
      "blockedOn": "POI 10 stability",
      "steps": [
        { "text": "code", "done": true },
        { "text": "packaged", "done": true },
        { "text": "ship", "done": false }
      ],
      "created": "2026-07-08T10:00:00Z",
      "updated": "2026-07-28T09:00:00Z",
      "moved": "2026-07-26T18:00:00Z",
      "movedFrom": "Building",
      "movedBy": 1
    }]
  }]
}
```

`tone` is one of `blue`, `hot`, `grey` (the lane's accent rule). A non-empty
`blockedOn` is what marks a card held. `moved` / `movedFrom` / `movedBy` are
stamped whenever a card crosses lanes — by drag, by `H`/`L`, by `dd`+`p` into
another lane, or from the drawer's lane picker. The card then shows
*→ moved 2d ago* in place of its edit date, tinted hot for the first three
days, with the full history (added · moved from where · edited) on hover.

`movedBy` is the signed distance: one arrow per lane crossed, rightward
positive, so `→→` came from two lanes back and `←` slipped one. Past three it
counts instead (`→×5`). Omit it in a hand-written file and it's derived from
`movedFrom`. A step may be written as a bare string
(`"steps": ["code", "ship"]`) when you're editing by hand — import expands it.
Everything else is optional; import fills in what's missing rather than
rejecting the file.

## Keyboard

Supports vim-like shortcuts.

**Move**

| | |
|---|---|
| `h` `j` `k` `l` | lane left · down · up · lane right (arrows work too) |
| `gg` / `G` | first / last card in the lane |
| `0` / `$` | leftmost / rightmost lane |
| `3j` | counts prefix any motion |

**Change** — needs edit mode, press `e` first

| | |
|---|---|
| `H` `J` `K` `L` | carry the card with the cursor (Shift+arrows too) |
| `i` or `Enter` | open the card for editing |
| `o` / `O` | new card below / above the cursor |
| `b` | set what it's waiting on · `b` again clears it |
| `Space` | tick the next open step |
| `dd` / `yy` | delete / copy into the register |
| `p` / `P` | paste below / above |
| `A` | append a lane |
| `u` / `U` | undo / redo |

**Other**

| | |
|---|---|
| `e` | toggle edit mode |
| `/` | filter — motions still work on what's left |
| `?` | the help panel |
| `Esc` | clears the count, then the filter, then the cursor |

**Checklists** — `s` drops the cursor into a card's checklist and the card opens
out; the mode line reads `STEPS`. The keys mean the same things one level down.

| | |
|---|---|
| `s` | enter the checklist — starts one if the card has none |
| `j` `k` | walk the steps |
| `Space` / `x` | tick or untick |
| `J` `K` | reorder the step |
| `o` / `O` | new step below / above |
| `i` or `Enter` | rename in place |
| `dd` | remove the step |
| `Esc` `h` `s` | back to the board |

## Testing locally

Opening `index.html` straight off disk works, but browsers block `file://` from
reading `board.json` — you'll get the sample board and a note saying so. Use
Import to pull your file in, or serve the folder:

    python3 -m http.server 8000    # then http://localhost:8000
