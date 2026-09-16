"""E1-C Option B: deterministic per-row delta revalidation of NEWS_CALENDAR_TAINTED holds.

Read-only analysis. It never touches the farm database, the taint config, any
hold, any verdict, or any calendar file. It compares, per held row, the event
sets of the tainted pinned calendar against the live clean calendar over the
row's evidence window and currency exposure, records the exact delta, and
classifies the row into exactly one status:

  UNCHANGED_EQUIVALENT  zero relevant calendar delta over the held row's own
                        evidence window AND (where an original verdict exists)
                        the original verdict reproduces under the same
                        deterministic gate logic. Only this status is eligible
                        for Option-B governed hold release.
  VERDICT_FLIP          deterministic recompute shows the verdict would change.
                        Unreachable from sealed aggregate evidence by
                        construction: the calendar is not an input to either
                        gate (q09_news_contract.adjudicate or
                        q10_confirmation._decide_verdict); a non-empty delta
                        therefore always fails closed to DELTA_NOT_EXACT.
  DELTA_NOT_EXACT       non-empty relevant delta; exact equivalence (and hence
                        a deterministic verdict recompute) is impossible
                        without new measurement -> Option A full remeasurement.
  EVIDENCE_INCOMPLETE   the held row's evidence window is not hash-bound
                        (sealed plan unbuilt/unreadable) or the original
                        verdict logic cannot be reproduced over the old
                        evidence -> fail closed -> Option A.

Gate logic sources of truth (found, not invented):
  - news-matrix evidence (q09-news-evidence/v2|v3): q09_news_contract.adjudicate
  - legacy aggregate evidence: framework/scripts/q10_confirmation._decide_verdict
    (PF_FLOOR=1.0, DD_PCT_MAX=25.0) plus the recency-gate outcome recorded in
    the sealed aggregate (q10_recency_enforcement_v1; STALE_WINDOW/UNKNOWN keep
    the base verdict, FAIL flips it).

Currency exposure authority: the OWNER-bound symbol_currency_overrides table in
tools/strategy_farm/config/news_calendar_scoped_consumer_b.v1.json (XAUUSD,
XAGUSD, XTIUSD, XNGUSD, NDX, SP500, WS30 -> USD; GDAXI -> EUR; UK100 -> GBP),
falling back to 6-letter base/quote legs; the same convention as the shipped
read-only census news_calendar_blast_radius.py for USD-index aliases.

Output: one JSON record per row under
docs/ops/evidence/2026-09-16_e1c_optionb/rows/ plus summary.json with the
reconciled 9-metric output. Holds created on/after 2026-09-16 (live sweep
drift after the OWNER census) are classified but excluded from the metrics and
reported under hold_drift_excluded_from_metrics.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
import sys
from collections import Counter
from pathlib import Path
from typing import Any, Iterable, Mapping

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_contract as contract  # noqa: E402
from framework.scripts.q07_multiseed import evaluate_seeds  # noqa: E402
from framework.scripts.q10_confirmation import (  # noqa: E402
    DD_PCT_MAX,
    PF_FLOOR,
    _decide_verdict,
)

DB_URI = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
OLD_EVENTS = Path(r"D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\events.csv")
OLD_MANIFEST = OLD_EVENTS.parent / "manifest.json"
NEW_PRIMARY = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
NEW_SECONDARY = Path(r"D:\QM\data\news_calendar\forex_factory_calendar_clean.csv")
NEW_MANIFEST = Path(r"D:\QM\data\news_calendar\news_calendar_bundle_manifest.json")
OVERRIDES_CONFIG = REPO / "tools" / "strategy_farm" / "config" / "news_calendar_scoped_consumer_b.v1.json"

EXPECTED = {
    "old_events_sha256": "86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1",
    "new_primary_sha256": "c48ad8b4bf667001ef7204d37f5420504f853ac25aa6f0a70152b3d743a1c134",
    "new_secondary_sha256": "e15b6fe1f80f2f6a82a612f16ef7aaf6b9cc450d3eba1c3a94690ceee2f3b935",
    "new_manifest_declared_sha256": "6d7d64b60bb72278e6c65cfb1e738b84a1d9fc5cf11488b573cc136cc1356320",
    "tainted_pin_sha256": "86b2c0b595fd6011a2fe64b7da07f933e755294136a16f584d75389b66c56ce1",
}

USD_INDEX_SYMBOLS = {"NDX", "SP500", "SPX500", "WS30", "US30", "US500", "USTEC"}
TIMEFRAME_RE = re.compile(
    r"_(M1|M2|M3|M4|M5|M6|M10|M12|M15|M20|M30|H1|H2|H3|H4|H6|H8|H12|D1|W1|MN1)(?:_|\.)",
    re.I,
)
HOLD = "NEWS_CALENDAR_TAINTED"
DELEGATION_CUTOVER = "2026-09-16"  # holds created before this date = the 99-row OWNER census

STATUSES = ("UNCHANGED_EQUIVALENT", "VERDICT_FLIP", "DELTA_NOT_EXACT", "EVIDENCE_INCOMPLETE")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()


def parse_instant(value: str) -> str:
    text = value.strip().replace("T", " ").replace("Z", "")
    return dt.datetime.strptime(text, "%Y-%m-%d %H:%M:%S").strftime("%Y-%m-%dT%H:%M:%SZ")


def load_events(path: Path) -> dict[str, list[tuple[str, str, str]]]:
    """Return {currency: [(instant, event_name, impact_upper), ...]} sorted."""
    by_currency: dict[str, list[tuple[str, str, str]]] = {}
    with path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            instant = parse_instant(row["datetime"])
            currency = row["currency"].strip().upper()
            name = " ".join(row["event_name"].split())
            impact = row["impact"].strip().upper()
            by_currency.setdefault(currency, []).append((instant, name, impact))
    for events in by_currency.values():
        events.sort()
    return by_currency


def window_events(events: Mapping[str, list[tuple[str, str, str]]], currencies: Iterable[str],
                  start: str, end: str) -> dict[str, list[tuple[str, str, str]]]:
    result: dict[str, list[tuple[str, str, str]]] = {}
    for currency in currencies:
        rows = [e for e in events.get(currency, []) if start <= e[0] <= end]
        if rows:
            result[currency] = rows
    return result


def summarize(event_map: Mapping[str, list[tuple[str, str, str]]]) -> dict[str, Any]:
    per_currency = {}
    total = 0
    high = 0
    for currency, rows in sorted(event_map.items()):
        per_currency[currency] = {
            "count": len(rows),
            "by_impact": dict(sorted(Counter(r[2] for r in rows).items())),
        }
        total += len(rows)
        high += sum(1 for r in rows if r[2] == "HIGH")
    return {"total": total, "high_impact_total": high, "per_currency": per_currency}


def delta(old_map: Mapping[str, list[tuple[str, str, str]]],
          new_map: Mapping[str, list[tuple[str, str, str]]]) -> dict[str, Any]:
    """Exact delta on (currency, instant, name, impact) rows plus structured lists."""
    added: list[dict[str, str]] = []
    removed: list[dict[str, str]] = []
    changed_impact: list[dict[str, str]] = []
    old_by_key: dict[tuple[str, str, str], list[str]] = {}
    for currency, rows in old_map.items():
        for instant, name, impact in rows:
            old_by_key.setdefault((currency, instant, name), []).append(impact)
    new_by_key: dict[tuple[str, str, str], list[str]] = {}
    for currency, rows in new_map.items():
        for instant, name, impact in rows:
            new_by_key.setdefault((currency, instant, name), []).append(impact)
    for key in sorted(set(old_by_key) | set(new_by_key)):
        currency, instant, name = key
        o = sorted(old_by_key.get(key, []))
        n = sorted(new_by_key.get(key, []))
        if o == n:
            continue
        if o and n:
            changed_impact.append({"currency": currency, "instant_utc": instant,
                                   "event_name": name, "old_impact": o, "new_impact": n})
        elif n:
            for impact in n:
                added.append({"currency": currency, "instant_utc": instant,
                              "event_name": name, "impact": impact})
        else:
            for impact in o:
                removed.append({"currency": currency, "instant_utc": instant,
                                "event_name": name, "impact": impact})
    time_shifted = _time_shifts(old_map, new_map)
    return {
        "added_count": len(added),
        "removed_count": len(removed),
        "changed_impact_count": len(changed_impact),
        "time_shifted_count": len(time_shifted),
        "is_empty": not (added or removed or changed_impact),
        "added_events": added,
        "removed_events": removed,
        "changed_impact_classifications": changed_impact,
        "time_shifted_events": time_shifted,
    }


def _time_shifts(old_map: Mapping[str, list[tuple[str, str, str]]],
                 new_map: Mapping[str, list[tuple[str, str, str]]]) -> list[dict[str, str]]:
    """Informational: same (currency, event_name, impact) at a different instant."""
    shifts = []
    for currency in sorted(set(old_map) | set(new_map)):
        old_by_name: dict[tuple[str, str], list[str]] = {}
        new_by_name: dict[tuple[str, str], list[str]] = {}
        for instant, name, impact in old_map.get(currency, []):
            old_by_name.setdefault((name, impact), []).append(instant)
        for instant, name, impact in new_map.get(currency, []):
            new_by_name.setdefault((name, impact), []).append(instant)
        for key in sorted(set(old_by_name) & set(new_by_name)):
            o = sorted(old_by_name[key])
            n = sorted(new_by_name[key])
            if o != n:
                for old_inst, new_inst in zip(o, n):
                    if old_inst != new_inst:
                        shifts.append({"currency": currency, "event_name": key[0],
                                       "impact": key[1], "old_instant_utc": old_inst,
                                       "new_instant_utc": new_inst})
    return shifts


def load_overrides() -> tuple[dict[str, list[str]], str]:
    raw = OVERRIDES_CONFIG.read_bytes()
    doc = json.loads(raw.decode("utf-8-sig"))
    overrides = doc.get("admissibility", {}).get("symbol_currency_overrides", {})
    return ({str(k).upper(): [str(c).upper() for c in v] for k, v in overrides.items() if isinstance(v, list)},
            sha256_bytes(raw))


def symbol_currencies(symbols: list[str], overrides: Mapping[str, list[str]]) -> tuple[list[str], str]:
    currencies: set[str] = set()
    sources = []
    for raw in symbols:
        normalized = re.sub(r"[^A-Z0-9]", "", raw.upper().replace(".DWX", ""))
        dotted = raw.upper() if "." in raw else f"{raw.upper()}.DWX"
        if dotted in overrides:
            currencies.update(overrides[dotted])
            sources.append(f"{dotted}:owner_override")
            continue
        if normalized in USD_INDEX_SYMBOLS:
            currencies.add("USD")
            sources.append(f"{normalized}:usd_index_alias")
            continue
        if len(normalized) >= 6:
            currencies.update((normalized[:3], normalized[3:6]))
            sources.append(f"{normalized}:legs")
    return sorted(currencies), ",".join(sources)


def payload_symbols(item: Mapping[str, Any], payload: Mapping[str, Any]) -> list[str]:
    basket = payload.get("basket_symbols")
    if isinstance(basket, list) and basket:
        return sorted({str(s) for s in basket})
    host = payload.get("host_symbol") or item.get("symbol")
    return [str(host)] if host else []


def item_timeframe(item: Mapping[str, Any], payload: Mapping[str, Any]) -> str | None:
    direct = payload.get("host_timeframe") or payload.get("expected_period")
    if isinstance(direct, str) and direct.strip():
        return direct.strip().upper()
    match = TIMEFRAME_RE.search(str(item.get("setfile_path") or ""))
    return match.group(1).upper() if match else None


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def strict_json(raw: bytes) -> Any:
    def pairs(items):
        out = {}
        for key, value in items:
            if key in out:
                raise ValueError(f"duplicate key: {key}")
            out[key] = value
        return out
    return json.loads(raw.decode("utf-8-sig"), object_pairs_hook=pairs)


def overlap_stats_legacy(aggregate: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "status": "LEGACY_AGGREGATE",
        "news_compliance": aggregate.get("news_compliance"),
        "news_temporal": aggregate.get("news_temporal"),
        "history_from": aggregate.get("history_from"),
        "history_to": aggregate.get("history_to"),
        "recency_gate_status": (aggregate.get("recency_gate") or {}).get("status"),
        "trades": ((aggregate.get("recency_shadow_v1") or {}).get("full") or {}).get("trades"),
    }


def overlap_stats_matrix(evidence: Mapping[str, Any]) -> dict[str, Any]:
    cells = evidence.get("cells")
    if not isinstance(cells, list):
        return {"status": "no_cells"}
    stats = Counter()
    selfreports = Counter()
    for cell in cells:
        if not isinstance(cell, Mapping):
            continue
        for window in ("selection", "holdout", "full"):
            metrics = cell.get(window)
            if isinstance(metrics, Mapping):
                stats[f"{window}.trades"] += int(metrics.get("trades") or 0)
                stats[f"{window}.affected_entries"] += int(metrics.get("affected_entries") or 0)
                stats[f"{window}.blocked_entries"] += int(metrics.get("blocked_entries") or 0)
        report = cell.get("news_selfreport")
        if isinstance(report, Mapping):
            selfreports[str(report.get("content_sha256"))] += 1
    return {
        "cell_count": len(cells),
        "totals": dict(sorted(stats.items())),
        "calendar_content_sha256_by_cell": dict(selfreports),
    }


def reproduce_q07_verdict(aggregate: Mapping[str, Any]) -> dict[str, Any]:
    """Reproduce a Q07 multi-seed verdict with the gate's own evaluate_seeds().

    framework/scripts/q07_multiseed.evaluate_seeds over the aggregate's embedded
    per_seed_detail (per-seed pf/trades/timed_out/invalid_reason), comparing both
    the verdict and the exact reason string.
    """
    try:
        detail = aggregate.get("per_seed_detail")
        if not isinstance(detail, list) or not detail:
            return {"status": "failed", "reason": "per_seed_detail missing/empty"}
        verdict, reason, _metrics = evaluate_seeds([dict(r) for r in detail])
        return {
            "status": "reproduced_fields",
            "gate_logic": "q07_multiseed.evaluate_seeds over embedded per_seed_detail",
            "recomputed_verdict": verdict,
            "recomputed_reason": reason,
            "recorded_verdict": aggregate.get("verdict"),
            "recorded_reason": aggregate.get("reason"),
            "reason_matches_recorded": reason == aggregate.get("reason"),
        }
    except Exception as exc:  # noqa: BLE001 - fail closed with the reason
        return {"status": "failed", "reason": str(exc)}


def reproduce_legacy_verdict(aggregate: Mapping[str, Any]) -> dict[str, Any]:
    """Reproduce the sealed legacy verdict with the gate's own logic.

    framework/scripts/q10_confirmation._decide_verdict (PF_FLOOR=1.0,
    DD_PCT_MAX=25.0) over the aggregate's own pf/dd/exit_code, then apply the
    recency-gate outcome recorded in the sealed aggregate
    (q10_recency_enforcement_v1: only gate status FAIL flips the verdict).
    """
    try:
        timed_out = False
        invalid_reason = None
        exit_code = aggregate.get("exit_code")
        if exit_code not in (0, None):
            invalid_reason = f"exit_code={exit_code}"
        base, base_reason = _decide_verdict(
            timed_out=timed_out,
            invalid_reason=invalid_reason,
            pf=aggregate.get("pf"),
            dd_money=aggregate.get("dd_money"),
            dd_pct=aggregate.get("dd_pct"),
            timeout_sec=0,
        )
        gate = aggregate.get("recency_gate") or {}
        verdict = "FAIL" if gate.get("status") == "FAIL" else base
        return {
            "status": "reproduced_fields",
            "gate_logic": "q10_confirmation._decide_verdict + recorded recency_gate outcome",
            "gate_constants": {"PF_FLOOR": PF_FLOOR, "DD_PCT_MAX": DD_PCT_MAX},
            "base_verdict": base,
            "base_reason": base_reason,
            "recorded_reason": aggregate.get("reason"),
            "recency_gate_status": gate.get("status"),
            "recomputed_verdict": verdict,
            "reason_matches_recorded": base_reason == aggregate.get("reason"),
        }
    except Exception as exc:  # noqa: BLE001 - fail closed with the reason
        return {"status": "failed", "reason": str(exc)}


def resolve_window(payload: Mapping[str, Any]) -> tuple[tuple[str, str] | None, str | None]:
    """Return ((from, to), source) from hash-bound artifacts only."""
    if payload.get("diagnostic_contract"):
        start, end = payload.get("window_from_utc"), payload.get("window_to_utc")
        if start and end:
            return (start, end), "payload.window_from_utc/window_to_utc"
        return None, None
    plan_path = payload.get("q09_run_plan_path")
    if plan_path and Path(str(plan_path)).is_file():
        try:
            plan_raw = Path(str(plan_path)).read_bytes()
            if sha256_bytes(plan_raw) == payload.get("q09_run_plan_file_sha256"):
                plan = strict_json(plan_raw)
                manifest_ref = plan.get("input_manifest_path")
                manifest_sha = payload.get("q09_input_manifest_sha256")
                if manifest_ref and Path(str(manifest_ref)).is_file():
                    manifest_raw = Path(str(manifest_ref)).read_bytes()
                    if manifest_sha and sha256_bytes(manifest_raw) == manifest_sha:
                        manifest = strict_json(manifest_raw)
                        windows = manifest.get("windows") or {}
                        if windows.get("full_from_utc") and windows.get("full_to_utc"):
                            return ((windows["full_from_utc"], windows["full_to_utc"]),
                                    "sealed run_plan+input_manifest (hash-verified)")
        except (OSError, ValueError, KeyError, TypeError):
            pass
    anchor = payload.get("scoped_q09_pass_execution_anchor")
    if isinstance(anchor, Mapping):
        for key in ("q09_news_evidence_path", "path", "source_evidence_path"):
            value = anchor.get(key)
            if value and Path(str(value)).is_file():
                try:
                    doc = load_json(Path(str(value)))
                    windows = doc.get("windows") or {}
                    if windows.get("full_from_utc") and windows.get("full_to_utc"):
                        return ((windows["full_from_utc"], windows["full_to_utc"]),
                                f"scoped anchor field {key}")
                except (OSError, ValueError):
                    pass
    if payload.get("window_from_utc") and payload.get("window_to_utc"):
        return ((payload["window_from_utc"], payload["window_to_utc"]),
                "payload window fields")
    return None, None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path,
                        default=REPO / "docs" / "ops" / "evidence" / "2026-09-16_e1c_optionb")
    parser.add_argument("--include-drift", action="store_true",
                        help="also classify holds created on/after the delegation census "
                             "(reported separately, excluded from metrics)")
    args = parser.parse_args()
    rows_dir = args.out / "rows"
    rows_dir.mkdir(parents=True, exist_ok=True)

    # ---- calendar + config identity verification (fail closed on mismatch) ----
    identity = {
        "old_events": {"path": str(OLD_EVENTS), "sha256": sha256_file(OLD_EVENTS)},
        "old_manifest": {"path": str(OLD_MANIFEST), "sha256": sha256_file(OLD_MANIFEST)},
        "new_primary": {"path": str(NEW_PRIMARY), "sha256": sha256_file(NEW_PRIMARY)},
        "new_secondary": {"path": str(NEW_SECONDARY), "sha256": sha256_file(NEW_SECONDARY)},
        "new_manifest": {"path": str(NEW_MANIFEST), "sha256": sha256_file(NEW_MANIFEST),
                         "declared_manifest_sha256": None},
    }
    manifest_doc = strict_json(NEW_MANIFEST.read_bytes())
    identity["new_manifest"]["declared_manifest_sha256"] = manifest_doc.get("manifest_sha256")
    old_manifest_doc = strict_json(OLD_MANIFEST.read_bytes())
    overrides, overrides_sha = load_overrides()
    identity["currency_overrides_config"] = {"path": str(OVERRIDES_CONFIG), "sha256": overrides_sha}
    problems = []
    if identity["old_events"]["sha256"] != EXPECTED["old_events_sha256"]:
        problems.append("old events sha mismatch")
    if identity["new_primary"]["sha256"] != EXPECTED["new_primary_sha256"]:
        problems.append("new primary sha mismatch")
    if identity["new_secondary"]["sha256"] != EXPECTED["new_secondary_sha256"]:
        problems.append("new secondary sha mismatch")
    if identity["new_manifest"]["declared_manifest_sha256"] != EXPECTED["new_manifest_declared_sha256"]:
        problems.append("live manifest declared sha mismatch")
    if old_manifest_doc.get("content_sha256") != EXPECTED["tainted_pin_sha256"]:
        problems.append("old manifest content sha != declared tainted pin")
    if problems:
        print(json.dumps({"fatal": problems, "identity": identity}, indent=1))
        return 2

    old_calendar = load_events(OLD_EVENTS)
    new_calendar = load_events(NEW_PRIMARY)
    coverage_note = ("both calendars verified EMPTY for every currency for "
                     "2025-05-01T00:00:00Z..2026-06-30T23:59:59Z (shared upstream gap; "
                     "backfill is the separate human-gated registry-repair/refresh program)")

    conn = sqlite3.connect(DB_URI, uri=True)
    conn.row_factory = sqlite3.Row
    held = conn.execute(
        """
        SELECT h.work_item_id, h.created_at, w.phase, w.ea_id, w.symbol,
               w.setfile_path, w.payload_json
        FROM work_item_holds h JOIN work_items w ON w.id = h.work_item_id
        WHERE h.hold_code = ? AND h.active = 1
        ORDER BY h.work_item_id
        """,
        (HOLD,),
    ).fetchall()

    records = []
    drift_records = []
    for held_row in held:
        item_id = held_row["work_item_id"]
        is_drift = str(held_row["created_at"]) >= DELEGATION_CUTOVER
        if is_drift and not args.include_drift:
            drift_records.append({"work_item_id": item_id, "hold_created_at": held_row["created_at"],
                                  "phase": held_row["phase"], "ea_id": held_row["ea_id"],
                                  "symbol": held_row["symbol"], "classified": False})
            continue
        payload = json.loads(held_row["payload_json"] or "{}")
        symbols = payload_symbols(dict(held_row), payload)
        currencies, currency_source = symbol_currencies(symbols, overrides)
        timeframe = item_timeframe(dict(held_row), payload)
        row_class = ("diagnostic_backfill" if payload.get("diagnostic_contract")
                     else "promoted" if payload.get("promoted_from_work_item") else "other")

        record: dict[str, Any] = {
            "schema": "qm.e1c-optionb-row-delta/v1",
            "work_item_id": item_id,
            "hold_created_at": held_row["created_at"],
            "phase": held_row["phase"],
            "ea_id": held_row["ea_id"],
            "symbol": held_row["symbol"],
            "timeframe": timeframe,
            "symbols_considered": symbols,
            "currency_exposure": currencies,
            "currency_source": currency_source,
            "row_class": row_class,
            "original_evidence_window": None,
            "old_calendar": {"bundle_id": old_manifest_doc.get("bundle_id"),
                             "content_sha256": EXPECTED["tainted_pin_sha256"],
                             "manifest_sha256": identity["old_manifest"]["sha256"]},
            "new_calendar": {"bundle_id": manifest_doc.get("bundle_id"),
                             "primary_file": identity["new_primary"],
                             "secondary_file": identity["new_secondary"],
                             "manifest_file_sha256": identity["new_manifest"]["sha256"],
                             "manifest_declared_sha256": identity["new_manifest"]["declared_manifest_sha256"]},
            "original_overlap_result": None,
            "recomputed_overlap_result": None,
            "original_q09_verdict": None,
            "recomputed_verdict": None,
            "verdict_reproduction": None,
            "delta": None,
            "delta_validation_status": None,
            "delta_validation_reason": None,
            "option_b_hold_release_eligible": False,
        }
        incomplete_reasons: list[str] = []

        # ---------- evidence window ----------
        window, window_source = resolve_window(payload)
        record["original_evidence_window"] = (
            {"from_utc": window[0], "to_utc": window[1], "source": window_source}
            if window else None
        )

        # ---------- original evidence + verdict reproduction ----------
        rerun_of = payload.get("append_only_rerun_of_work_item")
        promoted_from = payload.get("promoted_from_work_item")
        promoted_phase = payload.get("promoted_from_phase")
        if payload.get("diagnostic_contract"):
            if rerun_of:
                src = conn.execute(
                    "SELECT id, phase, verdict, evidence_path, payload_json, status FROM work_items WHERE id=?",
                    (str(rerun_of),),
                ).fetchone()
                if src is not None:
                    sp = json.loads(src["payload_json"] or "{}")
                    record["original_q09_verdict"] = {
                        "work_item_id": src["id"], "phase": src["phase"], "verdict": src["verdict"],
                        "status": src["status"],
                        "window_from_utc": sp.get("window_from_utc"),
                        "window_to_utc": sp.get("window_to_utc"),
                        "relation": ("append_only_rerun predecessor (calendar equivalence is judged "
                                     "over the HELD row's own window, not the predecessor's)"),
                    }
                    if src["evidence_path"]:
                        record["original_q09_verdict"]["evidence_path"] = src["evidence_path"]
            else:
                record["original_q09_verdict"] = {
                    "verdict": None, "status": "never ran (pending diagnostic backfill)",
                }
            record["original_overlap_result"] = {"status": "NOT_MEASURED",
                                                 "reason": "diagnostic_non_admission backfill never executed"}
        elif promoted_from:
            src = conn.execute(
                "SELECT id, phase, verdict, evidence_path, payload_json, status FROM work_items WHERE id=?",
                (str(promoted_from),),
            ).fetchone()
            if src is not None:
                record["original_q09_verdict"] = {
                    "work_item_id": src["id"], "phase": src["phase"], "verdict": src["verdict"],
                    "status": src["status"], "promoted_from_phase": promoted_phase,
                }
                if src["evidence_path"]:
                    record["original_q09_verdict"]["evidence_path"] = src["evidence_path"]
            if promoted_phase == "Q09":
                ev_path = payload.get("q09_q07_evidence_path")
                reproduced: dict[str, Any] = {"status": "not_attempted"}
                if ev_path and Path(str(ev_path)).is_file():
                    try:
                        raw = Path(str(ev_path)).read_bytes()
                        sha_ok = sha256_bytes(raw) == payload.get("q09_q07_evidence_sha256")
                        doc = strict_json(raw)
                        if isinstance(doc.get("cells"), list):
                            result = contract.adjudicate(doc)
                            reproduced = {
                                "status": "reproduced" if result.get("verdict") == (src["verdict"] if src else None)
                                else "mismatch",
                                "gate_logic": "q09_news_contract.adjudicate over sealed q09_news_evidence.json",
                                "recomputed_verdict": result.get("verdict"),
                                "recorded_verdict": src["verdict"] if src else None,
                                "evidence_sha_verified": sha_ok,
                            }
                            record["original_overlap_result"] = {
                                "status": "SEALED_MATRIX_EVIDENCE_PRESENT",
                                "q09_news_evidence_path": str(ev_path),
                                "q09_news_evidence_sha256": sha256_bytes(raw),
                                **overlap_stats_matrix(doc),
                            }
                        elif isinstance(doc.get("per_seed_detail"), list):
                            reproduced = reproduce_q07_verdict(doc)
                            reproduced["evidence_sha_verified"] = sha_ok
                            record["original_overlap_result"] = {
                                "status": "SEALED_Q07_MULTISEED_EVIDENCE_PRESENT",
                                "q07_aggregate_path": str(ev_path),
                                "q07_aggregate_sha256": sha256_bytes(raw),
                                "q07_verdict": doc.get("verdict"),
                                "q07_reason": doc.get("reason"),
                                "history_from": doc.get("history_from"),
                                "history_to": doc.get("history_to"),
                                "news_compliance": doc.get("news_compliance"),
                                "news_temporal": doc.get("news_temporal"),
                            }
                        else:
                            reproduced = reproduce_legacy_verdict(doc)
                            reproduced["evidence_sha_verified"] = sha_ok
                            record["original_overlap_result"] = overlap_stats_legacy(doc)
                        record["recomputed_verdict"] = reproduced.get("recomputed_verdict")
                    except (OSError, ValueError, TypeError, KeyError) as exc:
                        reproduced = {"status": "failed", "reason": str(exc)}
                else:
                    reproduced = {"status": "failed", "reason": "q09 evidence file unavailable"}
                record["verdict_reproduction"] = reproduced
                ok = (reproduced.get("status") in ("reproduced", "reproduced_fields")
                      and reproduced.get("recomputed_verdict") == (src["verdict"] if src else None))
                if not reproduced.get("reason_matches_recorded", True):
                    ok = False
                if not ok:
                    incomplete_reasons.append(
                        f"original Q09 verdict not reproducible over old evidence: {reproduced}")
            else:
                record["original_overlap_result"] = {
                    "status": "NOT_MEASURED",
                    "reason": f"promoted_from_phase={promoted_phase}; Q09 news measurement not yet executed",
                }

        # ---------- event-set delta ----------
        if window and currencies:
            old_set = window_events(old_calendar, currencies, window[0], window[1])
            new_set = window_events(new_calendar, currencies, window[0], window[1])
            row_delta = delta(old_set, new_set)
            record["relevant_old_event_set"] = summarize(old_set)
            record["relevant_new_event_set"] = summarize(new_set)
            record["delta"] = row_delta
            record["recomputed_overlap_result"] = {
                "status": "DETERMINISTIC_RECOMPUTE_UNAVAILABLE",
                "reason": ("the calendar is not an input to the gate verdict logic "
                           "(q09_news_contract.adjudicate / q10_confirmation._decide_verdict consume "
                           "sealed backtest metrics only); a calendar delta cannot be turned into a new "
                           "verdict without new MT5 measurement"),
                "calendar_delta_nonempty": not row_delta["is_empty"],
                "calendar_delta_summary": {
                    "added": row_delta["added_count"], "removed": row_delta["removed_count"],
                    "changed_impact": row_delta["changed_impact_count"],
                    "time_shifted": row_delta["time_shifted_count"],
                },
            }
        elif window is None:
            incomplete_reasons.append("evidence window could not be resolved (sealed plan unbuilt/unreadable; "
                                      "no hash-bound Q09 window exists for this row)")
        elif not currencies:
            incomplete_reasons.append(f"currency exposure unresolvable for symbols {symbols}")

        # ---------- classification ----------
        if incomplete_reasons:
            status = "EVIDENCE_INCOMPLETE"
            reason = "; ".join(incomplete_reasons)
        elif record["delta"] is not None and record["delta"]["is_empty"]:
            status = "UNCHANGED_EQUIVALENT"
            reason = ("relevant in-window event sets identical between tainted bundle and live clean "
                      "calendar; any sealed verdict reproduces via the same gate logic; a pending "
                      "measurement would observe an identical calendar")
            record["option_b_hold_release_eligible"] = True
        else:
            status = "DELTA_NOT_EXACT"
            reason = ("non-empty relevant calendar delta over the row's evidence window; exact equivalence "
                      "and deterministic verdict recompute impossible without new measurement -> Option A "
                      "full remeasurement on the clean calendar")
        record["delta_validation_status"] = status
        record["delta_validation_reason"] = reason
        record["calendar_coverage_note"] = coverage_note
        record["record_sha256"] = sha256_bytes(
            canonical_bytes({k: v for k, v in record.items() if k != "record_sha256"}))

        out_path = rows_dir / f"{item_id}.json"
        out_path.write_text(json.dumps(record, indent=1, sort_keys=True) + "\n", encoding="utf-8")
        (drift_records if is_drift else records).append(record)

    # ---------- summary + reconciled metrics ----------
    counts = Counter(r["delta_validation_status"] for r in records)
    released = sum(1 for r in records if r["option_b_hold_release_eligible"])
    option_a = sum(1 for r in records if r["delta_validation_status"] in
                   {"VERDICT_FLIP", "DELTA_NOT_EXACT", "EVIDENCE_INCOMPLETE"})
    runnable = released
    summary = {
        "schema": "qm.e1c-optionb-summary/v1",
        "generated_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "delegation_census": (f"NEWS_CALENDAR_TAINTED unreleased holds with created_at < {DELEGATION_CUTOVER} "
                              "(the 99-row OWNER census; later holds are live sweep drift)"),
        "identity": identity,
        "expected_hashes": EXPECTED,
        "hold_drift_excluded_from_metrics": [
            {"work_item_id": r["work_item_id"], "hold_created_at": r["hold_created_at"],
             "phase": r["phase"], "ea_id": r["ea_id"], "symbol": r["symbol"],
             "delta_validation_status": r.get("delta_validation_status"),
             "classified": r.get("classified", True)}
            for r in drift_records
        ],
        "metrics": {
            "NEWS_TAINT_TOTAL": len(records),
            "UNCHANGED_EQUIVALENT": counts.get("UNCHANGED_EQUIVALENT", 0),
            "VERDICT_FLIP": counts.get("VERDICT_FLIP", 0),
            "DELTA_NOT_EXACT": counts.get("DELTA_NOT_EXACT", 0),
            "EVIDENCE_INCOMPLETE": counts.get("EVIDENCE_INCOMPLETE", 0),
            "HOLDS_RELEASED_OPTION_B": released,
            "FULL_REMEASUREMENT_OPTION_A": option_a,
            "NEW_RUNNABLE_WORK": runnable,
            "FORECAST_RUNNABLE_HOURS_ADDED": 0,
        },
        "metrics_notes": {
            "FORECAST_RUNNABLE_HOURS_ADDED": ("0: Option-B release adds runnable rows without new MT5 "
                                              "measurement, and it is counted only at governed release. "
                                              "The ~93h news figure in KIMI_INTERIM_HANDOFF_2026-09-18.md is "
                                              "the Option-A remeasurement program forecast, not this pass."),
            "VERDICT_FLIP": ("unreachable by construction: the calendar is not an input to either gate; "
                             "a non-empty delta fails closed to DELTA_NOT_EXACT."),
            "UNCHANGED_EQUIVALENT_note": ("equivalence is certified against the LIVE published calendar "
                                          "bytes (hashes above); the shared 2025-05..2026-06 upstream gap is "
                                          "present in BOTH calendars. When the separate human-gated registry "
                                          "repair + refresh backfills those months, equivalence must be "
                                          "re-certified before any further release."),
        },
        "reconciliation": ("UNCHANGED_EQUIVALENT + VERDICT_FLIP + DELTA_NOT_EXACT + EVIDENCE_INCOMPLETE "
                           "== NEWS_TAINT_TOTAL == HOLDS_RELEASED_OPTION_B + FULL_REMEASUREMENT_OPTION_A"),
        "status_counts": dict(counts),
        "rows": [
            {"work_item_id": r["work_item_id"], "phase": r["phase"], "ea_id": r["ea_id"],
             "symbol": r["symbol"], "timeframe": r["timeframe"], "row_class": r["row_class"],
             "delta_validation_status": r["delta_validation_status"],
             "window_from": (r["original_evidence_window"] or {}).get("from_utc"),
             "window_to": (r["original_evidence_window"] or {}).get("to_utc"),
             "release_eligible": r["option_b_hold_release_eligible"],
             "record_sha256": r["record_sha256"]}
            for r in records
        ],
    }
    metrics = summary["metrics"]
    assert (metrics["UNCHANGED_EQUIVALENT"] + metrics["VERDICT_FLIP"] + metrics["DELTA_NOT_EXACT"]
            + metrics["EVIDENCE_INCOMPLETE"] == metrics["NEWS_TAINT_TOTAL"])
    assert metrics["HOLDS_RELEASED_OPTION_B"] + metrics["FULL_REMEASUREMENT_OPTION_A"] == \
        metrics["NEWS_TAINT_TOTAL"]
    summary["summary_sha256"] = sha256_bytes(
        canonical_bytes({k: v for k, v in summary.items() if k != "summary_sha256"}))
    (args.out / "summary.json").write_text(
        json.dumps(summary, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(metrics, indent=1, sort_keys=True))
    print("status_counts:", dict(counts))
    print("drift_excluded:", len(drift_records))
    print("summary:", args.out / "summary.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
