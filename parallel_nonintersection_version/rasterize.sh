#!/usr/bin/env bash
# Rasterize every .svg in this folder to a PNG of SIZE x SIZE in ./rasterized
#
# Uses headless Chrome (or Edge), which is already on this machine -- no install.
# The SVGs carry width/height but no viewBox, so they cannot simply be scaled by
# a CSS size; instead the browser window is set to the SVG's own size and the
# device scale factor does the magnification, which keeps it vector-crisp.
#
# Usage:  ./rasterize.sh [SIZE]        (default 2000)

set -u
SIZE="${1:-2000}"
OUT="rasterized"

for CANDIDATE in \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
do
  [ -f "$CANDIDATE" ] && BROWSER="$CANDIDATE" && break
done

if [ -z "${BROWSER:-}" ]; then
  echo "No Chrome or Edge found." >&2
  exit 1
fi

mkdir -p "$OUT"
HERE="$(pwd -W 2>/dev/null || pwd)"
shopt -s nullglob

ok=0
fail=0
for f in *.svg; do
  base="${f%.svg}"
  png="$OUT/$base.png"

  # the SVG's own canvas size, so non-1000px outputs still land at SIZE
  dims=$(grep -o 'width="[0-9]*" height="[0-9]*"' "$f" | head -1)
  w=$(echo "$dims" | sed -n 's/.*width="\([0-9]*\)".*/\1/p')
  h=$(echo "$dims" | sed -n 's/.*height="\([0-9]*\)".*/\1/p')
  w=${w:-1000}
  h=${h:-1000}

  scale=$(python -c "print($SIZE / max($w, $h))" 2>/dev/null)
  [ -z "$scale" ] && scale=$(awk "BEGIN{print $SIZE/($w>$h?$w:$h)}")

  "$BROWSER" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --default-background-color=FFFFFFFF \
    --force-device-scale-factor="$scale" \
    --window-size="$w,$h" \
    --virtual-time-budget=20000 \
    --screenshot="$HERE/$OUT/$base.png" \
    "file:///$HERE/$f" >/dev/null 2>&1

  if [ -s "$png" ]; then
    printf "  %-16s -> %s\n" "$f" "$png"
    ok=$((ok + 1))
  else
    printf "  %-16s FAILED\n" "$f" >&2
    fail=$((fail + 1))
  fi
done

echo "rasterized $ok file(s) at ${SIZE}x${SIZE}${fail:+, $fail failed}"
