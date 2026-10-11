#!/usr/bin/env python3
"""Find the last frame of a source loop that still shows the app window.

The recorder's tail captures the desktop once the app exits during teardown
(~0.5-1.5s before EOF). Compares each sampled frame to a known in-app frame
at 20% duration; the app frame is the last one whose mean pixel diff stays
under the threshold. Prints the cutoff time in seconds.

usage: loopend.py <video.mp4>
"""
import subprocess, sys, io
from PIL import Image, ImageChops

src = sys.argv[1]
dur = float(subprocess.check_output(
    ["ffprobe", "-v", "error", "-show_entries", "format=duration",
     "-of", "csv=p=0", src]).decode().strip())


def frame(t):
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-y", "-ss", f"{t:.2f}", "-i", src,
        "-frames:v", "1", "-f", "image2pipe", "-c:v", "png", "-"])
    im = Image.open(io.BytesIO(raw)).convert("L")
    # central strip — app content vs desktop differs most in the middle
    return im.crop((300, 200, 1620, 900)).resize((220, 117))


ref = frame(dur * 0.2)
t = dur - 0.2
cut = None
while t > dur - 2.5:
    diff = ImageChops.difference(frame(t), ref)
    m = sum(diff.getdata()) / len(diff.getdata())
    if m < 12:
        cut = t
        break
    t -= 0.2

print(f"{cut if cut is not None else dur - 1.6:.2f}")
