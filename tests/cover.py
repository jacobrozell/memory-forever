"""Line coverage for the addon sources, measured while the suite runs.

    .venv\\Scripts\\python.exe tests\\cover.py

Counts a source line when the suite executes it. Blank lines, comments, and
lines that are only `end` or `else` are left out of the total.
"""
import os
import re
import sys

try:
    import lupa.lua51 as lupa
except ImportError:
    sys.exit("lupa is required: pip install -r requirements-dev.txt")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

SKIP_DIRS = ("tests", ".venv")
ADDON_ROOTS = ("Core", "Data", "Trackers", "UI", "View")
ADDON_FILES = ("Commands.lua", "Init.lua")


def addon_sources():
    found = []
    for name in ADDON_FILES:
        if os.path.isfile(name):
            found.append(name.replace("\\", "/"))
    for folder in ADDON_ROOTS:
        for dirpath, _, files in os.walk(folder):
            for name in files:
                if name.endswith(".lua"):
                    found.append(os.path.join(dirpath, name).replace("\\", "/"))
    return sorted(found)


def coverable_lines(path):
    lines = {}
    in_block = False
    with open(path, encoding="utf-8") as handle:
        for number, raw in enumerate(handle, 1):
            text = raw.strip()
            if in_block:
                if "]]" in text:
                    in_block = False
                continue
            if text.startswith("--[["):
                if "]]" not in text[4:]:
                    in_block = True
                continue
            if text == "" or text.startswith("--"):
                continue
            if text in ("end", "else", "end,", "end)", "}", "})", "},", ")"):
                continue
            lines[number] = text
    return lines


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(
        r"""
COVER_HITS = {}
local function hook()
  local info = debug.getinfo(2, "Sl")
  if not info or not info.source or not info.currentline or info.currentline < 1 then return end
  local src = info.source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  src = src:gsub("\\", "/")
  if src:find("tests/", 1, true) or src:find("/tests/", 1, true) then return end
  local bucket = COVER_HITS[src]
  if not bucket then
    bucket = {}
    COVER_HITS[src] = bucket
  end
  bucket[info.currentline] = true
end
debug.sethook(hook, "l")
RUN_EMBEDDED = true
"""
    )
    with open(os.path.join("tests", "run.lua"), encoding="utf-8") as handle:
        failed = lua.execute(handle.read())
    lua.execute("debug.sethook()")

    hits = {}
    cover = lua.globals().COVER_HITS
    for src, lines in cover.items():
        key = str(src).replace("\\", "/")
        hits[key] = {int(n) for n in lines.keys()}

    total_hit = 0
    total_lines = 0
    rows = []
    missed = []
    for path in addon_sources():
        coverable = coverable_lines(path)
        seen = hits.get(path, set())
        # loadfile may report a relative path; also accept a suffix match
        if not seen:
            for src, numbers in hits.items():
                if src.endswith(path):
                    seen = numbers
                    break
        hit = sum(1 for n in coverable if n in seen)
        count = len(coverable)
        total_hit += hit
        total_lines += count
        percent = (100.0 * hit / count) if count else 100.0
        rows.append((percent, hit, count, path))
        for number, text in sorted(coverable.items()):
            if number not in seen:
                missed.append((path, number, text))

    rows.sort()
    print("file coverage (lowest first)")
    for percent, hit, count, path in rows:
        print(f"  {percent:5.1f}%  {hit:4d}/{count:<4d}  {path}")
    overall = (100.0 * total_hit / total_lines) if total_lines else 100.0
    print(f"\n{overall:.1f}%  {total_hit}/{total_lines} coverable lines")
    print(f"tests failed: {int(failed or 0)}")
    print("\nuncovered")
    current = None
    for path, number, text in missed:
        if path != current:
            print(f"\n{path}")
            current = path
        print(f"  {number}: {text[:120]}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
