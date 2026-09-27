#!/bin/zsh
# Renders the App Store screenshots (1320x2868, 6.9") into ../../promo/Editorial.
# Usage: ./render.sh [panel indexes 0-5]
cd "$(dirname "$0")"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
OUT="../../promo/Editorial"; mkdir -p "$OUT"
# Apple system fonts and app art are copied in at render time, not committed.
for f in SFNS SFNSRounded; do [[ -f $f.ttf ]] || cp /System/Library/Fonts/$f.ttf .; done
for f in OtterOverlook OtterSwim; do [[ -f $f.png ]] || cp ../../../EarlyOtter/Resources/$f.png .; done
L=($@); [[ $# -eq 0 ]] && L=(0 1 2 3 4)
shot() { "$C" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 \
  --virtual-time-budget=4000 --window-size=$1 --screenshot="$PWD/$2" "file://$PWD/index.html?$3" >/dev/null 2>&1; }
for i in $L; do shot 1320,2868 "$OUT/$((i+1)).png" "p=$i"; done
shot 1980,860 "$OUT/overview.png" "preview=0.3"
