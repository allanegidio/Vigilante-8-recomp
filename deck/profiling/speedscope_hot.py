"""Per-thread hot spots from a dotnet-trace speedscope export (evented profiles).

usage: python3 -I speedscope_hot.py <file.speedscope.json> [top=35] [window_start_frac=0.5]

Only the tail of the run (from window_start_frac of each thread's timeline) is
counted, so boot, intro movies and menus don't dilute gameplay.
Waits (Sleep, WaitOne, Monitor.Wait, GetQueuedCompletionStatus...) are
reported apart from busy time.
"""
import json
import sys
from collections import defaultdict

WAIT_MARKERS = ("Thread.Sleep", "WaitOneCore", "Monitor.Wait", "GetQueuedCompletionStatus",
                "WaitHandle", "SpinWait", "LowLevelLifoSemaphore", "Thread.Join")


def short(name):
    name = name.split("!", 1)[-1]
    if "(" in name:
        name = name[: name.index("(")]
    parts = name.split(".")
    return ".".join(parts[-2:]) if len(parts) > 2 else name


def main():
    path = sys.argv[1]
    top = int(sys.argv[2]) if len(sys.argv) > 2 else 35
    start_frac = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    data = json.load(open(path))
    frames = [f["name"] for f in data["shared"]["frames"]]
    results = []
    for profile in data["profiles"]:
        events = profile.get("events", [])
        if not events:
            continue
        t0, t1 = profile["startValue"], profile["endValue"]
        window = t0 + (t1 - t0) * start_frac
        stack = []
        self_time = defaultdict(float)
        incl_time = defaultdict(float)
        busy = 0.0
        wait = 0.0
        last = None
        for event in events:
            at = event["at"]
            if last is not None and stack and at > window:
                begin = max(last, window)
                span = at - begin
                if span > 0:
                    top_name = frames[stack[-1]]
                    if any(m in top_name for m in WAIT_MARKERS):
                        wait += span
                    else:
                        busy += span
                        self_time[stack[-1]] += span
                        for index in set(stack):
                            incl_time[index] += span
            if event["type"] == "O":
                stack.append(event["frame"])
            elif stack:
                stack.pop()
            last = at
        results.append((busy, wait, profile["name"], self_time, incl_time))
    results.sort(reverse=True)
    print("threads by busy time (window):")
    for busy, wait, name, _, _ in results[:8]:
        print(f"  {name:28s} busy={busy / 1000:8.1f}s wait={wait / 1000:8.1f}s")
    busy, wait, name, self_time, incl_time = results[0]
    print(f"\nbusiest thread {name}: top self time")
    for index, span in sorted(self_time.items(), key=lambda kv: -kv[1])[:top]:
        print(f"  {100 * span / busy:5.1f}%  {short(frames[index])}")
    print(f"\nbusiest thread {name}: top inclusive time")
    skip = ("Thread", "Threads", "(Non-Activities)", "Process64")
    shown = 0
    for index, span in sorted(incl_time.items(), key=lambda kv: -kv[1]):
        label = frames[index]
        if label.startswith(skip) or label.startswith("Thread ("):
            continue
        print(f"  {100 * span / busy:5.1f}%  {short(label)}")
        shown += 1
        if shown >= top:
            break


if __name__ == "__main__":
    main()
