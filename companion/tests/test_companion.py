"""Companion app tests (P9-03 and P9-05 safety). Run: py -I companion/tests/test_companion.py"""
import json
import os
import shutil
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from outrider_companion import advice, luadata, server, store  # noqa: E402

SV = r'''
Outrider_DB = {
	["schema"] = 1,
	["global"] = {
		["sightings"] = {
			[259388] = {
				{ ["t"] = 1731300000, ["state"] = "alive", ["mapID"] = 2521, ["x"] = 0.598, ["y"] = 0.344, ["layer"] = 1, },
			},
		},
		["discovered"] = { ["npcs"] = { [259388] = { ["name"] = "Mystmane", }, }, },
		["respawnObs"] = { [259388] = { 600, 900, 700, }, },
	},
	["chars"] = {
		["Torrant-Mcluvin"] = {
			["meta"] = { ["class"] = "HUNTER", ["level"] = 15, ["faction"] = "Horde", },
			["professions"] = { ["Leatherworking"] = { ["skill"] = 75, ["max"] = 150,
				["recipes"] = { [2149] = { ["name"] = "Boots", }, }, }, },
		},
	},
}
Outrider_Snapshots = {
	["Torrant-Mcluvin"] = {
		["takenAt"] = 1731300500,
		["level"] = 15,
		["gear"] = { [18] = 2504, },
		["quests"] = { { ["id"] = 747, ["title"] = "The Hunt Begins", ["level"] = 3, ["complete"] = false, }, },
		["modules"] = { ["RareScan"] = { ["watch"] = { "mystmane", }, }, ["GearScore"] = { ["role"] = "Ranged (levelling)", }, },
	},
}
-- a comment WoW never writes, still fine
Outrider_Advice = nil
'''


class LuaDataTests(unittest.TestCase):
    def test_parses_what_wow_writes(self):
        d = luadata.parse(SV)
        self.assertEqual(d["Outrider_DB"]["chars"]["Torrant-Mcluvin"]["meta"]["level"], 15)
        self.assertEqual(d["Outrider_DB"]["global"]["respawnObs"][259388], [600, 900, 700])
        self.assertIsNone(d["Outrider_Advice"])
        self.assertEqual(luadata.parse('X = { "a\\"b\\n\\065", -1.5e3, 0x10, [[long]] }')["X"], ['a"b\nA', -1500.0, 16, "long"])

    def test_refuses_code(self):
        for bad in ['X = os.execute("calc")', 'X = { y = print("hi") }', 'X = 1 + 2', 'X = function() end',
                    'X = { [1] = loadstring("x") }', 'X = "unterminated']:
            with self.assertRaises(luadata.LuaDataError, msg=bad):
                luadata.parse(bad)

    def test_written_strings_cannot_break_out(self):
        nasty = 'a"]]--\n\\x\0end) os.execute("calc") --[['
        text = luadata.dumps("Outrider_Advice", {"items": [{"title": nasty}]})
        back = luadata.parse(text)
        self.assertEqual(back["Outrider_Advice"]["items"][0]["title"], nasty)
        self.assertEqual(list(back), ["Outrider_Advice"], "nothing else got defined")


class AdviceTests(unittest.TestCase):
    def test_only_whitelisted_actions_survive(self):
        items = [
            {"title": "Hunt Mystmane", "why": "window open", "action": "waypoint", "confidence": "verified",
             "args": {"mapID": 2521, "x": 0.6, "y": 0.34}},
            {"title": "Cast", "action": "cast", "args": {"spell": "Fireball"}},
            {"title": "Bad waypoint", "action": "waypoint", "args": {"mapID": 2521, "x": 4, "y": 0.3}},
            {"title": "|cffff0000Track|r", "action": "track_quest", "args": {"questID": 747}},
            {"title": "Open", "action": "open_panel", "args": {"panel": "settings"}},
        ]
        data, rejected = advice.build("Torrant-Mcluvin", 1731300500, items)
        self.assertEqual([i["action"] for i in data["items"]], ["waypoint", "track_quest"])
        self.assertEqual(data["items"][1]["title"], "cffff0000Trackr")
        self.assertEqual(len(rejected), 3)
        self.assertEqual(data["answersSnapshot"], 1731300500)

    def test_caps_items_and_needs_a_snapshot(self):
        many = [{"title": "t%d" % i, "action": "show_item", "args": {"itemID": 100 + i}} for i in range(20)]
        data, rejected = advice.build("Torrant-Mcluvin", 1, many)
        self.assertEqual(len(data["items"]), advice.MAX_ITEMS)
        with self.assertRaises(ValueError):
            advice.build("Torrant-Mcluvin", None, many)

    def test_writes_only_advice_lua(self):
        tmp = tempfile.mkdtemp()
        try:
            folder = os.path.join(tmp, "Interface", "AddOns", "Outrider", "Advisor")
            os.makedirs(folder)
            data, _ = advice.build("Torrant-Mcluvin", 5, [{"title": "x", "action": "open_panel", "args": {"panel": "gear"}}])
            advice.write(os.path.join(folder, "Advice.lua"), data)
            with open(os.path.join(folder, "Advice.lua"), encoding="utf-8") as f:
                self.assertEqual(luadata.parse(f.read())["Outrider_Advice"]["items"][0]["args"]["panel"], "gear")
            with self.assertRaises(ValueError):
                advice.write(os.path.join(tmp, "WTF", "Config.wtf"), data)
        finally:
            shutil.rmtree(tmp)


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.sv = os.path.join(self.tmp, "Outrider.lua")
        with open(self.sv, "w", encoding="utf-8") as f:
            f.write(SV)
        folder = os.path.join(self.tmp, "Interface", "AddOns", "Outrider", "Advisor")
        os.makedirs(folder)
        self.advice_file = os.path.join(folder, "Advice.lua")
        self.srv = server.Server({"savedVariablesFile": self.sv, "adviceFile": self.advice_file})

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def rpc(self, method, params=None, mid=1):
        return self.srv.handle({"jsonrpc": "2.0", "id": mid, "method": method, "params": params or {}})

    def tool(self, name, **args):
        r = self.rpc("tools/call", {"name": name, "arguments": args})["result"]
        return r, json.loads(r["content"][0]["text"]) if not r.get("isError") else r["content"][0]["text"]

    def test_handshake_and_tool_list(self):
        self.assertEqual(self.rpc("initialize", {"protocolVersion": "2025-06-18"})["result"]["serverInfo"]["name"], "outrider-companion")
        names = [t["name"] for t in self.rpc("tools/list")["result"]["tools"]]
        self.assertEqual(names, ["list_characters", "get_snapshot", "get_rare_log", "get_gear", "get_professions", "write_advice"])
        self.assertIsNone(self.srv.handle({"jsonrpc": "2.0", "method": "notifications/initialized"}))
        self.assertEqual(self.rpc("nope")["error"]["code"], -32601)

    def test_read_tools(self):
        _, chars = self.tool("list_characters")
        self.assertEqual(chars[0]["character"], "Torrant-Mcluvin")
        self.assertEqual(chars[0]["snapshotTakenAt"], 1731300500)
        _, snap = self.tool("get_snapshot", character="Torrant-Mcluvin")
        self.assertEqual(snap["quests"][0]["id"], 747)
        _, rares = self.tool("get_rare_log", character="Torrant-Mcluvin")
        self.assertEqual(rares["rares"][0]["name"], "Mystmane")
        self.assertEqual(rares["watchlist"], ["mystmane"])
        _, profs = self.tool("get_professions", character="Torrant-Mcluvin")
        self.assertEqual(profs["professions"]["Leatherworking"]["recipes"], ["Boots"])
        r, msg = self.tool("get_snapshot", character="Nobody-Realm")
        self.assertTrue(r["isError"])

    def test_write_advice_round_trip(self):
        _, res = self.tool("write_advice", character="Torrant-Mcluvin", items=[
            {"title": "Hunt Mystmane", "why": "window open", "action": "waypoint", "args": {"mapID": 2521, "x": 0.6, "y": 0.34}},
            {"title": "nope", "action": "buy", "args": {}}])
        self.assertEqual(res["written"], 1)
        with open(self.advice_file, encoding="utf-8") as f:
            a = luadata.parse(f.read())["Outrider_Advice"]
        self.assertEqual(a["forCharacter"], "Torrant-Mcluvin")
        self.assertEqual(a["answersSnapshot"], 1731300500)


class ConfigTests(unittest.TestCase):
    def test_never_runs_unconfigured(self):
        tmp = tempfile.mkdtemp()
        try:
            with self.assertRaises(store.NotConfigured):
                store.load_config(os.path.join(tmp, "missing.json"))
            p = os.path.join(tmp, "config.json")
            with open(p, "w") as f:
                json.dump({"enabled": False}, f)
            with self.assertRaises(store.NotConfigured):
                store.load_config(p)
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
