#!/usr/bin/env python3
"""Merge a Windows MUI resource file into its executable.

Wine does not implement MUI redirection, so Windows 7 system binaries (notepad,
mspaint, wordpad, ...) load no strings/menus and render blank or refuse to
start. This copies the resources from <app>.exe.mui into <app>.exe.

Written for LIEF 0.17. Each MUI resource type is built detached and attached in
one operation, because mutating a parsed resource tree child-by-child
invalidates LIEF wrappers and silently drops resources.

Usage: patch_mui.py <app.exe> <app.exe.mui>
Installs nothing; edits the exe in place (a .bak is written once).
"""

import os
import sys

import lief

SKIP_IDS = {16, 24}          # keep the exe's own VERSION and MANIFEST
SKIP_NAMES = {"MUI"}         # keep the exe's own MUI marker


def key(node):
    return ("name", node.name) if node.has_name else ("id", node.id)


def make_dir(node):
    try:
        out = lief.PE.ResourceDirectory(node.id)
    except Exception:
        out = lief.PE.ResourceDirectory()
        out.id = node.id
    if node.has_name:
        out.name = node.name
    return out


def make_data(node):
    try:
        out = lief.PE.ResourceData(node.content)
    except Exception:
        out = lief.PE.ResourceData(list(node.content))
    if node.has_name:
        out.name = node.name
    else:
        out.id = node.id
    return out


def build(src):
    out = make_dir(src)
    for child in list(src.childs):
        if isinstance(child, lief.PE.ResourceData):
            out.add_child(make_data(child))
        else:
            out.add_child(build(child))
    return out


def merge(exe_path, mui_path):
    binary = lief.PE.parse(exe_path)
    mui = lief.PE.parse(mui_path)
    if binary is None:
        raise SystemExit(f"could not parse {exe_path}")
    if mui is None:
        raise SystemExit(f"could not parse {mui_path}")

    if binary.resources is None:
        raise SystemExit(f"{exe_path} has no resource directory")

    for res_type in list(mui.resources.childs):
        if res_type.has_name and res_type.name in SKIP_NAMES:
            continue
        if not res_type.has_name and res_type.id in SKIP_IDS:
            continue

        sub = build(res_type)
        root = binary.resources
        existing = next((c for c in root.childs if key(c) == key(res_type)), None)
        if existing is not None:
            root.delete_child(existing)
        binary.resources.add_child(sub)

    config = lief.PE.Builder.config_t()
    config.resources = True
    builder = lief.PE.Builder(binary, config)
    builder.build()
    tmp = exe_path + ".tmp"
    builder.write(tmp)
    os.replace(tmp, exe_path)


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    exe, mui = sys.argv[1], sys.argv[2]
    if not os.path.isfile(exe) or not os.path.isfile(mui):
        print(f"missing file: {exe if not os.path.isfile(exe) else mui}", file=sys.stderr)
        return 1
    merge(exe, mui)
    print(f"merged {os.path.basename(mui)} -> {os.path.basename(exe)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
