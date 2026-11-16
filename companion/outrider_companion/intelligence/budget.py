"""Spend guard (spec AI04-02): a daily token cap for cloud models.

Usage is counted per day and provider in companion/usage.json (machine-only,
never committed). Before a cloud call the guard checks today's total plus a
worst-case estimate for this call (input characters / 3 + max output tokens);
over the cap, the call is refused and the answer falls back to Outrider's own
steps. Local models are not capped.
"""

import json
import os
import time

from .providers import ProviderError

DEFAULT_DAILY_TOKENS = 100000


class SpendGuard:
    def __init__(self, path, daily_tokens=DEFAULT_DAILY_TOKENS, clock=time.time):
        self.path = path
        self.cap = int(daily_tokens) if daily_tokens else DEFAULT_DAILY_TOKENS
        self.clock = clock

    def _today(self):
        return time.strftime("%Y-%m-%d", time.localtime(self.clock()))

    def _load(self):
        try:
            with open(self.path, encoding="utf-8") as f:
                data = json.load(f)
            return data if isinstance(data, dict) else {}
        except (OSError, ValueError):
            return {}

    def used_today(self):
        day = self._load().get(self._today()) or {}
        return sum(int(v.get("input", 0)) + int(v.get("output", 0)) for v in day.values() if isinstance(v, dict))

    def check(self, messages, max_output_tokens):
        chars = sum(len(m.get("content") or "") for m in messages)
        estimate = chars // 3 + int(max_output_tokens)
        used = self.used_today()
        if used + estimate > self.cap:
            raise ProviderError("budget", "today's cloud token cap is reached (%d of %d used; "
                                          "raise dailyTokenCap in companion/config.json)" % (used, self.cap))
        return estimate

    def record(self, provider, usage):
        if not usage:
            return
        data = self._load()
        day = data.setdefault(self._today(), {})
        row = day.setdefault(provider, {"input": 0, "output": 0, "calls": 0})
        row["input"] += int(usage.get("input", 0) or 0)
        row["output"] += int(usage.get("output", 0) or 0)
        row["calls"] += 1
        for k in sorted(data)[:-30]:   # keep a month
            del data[k]
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=1)
        os.replace(tmp, self.path)


class Guarded:
    """A cloud provider behind the spend guard."""

    def __init__(self, provider, guard):
        self.provider, self.guard = provider, guard
        self.label = provider.label

    def validate_config(self):
        return self.provider.validate_config()

    def generate(self, messages, max_output_tokens=4000, timeout_seconds=120.0):
        self.provider.validate_config()
        self.guard.check(messages, max_output_tokens)
        try:
            return self.provider.generate(messages, max_output_tokens, timeout_seconds)
        finally:
            self.guard.record(self.provider.name, self.provider.last_usage)
