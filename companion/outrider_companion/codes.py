"""Outrider export codes in Python (no-reload advice, 2026-11-11).

Byte-for-byte the same format as addon/Outrider/Core/Serialize.lua:
  wire:   Z nil | T true | F false | N<number>; | S<len>:<bytes> | { k v k v ... }
  export: OTR1:<8 hex adler32>:<base64 payload>
Decoding never evaluates anything; lengths and depth are checked.
"""

import base64
import math

TAG = "OTR1"
MAX_DEPTH = 32
MAX_LEN = 400000


class CodeError(ValueError):
    pass


def _num(v):
    if isinstance(v, bool):
        raise CodeError("bool is not a number")
    if isinstance(v, float) and not math.isfinite(v):
        raise CodeError("cannot encode NaN/inf")
    if float(v) == math.floor(v) and -2 ** 53 < v < 2 ** 53:
        return "N%d;" % int(v)
    return "N%s;" % repr(float(v))


def _key_sort(k):
    order = {bool: 0, int: 1, float: 1, str: 2}  # Lua sorts by type name: boolean < number < string
    return (order[type(k)], (1 if k else 0) if isinstance(k, bool) else k)


def _enc(v, out, depth):
    if v is None:
        out.append(b"Z")
    elif v is True:
        out.append(b"T")
    elif v is False:
        out.append(b"F")
    elif isinstance(v, (int, float)):
        out.append(_num(v).encode())
    elif isinstance(v, str):
        b = v.encode("utf-8")
        out.append(b"S%d:" % len(b) + b)
    elif isinstance(v, (list, tuple, dict)):
        if depth >= MAX_DEPTH:
            raise CodeError("table too deep")
        out.append(b"{")
        if isinstance(v, (list, tuple)):
            for i, x in enumerate(v, 1):
                _enc(i, out, depth + 1)
                _enc(x, out, depth + 1)
        else:
            n = 0
            while (n + 1) in v:
                n += 1
            for i in range(1, n + 1):
                _enc(i, out, depth + 1)
                _enc(v[i], out, depth + 1)
            rest = [k for k in v if not (isinstance(k, int) and not isinstance(k, bool) and 1 <= k <= n)]
            for k in sorted(rest, key=_key_sort):
                if not isinstance(k, (str, int, float, bool)):
                    raise CodeError("bad key type")
                _enc(k, out, depth + 1)
                _enc(v[k], out, depth + 1)
        out.append(b"}")
    else:
        raise CodeError("cannot encode %s" % type(v).__name__)


def encode(v):
    out = []
    _enc(v, out, 0)
    return b"".join(out)


def _dec(s, pos, depth):
    if pos >= len(s):
        raise CodeError("unexpected end")
    c = s[pos:pos + 1]
    if c == b"Z":
        return None, pos + 1
    if c == b"T":
        return True, pos + 1
    if c == b"F":
        return False, pos + 1
    if c == b"N":
        stop = s.find(b";", pos + 1)
        if stop < 0:
            raise CodeError("unterminated number")
        raw = s[pos + 1:stop].decode("ascii", "replace")
        try:
            f = float(raw)
        except ValueError:
            raise CodeError("bad number")
        if not math.isfinite(f):
            raise CodeError("bad number")
        return (int(f) if f.is_integer() and "e" not in raw.lower() and "." not in raw else f), stop + 1
    if c == b"S":
        colon = s.find(b":", pos + 1)
        if colon < 0:
            raise CodeError("bad string header")
        try:
            n = int(s[pos + 1:colon])
        except ValueError:
            raise CodeError("bad string length")
        if n < 0 or colon + 1 + n > len(s):
            raise CodeError("string runs past end")
        return s[colon + 1:colon + 1 + n].decode("utf-8", "replace"), colon + 1 + n
    if c == b"{":
        if depth >= MAX_DEPTH:
            raise CodeError("table too deep")
        t, pos = {}, pos + 1
        while True:
            if pos >= len(s):
                raise CodeError("unterminated table")
            if s[pos:pos + 1] == b"}":
                break
            k, pos = _dec(s, pos, depth + 1)
            if k is None or isinstance(k, dict):
                raise CodeError("bad table key")
            v, pos = _dec(s, pos, depth + 1)
            t[k] = v
        keys = list(t)
        if keys and all(isinstance(k, int) and not isinstance(k, bool) for k in keys) and \
                sorted(keys) == list(range(1, len(keys) + 1)):
            return [t[i] for i in range(1, len(keys) + 1)], pos + 1
        return t, pos + 1
    raise CodeError("unexpected byte at %d" % pos)


def decode(payload):
    if len(payload) > MAX_LEN:
        raise CodeError("too long")
    v, pos = _dec(payload, 0, 0)
    if pos != len(payload):
        raise CodeError("trailing data")
    return v


def adler32(b):
    a, c = 1, 0
    for x in b:
        a = (a + x) % 65521
        c = (c + a) % 65521
    return "%04x%04x" % (c, a)


def export(value):
    payload = encode(value)
    return "%s:%s:%s" % (TAG, adler32(payload), base64.b64encode(payload).decode("ascii"))


def import_code(text):
    if not isinstance(text, str):
        raise CodeError("nothing to import")
    text = text.strip()
    parts = text.split(":", 2)
    if len(parts) != 3 or parts[0] != TAG:
        raise CodeError("not an Outrider code")
    try:
        payload = base64.b64decode("".join(parts[2].split()), validate=True)
    except ValueError:
        raise CodeError("bad base64")
    if adler32(payload) != parts[1].lower():
        raise CodeError("checksum mismatch (the code was cut off or edited)")
    return decode(payload)
