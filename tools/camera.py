#!/usr/bin/env python3
"""Emit the ffmpeg filtergraph for a loop's camera timeline.

usage: camera.py <loop-name> <out-width> [fps]

Reads shots [t, x, y, w] from tools/crops.json (h = w*9/16 on the 1920x1080
source). The camera holds each region, then smoothstep-eases over D seconds
into the next shot, arriving at its t_start. Prints the -vf string.

Implemented with zoompan: ffmpeg's crop filter negotiates w/h once at init
(tested on ffmpeg 9 — timeline expressions for w/h render as a fixed region),
so an animated camera is expressed as zoom = iw / shot_w over a fixed-size
output instead. `in_time` is the input frame timestamp — the same role `t`
played in the old crop expressions.
"""
import json, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_W, D = 1920.0, 0.7

name, out_w = sys.argv[1], int(sys.argv[2])
fps = sys.argv[3] if len(sys.argv) > 3 else "30"
if "/" in str(fps):
    num, den = fps.split("/")
    fps = float(num) / float(den)
fps = float(fps)

d = json.load(open(os.path.join(HERE, "crops.json")))
shots = (d.get(name) or {}).get("shots")
out_h = out_w * 9 // 16

if not shots:
    print(f"scale={out_w}:-2")
    raise SystemExit

T = "in_time"


def param(v_fn):
    def lerp(a, b, ts):
        p = f"clip(({T}-{ts:.2f})/{D},0,1)"
        s = f"({p}*{p}*(3-2*{p}))"
        return f"({a}+(({b})-({a}))*{s})"

    def build(i):
        vs = [v_fn(s) for s in shots]
        if i == 0:
            return vs[0]
        end, start = shots[i][0], shots[i][0] - D
        return (
            f"if(lt({T},{start:.2f}),{build(i-1)},"
            f"if(lt({T},{end:.2f}),{lerp(vs[i-1], vs[i], start)},{vs[i]}))"
        )

    return build(len(shots) - 1)


w = param(lambda s: f"{s[3]}")
x = param(lambda s: f"{s[1]}")
y = param(lambda s: f"{s[2]}")

z = f"max({int(SRC_W)}/({w}),1)"
px = f"clip({x},0,iw-iw/zoom)"
py = f"clip({y},0,ih-ih/zoom)"

print(f"zoompan=z='{z}':x='{px}':y='{py}':d=1:s={out_w}x{out_h}:fps={fps:g}")
