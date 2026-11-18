"""Ask Outrider from the command line (AI02-04). The MCP server is unchanged.

    python -m outrider_companion.intelligence.ask "I have 45 minutes, what should I do?"

1. In game: Advisor tab > Ask (copy snapshot), press Ctrl+C.
2. Run this: it reads the snapshot code from the clipboard, asks the model set
   in companion/config.json ("intelligence" section), validates the answer and
   puts an advice code back on the clipboard.
3. In game: Advisor tab > Paste advice. No reload.

Options: --snapshot FILE (read the code from a file), --out FILE (write the
advice code there instead of the clipboard), --no-model (Outrider's own picks,
no model call), --config FILE.
"""

import argparse
import json
import os
import sys

from .. import clipboard, codes
from . import context, orchestrator, providers, coach_v3, schemas_v3

HERE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_config(path=None):
    path = path or os.path.join(HERE, "config.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def run(snapshot_code, question, provider):
    data = codes.import_code(snapshot_code)
    env, binding = context.build(data)
    advice, report = orchestrator.ask(question, env, binding, provider)
    return codes.export(advice), advice, report


def main(argv=None):
    ap = argparse.ArgumentParser(description="Ask Outrider (local model, validated answer)")
    ap.add_argument("question", nargs="?", default=None,
                    help="optional: the question typed in the Advisor tab is used when this is left out")
    ap.add_argument("--snapshot")
    ap.add_argument("--out")
    ap.add_argument("--no-model", action="store_true")
    ap.add_argument("--config")
    ap.add_argument("--v3", action="store_true",
                    help="use source-bound Intelligence 2.0 advice v3 (opt-in)")
    ap.add_argument("--task", choices=tuple(schemas_v3.TASK_CATEGORIES), default="general",
                    help="select the evidence category for v3 questions")
    ap.add_argument("--preview", action="store_true",
                    help="print exactly what would be sent to the model, send nothing")
    a = ap.parse_args(argv)
    if a.preview:
        try:
            code = open(a.snapshot, encoding="utf-8").read() if a.snapshot else clipboard.read()
            env, _ = context.build(codes.import_code(code))
        except (codes.CodeError, context.ContextError, OSError) as e:
            print("Nothing to preview: %s" % e, file=sys.stderr)
            return 1
        msgs = orchestrator._messages(a.question or env.get("question") or "What should I do next?", env)
        if a.v3:
            v3, _ = schemas_v3.envelope_v3(codes.import_code(code), task=a.task)
            msgs = [{"role": "system", "content": coach_v3.SYSTEM},
                    {"role": "user", "content": json.dumps(v3, ensure_ascii=False)}]
        print("This is everything the model would receive (nothing was sent):")
        print()
        for m in msgs:
            print("--- %s ---" % m["role"])
            print(m["content"])
        return 0
    try:
        provider = None if a.no_model else providers.from_config(load_config(a.config))
        if provider:
            provider.validate_config()
        if a.snapshot:
            with open(a.snapshot, encoding="utf-8") as f:
                code = f.read()
        else:
            code = clipboard.read()
        out, advice, report = coach_v3.run(code, a.question, provider, task=a.task) if a.v3 else run(code, a.question, provider)
    except (codes.CodeError, context.ContextError, schemas_v3.ContractError, providers.ProviderError, OSError, ValueError) as e:
        print("Not answered: %s" % e, file=sys.stderr)
        return 1
    if a.out:
        with open(a.out, "w", encoding="utf-8") as f:
            f.write(out)
    else:
        clipboard.write(out)
    ans = advice if a.v3 else advice["answer"]
    print(ans.get("headline") or "")
    if a.v3:
        for i, cid in enumerate(advice["rankedCandidateIds"], 1):
            print("  %d. %s" % (i, cid))
        for note in advice["limitations"]:
            print("  note: %s" % note)
        print("[v3 %s] paste code in Advisor (manual copy, no live sync)" % report["mode"])
        return 0
    if ans.get("plan"):
        print("Plan: about %d minutes%s" % (ans.get("planMinutes", 0),
                                           (" of %d" % ans["budget"]) if ans.get("budget") else ""))
    for r in ans.get("compare") or []:
        print("  compare: %s (~%d min, %s%s)" % (r["title"], r["minutes"], r["label"], ", needs a group" if r["group"] else ""))
    if ans.get("summary"):
        print(ans["summary"])
    for i, it in enumerate(advice["items"], 1):
        print("  %d. %s (%s)" % (i, it["title"], it["action"]))
    for l in ans.get("limits") or []:
        print("  note: %s" % l)
    print("[%s%s] %s" % (report.get("mode"), (", " + report["error"]) if report.get("error") else "",
                         "advice code in %s" % a.out if a.out else "advice code copied: paste it in the Advisor tab"))
    for p in report.get("problems") or []:
        print("  dropped: %s" % p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
