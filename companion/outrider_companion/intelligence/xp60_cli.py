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
    parser.add_argument("--character", help="optional; defaults to most recent completed character")
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
    last_error = None
    try:
        while True:
            try:
                result = session_reader.read_sessions(args.savedvariables, character=args.character)
                digest = result["sourceDigest"]
                if digest != last:
                    choice = session_reader.newest_completed(result, character=args.character)
                    if not choice:
                        raise delivery.DeliveryError("no finished session yet")
                    character = args.character or choice[0]
                    plan = delivery.create_plan(result, character)
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
            except (delivery.DeliveryError, session_reader.SessionReadError, ValueError, OSError) as exc:
                if not args.watch:
                    raise
                # Keep the previous digest pending. A running game or an
                # incomplete write must be retried, not permanently discarded.
                message = str(exc)
                if message != last_error:
                    print("XP60 waiting: %s" % message, file=sys.stderr)
                    last_error = message
            else:
                last_error = None
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
