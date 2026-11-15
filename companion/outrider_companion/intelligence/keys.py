"""API keys for cloud models (spec AI04-02), kept out of every file Outrider writes.

On Windows the key lives in Windows Credential Manager (generic credential
"Outrider/<provider>", current user only), read with the standard library
(ctypes). Elsewhere, or for a one-off run, the environment variable
OUTRIDER_<PROVIDER>_KEY is used. Keys never go into config.json,
SavedVariables, codes, logs or the repo, and this module never prints one.

    python -m outrider_companion.intelligence.keys set anthropic     (asks for the key, hidden)
    python -m outrider_companion.intelligence.keys status
    python -m outrider_companion.intelligence.keys delete anthropic
"""

import getpass
import os
import sys

PROVIDERS = ("anthropic", "openai", "gemini", "openai-compatible")
PREFIX = "Outrider/"


class _Memory:
    """In-memory store for tests."""

    def __init__(self):
        self.items = {}

    def read(self, target):
        return self.items.get(target)

    def write(self, target, secret):
        self.items[target] = secret

    def delete(self, target):
        return self.items.pop(target, None) is not None


class _WinCred:
    """Windows Credential Manager through advapi32 (generic credentials)."""

    def __init__(self):
        import ctypes
        from ctypes import wintypes
        self.ctypes, self.wt = ctypes, wintypes

        class FILETIME(ctypes.Structure):
            _fields_ = [("lo", wintypes.DWORD), ("hi", wintypes.DWORD)]

        class CREDENTIAL(ctypes.Structure):
            _fields_ = [("Flags", wintypes.DWORD), ("Type", wintypes.DWORD), ("TargetName", wintypes.LPWSTR),
                        ("Comment", wintypes.LPWSTR), ("LastWritten", FILETIME),
                        ("CredentialBlobSize", wintypes.DWORD), ("CredentialBlob", ctypes.POINTER(ctypes.c_ubyte)),
                        ("Persist", wintypes.DWORD), ("AttributeCount", wintypes.DWORD), ("Attributes", ctypes.c_void_p),
                        ("TargetAlias", wintypes.LPWSTR), ("UserName", wintypes.LPWSTR)]

        self.CREDENTIAL = CREDENTIAL
        self.adv = ctypes.WinDLL("advapi32", use_last_error=True)
        self.adv.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(ctypes.POINTER(CREDENTIAL))]
        self.adv.CredWriteW.argtypes = [ctypes.POINTER(CREDENTIAL), wintypes.DWORD]
        self.adv.CredDeleteW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD]
        self.adv.CredFree.argtypes = [ctypes.c_void_p]

    GENERIC, LOCAL_MACHINE = 1, 2   # CRED_TYPE_GENERIC, CRED_PERSIST_LOCAL_MACHINE (this user, this PC)

    def read(self, target):
        p = self.ctypes.POINTER(self.CREDENTIAL)()
        if not self.adv.CredReadW(target, self.GENERIC, 0, self.ctypes.byref(p)):
            return None
        try:
            c = p.contents
            raw = self.ctypes.string_at(c.CredentialBlob, c.CredentialBlobSize)
            return raw.decode("utf-16-le")
        finally:
            self.adv.CredFree(p)

    def write(self, target, secret):
        blob = secret.encode("utf-16-le")
        buf = (self.ctypes.c_ubyte * len(blob)).from_buffer_copy(blob)
        c = self.CREDENTIAL()
        c.Type, c.TargetName, c.Persist = self.GENERIC, target, self.LOCAL_MACHINE
        c.CredentialBlobSize, c.CredentialBlob = len(blob), self.ctypes.cast(buf, self.ctypes.POINTER(self.ctypes.c_ubyte))
        c.UserName = "outrider"
        if not self.adv.CredWriteW(self.ctypes.byref(c), 0):
            raise OSError("Windows Credential Manager refused the key (error %d)" % self.ctypes.get_last_error())

    def delete(self, target):
        return bool(self.adv.CredDeleteW(target, self.GENERIC, 0))


_store = None


def store():
    global _store
    if _store is None:
        _store = _WinCred() if sys.platform == "win32" else _Memory()
    return _store


def use_store(s):
    """Tests swap in an in-memory store."""
    global _store
    _store = s


def get(provider):
    env = os.environ.get("OUTRIDER_%s_KEY" % provider.upper().replace("-", "_"))
    if env:
        return env.strip()
    try:
        return store().read(PREFIX + provider)
    except OSError:
        return None


def set_key(provider, secret):
    if provider not in PROVIDERS:
        raise ValueError("unknown provider %r (one of %s)" % (provider, ", ".join(PROVIDERS)))
    secret = (secret or "").strip()
    if len(secret) < 8 or any(c.isspace() for c in secret):
        raise ValueError("that doesn't look like an API key")
    store().write(PREFIX + provider, secret)


def delete(provider):
    return store().delete(PREFIX + provider)


def status():
    return {p: (get(p) is not None) for p in PROVIDERS}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv or argv[0] not in ("set", "delete", "status"):
        print(__doc__)
        return 1
    if argv[0] == "status":
        for p, has in status().items():
            print("%-18s %s" % (p, "key stored" if has else "-"))
        return 0
    if len(argv) < 2:
        print("which provider? %s" % ", ".join(PROVIDERS))
        return 1
    if argv[0] == "set":
        set_key(argv[1], getpass.getpass("API key for %s (hidden): " % argv[1]))
        print("stored in Windows Credential Manager as %s%s" % (PREFIX, argv[1]))
        return 0
    print("deleted" if delete(argv[1]) else "nothing stored for %s" % argv[1])
    return 0


if __name__ == "__main__":
    sys.exit(main())
