#!/usr/bin/env bash
# Lints every src/href/poster on the pages: local files exist, remote URLs 200,
# nothing points at the private app repo.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE="https://nkunal1992.github.io/Trakisilo-site"
fail=0
cd "$HERE"

grep -ohE '(src|href|poster)="[^"#][^"]*"' index.html features.html download.html 404.html 2>/dev/null \
  | sed -E 's/^[a-z]+="//; s/"$//' | sort -u | while read -r u; do
  case "$u" in
    https://github.com/nkunal1992/Trakisilo|https://github.com/nkunal1992/Trakisilo/*|http://github.com/nkunal1992/Trakisilo*)
      echo "PRIVATE-LINK $u"; exit 1 ;;
    http*|mailto:*) echo "EXT  $u" ;;
    *) f="${u%%#*}"; [ -f "$f" ] && echo "ok   $u" || { echo "MISS $u"; exit 1; } ;;
  esac
done > /tmp/site-links.txt || true

cat /tmp/site-links.txt
grep -c "^EXT" /tmp/site-links.txt | xargs echo "external links:"
grep -c "^ok"  /tmp/site-links.txt | xargs echo "local files ok:"
grep  "^MISS\|PRIVATE-LINK" /tmp/site-links.txt && fail=1

# live check
for u in $(awk '/^(ok|MISS)/{print $2}' /tmp/site-links.txt); do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$BASE/$u")
  [ "$code" = 200 ] || { echo "LIVE-$code $u"; fail=1; }
done

# the stable macOS download link must resolve through the latest-release redirect
code=$(curl -s -o /dev/null -w '%{http_code}' -L --max-time 30 \
  "https://github.com/nkunal1992/Trakisilo-site/releases/latest/download/Trakisilo-macOS-universal.dmg")
[ "$code" = 200 ] || { echo "DMG-$code stable macOS download link"; fail=1; }

[ "$fail" = 0 ] && echo "ALL GREEN" || exit 1
