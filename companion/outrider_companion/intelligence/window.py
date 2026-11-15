"""Ask Outrider window (transport B, docs/intelligence/TRANSPORT_FEASIBILITY.md).

    python -m outrider_companion.intelligence.window      (or pythonw for no console)

A small desktop window instead of the command line. It never touches the
game: in game you click Ask and press Ctrl+C; here you click "Read snapshot",
then "Ask"; the answer goes to the clipboard; in game you click Paste advice
and press Ctrl+V. "Preview" shows exactly what a model would receive.
"Stop waiting" lets go of a slow model (its late answer is ignored).

Controller holds the logic (tested without a screen); App is the Tk window.
"""

import threading

from .. import clipboard, codes
from . import context, doctor, orchestrator, providers
from .ask import load_config


class Controller:
    def __init__(self, cfg=None, read_clip=None, write_clip=None, make_provider=None):
        self.cfg = load_config() if cfg is None else cfg
        self.read_clip = read_clip or clipboard.read
        self.write_clip = write_clip or clipboard.write
        self.make_provider = make_provider or (lambda: providers.from_config(self.cfg))
        self.env = self.binding = None
        self.ticket = 0   # bumps on each ask; a stale result is dropped

    def read_snapshot(self):
        env, binding = context.build(codes.import_code(self.read_clip()))
        self.env, self.binding = env, binding
        c = env["character"]
        who = "%s, level %s %s" % (binding["forCharacter"].split("-")[0], c.get("level") or "?", (c.get("class") or "").lower())
        return {"who": who, "question": env.get("question") or "", "steps": len(env["candidates"]),
                "budget": env.get("timeBudget")}

    def preview(self, question):
        if not self.env:
            raise ValueError("read a snapshot first")
        return "\n\n".join("--- %s ---\n%s" % (m["role"], m["content"])
                           for m in orchestrator._messages(question or "What should I do next?", self.env))

    def status(self):
        return "\n".join(doctor.report(self.cfg))

    def start(self):
        self.ticket += 1
        return self.ticket

    def stop(self):
        self.ticket += 1   # whatever is running now gets ignored

    def ask(self, question, ticket=None):
        """(text for the window, copied?) or None if this ask was stopped."""
        if not self.env:
            raise ValueError("read a snapshot first")
        provider = self.make_provider()
        advice, report = orchestrator.ask(question or None, self.env, self.binding, provider)
        if ticket is not None and ticket != self.ticket:
            return None
        self.write_clip(codes.export(advice))
        a = advice["answer"]
        lines = [a.get("headline") or "", a.get("summary") or ""]
        if a.get("plan"):
            lines.append("Plan: about %d min%s" % (a.get("planMinutes", 0), (" of %d" % a["budget"]) if a.get("budget") else ""))
        for r in a.get("compare") or []:
            lines.append("Compare: %s (~%d min, %s%s)" % (r["title"], r["minutes"], r["label"], ", needs a group" if r["group"] else ""))
        for i, it in enumerate(advice["items"], 1):
            lines.append("%d. %s" % (i, it["title"]))
        for l in a.get("limits") or []:
            lines.append("Not checked: " + l)
        mode = report.get("mode")
        lines.append("")
        lines.append("Answer copied: in game click Paste advice and press Ctrl+V. (%s%s)" % (
            mode, (", " + report["error"]) if report.get("error") else ""))
        return "\n".join(l for l in lines if l is not None), True


class App:   # pragma: no cover - needs a screen; the logic is in Controller
    def __init__(self, ctl):
        import tkinter as tk
        from tkinter import scrolledtext
        self.ctl, self.tk = ctl, tk
        root = self.root = tk.Tk()
        root.title("Ask Outrider")
        root.geometry("620x520")
        root.configure(bg="#0f1116")
        style = {"bg": "#0f1116", "fg": "#e8eaef"}
        self.who = tk.Label(root, text="Click Read snapshot after Ask + Ctrl+C in game.", anchor="w", **style)
        self.who.pack(fill="x", padx=10, pady=(10, 4))
        self.q = tk.Entry(root, bg="#161a22", fg="#e8eaef", insertbackground="#e8eaef")
        self.q.pack(fill="x", padx=10, pady=4)
        bar = tk.Frame(root, bg="#0f1116")
        bar.pack(fill="x", padx=10, pady=4)
        for label, fn in (("Read snapshot", self.read), ("Ask", self.ask), ("Stop waiting", self.stop),
                          ("Preview", self.preview), ("Status", self.status)):
            tk.Button(bar, text=label, command=fn, bg="#d4a84a" if label == "Ask" else "#161a22",
                      fg="#1c1405" if label == "Ask" else "#e8eaef").pack(side="left", padx=(0, 6))
        self.out = scrolledtext.ScrolledText(root, wrap="word", bg="#161a22", fg="#c3c8d2")
        self.out.pack(fill="both", expand=True, padx=10, pady=(4, 10))
        root.bind("<Return>", lambda e: self.ask())
        root.bind("<Escape>", lambda e: root.destroy())

    def show(self, text):
        self.out.delete("1.0", "end")
        self.out.insert("1.0", text)

    def read(self):
        try:
            info = self.ctl.read_snapshot()
        except Exception as e:
            self.show("Couldn't read a snapshot: %s" % e)
            return
        self.who.config(text="%s - %d steps%s" % (info["who"], info["steps"],
                                                 (", %d minutes" % info["budget"]) if info["budget"] else ""))
        self.q.delete(0, "end")
        self.q.insert(0, info["question"])
        self.show("Snapshot read. Type or edit the question, then Ask.")

    def ask(self):
        ticket = self.ctl.start()
        question = self.q.get()
        self.show("Asking...")

        def work():
            try:
                res = self.ctl.ask(question, ticket)
                text = res[0] if res else None
            except Exception as e:
                text = "Not answered: %s" % e
            if text is not None:
                self.root.after(0, lambda: self.show(text))
        threading.Thread(target=work, daemon=True).start()

    def stop(self):
        self.ctl.stop()
        self.show("Stopped waiting. A late answer will be ignored.")

    def preview(self):
        try:
            self.show("Everything a model would receive (nothing sent):\n\n" + self.ctl.preview(self.q.get()))
        except Exception as e:
            self.show(str(e))

    def status(self):
        self.show(self.ctl.status())

    def run(self):
        self.root.mainloop()


def main():   # pragma: no cover
    App(Controller()).run()


if __name__ == "__main__":
    main()
