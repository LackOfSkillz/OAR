"""Safe, bounded, read-only inspection of Outrider's completed SavedVariables.

Do not execute Lua, mutate WTF or infer a session from a /reload checkpoint.
"""
import hashlib
import os
from pathlib import Path

from .. import luadata

MAX_FILE_BYTES = 2 * 1024 * 1024
MAX_SESSIONS = 20


class SessionReadError(ValueError):
    pass


def stable_bytes(path, *, cap=MAX_FILE_BYTES):
    path = Path(path)
    if path.name.lower() != "outrider_db.lua":
        raise SessionReadError("select the Outrider_DB.lua SavedVariables file")
    if not path.is_file() or path.is_symlink():
        raise SessionReadError("saved file is missing or is a symlink")
    first = path.stat()
    if first.st_size <= 0 or first.st_size > cap:
        raise SessionReadError("saved file is empty or too large")
    data = path.read_bytes()
    last = path.stat()
    if (first.st_size, first.st_mtime_ns, first.st_ino) != (
            last.st_size, last.st_mtime_ns, last.st_ino) or len(data) != first.st_size:
        raise SessionReadError("SavedVariables changed while reading; retry after logout")
    # A second complete read catches partial/in-place writes that retain metadata.
    if path.read_bytes() != data:
        raise SessionReadError("SavedVariables is not stable")
    return data


def read_sessions(path, *, character=None):
    data = stable_bytes(path)
    try:
        root = luadata.parse(data.decode("utf-8-sig"))
    except (UnicodeDecodeError, luadata.LuaDataError) as exc:
        raise SessionReadError("SavedVariables is incomplete or not plain Lua data") from exc
    saved = root.get("Outrider_DB")
    if not isinstance(saved, dict) or not isinstance(saved.get("chars"), dict):
        raise SessionReadError("Outrider character database is missing")
    records = []
    for key, char in saved["chars"].items():
        if not isinstance(key, str) or (character is not None and key != character):
            continue
        if not isinstance(char, dict):
            continue
        state = char.get("xp60")
        if not isinstance(state, dict) or state.get("schema") != 1:
            continue
        history = state.get("history", [])
        if not isinstance(history, list) or len(history) > MAX_SESSIONS:
            raise SessionReadError("session history exceeds bounds")
        seen = set()
        for item in history:
            if not isinstance(item, dict) or item.get("schema") != 1:
                continue
            sid = item.get("sessionId")
            if not isinstance(sid, str) or not 1 <= len(sid) <= 80:
                continue
            if sid in seen:
                continue
            seen.add(sid)
            # Do not include account name in telemetry sent to models. It is a
            # private client-side binding needed for matching delivery.
            records.append((key, item))
    records.sort(key=lambda it: (it[1].get("endedAt") or 0, it[1]["sessionId"]))
    return {
        "sourceDigest": hashlib.sha256(data).hexdigest(),
        "sessions": records,
        "snapshots": root.get("Outrider_Snapshots") or {},
    }


def newest_completed(result, *, character=None):
    for key, session in reversed(result["sessions"]):
        if character is not None and character != key:
            continue
        if session.get("final") is True and not (session.get("flags") or {}).get("incomplete"):
            return key, session
    return None
