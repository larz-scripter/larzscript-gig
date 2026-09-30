#!/bin/sh
# A too-short/empty id must fail cleanly, not silently match the first
# contract iterated over - see bin/larzgig.lz's _find_by_prefix(). Also
# covers a couple of ordinary status-guard rejections (approving a
# milestone that hasn't been submitted yet, disputing one that's already
# approved).
set -e
DB="tests/data/guard.json"
rm -f "$DB"
G="$LARZGIG --board=$DB"

$G fund cara 100
$G create cara sam "Only Contract" Design 50
id="$($G list | awk 'NR==3{print $2}')"
$G show "" || true
$G show "ab" || true
$G approve "$id" 0 || true
$G submit "$id" 0
$G approve "$id" 0
$G dispute "$id" 0 "too late, already approved" || true
