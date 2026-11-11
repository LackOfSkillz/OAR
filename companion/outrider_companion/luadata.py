"""Read and write WoW SavedVariables as plain data (P9-03).

Reading never executes the file: a small tokenizer accepts only what WoW
writes into SavedVariables (`Name = <value>` statements; tables, strings,
numbers, true/false/nil, `--` comments) and rejects anything else
(function calls, operators, code). Writing produces the same plain shape,
with every string quoted and escaped the way Lua's %q does, so text such
as ``]]``, ``--`` or quotes inside advice can never break out of the data.
"""

import math
import re

__all__ = ["parse", "dumps", "LuaDataError", "quote"]


class LuaDataError(ValueError):
    pass


_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_NUMBER = re.compile(r"-?(0[xX][0-9A-Fa-f]+|(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)")
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v",
        "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class _Reader:
    def __init__(self, text):
        self.s, self.i, self.n = text, 0, len(text)

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise LuaDataError("%s at line %d" % (msg, line))

    def skip(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n;":
                self.i += 1
            elif s.startswith("--", self.i):
                if s.startswith("--[[", self.i):
                    end = s.find("]]", self.i + 4)
                    self.i = n if end < 0 else end + 2
                else:
                    end = s.find("\n", self.i)
                    self.i = n if end < 0 else end + 1
            else:
                break

    def peek(self):
        self.skip()
        return self.s[self.i] if self.i < self.n else ""

    def expect(self, ch):
        if self.peek() != ch:
            self.error("expected %r" % ch)
        self.i += 1

    def name(self):
        self.skip()
        m = _NAME.match(self.s, self.i)
        if not m:
            self.error("expected a name")
        self.i = m.end()
        return m.group(0)

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = []
        s, n = self.s, self.n
        while True:
            if self.i >= n:
                self.error("unfinished string")
            c = s[self.i]
            if c == q:
                self.i += 1
                return "".join(out)
            if c == "\n":
                self.error("newline in string")
            if c == "\\":
                self.i += 1
                e = s[self.i] if self.i < n else ""
                if e.isdigit():
                    m = re.match(r"\d{1,3}", s[self.i:])
                    code = int(m.group(0))
                    if code > 255:
                        self.error("bad escape")
                    out.append(chr(code))
                    self.i += len(m.group(0))
                elif e in _ESC:
                    out.append(_ESC[e])
                    self.i += 1
                else:
                    self.error("bad escape")
            else:
                out.append(c)
                self.i += 1

    def long_string(self):
        m = re.match(r"\[(=*)\[", self.s[self.i:])
        if not m:
            self.error("bad long string")
        close = "]" + m.group(1) + "]"
        start = self.i + m.end()
        end = self.s.find(close, start)
        if end < 0:
            self.error("unfinished long string")
        self.i = end + len(close)
        text = self.s[start:end]
        return text[1:] if text.startswith("\n") else text

    def number(self):
        m = _NUMBER.match(self.s, self.i)
        if not m:
            self.error("bad number")
        self.i = m.end()
        t = m.group(0)
        if t.lower().lstrip("-").startswith("0x"):
            return int(t, 16)
        v = float(t)
        return int(v) if v.is_integer() and "." not in t and "e" not in t.lower() else v

    def value(self, depth=0):
        if depth > 64:
            self.error("nested too deep")
        c = self.peek()
        if c == "{":
            return self.table(depth)
        if c in "\"'":
            return self.string()
        if c == "[" and re.match(r"\[=*\[", self.s[self.i:]):
            return self.long_string()
        if c == "-" or c.isdigit() or c == ".":
            return self.number()
        word = self.name()
        if word == "true":
            return True
        if word == "false":
            return False
        if word == "nil":
            return None
        self.error("unexpected %r (only plain data is allowed)" % word)

    def table(self, depth):
        self.expect("{")
        items, arr = {}, []
        while True:
            c = self.peek()
            if c == "}":
                self.i += 1
                break
            if c == "[" and not re.match(r"\[=*\[", self.s[self.i:]):
                self.i += 1
                key = self.value(depth + 1)
                self.expect("]")
                self.expect("=")
                items[key] = self.value(depth + 1)
            else:
                save = self.i
                m = _NAME.match(self.s, self.i)
                if m and m.group(0) not in ("true", "false", "nil"):
                    self.i = m.end()
                    if self.peek() == "=":
                        self.i += 1
                        items[m.group(0)] = self.value(depth + 1)
                    else:
                        self.i = save
                        arr.append(self.value(depth + 1))
                else:
                    arr.append(self.value(depth + 1))
            c = self.peek()
            if c in ",;":
                self.i += 1
            elif c != "}":
                self.error("expected , or }")
        if arr and not items:
            return arr
        for idx, v in enumerate(arr, 1):
            items.setdefault(idx, v)
        # a table whose keys are exactly 1..n reads as a list
        if items and all(isinstance(k, int) and not isinstance(k, bool) for k in items):
            keys = sorted(items)
            if keys == list(range(1, len(keys) + 1)):
                return [items[k] for k in keys]
        return items


def parse(text):
    """Parse a SavedVariables file into {global name: value}."""
    r = _Reader(text)
    out = {}
    while r.peek():
        name = r.name()
        r.expect("=")
        out[name] = r.value()
    return out


def quote(s):
    """Quote a string like Lua's %q (safe for any content)."""
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif o < 32 or o == 127:
            out.append("\\%03d" % o)
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def _dump(v, indent, depth):
    if depth > 32:
        raise LuaDataError("nested too deep")
    if v is None:
        return "nil"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if not math.isfinite(v):
            raise LuaDataError("number is not finite")
        return repr(v)
    if isinstance(v, str):
        return quote(v)
    pad, inner = "  " * indent, "  " * (indent + 1)
    if isinstance(v, (list, tuple)):
        if not v:
            return "{}"
        return "{\n" + "".join(inner + _dump(x, indent + 1, depth + 1) + ",\n" for x in v) + pad + "}"
    if isinstance(v, dict):
        if not v:
            return "{}"
        parts = []
        for k in sorted(v, key=lambda k: (isinstance(k, str), str(k))):
            if isinstance(k, bool) or not isinstance(k, (str, int)):
                raise LuaDataError("table keys must be strings or integers")
            key = ("[%d]" % k) if isinstance(k, int) else ("[%s]" % quote(k))
            parts.append(inner + key + " = " + _dump(v[k], indent + 1, depth + 1) + ",\n")
        return "{\n" + "".join(parts) + pad + "}"
    raise LuaDataError("cannot write %s" % type(v).__name__)


def dumps(name, value):
    """`Name = <value>` as plain Lua data."""
    if not _NAME.fullmatch(name):
        raise LuaDataError("bad global name")
    return "%s = %s\n" % (name, _dump(value, 0, 0))
