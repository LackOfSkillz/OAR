#!/usr/bin/env python3
"""Run a Lua 5.1 script when no Lua interpreter is installed.

    python tools/lua.py tests/run_tests.lua [args...]

Uses the 'lupa' package (pip install lupa), which bundles real Lua 5.1, the
same language version WoW uses. Exit code is the script's os.exit code.
"""
import sys

try:
    from lupa import lua51
except ImportError:
    sys.stderr.write("lupa is not installed. Run:  python -m pip install lupa\n")
    sys.exit(3)


def main() -> int:
    if len(sys.argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    script, args = sys.argv[1], sys.argv[2:]
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    argtable = {0: script}
    for i, a in enumerate(args, start=1):
        argtable[i] = a
    g.arg = lua.table_from(argtable)

    # lupa's Lua is built without io.popen, so give scripts a file lister.
    import os

    def list_lua(directory):
        found = []
        for root, _dirs, files in os.walk(directory):
            for name in files:
                if name.endswith(".lua"):
                    found.append(os.path.join(root, name).replace(os.sep, "/"))
        return lua.table_from(sorted(found))

    g.OTR_HOST_LIST_LUA = list_lua
    try:
        g.dofile(script)
    except Exception as exc:  # LuaError and friends
        sys.stdout.flush()
        sys.stderr.write(f"lua error: {exc}\n")
        return 1
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
