#!/usr/bin/env python3
"""Read the frontmatter of factory/profile.md without third-party YAML.

Supports the subset the profile uses: `key: value`, inline lists `[a, b]`,
block lists (`- item`) and one nesting level (`docs:` with indented keys).
Usage:  python3 profile.py [path] [key[.sub]]   → prints JSON, or one value.
"""
import json, re, sys


def scalar(v):
    v = v.split(" #", 1)[0].strip()
    if v in ("", "~", "null"):
        return None
    if v in ("true", "false"):
        return v == "true"
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    if v.startswith("[") and v.endswith("]"):
        return [scalar(x) for x in v[1:-1].split(",") if x.strip()]
    return v.strip("'\"")


def load(path="factory/profile.md"):
    text = open(path, encoding="utf-8").read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        raise ValueError(f"{path}: no frontmatter")
    data, parent, last = {}, None, None
    for raw in m.group(1).splitlines():
        if not raw.strip() or raw.lstrip().startswith("#"):
            continue
        indent = len(raw) - len(raw.lstrip())
        line = raw.strip()
        if line.startswith("- "):
            item = scalar(line[2:])
            sub = data.get(parent)
            if isinstance(sub, dict) and last != parent:
                # list under a nested key, e.g. docs: / extra: / - x
                sub.setdefault(last, [])
                if not isinstance(sub[last], list):
                    sub[last] = []
                sub[last].append(item)
            else:
                if not isinstance(sub, list):
                    data[parent] = []
                data[parent].append(item)
            continue
        k, _, v = line.partition(":")
        k = k.strip()
        if indent and parent is not None and isinstance(data.get(parent), dict):
            data[parent][k] = scalar(v)
            last = k
        else:
            val = scalar(v)
            data[k] = {} if val is None else val
            parent, last = k, k
    # an empty mapping that only held block-list items became a list above
    return {k: (v if v != {} else None) for k, v in data.items()}


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "factory/profile.md"
    prof = load(path)
    if len(sys.argv) > 2:
        cur = prof
        for part in sys.argv[2].split("."):
            cur = cur.get(part) if isinstance(cur, dict) else None
        print(cur if not isinstance(cur, (dict, list)) else json.dumps(cur))
    else:
        print(json.dumps(prof, indent=2))
