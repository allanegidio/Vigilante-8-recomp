"""Most frequent stack tails on one thread of a speedscope export.
usage: python3 -I speedscope_stacks.py <file> <thread name> [start_frac] [depth] [top]"""
import json
import sys
from collections import defaultdict


def short(name):
    name = name.split("!", 1)[-1]
    if "(" in name:
        name = name[: name.index("(")]
    parts = name.split(".")
    return ".".join(parts[-2:]) if len(parts) > 2 else name


path, thread = sys.argv[1], sys.argv[2]
start_frac = float(sys.argv[3]) if len(sys.argv) > 3 else 0.55
depth = int(sys.argv[4]) if len(sys.argv) > 4 else 7
top = int(sys.argv[5]) if len(sys.argv) > 5 else 20
data = json.load(open(path))
frames = [f["name"] for f in data["shared"]["frames"]]
profile = next(p for p in data["profiles"] if p["name"] == thread)
t0, t1 = profile["startValue"], profile["endValue"]
window = t0 + (t1 - t0) * start_frac
stack, last, total = [], None, 0.0
tails = defaultdict(float)
for event in profile["events"]:
    at = event["at"]
    if last is not None and stack and at > window:
        span = at - max(last, window)
        if span > 0:
            names = [short(frames[i]) for i in stack]
            names = [n for n in names if n not in ("CPU_TIME",)]
            tails[" > ".join(names[-depth:])] += span
            total += span
    if event["type"] == "O":
        stack.append(event["frame"])
    elif stack:
        stack.pop()
    last = at
for tail, span in sorted(tails.items(), key=lambda kv: -kv[1])[:top]:
    print(f"{100 * span / total:5.1f}%  {tail}")
