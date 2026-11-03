"""Append one manual GitHub entry to Quiver v3.5.1's apps.json (Quiver closed).

usage: python3 -I quiver_add_app.py <apps.json> <entry.json>
"""
import json
import shutil
import sys

STRING_OR_NULL = ("name", "folderName", "installPath", "appIconUrl", "repository",
                  "preferredVersion", "skippedUpdateVersion", "project",
                  "linuxRunner", "linuxProtonPath")


def validate(entry):
    for key in STRING_OR_NULL:
        if key in entry and entry[key] is not None and not isinstance(entry[key], str):
            raise SystemExit(f"{key} must be a string or null")
    if not isinstance(entry.get("autoUpdate", False), bool):
        raise SystemExit("autoUpdate must be a bool")
    tags = entry.get("tags", [])
    if not isinstance(tags, list) or not all(isinstance(t, str) for t in tags):
        raise SystemExit("tags must be a list of strings")
    if entry.get("linuxRunner") not in (None, "auto", "wine", "proton", "custom"):
        raise SystemExit("bad linuxRunner")


def main():
    apps_path, entry_path = sys.argv[1:3]
    entry = json.load(open(entry_path, encoding="utf-8"))
    validate(entry)
    raw = open(apps_path, "rb").read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raise SystemExit("apps.json has a BOM; not touching it")
    library = json.loads(raw.decode("utf-8"))
    apps = library["apps"]
    for app in apps:
        if app.get("folderName") == entry["folderName"]:
            raise SystemExit(f"folder already in library: {entry['folderName']}")
        if app.get("name") == entry["name"]:
            raise SystemExit(f"name already in library: {entry['name']}")
    shutil.copy2(apps_path, apps_path + ".bak-before-vigilante8")
    apps.append(entry)
    for app in apps:
        validate(app)
    with open(apps_path, "w", encoding="utf-8") as handle:
        json.dump(library, handle, indent=1, ensure_ascii=False)
        handle.write("\n")
    reread = json.load(open(apps_path, encoding="utf-8"))
    print("apps now:", [app["name"] for app in reread["apps"]])


if __name__ == "__main__":
    main()
