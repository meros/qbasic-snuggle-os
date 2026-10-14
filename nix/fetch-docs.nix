# Downloads QBasic reference pages into docs/qbasic (not committed: third party
# text). The QB64 wiki marks each keyword page with its QBasic or QB64
# availability; read that before you trust a page for QBasic 1.1.
{ writeShellApplication, curl, coreutils, gnused, findutils }:
writeShellApplication {
  name = "snuggle-fetch-docs";
  runtimeInputs = [ curl coreutils gnused findutils ];
  text = ''
    out="''${1:-docs/qbasic}"
    mkdir -p "$out/wikibooks" "$out/qb64wiki"
    slug() { printf '%s' "$1" | tr ' /()$' '_____' | tr -s '_'; }
    fetch() { curl -fsS -m 60 --retry 3 --retry-delay 2 -o "$2" "$1" || { rm -f "$2"; return 1; }; }

    for p in "QBasic" "QBasic/Graphics" "QBasic/Advanced Graphics" "QBasic/Images" \
             "QBasic/Advanced Input" "QBasic/Basic Input" "QBasic/Subroutines and Functions" \
             "QBasic/Arrays and Types" "QBasic/Text Output" "QBasic/Code Snippets"; do
      if fetch "https://en.wikibooks.org/w/index.php?action=raw&title=$(printf '%s' "$p" | sed 's/ /_/g')" "$out/wikibooks/$(slug "$p").wiki"; then
        echo "ok   wikibooks $p"; else echo "miss wikibooks $p"; fi
      sleep 1
    done
    for p in SCREEN PSET LINE CIRCLE PAINT COLOR PALETTE GET PUT VIEW WINDOW POINT PRINT OUT INP \
             "DEF SEG" PEEK POKE VARSEG SADD "CALL ABSOLUTE" TIMER "SELECT CASE" DIM SHARED \
             OPEN BINARY INKEY\$ INSTR MKD\$ CVD; do
      if fetch "https://qb64phoenix.com/qb64wiki/index.php?action=raw&title=$(printf '%s' "$p" | sed 's/ /_/g')" "$out/qb64wiki/$(slug "$p").wiki"; then
        echo "ok   qb64wiki  $p"; else echo "miss qb64wiki  $p"; fi
      sleep 1
    done
    # a raw redirect or an empty page is not documentation
    find "$out" -name '*.wiki' -size -200c -print -delete | sed 's/^/drop  /'
    date -u +"fetched %Y-%m-%dT%H:%M:%SZ" > "$out/FETCHED"
  '';
}
