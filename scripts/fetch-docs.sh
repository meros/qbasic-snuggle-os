#!/usr/bin/env bash
# Download QBasic reference material into docs/qbasic/ (gitignored: third-party text).
#   Wikibooks "QBasic"  CC BY-SA 4.0  the tutorial book, graphics chapters included
#   QB64 Phoenix wiki   keyword pages with syntax and runnable examples
# The QB64 wiki marks every keyword page with its QBasic/QB64 availability.
# Read that before you trust a page for QBasic 1.1: QB64 adds many extensions.
# QBasic 1.1 itself ships its own reference in QBASIC.HLP, inside qb11.zip.
set -euo pipefail

out="$(cd "$(dirname "$0")/.." && pwd)/docs/qbasic"
mkdir -p "$out/wikibooks" "$out/qb64wiki"

wb_pages=(
  "QBasic" "QBasic/Graphics" "QBasic/Advanced Graphics" "QBasic/Images"
  "QBasic/Advanced Input" "QBasic/Basic Input" "QBasic/Subroutines and Functions"
  "QBasic/Arrays and Types" "QBasic/Text Output" "QBasic/Advanced Text Output"
  "QBasic/Code Snippets" "QBasic/Sample Programs" "QBasic/Appendix"
)

# Graphics, memory, port and mouse keywords the Snuggle OS source uses or needs.
kw_pages=(
  SCREEN "SCREEN (statement)" PSET PRESET LINE CIRCLE PAINT DRAW COLOR PALETTE
  "PALETTE USING" GET "GET (graphics statement)" "PUT (graphics statement)" VIEW
  "VIEW (statement)" WINDOW PCOPY POINT CLS LOCATE PRINT OUT INP WAIT
  "DEF SEG" PEEK POKE VARSEG SADD "CALL ABSOLUTE" INTERRUPT INTERRUPTX
  "Screen pages" "Screen mode" "SCREEN 12" "SCREEN 9" "Mouse programming"
  TIMER SLEEP "DO...LOOP" "SELECT CASE" "SUB" FUNCTION "DIM" SHARED "STATIC" '$DYNAMIC'
  '$INCLUDE' '$STATIC' "OPEN" "BINARY" "INKEY$" "INPUT$" "INSTR" "MID$" "CHR$" "ASC"
  "Bitmaps" "Bitwise operations" "Binary" "Hexadecimal" "Page flipping" "Animation"
)

fetch() { # url dest
  curl -fsS -m 60 --retry 3 --retry-delay 2 -o "$2" "$1" || { rm -f "$2"; return 1; }
}

slug() { printf '%s' "$1" | tr ' /()$' '_____' | tr -s '_'; }

for p in "${wb_pages[@]}"; do
  dest="$out/wikibooks/$(slug "$p").wiki"
  fetch "https://en.wikibooks.org/w/index.php?action=raw&title=$(printf '%s' "$p" | sed 's/ /_/g')" "$dest" \
    && echo "ok   wikibooks $p" || echo "miss wikibooks $p"
  sleep 1
done

for p in "${kw_pages[@]}"; do
  dest="$out/qb64wiki/$(slug "$p").wiki"
  fetch "https://qb64phoenix.com/qb64wiki/index.php?action=raw&title=$(printf '%s' "$p" | sed 's/ /_/g')" "$dest" \
    && echo "ok   qb64wiki  $p" || echo "miss qb64wiki  $p"
  sleep 1
done

# A raw wiki redirect or an empty page is not documentation: drop it.
find "$out" -name '*.wiki' -size -200c -print -delete | sed 's/^/drop  /'

date -u +"fetched %Y-%m-%dT%H:%M:%SZ" > "$out/FETCHED"
echo "Docs in $out"
