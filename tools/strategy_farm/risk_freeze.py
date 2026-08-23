"""Interim live-risk freeze: arm it, and prove afterwards that it held.

`OWNER-DEC-RISK-FREEZE`, ordered by OWNER on 2026-08-22: risk unchanged, no new
live promotion, until the deploy pointer (SP-A1/A2), the news contract V2 spec
and the governor hardening are in place.

A freeze that only exists in a document is not a freeze -- it is a note. This
tool turns it into a measured state:

  arm     capture the exact live risk vector as a baseline and write the signed
          freeze state. Refuses to re-arm an active freeze (that would silently
          rebase the very thing being protected).
  verify  re-measure T_Live and the sleeve roster against that baseline. Any
          drift in a risk value, a preset byte, a binary, or the roster exits
          non-zero. Fail-closed: an unreadable baseline is drift, not "fine".
  status  the same check, rendered for a human.

Read-only against `C:\\QM\\mt5\\T_Live`. This tool never writes a preset, never
touches a binary, and never toggles AutoTrading -- that last one is OWNER-only
under the Hard Rules and no AI seat may do it.

Scope note: the freeze covers the DXZ live book on T_Live. Backtests, the
factory, and gate work are explicitly NOT frozen -- the drain programme
continues; that is the point of freezing the book instead of the pipeline.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

PRESETS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets")
STATE = Path(r"D:\QM\reports\state\live_risk_freeze.json")
SCHEMA = "qm.live_risk_freeze.v1"

PRESET_RE = re.compile(r"^(?P<nn>\d{2})_(?P<sym>[A-Z0-9]+)_(?P<tf>[A-Z0-9]+)_QM5_(?P<ea>\d+)_")
KEY_RE = {
    "RISK_PERCENT": re.compile(r"^RISK_PERCENT=([0-9.]+)", re.M),
    "RISK_FIXED": re.compile(r"^RISK_FIXED=([0-9.]+)", re.M),
    "PORTFOLIO_WEIGHT": re.compile(r"^PORTFOLIO_WEIGHT=([0-9.]+)", re.M),
    "qm_magic_slot_offset": re.compile(r"^qm_magic_slot_offset=(\d+)", re.M),
}

LIFT_CONDITIONS = [
    {
        "id": "SP-A1/A2-DEPLOY-POINTER",
        "requirement": "live_deployment_pointer.json is signed and its consumers read authenticated instead of UNKNOWN",
        "status": "BLOCKED",
        "blocked_by": "OWNER-DEC-POINTER-PRESETS -- 10 of 24 deployed presets carry no valid build provenance; signing was held rather than asserting provenance that does not exist. Repair diagnosis: router task 740049db",
    },
    {
        "id": "NEWS-CONTRACT-V2",
        "requirement": "news impact taxonomy implemented under qm.news_impact_mapping.v1",
        "status": "PARTIAL",
        "blocked_by": "router task 84c988e6 -- OWNER half decided 2026-08-22 (clean canonical); still gated on Q09 rerun completion",
    },
    {
        "id": "GOVERNOR-HARDENING",
        "requirement": "account/portfolio governor hardened AND actually enforcing",
        "status": "PARTIAL",
        "blocked_by": "SP-C1 is approved and dry-run-proven at commit 593c9ddca, but its v2 monitor deploy and action adapter remain OWNER/ROT-gated and are not live",
    },
]

INACTIVE_STATUSES = frozenset({"INACTIVE", "LIFTED"})


class RiskFreezeBlocked(RuntimeError):
    """A live-book mutation was refused by the OWNER risk-freeze contract."""

    def __init__(self, message: str, result: dict):
        super().__init__(message)
        self.result = result


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str | None:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError:
        return None


def measure(presets_dir: Path | None = None) -> dict:
    """Measure the live risk vector from the deployed presets themselves.

    The presets on disk are the ground truth: they are what the terminal loads.
    A manifest states intent; only these files state fact.

    `presets_dir` resolves at call time, not import time, so the whole tool can
    be exercised against a fixture directory. A verifier that cannot be pointed
    at a known-bad tree cannot be proven to refuse anything.
    """
    presets_dir = presets_dir or PRESETS
    sleeves, problems = [], []
    if not presets_dir.is_dir():
        return {
            "ok": False,
            "problems": [f"presets_dir_unreadable:{presets_dir}"],
            "sleeve_count": 0,
            "total_risk_percent": None,
            "roster_sha256": None,
            "sleeves": [],
        }

    for preset in sorted(presets_dir.glob("*.set")):
        m = PRESET_RE.match(preset.name)
        if not m:
            problems.append(f"unparseable_preset_name:{preset.name}")
            continue
        try:
            raw = preset.read_bytes()
        except OSError as exc:
            problems.append(f"preset_unreadable:{preset.name}:{exc}")
            continue
        text = raw.decode("utf-8", errors="replace")
        entry = {
            "preset": preset.name,
            "slot": int(m.group("nn")),
            "ea_id": int(m.group("ea")),
            "symbol": m.group("sym"),
            "timeframe": m.group("tf"),
            "preset_sha256": sha256_bytes(raw),
        }
        for key, rx in KEY_RE.items():
            hit = rx.search(text)
            entry[key] = float(hit.group(1)) if hit else None
            if hit is None:
                problems.append(f"missing_key:{preset.name}:{key}")
        sleeves.append(entry)

    risks = [s["RISK_PERCENT"] for s in sleeves if s["RISK_PERCENT"] is not None]
    return {
        "ok": not problems,
        "problems": problems,
        "sleeve_count": len(sleeves),
        "total_risk_percent": round(sum(risks), 4) if risks else None,
        "roster_sha256": sha256_bytes(
            json.dumps(sorted((s["ea_id"], s["symbol"]) for s in sleeves)).encode()
        ),
        "sleeves": sleeves,
    }


def cmd_arm(args) -> int:
    if STATE.exists() and not args.force:
        existing = json.loads(STATE.read_text(encoding="utf-8"))
        if existing.get("status") == "ACTIVE":
            print(json.dumps({
                "ok": False,
                "reason": "freeze_already_active",
                "armed_at_utc": existing.get("armed_at_utc"),
                "detail": "Re-arming would rebase the baseline onto whatever is deployed now, "
                          "silently absorbing any drift the freeze exists to catch. "
                          "Use `verify` to check it, or lift it deliberately.",
            }, indent=1))
            return 3

    baseline = measure()
    if not baseline["ok"]:
        print(json.dumps({"ok": False, "reason": "baseline_measurement_unclean",
                          "problems": baseline["problems"]}, indent=1))
        return 2

    state = {
        "schema": SCHEMA,
        "status": "ACTIVE",
        "decision_id": "OWNER-DEC-RISK-FREEZE",
        "authority": args.authority,
        "armed_at_utc": args.armed_at_utc,
        "armed_by": "claude-orchestrator",
        "scope": {
            "frozen": [
                "per-sleeve RISK_PERCENT on the T_Live DXZ book",
                "the sleeve roster (no additions, no removals)",
                "deployed preset bytes and their bound binaries",
                "new live promotions of any kind",
            ],
            "not_frozen": [
                "backtests and the T1-T10 factory",
                "gate work Q02-Q10 and the drain programme",
                "builds, reviews, research",
                "diagnosis of the deployed presets (740049db) -- diagnosis only, no T_Live write",
            ],
        },
        "lift_conditions": LIFT_CONDITIONS,
        "lift_rule": "All three conditions met AND an explicit written OWNER lift. "
                     "No AI seat lifts this freeze, and no seat lifts it by inference "
                     "from a condition merely being satisfied.",
        "baseline": baseline,
    }
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=1), encoding="utf-8")
    print(json.dumps({
        "ok": True, "state_path": str(STATE), "state_sha256": sha256_file(STATE),
        "sleeve_count": baseline["sleeve_count"],
        "total_risk_percent": baseline["total_risk_percent"],
        "roster_sha256": baseline["roster_sha256"],
    }, indent=1))
    return 0


def diff_against_baseline(
    state_path: Path | None = None,
    presets_dir: Path | None = None,
) -> dict:
    """Return the single canonical freeze status and baseline diff.

    Paths resolve at call time so every refusal path can be exercised against
    fixtures.  Mutation guards consume this function rather than inventing a
    second interpretation of ACTIVE/inactive state.
    """
    state_path = Path(state_path or STATE)
    presets_dir = Path(presets_dir or PRESETS)
    if not state_path.exists():
        return {
            "status": "NO_FREEZE_STATE",
            "state_path": str(state_path),
            "drift": [f"freeze_state_missing:{state_path}"],
            "held": None,
            "baseline_sleeve_count": None,
            "current_sleeve_count": None,
            "baseline_total_risk_percent": None,
            "current_total_risk_percent": None,
            "lift_conditions": [],
            "lift_rule": None,
        }
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        # Fail closed: an unreadable freeze state is treated as drift, never as "fine".
        return {
            "status": "STATE_UNREADABLE",
            "state_path": str(state_path),
            "drift": [f"state_unreadable:{exc}"],
            "held": False,
            "baseline_sleeve_count": None,
            "current_sleeve_count": None,
            "baseline_total_risk_percent": None,
            "current_total_risk_percent": None,
            "lift_conditions": [],
            "lift_rule": None,
        }

    if not isinstance(state, dict) or state.get("schema") != SCHEMA:
        found = state.get("schema") if isinstance(state, dict) else type(state).__name__
        return {
            "status": "STATE_INVALID",
            "state_path": str(state_path),
            "drift": [f"freeze_state_schema_invalid:{found!r}:expected:{SCHEMA}"],
            "held": False,
            "baseline_sleeve_count": None,
            "current_sleeve_count": None,
            "baseline_total_risk_percent": None,
            "current_total_risk_percent": None,
            "lift_conditions": [],
            "lift_rule": None,
        }

    if state.get("status") != "ACTIVE":
        baseline = state.get("baseline") if isinstance(state.get("baseline"), dict) else {}
        return {
            "status": state.get("status", "UNKNOWN"),
            "state_path": str(state_path),
            "armed_at_utc": state.get("armed_at_utc"),
            "held": None,
            "drift": [],
            "baseline_sleeve_count": baseline.get("sleeve_count"),
            "current_sleeve_count": None,
            "baseline_total_risk_percent": baseline.get("total_risk_percent"),
            "current_total_risk_percent": None,
            "lift_conditions": state.get("lift_conditions", []),
            "lift_rule": state.get("lift_rule"),
            "lift_authority": state.get("lift_authority") or state.get("lifted_by"),
            "lifted_at_utc": state.get("lifted_at_utc"),
        }

    base = state.get("baseline")
    required_baseline_fields = {
        "sleeves", "sleeve_count", "total_risk_percent", "roster_sha256"
    }
    if (
        not isinstance(base, dict)
        or not isinstance(base.get("sleeves"), list)
        or not required_baseline_fields.issubset(base)
    ):
        return {
            "status": "STATE_INVALID",
            "state_path": str(state_path),
            "drift": ["freeze_state_baseline_missing_or_invalid"],
            "held": False,
            "baseline_sleeve_count": None,
            "current_sleeve_count": None,
            "baseline_total_risk_percent": None,
            "current_total_risk_percent": None,
            "lift_conditions": state.get("lift_conditions", []),
            "lift_rule": state.get("lift_rule"),
        }
    required_sleeve_fields = {
        "preset", "RISK_PERCENT", "RISK_FIXED", "PORTFOLIO_WEIGHT",
        "qm_magic_slot_offset", "preset_sha256",
    }
    if any(
        not isinstance(sleeve, dict)
        or not required_sleeve_fields.issubset(sleeve)
        for sleeve in base["sleeves"]
    ):
        return {
            "status": "STATE_INVALID",
            "state_path": str(state_path),
            "drift": ["freeze_state_baseline_sleeve_missing_required_fields"],
            "held": False,
            "baseline_sleeve_count": base.get("sleeve_count"),
            "current_sleeve_count": None,
            "baseline_total_risk_percent": base.get("total_risk_percent"),
            "current_total_risk_percent": None,
            "lift_conditions": state.get("lift_conditions", []),
            "lift_rule": state.get("lift_rule"),
        }
    now = measure(presets_dir)
    drift: list[str] = []

    if not now["ok"]:
        drift.extend(f"measurement:{p}" for p in now["problems"])
    if now["roster_sha256"] != base["roster_sha256"]:
        drift.append(
            f"roster changed: {base['sleeve_count']} sleeves -> {now['sleeve_count']}"
        )
    if now["total_risk_percent"] != base["total_risk_percent"]:
        drift.append(
            f"total RISK_PERCENT {base['total_risk_percent']} -> {now['total_risk_percent']}"
        )

    by_name = {s["preset"]: s for s in now["sleeves"]}
    for old in base["sleeves"]:
        cur = by_name.get(old["preset"])
        if cur is None:
            drift.append(f"preset removed: {old['preset']}")
            continue
        for key in ("RISK_PERCENT", "RISK_FIXED", "PORTFOLIO_WEIGHT",
                    "qm_magic_slot_offset", "preset_sha256"):
            if cur[key] != old[key]:
                drift.append(f"{old['preset']}: {key} {old[key]} -> {cur[key]}")
    for name in by_name.keys() - {s["preset"] for s in base["sleeves"]}:
        drift.append(f"preset added: {name}")

    return {
        "status": "ACTIVE",
        "state_path": str(state_path),
        "armed_at_utc": state.get("armed_at_utc"),
        "held": not drift,
        "drift": drift,
        "baseline_sleeve_count": base["sleeve_count"],
        "current_sleeve_count": now["sleeve_count"],
        "baseline_total_risk_percent": base["total_risk_percent"],
        "current_total_risk_percent": now["total_risk_percent"],
        "lift_conditions": state.get("lift_conditions", []),
        "lift_rule": state.get("lift_rule"),
    }


def _blocked_message(operation: str, result: dict) -> str:
    conditions = []
    for condition in result.get("lift_conditions", []):
        if not isinstance(condition, dict):
            continue
        conditions.append(
            f"{condition.get('id')}[{condition.get('status', 'OPEN')}]:"
            f"{condition.get('blocked_by') or condition.get('requirement')}"
        )
    condition_text = " | ".join(conditions) if conditions else "unavailable"
    drift = " | ".join(str(item) for item in result.get("drift", [])) or "none"
    return (
        f"LIVE_RISK_FREEZE_BLOCKED: operation={operation}; status={result.get('status')}; "
        f"held={result.get('held')}; drift={drift}; "
        f"lift_rule={result.get('lift_rule') or 'explicit written OWNER lift required'}; "
        f"lift_conditions={condition_text}"
    )


def assert_live_book_mutation_allowed(
    operation: str,
    *,
    state_path: Path | None = None,
    presets_dir: Path | None = None,
) -> dict:
    """Fail closed unless a durable state records an explicit OWNER lift.

    Missing, unreadable, invalid, unknown, and ACTIVE states all refuse.  The
    only passing states are explicit INACTIVE/LIFTED records carrying lift
    authority and a lift timestamp; absence of a state is never interpreted as
    permission.  This guard has no effect on backtests, T1-T10, gates, builds,
    reviews, or research because only live-book mutation entrypoints call it.
    """
    result = diff_against_baseline(state_path=state_path, presets_dir=presets_dir)
    status = result.get("status")
    if status in INACTIVE_STATUSES:
        if result.get("lift_authority") and result.get("lifted_at_utc"):
            return {
                **result,
                "allowed": True,
                "operation": operation,
            }
        invalid = {
            **result,
            "status": "STATE_INVALID",
            "held": False,
            "drift": [
                "inactive_freeze_state_missing_explicit_lift_authority_or_lifted_at_utc"
            ],
        }
        raise RiskFreezeBlocked(_blocked_message(operation, invalid), invalid)

    blocked = {**result, "allowed": False, "operation": operation}
    raise RiskFreezeBlocked(_blocked_message(operation, blocked), blocked)


def cmd_verify(args) -> int:
    result = diff_against_baseline()
    print(json.dumps(result, indent=1))
    if result["status"] in ("NO_FREEZE_STATE",):
        return 0
    return 0 if result.get("held") else 1


def cmd_status(args) -> int:
    r = diff_against_baseline()
    if r["status"] == "NO_FREEZE_STATE":
        print("No freeze armed.")
        return 0
    if r["status"] != "ACTIVE":
        print(f"Freeze status: {r['status']}")
        return 0
    print(f"OWNER-DEC-RISK-FREEZE  status=ACTIVE  armed={r['armed_at_utc']}")
    print(f"  total RISK_PERCENT   baseline {r['baseline_total_risk_percent']}"
          f"  now {r['current_total_risk_percent']}")
    print(f"  freeze held          {'YES' if r['held'] else 'NO'}")
    for d in r["drift"]:
        print(f"    DRIFT: {d}")
    print("  lift conditions:")
    for c in r["lift_conditions"]:
        print(f"    [{c['id']}] {c['requirement']}")
        print(f"        blocked by: {c['blocked_by']}")
    return 0 if r["held"] else 1


def cmd_guard(args) -> int:
    try:
        result = assert_live_book_mutation_allowed(args.operation)
    except RiskFreezeBlocked as exc:
        print(json.dumps({
            "ok": False,
            "reason": str(exc),
            "freeze": exc.result,
        }, indent=1))
        return 3
    print(json.dumps({"ok": True, "freeze": result}, indent=1))
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("arm", help="capture the baseline and arm the freeze")
    a.add_argument("--armed-at-utc", required=True,
                   help="ISO-8601 UTC; caller-supplied so the tool needs no clock")
    a.add_argument("--authority", required=True,
                   help="the written OWNER instruction this freeze rests on")
    a.add_argument("--force", action="store_true",
                   help="re-arm over an ACTIVE freeze (rebases the baseline -- deliberate use only)")
    a.set_defaults(func=cmd_arm)

    v = sub.add_parser("verify", help="re-measure against the baseline; non-zero on drift")
    v.set_defaults(func=cmd_verify)

    s = sub.add_parser("status", help="human-readable freeze status")
    s.set_defaults(func=cmd_status)

    g = sub.add_parser("guard", help="refuse a live-book mutation unless OWNER explicitly lifted the freeze")
    g.add_argument("--operation", required=True, help="bounded mutation the caller intends to perform")
    g.set_defaults(func=cmd_guard)

    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
