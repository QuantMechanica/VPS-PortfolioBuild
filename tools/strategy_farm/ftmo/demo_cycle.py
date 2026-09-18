"""Deterministic FTMO Demo-cycle ledger and material-change state machine.

Directive 2026-09-15 sections 12, 16 and follow-up sections 13-14
(OWNER-DEC-CBE-20260915). Answers, deterministically:

* Which exact portfolio is under Demo validation? (roster + roster_hash)
* When did the representative two-week period begin? (cycle_start_utc)
* Has composition changed materially? (material_changes + state)
* Is current evidence still representative? (state REPRESENTATIVE / reset)

The roster is OBSERVED read-only from the FTMO demo terminal's actual chart/EA
set. Nothing here starts MT5, toggles AutoTrading, trades, or writes the farm DB.

The read-model D:/QM/reports/state/ftmo_demo_cycle.json is also the ledger:
`build_demo_cycle(observation, prev_ledger, now, policy)` is a pure function of
its inputs, so the same inputs reproduce the same ledger (directive section 70).
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm.ftmo import policy_config

SCHEMA = "qm.ftmo-demo-cycle/v1"
DEFAULT_OUT = Path(r"D:\QM\reports\state\ftmo_demo_cycle.json")
DEFAULT_TERMINAL = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)

# EA name prefixes that are NOT trading sleeves (governor / telemetry).
_NON_SLEEVE_MARKERS = ("account-governor", "TrialTelemetry", "telemetry")
_EA_ID_RE = re.compile(r"QM5?_(\d+)_")

# GAPS G4.2: "attached" is not "trading". A sleeve that initialises and never
# places an order still counts toward the ledger's roster and total_book_risk_pct,
# so the reported book overstates the realised one (this is exactly how QM5_20048
# and QM5_13054 inflate the live demo to a nominal 2.5 %). Flagging is an
# OBSERVABILITY addition only: attached_dark never enters roster_hash, never
# classifies as a material change, and never resets or extends the cycle.
DARK_AFTER_TRADING_DAYS = 5
_PLACEMENT_MARKERS = ("TM_OPEN", "ENTRY_ACCEPTED")
_EA_LOG_RE = re.compile(r"QM5?_(\d+)_.*\.log$", re.IGNORECASE)


def _trading_days_between(start: dt.datetime, end: dt.datetime) -> int:
    """Whole Mon-Fri days elapsed. Deterministic, calendar-free, no holidays."""
    if end <= start:
        return 0
    days = 0
    cursor = start.date()
    last = end.date()
    while cursor < last:
        cursor += dt.timedelta(days=1)
        if cursor.weekday() < 5:
            days += 1
    return days


def observe_placements(files_dir: Path) -> dict[int, int]:
    """Count observed order placements per ea_id from the terminal's EA logs.

    Read-only and tolerant: an unreadable or absent log contributes nothing and
    the sleeve is then reported with placements_source EVIDENCE_MISSING rather
    than being called dark on no evidence.
    """
    counts: dict[int, int] = {}
    files_dir = Path(files_dir)
    if not files_dir.is_dir():
        return counts
    for log in sorted(files_dir.glob("QM*_ea-*.log")):
        match = _EA_ID_RE.search(log.name)
        if not match:
            continue
        ea_id = int(match.group(1))
        try:
            text = log.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        counts[ea_id] = counts.get(ea_id, 0) + sum(
            1 for line in text.splitlines() if any(m in line for m in _PLACEMENT_MARKERS)
        )
    return counts


def flag_attached_dark(
    roster: list[dict[str, Any]],
    placements: dict[Any, int] | None,
    trading_days: int,
    *,
    min_trading_days: int = DARK_AFTER_TRADING_DAYS,
) -> list[dict[str, Any]]:
    """Annotate each sleeve with placements / attached_dark. Pure; returns new rows."""
    out: list[dict[str, Any]] = []
    for sleeve in roster:
        row = dict(sleeve)
        ea_id = row.get("ea_id")
        observed = None
        if placements is not None and ea_id is not None:
            observed = int(placements.get(ea_id, placements.get(str(ea_id), 0)) or 0)
        row["placements_observed"] = observed if observed is not None else "EVIDENCE_MISSING"
        row["trading_days_observed"] = trading_days
        row["attached_dark"] = bool(
            observed == 0 and trading_days >= min_trading_days
        )
        out.append(row)
    return out


def _now(now: dt.datetime | None = None) -> dt.datetime:
    return now or dt.datetime.now(dt.timezone.utc)


def _iso(ts: dt.datetime) -> str:
    return ts.strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------- #
# Roster observation (read-only I/O)
# --------------------------------------------------------------------------- #
def _read_chart_text(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ("utf-16", "utf-16-le", "utf-8"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_chart_profile(profile_dir: Path, experts_dir: Path | None = None) -> list[dict[str, Any]]:
    """Parse the demo terminal's chart profile into trading-sleeve rows.

    Reads each chart*.chr (UTF-16) for symbol + first expert name + magic slot
    offset + RISK_PERCENT. Governor and telemetry experts and empty charts are
    excluded. ex5 sha is hashed from `experts_dir` when the binary is present.
    """
    profile_dir = Path(profile_dir)
    sleeves: list[dict[str, Any]] = []
    for chart in sorted(profile_dir.glob("chart*.chr")):
        text = _read_chart_text(chart)
        symbol = None
        ea_name = None
        slot_offset = 0
        risk_pct = None
        in_expert = False
        for line in text.splitlines():
            s = line.strip()
            if s.startswith("symbol=") and symbol is None:
                symbol = s.split("=", 1)[1].strip()
            elif s == "<expert>":
                in_expert = True
            elif in_expert and s.startswith("name=") and ea_name is None:
                ea_name = s.split("=", 1)[1].strip()
            elif s.startswith("qm_magic_slot_offset="):
                try:
                    slot_offset = int(s.split("=", 1)[1].strip())
                except ValueError:
                    slot_offset = 0
            elif s.startswith("RISK_PERCENT="):
                try:
                    risk_pct = float(s.split("=", 1)[1].strip())
                except ValueError:
                    risk_pct = None
        if not ea_name or any(m in ea_name for m in _NON_SLEEVE_MARKERS):
            continue
        m = _EA_ID_RE.search(ea_name)
        if not m:
            continue
        ea_id = int(m.group(1))
        magic = ea_id * 10000 + slot_offset
        ex5_sha = "UNKNOWN"
        if experts_dir is not None:
            cand = Path(experts_dir) / f"{ea_name}.ex5"
            if cand.is_file():
                ex5_sha = _sha256(cand)
        sleeves.append(
            {
                "ea_id": ea_id,
                "ea_name": ea_name,
                "symbol": symbol or "UNKNOWN",
                "slot": slot_offset,
                "magic": magic,
                "risk_pct": risk_pct,
                "ex5_sha": ex5_sha,
                "chart": chart.name,
            }
        )
    return sleeves


def observe_demo_terminal(terminal_dir: Path = DEFAULT_TERMINAL) -> dict[str, Any]:
    """Build an observation dict from the live terminal, read-only.

    Falls back across roster sources and records `roster_source`. Returns
    {'roster': [...], 'roster_source', 'product', 'compliance'}.
    """
    terminal_dir = Path(terminal_dir)
    profile = terminal_dir / "MQL5" / "Profiles" / "Charts" / "Default"
    experts = terminal_dir / "MQL5" / "Experts" / "QM_FTMO"
    roster: list[dict[str, Any]] = []
    source = "EVIDENCE_MISSING"
    if profile.is_dir():
        roster = parse_chart_profile(profile, experts if experts.is_dir() else None)
        if roster:
            source = "chart_profile"
    if not roster:
        attach = terminal_dir / "ftmo_demo_attach_map.json"
        if attach.is_file():
            try:
                rows = json.loads(attach.read_text(encoding="utf-8"))
                for row in rows:
                    slot, symbol, tf, ea_file, _setf, magic = row
                    m = _EA_ID_RE.search(ea_file)
                    roster.append(
                        {
                            "ea_id": int(m.group(1)) if m else None,
                            "ea_name": ea_file.rsplit(".", 1)[0],
                            "symbol": symbol,
                            "slot": slot,
                            "magic": magic,
                            "risk_pct": None,
                            "ex5_sha": "UNKNOWN",
                        }
                    )
                if roster:
                    source = "ftmo_demo_attach_map"
            except (OSError, json.JSONDecodeError, ValueError, TypeError):
                roster = []
    files_dir = terminal_dir / "MQL5" / "Files" / "QM"
    placements = observe_placements(files_dir)
    return {
        "roster": roster,
        "roster_source": source,
        "placements": placements,
        "placements_source": str(files_dir) if placements else "EVIDENCE_MISSING",
        "product": policy_config.DEFAULT_ACCOUNT_LABEL,
        "compliance": {"rulepack": "FTMO_2S_100K_STANDARD_V2"},
        "observed_at_utc": _iso(_now()),
    }


# --------------------------------------------------------------------------- #
# Pure hashing / classification
# --------------------------------------------------------------------------- #
def roster_hash(roster: list[dict[str, Any]]) -> str:
    """Composition identity: sorted (magic, ea_id, symbol). ex5/risk excluded so
    mechanics/risk changes are classified separately, not folded into identity."""
    canon = sorted(
        (str(s.get("magic")), str(s.get("ea_id")), str(s.get("symbol"))) for s in roster
    )
    blob = json.dumps(canon, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def _by_magic(roster: list[dict[str, Any]]) -> dict[Any, dict[str, Any]]:
    return {s.get("magic"): s for s in roster}


def _total_book_risk(roster: list[dict[str, Any]]) -> float:
    return sum(float(s.get("risk_pct") or 0.0) for s in roster)


def classify_material_change(
    prev_roster: list[dict[str, Any]],
    curr_roster: list[dict[str, Any]],
    *,
    prev_product: str | None = None,
    curr_product: str | None = None,
    prev_compliance: Any = None,
    curr_compliance: Any = None,
    policy=policy_config,
) -> dict[str, Any]:
    """Deterministic §14 material-change classification.

    Returns {changes:[{type, detail, material, representative_breaking}],
    material: bool, representative_breaking: bool, resets_cycle: bool}.
    """
    changes: list[dict[str, Any]] = []
    prev = _by_magic(prev_roster)
    curr = _by_magic(curr_roster)
    prev_total = _total_book_risk(prev_roster)
    risk_denom = max(prev_total, policy.RISK_MATERIAL_ABS_PCT_FLOOR)

    added = [m for m in curr if m not in prev]
    removed = [m for m in prev if m not in curr]
    for m in sorted(added, key=str):
        changes.append(
            {
                "type": "SLEEVE_ADDED",
                "detail": {"magic": m, "symbol": curr[m].get("symbol")},
                "material": True,
                "representative_breaking": True,
            }
        )
    for m in sorted(removed, key=str):
        changes.append(
            {
                "type": "SLEEVE_REMOVED",
                "detail": {"magic": m, "symbol": prev[m].get("symbol")},
                "material": True,
                "representative_breaking": True,
            }
        )

    # Risk change on surviving sleeves: material if aggregate risk delta over
    # surviving sleeves exceeds X * prior total book risk.
    survivors = [m for m in curr if m in prev]
    risk_delta_abs = 0.0
    per_sleeve_risk: list[dict[str, Any]] = []
    for m in survivors:
        pr = float(prev[m].get("risk_pct") or 0.0)
        cr = float(curr[m].get("risk_pct") or 0.0)
        d = abs(cr - pr)
        if d > 0:
            risk_delta_abs += d
            per_sleeve_risk.append({"magic": m, "prev": pr, "curr": cr, "delta": round(d, 6)})
    if risk_delta_abs > 0:
        share = risk_delta_abs / risk_denom
        material = share > policy.RISK_MATERIAL_BOOK_SHARE_X
        changes.append(
            {
                "type": "RISK_CHANGED",
                "detail": {
                    "aggregate_delta_pct": round(risk_delta_abs, 6),
                    "prior_book_risk_pct": round(prev_total, 6),
                    "share_of_book": round(share, 6),
                    "threshold_X": policy.RISK_MATERIAL_BOOK_SHARE_X,
                    "sleeves": per_sleeve_risk,
                },
                "material": material,
                "representative_breaking": material,
            }
        )

    # Mechanics (ex5 hash) change on surviving sleeves. Material for the sleeve;
    # representative-breaking only if the affected risk share >= Y of book risk.
    mech_magics: list[Any] = []
    mech_risk = 0.0
    for m in survivors:
        p_sha = prev[m].get("ex5_sha")
        c_sha = curr[m].get("ex5_sha")
        if p_sha and c_sha and p_sha != "UNKNOWN" and c_sha != "UNKNOWN" and p_sha != c_sha:
            mech_magics.append(m)
            mech_risk += float(curr[m].get("risk_pct") or 0.0)
    if mech_magics:
        share = mech_risk / risk_denom
        breaking = share >= policy.MECHANICS_REPRESENTATIVE_BOOK_SHARE_Y
        changes.append(
            {
                "type": "MECHANICS_CHANGED",
                "detail": {
                    "magics": sorted(mech_magics, key=str),
                    "affected_risk_pct": round(mech_risk, 6),
                    "affected_risk_share": round(share, 6),
                    "threshold_Y": policy.MECHANICS_REPRESENTATIVE_BOOK_SHARE_Y,
                },
                "material": True,
                "representative_breaking": breaking,
            }
        )

    # Compliance / news rule change: material (representative-breaking).
    if prev_compliance is not None and curr_compliance is not None and prev_compliance != curr_compliance:
        changes.append(
            {
                "type": "COMPLIANCE_CHANGED",
                "detail": {"prev": prev_compliance, "curr": curr_compliance},
                "material": True,
                "representative_breaking": True,
            }
        )

    # Product change: material and always starts a new cycle.
    product_changed = (
        prev_product is not None and curr_product is not None and prev_product != curr_product
    )
    if product_changed:
        changes.append(
            {
                "type": "PRODUCT_CHANGED",
                "detail": {"prev": prev_product, "curr": curr_product},
                "material": True,
                "representative_breaking": True,
            }
        )

    material = any(c["material"] for c in changes)
    representative_breaking = any(c["representative_breaking"] for c in changes)
    return {
        "changes": changes,
        "material": material,
        "representative_breaking": representative_breaking,
        "resets_cycle": representative_breaking,
    }


def advance_state(
    prev_state: str | None,
    *,
    validation_days: float,
    representative_breaking_since_start: bool,
    is_new_cycle: bool,
    min_days: int = policy_config.VALIDATION_MIN_DAYS,
) -> str:
    """NEW -> RUNNING -> REPRESENTATIVE(>=min_days, no rep-breaking change).

    DECISION_PACKAGE is stamped by the readiness layer and preserved here while
    the cycle stays representative.
    """
    if is_new_cycle:
        return "NEW"
    if representative_breaking_since_start:
        # A rep-breaking change resets the clock; handled by is_new_cycle upstream,
        # but guard here too.
        return "NEW"
    if validation_days >= min_days:
        if prev_state == "DECISION_PACKAGE":
            return "DECISION_PACKAGE"
        return "REPRESENTATIVE"
    return "RUNNING"


# --------------------------------------------------------------------------- #
# Ledger assembly (pure)
# --------------------------------------------------------------------------- #
def build_demo_cycle(
    observation: dict[str, Any],
    prev_ledger: dict[str, Any] | None,
    now: dt.datetime | None = None,
    policy=policy_config,
) -> dict[str, Any]:
    """Pure ledger update. Reproducible from (observation, prev_ledger, now)."""
    now = _now(now)
    roster = observation.get("roster") or []
    r_hash = roster_hash(roster) if roster else "EVIDENCE_MISSING"
    product = observation.get("product")
    compliance = observation.get("compliance")

    prev = prev_ledger or {}
    prev_hash = prev.get("roster_hash")
    prev_roster = prev.get("roster") or []
    history = list(prev.get("roster_history") or [])

    material = classify_material_change(
        prev_roster,
        roster,
        prev_product=prev.get("product"),
        curr_product=product,
        prev_compliance=prev.get("compliance"),
        curr_compliance=compliance,
        policy=policy,
    )

    # A new cycle starts when: no prior evidence, the composition hash changed, or
    # a representative-breaking change occurred.
    is_new_cycle = (
        not prev
        or prev_hash in (None, "EVIDENCE_MISSING")
        or (r_hash != "EVIDENCE_MISSING" and r_hash != prev_hash)
        or material["resets_cycle"]
    )

    if roster == [] :
        cycle_start = prev.get("cycle_start_utc", "UNKNOWN")
        start_provenance = prev.get("cycle_start_provenance", "EVIDENCE_MISSING")
    elif is_new_cycle:
        cycle_start = _iso(now)
        start_provenance = "first_observation_of_current_roster_hash"
        history.append({"roster_hash": r_hash, "first_seen_utc": _iso(now)})
    else:
        cycle_start = prev.get("cycle_start_utc", _iso(now))
        start_provenance = prev.get("cycle_start_provenance", "first_observation_of_current_roster_hash")

    # validation_days
    if isinstance(cycle_start, str) and cycle_start not in ("UNKNOWN",):
        try:
            start_dt = dt.datetime.fromisoformat(cycle_start.replace("Z", "+00:00"))
            if start_dt.tzinfo is None:
                start_dt = start_dt.replace(tzinfo=dt.timezone.utc)
            validation_days = round((now - start_dt).total_seconds() / 86400.0, 3)
        except ValueError:
            validation_days = 0.0
    else:
        validation_days = "UNKNOWN"

    # Accumulate material changes recorded during the CURRENT cycle.
    if is_new_cycle:
        cycle_material_changes: list[dict[str, Any]] = []
    else:
        cycle_material_changes = list(prev.get("material_changes") or [])
        for c in material["changes"]:
            if c["material"]:
                cycle_material_changes.append({**c, "observed_utc": _iso(now)})

    rep_breaking_since_start = any(
        c.get("representative_breaking") for c in cycle_material_changes
    )

    vdays_num = validation_days if isinstance(validation_days, (int, float)) else 0.0
    state = advance_state(
        prev.get("state"),
        validation_days=vdays_num,
        representative_breaking_since_start=rep_breaking_since_start,
        is_new_cycle=is_new_cycle,
        min_days=policy.VALIDATION_MIN_DAYS,
    )

    representative = state in ("REPRESENTATIVE", "DECISION_PACKAGE")

    # Observability only (G4.2): computed AFTER roster_hash, material changes and
    # state, so a dark sleeve is surfaced without altering cycle semantics.
    trading_days = 0
    if isinstance(cycle_start, str) and cycle_start not in ("UNKNOWN",):
        try:
            start_dt = dt.datetime.fromisoformat(cycle_start.replace("Z", "+00:00"))
            if start_dt.tzinfo is None:
                start_dt = start_dt.replace(tzinfo=dt.timezone.utc)
            trading_days = _trading_days_between(start_dt, now)
        except ValueError:
            trading_days = 0
    placements = observation.get("placements")
    annotated = flag_attached_dark(
        roster, placements, trading_days,
        min_trading_days=int(observation.get("dark_after_trading_days", DARK_AFTER_TRADING_DAYS)),
    )
    dark = [s["magic"] for s in annotated if s.get("attached_dark")]
    dark_risk = round(sum(float(s.get("risk_pct") or 0.0) for s in annotated if s.get("attached_dark")), 6)
    book_risk = round(_total_book_risk(roster), 6) if roster else "EVIDENCE_MISSING"

    return {
        "schema": SCHEMA,
        "generated_at_utc": _iso(now),
        "account": {
            "type": policy.DEFAULT_ACCOUNT_TYPE,
            "size_usd": policy.DEFAULT_ACCOUNT_SIZE_USD,
            "product": policy.DEFAULT_PRODUCT,
        },
        "roster_source": observation.get("roster_source", "EVIDENCE_MISSING"),
        "roster_hash": r_hash,
        "roster": annotated,
        "sleeve_count": len(roster),
        "total_book_risk_pct": book_risk,
        "placements_source": observation.get("placements_source", "EVIDENCE_MISSING"),
        "trading_days_observed": trading_days,
        "dark_after_trading_days": int(observation.get("dark_after_trading_days", DARK_AFTER_TRADING_DAYS)),
        "attached_dark_magics": sorted(dark, key=str),
        "attached_dark_count": len(dark),
        "attached_dark_risk_pct": dark_risk,
        "realised_book_risk_pct": (round(float(book_risk) - dark_risk, 6)
                                   if isinstance(book_risk, (int, float)) else "EVIDENCE_MISSING"),
        "product": product,
        "compliance": compliance,
        "cycle_start_utc": cycle_start,
        "cycle_start_provenance": start_provenance,
        "validation_days": validation_days,
        "validation_min_days": policy.VALIDATION_MIN_DAYS,
        "state": state,
        "representative": representative,
        "is_new_cycle_this_observation": is_new_cycle,
        "latest_change_assessment": material,
        "material_changes": cycle_material_changes,
        "roster_history": history,
    }


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
def _load_json(path: Path) -> dict[str, Any] | None:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None


def build_and_write(
    out: Path = DEFAULT_OUT,
    terminal_dir: Path = DEFAULT_TERMINAL,
    now: dt.datetime | None = None,
    dark_after_trading_days: int = DARK_AFTER_TRADING_DAYS,
) -> dict[str, Any]:
    observation = observe_demo_terminal(terminal_dir)
    observation["dark_after_trading_days"] = int(dark_after_trading_days)
    prev = _load_json(out)
    ledger = build_demo_cycle(observation, prev, now)
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(ledger, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return ledger


def _main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="FTMO Demo-cycle ledger")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_build = sub.add_parser("build", help="observe the demo terminal and update the ledger")
    p_build.add_argument("--out", default=str(DEFAULT_OUT))
    p_build.add_argument("--terminal", default=str(DEFAULT_TERMINAL))
    p_build.add_argument("--dark-after-days", type=int, default=DARK_AFTER_TRADING_DAYS,
                         help="trading days with zero placements before a sleeve is flagged attached_dark")
    args = parser.parse_args(argv)
    if args.cmd == "build":
        ledger = build_and_write(Path(args.out), Path(args.terminal), dark_after_trading_days=args.dark_after_days)
        print(json.dumps({k: ledger[k] for k in (
            "schema", "state", "roster_hash", "cycle_start_utc", "validation_days", "sleeve_count",
            "attached_dark_count", "attached_dark_magics", "realised_book_risk_pct")}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
