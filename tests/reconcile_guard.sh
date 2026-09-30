#!/bin/sh
# A 50/50 split on a $10.01 milestone rounds to $5.01 on BOTH sides
# (round(10.01*0.5, 2) = 5.01), which sums to $10.02 - one cent more
# than was ever actually locked. The require in resolve_dispute() must
# refuse this split outright rather than silently mint a cent.
set -e
DB="tests/data/reconcile_guard.json"
rm -f "$DB"
G="$LARZGIG --board=$DB"

$G fund cara 100
$G create cara sam "Odd amount test" Design 10.01
id="$($G list | awk 'NR==3{print $2}')"
$G submit "$id" 0
$G dispute "$id" 0 "test rounding"
$G resolve "$id" 0 0.5 "50/50 split" || true
$G balance cara
$G balance sam
$G show "$id"
