"""Vanguard desktop commands (VG07). Run from the companion folder:

  py -I -m outrider_companion.vanguard.cli export   --savedvariables PATH --character Name-Realm [--profile] [--guild] [--out FILE]
  py -I -m outrider_companion.vanguard.cli import   --file FILE [--vault PATH]
  py -I -m outrider_companion.vanguard.cli vault    [--vault PATH]
  py -I -m outrider_companion.vanguard.cli backup   [--vault PATH]
  py -I -m outrider_companion.vanguard.cli restore  --backup FILE [--vault PATH]
  py -I -m outrider_companion.vanguard.cli scenario --group GROUP.json [--instance NAME] (--exporter ID | --everyone) [--vault PATH]
  py -I -m outrider_companion.vanguard.cli forecast --target full_clear [--cohort NAME] (--exporter ID | --everyone) [--out FILE]
  py -I -m outrider_companion.vanguard.cli guild    [--objectives FILE] [--out report.md] [--vault PATH]

export shows a preview and writes nothing unless --out is given, and only
with the game closed. Everything is local: no network, nothing written
inside the game folder, and the addon works the same without any of this.
"""
import argparse
import json
import sys

from . import contract, vault, scenario, forecast, guild


def _game_closed():
    from ..intelligence import next_session_delivery
    return next_session_delivery.game_closed()


def do_export(args, check_game=_game_closed):
    db, sha = contract.read_saved(args.savedvariables)
    env, dropped = contract.build_export(db, sha, args.character, profile=args.profile, guild=args.guild)
    print(contract.preview(env))
    if dropped:
        print("  dropped: " + ", ".join("%s x%d" % kv for kv in sorted(dropped.items())))
    if not args.out:
        print("Nothing written. Add --out FILE to save it.")
        return 0
    if not check_game():
        raise contract.ContractError("close the game first (export happens after the game closes)")
    print("wrote %s" % contract.write_export(env, args.out))
    return 0


def _runs(v, args, **kw):
    return v.runs(exporter=getattr(args, "exporter", None), everyone=getattr(args, "everyone", False), **kw)


def main(argv=None, check_game=_game_closed):
    ap = argparse.ArgumentParser(prog="vanguard", description="Outrider Vanguard desktop tools (local only)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("--savedvariables", required=True)
    e.add_argument("--character", required=True)
    e.add_argument("--profile", action="store_true", help="include your class and level")
    e.add_argument("--guild", action="store_true", help="allow these runs in a guild report")
    e.add_argument("--out")
    for name in ("import", "vault", "backup", "restore", "scenario", "forecast", "guild"):
        p = sub.add_parser(name)
        p.add_argument("--vault", default=None)
        if name == "import":
            p.add_argument("--file", required=True)
        if name == "restore":
            p.add_argument("--backup", required=True)
        if name in ("scenario", "forecast"):
            who = p.add_mutually_exclusive_group()
            who.add_argument("--exporter")
            who.add_argument("--everyone", action="store_true")
        if name == "scenario":
            p.add_argument("--group", required=True)
            p.add_argument("--instance")
        if name == "forecast":
            p.add_argument("--target", required=True, choices=forecast.TARGETS)
            p.add_argument("--cohort")
            p.add_argument("--out")
        if name == "guild":
            p.add_argument("--objectives")
            p.add_argument("--out")
    args = ap.parse_args(argv)
    try:
        if args.cmd == "export":
            return do_export(args, check_game)
        if args.cmd == "restore":
            print(json.dumps(vault.restore(args.vault or vault.default_path(), args.backup), indent=2))
            return 0
        v = vault.Vault(args.vault)
        try:
            if args.cmd == "import":
                print(json.dumps(v.import_file(args.file), indent=2, sort_keys=True))
            elif args.cmd == "vault":
                print(json.dumps(v.status(), indent=2, sort_keys=True))
            elif args.cmd == "backup":
                print("backup: %s" % v.backup())
            elif args.cmd == "scenario":
                with open(args.group, encoding="utf-8") as f:
                    group = json.load(f)
                past = _runs(v, args) if (args.exporter or args.everyone) else None
                print(scenario.text(scenario.analyse(group, args.instance, past)))
            elif args.cmd == "forecast":
                card = forecast.run(_runs(v, args), args.target, args.cohort, approval=forecast.plan_approval())
                if args.out:
                    print("wrote %s" % forecast.write_card(card, args.out))
                print(json.dumps({k: card[k] for k in ("target", "cohort", "rows", "eligible", "reasons")}, indent=2))
            elif args.cmd == "guild":
                objs = guild.read_objectives(args.objectives) if args.objectives else []
                rep = guild.report(v.runs(everyone=True, guild_only=True), objs)
                if args.out:
                    print("wrote %s" % guild.write(rep, args.out))
                else:
                    print(guild.markdown(rep))
        finally:
            v.close()
    except (contract.ContractError, vault.VaultError, scenario.ScenarioError, forecast.ForecastError,
            guild.GuildError, OSError, ValueError) as exc:
        print("Vanguard: %s" % exc, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
