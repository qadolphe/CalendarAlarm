#!/usr/bin/env python3
"""Write a language's strings (tools/localization/<lang>.py) into the String Catalogs.

Usage: python3 tools/localization/apply.py es

Run it after Xcode has extracted new keys (a build or Product > Export
Localizations). It reports catalog keys the language file doesn't cover, so a
new string can't ship untranslated without anyone noticing.
"""
import json
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOGS = ["EarlyOtter/Localizable.xcstrings", "NextAlarmWidget/Localizable.xcstrings"]


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def multi_plural(sentence, args):
    return {
        "stringUnit": {"state": "translated", "value": sentence},
        "substitutions": {
            name: {"argNum": num, "formatSpecifier": "lld", "variations": {"plural": {"one": unit(one), "other": unit(other)}}}
            for name, (num, one, other) in args.items()
        },
    }


def load(path):
    return json.loads((ROOT / path).read_text())


def save(path, catalog):
    # Xcode's own formatting, so its next sync doesn't rewrite the whole file.
    text = json.dumps(catalog, indent=2, ensure_ascii=False, sort_keys=True).replace('": ', '" : ')
    (ROOT / path).write_text(text + "\n")


def main(lang):
    spec = runpy.run_path(str(ROOT / "tools/localization" / f"{lang}.py"))
    strings, plurals, multi = spec["STRINGS"], spec["PLURALS"], spec["MULTI_PLURALS"]
    skip = spec["DO_NOT_TRANSLATE"]
    missing = []

    for path in CATALOGS:
        catalog = load(path)
        # Strings the code no longer uses.
        catalog["strings"] = {k: v for k, v in catalog["strings"].items() if v.get("extractionState") != "stale"}
        for key, entry in catalog["strings"].items():
            locs = entry.setdefault("localizations", {})
            if key in skip:
                entry["shouldTranslate"] = False
                locs.pop(lang, None)
            elif key in plurals:
                locs["en"] = plural(*plurals[key]["en"])
                locs[lang] = plural(*plurals[key][lang])
            elif key in multi:
                locs["en"] = multi_plural(*multi[key]["en"])
                locs[lang] = multi_plural(*multi[key][lang])
            elif key in strings:
                locs[lang] = unit(strings[key])
            else:
                missing.append(f"{path}: {key!r}")
            if not locs:
                entry.pop("localizations")
        save(path, catalog)

    for path, values in spec.get("INFO_PLIST_SOURCE", {}).items():
        catalog = load(path)
        for key, value in values.items():
            entry = catalog["strings"].setdefault(key, {"extractionState": "manual"})
            entry.setdefault("localizations", {})["en"] = unit(value)
        save(path, catalog)

    for path, values in spec.get("INFO_PLIST", {}).items():
        catalog = load(path)
        for key, value in values.items():
            catalog["strings"].setdefault(key, {}).setdefault("localizations", {})[lang] = unit(value)
        save(path, catalog)

    shortcuts = "EarlyOtter/AppShortcuts.xcstrings"
    catalog = load(shortcuts)
    for key, phrases in spec.get("SHORTCUT_PHRASES", {}).items():
        entry = catalog["strings"].get(key)
        if entry is None:
            missing.append(f"{shortcuts}: {key!r}")
            continue
        entry["localizations"][lang] = {"stringSet": {"state": "translated", "values": phrases}}
    save(shortcuts, catalog)

    used = {k for path in CATALOGS for k in load(path)["strings"]}
    unused = [k for table in (strings, plurals, multi) for k in table if k not in used]
    if unused:
        print(f"{len(unused)} {lang} entries are no longer used; remove them:")
        print("\n".join(f"  {k!r}" for k in unused))

    if missing:
        print(f"{len(missing)} keys have no {lang} translation:")
        print("\n".join(f"  {m}" for m in missing))
        sys.exit(1)
    print(f"{lang}: all keys translated")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "es")
