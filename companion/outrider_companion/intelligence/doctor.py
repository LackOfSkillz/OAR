"""What is the AI set up to do? (spec AI04-06)

    python -m outrider_companion.intelligence.doctor          settings only, no network
    python -m outrider_companion.intelligence.doctor --check  also asks a LOCAL model server
                                                              for its model list (never a cloud API)

Shows: on or off, provider, model, where requests go, whether a key is stored
(never the key), cloud consent, today's cloud tokens against the cap.
"""

import json
import os
import sys
import urllib.parse
import urllib.request

from . import budget, keys, providers


def report(cfg, usage_path=None, check=False, opener=None):
    ic = cfg.get("intelligence") if isinstance(cfg, dict) else None
    lines = []
    if not isinstance(ic, dict) or not ic.get("enabled"):
        return ["AI answers: off (Outrider's own steps only). Set \"intelligence\": {\"enabled\": true, ...} in companion/config.json."]
    kind = ic.get("provider", "openai-compatible")
    lines.append("AI answers: on, provider %s, model %s" % (kind, ic.get("model") or "(default)"))
    if kind == "openai-compatible":
        url = ic.get("baseUrl") or "http://127.0.0.1:11434"
        host = urllib.parse.urlparse(url).hostname or "?"
        local = providers._is_loopback(host)
        lines.append("Requests go to %s (%s)" % (url, "this PC" if local else "ANOTHER MACHINE: your data travels there"))
        try:
            providers.OpenAICompatibleProvider(url, ic.get("model"), allow_remote=ic.get("allowRemote") is True).validate_config()
            lines.append("Settings: ok")
        except providers.ProviderError as e:
            lines.append("Settings problem: %s" % e)
        if check:
            try:
                op = opener or urllib.request.build_opener(providers._NoRedirect)
                with op.open(url.rstrip("/") + "/v1/models", timeout=5) as r:
                    data = json.loads(r.read(64 * 1024).decode("utf-8"))
                names = [m.get("id") for m in data.get("data", []) if isinstance(m, dict)]
                lines.append("Model server answered; models: %s" % (", ".join(names[:8]) or "none listed"))
                if ic.get("model") and names and ic.get("model") not in names:
                    lines.append("Warning: model %r is not in that list" % ic.get("model"))
            except Exception as e:  # report, never crash
                lines.append("Model server check failed: %s" % e.__class__.__name__)
    else:
        lines.append("Requests go to the %s cloud API" % kind)
        lines.append("API key: %s" % ("stored" if keys.get(kind) else "MISSING (python -m outrider_companion.intelligence.keys set %s)" % kind))
        lines.append("Cloud consent: %s" % ("given" if ic.get("cloudConsent") is True
                                            else "NOT given: check `ask --preview`, then set \"cloudConsent\": true"))
        guard = budget.SpendGuard(usage_path or os.path.join(providers.COMPANION_DIR, "usage.json"),
                                  ic.get("dailyTokenCap") or budget.DEFAULT_DAILY_TOKENS)
        lines.append("Cloud tokens today: %d of %d" % (guard.used_today(), guard.cap))
        if check:
            lines.append("(--check never calls a cloud API; ask a question to test it)")
    return lines


def main(argv=None):
    from .ask import load_config
    argv = sys.argv[1:] if argv is None else argv
    for line in report(load_config(), check="--check" in argv):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
