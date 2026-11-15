"""Minimal MCP server over stdio (P9-03), standard library only.

Read-only tools: list_characters, get_snapshot, get_rare_log, get_gear,
get_professions. One write tool: write_advice, which validates against the
same whitelist as the game and writes only Interface/AddOns/Outrider/
Advisor/Advice.lua. No network: the server only talks over stdin/stdout to
the MCP client that started it.

Run:  py -I companion/run.py     (from an MCP client config; see README.md)
"""

import json
import sys

from . import advice, clipboard, codes, store
from .intelligence import context as ictx, orchestrator, providers

PROTOCOL = "2025-06-18"
CHAR = {"type": "object", "properties": {"character": {"type": "string", "description": "Character key exactly as list_characters returns it (Name-Realm)"}},
        "required": ["character"]}
TOOLS = [
    {"name": "list_characters", "description": "Characters Outrider knows, with class, level and when their last snapshot was taken.",
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "get_snapshot", "description": "The character's latest snapshot (/ride ask): level, zone, money, gear, quest log, module data.",
     "inputSchema": CHAR},
    {"name": "get_rare_log", "description": "Rare sightings (account-wide) and the character's rare watchlist.", "inputSchema": CHAR},
    {"name": "get_gear", "description": "Worn item IDs, stat weights and the best nearby upgrade candidates.", "inputSchema": CHAR},
    {"name": "get_professions", "description": "Profession skills, known recipe names and the craft queue.", "inputSchema": CHAR},
    {"name": "write_advice",
     "description": ("Write 3 to 8 suggestions for the character's Advisor tab. Allowed actions only: "
                     "waypoint {mapID, x, y in 0..1}, track_quest {questID}, open_panel {panel: hub|rares|pet|macros|gear|professions|map}, "
                     "show_item {itemID}. Each item: title, why, action, args, confidence (verified|community|inferred|unknown). "
                     "Use only IDs found in the snapshot. Gary sees it after /reload."),
     "inputSchema": {"type": "object", "properties": {
         "character": {"type": "string"},
         "items": {"type": "array", "items": {"type": "object"}}}, "required": ["character", "items"]}},
    {"name": "read_clipboard_snapshot",
     "description": ("No-reload route: Gary typed /ride ask in game and pressed Ctrl+C on the code. Reads that "
                     "snapshot code from the Windows clipboard and returns {character, snapshot}."),
     "inputSchema": {"type": "object", "properties": {}}},
    {"name": "advice_to_clipboard",
     "description": ("No-reload route: same items as write_advice, answering the clipboard snapshot. Puts an advice "
                     "code on the Windows clipboard; Gary clicks Paste advice in the Advisor tab and presses Ctrl+V."),
     "inputSchema": {"type": "object", "properties": {
         "character": {"type": "string"}, "answersSnapshot": {"type": "number"},
         "items": {"type": "array", "items": {"type": "object"}}}, "required": ["character", "answersSnapshot", "items"]}},
    # Outrider Intelligence (AI03/AI04-03): read-only views of What now?'s steps,
    # and a validated way for this MCP client to answer as the model.
    {"name": "get_pathfinder_candidates",
     "description": ("What now?'s ranked next steps from the character's last /ride ask (or the clipboard snapshot "
                     "when character is omitted): candidateId, kind, title, why, where, trip minutes, evidence label "
                     "(observed|community|inferred|unknown), the player's question, time budget and feedback. "
                     "Character names are left out."),
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}}}},
    {"name": "get_candidate_explanation",
     "description": "Everything Outrider recorded for one step: why, where, caveat, label, minutes, target or panel.",
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}, "candidateId": {"type": "string"}},
                     "required": ["candidateId"]}},
    {"name": "get_gear_opportunities",
     "description": "Upgrade candidates near and anywhere (item, % better for this class, source and where) and the class stat weights. From the last /ride ask, or the clipboard snapshot when character is omitted.",
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}}}},
    {"name": "get_dungeon_opportunities",
     "description": "Dungeons that fit the character's level now and coming up, with upgrades per dungeon (item, %, boss) and entrance. Level ranges and loot are unverified for Forever.",
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}}}},
    {"name": "get_gold_options",
     "description": "Gold methods ranked for the character (copper per hour, measured or from guides), crafting profit after the AH cut, and the session ledger.",
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}}}},
    {"name": "get_rare_evidence",
     "description": "Rare sightings with time, layer and place, the watch list and respawn windows. Sparse data: never turn a few sightings into a precise timer.",
     "inputSchema": {"type": "object", "properties": {"character": {"type": "string"}}}},
    {"name": "plan_to_clipboard",
     "description": ("Answer the clipboard snapshot as the planner model: pick up to 3 candidateIds (from "
                     "get_pathfinder_candidates) in order, with a short why each, a headline, a summary, optional "
                     "compare [idA, idB] and limits. Outrider validates it, adds the plan and times, rebuilds every "
                     "card from its own data and puts an advice code on the clipboard; Gary clicks Paste advice."),
     "inputSchema": {"type": "object", "properties": {
         "headline": {"type": "string"}, "summary": {"type": "string"},
         "picks": {"type": "array", "items": {"type": "object"}},
         "compare": {"type": "array", "items": {"type": "string"}},
         "limits": {"type": "array", "items": {"type": "string"}}}, "required": ["picks"]}},
]


class Server:
    def __init__(self, cfg):
        self.cfg = cfg
        self.store = store.Store(cfg["savedVariablesFile"])

    def call(self, name, args):
        char = args.get("character")
        if name == "list_characters":
            return self.store.characters()
        if name == "get_snapshot":
            return self.store.snapshot(char)
        if name == "get_rare_log":
            return self.store.rare_log(char)
        if name == "get_gear":
            return self.store.gear(char)
        if name == "get_professions":
            return self.store.professions(char)
        if name == "write_advice":
            snap = self.store.snapshot(char)
            # advice answers the last /ride ask (askedAt survives the logout snapshot)
            data, rejected = advice.build(char, snap.get("askedAt") or snap.get("takenAt"), args.get("items"))
            if not data["items"]:
                raise ValueError("no valid items: %s" % json.dumps(rejected))
            size = advice.write(self.cfg["adviceFile"], data)
            return {"written": len(data["items"]), "rejected": rejected, "bytes": size,
                    "next": "Gary types /reload in game to see the Advisor tab"}
        if name == "read_clipboard_snapshot":
            data = codes.import_code(self.read_clipboard())
            if not isinstance(data, dict) or data.get("kind") != "snapshot":
                raise ValueError("the clipboard does not hold an Outrider snapshot code (type /ride ask, then Ctrl+C)")
            return {"character": data.get("character"), "snapshot": data.get("snapshot")}
        if name == "advice_to_clipboard":
            data, rejected = advice.build(char, args.get("answersSnapshot"), args.get("items"))
            if not data["items"]:
                raise ValueError("no valid items: %s" % json.dumps(rejected))
            data["kind"] = "advice"
            code = codes.export(data)
            self.write_clipboard(code)
            return {"written": len(data["items"]), "rejected": rejected, "characters": len(code),
                    "next": "Gary clicks Paste advice in the Advisor tab and presses Ctrl+V"}
        if name in ("get_pathfinder_candidates", "get_candidate_explanation"):
            env, _ = self.envelope(char)
            if name == "get_pathfinder_candidates":
                view = ictx.model_view(env)
                view["question"], view["snapshotId"] = env.get("question"), env.get("snapshotId")
                return view
            cid = args.get("candidateId")
            for c in env["candidates"]:
                if c["candidateId"] == cid:
                    return c
            raise ValueError("no step %r in that snapshot" % cid)
        if name in ("get_gear_opportunities", "get_dungeon_opportunities", "get_gold_options", "get_rare_evidence"):
            snap = self.raw_snapshot(char)
            if name == "get_gear_opportunities":
                return {"nearby": ictx.module(snap, "Nearby"), "weights": ictx.module(snap, "GearScore")}
            if name == "get_dungeon_opportunities":
                d = ictx.module(snap, "DungeonGuide")
                return d if d is not None else {"note": "no dungeon data in this snapshot (pack missing, or snapshot from before this version: Ask again)"}
            if name == "get_gold_options":
                return {"guide": ictx.module(snap, "MoneyGuide"), "ledger": ictx.module(snap, "Ledger")}
            out = {"sightings": ictx.module(snap, "Sightings"), "watch": ictx.module(snap, "RareScan"),
                   "note": "Few sightings make wide windows; say how sure you are."}
            if char:
                try:
                    out["log"] = ictx.clean_tree(self.store.rare_log(char))
                except Exception:   # the saved log is optional
                    pass
            return out
        if name == "plan_to_clipboard":
            env, binding = self.envelope(None)
            reply = {k: args.get(k) for k in ("headline", "summary", "picks", "compare", "limits")}
            data, report = orchestrator.ask(None, env, binding, providers.FakeProvider([json.dumps(reply)]))
            if report.get("mode") != "model":
                raise ValueError("no usable picks (use candidateIds from get_pathfinder_candidates): %s"
                                 % "; ".join(report.get("problems") or [report.get("error") or "?"]))
            code = codes.export(data)
            self.write_clipboard(code)
            return {"cards": len(data["items"]), "plan": data["answer"].get("plan"),
                    "compare": data["answer"].get("compare"), "dropped": report.get("problems"),
                    "next": "Gary clicks Paste advice in the Advisor tab and presses Ctrl+V"}
        raise KeyError("unknown tool %s" % name)

    def raw_snapshot(self, char):
        if char:
            return self.store.snapshot(char)
        data = codes.import_code(self.read_clipboard())
        if not isinstance(data, dict) or data.get("kind") != "snapshot" or not isinstance(data.get("snapshot"), dict):
            raise ValueError("the clipboard does not hold an Outrider snapshot code (Advisor > Ask, then Ctrl+C)")
        return data["snapshot"]

    def envelope(self, char):
        """(envelope, binding) from the clipboard snapshot, or the character's saved one."""
        if char:
            snap = self.store.snapshot(char)
            return ictx.build({"kind": "snapshot", "character": char, "snapshot": snap})
        return ictx.build(codes.import_code(self.read_clipboard()))

    # overridable in tests
    def read_clipboard(self):
        return clipboard.read()

    def write_clipboard(self, text):
        return clipboard.write(text)

    def handle(self, msg):
        """One JSON-RPC message in, a response dict (or None for notifications) out."""
        mid, method = msg.get("id"), msg.get("method")
        if mid is None:
            return None
        try:
            if method == "initialize":
                want = (msg.get("params") or {}).get("protocolVersion")
                result = {"protocolVersion": want or PROTOCOL, "capabilities": {"tools": {}},
                          "serverInfo": {"name": "outrider-companion", "version": "0.1.0"}}
            elif method == "ping":
                result = {}
            elif method == "tools/list":
                result = {"tools": TOOLS}
            elif method == "tools/call":
                p = msg.get("params") or {}
                try:
                    data = self.call(p.get("name"), p.get("arguments") or {})
                    result = {"content": [{"type": "text", "text": json.dumps(data, default=str)}]}
                except Exception as e:  # tool errors go back to the model, not as protocol errors
                    result = {"content": [{"type": "text", "text": str(e)}], "isError": True}
            else:
                return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": "method not found"}}
            return {"jsonrpc": "2.0", "id": mid, "result": result}
        except Exception as e:
            return {"jsonrpc": "2.0", "id": mid, "error": {"code": -32603, "message": str(e)}}


def main():
    try:
        cfg = store.load_config()
    except store.NotConfigured as e:
        sys.stderr.write("Outrider companion is not configured: %s\n" % e)
        return 2
    server = Server(cfg)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        reply = server.handle(msg)
        if reply is not None:
            sys.stdout.write(json.dumps(reply) + "\n")
            sys.stdout.flush()
    return 0
