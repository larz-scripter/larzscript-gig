#!/bin/sh
# A narrated walkthrough - a contract with two milestones. One is
# approved cleanly. The other is disputed and resolved with a 60/40
# split, which reconciles fine. Then a second contract shows the split
# logic's real edge: a 50/50 split on an odd-cent amount that rounds to
# a cent more than was ever locked, and gets refused outright instead
# of silently minting it. Run from the repo root: sh examples/demo.sh
set -e
DB="/tmp/larzgig-demo-$$.json"
rm -f "$DB"
LARZGIG="larzscript bin/larzgig.lz --board=$DB"

echo "--- fund a client (demo-only faucet) ---"
$LARZGIG fund cara 500

echo "--- cara hires sam for a two-milestone contract - the FULL budget escrows now ---"
$LARZGIG create cara sam "Landing page" Wireframes 100 Build 300
id="$($LARZGIG list | awk 'NR==3{print $2}')"
$LARZGIG balance cara
$LARZGIG show "$id"

echo "--- milestone 0: sam submits, cara approves - pays out immediately ---"
$LARZGIG submit "$id" 0
$LARZGIG approve "$id" 0
$LARZGIG balance sam

echo "--- milestone 1: cara isn't happy with the build - disputes it ---"
$LARZGIG submit "$id" 1
$LARZGIG dispute "$id" 1 "build doesn't match the wireframes"

echo "--- an arbiter looks at it and splits it 60/40 in sam's favor ---"
$LARZGIG resolve "$id" 1 0.6 "partial credit - scope was ambiguous"
$LARZGIG balance sam
$LARZGIG balance cara
$LARZGIG show "$id"
$LARZGIG reputation sam

echo
echo "--- second contract: an odd-cent milestone, disputed, split 50/50 ---"
$LARZGIG create cara sam2 "Odd amount test" Design 10.01
id2="$($LARZGIG list | awk 'NR==3{print $2}')"
$LARZGIG submit "$id2" 0
$LARZGIG dispute "$id2" 0 "test rounding"
echo "--- 10.01 * 0.5 rounds to 5.01 on BOTH sides - that's \$10.02, a cent more than was ever locked ---"
$LARZGIG resolve "$id2" 0 0.5 "50/50 split" || true
echo "--- refused - nobody got paid, the \$10.01 is still sitting exactly where it was ---"
$LARZGIG balance cara
$LARZGIG balance sam2
$LARZGIG show "$id2"

rm -f "$DB"
