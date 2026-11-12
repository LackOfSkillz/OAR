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

from . import advice, store

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
        raise KeyError("unknown tool %s" % name)

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
