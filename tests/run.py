#!/usr/bin/env python3
"""Headless test runner. Needs the `luau` binary (https://github.com/luau-lang/luau/releases) in PATH.

It bundles the library sources into one script, loads them through Config.Loader, runs the portable
suite (Tests.luau) and then the mock-only interaction tests.

    python3 tests/run.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read().replace("\r\n", "\n")


def long_string(text):
    level = 3
    while f"]{'=' * level}]" in text:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{text}]{eq}]"


def main():
    luau = shutil.which("luau")
    if not luau:
        print("luau binary not found in PATH")
        return 2

    modules = {name: read(f"{name}.luau") for name in ("src/ThemeEngine", "src/Core", "src/Notifications", "src/Controls")}
    bundle = [
        "local Mock = (function()",
        read("tests/mock_roblox.luau"),
        "end)()",
        "local Sources = {}",
    ]
    for name, src in modules.items():
        bundle.append(f'Sources["{name}"] = {long_string(src)}')
    bundle.append(f"local InitSource = {long_string(read('Init.luau'))}")
    bundle.append(f"local TestsSource = {long_string(read('Tests.luau'))}")
    bundle.append(f"local ExtraSource = {long_string(read('tests/headless_extra.luau'))}")
    bundle.append(
        """
local Init = assert(loadstring(InitSource, "=Init"))
local Library = Init({ Loader = function(path) return assert(Sources[path], "missing module " .. path) end })
local Tests = assert(loadstring(TestsSource, "=Tests"))
local result = Tests(Library)

-- the suite ends with Library:Destroy(), build a fresh library for the interaction tests
local Library2 = Init({ Loader = function(path) return assert(Sources[path], "missing module " .. path) end })
local Extra = assert(loadstring(ExtraSource, "=Extra"))
local extra = Extra(Library2, Mock)

local failed = result.Failed + extra.Failed
print(failed == 0 and "\\nALL GREEN" or ("\\nFAILED: " .. failed))
if #(Mock.Warnings or {}) > 0 then
	print("warnings emitted:")
	for _, w in Mock.Warnings do print("  " .. w) end
end
if failed > 0 then error("tests failed") end
"""
    )

    tmp = tempfile.mkdtemp()
    try:
        path = os.path.join(tmp, "bundle.luau")
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(bundle))
        return subprocess.call([luau, path], cwd=tmp)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
