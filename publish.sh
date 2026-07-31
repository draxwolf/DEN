#!/usr/bin/env bash
# Publish the board to Cloudflare Pages.
#
#   ./publish.sh                        deploy the board.json sitting here
#   ./publish.sh ~/Downloads/board.json take that export first, then deploy
#   ./publish.sh -n                     validate and stage only, don't deploy
#
# Only index.html, board.json and _headers are uploaded. The deploy is staged
# in a temp directory so nothing else in this folder — backups, screenshots,
# the git history — can ride along by accident.
#
# One-time setup:
#   npx wrangler login
#   npx wrangler pages project create den --production-branch main
#
# Override the project name with DEN_PROJECT=... if you called it something else.

set -euo pipefail

PROJECT="${DEN_PROJECT:-den}"
BRANCH="${DEN_BRANCH:-main}"

cd "$(dirname "${BASH_SOURCE[0]}")"

dry=0
if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--dry-run" ]; then dry=1; shift; fi
src="${1:-}"

# An export straight out of the browser lands in ~/Downloads. Take it when it's
# newer than what we last published, so the everyday case is a bare publish.sh.
if [ -z "$src" ] && [ -f "$HOME/Downloads/board.json" ] &&
   [ "$HOME/Downloads/board.json" -nt board.json ]; then
  src="$HOME/Downloads/board.json"
  echo "Newer export found: $src"
fi

check() {
  node -e '
    const fs = require("fs");
    const p = process.argv[1];
    let b;
    try { b = JSON.parse(fs.readFileSync(p, "utf8")); }
    catch (e) { console.error(`${p}: not valid JSON — ${e.message}`); process.exit(1); }
    if (b.schema !== "kanban.v1")
      { console.error(`${p}: schema is ${JSON.stringify(b.schema)}, expected "kanban.v1".`); process.exit(1); }
    if (!Array.isArray(b.lanes) || !b.lanes.length)
      { console.error(`${p}: no lanes.`); process.exit(1); }
    const cards = b.lanes.flatMap((l) => Array.isArray(l.cards) ? l.cards : []);
    const moved = cards.filter((c) => c.moved).length;
    console.log(`  ${b.title} — ${b.lanes.length} lanes, ${cards.length} cards, ${moved} with move history`);
    console.log(`  exported ${b.updated || "(undated)"}`);
    // A board with nothing on it is almost always a mis-click, not a decision.
    if (!cards.length && !process.env.FORCE)
      { console.error("  No cards. Re-run with FORCE=1 if you really mean to publish an empty board."); process.exit(1); }
  ' "$1"
}

if [ -n "$src" ]; then
  [ -f "$src" ] || { echo "No such file: $src" >&2; exit 1; }
  echo "Checking $src"
  check "$src"
  if [ -f board.json ] && ! cmp -s "$src" board.json; then
    cp board.json board.bak.json
    echo "  previous board kept as board.bak.json"
  fi
  cp "$src" board.json
else
  [ -f board.json ] || { echo "No board.json here. Export one, or pass its path." >&2; exit 1; }
  echo "Checking board.json"
  check board.json
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp index.html board.json _headers "$stage/"
echo "Staged: $(cd "$stage" && ls | tr '\n' ' ')"

if [ "$dry" = 1 ]; then
  echo "Dry run — not deploying."
  exit 0
fi

npx --yes wrangler@4 pages deploy "$stage" \
  --project-name="$PROJECT" \
  --branch="$BRANCH" \
  --commit-dirty=true \
  --commit-message="board $(date -u +%Y-%m-%dT%H:%M:%SZ)"
