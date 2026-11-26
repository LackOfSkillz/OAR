"""VG07-05: the offline forecast pipeline from docs/vanguard/VG05-07_FORECAST_PLAN.md.

Implements only the pre-registered workflow, and only once the plan is
approved in companion/policy.json:
  {"vanguardForecast": {"planApprovedBy": "<reviewer>", "planApprovedAt": "<date>"}}
Without that it builds the datasets and reports their sizes and hashes, and
fits nothing.

  * targets: first_attempt_kill, eventual_kill, full_clear (separate, never multiplied);
  * labels exclude unknown attempts and censored runs (counted, reported);
  * aggregate features only (roles, classes, levels, readiness at run start);
  * cohort = target and place; floors: 200 training runs, 50 held-out runs
    with at least 10 of each outcome; one outcome above 95%, a mix of game
    builds or of catalog versions: abstain;
  * chronological split by run (all rows of a run on one side);
  * models: prevalence baseline, a role-and-level logistic model, a
    regularized logistic model on all features; the simplest that passes wins;
  * metrics: Brier with a bootstrap interval against the baseline, reliability
    bins with counts, calibration slope and intercept with intervals, AUC
    (reported, not used to pass), coverage;
  * pass rule (our reading of "no worse than the baseline"): the upper end of
    the 95% bootstrap interval of (model Brier - baseline Brier) is at or below 0;
  * synthetic records never count (a card built with them is never eligible);
  * the card is never approved here: an independent reviewer approves an
    exact model version and data hashes by hand (Forecast.Eligible in the
    addon needs approved = true and approvedBy). Nothing is written into the addon.
"""
import hashlib
import json
import math
import random
from pathlib import Path

from . import contract

TARGETS = ("first_attempt_kill", "eventual_kill", "full_clear")
MIN_TRAIN, MIN_HOLDOUT, MIN_EACH, MAX_SHARE = 200, 50, 10, 0.95
CLASSES = contract.CLASSES
POLICY = Path(__file__).resolve().parents[2] / "policy.json"
MODEL_VERSION = "vg-forecast-0.1"


class ForecastError(ValueError):
    pass


def plan_approval(path=POLICY):
    try:
        with open(path, encoding="utf-8") as f:
            p = json.load(f).get("vanguardForecast") or {}
    except (OSError, ValueError, AttributeError):
        return None
    if isinstance(p.get("planApprovedBy"), str) and p["planApprovedBy"].strip() and p.get("planApprovedAt"):
        return {"by": p["planApprovedBy"], "at": p["planApprovedAt"]}
    return None


# ------------------------------------------------------------ datasets
def features(run):
    f = run.get("features") or {}
    a = run.get("assessment") or {}
    x = {k: float(f.get(k) or 0) for k in ("members", "tank", "healer", "damage", "unknownRole")}
    x["levelMin"] = float(f.get("levelMin") or 0)
    x["levelMax"] = float(f.get("levelMax") or 0)
    cls = f.get("classes") or {}
    for c in CLASSES:
        x["class_" + c] = float(cls.get(c) or 0)
    has = 1.0 if "low" in a and "high" in a else 0.0
    x["readiness_known"] = has
    x["readiness_mid"] = (float(a["low"]) + float(a["high"])) / 2 if has else 0.0
    x["readiness_coverage"] = float(a.get("coverage") or 0)
    return x


def labelled(runs, target):
    """[(run_key, startedAt, cohort, features, label)], plus exclusion counts."""
    if target not in TARGETS:
        raise ForecastError("unknown target")
    rows, excluded = [], {"censored_run": 0, "unknown_attempt": 0, "synthetic": 0}
    for r in runs:
        if r.get("_synthetic"):
            excluded["synthetic"] += 1
            continue
        key = "%s/%s" % (r.get("_exporter", "?"), r["runId"])
        x = features(r)
        meta = {"build": r.get("build"), "catalog": (r.get("assessment") or {}).get("catalog")}
        if target == "full_clear":
            if r["outcome"] == "unknown":
                excluded["censored_run"] += 1
                continue
            rows.append((key, r["startedAt"], r["instance"], x, 1 if r["outcome"] == "completed" else 0, meta))
            continue
        if r["outcome"] == "unknown":
            excluded["censored_run"] += 1
            continue
        by = {}
        for a in r.get("attempts") or []:
            by.setdefault(a["encounterId"], []).append(a)
        for enc, atts in sorted(by.items()):
            atts.sort(key=lambda a: (a.get("start") or 0, a["id"]))
            cohort = "%s/%s" % (r["instance"], atts[0].get("name") or enc)
            if target == "first_attempt_kill":
                res = atts[0]["result"]
                if res == "unknown":
                    excluded["unknown_attempt"] += 1
                    continue
                y = 1 if res == "kill" else 0
            else:
                results = [a["result"] for a in atts]
                if "kill" in results:
                    y = 1
                elif "unknown" in results:
                    excluded["unknown_attempt"] += 1
                    continue
                else:
                    y = 0
            rows.append((key, r["startedAt"], cohort, x, y, meta))
    return rows, excluded


def digest(rows):
    h = hashlib.sha256()
    for key, t, cohort, x, y, _ in sorted(rows, key=lambda r: (r[1], r[0], r[2])):
        h.update(contract.canonical([key, t, cohort, x, y]))
    return h.hexdigest()


def split(rows):
    """Chronological by run: the newest 20% of runs (at least MIN_HOLDOUT) are held out."""
    order = sorted({(t, key) for key, t, *_ in rows})
    n_hold = max(MIN_HOLDOUT, int(math.ceil(len(order) * 0.2)))
    hold_keys = {k for _, k in order[-n_hold:]} if len(order) > n_hold else set()
    train = [r for r in rows if r[0] not in hold_keys]
    hold = [r for r in rows if r[0] in hold_keys]
    return train, hold, len(order) - len(hold_keys), len(hold_keys)


def eligibility(rows):
    reasons = []
    train, hold, n_train_runs, n_hold_runs = split(rows)
    if n_train_runs < MIN_TRAIN:
        reasons.append("training runs %d < %d" % (n_train_runs, MIN_TRAIN))
    if n_hold_runs < MIN_HOLDOUT:
        reasons.append("held-out runs %d < %d" % (n_hold_runs, MIN_HOLDOUT))
    pos = sum(r[4] for r in hold)
    if pos < MIN_EACH or len(hold) - pos < MIN_EACH:
        reasons.append("held-out outcomes: %d yes, %d no (need %d each)" % (pos, len(hold) - pos, MIN_EACH))
    if rows:
        share = sum(r[4] for r in rows) / len(rows)
        if share > MAX_SHARE or share < 1 - MAX_SHARE:
            reasons.append("one outcome is above 95%")
    if len({r[5]["build"] for r in rows}) > 1:
        reasons.append("runs come from more than one game build")
    if len({r[5]["catalog"] for r in rows}) > 1:
        reasons.append("runs come from more than one catalog version")
    return reasons, train, hold


# ------------------------------------------------------------ models
def _sig(z):
    if z < -35:
        return 1e-15
    if z > 35:
        return 1 - 1e-15
    return 1 / (1 + math.exp(-z))


class Logistic:
    def __init__(self, names, l2=1.0, steps=400, lr=0.5):
        self.names, self.l2, self.steps, self.lr = names, l2, steps, lr

    def fit(self, X, y):
        n, k = len(X), len(self.names)
        cols = [[row[j] for row in X] for j in range(k)]
        self.mu = [sum(c) / n for c in cols]
        self.sd = [math.sqrt(sum((v - m) ** 2 for v in c) / n) or 1.0 for c, m in zip(cols, self.mu)]
        Z = [[(row[j] - self.mu[j]) / self.sd[j] for j in range(k)] for row in X]
        self.w, self.b = [0.0] * k, 0.0
        for _ in range(self.steps):
            gw, gb = [0.0] * k, 0.0
            for z, t in zip(Z, y):
                e = _sig(self.b + sum(wj * zj for wj, zj in zip(self.w, z))) - t
                gb += e
                for j in range(k):
                    gw[j] += e * z[j]
            self.b -= self.lr * gb / n
            self.w = [wj - self.lr * (g / n + self.l2 * wj / n) for wj, g in zip(self.w, gw)]
        return self

    def predict(self, X):
        k = len(self.names)
        return [_sig(self.b + sum(self.w[j] * (row[j] - self.mu[j]) / self.sd[j] for j in range(k))) for row in X]


ROLE_LEVEL = ["tank", "healer", "levelMin", "levelMax"]


def _matrix(rows, names):
    return [[r[3][n] for n in names] for r in rows], [r[4] for r in rows]


def brier(p, y):
    return sum((a - b) ** 2 for a, b in zip(p, y)) / len(y)


def auc(p, y):
    pos = [a for a, t in zip(p, y) if t == 1]
    neg = [a for a, t in zip(p, y) if t == 0]
    if not pos or not neg:
        return None
    wins = sum(1.0 if a > b else 0.5 if a == b else 0.0 for a in pos for b in neg)
    return wins / (len(pos) * len(neg))


def reliability(p, y, bins=10):
    out = []
    for i in range(bins):
        lo, hi = i / bins, (i + 1) / bins
        idx = [j for j, v in enumerate(p) if lo <= v < hi or (i == bins - 1 and v == 1.0)]
        if idx:
            out.append({"bin": [lo, hi], "n": len(idx), "meanPredicted": round(sum(p[j] for j in idx) / len(idx), 4),
                        "observed": round(sum(y[j] for j in idx) / len(idx), 4)})
    return out


def calibration(p, y):
    """Slope and intercept of y on logit(p) (a one-feature logistic fit)."""
    lg = [[math.log(max(min(v, 1 - 1e-9), 1e-9) / (1 - max(min(v, 1 - 1e-9), 1e-9)))] for v in p]
    m = Logistic(["logit"], l2=0.0, steps=300).fit(lg, y)
    slope = m.w[0] / m.sd[0]
    return slope, m.b - slope * m.mu[0]


def _boot(fn, n, seed=7, reps=200):
    rng = random.Random(seed)
    vals = sorted(fn([rng.randrange(n) for _ in range(n)]) for _ in range(reps))
    return vals[int(0.025 * reps)], vals[int(0.975 * reps) - 1]


def evaluate(name, p, base_p, y):
    m = {"model": name, "brier": round(brier(p, y), 5), "baselineBrier": round(brier(base_p, y), 5),
         "auc": auc(p, y), "reliability": reliability(p, y)}
    lo, hi = _boot(lambda idx: brier([p[i] for i in idx], [y[i] for i in idx]) -
                   brier([base_p[i] for i in idx], [y[i] for i in idx]), len(y))
    m["brierMinusBaseline"] = {"low": round(lo, 5), "high": round(hi, 5)}
    if name != "prevalence":
        slope, icpt = calibration(p, y)
        s_lo, s_hi = _boot(lambda idx: calibration([p[i] for i in idx], [y[i] for i in idx])[0], len(y), reps=60)
        m["calibration"] = {"slope": round(slope, 3), "intercept": round(icpt, 3),
                            "slopeInterval": [round(s_lo, 3), round(s_hi, 3)]}
    m["passes"] = name != "prevalence" and hi <= 0
    return m


# ------------------------------------------------------------ pipeline
def run(runs, target, cohort=None, *, approval=None, allow_unapproved_for_test=False):
    """One model card per (target, cohort). Never approved; eligible only when
    everything in the plan holds on real data."""
    rows, excluded = labelled(runs, target)
    if cohort:
        rows = [r for r in rows if r[2] == cohort]
    card = {"modelVersion": MODEL_VERSION, "target": target, "cohort": cohort, "rows": len(rows),
            "excluded": excluded, "datasetSha256": digest(rows), "approved": False, "approvedBy": None,
            "eligible": False, "reasons": [], "planApproval": approval}
    if excluded["synthetic"]:
        card["reasons"].append("synthetic records were left out (they never count)")
    if not approval and not allow_unapproved_for_test:
        card["reasons"].append("the forecast plan is not approved yet: nothing fitted")
        return card
    reasons, train, hold = eligibility(rows)
    card["reasons"].extend(reasons)
    card["trainSha256"], card["holdoutSha256"] = digest(train), digest(hold)
    card["trainRows"], card["holdoutRows"] = len(train), len(hold)
    if not train or not hold or len({r[4] for r in train}) < 2 or len({r[4] for r in hold}) < 2:
        card["reasons"].append("both outcomes are needed on both sides: nothing fitted")
        return card
    y_hold = [r[4] for r in hold]
    rate = sum(r[4] for r in train) / len(train)
    base = [rate] * len(hold)
    models = [evaluate("prevalence", base, base, y_hold)]
    for name, names in (("role_level_logistic", ROLE_LEVEL), ("regularized_logistic", sorted(train[0][3]))):
        X, y = _matrix(train, names)
        Xh, _ = _matrix(hold, names)
        p = Logistic(names, l2=1.0 if name == "role_level_logistic" else 5.0).fit(X, y).predict(Xh)
        models.append(evaluate(name, p, base, y_hold))
    card["baseRate"] = round(rate, 4)
    card["models"] = models
    chosen = next((m["model"] for m in models if m["passes"]), None)
    card["chosen"] = chosen
    if not chosen:
        card["reasons"].append("no model beat the prevalence baseline")
    card["eligible"] = bool(chosen and not reasons and approval and not excluded["synthetic"])
    return card


def write_card(card, out):
    if contract._inside_game(out):
        raise ForecastError("refusing to write inside the game folder")
    Path(out).write_text(json.dumps(card, indent=2, sort_keys=True), encoding="utf-8")
    return out
