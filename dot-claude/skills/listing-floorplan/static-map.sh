#!/bin/sh
# Render a static OpenStreetMap image centred on a point.
# Usage: static-map.sh LAT LON ZOOM WIDTH HEIGHT OUT.png [WORKDIR]
# The point lands at the exact centre of OUT.png. Tiles are fetched one by one
# and cached in WORKDIR. OSM's tile policy requires an identifying User-Agent:
# curl's default one gets a grey "Access blocked" tile with HTTP 200.
set -eu
lat=$1 lon=$2 z=$3 w=$4 h=$5 out=$6
work=${7:-$(mktemp -d)}
mkdir -p "$work"

# x0 y0 = top-left global pixel of the crop; then one "tx ty" line per tile.
python3 -I - "$lat" "$lon" "$z" "$w" "$h" > "$work/tiles.txt" <<'EOF'
import math, sys
lat, lon, z, w, h = float(sys.argv[1]), float(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
n = 256 * 2 ** z
px = (lon + 180) / 360 * n
py = (1 - math.asinh(math.tan(math.radians(lat))) / math.pi) / 2 * n
x0, y0 = round(px - w / 2), round(py - h / 2)
print(x0, y0)
for ty in range(y0 // 256, (y0 + h - 1) // 256 + 1):
    for tx in range(x0 // 256, (x0 + w - 1) // 256 + 1):
        print(tx, ty)
EOF

read -r x0 y0 < "$work/tiles.txt"
set -- magick -size "${w}x${h}" xc:white
tail -n +2 "$work/tiles.txt" | while read -r tx ty; do
  f="$work/$z-$tx-$ty.png"
  [ -s "$f" ] || curl -sf -A "listing-floorplan-static-map/1.0" -o "$f" "https://tile.openstreetmap.org/$z/$tx/$ty.png"
done
for line in $(tail -n +2 "$work/tiles.txt" | tr ' ' ','); do
  tx=${line%,*} ty=${line#*,}
  set -- "$@" "$work/$z-$tx-$ty.png" -geometry "$(printf '%+d%+d' $((tx * 256 - x0)) $((ty * 256 - y0)))" -composite
done
"$@" -strip "$out"
echo "$out"
