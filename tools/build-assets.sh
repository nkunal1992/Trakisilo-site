#!/usr/bin/env bash
# Converts captured store assets into web-optimized site assets.
# Reads:  ../Trakisilo/store-assets/site/*.mp4   (dark loops + tour)
#         ../Trakisilo/store-assets/site/thumb-*.png
#         ../Trakisilo/store-assets/dark/*.png   (screenshots, dark)
#         ../Trakisilo/store-assets/light/*.png  (screenshots, light)
# Writes: assets/v/*.mp4 assets/p/*.webp assets/s/*.webp assets/og.png favicons
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${SITE_SRC:-$HOME/Projects/Trakisilo/store-assets}"
LOOPS="$SRC/site"
SHOTS="$SRC/dark"
SHOTS_LIGHT="$SRC/light"
A="$HERE/assets"

[ -d "$LOOPS" ] || { echo "missing $LOOPS — record loops first" >&2; exit 1; }

LOOPS_LIST="f-hero f-kanban f-card f-clips f-quickpaste f-time f-calendar f-chronicle f-bdoc f-editor f-sheet f-sheets f-mail f-process f-search f-themes"

# Per-loop camera moves live in tools/crops.json as `shots`: keyframes
# [t,x,y,w] on the 1920x1080 source (h = w*9/16). Each loop starts and ends
# full-window, easing into each region so the action stays legible at the
# ~400-650px display sizes on the pages. tools/camera.py emits the -vf.
LOOPS_LIGHT="${SITE_SRC_LIGHT:-$SRC/site-light}"

encode_dir() {  # $1 loops dir, $2 output dir — f-*.mp4 loops + tour.mp4
  local loops="$1" outdir="$2"
  mkdir -p "$outdir"
  for n in $LOOPS_LIST; do
    src="$loops/$n.mp4"; [ -f "$src" ] || { echo "skip $n (missing)"; continue; }
    w=1280; crf=26
    [ "$n" = "f-hero" ] && { w=1600; crf=24; }
    out="$outdir/${n#f-}.mp4"
    src_fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$src")
    vf=$(python3 "$HERE/tools/camera.py" "$n" "$w" "$src_fps")
    end=$(python3 -c "import json;d=json.load(open('$HERE/tools/crops.json'));print(d.get('$n',{}).get('end') or '')")
    trim=()
    [ -n "$end" ] && trim=(-t "$end")
    ffmpeg -hide_banner -loglevel error -y -i "$src" \
      -vf "$vf" "${trim[@]}" -c:v libx264 -preset slow -crf "$crf" \
      -pix_fmt yuv420p -an -movflags +faststart "$out"
  done
  # Tour — watched with controls, keep audio, full width.
  if [ -f "$loops/tour.mp4" ]; then
    ffmpeg -hide_banner -loglevel error -y -i "$loops/tour.mp4" \
      -vf "scale=1600:-2" -c:v libx264 -preset slow -crf 24 \
      -pix_fmt yuv420p -c:a aac -movflags +faststart "$outdir/tour.mp4"
  fi
}

encode_dir "$LOOPS" "$A/v"
[ -d "$LOOPS_LIGHT" ] && encode_dir "$LOOPS_LIGHT" "$A/v-light" || true

python3 - "$LOOPS" "$LOOPS_LIGHT" "$SHOTS" "$SHOTS_LIGHT" "$A" "$HERE" <<'PY'
import sys, os
from PIL import Image
loops, loops_light, shots, shots_light, assets, root = sys.argv[1:7]

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

def posters(loops_dir, v_dir, p_dir):
    if not os.path.isdir(loops_dir):
        return
    os.makedirs(p_dir, exist_ok=True)
    for n in os.listdir(loops_dir):
        if not n.startswith("f-") or not n.endswith(".mp4"):
            continue
        name = n[2:-4]
        out_mp4 = f"{v_dir}/{name}.mp4"
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
        save_webp(im, f"{p_dir}/{name}.webp", 1280)
    for n in os.listdir(loops_dir):
        if n.startswith("thumb-") and n.endswith(".png"):
            name = n[6:-4]
            if name.startswith("f-"):
                continue  # loop posters come from the money-frame pass above
            im = Image.open(os.path.join(loops_dir, n)).convert("RGB")
            save_webp(im, f"{p_dir}/{name}.webp", 1280)

posters(loops, f"{assets}/v", f"{assets}/p")
posters(loops_light, f"{assets}/v-light", f"{assets}/p-light")

# Screenshots → assets/s/<NN-name>.webp at 1600w (dark), s-light/ (light)
for shot_dir, out_dir in ((shots, "s"), (shots_light, "s-light")):
    if not os.path.isdir(shot_dir):
        continue
    os.makedirs(f"{assets}/{out_dir}", exist_ok=True)
    for n in sorted(os.listdir(shot_dir)):
        if n.endswith(".png"):
            im = Image.open(os.path.join(shot_dir, n)).convert("RGB")
            save_webp(im, f"{assets}/{out_dir}/{n[:-4]}.webp", 1600)

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
du -sh "$A/v" "$A/v-light" "$A/p" "$A/p-light" "$A/s" "$A/s-light" 2>/dev/null
