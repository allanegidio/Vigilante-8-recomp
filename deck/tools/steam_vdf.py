"""Add non-Steam shortcuts and force a Steam Play tool for them.

Run with Steam closed:
  python3 -I steam_vdf.py list <shortcuts.vdf>
  python3 -I steam_vdf.py add <shortcuts.vdf> <config.vdf> <tool> <spec.json>

spec.json is a list of {"appname", "exe", "startdir", "launch_options"}.
Entries whose appname already exists are left alone (idempotent).
"""
import json
import re
import sys
import zlib

MAP, STR, INT, END = b"\x00", b"\x01", b"\x02", b"\x08"


def read_cstr(data, pos):
    end = data.index(b"\x00", pos)
    return data[pos:end].decode("utf-8"), end + 1


def parse_map(data, pos):
    """Returns (list of (key, type, value)), pos after the END byte."""
    items = []
    while True:
        kind = data[pos:pos + 1]
        pos += 1
        if kind == END:
            return items, pos
        key, pos = read_cstr(data, pos)
        if kind == MAP:
            value, pos = parse_map(data, pos)
        elif kind == STR:
            value, pos = read_cstr(data, pos)
        elif kind == INT:
            value = int.from_bytes(data[pos:pos + 4], "little", signed=True)
            pos += 4
        else:
            raise ValueError(f"unsupported VDF type {kind!r} at {pos - 1}")
        items.append((key, kind, value))


def dump_map(items):
    out = bytearray()
    for key, kind, value in items:
        out += kind + key.encode("utf-8") + b"\x00"
        if kind == MAP:
            out += dump_map(value)
        elif kind == STR:
            out += value.encode("utf-8") + b"\x00"
        elif kind == INT:
            out += int(value).to_bytes(4, "little", signed=True)
    return bytes(out + END)


def load_shortcuts(path):
    data = open(path, "rb").read()
    root, pos = parse_map(data, 0)
    # The file ends with a second END byte closing the implicit root.
    if data[pos:] not in (b"", END):
        raise ValueError(f"trailing bytes after root map: {data[pos:]!r}")
    if len(root) != 1 or root[0][0].lower() != "shortcuts":
        raise ValueError("not a shortcuts.vdf")
    return root, data[pos:]


def field(entry, name):
    for key, _, value in entry:
        if key.lower() == name.lower():
            return value
    return None


def shortcut_appid(exe, appname):
    return (zlib.crc32((exe + appname).encode("utf-8")) & 0xFFFFFFFF) | 0x80000000


def new_entry(index, appid, spec):
    signed = appid - (1 << 32) if appid >= (1 << 31) else appid
    return (str(index), MAP, [
        ("appid", INT, signed),
        ("appname", STR, spec["appname"]),
        ("Exe", STR, spec["exe"]),
        ("StartDir", STR, spec["startdir"]),
        ("icon", STR, ""),
        ("ShortcutPath", STR, ""),
        ("LaunchOptions", STR, spec["launch_options"]),
        ("IsHidden", INT, 0),
        ("AllowDesktopConfig", INT, 1),
        ("AllowOverlay", INT, 1),
        ("OpenVR", INT, 0),
        ("Devkit", INT, 0),
        ("DevkitGameID", STR, ""),
        ("DevkitOverrideAppID", INT, 0),
        ("LastPlayTime", INT, 0),
        ("FlatpakAppID", STR, ""),
        ("sortas", STR, ""),
        ("tags", MAP, []),
    ])


def add_compat_mapping(config_text, appids, tool):
    match = re.search(r'\n(\t*)"CompatToolMapping"\n\t*\{\n', config_text)
    if not match:
        raise ValueError("CompatToolMapping block not found in config.vdf")
    indent = match.group(1)
    block_start = match.end()
    block_end = config_text.index("\n" + indent + "}", block_start - 1)
    block = config_text[block_start:block_end + 1]
    inner = indent + "\t"
    added = []
    for appid in appids:
        if f'{inner}"{appid}"\n' in block:
            continue
        block += (
            f'{inner}"{appid}"\n{inner}{{\n'
            f'{inner}\t"name"\t\t"{tool}"\n'
            f'{inner}\t"config"\t\t""\n'
            f'{inner}\t"priority"\t\t"250"\n'
            f"{inner}}}\n"
        )
        added.append(appid)
    return config_text[:block_start] + block + config_text[block_end + 1:], added


def main():
    command = sys.argv[1]
    if command == "list":
        root, tail = load_shortcuts(sys.argv[2])
        original = open(sys.argv[2], "rb").read()
        print("round-trip identical:", dump_map(root) + tail == original)
        for _, _, entry in root[0][2]:
            appid = field(entry, "appid") & 0xFFFFFFFF
            print(appid, repr(field(entry, "AppName")), field(entry, "Exe"),
                  "| start:", field(entry, "StartDir"),
                  "| opts:", field(entry, "LaunchOptions"))
        return
    if command == "edit":
        # edit <shortcuts.vdf> <remove appname|-> <appname to update> <launch options>
        shortcuts_path, remove_name, update_name, options = sys.argv[2:6]
        root, tail = load_shortcuts(shortcuts_path)
        kept = [e for e in root[0][2] if field(e[2], "AppName") != remove_name]
        if remove_name != "-" and len(kept) == len(root[0][2]):
            raise SystemExit(f"not found: {remove_name}")
        updated = False
        for index, (_, kind, entry) in enumerate(kept):
            if field(entry, "AppName") == update_name:
                for i, (key, ftype, _) in enumerate(entry):
                    if key.lower() == "launchoptions":
                        entry[i] = (key, ftype, options)
                        updated = True
            kept[index] = (str(index), kind, entry)
        if not updated:
            raise SystemExit(f"not found: {update_name}")
        root[0] = (root[0][0], root[0][1], kept)
        with open(shortcuts_path, "wb") as handle:
            handle.write(dump_map(root) + tail)
        print(f"removed {remove_name!r}; {update_name!r} launch options = {options!r}")
        return
    if command != "add":
        raise SystemExit(__doc__)
    shortcuts_path, config_path, tool, spec_path = sys.argv[2:6]
    specs = json.load(open(spec_path, encoding="utf-8"))
    root, tail = load_shortcuts(shortcuts_path)
    entries = root[0][2]
    names = {field(entry, "AppName") for _, _, entry in entries}
    appids = []
    for spec in specs:
        appid = shortcut_appid(spec["exe"], spec["appname"])
        appids.append(appid)
        if spec["appname"] in names:
            print(f"exists: {spec['appname']}")
            continue
        entries.append(new_entry(len(entries), appid, spec))
        print(f"added: {spec['appname']} appid={appid}")
    with open(shortcuts_path, "wb") as handle:
        handle.write(dump_map(root) + tail)
    config_text = open(config_path, encoding="utf-8").read()
    config_text, added = add_compat_mapping(config_text, appids, tool)
    with open(config_path, "w", encoding="utf-8") as handle:
        handle.write(config_text)
    print(f"compat {tool} added for: {added}")


if __name__ == "__main__":
    main()
