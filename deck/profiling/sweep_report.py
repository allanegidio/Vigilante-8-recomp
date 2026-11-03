"""Summarize a weapon sweep (deck/tools/weapon-sweep.sh): one row per car with
each weapon kind's attach callback and first ammo drop, whether the special
is the engine's placeholder, ported-special traces, and warning lines.

usage: python3 -I sweep_report.py <sweep dir with <type>/v8_latest.log>
"""
import re
import sys
from collections import Counter
from pathlib import Path

PLACEHOLDER_SPECIAL = "0x80049880"
KINDS = {1: "rockets", 2: "missiles", 3: "cannon", 4: "mortar", 5: "mines", 6: "flamethrower", 7: "special"}
WARNINGS = re.compile(r"Exception|\[Fatal\]|failed|rejected|malformed|mismatch|out of vram|invalid", re.I)


def report(log_path):
    text = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
    name = ""
    armed, fired = {}, set()
    source_fire = 0
    warnings = Counter()
    finished = False
    for line in text:
        if m := re.search(r"player=1 selected guest type=\d+ name=(.+)$", line):
            name = m.group(1).strip()
        if m := re.search(r"weapon-armed kind=(\d) .*callback=(0x[0-9A-F]+)", line):
            armed.setdefault(int(m.group(1)), m.group(2))
        if m := re.search(r"weapon-fired kind=(\d)", line):
            fired.add(int(m.group(1)))
        if "[V8SourceSpecial] fire" in line:
            source_fire += 1
        if "deterministic replay completed after stage 'soak_teardown'" in line:
            finished = True
        if WARNINGS.search(line):
            warnings[re.sub(r"0x[0-9A-Fa-f]+|\d+", "#", line)[:150]] += 1
    return name, armed, fired, source_fire, warnings, finished


def main():
    root = Path(sys.argv[1])
    runs = sorted((p for p in root.iterdir() if p.is_dir() and p.name.isdigit()), key=lambda p: int(p.name))
    all_warnings = Counter()
    print(f"{'type':>4}  {'car':<16} {'finished':<8} " + " ".join(f"{KINDS[k][:7]:<9}" for k in KINDS) + "  special")
    for run in runs:
        log = run / "v8_latest.log"
        if not log.exists():
            print(f"{run.name:>4}  (no log)")
            continue
        name, armed, fired, source_fire, warnings, finished = report(log)
        cells = []
        for kind in KINDS:
            if kind not in armed:
                cells.append("NOT-ARMED")
            elif kind not in fired:
                cells.append("NO-FIRE")
            else:
                cells.append("ok")
        special = armed.get(7, "?")
        verdict = "PLACEHOLDER" if special == PLACEHOLDER_SPECIAL else "real"
        if source_fire:
            verdict += f" (ported, {source_fire} shots)"
        print(f"{run.name:>4}  {name or 'retail':<16} {'yes' if finished else 'NO':<8} "
              + " ".join(f"{c:<9}" for c in cells) + f"  {verdict} {special}")
        for key, count in warnings.items():
            all_warnings[key] += count
    print("\nwarning lines across all runs (count, normalized):")
    for key, count in all_warnings.most_common(40):
        print(f"{count:6d}  {key}")


if __name__ == "__main__":
    main()
