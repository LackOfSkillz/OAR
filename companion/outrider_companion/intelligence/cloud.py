"""Cloud model providers (spec AI04-01): Anthropic, OpenAI, Gemini.

Raw HTTP with the standard library: the companion installs nothing (its
README promises that), so no vendor SDKs here. Every cloud provider:
- needs an API key from the key store (keys.py: Windows Credential Manager),
- refuses to run until Gary set "cloudConsent": true in the config, after
  looking at the exact payload with `ask --preview`,
- goes through the daily spend cap (budget.py) before each call,
- never falls back to another provider by itself.
These adapters are tested against local stand-in servers only; no request has
been sent to a real provider from this PC.
"""

import urllib.request

from .providers import ModelProvider, ProviderError, _NoRedirect, post_json

ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2026-10-21"
ANTHROPIC_DEFAULT_MODEL = "claude-opus-5-5"
OPENAI_URL = "https://api.openai.com/v1/chat/completions"
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
MAX_TOKENS = 4000   # a short JSON answer, with room for the model's thinking


class CloudProvider(ModelProvider):
    name = "cloud"

    def __init__(self, api_key, model, consent=False, url=None):
        self.api_key = api_key
        self.model = model
        self.consent = consent is True
        self.url = url          # tests point this at a local stand-in server
        self._opener = urllib.request.build_opener(_NoRedirect)
        self.last_usage = None

    def validate_config(self):
        if not self.consent:
            raise ProviderError("consent", "cloud models are off until you look at what would be sent "
                                           "(ask --preview) and set \"cloudConsent\": true in companion/config.json")
        if not self.api_key:
            raise ProviderError("auth", "no API key stored for %s (keys set %s)" % (self.name, self.name))
        if not isinstance(self.model, str) or not self.model.strip():
            raise ProviderError("config", "no model name set for %s" % self.name)
        return {"ok": True, "provider": self.name}

    @staticmethod
    def _split(messages):
        system = "\n\n".join(m["content"] for m in messages if m.get("role") == "system")
        rest = [m for m in messages if m.get("role") != "system"]
        return system, rest


class AnthropicProvider(CloudProvider):
    """Claude via the Messages API. No server-side fallback or model substitution.
    A refusal is returned to the caller; another paid model is never selected."""
    name = "anthropic"
    label = "Claude (Anthropic API)"

    def generate(self, messages, max_output_tokens=MAX_TOKENS, timeout_seconds=120.0):
        self.validate_config()
        system, rest = self._split(messages)
        body = {"model": self.model, "max_tokens": int(max_output_tokens or MAX_TOKENS),
                "system": system, "messages": rest,
                "output_config": {"effort": "low"}}   # a short structured answer
        headers = {"x-api-key": self.api_key, "anthropic-version": ANTHROPIC_VERSION}
        out = post_json(self._opener, self.url or ANTHROPIC_URL, body, headers, timeout_seconds, "the Anthropic API")
        u = out.get("usage") if isinstance(out, dict) else None
        if isinstance(u, dict):
            self.last_usage = {"input": u.get("input_tokens", 0), "output": u.get("output_tokens", 0)}
        if not isinstance(out, dict):
            raise ProviderError("bad_response", "unexpected answer from the Anthropic API")
        if out.get("stop_reason") == "refusal":
            raise ProviderError("refused", "Claude declined this request")
        texts = [b.get("text", "") for b in out.get("content") or [] if isinstance(b, dict) and b.get("type") == "text"]
        if not texts:
            raise ProviderError("bad_response", "Claude's answer had no text")
        return "".join(texts)


class OpenAIProvider(CloudProvider):
    name = "openai"
    label = "OpenAI API"

    def generate(self, messages, max_output_tokens=MAX_TOKENS, timeout_seconds=120.0):
        self.validate_config()
        body = {"model": self.model, "messages": messages, "max_completion_tokens": int(max_output_tokens or MAX_TOKENS)}
        out = post_json(self._opener, self.url or OPENAI_URL, body, {"Authorization": "Bearer " + self.api_key},
                        timeout_seconds, "the OpenAI API")
        u = out.get("usage") if isinstance(out, dict) else None
        if isinstance(u, dict):
            self.last_usage = {"input": u.get("prompt_tokens", 0), "output": u.get("completion_tokens", 0)}
        try:
            text = out["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            raise ProviderError("bad_response", "the OpenAI answer had no message")
        if not isinstance(text, str):
            raise ProviderError("bad_response", "the OpenAI answer was not text")
        return text


class GeminiProvider(CloudProvider):
    name = "gemini"
    label = "Gemini API"

    def generate(self, messages, max_output_tokens=MAX_TOKENS, timeout_seconds=120.0):
        self.validate_config()
        system, rest = self._split(messages)
        body = {"contents": [{"role": "user", "parts": [{"text": m["content"]}]} for m in rest],
                "generationConfig": {"maxOutputTokens": int(max_output_tokens or MAX_TOKENS)}}
        if system:
            body["systemInstruction"] = {"parts": [{"text": system}]}
        url = self.url or (GEMINI_URL % urllib.request.quote(self.model, safe=""))
        out = post_json(self._opener, url, body, {"x-goog-api-key": self.api_key}, timeout_seconds, "the Gemini API")
        u = out.get("usageMetadata") if isinstance(out, dict) else None
        if isinstance(u, dict):
            self.last_usage = {"input": u.get("promptTokenCount", 0), "output": u.get("candidatesTokenCount", 0)}
        try:
            parts = out["candidates"][0]["content"]["parts"]
            text = "".join(p.get("text", "") for p in parts if isinstance(p, dict))
        except (KeyError, IndexError, TypeError):
            raise ProviderError("bad_response", "the Gemini answer had no text")
        if not text:
            raise ProviderError("bad_response", "the Gemini answer was empty")
        return text


CLOUD = {"anthropic": (AnthropicProvider, ANTHROPIC_DEFAULT_MODEL), "openai": (OpenAIProvider, None),
         "gemini": (GeminiProvider, None)}
