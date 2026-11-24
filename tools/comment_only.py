"""tools/comment_only.py - prove a change touched comments only (OI01-07).

    python -I tools/comment_only.py [base]      base defaults to HEAD

For every changed .lua file under addon/, compares the token stream of the base version with the
working tree, ignoring comments and whitespace. Strings, numbers, names and operators must be
identical. Exit 1 and name the first differing token when code changed.
"""
import re
import subprocess
import sys
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LONG_OPEN = re.compile(r"\[(=*)\[")


def tokens(src):
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
        elif src.startswith("--", i):
            m = LONG_OPEN.match(src, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, i)
                i = n if j < 0 else j + len(close)
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
        elif c == "[" and LONG_OPEN.match(src, i):
            m = LONG_OPEN.match(src, i)
            close = "]" + m.group(1) + "]"
            j = src.find(close, i)
            j = n if j < 0 else j + len(close)
            out.append(src[i:j])
            i = j
        elif c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
        else:
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*|0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\.\.|\.\.|==|~=|<=|>=|.", src[i:])
            out.append(m.group(0))
            i += len(m.group(0))
    return out


def git(*args):
    return subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


def main(argv):
    base = argv[0] if argv else "HEAD"
    files = [f for f in git("diff", "--name-only", base, "--", "addon").split("\n") if f.endswith(".lua")]
    bad = 0
    for f in files:
        old = git("show", "%s:%s" % (base, f))
        path = os.path.join(ROOT, f)
        if not os.path.exists(path):
            print("REMOVED %s" % f)
            bad += 1
            continue
        with open(path, encoding="utf-8", errors="replace") as fh:
            new = fh.read()
        a, b = tokens(old), tokens(new)
        if a != b:
            k = next((i for i, (x, y) in enumerate(zip(a, b)) if x != y), min(len(a), len(b)))
            print("CODE CHANGED %s near token %d: %r -> %r" % (f, k, a[k:k + 3], b[k:k + 3]))
            bad += 1
    print("comment-only check: %d files, %d with code changes" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
