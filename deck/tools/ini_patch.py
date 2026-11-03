"""Set keys in the [RecompOne] section of a game-written interface.ini,
keeping every other line (panel states and the ImGui layout) as written.

usage: python3 -I ini_patch.py <interface.ini> <values.ini>
values.ini holds KEY=VALUE lines.
"""
import sys


def main():
    target, values_path = sys.argv[1:3]
    values = {}
    for line in open(values_path, encoding="utf-8"):
        line = line.strip()
        if line and not line.startswith("[") and "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    text = open(target, encoding="utf-8-sig").read()
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.split(newline)
    if not lines or lines[0] != "[RecompOne]":
        raise SystemExit("interface.ini does not start with [RecompOne]")
    end = next((i for i in range(1, len(lines)) if lines[i].startswith("[")), len(lines))
    section = lines[1:end]
    seen = set()
    for index, line in enumerate(section):
        key = line.split("=", 1)[0]
        if "=" in line and key in values:
            section[index] = f"{key}={values[key]}"
            seen.add(key)
    missing = [f"{key}={value}" for key, value in values.items() if key not in seen]
    # Keep the blank separator line before the ImGui layout.
    insert_at = len(section)
    while insert_at > 0 and section[insert_at - 1] == "":
        insert_at -= 1
    section[insert_at:insert_at] = missing
    output = [lines[0]] + section + lines[end:]
    with open(target, "w", encoding="utf-8", newline="") as handle:
        handle.write(newline.join(output))
    print(f"set {len(values)} keys ({len(missing)} added); layout lines kept: {len(lines) - end}")


if __name__ == "__main__":
    main()
