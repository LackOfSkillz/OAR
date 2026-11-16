"""Model providers (spec 6.1, AI02-01/02).

ModelProvider.generate(messages, max_output_tokens, timeout_seconds) -> text.
Errors are ProviderError with a kind: config, connect, timeout, http,
bad_response. No provider ever falls back to another one by itself.

OpenAICompatibleProvider talks to a local server that speaks the OpenAI chat
completions API (Ollama, LM Studio, vLLM, llama.cpp server). The base URL is
Gary's setting; by default only loopback hosts are allowed (a LAN machine is
not private to this PC, so it has to be switched on explicitly). Redirects
are refused, so a server can't send the request somewhere else.
"""

import ipaddress
import json
import socket
import time
import urllib.error
import urllib.parse
import urllib.request

MAX_OUTPUT_TOKENS = 800
TIMEOUT = 60.0
MAX_RESPONSE_BYTES = 256 * 1024


class ProviderError(Exception):
    def __init__(self, kind, message):
        super().__init__(message)
        self.kind = kind


class ModelProvider:
    label = "model"

    def validate_config(self):
        return {"ok": True}

    def healthcheck(self, timeout_seconds=5.0):
        return {"ok": True}

    def generate(self, messages, max_output_tokens=MAX_OUTPUT_TOKENS, timeout_seconds=TIMEOUT):
        raise NotImplementedError


class FakeProvider(ModelProvider):
    """Deterministic provider for tests: replies is a list of strings or
    exceptions (used in order), or a function(messages) -> string."""
    label = "fake"

    def __init__(self, replies):
        self.replies = replies
        self.calls = []

    def generate(self, messages, max_output_tokens=MAX_OUTPUT_TOKENS, timeout_seconds=TIMEOUT):
        self.calls.append(messages)
        if callable(self.replies):
            r = self.replies(messages)
        else:
            if not self.replies:
                raise ProviderError("bad_response", "fake provider has no more replies")
            r = self.replies.pop(0)
        if isinstance(r, Exception):
            raise r
        return r


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ProviderError("config", "the model server tried to redirect to %s; refused" % newurl)


HTTP_KIND = {400: "bad_request", 401: "auth", 403: "auth", 404: "model", 413: "too_large", 429: "rate_limit"}


def post_json(opener, url, body, headers, timeout_seconds, where):
    """POST JSON, return parsed JSON. Errors become ProviderError with a kind:
    auth (wrong or missing key), model (wrong model or URL), rate_limit
    (quota), server (5xx, overloaded), tls, timeout, connect, bad_response.
    The request body and keys are never put into error messages."""
    import ssl
    data = json.dumps(body).encode("utf-8")
    h = {"Content-Type": "application/json", "User-Agent": "Outrider-Companion"}
    h.update(headers or {})
    req = urllib.request.Request(url, data=data, headers=h, method="POST")
    try:
        with opener.open(req, timeout=timeout_seconds) as resp:
            raw = resp.read(MAX_RESPONSE_BYTES + 1)
    except ProviderError:
        raise
    except urllib.error.HTTPError as e:
        kind = HTTP_KIND.get(e.code) or ("server" if e.code >= 500 else "http")
        hint = {"auth": "check the API key (keys command)", "model": "check the model name and URL",
                "rate_limit": "quota or rate limit reached; try later", "server": "the provider is busy or down"}.get(kind, "")
        raise ProviderError(kind, "the model server answered HTTP %s%s" % (e.code, (": " + hint) if hint else ""))
    except ssl.SSLError:
        raise ProviderError("tls", "secure connection to %s failed (certificate or TLS problem)" % where)
    except (socket.timeout, TimeoutError):
        raise ProviderError("timeout", "the model took longer than %.0f s" % timeout_seconds)
    except urllib.error.URLError as e:
        reason = getattr(e, "reason", None)
        if isinstance(reason, (socket.timeout, TimeoutError)):
            raise ProviderError("timeout", "the model took longer than %.0f s" % timeout_seconds)
        if isinstance(reason, ssl.SSLError):
            raise ProviderError("tls", "secure connection to %s failed (certificate or TLS problem)" % where)
        raise ProviderError("connect", "can't reach %s (is it running, or is the network off?)" % where)
    if len(raw) > MAX_RESPONSE_BYTES:
        raise ProviderError("bad_response", "the model's answer was too large")
    try:
        return json.loads(raw.decode("utf-8"))
    except (ValueError, UnicodeDecodeError):
        raise ProviderError("bad_response", "the model server did not answer with JSON")


def _is_loopback(host):
    if host in ("localhost",):
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


class OpenAICompatibleProvider(ModelProvider):
    label = "local model"

    def __init__(self, base_url, model, allow_remote=False, api_key=None, retries=1):
        self.base_url = (base_url or "").rstrip("/")
        self.model = model
        self.allow_remote = allow_remote
        self.api_key = api_key   # local servers usually need none; never logged
        self.retries = max(0, min(int(retries), 2))
        self._opener = urllib.request.build_opener(_NoRedirect)

    def validate_config(self):
        u = urllib.parse.urlparse(self.base_url)
        if u.scheme not in ("http", "https"):
            raise ProviderError("config", "the model URL must start with http:// or https:// (got %r)" % self.base_url)
        if not u.hostname:
            raise ProviderError("config", "the model URL has no host")
        if not self.allow_remote and not _is_loopback(u.hostname):
            raise ProviderError("config", "only this PC (127.0.0.1) is allowed unless allowRemote is set in the config: "
                                          "a model on another machine sees your data")
        if not isinstance(self.model, str) or not self.model.strip():
            raise ProviderError("config", "no model name set")
        return {"ok": True, "host": u.hostname}

    def _post(self, path, body, timeout_seconds):
        headers = {}
        if self.api_key:
            headers["Authorization"] = "Bearer " + self.api_key
        return post_json(self._opener, self.base_url + path, body, headers, timeout_seconds, self.base_url)

    def generate(self, messages, max_output_tokens=MAX_OUTPUT_TOKENS, timeout_seconds=TIMEOUT):
        self.validate_config()
        body = {"model": self.model, "messages": messages, "temperature": 0.2,
                "max_tokens": int(min(max_output_tokens, MAX_OUTPUT_TOKENS)), "stream": False}
        last = None
        for attempt in range(self.retries + 1):
            try:
                out = self._post("/v1/chat/completions", body, timeout_seconds)
                break
            except ProviderError as e:
                last = e
                if e.kind != "connect" or attempt == self.retries:
                    raise
                time.sleep(0.5 * (attempt + 1))
        else:
            raise last
        try:
            text = out["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            raise ProviderError("bad_response", "the model server's answer had no message")
        if not isinstance(text, str):
            raise ProviderError("bad_response", "the model's message was not text")
        return text


COMPANION_DIR = __import__("os").path.dirname(__import__("os").path.dirname(
    __import__("os").path.dirname(__import__("os").path.abspath(__file__))))


def from_config(cfg, usage_path=None):
    """A provider from companion config {"intelligence": {...}}, or None when off.

    provider: "openai-compatible" (local, default), "anthropic", "openai" or
    "gemini" (cloud: key from the key store, cloudConsent required, daily
    token cap from dailyTokenCap)."""
    ic = cfg.get("intelligence") if isinstance(cfg, dict) else None
    if not isinstance(ic, dict) or not ic.get("enabled"):
        return None
    kind = ic.get("provider", "openai-compatible")
    if kind == "openai-compatible":
        from . import keys
        return OpenAICompatibleProvider(ic.get("baseUrl") or "http://127.0.0.1:11434", ic.get("model"),
                                        allow_remote=ic.get("allowRemote") is True,
                                        api_key=keys.get("openai-compatible"))
    from . import budget, cloud, keys
    if kind not in cloud.CLOUD:
        raise ProviderError("config", "unknown provider %r (openai-compatible, anthropic, openai, gemini)" % kind)
    cls, default_model = cloud.CLOUD[kind]
    prov = cls(keys.get(kind), ic.get("model") or default_model, consent=ic.get("cloudConsent") is True)
    guard = budget.SpendGuard(usage_path or __import__("os").path.join(COMPANION_DIR, "usage.json"),
                              ic.get("dailyTokenCap") or budget.DEFAULT_DAILY_TOKENS)
    return budget.Guarded(prov, guard)
