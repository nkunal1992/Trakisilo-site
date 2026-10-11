#!/usr/bin/env bash
# Converts captured store assets into web-optimized site assets.
# Reads:  ../Trakisilo/store-assets/site/*.mp4   (dark loops + tour)
#         ../Trakisilo/store-assets/site/thumb-*.png
#         ../Trakisilo/store-assets/dark/*.png   (screenshots)
# Writes: assets/v/*.mp4 assets/p/*.webp assets/s/*.webp assets/og.png favicons
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SITE_SRC:-$HOME/Projects/Trakisilo/store-assets}"
LOOPS="$SRC/site"
SHOTS="$SRC/dark"
A="$HERE/assets"

[ -d "$LOOPS" ] || { echo "missing $LOOPS — record loops first" >&2; exit 1; }

LOOPS_LIST="f-hero f-kanban f-card f-clips f-quickpaste f-time f-calendar f-chronicle f-bdoc f-editor f-process f-search f-themes"

# Per-loop crops + poster moments live in tools/crops.json — the loops are
# recorded full-window at 1920x1080; cropping into each feature's region
# keeps the UI legible at the ~400-650px display sizes on the pages.
read_json() { python3 -c "import json,sys;d=json.load(open('$HERE/tools/crops.json'));v=d[sys.argv[1]][sys.argv[2]];print('' if v is None else v)" "$1" "$2"; }

for n in $LOOPS_LIST; do
  src="$LOOPS/$n.mp4"; [ -f "$src" ] || { echo "skip $n (missing)"; continue; }
  w=1280; crf=26
  [ "$n" = "f-hero" ] && { w=1600; crf=24; }
  out="$A/v/${n#f-}.mp4"
  crop=$(read_json "$n" crop)
  vf="scale=$w:-2"
  if [ -n "$crop" ]; then
    IFS=', ' read -r cx cy cw <<<"${crop//[\[\]]/}"
    ch=$(( cw * 9 / 16 ))
    vf="crop=$cw:$ch:$cx:$cy,scale=$w:-2"
  fi
  ffmpeg -hide_banner -loglevel error -y -i "$src" \
    -vf "$vf" -c:v libx264 -preset slow -crf "$crf" \
    -pix_fmt yuv420p -an -movflags +faststart "$out"
done

# Tour — watched with controls, keep audio, full width.
if [ -f "$LOOPS/tour.mp4" ]; then
  ffmpeg -hide_banner -loglevel error -y -i "$LOOPS/tour.mp4" \
    -vf "scale=1600:-2" -c:v libx264 -preset slow -crf 24 \
    -pix_fmt yuv420p -c:a aac -movflags +faststart "$A/v/tour.mp4"
fi

python3 - "$LOOPS" "$SHOTS" "$A" "$HERE" <<'PY'
import sys, os
from PIL import Image
loops, shots, assets, root = sys.argv[1:5]

def save_webp(im, path, w):
    if im.width > w:
        im = im.resize((w, int(im.height * w / im.width)), Image.LANCZOS)
    im.save(path, "WEBP", quality=82, method=6)
    print(" ", os.path.basename(path), im.size)

# Posters — money frame per loop: extract poster_t * duration from the
# cropped OUTPUT video so the poster matches what plays. tour keeps the
# recorder's mid-action thumb.
import json, subprocess
crops = json.load(open(os.path.join(root, "tools/crops.json")))
for n in os.listdir(loops):
    if not n.startswith("f-") or not n.endswith(".mp4"):
        continue
    name = n[2:-4]
    out_mp4 = f"{assets}/v/{name}.mp4"
    if not os.path.exists(out_mp4):
        continue
    dur = float(subprocess.check_output([
        "ffprobe","-v","error","-show_entries","format=duration",
        "-of","csv=p=0", out_mp4]).decode().strip())
    t = crops.get(n[:-4], {}).get("poster_t", 0.5) * dur
    subprocess.check_call([
        "ffmpeg","-v","error","-y","-ss",str(t),"-i",out_mp4,
        "-frames:v","1","/tmp/_poster.png"])
    im = Image.open("/tmp/_poster.png").convert("RGB")
    save_webp(im, f"{assets}/p/{name}.webp", 1280)

for n in os.listdir(loops):
    if n.startswith("thumb-") and n.endswith(".png"):
        name = n[6:-4]
        if name.startswith("f-"):
            continue  # loop posters come from the money-frame pass above
        im = Image.open(os.path.join(loops, n)).convert("RGB")
        save_webp(im, f"{assets}/p/{name}.webp", 1280)

# Screenshots → assets/s/<NN-name>.webp at 1600w
for n in sorted(os.listdir(shots)):
    if n.endswith(".png"):
        im = Image.open(os.path.join(shots, n)).convert("RGB")
        save_webp(im, f"{assets}/s/{n[:-4]}.webp", 1600)

# OG image 1200x630 from the Store hero art.
hero = os.path.join(os.path.dirname(shots), "hero-16x9.png")
if os.path.exists(hero):
    im = Image.open(hero).convert("RGB")
    # center-crop to 1200:630
    tw, th = 1200, 630
    s = max(tw / im.width, th / im.height)
    im = im.resize((int(im.width * s + .5), int(im.height * s + .5)), Image.LANCZOS)
    l = (im.width - tw) // 2; t = (im.height - th) // 2
    im.crop((l, t, l + tw, t + th)).save(f"{assets}/og.png")
    print(" og.png", im.crop((l, t, l + tw, t + th)).size)

# Favicons from icon.png
icon = Image.open(f"{root}/icon.png").convert("RGBA")
for size, name in [(32, "favicon-32.png"), (180, "apple-touch-icon.png")]:
    icon.resize((size, size), Image.LANCZOS).save(f"{root}/{name}")
    print(" ", name)
PY

# Self-hosted variable font (OFL) — the app's own typeface.
cp /Users/narayan/Projects/Trakisilo/node_modules/@fontsource-variable/inter/files/inter-latin-opsz-normal.woff2 "$A/inter.woff2" 2>/dev/null \
  || cp /Users/narayan/Projects/Trakisilo/node_modules/@fontsource-variable/inter/files/inter-latin-standard-normal.woff2 "$A/inter.woff2"

# Official Microsoft Store badge (dark), self-hosted.
curl -sf -o "$A/ms-badge.svg" "https://get.microsoft.com/images/en-US%20dark.svg" \
  && echo " ms-badge.svg" || echo "badge fetch failed — add manually" >&2

echo "done:"
du -sh "$A/v" "$A/p" "$A/s" 2>/dev/null
