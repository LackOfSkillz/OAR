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
        data = json.dumps(body).encode("utf-8")
        headers = {"Content-Type": "application/json", "User-Agent": "Outrider-Companion"}
        if self.api_key:
            headers["Authorization"] = "Bearer " + self.api_key
        req = urllib.request.Request(self.base_url + path, data=data, headers=headers, method="POST")
        try:
            with self._opener.open(req, timeout=timeout_seconds) as resp:
                raw = resp.read(MAX_RESPONSE_BYTES + 1)
        except ProviderError:
            raise
        except urllib.error.HTTPError as e:
            raise ProviderError("http", "the model server answered HTTP %s" % e.code)
        except (socket.timeout, TimeoutError):
            raise ProviderError("timeout", "the model took longer than %.0f s" % timeout_seconds)
        except urllib.error.URLError as e:
            if isinstance(getattr(e, "reason", None), (socket.timeout, TimeoutError)):
                raise ProviderError("timeout", "the model took longer than %.0f s" % timeout_seconds)
            raise ProviderError("connect", "can't reach the model server at %s (is it running?)" % self.base_url)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise ProviderError("bad_response", "the model's answer was too large")
        try:
            return json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise ProviderError("bad_response", "the model server did not answer with JSON")

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


def from_config(cfg):
    """A provider from companion config {"intelligence": {...}}, or None when off."""
    ic = cfg.get("intelligence") if isinstance(cfg, dict) else None
    if not isinstance(ic, dict) or not ic.get("enabled"):
        return None
    kind = ic.get("provider", "openai-compatible")
    if kind != "openai-compatible":
        raise ProviderError("config", "provider %r is not available yet (only openai-compatible local models)" % kind)
    return OpenAICompatibleProvider(ic.get("baseUrl") or "http://127.0.0.1:11434", ic.get("model"),
                                    allow_remote=ic.get("allowRemote") is True)
