"""Additive, privacy-preserving Intelligence 2.0 context and reply contracts.

No network, file writes, client introspection or game control. Caller must supply
an already player-copied and OTR1-decoded snapshot. Existing v1/v2 tools remain
unchanged. This module is deliberately independent of any LLM SDK.
"""
import json

from . import context

SCHEMA = 3
MAX_ENVELOPE_BYTES = 50 * 1024
MAX_OPPORTUNITIES = 12
MAX_PICKS = 3
TASK_CATEGORIES = {
    "quest": {"quest", "dungeon", "errand"},
    "economy": {"gold", "gather", "profession", "errand"},
    "gear": {"gear", "dungeon", "quest"},
    "progression": {"quest", "errand", "profession", "dungeon"},
    "general": None,
}


class ContractError(ValueError):
    """A read-only contract is malformed, unsafe, or stale."""


def envelope_v3(code_data, task="general", *, byte_limit=MAX_ENVELOPE_BYTES):
    """Produce model-safe v3 data plus private binding from v1/v2 OTR1 input.

    No actual names, raw module values, coordinates, account metadata, gold,
    unselected categories, or call/command capabilities appear in the envelope.
    Do not truncate required evidence on overflow: fail visibly.
    """
    if task not in TASK_CATEGORIES:
        raise ContractError("unknown context task")
    if not isinstance(byte_limit, int) or isinstance(byte_limit, bool) or not 256 <= byte_limit <= MAX_ENVELOPE_BYTES:
        raise ContractError("invalid envelope limit")
    source, binding = context.build(code_data)
    allowed = TASK_CATEGORIES[task]
    selected = [c for c in source["candidates"]
                if (allowed is None or c["kind"] in allowed)][:MAX_OPPORTUNITIES]
    seen_at = source.get("candidatesSeenAt")
    taken_at = source["takenAt"]
    if isinstance(seen_at, int) and seen_at > taken_at:
        raise ContractError("candidate observation cannot postdate snapshot")
    entries = []
    evidence = []
    for c in selected:
        eid = "local:" + c["candidateId"]
        entries.append({
            "candidateId": c["candidateId"],
            "kind": c["kind"],
            "title": c["title"],
            "why": c["why"],
            "where": c["where"],
            "confidence": c["label"],
            "evidenceIds": [eid],
        })
        evidence.append({
            "evidenceId": eid, "origin": "player-copied-outrider",
            "confidence": c["label"], "observedAt": seen_at or taken_at,
        })
    envelope = {
        "schema": SCHEMA,
        "snapshotId": source.get("snapshotId"),
        "createdAt": taken_at,
        "gameBuild": source.get("gameBuild"),
        "character": {
            "anonId": "character-1",
            "classToken": source["character"]["class"],
            "level": source["character"]["level"],
            "selectedRole": "UNKNOWN",
            "roleSource": "not established by legacy snapshot",
        },
        "task": task,
        "goal": source["goal"],
        "timeBudgetMinutes": source.get("timeBudget"),
        "opportunities": entries,
        "evidence": evidence,
        "transport": "player_clipboard",
        "privacy": {"cloudConsent": False, "playerNamesIncluded": False,
                    "otherPlayersIncluded": False},
    }
    if len(json.dumps(envelope, ensure_ascii=False, separators=(",", ":")).encode("utf-8")) > byte_limit:
        raise ContractError("context too large: select a narrower task; nothing was sent")
    return envelope, binding


def validate_answer_v3(reply, envelope, binding):
    """Validate model-selected IDs without accepting any model action or facts.

    Returns an answer and the corresponding trusted opportunity rows. An
    untrusted model never gets to author coordinates, IDs, or an executable
    command; an addon must rebuild any UI actions from saved source records.
    """
    if not isinstance(envelope, dict) or envelope.get("schema") != SCHEMA:
        raise ContractError("invalid evidence envelope")
    if not isinstance(binding, dict) or not binding.get("forCharacter"):
        raise ContractError("missing private snapshot binding")
    if isinstance(reply, str):
        if len(reply.encode("utf-8")) > 16384:
            raise ContractError("model reply is oversized")
        try:
            reply = json.loads(reply)
        except (ValueError, TypeError) as exc:
            raise ContractError("not a JSON answer") from exc
    if not isinstance(reply, dict) or reply.get("schema") != SCHEMA:
        raise ContractError("wrong response schema")
    if not envelope.get("snapshotId") or reply.get("answersSnapshotId") != envelope["snapshotId"]:
        raise ContractError("stale or mismatched snapshot")
    if reply.get("actionRequests") not in (None, []):
        raise ContractError("model-requested actions are forbidden")
    # Reject unrecognized top-level fields rather than accepting concealed
    # actions or alternate tool-call representations.
    permitted = {
        "schema", "answersSnapshotId", "headline", "summary",
        "rankedCandidateIds", "rationaleEvidenceIds",
        "assumptions", "limitations", "actionRequests",
    }
    if set(reply) - permitted:
        raise ContractError("unexpected model output fields")
    index = {c["candidateId"]: c for c in envelope.get("opportunities", [])}
    evidence = {e["evidenceId"] for e in envelope.get("evidence", [])}
    picks = reply.get("rankedCandidateIds")
    if not isinstance(picks, list) or not 1 <= len(picks) <= MAX_PICKS:
        raise ContractError("invalid number of picks")
    if len(set(x for x in picks if isinstance(x, str))) != len(picks):
        raise ContractError("duplicate or malformed picks")
    if any(not isinstance(x, str) or x not in index for x in picks):
        raise ContractError("unknown candidate IDs")
    sources = reply.get("rationaleEvidenceIds", [])
    if not isinstance(sources, list) or len(sources) > 12 or any(
        not isinstance(x, str) or x not in evidence for x in sources
    ):
        raise ContractError("unknown evidence IDs")
    def clean(value, length):
        if not isinstance(value, str) or len(value) > length:
            raise ContractError("missing or oversized text")
        clean_value = context.clean_text(value, length)
        return clean_value or ""
    def safe_list(value):
        if not isinstance(value, list) or len(value) > 4:
            raise ContractError("invalid limitations or assumptions")
        return [clean(x, 160) for x in value]
    answer = {
        "schema": SCHEMA,
        "answersSnapshotId": envelope["snapshotId"],
        "headline": clean(reply.get("headline", ""), 120),
        "summary": clean(reply.get("summary", ""), 600),
        "rankedCandidateIds": list(picks),
        "rationaleEvidenceIds": list(sources),
        "assumptions": safe_list(reply.get("assumptions", [])),
        "limitations": safe_list(reply.get("limitations", [])),
        "actionRequests": [],
    }
    return answer, [index[x] for x in picks]
