#!/bin/sh
set -e
DB="tests/data/basic.json"
rm -f "$DB"
G="$LARZGIG --board=$DB"

$G fund cara 500
$G create cara sam "Landing page" Wireframes 100 Build 300
id="$($G list | awk 'NR==3{print $2}')"
$G balance cara
$G show "$id"

$G submit "$id" 0
$G approve "$id" 0
$G balance sam

$G submit "$id" 1
$G dispute "$id" 1 "build doesn't match the wireframes"
$G resolve "$id" 1 0.6 "partial credit - scope was ambiguous"
$G balance sam
$G balance cara
$G show "$id"
$G reputation sam
