#!/usr/bin/env python3
"""Emit the ffmpeg filtergraph for a loop's camera timeline.

usage: camera.py <loop-name> <out-width>

Reads shots [t, x, y, w] from tools/crops.json (h = w*9/16 on the 1920x1080
source). The camera holds each region, then smoothstep-eases over D seconds
into the next shot, arriving at its t_start. Prints the -vf string.
"""
import json, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC_W, SRC_H, D = 1920.0, 1080.0, 0.7

name, out_w = sys.argv[1], int(sys.argv[2])
d = json.load(open(os.path.join(HERE, "crops.json")))
shots = (d.get(name) or {}).get("shots")

if not shots:
    print(f"scale={out_w}:-2")
    raise SystemExit


def param(v_fn):
    def lerp(a, b, ts):
        p = f"clip((t-{ts:.2f})/{D},0,1)"
        s = f"({p}*{p}*(3-2*{p}))"
        return f"({a}+(({b})-({a}))*{s})"

    def build(i):
        vs = [v_fn(s) for s in shots]
        if i == 0:
            return vs[0]
        end, start = shots[i][0], shots[i][0] - D
        return (
            f"if(lt(t,{start:.2f}),{build(i-1)},"
            f"if(lt(t,{end:.2f}),{lerp(vs[i-1], vs[i], start)},{vs[i]}))"
        )

    return build(len(shots) - 1)


w = param(lambda s: f"{s[3]}")
x = param(lambda s: f"{s[1]}")
y = param(lambda s: f"{s[2]}")
h = f"(({w})*9/16)"
xc = f"clip({x},0,{int(SRC_W)}-({w}))"
yc = f"clip({y},0,{int(SRC_H)}-({h}))"
print(f"crop=w='{w}':h='{h}':x='{xc}':y='{yc}',scale={out_w}:-2")
