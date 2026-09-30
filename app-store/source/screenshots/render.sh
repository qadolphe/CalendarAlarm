#!/bin/zsh
# Renders the App Store screenshots (1320x2868, 6.9") for one language.
# Captions come from ../../listing/copy/<lang>.json, app screens from app/<lang>/.
# English lands in ../../promo/Editorial, other languages in ../../promo/Editorial/<lang>.
# Usage: ./render.sh [lang] [panel indexes 0-3]     e.g. ./render.sh es
cd "$(dirname "$0")"
C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LANG_CODE=en; [[ $1 == [a-z][a-z] ]] && { LANG_CODE=$1; shift; }
OUT="../../promo/Editorial"; [[ $LANG_CODE != en ]] && OUT="$OUT/$LANG_CODE"; mkdir -p "$OUT"
python3 -c 'import json,sys; s=json.load(open(sys.argv[1]))["screenshots"]; s["lang"]=sys.argv[2]; print("window.SCREENSHOT_STRINGS = " + json.dumps(s, ensure_ascii=False) + ";")' \
  "../../listing/copy/$LANG_CODE.json" "$LANG_CODE" > strings.js
# Apple system fonts and app art are copied in at render time, not committed.
for f in SFNS SFNSRounded; do [[ -f $f.ttf ]] || cp /System/Library/Fonts/$f.ttf .; done
for f in OtterOverlook OtterSwim; do [[ -f $f.png ]] || cp ../../../EarlyOtter/Resources/$f.png .; done
L=($@); [[ $# -eq 0 ]] && L=(0 1 2 3)
shot() { "$C" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --force-device-scale-factor=1 \
  --virtual-time-budget=4000 --window-size=$1 --screenshot="$PWD/$2" "file://$PWD/index.html?$3" >/dev/null 2>&1; }
for i in $L; do shot 1320,2868 "$OUT/$((i+1)).png" "p=$i"; done
shot 1584,860 "$OUT/overview.png" "preview=0.3"
