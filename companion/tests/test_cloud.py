"""Cloud providers, keys, spend cap, preview, doctor (AI-04). Run: py -I companion/tests/test_cloud.py
Everything talks to local stand-in servers; nothing reaches a real provider."""
import http.server
import io
import json
import os
import ssl
import sys
import tempfile
import threading
import unittest
import urllib.error
from contextlib import redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import codes  # noqa: E402
from outrider_companion.intelligence import ask, budget, cloud, context, doctor, keys, orchestrator, providers, window  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from test_intelligence import reply, snapshot_code  # noqa: E402


class Stub(http.server.BaseHTTPRequestHandler):
    status, body, seen = 200, None, []

    def log_message(self, *a):
        pass

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        Stub.seen.append({"path": self.path, "headers": {k.lower(): v for k, v in self.headers.items()}, "body": json.loads(self.rfile.read(n))})
        data = json.dumps(Stub.body if Stub.body is not None else {}).encode()
        self.send_response(Stub.status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


class CloudBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.srv = http.server.HTTPServer(("127.0.0.1", 0), Stub)
        cls.url = "http://127.0.0.1:%d/x" % cls.srv.server_address[1]
        threading.Thread(target=cls.srv.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.srv.shutdown()
        cls.srv.server_close()

    def setUp(self):
        Stub.status, Stub.body, Stub.seen = 200, None, []

    MSGS = [{"role": "system", "content": "rules"}, {"role": "user", "content": "question"}]


class Anthropic(CloudBase):
    def test_request_shape_and_answer(self):
        Stub.body = {"content": [{"type": "thinking", "thinking": ""}, {"type": "text", "text": reply()}],
                     "stop_reason": "end_turn", "usage": {"input_tokens": 120, "output_tokens": 40}}
        p = cloud.AnthropicProvider("sk-test-123456", "claude-opus-5-5", consent=True, url=self.url)
        out = p.generate(self.MSGS)
        self.assertIn("Quest first", out)
        req = Stub.seen[0]
        self.assertEqual(req["headers"].get("x-api-key"), "sk-test-123456")
        self.assertEqual(req["headers"].get("anthropic-version"), cloud.ANTHROPIC_VERSION)
        self.assertIn("server-side-fallback", req["headers"].get("anthropic-beta", ""))
        b = req["body"]
        self.assertEqual(b["system"], "rules")
        self.assertEqual([m["role"] for m in b["messages"]], ["user"])
        self.assertEqual(b["fallbacks"], "default")
        for banned in ("temperature", "top_p", "top_k", "thinking"):
            self.assertNotIn(banned, b)
        self.assertEqual(p.last_usage, {"input": 120, "output": 40})

    def test_refusal_and_http_errors(self):
        p = cloud.AnthropicProvider("sk-test-123456", "claude-opus-5-5", consent=True, url=self.url)
        Stub.body = {"content": [], "stop_reason": "refusal"}
        with self.assertRaises(providers.ProviderError) as e:
            p.generate(self.MSGS)
        self.assertEqual(e.exception.kind, "refused")
        for status, kind in ((401, "auth"), (404, "model"), (429, "rate_limit"), (529, "server"), (500, "server")):
            Stub.status, Stub.body = status, {"type": "error"}
            with self.assertRaises(providers.ProviderError) as e:
                p.generate(self.MSGS)
            self.assertEqual(e.exception.kind, kind, status)
            self.assertNotIn("sk-test", str(e.exception))

    def test_consent_and_key_required(self):
        with self.assertRaises(providers.ProviderError) as e:
            cloud.AnthropicProvider("sk-test-123456", "m", consent=False, url=self.url).generate(self.MSGS)
        self.assertEqual(e.exception.kind, "consent")
        with self.assertRaises(providers.ProviderError) as e:
            cloud.AnthropicProvider(None, "m", consent=True, url=self.url).generate(self.MSGS)
        self.assertEqual(e.exception.kind, "auth")
        self.assertEqual(Stub.seen, [])   # nothing was sent


class OpenAIAndGemini(CloudBase):
    def test_openai(self):
        Stub.body = {"choices": [{"message": {"content": reply()}}], "usage": {"prompt_tokens": 10, "completion_tokens": 5}}
        p = cloud.OpenAIProvider("sk-test-abcdefgh", "gpt-model", consent=True, url=self.url)
        self.assertIn("picks", p.generate(self.MSGS))
        self.assertEqual(Stub.seen[0]["headers"].get("authorization"), "Bearer sk-test-abcdefgh")
        self.assertEqual(p.last_usage, {"input": 10, "output": 5})

    def test_gemini(self):
        Stub.body = {"candidates": [{"content": {"parts": [{"text": reply()}]}}],
                     "usageMetadata": {"promptTokenCount": 7, "candidatesTokenCount": 3}}
        p = cloud.GeminiProvider("gm-test-abcdefgh", "gemini-model", consent=True, url=self.url)
        self.assertIn("picks", p.generate(self.MSGS))
        b = Stub.seen[0]["body"]
        self.assertEqual(b["systemInstruction"]["parts"][0]["text"], "rules")
        self.assertEqual(Stub.seen[0]["headers"].get("x-goog-api-key"), "gm-test-abcdefgh")


class Network(unittest.TestCase):
    class Opener:
        def __init__(self, exc):
            self.exc = exc

        def open(self, *a, **k):
            raise self.exc

    def test_tls_and_offline(self):
        with self.assertRaises(providers.ProviderError) as e:
            providers.post_json(self.Opener(urllib.error.URLError(ssl.SSLError("bad cert"))), "https://x", {}, {}, 5, "x")
        self.assertEqual(e.exception.kind, "tls")
        with self.assertRaises(providers.ProviderError) as e:
            providers.post_json(self.Opener(urllib.error.URLError(OSError("network unreachable"))), "https://x", {}, {}, 5, "x")
        self.assertEqual(e.exception.kind, "connect")


class Budget(unittest.TestCase):
    def test_cap_blocks_and_records(self):
        path = os.path.join(tempfile.mkdtemp(), "usage.json")
        g = budget.SpendGuard(path, daily_tokens=1000, clock=lambda: 1794740000)
        g.record("anthropic", {"input": 700, "output": 100})
        self.assertEqual(g.used_today(), 800)
        with self.assertRaises(providers.ProviderError) as e:
            g.check([{"content": "x" * 30}], max_output_tokens=400)
        self.assertEqual(e.exception.kind, "budget")
        g.check([{"content": "x" * 30}], max_output_tokens=100)

    def test_over_cap_falls_back_without_calling(self):
        path = os.path.join(tempfile.mkdtemp(), "usage.json")
        fake = providers.FakeProvider([reply()])
        fake.name, fake.last_usage = "anthropic", None
        g = budget.Guarded(fake, budget.SpendGuard(path, daily_tokens=10))
        env, binding = context.build(codes.import_code(snapshot_code()))
        advice, report = orchestrator.ask("x", env, binding, g)
        self.assertEqual(report["mode"], "fallback")
        self.assertEqual(report["error"], "budget")
        self.assertEqual(fake.calls, [])
        self.assertTrue(advice["items"])


class Keys(unittest.TestCase):
    def setUp(self):
        keys.use_store(keys._Memory())
        os.environ.pop("OUTRIDER_ANTHROPIC_KEY", None)

    def test_store_and_env(self):
        self.assertIsNone(keys.get("anthropic"))
        keys.set_key("anthropic", "sk-ant-test-12345678")
        self.assertEqual(keys.get("anthropic"), "sk-ant-test-12345678")
        self.assertTrue(keys.status()["anthropic"])
        os.environ["OUTRIDER_ANTHROPIC_KEY"] = "sk-env-override-1"
        self.assertEqual(keys.get("anthropic"), "sk-env-override-1")
        os.environ.pop("OUTRIDER_ANTHROPIC_KEY")
        self.assertTrue(keys.delete("anthropic"))
        for bad in ("short", "has space in it", ""):
            with self.assertRaises(ValueError):
                keys.set_key("anthropic", bad)
        with self.assertRaises(ValueError):
            keys.set_key("someone-else", "sk-ant-test-12345678")

    def test_status_never_shows_keys(self):
        keys.set_key("openai", "sk-secret-value-999")
        out = io.StringIO()
        with redirect_stdout(out):
            keys.main(["status"])
        self.assertNotIn("sk-secret-value-999", out.getvalue())

    @unittest.skipUnless(os.environ.get("OUTRIDER_TEST_CREDMAN") == "1" and sys.platform == "win32",
                         "set OUTRIDER_TEST_CREDMAN=1 to round-trip the real Windows Credential Manager")
    def test_real_credential_manager(self):
        s = keys._WinCred()
        s.write("Outrider/test-only", "sk-roundtrip-123456")
        self.assertEqual(s.read("Outrider/test-only"), "sk-roundtrip-123456")
        self.assertTrue(s.delete("Outrider/test-only"))


class Wiring(unittest.TestCase):
    def setUp(self):
        keys.use_store(keys._Memory())

    def test_from_config_cloud(self):
        keys.set_key("anthropic", "sk-ant-test-12345678")
        p = providers.from_config({"intelligence": {"enabled": True, "provider": "anthropic", "cloudConsent": True}},
                                  usage_path=os.path.join(tempfile.mkdtemp(), "u.json"))
        self.assertIsInstance(p, budget.Guarded)
        self.assertEqual(p.provider.model, cloud.ANTHROPIC_DEFAULT_MODEL)
        self.assertTrue(p.validate_config()["ok"])
        with self.assertRaises(providers.ProviderError):
            providers.from_config({"intelligence": {"enabled": True, "provider": "skynet"}})

    def test_preview_sends_nothing(self):
        path = os.path.join(tempfile.mkdtemp(), "snap.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write(snapshot_code(question="45 minutes?"))
        out = io.StringIO()
        with redirect_stdout(out):
            self.assertEqual(ask.main(["--snapshot", path, "--preview"]), 0)
        text = out.getvalue()
        self.assertIn("nothing was sent", text)
        self.assertIn("45 minutes?", text)
        self.assertNotIn("Khreos", text)

    def test_doctor(self):
        self.assertIn("off", doctor.report({})[0])
        lines = doctor.report({"intelligence": {"enabled": True, "provider": "openai-compatible",
                                                "baseUrl": "http://192.168.1.9:11434", "model": "m"}})
        self.assertTrue(any("ANOTHER MACHINE" in l for l in lines))
        self.assertTrue(any("Settings problem" in l for l in lines))   # allowRemote not set
        lines = doctor.report({"intelligence": {"enabled": True, "provider": "gemini"}},
                              usage_path=os.path.join(tempfile.mkdtemp(), "u.json"), check=True)
        text = "\n".join(lines)
        self.assertIn("MISSING", text)
        self.assertIn("NOT given", text)
        self.assertIn("never calls a cloud API", text)


class Window(unittest.TestCase):
    def make(self, clip, replies=None):
        out = []
        ctl = window.Controller(cfg={}, read_clip=lambda: clip, write_clip=out.append,
                                make_provider=lambda: providers.FakeProvider(replies) if replies is not None else None)
        return ctl, out

    def test_read_preview_ask(self):
        ctl, out = self.make(snapshot_code(question="45 minutes?", timeBudget=45), [reply()])
        info = ctl.read_snapshot()
        self.assertEqual(info["question"], "45 minutes?")
        self.assertEqual(info["budget"], 45)
        self.assertIn("Khreos", info["who"])          # shown locally only
        self.assertNotIn("Khreos", ctl.preview("45 minutes?"))   # never in what a model sees
        text, copied = ctl.ask("45 minutes?", ctl.start())
        self.assertTrue(copied)
        self.assertIn("Paste advice", text)
        self.assertEqual(codes.import_code(out[0])["kind"], "advice")

    def test_stop_drops_a_late_answer(self):
        ctl, out = self.make(snapshot_code(), [reply()])
        ctl.read_snapshot()
        t = ctl.start()
        ctl.stop()
        self.assertIsNone(ctl.ask("x", t))
        self.assertEqual(out, [])

    def test_needs_a_snapshot(self):
        ctl, _ = self.make("garbage")
        with self.assertRaises(Exception):
            ctl.read_snapshot()
        with self.assertRaises(ValueError):
            ctl.ask("x")
        self.assertIn("off", ctl.status())


if __name__ == "__main__":
    unittest.main()
