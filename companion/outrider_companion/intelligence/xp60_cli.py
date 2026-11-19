"""Manual one-shot or opt-in polling XP60 companion (no live game bridge).

Usage:
 python -m outrider_companion.intelligence.xp60_cli --savedvariables PATH --character Name-Realm
 python -m outrider_companion.intelligence.xp60_cli ... --install --addon-dir PATH

The CLI always reads SavedVariables only. Installing Advice.lua requires
positive verification that WoW has exited; the first execution previews.
"""
import argparse
import json
import sys
import time

from . import next_session_delivery as delivery
from . import session_reader


def one(saved, character, addon, install=False):
    result = session_reader.read_sessions(saved, character=character)
    plan = delivery.create_plan(result, character)
    delivery.validate_payload(plan)
    if install:
        if not addon:
            raise delivery.DeliveryError("--addon-dir is required for --install")
        delivery.write_after_exit(plan, addon)
    return plan


def main(argv=None):
    parser = argparse.ArgumentParser(description="XP60: post-logout, read-only 60-minute XP planning")
    parser.add_argument("--savedvariables", required=True)
    parser.add_argument("--character", required=True)
    parser.add_argument("--addon-dir")
    parser.add_argument("--install", action="store_true",
                        help="write data-only advice after verifying WoW is fully closed")
    parser.add_argument("--watch", action="store_true",
                        help="monitor bounded file changes; no gameplay interaction")
    parser.add_argument("--interval", type=float, default=5.0)
    args = parser.parse_args(argv)
    if args.watch and not 2 <= args.interval <= 300:
        parser.error("--interval must be between 2 and 300 seconds")
    last = None
    try:
        while True:
            result = session_reader.read_sessions(args.savedvariables, character=args.character)
            digest = result["sourceDigest"]
            if digest != last:
                plan = delivery.create_plan(result, args.character)
                delivery.validate_payload(plan)
                if args.install:
                    if not args.addon_dir:
                        raise delivery.DeliveryError("--addon-dir is required for --install")
                    delivery.write_after_exit(plan, args.addon_dir)
                print(json.dumps({"status": plan["status"], "headline": plan["headline"],
                                  "basedOnSessionId": plan["basedOnSessionId"],
                                  "budgetSeconds": plan["budgetSeconds"],
                                  "baselineXPPerHour": plan["baselineXPPerHour"],
                                  "installed": args.install}, indent=2))
                last = digest
            if not args.watch:
                return 0
            time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0
    except (delivery.DeliveryError, session_reader.SessionReadError, ValueError, OSError) as exc:
        print("XP60: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
