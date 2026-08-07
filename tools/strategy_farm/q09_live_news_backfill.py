#!/usr/bin/env python3
"""Plan, enqueue, and inspect the OWNER-requested live-book Q09 diagnostic.

This lane deliberately reuses the sealed Q09 7x1 execution machinery while
remaining outside canonical Q09 admission storage.  It reads T_Live artifacts,
never modifies them, stages either the exact deployed EX5 or an explicitly
hash-bound current rebuild through the resident terminal worker, and constrains
execution to T1-T5.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import sys
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Sequence


HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import farmctl  # noqa: E402
import q09_news_contract as contract  # noqa: E402
import q09_news_runner as q09  # noqa: E402


CAMPAIGN_ID = "q09-live-news-backfill-20260805-v1"
ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\q09_live_news_backfill_20260805")
FARM_ROOT = Path(r"D:\QM\strategy_farm")
T_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
PRESET_ROOT = T_LIVE_ROOT / "MQL5" / "Presets"
LIVE_EXPERT_ROOT = T_LIVE_ROOT / "MQL5" / "Experts" / "Live EAs"
PROFILE_ROOT = T_LIVE_ROOT / "MQL5" / "Profiles" / "Charts" / "DarwinexZero_V2_LiveOps"
LIVE_PULSE = Path(r"D:\QM\reports\state\live_book_pulse.json")
CALENDAR_MANIFEST = Path(
    r"D:\QM\data\news_calendar\q09_bundles"
    r"\q09cal-20150101-20260809-0bb19b5bb9790b76\manifest.json"
)
CALENDAR_COMMON_PATH = (
    "QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv"
)
ALLOWED_TERMINALS = ("T1", "T2", "T3", "T4", "T5")
AVOID_TERMINALS = ("T6", "T7", "T8", "T9", "T10")
INDEX_SYMBOLS = frozenset({"NDX", "SP500", "GDAXI"})
NEWS_SCOPING_FIX_UTC = datetime(2026, 7, 5, 11, 43, tzinfo=timezone.utc)
SYMBOL_SLOT_CONSTRUCTOR_FIX_UTC = datetime(2026, 7, 6, 12, 7, tzinfo=timezone.utc)
FRESH_BUILD_GENERATION = 2
FRESH_BUILD_QUEUE_OFFSET = -100
AUTHENTICATED_RERUN_SPAWN_REFUSAL_REASONS = frozenset({
    "worker_staged_ex5_destination_path_mismatch",
})


@dataclass(frozen=True)
class Sleeve:
    rank: int
    ea_id: int
    symbol: str
    period: str
    preset_name: str
    weight: float | None = None

    @property
    def ea_key(self) -> str:
        return f"QM5_{self.ea_id}"

    @property
    def symbol_dwx(self) -> str:
        return f"{self.symbol}.DWX"

    @property
    def key(self) -> str:
        return f"{self.ea_key}/{self.symbol}"

    @property
    def work_item_id(self) -> str:
        return str(uuid.uuid5(uuid.NAMESPACE_URL, f"quantmechanica:{CAMPAIGN_ID}:{self.key}"))


SLEEVES = (
    Sleeve(1, 12567, "XNGUSD", "D1", "23_XNGUSD_D1_QM5_12567_cum-rsi2-commodity.set", 0.98),
    Sleeve(2, 10919, "XTIUSD", "H4", "04_XTIUSD_H4_QM5_10919_grimes-overshoot.set", 0.92),
    Sleeve(3, 12567, "XAUUSD", "D1", "20_XAUUSD_D1_QM5_12567_cum-rsi2-commodity.set", 0.75),
    Sleeve(4, 1556, "XAUUSD", "D1", "22_XAUUSD_D1_QM5_1556_aa-zak-mom12.set", 0.60),
    Sleeve(5, 11165, "AUDCAD", "H1", "05_AUDCAD_H1_QM5_11165_weiss-rsi-ma.set"),
    Sleeve(6, 11708, "EURUSD", "D1", "10_EURUSD_D1_QM5_11708_anon-market-squeeze-d1.set"),
    Sleeve(7, 11132, "SP500", "D1", "16_SP500_D1_QM5_11132_tm-cum-rsi2.set"),
    Sleeve(8, 11165, "EURUSD", "H1", "08_EURUSD_H1_QM5_11165_weiss-rsi-ma.set"),
    Sleeve(9, 11421, "AUDUSD", "D1", "07_AUDUSD_D1_QM5_11421_ohlc-daily-squeeze-reversal-d1.set"),
    Sleeve(10, 11421, "EURUSD", "D1", "09_EURUSD_D1_QM5_11421_ohlc-daily-squeeze-reversal-d1.set"),
    Sleeve(11, 10513, "XAUUSD", "D1", "19_XAUUSD_D1_QM5_10513_mql5-ichimoku.set"),
    Sleeve(12, 12989, "XAUUSD", "H4", "21_XAUUSD_H4_QM5_12989_grimes-nested-pb-v2.set"),
    Sleeve(13, 10403, "XAUUSD", "D1", "18_XAUUSD_D1_QM5_10403_et-turtle20x.set"),
    Sleeve(14, 10939, "GBPUSD", "H4", "12_GBPUSD_H4_QM5_10939_grimes-context-pb.set"),
    Sleeve(15, 10911, "GDAXI", "H1", "13_GDAXI_H1_QM5_10911_grimes-complex-pb.set"),
    Sleeve(16, 10706, "GBPUSD", "H1", "11_GBPUSD_H1_QM5_10706_tv-mon-ls.set"),
    Sleeve(17, 10440, "NDX", "H1", "15_NDX_H1_QM5_10440_mql5-ohlc-mtf.set"),
)


class BackfillError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def write_immutable(path: Path, data: bytes) -> None:
    if path.exists():
        if not path.is_file() or path.read_bytes() != data:
            raise BackfillError(f"immutable artifact contradiction: {path}")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(path)


def write_status(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(canonical_bytes(value))
    temporary.replace(path)


def normalize_launch_not_before_utc(value: str | None) -> str | None:
    if value is None or not value.strip():
        return None
    try:
        parsed = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError as exc:
        raise BackfillError("rerun launch-not-before timestamp is invalid") from exc
    if parsed.tzinfo is None:
        raise BackfillError("rerun launch-not-before timestamp is not timezone-aware")
    return parsed.astimezone(timezone.utc).isoformat()


def binding_launch_hold(now: datetime, launch_not_before_utc: str | None) -> str:
    hold = now + timedelta(minutes=5)
    if launch_not_before_utc is not None:
        scheduled = datetime.fromisoformat(launch_not_before_utc)
        hold = max(hold, scheduled)
    return hold.isoformat()


def decode_text(path: Path) -> tuple[str, str, bytes]:
    return q09._decode_setfile(path.read_bytes())


def live_ex5_for(sleeve: Sleeve) -> Path:
    matches = sorted(LIVE_EXPERT_ROOT.glob(f"{sleeve.ea_key}_*.ex5"))
    if len(matches) != 1:
        raise BackfillError(f"{sleeve.key}: expected one deployed EX5, found {len(matches)}")
    return matches[0].resolve()


def ea_source_for(ex5: Path) -> Path:
    ea_dir = REPO_ROOT / "framework" / "EAs" / ex5.stem
    mq5 = ea_dir / f"{ex5.stem}.mq5"
    if not mq5.is_file():
        raise BackfillError(f"EA source missing for deployed label: {mq5}")
    return mq5.resolve()


def chart_snapshot(sleeve: Sleeve, ex5: Path) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []
    for chart in sorted(PROFILE_ROOT.glob("chart*.chr")):
        text, _, _ = decode_text(chart)
        symbol_match = re.search(r"(?m)^symbol=(.+)$", text)
        expert_match = re.search(r"(?ms)<expert>\s*\nname=(.+?)\r?\n.*?<inputs>\s*\n(.*?)</inputs>", text)
        if not symbol_match or not expert_match:
            continue
        symbol = symbol_match.group(1).strip().split(".", 1)[0].upper()
        expert_name = expert_match.group(1).strip()
        if symbol != sleeve.symbol or expert_name != ex5.stem:
            continue
        inputs: dict[str, str] = {}
        for line in expert_match.group(2).splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                inputs[key.strip()] = value.strip()
        matches.append({
            "chart_path": str(chart.resolve()),
            "chart_sha256": sha256_file(chart),
            "expert_name": expert_name,
            "symbol": symbol,
            "effective_inputs": inputs,
        })
    if len(matches) != 1:
        raise BackfillError(f"{sleeve.key}: expected one loaded chart, found {len(matches)}")
    snapshot = matches[0]
    inputs = snapshot["effective_inputs"]
    required = {
        "qm_news_temporal": "3",
        "qm_news_compliance": "1",
        "qm_news_min_impact": "high",
    }
    for key, expected in required.items():
        if inputs.get(key, "").lower() != expected:
            raise BackfillError(f"{sleeve.key}: loaded {key}={inputs.get(key)!r}, expected {expected!r}")
    try:
        stale_hours = int(inputs.get("qm_news_stale_max_hours", "-1"))
    except ValueError as exc:
        raise BackfillError(f"{sleeve.key}: loaded stale-hours value is invalid") from exc
    if stale_hours < 1 or stale_hours > 336:
        raise BackfillError(f"{sleeve.key}: loaded stale-hours exceeds fail-closed guardrail")
    return snapshot


def q07_seed_stability(connection: sqlite3.Connection, sleeve: Sleeve) -> dict[str, Any]:
    row = connection.execute(
        """
        SELECT id,status,verdict,evidence_path,updated_at FROM work_items
        WHERE ea_id=? AND symbol IN (?,?) AND phase='Q07' AND status='done'
          AND verdict IN ('PASS','MULTI_SEED_PASS')
        ORDER BY updated_at DESC LIMIT 1
        """,
        (sleeve.ea_key, sleeve.symbol, sleeve.symbol_dwx),
    ).fetchone()
    if row is None:
        raise BackfillError(f"{sleeve.key}: no completed Q07 seed-stability PASS")
    evidence_path = Path(str(row["evidence_path"] or "")).resolve()
    evidence_source = "WORK_ITEM_EVIDENCE"
    if not evidence_path.is_file():
        # Some pre-archival-discipline Q07 rows point at a volatile work-item
        # copy that has since been pruned.  The runner also published the same
        # adjudication to the durable pipeline tree.  Use it only after checking
        # the exact EA/symbol/phase/verdict; never substitute a sibling symbol.
        candidates = (
            Path(r"D:\QM\reports\q07_rerun_20260725")
            / f"{sleeve.ea_id}_{sleeve.symbol}_DWX"
            / sleeve.ea_key / "Q07" / f"{sleeve.symbol}_DWX" / "aggregate.json",
            Path(r"D:\QM\reports\pipeline") / sleeve.ea_key / "Q07" / "aggregate.json",
        )
        exact_fallback: Path | None = None
        for fallback in candidates:
            if not fallback.is_file():
                continue
            document = json.loads(fallback.read_text(encoding="utf-8-sig"))
            if (
                str(document.get("phase") or "").upper() == "Q07"
                and str(document.get("verdict") or "").upper() in {"PASS", "MULTI_SEED_PASS"}
                and str(document.get("symbol") or document.get("runner_symbol") or "")
                .split(".", 1)[0].upper() == sleeve.symbol
                and int(document.get("ea_id") or -1) == sleeve.ea_id
            ):
                exact_fallback = fallback.resolve()
                break
        if exact_fallback is None:
            raise BackfillError(f"{sleeve.key}: no exact durable Q07 PASS fallback")
        evidence_path = exact_fallback
        evidence_source = "DURABLE_PIPELINE_FALLBACK"
    result = {
        "work_item_id": str(row["id"]),
        "verdict": str(row["verdict"]),
        "evidence_path": str(evidence_path),
        "evidence_sha256": sha256_file(evidence_path),
        "updated_at": str(row["updated_at"]),
    }
    if evidence_source != "WORK_ITEM_EVIDENCE":
        result["evidence_source"] = evidence_source
    return result


def derived_baseline(source: Path, destination: Path) -> dict[str, Any]:
    source_before = source.read_bytes()
    text, encoding, bom = q09._decode_setfile(source_before)
    updated = q09._replace_set_values(
        text,
        {
            "RISK_FIXED": "1000",
            "RISK_PERCENT": "0",
            "qm_filter_news_enabled": "0",
            "qm_filter_news_mode": "0",
            "qm_news_mode_legacy": "0",
            "qm_news_temporal": "0",
            "qm_news_compliance": "0",
            "qm_news_stale_max_hours": "336",
            "qm_news_min_impact": "high",
        },
    )
    write_immutable(destination, bom + updated.encode(encoding))
    if source.read_bytes() != source_before:
        raise BackfillError(f"T_Live source preset changed during derivation: {source}")
    values = q09._setfile_values(destination)
    if float(values.get("risk_fixed", "0")) != 1000 or float(values.get("risk_percent", "-1")) != 0:
        raise BackfillError("derived diagnostic baseline violates risk guardrails")
    if float(values.get("qm_news_stale_max_hours", "337")) > 336:
        raise BackfillError("derived diagnostic baseline weakens stale-news guardrail")
    if values.get("qm_filter_news_enabled") != "0" or values.get("qm_filter_news_mode") != "0":
        raise BackfillError("derived diagnostic baseline did not neutralize legacy news inputs")
    return {
        "source_path": str(source.resolve()),
        "source_sha256": hashlib.sha256(source_before).hexdigest(),
        "derived_path": str(destination.resolve()),
        "derived_sha256": sha256_file(destination),
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "legacy_control_neutralized": True,
    }


def generation_assessment(sleeve: Sleeve, ex5: Path, mq5: Path) -> dict[str, Any]:
    built_utc = datetime.fromtimestamp(ex5.stat().st_mtime, tz=timezone.utc)
    source = mq5.read_text(encoding="utf-8-sig", errors="replace")
    has_explicit_slot = bool(re.search(r"\.symbol_slot\s*=", source))
    if has_explicit_slot:
        slot_status = "UNAFFECTED_EXPLICIT_SYMBOL_SLOT_ASSIGNMENT"
    elif built_utc >= SYMBOL_SLOT_CONSTRUCTOR_FIX_UTC:
        slot_status = "POST_DEFAULT_CONSTRUCTOR_FIX_GENERATION"
    else:
        slot_status = "PRE_FIX_GENERATION_NOT_PROVEN_SAFE"
    if sleeve.symbol not in INDEX_SYMBOLS:
        scoping_status = "NOT_APPLICABLE_SIX_CHAR_OR_FX_SYMBOL"
    elif built_utc >= NEWS_SCOPING_FIX_UTC:
        scoping_status = "POST_89963ff75_INDEX_SCOPING_GENERATION"
    else:
        scoping_status = "PRE_89963ff75_INDEX_SCOPING_DEFECT_PRESENT"
    return {
        "deployed_ex5_mtime_utc": built_utc.isoformat(),
        "news_index_scoping_status": scoping_status,
        "symbol_slot_status": slot_status,
        "current_source_explicit_symbol_slot_assignment": has_explicit_slot,
        "classification_basis": "deployed EX5 timestamp plus current EA source; exact hash retained",
    }


def validate_live_pulse() -> dict[str, Any]:
    if not LIVE_PULSE.is_file():
        raise BackfillError(f"live-book pulse missing: {LIVE_PULSE}")
    pulse = json.loads(LIVE_PULSE.read_text(encoding="utf-8-sig"))
    reconcile = pulse.get("manifest_reconcile") or {}
    journals = pulse.get("terminal_journals") or {}
    baselines = pulse.get("kill_switch_baselines") or {}
    if int(reconcile.get("expected_count") or 0) != 24:
        raise BackfillError("T_Live pulse does not declare the 24-sleeve book")
    missing = reconcile.get("missing_loaded") or []
    mismatch = reconcile.get("mismatch_count", 0)
    if missing or int(mismatch or 0) != 0 or int(journals.get("loaded_sleeve_count") or 0) != 24:
        raise BackfillError("T_Live pulse is not 24/24 clean")
    serialized = canonical_bytes(pulse)
    return {
        "path": str(LIVE_PULSE.resolve()),
        "sha256": hashlib.sha256(LIVE_PULSE.read_bytes()).hexdigest(),
        "expected_count": 24,
        "missing_loaded": missing,
        "mismatch": int(mismatch or 0),
        "qm5_10440_reconciled": True,
        "qm5_10440_reconciliation": (
            "actual terminal/profile state is loaded 24/24; the separate 23/24 alarm "
            "is kill-switch baseline coverage, missing 10440|NDX"
        ),
        "kill_switch_loaded_ok": int(baselines.get("loaded_ok") or 0),
        "kill_switch_missing_files": baselines.get("missing_files") or [],
        "snapshot_digest": hashlib.sha256(serialized).hexdigest(),
        "generated_at": pulse.get("generated_at") or pulse.get("generated_at_utc"),
    }


def prepare_campaign(task_id: str) -> dict[str, Any]:
    if not task_id.strip():
        raise BackfillError("router task id is required")
    pulse = validate_live_pulse()
    calendar_bundle = json.loads(CALENDAR_MANIFEST.read_text(encoding="utf-8"))
    if calendar_bundle.get("bundle_id") != "q09cal-20150101-20260809-0bb19b5bb9790b76":
        raise BackfillError("required calendar bundle is not present")
    rows: list[dict[str, Any]] = []
    with farmctl.connect(FARM_ROOT) as connection:
        for sleeve in SLEEVES:
            preset = (PRESET_ROOT / sleeve.preset_name).resolve()
            if not preset.is_file():
                raise BackfillError(f"T_Live preset missing: {preset}")
            ex5 = live_ex5_for(sleeve)
            mq5 = ea_source_for(ex5)
            chart = chart_snapshot(sleeve, ex5)
            q07 = q07_seed_stability(connection, sleeve)
            sleeve_root = ARTIFACT_ROOT / f"{sleeve.rank:02d}_{sleeve.ea_key}_{sleeve.symbol}"
            baseline_path = sleeve_root / "baseline" / "live_derived_diagnostic.set"
            baseline = derived_baseline(preset, baseline_path)
            assessment = generation_assessment(sleeve, ex5, mq5)
            closure_path = sleeve_root / "diagnostic_include_assessment.json"
            closure = {
                "schema_version": "q09-live-news-diagnostic-include-assessment/v1",
                "diagnostic_non_admission": True,
                "ea_id": sleeve.ea_key,
                "symbol": sleeve.symbol_dwx,
                "deployed_ex5": {"path": str(ex5), "sha256": sha256_file(ex5)},
                "current_ea_source": {"path": str(mq5), "sha256": sha256_file(mq5)},
                "framework_news_filter": {
                    "path": str((REPO_ROOT / "framework/include/QM/QM_NewsFilter.mqh").resolve()),
                    "sha256": sha256_file(REPO_ROOT / "framework/include/QM/QM_NewsFilter.mqh"),
                    "index_scoping_fix_commit": "89963ff75",
                },
                "generation_assessment": assessment,
            }
            write_immutable(closure_path, canonical_bytes(closure))
            anchor_path = sleeve_root / "diagnostic_anchor.json"
            anchor = {
                "schema_version": q09.DIAGNOSTIC_ANCHOR_SCHEMA,
                "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
                "diagnostic_non_admission": True,
                "campaign_id": CAMPAIGN_ID,
                "router_task_id": task_id,
                "anchor_id": f"diagnostic-anchor:{CAMPAIGN_ID}:{sleeve.key}",
                "work_item_id": sleeve.work_item_id,
                "ea_id": sleeve.ea_key,
                "symbol": sleeve.symbol_dwx,
                "period": sleeve.period,
                "queue_rank": sleeve.rank,
                "live_weight": sleeve.weight,
                "live_source_preset": {
                    "path": str(preset), "sha256": sha256_file(preset), "read_only": True,
                },
                "derived_baseline": baseline,
                "baseline_run": {
                    "period": sleeve.period,
                    "baseline_setfile_path": str(baseline_path.resolve()),
                    "baseline_setfile_sha256": sha256_file(baseline_path),
                    "baseline_ex5_sha256": sha256_file(ex5),
                },
                "deployed_ex5": {"path": str(ex5), "sha256": sha256_file(ex5)},
                "loaded_chart": chart,
                "mapped_current_live_mode": {
                    "temporal_mode_id": 3,
                    "temporal_mode": "PRE30_POST30",
                    "compliance_mode_id": 1,
                    "compliance_mode": "DXZ",
                    "min_impact": "HIGH",
                },
                "generation_assessment": assessment,
                "q07_seed_stability": q07,
                "diagnostic_include_assessment": {
                    "path": str(closure_path.resolve()), "sha256": sha256_file(closure_path),
                },
                "calendar_bundle_id": calendar_bundle["bundle_id"],
                "allowed_terminals": list(ALLOWED_TERMINALS),
                "avoid_terminals": list(AVOID_TERMINALS),
            }
            write_immutable(anchor_path, canonical_bytes(anchor))
            plan = q09.build_run_plan(
                work_item_id=sleeve.work_item_id,
                candidate_lineage_key=sha256_file(anchor_path),
                deployment_target="DXZ",
                q08_work_item_id=anchor["anchor_id"],
                q08_evidence_path=anchor_path,
                baseline_setfile_path=baseline_path,
                ex5_path=ex5,
                include_closure_path=closure_path,
                calendar_manifest_path=CALENDAR_MANIFEST,
                calendar_common_relative_path=CALENDAR_COMMON_PATH,
                full_from_utc="2019-01-01T00:00:00Z",
                full_to_utc="2025-12-31T23:59:59Z",
                selection_from_utc="2019-01-01T00:00:00Z",
                selection_to_utc="2023-12-31T23:59:59Z",
                holdout_from_utc="2024-01-01T00:00:00Z",
                holdout_to_utc="2025-12-31T23:59:59Z",
                complete_months=60,
                holdout_complete_months=24,
                tester_model="REAL_TICKS",
                cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
                output_root=sleeve_root / "q09_plan",
            )
            if int(plan["cell_count"]) != 40:
                raise BackfillError(f"{sleeve.key}: plan is not 40 cells")
            rows.append({
                "rank": sleeve.rank,
                "ea_id": sleeve.ea_key,
                "symbol": sleeve.symbol_dwx,
                "period": sleeve.period,
                "weight": sleeve.weight,
                "work_item_id": sleeve.work_item_id,
                "baseline_setfile_path": str(baseline_path.resolve()),
                "baseline_setfile_sha256": sha256_file(baseline_path),
                "live_preset_path": str(preset),
                "live_preset_sha256": sha256_file(preset),
                "deployed_ex5_path": str(ex5),
                "deployed_ex5_sha256": sha256_file(ex5),
                "anchor_path": str(anchor_path.resolve()),
                "anchor_sha256": sha256_file(anchor_path),
                "run_plan_path": str(Path(plan["plan_path"]).resolve()),
                "run_plan_file_sha256": sha256_file(Path(plan["plan_path"])),
                "run_plan_sha256": plan["plan_sha256"],
                "cell_count": 40,
                "generation_assessment": assessment,
                "q07_seed_stability": q07,
            })
    campaign = {
        "schema_version": "q09-live-news-backfill-plan/v1",
        "campaign_id": CAMPAIGN_ID,
        "router_task_id": task_id,
        "diagnostic_non_admission": True,
        "t_live_read_only": True,
        "t_live_pulse": pulse,
        "calendar_bundle": {
            "bundle_id": calendar_bundle["bundle_id"],
            "manifest_path": str(CALENDAR_MANIFEST.resolve()),
            "manifest_sha256": sha256_file(CALENDAR_MANIFEST),
        },
        "tester_model": "REAL_TICKS",
        "matrix": "7x1_DXZ_40_cells_per_sleeve",
        "seeds": list(contract.SEEDS),
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "avoid_terminals": list(AVOID_TERMINALS),
        "max_simultaneous_diagnostics": 5,
        "sleeves": rows,
    }
    plan_path = ARTIFACT_ROOT / "campaign_plan.json"
    write_immutable(plan_path, canonical_bytes(campaign))
    return {**campaign, "campaign_plan_path": str(plan_path.resolve()), "campaign_plan_sha256": sha256_file(plan_path)}


def enqueue_campaign(campaign: dict[str, Any]) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat()
    inserted: list[str] = []
    existing: list[str] = []
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        for row in campaign["sleeves"]:
            current = connection.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (row["work_item_id"],)
            ).fetchone()
            if current is not None:
                payload = json.loads(current["payload_json"] or "{}")
                if payload.get("diagnostic_campaign_id") != CAMPAIGN_ID:
                    raise BackfillError(f"work-item UUID collision: {row['work_item_id']}")
                existing.append(row["work_item_id"])
                continue
            payload = {
                "diagnostic_non_admission": True,
                "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
                "diagnostic_campaign_id": CAMPAIGN_ID,
                "diagnostic_queue_rank": int(row["rank"]),
                "diagnostic_live_weight": row["weight"],
                "diagnostic_anchor_path": row["anchor_path"],
                "diagnostic_anchor_sha256": row["anchor_sha256"],
                "diagnostic_control": "legacy_and_two_axis_news_inputs_neutralized",
                "priority_track": True,
                "host_symbol": row["symbol"],
                "host_timeframe": row["period"],
                "risk_fixed": 1000.0,
                "risk_percent": 0.0,
                "staged_ex5_path": row["deployed_ex5_path"],
                "staged_ex5_sha256": row["deployed_ex5_sha256"],
                "avoid_terminals": list(AVOID_TERMINALS),
                "diagnostic_allowed_terminals": list(ALLOWED_TERMINALS),
                "diagnostic_concurrency_cap": 5,
                "protected_chain_exclusion": [
                    "9fabcddb-8c2e-4b01-9295-4ef4dbb6892d", "Q09_PORTFOLIO", "Q10"
                ],
                "router_task_id": campaign["router_task_id"],
            }
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', 'Q09_NEWS', ?, ?, ?, 'pending', NULL,
                         0, NULL, NULL, NULL, ?, ?, ?)
                """,
                (
                    row["work_item_id"], row["ea_id"], row["symbol"],
                    row["baseline_setfile_path"], json.dumps(payload, sort_keys=True), now, now,
                ),
            )
            inserted.append(row["work_item_id"])
        connection.commit()

    bound: list[dict[str, Any]] = []
    with farmctl.connect(FARM_ROOT) as connection:
        states = {
            str(row["id"]): (str(row["status"]), json.loads(row["payload_json"] or "{}"))
            for row in connection.execute(
                "SELECT id,status,payload_json FROM work_items WHERE id IN (%s)"
                % ",".join("?" for _ in campaign["sleeves"]),
                tuple(row["work_item_id"] for row in campaign["sleeves"]),
            )
        }
    for row in campaign["sleeves"]:
        status, payload = states[row["work_item_id"]]
        if payload.get("q09_dispatch_binding_sha256"):
            continue
        if status != "pending":
            raise BackfillError(f"unbound diagnostic row is not pending: {row['work_item_id']} ({status})")
        bound.append(q09.bind_diagnostic_plan_to_work_item(
            FARM_ROOT,
            work_item_id=row["work_item_id"],
            plan_path=Path(row["run_plan_path"]),
            expected_plan_file_sha256=row["run_plan_file_sha256"],
            cell_timeout_sec=q09.DEFAULT_CELL_TIMEOUT_SEC,
        ))
    receipt = {
        "schema_version": "q09-live-news-backfill-enqueue-receipt/v1",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "inserted_work_item_ids": inserted,
        "preexisting_work_item_ids": existing,
        "newly_bound": [item["work_item_id"] for item in bound],
        "work_item_ids": [row["work_item_id"] for row in campaign["sleeves"]],
        "count": len(campaign["sleeves"]),
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "max_simultaneous_diagnostics": 5,
        "enqueued_at_utc": now,
    }
    receipt_path = ARTIFACT_ROOT / "enqueue_receipt.json"
    write_immutable(receipt_path, canonical_bytes(receipt))
    receipt["receipt_path"] = str(receipt_path.resolve())
    receipt["receipt_sha256"] = sha256_file(receipt_path)
    return receipt


def append_only_rerun_id(predecessor_id: str, task_id: str) -> str:
    """Return the stable identity for one router-authorized diagnostic rerun."""

    return str(uuid.uuid5(
        uuid.NAMESPACE_URL,
        f"quantmechanica:{CAMPAIGN_ID}:rerun:{predecessor_id}:{task_id}",
    ))


def transient_generation_rerun_id(predecessor_id: str, task_id: str) -> str:
    """Return the stable identity for a sealed-identity generation rerun."""

    return str(uuid.uuid5(
        uuid.NAMESPACE_URL,
        (
            f"quantmechanica:{CAMPAIGN_ID}:transient-generation-rerun/v1:"
            f"{predecessor_id}:{task_id}"
        ),
    ))


def _row_value(row: sqlite3.Row | dict[str, Any], key: str) -> Any:
    try:
        return row[key]
    except (IndexError, KeyError):
        return None


def _authenticated_spawn_refusal(
    connection: sqlite3.Connection,
    predecessor: sqlite3.Row | dict[str, Any],
    payload: dict[str, Any],
    *,
    farm_root: Path,
) -> dict[str, str] | None:
    """Authenticate one exact, atomically recorded runner spawn refusal.

    A payload timestamp is not evidence.  The structured payload must agree
    with the terminal work-item row and with the durable
    ``runner_spawn_refused`` event written by
    :func:`farmctl.record_work_item_spawn_refusal` in the same transaction.
    """

    refusal = payload.get("spawn_refusal")
    if not isinstance(refusal, dict):
        return None
    reason = str(refusal.get("reason") or "")
    if reason not in AUTHENTICATED_RERUN_SPAWN_REFUSAL_REASONS:
        return None

    predecessor_id = str(_row_value(predecessor, "id") or "")
    terminal = str(refusal.get("terminal") or "").upper()
    phase = str(refusal.get("phase") or "")
    failed_at = str(refusal.get("failed_at_utc") or "")
    if (
        not predecessor_id
        or _row_value(predecessor, "status") != "failed"
        or _row_value(predecessor, "verdict") != "INFRA_FAIL"
        or str(_row_value(predecessor, "phase") or "") != "Q09_NEWS"
        or phase != "Q09_NEWS"
        or terminal not in ALLOWED_TERMINALS
        or not failed_at
        or str(_row_value(predecessor, "updated_at") or "") != failed_at
        or str(_row_value(predecessor, "claimed_by") or "").strip()
        or payload.get("verdict_reason") != reason
        or refusal.get("phase_runner_scope_blocked") is not False
    ):
        raise BackfillError(
            "generation rerun spawn refusal contradicts terminal work-item state"
        )
    try:
        parsed_failed_at = datetime.fromisoformat(failed_at.replace("Z", "+00:00"))
    except ValueError as exc:
        raise BackfillError(
            "generation rerun spawn refusal timestamp is invalid"
        ) from exc
    if parsed_failed_at.tzinfo is None:
        raise BackfillError(
            "generation rerun spawn refusal timestamp is not timezone-aware"
        )

    event_rows = connection.execute(
        """
        SELECT id,ts,entity_type,entity_id,event,detail_json
        FROM events
        WHERE entity_type='work_item' AND entity_id=?
          AND event='runner_spawn_refused'
        ORDER BY id
        """,
        (predecessor_id,),
    ).fetchall()
    if len(event_rows) != 1:
        raise BackfillError(
            "generation rerun spawn refusal lacks one durable refusal event"
        )
    event_row = event_rows[0]
    try:
        event_detail = json.loads(event_row["detail_json"] or "{}")
    except (TypeError, json.JSONDecodeError) as exc:
        raise BackfillError(
            "generation rerun spawn refusal event is malformed"
        ) from exc
    if event_detail != refusal:
        raise BackfillError(
            "generation rerun spawn refusal event contradicts payload"
        )

    event_record = {
        "id": int(event_row["id"]),
        "ts": str(event_row["ts"]),
        "entity_type": str(event_row["entity_type"]),
        "entity_id": str(event_row["entity_id"]),
        "event": str(event_row["event"]),
        "detail": event_detail,
    }
    event_record_sha256 = hashlib.sha256(canonical_bytes(event_record)).hexdigest()
    database_path = (farm_root / farmctl.DB_REL).resolve()
    return {
        "path": f"{database_path}#events/{event_row['id']}",
        "sha256": event_record_sha256,
        "error_type": "SpawnRefusal",
        "error": reason,
        "run_identity_sha256": "",
        "proof_kind": "authenticated_runner_spawn_refusal",
        "refusal_event_id": str(event_row["id"]),
        "refusal_terminal": terminal,
        "refusal_failed_at_utc": failed_at,
        "refusal_phase": phase,
    }


def _transient_generation_failure_proof(
    predecessor: sqlite3.Row,
    payload: dict[str, Any],
    plan: dict[str, Any],
    *,
    spawn_refusal_proof: dict[str, str] | None = None,
) -> list[dict[str, str]]:
    """Authenticate a terminal pre-fix transient/no-receipt diagnostic stop."""

    if (
        payload.get("diagnostic_non_admission") is not True
        or payload.get("diagnostic_campaign_id") != CAMPAIGN_ID
        or int(payload.get("diagnostic_generation") or 0) < FRESH_BUILD_GENERATION
    ):
        raise BackfillError(
            "generation rerun predecessor is not a terminal generation-2+ diagnostic"
        )
    if spawn_refusal_proof is not None:
        return [spawn_refusal_proof]
    evidence_path = Path(str(predecessor["evidence_path"] or ""))
    if not evidence_path.is_file():
        raise BackfillError("generation rerun predecessor summary is missing")

    if predecessor["status"] == "failed" and predecessor["verdict"] == "INFRA_FAIL":
        preflight = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
        payload_failure = payload.get("preflight_failure") or {}
        detail = str(preflight.get("detail") or "")
        match = re.fullmatch(r"staged_ex5_source_sha256_mismatch:([0-9a-f]{64})", detail)
        if (
            preflight.get("verdict") != "INFRA_FAIL"
            or preflight.get("reason") != "staged_ex5_preflight_failed"
            or preflight.get("phase") != "Q09_NEWS"
            or str(preflight.get("ea_id") or "") != str(predecessor["ea_id"])
            or str(preflight.get("symbol") or "") != str(predecessor["symbol"])
            or payload_failure.get("reason") != preflight.get("reason")
            or payload_failure.get("detail") != detail
            or match is None
        ):
            raise BackfillError(
                "generation rerun INFRA_FAIL lacks authenticated EX5-drift preflight evidence"
            )
        return [{
            "path": str(evidence_path.resolve()),
            "sha256": sha256_file(evidence_path),
            "error_type": "PreflightFailure",
            "error": detail,
            "run_identity_sha256": "",
            "proof_kind": "mutable_staged_ex5_source_drift",
        }]

    if (
        predecessor["status"] != "done"
        or predecessor["verdict"] != "REVIEW_REQUIRED"
    ):
        raise BackfillError(
            "generation rerun predecessor is not a supported terminal diagnostic"
        )
    summary = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    if (
        summary.get("schema_version") != "q09-live-news-diagnostic-summary/v1"
        or summary.get("diagnostic_non_admission") is not True
        or summary.get("diagnostic_contract") != q09.DIAGNOSTIC_CONTRACT
        or str(summary.get("work_item_id") or "") != str(predecessor["id"])
    ):
        raise BackfillError("generation rerun predecessor summary is contradictory")

    failures: list[dict[str, str]] = []
    for cell in plan.get("cells", []):
        cell_root = Path(str(cell.get("receipt_path") or "")).resolve().parent
        if (cell_root / "cell_receipt.json").is_file():
            continue
        for failure_path in sorted(cell_root.glob("cell_failure*.json")):
            failure = json.loads(failure_path.read_text(encoding="utf-8-sig"))
            error_type = str(failure.get("error_type") or "")
            error = str(failure.get("error") or "")
            proof_kind = ""
            supporting_summary: dict[str, str] | None = None
            exit_one_match = re.match(
                r"^Q09 (selection|holdout|full) run_smoke exited with code 1(?:\b| )",
                error,
            )
            if (
                error_type in {"RunnerError", "TransientCellError"}
                and exit_one_match is not None
            ):
                failed_window = exit_one_match.group(1)
                declared_summaries: list[dict[str, Any]] = []
                authenticated_summaries: list[tuple[Path, str, dict[str, Any]]] = []
                for artifact in failure.get("artifacts", []):
                    if not isinstance(artifact, dict):
                        continue
                    relative_path = str(artifact.get("relative_path") or "").replace("\\", "/")
                    if (
                        f"runs/{failed_window}/" not in relative_path
                        or not relative_path.endswith("/summary.json")
                    ):
                        continue
                    declared_summaries.append(artifact)
                    summary_path = Path(str(artifact.get("path") or "")).resolve()
                    try:
                        summary_path.relative_to(cell_root)
                    except ValueError:
                        continue
                    expected_summary_hash = str(artifact.get("sha256") or "").lower()
                    if (
                        not summary_path.is_file()
                        or sha256_file(summary_path) != expected_summary_hash
                    ):
                        continue
                    authenticated_summaries.append((
                        summary_path,
                        expected_summary_hash,
                        json.loads(summary_path.read_text(encoding="utf-8-sig")),
                    ))

                if not declared_summaries:
                    proof_kind = "child_exit_1_without_receipt"
                elif len(authenticated_summaries) == 1:
                    summary_path, expected_summary_hash, run_summary = authenticated_summaries[0]
                    try:
                        ok_run = q09._single_ok_run(run_summary)
                        min_trades = int(run_summary.get("min_trades_required"))
                        actual_trades = int(ok_run.get("total_trades"))
                    except (q09.RunnerError, TypeError, ValueError):
                        pass
                    else:
                        identity = run_summary.get("execution_identity")
                        if (
                            run_summary.get("result") == "FAIL"
                            and run_summary.get("reason_classes") == ["MIN_TRADES_NOT_MET"]
                            and run_summary.get("requested_runs") == 1
                            and run_summary.get("deterministic") is True
                            and run_summary.get("oninit_failure_detected") is False
                            and isinstance(identity, dict)
                            and identity.get("stable_during_run") is True
                            and min_trades > actual_trades >= 0
                        ):
                            proof_kind = "diagnostic_min_trades_floor_misapplied"
                            supporting_summary = {
                                "supporting_summary_path": str(summary_path),
                                "supporting_summary_sha256": expected_summary_hash,
                                "min_trades_required": str(min_trades),
                                "actual_trades": str(actual_trades),
                            }
            elif (
                error_type == "RunnerError"
                and error == "run_smoke did not publish exactly one authenticated OK run"
            ):
                for artifact in failure.get("artifacts", []):
                    if not isinstance(artifact, dict):
                        continue
                    relative_path = str(artifact.get("relative_path") or "")
                    if not relative_path.replace("\\", "/").endswith("/summary.json"):
                        continue
                    summary_path = Path(str(artifact.get("path") or "")).resolve()
                    try:
                        summary_path.relative_to(cell_root)
                    except ValueError:
                        continue
                    expected_summary_hash = str(artifact.get("sha256") or "").lower()
                    if (
                        not summary_path.is_file()
                        or sha256_file(summary_path) != expected_summary_hash
                    ):
                        continue
                    run_summary = json.loads(
                        summary_path.read_text(encoding="utf-8-sig")
                    )
                    runs = run_summary.get("runs")
                    if (
                        run_summary.get("result") == "PASS"
                        and isinstance(runs, list)
                        and len(runs) > 1
                    ):
                        try:
                            q09._single_ok_run(run_summary)
                        except q09.RunnerError:
                            continue
                        proof_kind = "one_ok_after_invalid_startup_attempt"
                        supporting_summary = {
                            "supporting_summary_path": str(summary_path),
                            "supporting_summary_sha256": expected_summary_hash,
                        }
                        break
            if proof_kind:
                failures.append({
                    "path": str(failure_path),
                    "sha256": sha256_file(failure_path),
                    "error_type": error_type,
                    "error": error,
                    "run_identity_sha256": str(cell.get("run_identity_sha256") or ""),
                    "proof_kind": proof_kind,
                    **(supporting_summary or {}),
                })
    if not failures:
        raise BackfillError(
            "generation rerun predecessor has no authenticated transient/no-receipt failure"
        )
    return failures


def _cell_identity_tuple(cell: dict[str, Any]) -> tuple[Any, ...]:
    return tuple(cell.get(key) for key in (
        "run_identity_sha256",
        "setfile_sha256",
        "arm",
        "compliance_mode",
        "temporal_mode",
        "seed",
        "paired_base_identity_sha256",
    ))


def _generation_ex5_vintage(
    payload: dict[str, Any],
) -> tuple[Path, dict[str, Any] | None]:
    """Resolve the exact EX5 vintage without rewriting a mutable build path.

    Generation reruns preserve the predecessor's cell identities, including its
    EX5 hash.  A later canonical rebuild may legitimately move the mutable source
    path to a new hash.  In that case only an already-recorded staging destination
    from the predecessor payload may recover the sealed vintage, and it must hash
    exactly to the predecessor binding.
    """

    expected = str(payload.get("staged_ex5_sha256") or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise BackfillError("generation rerun predecessor EX5 hash is invalid")
    primary = Path(str(payload.get("staged_ex5_path") or "")).resolve()
    if primary.is_file() and sha256_file(primary) == expected:
        return primary, None

    staged = payload.get("staged_ex5")
    candidate_raw = staged.get("destination_path") if isinstance(staged, dict) else None
    if not candidate_raw:
        raise BackfillError(
            "generation rerun predecessor EX5 source drifted and has no recorded vintage"
        )
    candidate = Path(str(candidate_raw)).resolve()
    if not candidate.is_file() or sha256_file(candidate) != expected:
        raise BackfillError(
            "generation rerun recorded EX5 vintage is missing or hash-mismatched"
        )
    observed = sha256_file(primary) if primary.is_file() else None
    return candidate, {
        "reason": "mutable_source_path_drift",
        "original_path": str(primary),
        "original_observed_sha256": observed,
        "recovered_from": str(candidate),
        "required_sha256": expected,
    }


def enqueue_transient_generation_rerun(
    *,
    task_id: str,
    predecessor_id: str,
    avoid_terminal: str,
    launch_not_before_utc: str | None = None,
) -> dict[str, Any]:
    """Append a generation-3+ rerun of a pre-fix transient diagnostic stop."""

    launch_not_before_utc = normalize_launch_not_before_utc(
        launch_not_before_utc
    )
    new_id = transient_generation_rerun_id(predecessor_id, task_id)
    with farmctl.connect(FARM_ROOT) as connection:
        predecessor = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (predecessor_id,)
        ).fetchone()
        if predecessor is None:
            raise BackfillError("generation rerun predecessor does not exist")
        payload = json.loads(predecessor["payload_json"] or "{}")
        spawn_refusal_proof = _authenticated_spawn_refusal(
            connection,
            predecessor,
            payload,
            farm_root=FARM_ROOT,
        )
    predecessor_terminal = (
        str(spawn_refusal_proof["refusal_terminal"])
        if spawn_refusal_proof is not None
        else str(payload.get("terminal") or "").upper()
    )
    if predecessor_terminal != avoid_terminal:
        raise BackfillError(
            "generation rerun avoidance does not match predecessor terminal evidence"
        )
    # The requested terminal is only a consistency check.  The actual steering
    # value is always drawn from authenticated predecessor evidence.
    avoid_terminal = predecessor_terminal
    plan_path = Path(str(payload.get("q09_run_plan_path") or "")).resolve()
    expected_plan_hash = str(payload.get("q09_run_plan_file_sha256") or "").lower()
    source_ex5_path, source_vintage_recovery = _generation_ex5_vintage(payload)
    plan, input_manifest = q09.load_authenticated_plan(
        plan_path,
        expected_file_sha256=expected_plan_hash,
        source_path_overrides={"ex5": source_ex5_path},
    )
    if (
        str(input_manifest["identities"]["ex5_sha256"]).lower()
        != str(payload["staged_ex5_sha256"]).lower()
    ):
        raise BackfillError("generation rerun EX5 payload/manifest hash mismatch")
    failures = _transient_generation_failure_proof(
        predecessor,
        payload,
        plan,
        spawn_refusal_proof=spawn_refusal_proof,
    )
    if int(plan.get("cell_count") or 0) != 40:
        raise BackfillError("generation rerun predecessor is not the sealed 40-cell matrix")
    if predecessor["claimed_by"]:
        raise BackfillError("generation rerun predecessor still has an active claim")

    generation = int(payload["diagnostic_generation"]) + 1
    rerun_root = ARTIFACT_ROOT / f"refresh_v{generation}" / new_id
    receipt_path = rerun_root / "enqueue_receipt.json"
    if receipt_path.is_file():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if (
            receipt.get("work_item_id") != new_id
            or receipt.get("rerun_of") != predecessor_id
            or int(receipt.get("diagnostic_generation") or 0) != generation
            or receipt.get("launch_not_before_utc") != launch_not_before_utc
        ):
            raise BackfillError(
                f"generation rerun receipt contradicts request: {receipt_path}"
            )
        return {
            **receipt,
            "receipt_path": str(receipt_path.resolve()),
            "receipt_sha256": sha256_file(receipt_path),
            "idempotent": True,
        }

    pinned_ex5_path = source_ex5_path
    if source_vintage_recovery is not None:
        pinned_ex5_path = rerun_root / "source_vintage" / source_ex5_path.name
        write_immutable(pinned_ex5_path, source_ex5_path.read_bytes())
        if sha256_file(pinned_ex5_path) != str(payload["staged_ex5_sha256"]).lower():
            raise BackfillError("immutable recovered EX5 vintage hash mismatch")
        source_vintage_recovery = {
            **source_vintage_recovery,
            "immutable_path": str(pinned_ex5_path.resolve()),
        }

    source_anchor_path = Path(str(payload.get("diagnostic_anchor_path") or "")).resolve()
    if sha256_file(source_anchor_path) != str(
        payload.get("diagnostic_anchor_sha256") or ""
    ).lower():
        raise BackfillError("generation rerun predecessor anchor hash changed")
    sealed_anchor_work_item_id = str(
        payload.get("sealed_identity_anchor_work_item_id") or predecessor_id
    )
    if (
        int(payload.get("diagnostic_generation") or 0) > FRESH_BUILD_GENERATION
        and payload.get("sealed_identity_rerun") is not True
    ):
        raise BackfillError("later-generation rerun lacks sealed anchor lineage")
    anchor = json.loads(source_anchor_path.read_text(encoding="utf-8-sig"))
    if (
        anchor.get("schema_version") != q09.DIAGNOSTIC_ANCHOR_SCHEMA
        or anchor.get("diagnostic_contract") != q09.DIAGNOSTIC_CONTRACT
        or anchor.get("diagnostic_non_admission") is not True
        or str(anchor.get("work_item_id") or "") != sealed_anchor_work_item_id
    ):
        raise BackfillError("generation rerun predecessor anchor is contradictory")

    sources = input_manifest["source_paths"]
    windows = input_manifest["windows"]
    rerun_plan = q09.build_run_plan(
        work_item_id=new_id,
        candidate_lineage_key=str(plan["candidate_lineage_key"]),
        deployment_target=str(input_manifest["target_compliance"]),
        q08_work_item_id=str(input_manifest["identities"]["q08_work_item_id"]),
        # The anchor hash is part of every sealed cell identity.  Reuse the
        # exact predecessor anchor and carry append-only lineage in the new
        # work-item payload; rewriting the anchor would define a new matrix.
        q08_evidence_path=source_anchor_path,
        baseline_setfile_path=Path(str(sources["baseline_setfile"])),
        ex5_path=pinned_ex5_path,
        include_closure_path=Path(str(sources["include_closure"])),
        calendar_manifest_path=Path(str(sources["calendar_manifest"])),
        calendar_common_relative_path=str(
            input_manifest["calendar_bundle"]["common_relative_path"]
        ),
        full_from_utc=str(windows["full_from_utc"]),
        full_to_utc=str(windows["full_to_utc"]),
        selection_from_utc=str(windows["selection_from_utc"]),
        selection_to_utc=str(windows["selection_to_utc"]),
        holdout_from_utc=str(windows["holdout_from_utc"]),
        holdout_to_utc=str(windows["holdout_to_utc"]),
        complete_months=int(windows["complete_months"]),
        holdout_complete_months=int(windows["holdout_complete_months"]),
        tester_model=str(input_manifest["tester_model"]),
        cost_profile=str(input_manifest["cost_profile"]),
        output_root=rerun_root / "q09_plan",
        news_or_event_strategy=bool(input_manifest.get("news_or_event_strategy")),
        force_expanded_matrix=str(plan.get("matrix_scope")) == "7x4",
    )
    predecessor_identities = [_cell_identity_tuple(cell) for cell in plan["cells"]]
    rerun_identities = [_cell_identity_tuple(cell) for cell in rerun_plan["cells"]]
    if rerun_identities != predecessor_identities:
        raise BackfillError("generation rerun changed sealed ordered cell identities")
    rerun_plan_path = Path(str(rerun_plan["plan_path"])).resolve()
    rerun_plan_file_sha256 = sha256_file(rerun_plan_path)

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    launch_hold = binding_launch_hold(now, launch_not_before_utc)
    rerun_payload = {
        "diagnostic_non_admission": True,
        "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
        "diagnostic_campaign_id": CAMPAIGN_ID,
        "diagnostic_generation": generation,
        "diagnostic_queue_rank": int(payload["diagnostic_queue_rank"])
        + FRESH_BUILD_QUEUE_OFFSET,
        "diagnostic_source_rank": int(payload["diagnostic_source_rank"]),
        "diagnostic_live_weight": payload.get("diagnostic_live_weight"),
        "diagnostic_anchor_path": str(source_anchor_path),
        "diagnostic_anchor_sha256": sha256_file(source_anchor_path),
        "diagnostic_control": str(payload["diagnostic_control"]),
        "priority_track": True,
        "host_symbol": str(payload["host_symbol"]),
        "host_timeframe": str(payload["host_timeframe"]),
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "staged_ex5_path": str(pinned_ex5_path.resolve()),
        "staged_ex5_sha256": str(payload["staged_ex5_sha256"]),
        "fresh_build_source_path": payload.get("fresh_build_source_path"),
        "fresh_build_source_sha256": payload.get("fresh_build_source_sha256"),
        "avoid_terminals": list(AVOID_TERMINALS),
        "diagnostic_allowed_terminals": list(ALLOWED_TERMINALS),
        "diagnostic_concurrency_cap": 5,
        "protected_chain_exclusion": list(payload["protected_chain_exclusion"]),
        "router_task_id": task_id,
        "rerun_of": predecessor_id,
        "rerun_avoid_terminal": avoid_terminal,
        "sealed_identity_rerun": True,
        "sealed_identity_anchor_work_item_id": sealed_anchor_work_item_id,
        "sealed_identity_anchor_sha256": sha256_file(source_anchor_path),
        "transient_predecessor_failures": failures,
        "source_vintage_recovery": source_vintage_recovery,
        # Prevent a claim between the binder commit and retry steering update.
        "launch_not_before_utc": launch_hold,
    }
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        if connection.execute(
            "SELECT 1 FROM q09_news_tests WHERE work_item_id IN (?,?) LIMIT 1",
            (predecessor_id, new_id),
        ).fetchone() is not None:
            raise BackfillError("generation rerun conflicts with canonical Q09 evidence")
        existing = connection.execute(
            "SELECT status,payload_json FROM work_items WHERE id=?", (new_id,)
        ).fetchone()
        if existing is None:
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', 'Q09_NEWS', ?, ?, ?, 'pending', NULL,
                         0, ?, NULL, NULL, ?, ?, ?)
                """,
                (
                    new_id,
                    predecessor["ea_id"],
                    predecessor["symbol"],
                    predecessor["setfile_path"],
                    predecessor_id,
                    json.dumps(rerun_payload, sort_keys=True),
                    now_iso,
                    now_iso,
                ),
            )
        else:
            existing_payload = json.loads(existing["payload_json"] or "{}")
            if (
                existing_payload.get("rerun_of") != predecessor_id
                or int(existing_payload.get("diagnostic_generation") or 0) != generation
            ):
                raise BackfillError("existing generation rerun row is contradictory")
        connection.commit()

    bound = q09.bind_diagnostic_plan_to_work_item(
        FARM_ROOT,
        work_item_id=new_id,
        plan_path=rerun_plan_path,
        expected_plan_file_sha256=rerun_plan_file_sha256,
        cell_timeout_sec=q09.DEFAULT_CELL_TIMEOUT_SEC,
    )
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute(
            "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?",
            (new_id,),
        ).fetchone()
        if row is None or row["status"] != "pending" or str(row["claimed_by"] or "").strip():
            raise BackfillError("generation rerun was claimed before retry steering completed")
        bound_payload = json.loads(row["payload_json"] or "{}")
        avoided = {str(value).upper() for value in bound_payload.get("avoid_terminals", [])}
        avoided.add(avoid_terminal)
        bound_payload["avoid_terminals"] = sorted(avoided)
        if launch_not_before_utc is None:
            bound_payload.pop("launch_not_before_utc", None)
        else:
            bound_payload["launch_not_before_utc"] = launch_not_before_utc
        bound_payload["rerun_steered_at_utc"] = datetime.now(timezone.utc).isoformat()
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (json.dumps(bound_payload, sort_keys=True), now_iso, new_id),
        )
        connection.commit()
    receipt = {
        "schema_version": "q09-live-news-transient-generation-rerun-receipt/v1",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "diagnostic_generation": generation,
        "router_task_id": task_id,
        "work_item_id": new_id,
        "rerun_of": predecessor_id,
        "status": "pending",
        "avoid_terminal": avoid_terminal,
        "launch_not_before_utc": launch_not_before_utc,
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "ordered_cell_identities_equal": True,
        "cell_count": len(rerun_identities),
        "predecessor_plan_path": str(plan_path),
        "predecessor_plan_file_sha256": expected_plan_hash,
        "plan_path": str(rerun_plan_path),
        "plan_file_sha256": rerun_plan_file_sha256,
        "plan_sha256": rerun_plan["plan_sha256"],
        "input_manifest_sha256": rerun_plan["input_manifest_sha256"],
        "anchor_path": str(source_anchor_path),
        "anchor_sha256": sha256_file(source_anchor_path),
        "sealed_identity_anchor_work_item_id": sealed_anchor_work_item_id,
        "transient_predecessor_failures": failures,
        "source_vintage_recovery": source_vintage_recovery,
        "binding": bound,
        "enqueued_at_utc": now_iso,
    }
    write_immutable(receipt_path, canonical_bytes(receipt))
    return {
        **receipt,
        "receipt_path": str(receipt_path.resolve()),
        "receipt_sha256": sha256_file(receipt_path),
    }


def enqueue_append_only_rerun(
    *,
    task_id: str,
    predecessor_id: str,
    avoid_terminal: str,
    launch_not_before_utc: str | None = None,
) -> dict[str, Any]:
    """Append a fresh diagnostic row while leaving its failed predecessor intact."""

    task_id = task_id.strip()
    predecessor_id = predecessor_id.strip()
    avoid_terminal = avoid_terminal.strip().upper()
    if not task_id or not predecessor_id:
        raise BackfillError("router task id and predecessor id are required")
    if avoid_terminal not in ALLOWED_TERMINALS:
        raise BackfillError("rerun avoidance must name one of T1-T5")
    launch_not_before_utc = normalize_launch_not_before_utc(
        launch_not_before_utc
    )

    with farmctl.connect(FARM_ROOT) as connection:
        generation_row = connection.execute(
            "SELECT payload_json FROM work_items WHERE id=?", (predecessor_id,)
        ).fetchone()
    if generation_row is not None:
        generation_payload = json.loads(generation_row["payload_json"] or "{}")
        if int(generation_payload.get("diagnostic_generation") or 0) >= 2:
            return enqueue_transient_generation_rerun(
                task_id=task_id,
                predecessor_id=predecessor_id,
                avoid_terminal=avoid_terminal,
                launch_not_before_utc=launch_not_before_utc,
            )

    campaign_path = ARTIFACT_ROOT / "campaign_plan.json"
    if not campaign_path.is_file():
        raise BackfillError(f"campaign plan is missing: {campaign_path}")
    campaign = json.loads(campaign_path.read_text(encoding="utf-8"))
    if (
        campaign.get("schema_version") != "q09-live-news-backfill-plan/v1"
        or campaign.get("campaign_id") != CAMPAIGN_ID
        or campaign.get("diagnostic_non_admission") is not True
    ):
        raise BackfillError("campaign plan contract is missing or contradictory")
    matches = [
        row for row in campaign.get("sleeves", [])
        if str(row.get("work_item_id")) == predecessor_id
    ]
    if len(matches) != 1:
        raise BackfillError("predecessor is not exactly one sealed campaign sleeve")
    source = matches[0]
    new_id = append_only_rerun_id(predecessor_id, task_id)
    rerun_root = ARTIFACT_ROOT / "reruns" / new_id

    source_anchor_path = Path(str(source["anchor_path"])).resolve()
    if sha256_file(source_anchor_path) != str(source["anchor_sha256"]).lower():
        raise BackfillError("predecessor diagnostic anchor hash changed")
    anchor = json.loads(source_anchor_path.read_text(encoding="utf-8"))
    if (
        anchor.get("schema_version") != q09.DIAGNOSTIC_ANCHOR_SCHEMA
        or anchor.get("diagnostic_contract") != q09.DIAGNOSTIC_CONTRACT
        or anchor.get("diagnostic_non_admission") is not True
        or str(anchor.get("work_item_id")) != predecessor_id
    ):
        raise BackfillError("predecessor diagnostic anchor is contradictory")
    anchor["work_item_id"] = new_id
    anchor["router_task_id"] = task_id
    anchor["rerun_of"] = predecessor_id
    anchor["source_anchor"] = {
        "path": str(source_anchor_path),
        "sha256": sha256_file(source_anchor_path),
    }
    anchor["loaded_chart_evidence_status"] = (
        "NON_PROCESS_ANCHORED_NOT_AUTHORITATIVE; runtime policy basis is "
        "live-preset omission plus compiled source defaults"
    )
    rerun_anchor_path = rerun_root / "diagnostic_anchor.json"
    write_immutable(rerun_anchor_path, canonical_bytes(anchor))

    baseline_path = Path(str(source["baseline_setfile_path"])).resolve()
    ex5_path = Path(str(source["deployed_ex5_path"])).resolve()
    if sha256_file(baseline_path) != str(source["baseline_setfile_sha256"]).lower():
        raise BackfillError("sealed diagnostic baseline changed")
    if sha256_file(ex5_path) != str(source["deployed_ex5_sha256"]).lower():
        raise BackfillError("deployed live EX5 changed")
    include_path = Path(str(
        (anchor.get("diagnostic_include_assessment") or {}).get("path") or ""
    )).resolve()
    if not include_path.is_file():
        raise BackfillError("diagnostic include assessment is missing")

    plan = q09.build_run_plan(
        work_item_id=new_id,
        candidate_lineage_key=sha256_file(rerun_anchor_path),
        deployment_target="DXZ",
        q08_work_item_id=str(anchor["anchor_id"]),
        q08_evidence_path=rerun_anchor_path,
        baseline_setfile_path=baseline_path,
        ex5_path=ex5_path,
        include_closure_path=include_path,
        calendar_manifest_path=CALENDAR_MANIFEST,
        calendar_common_relative_path=CALENDAR_COMMON_PATH,
        full_from_utc="2019-01-01T00:00:00Z",
        full_to_utc="2025-12-31T23:59:59Z",
        selection_from_utc="2019-01-01T00:00:00Z",
        selection_to_utc="2023-12-31T23:59:59Z",
        holdout_from_utc="2024-01-01T00:00:00Z",
        holdout_to_utc="2025-12-31T23:59:59Z",
        complete_months=60,
        holdout_complete_months=24,
        tester_model="REAL_TICKS",
        cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
        output_root=rerun_root / "q09_plan",
    )
    if int(plan.get("cell_count") or 0) != 40:
        raise BackfillError("rerun plan is not the sealed 40-cell matrix")
    plan_path = Path(str(plan["plan_path"])).resolve()
    plan_file_sha256 = sha256_file(plan_path)

    now = datetime.now(timezone.utc)
    now_iso = now.isoformat()
    launch_hold = binding_launch_hold(now, launch_not_before_utc)
    payload = {
        "diagnostic_non_admission": True,
        "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
        "diagnostic_campaign_id": CAMPAIGN_ID,
        "diagnostic_queue_rank": int(source["rank"]),
        "diagnostic_live_weight": source.get("weight"),
        "diagnostic_anchor_path": str(rerun_anchor_path.resolve()),
        "diagnostic_anchor_sha256": sha256_file(rerun_anchor_path),
        "diagnostic_control": "legacy_and_two_axis_news_inputs_neutralized",
        "priority_track": True,
        "host_symbol": source["symbol"],
        "host_timeframe": source["period"],
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "staged_ex5_path": str(ex5_path),
        "staged_ex5_sha256": sha256_file(ex5_path),
        "avoid_terminals": list(AVOID_TERMINALS),
        "diagnostic_allowed_terminals": list(ALLOWED_TERMINALS),
        "diagnostic_concurrency_cap": 5,
        "protected_chain_exclusion": [
            "9fabcddb-8c2e-4b01-9295-4ef4dbb6892d", "Q09_PORTFOLIO", "Q10"
        ],
        "router_task_id": task_id,
        "rerun_of": predecessor_id,
        "rerun_avoid_terminal": avoid_terminal,
        # Prevent a worker from claiming in the narrow interval between the
        # binder's commit and the post-bind dynamic retry-steering update.
        "launch_not_before_utc": launch_hold,
    }
    predecessor_infrastructure_proof: dict[str, str] | None = None
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        predecessor = connection.execute(
            "SELECT * FROM work_items WHERE id=?",
            (predecessor_id,),
        ).fetchone()
        if predecessor is None:
            raise BackfillError("rerun predecessor does not exist")
        predecessor_payload = json.loads(predecessor["payload_json"] or "{}")
        if (
            predecessor["status"] != "failed"
            or predecessor["verdict"] != "INFRA_FAIL"
            or predecessor_payload.get("diagnostic_campaign_id") != CAMPAIGN_ID
        ):
            raise BackfillError("rerun predecessor is not the failed campaign diagnostic")
        predecessor_infrastructure_proof = _authenticated_spawn_refusal(
            connection,
            predecessor,
            predecessor_payload,
            farm_root=FARM_ROOT,
        )
        predecessor_terminal = (
            str(predecessor_infrastructure_proof["refusal_terminal"])
            if predecessor_infrastructure_proof is not None
            else str(
                predecessor_payload.get("last_launch_fault_terminal") or ""
            ).upper()
        )
        if predecessor_terminal != avoid_terminal:
            raise BackfillError("requested avoidance does not match predecessor launch-fault evidence")
        # The requested terminal is only a consistency check.  The actual
        # steering value comes from authenticated predecessor evidence.
        avoid_terminal = predecessor_terminal
        if predecessor_infrastructure_proof is not None:
            payload["predecessor_infrastructure_proof"] = (
                predecessor_infrastructure_proof
            )
        if connection.execute(
            "SELECT 1 FROM q09_news_tests WHERE work_item_id IN (?,?) LIMIT 1",
            (predecessor_id, new_id),
        ).fetchone() is not None:
            raise BackfillError("diagnostic rerun would conflict with canonical Q09 evidence")
        if connection.execute(
            "SELECT 1 FROM work_items WHERE id=?", (new_id,)
        ).fetchone() is not None:
            raise BackfillError(f"append-only rerun already exists: {new_id}")
        connection.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,
                payload_json,created_at,updated_at
            ) VALUES(?, 'backtest', 'Q09_NEWS', ?, ?, ?, 'pending', NULL,
                     0, ?, NULL, NULL, ?, ?, ?)
            """,
            (
                new_id, source["ea_id"], source["symbol"], str(baseline_path),
                predecessor_id, json.dumps(payload, sort_keys=True), now_iso, now_iso,
            ),
        )
        connection.commit()

    bound = q09.bind_diagnostic_plan_to_work_item(
        FARM_ROOT,
        work_item_id=new_id,
        plan_path=plan_path,
        expected_plan_file_sha256=plan_file_sha256,
        cell_timeout_sec=q09.DEFAULT_CELL_TIMEOUT_SEC,
    )
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        row = connection.execute(
            "SELECT status,claimed_by,payload_json FROM work_items WHERE id=?", (new_id,)
        ).fetchone()
        if row is None or row["status"] != "pending" or str(row["claimed_by"] or "").strip():
            raise BackfillError("rerun was claimed before retry steering completed")
        bound_payload = json.loads(row["payload_json"] or "{}")
        avoided = {str(value).upper() for value in bound_payload.get("avoid_terminals", [])}
        avoided.add(avoid_terminal)
        bound_payload["avoid_terminals"] = sorted(avoided)
        if launch_not_before_utc is None:
            bound_payload.pop("launch_not_before_utc", None)
        else:
            bound_payload["launch_not_before_utc"] = launch_not_before_utc
        bound_payload["rerun_steered_at_utc"] = datetime.now(timezone.utc).isoformat()
        connection.execute(
            "UPDATE work_items SET payload_json=?,updated_at=? WHERE id=?",
            (json.dumps(bound_payload, sort_keys=True), now_iso, new_id),
        )
        connection.commit()

    receipt = {
        "schema_version": "q09-live-news-append-only-rerun-receipt/v1",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "router_task_id": task_id,
        "work_item_id": new_id,
        "rerun_of": predecessor_id,
        "status": "pending",
        "avoid_terminal": avoid_terminal,
        "launch_not_before_utc": launch_not_before_utc,
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "baseline_setfile_path": str(baseline_path),
        "baseline_setfile_sha256": sha256_file(baseline_path),
        "deployed_ex5_path": str(ex5_path),
        "deployed_ex5_sha256": sha256_file(ex5_path),
        "calendar_manifest_path": str(CALENDAR_MANIFEST.resolve()),
        "calendar_manifest_sha256": sha256_file(CALENDAR_MANIFEST),
        "source_anchor_path": str(source_anchor_path),
        "source_anchor_sha256": sha256_file(source_anchor_path),
        "rerun_anchor_path": str(rerun_anchor_path.resolve()),
        "rerun_anchor_sha256": sha256_file(rerun_anchor_path),
        "plan_path": str(plan_path),
        "plan_file_sha256": plan_file_sha256,
        "plan_sha256": plan["plan_sha256"],
        "input_manifest_sha256": plan["input_manifest_sha256"],
        "cell_count": 40,
        "seeds": list(contract.SEEDS),
        "enqueued_at_utc": now_iso,
        "binding": bound,
    }
    if predecessor_infrastructure_proof is not None:
        receipt["predecessor_infrastructure_proof"] = (
            predecessor_infrastructure_proof
        )
    receipt_path = rerun_root / "enqueue_receipt.json"
    write_immutable(receipt_path, canonical_bytes(receipt))
    return {
        **receipt,
        "receipt_path": str(receipt_path.resolve()),
        "receipt_sha256": sha256_file(receipt_path),
    }


def fresh_build_rerun_id(
    predecessor_id: str,
    task_id: str,
    fresh_ex5_sha256: str,
) -> str:
    """Return the stable identity for one generation-2 fresh-build diagnostic."""

    return str(uuid.uuid5(
        uuid.NAMESPACE_URL,
        (
            f"quantmechanica:{CAMPAIGN_ID}:fresh-v2:{predecessor_id}:"
            f"{task_id}:{fresh_ex5_sha256.lower()}"
        ),
    ))


def _fresh_build_source_assessment(ex5_path: Path, ea_id: str) -> dict[str, Any]:
    """Authenticate the narrow current-V5 source refresh behind a fresh EX5."""

    if not ex5_path.is_file() or ex5_path.suffix.lower() != ".ex5":
        raise BackfillError(f"fresh EX5 is missing: {ex5_path}")
    if not ex5_path.stem.startswith(f"{ea_id}_"):
        raise BackfillError(
            f"fresh EX5 label {ex5_path.stem!r} does not match {ea_id}"
        )
    mq5_path = ea_source_for(ex5_path)
    text = mq5_path.read_text(encoding="utf-8-sig", errors="strict")
    first_statement = re.search(
        r"void\s+OnTick\s*\(\s*\)\s*\{\s*"
        r"(?:(?://[^\r\n]*(?:\r?\n|$))\s*)*"
        r"QM_FrameworkTrackOpenPositionMae\s*\(\s*\)\s*;",
        text,
    )
    if first_statement is None:
        raise BackfillError(
            f"{ea_id}: QM_FrameworkTrackOpenPositionMae is not the first OnTick statement"
        )
    if len(re.findall(r"QM_FrameworkTrackOpenPositionMae\s*\(", text)) != 1:
        raise BackfillError(f"{ea_id}: Q08 MAE hook count is not exactly one")
    for declaration in (
        r"input\s+QM_NewsTemporalMode\s+qm_news_temporal\b",
        r"input\s+QM_NewsComplianceProfile\s+qm_news_compliance\b",
        r"input\s+string\s+qm_news_min_impact\b",
    ):
        if re.search(declaration, text) is None:
            raise BackfillError(f"{ea_id}: current two-axis news interface is incomplete")
    stale_match = re.search(
        r"input\s+int\s+qm_news_stale_max_hours\s*=\s*(\d+)\s*;",
        text,
    )
    if stale_match is None:
        raise BackfillError(f"{ea_id}: fail-closed news stale ceiling is missing")
    stale_hours = int(stale_match.group(1))
    if stale_hours < 1 or stale_hours > 336:
        raise BackfillError(f"{ea_id}: news stale ceiling violates the 336-hour guardrail")
    return {
        "mq5_path": str(mq5_path),
        "mq5_sha256": sha256_file(mq5_path),
        "ex5_path": str(ex5_path.resolve()),
        "ex5_sha256": sha256_file(ex5_path),
        "ex5_mtime_utc": datetime.fromtimestamp(
            ex5_path.stat().st_mtime, timezone.utc
        ).isoformat(),
        "q08_mae_first_statement": True,
        "q08_mae_hook_count": 1,
        "news_temporal_input": True,
        "news_compliance_input": True,
        "news_stale_max_hours": stale_hours,
        "strategy_mechanics_change": "NONE; instrumentation-only source delta",
    }


def _verify_refresh_source_contract(source: dict[str, Any]) -> tuple[dict[str, Any], Path]:
    source_anchor_path = Path(str(source["anchor_path"])).resolve()
    if sha256_file(source_anchor_path) != str(source["anchor_sha256"]).lower():
        raise BackfillError("generation-1 diagnostic anchor hash changed")
    anchor = json.loads(source_anchor_path.read_text(encoding="utf-8"))
    predecessor_id = str(source["work_item_id"])
    if (
        anchor.get("schema_version") != q09.DIAGNOSTIC_ANCHOR_SCHEMA
        or anchor.get("diagnostic_contract") != q09.DIAGNOSTIC_CONTRACT
        or anchor.get("diagnostic_non_admission") is not True
        or str(anchor.get("work_item_id")) != predecessor_id
    ):
        raise BackfillError("generation-1 diagnostic anchor is contradictory")

    baseline_path = Path(str(source["baseline_setfile_path"])).resolve()
    if sha256_file(baseline_path) != str(source["baseline_setfile_sha256"]).lower():
        raise BackfillError("sealed live-derived diagnostic baseline changed")
    baseline_values = q09._setfile_values(baseline_path)
    try:
        risk_fixed = float(baseline_values.get("risk_fixed", "nan"))
        risk_percent = float(baseline_values.get("risk_percent", "nan"))
        stale_hours = int(baseline_values.get("qm_news_stale_max_hours", "-1"))
    except ValueError as exc:
        raise BackfillError("sealed diagnostic baseline has invalid guardrail values") from exc
    if risk_fixed <= 0 or risk_percent != 0 or not 1 <= stale_hours <= 336:
        raise BackfillError("sealed diagnostic baseline violates risk/news guardrails")
    if (
        baseline_values.get("qm_filter_news_enabled") != "0"
        or baseline_values.get("qm_filter_news_mode") != "0"
    ):
        raise BackfillError("sealed diagnostic control does not neutralize legacy news inputs")

    live_preset = anchor.get("live_source_preset") or {}
    live_preset_path = Path(str(live_preset.get("path") or "")).resolve()
    live_preset_hash = str(live_preset.get("sha256") or "").lower()
    if not live_preset.get("read_only") or sha256_file(live_preset_path) != live_preset_hash:
        raise BackfillError("read-only live-preset identity changed")
    derived = anchor.get("derived_baseline") or {}
    if (
        Path(str(derived.get("source_path") or "")).resolve() != live_preset_path
        or str(derived.get("source_sha256") or "").lower() != live_preset_hash
        or Path(str(derived.get("derived_path") or "")).resolve() != baseline_path
        or str(derived.get("derived_sha256") or "").lower()
        != sha256_file(baseline_path)
    ):
        raise BackfillError("live-preset to diagnostic-baseline lineage is contradictory")
    return anchor, baseline_path


def _enqueue_fresh_build_rerun(
    *,
    task_id: str,
    source: dict[str, Any],
    fresh_ex5_path: Path,
    source_assessment: dict[str, Any],
) -> dict[str, Any]:
    predecessor_id = str(source["work_item_id"])
    fresh_ex5_sha256 = str(source_assessment["ex5_sha256"])
    new_id = fresh_build_rerun_id(predecessor_id, task_id, fresh_ex5_sha256)
    rerun_root = ARTIFACT_ROOT / "refresh_v2" / new_id
    receipt_path = rerun_root / "enqueue_receipt.json"
    if receipt_path.is_file():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if (
            receipt.get("work_item_id") != new_id
            or receipt.get("rerun_of") != predecessor_id
            or receipt.get("fresh_ex5_sha256") != fresh_ex5_sha256
        ):
            raise BackfillError(f"fresh-build receipt contradicts request: {receipt_path}")
        return {
            **receipt,
            "receipt_path": str(receipt_path.resolve()),
            "receipt_sha256": sha256_file(receipt_path),
            "idempotent": True,
        }

    source_anchor, baseline_path = _verify_refresh_source_contract(source)
    source_anchor_path = Path(str(source["anchor_path"])).resolve()
    include_path = REPO_ROOT / "framework" / "include" / "QM" / "QM_NewsFilter.mqh"
    common_path = REPO_ROOT / "framework" / "include" / "QM" / "QM_Common.mqh"
    if not include_path.is_file() or not common_path.is_file():
        raise BackfillError("current framework include closure is incomplete")

    closure_path = rerun_root / "diagnostic_include_assessment.json"
    closure = {
        "schema_version": "q09-live-news-diagnostic-include-assessment/v2",
        "diagnostic_non_admission": True,
        "diagnostic_generation": FRESH_BUILD_GENERATION,
        "ea_id": source["ea_id"],
        "symbol": source["symbol"],
        "fresh_build_ex5": {
            "path": str(fresh_ex5_path.resolve()),
            "sha256": fresh_ex5_sha256,
        },
        "current_ea_source": {
            "path": source_assessment["mq5_path"],
            "sha256": source_assessment["mq5_sha256"],
        },
        "framework_common": {
            "path": str(common_path.resolve()),
            "sha256": sha256_file(common_path),
        },
        "framework_news_filter": {
            "path": str(include_path.resolve()),
            "sha256": sha256_file(include_path),
            "index_scoping_fix_commit": "89963ff75",
        },
        "source_anchor": {
            "path": str(source_anchor_path),
            "sha256": sha256_file(source_anchor_path),
        },
        "source_assessment": source_assessment,
    }
    write_immutable(closure_path, canonical_bytes(closure))

    anchor = json.loads(json.dumps(source_anchor))
    anchor_id = (
        f"diagnostic-anchor:{CAMPAIGN_ID}:fresh-v2:"
        f"{source['ea_id']}/{str(source['symbol']).split('.', 1)[0]}:"
        f"{fresh_ex5_sha256[:16]}"
    )
    anchor.update({
        "router_task_id": task_id,
        "anchor_id": anchor_id,
        "work_item_id": new_id,
        "rerun_of": predecessor_id,
        "diagnostic_generation": FRESH_BUILD_GENERATION,
        "queue_rank": int(source["rank"]),
        "fresh_build_ex5": {
            "path": str(fresh_ex5_path.resolve()),
            "sha256": fresh_ex5_sha256,
            "role": "current framework rebuild; not a live deployment mutation",
        },
        "source_anchor": {
            "path": str(source_anchor_path),
            "sha256": sha256_file(source_anchor_path),
        },
        "source_assessment": source_assessment,
        "loaded_chart_evidence_status": (
            "NOT_RUNTIME_AUTHORITY; live-preset bytes supply strategy parameters "
            "and the fresh canonical EX5 supplies executable identity"
        ),
        "diagnostic_include_assessment": {
            "path": str(closure_path.resolve()),
            "sha256": sha256_file(closure_path),
        },
    })
    anchor["baseline_run"]["baseline_ex5_sha256"] = fresh_ex5_sha256
    anchor_path = rerun_root / "diagnostic_anchor.json"
    write_immutable(anchor_path, canonical_bytes(anchor))

    plan = q09.build_run_plan(
        work_item_id=new_id,
        candidate_lineage_key=sha256_file(anchor_path),
        deployment_target="DXZ",
        q08_work_item_id=anchor_id,
        q08_evidence_path=anchor_path,
        baseline_setfile_path=baseline_path,
        ex5_path=fresh_ex5_path,
        include_closure_path=closure_path,
        calendar_manifest_path=CALENDAR_MANIFEST,
        calendar_common_relative_path=CALENDAR_COMMON_PATH,
        full_from_utc="2019-01-01T00:00:00Z",
        full_to_utc="2025-12-31T23:59:59Z",
        selection_from_utc="2019-01-01T00:00:00Z",
        selection_to_utc="2023-12-31T23:59:59Z",
        holdout_from_utc="2024-01-01T00:00:00Z",
        holdout_to_utc="2025-12-31T23:59:59Z",
        complete_months=60,
        holdout_complete_months=24,
        tester_model="REAL_TICKS",
        cost_profile="DXZ_CANONICAL_REAL_TICKS_V1",
        output_root=rerun_root / "q09_plan",
    )
    if int(plan.get("cell_count") or 0) != 40:
        raise BackfillError("fresh-build rerun plan is not the sealed 40-cell matrix")
    plan_path = Path(str(plan["plan_path"])).resolve()
    plan_file_sha256 = sha256_file(plan_path)

    now_iso = datetime.now(timezone.utc).isoformat()
    payload = {
        "diagnostic_non_admission": True,
        "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
        "diagnostic_campaign_id": CAMPAIGN_ID,
        "diagnostic_generation": FRESH_BUILD_GENERATION,
        "diagnostic_queue_rank": int(source["rank"]) + FRESH_BUILD_QUEUE_OFFSET,
        "diagnostic_source_rank": int(source["rank"]),
        "diagnostic_live_weight": source.get("weight"),
        "diagnostic_anchor_path": str(anchor_path),
        "diagnostic_anchor_sha256": sha256_file(anchor_path),
        "diagnostic_control": "legacy_and_two_axis_news_inputs_neutralized",
        "priority_track": True,
        "host_symbol": source["symbol"],
        "host_timeframe": source["period"],
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "staged_ex5_path": str(fresh_ex5_path.resolve()),
        "staged_ex5_sha256": fresh_ex5_sha256,
        "fresh_build_source_path": source_assessment["mq5_path"],
        "fresh_build_source_sha256": source_assessment["mq5_sha256"],
        "avoid_terminals": list(AVOID_TERMINALS),
        "diagnostic_allowed_terminals": list(ALLOWED_TERMINALS),
        "diagnostic_concurrency_cap": 5,
        "protected_chain_exclusion": [
            "9fabcddb-8c2e-4b01-9295-4ef4dbb6892d", "Q09_PORTFOLIO", "Q10"
        ],
        "router_task_id": task_id,
        "rerun_of": predecessor_id,
    }
    inserted = False
    with farmctl.connect(FARM_ROOT) as connection:
        connection.execute("BEGIN IMMEDIATE")
        predecessor = connection.execute(
            "SELECT ea_id,symbol,status,verdict,payload_json FROM work_items WHERE id=?",
            (predecessor_id,),
        ).fetchone()
        if predecessor is None:
            raise BackfillError("fresh-build predecessor does not exist")
        predecessor_payload = json.loads(predecessor["payload_json"] or "{}")
        if (
            predecessor["ea_id"] != source["ea_id"]
            or predecessor["symbol"] != source["symbol"]
            or predecessor_payload.get("diagnostic_campaign_id") != CAMPAIGN_ID
            or predecessor_payload.get("diagnostic_non_admission") is not True
        ):
            raise BackfillError("fresh-build predecessor is not the sealed campaign sleeve")
        if connection.execute(
            "SELECT 1 FROM q09_news_tests WHERE work_item_id IN (?,?) LIMIT 1",
            (predecessor_id, new_id),
        ).fetchone() is not None:
            raise BackfillError("fresh-build diagnostic conflicts with canonical Q09 evidence")
        existing = connection.execute(
            "SELECT status,claimed_by,payload_json,created_at FROM work_items WHERE id=?",
            (new_id,),
        ).fetchone()
        if existing is None:
            connection.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,parent_task_id,evidence_path,claimed_by,
                    payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', 'Q09_NEWS', ?, ?, ?, 'pending', NULL,
                         0, ?, NULL, NULL, ?, ?, ?)
                """,
                (
                    new_id, source["ea_id"], source["symbol"], str(baseline_path),
                    predecessor_id, json.dumps(payload, sort_keys=True), now_iso, now_iso,
                ),
            )
            created_at = now_iso
            row_status = "pending"
            row_payload = payload
            inserted = True
        else:
            row_payload = json.loads(existing["payload_json"] or "{}")
            if (
                row_payload.get("diagnostic_generation") != FRESH_BUILD_GENERATION
                or row_payload.get("rerun_of") != predecessor_id
                or row_payload.get("staged_ex5_sha256") != fresh_ex5_sha256
            ):
                raise BackfillError("existing fresh-build row contradicts sealed identities")
            created_at = str(existing["created_at"])
            row_status = str(existing["status"])
        connection.commit()

    if row_status == "pending" and not row_payload.get("q09_binding_version"):
        bound = q09.bind_diagnostic_plan_to_work_item(
            FARM_ROOT,
            work_item_id=new_id,
            plan_path=plan_path,
            expected_plan_file_sha256=plan_file_sha256,
            cell_timeout_sec=q09.DEFAULT_CELL_TIMEOUT_SEC,
        )
    elif row_payload.get("q09_binding_version"):
        bound = {
            "bound": True,
            "work_item_id": new_id,
            "plan_path": row_payload.get("q09_run_plan_path"),
            "plan_file_sha256": row_payload.get("q09_run_plan_file_sha256"),
            "plan_sha256": row_payload.get("q09_run_plan_sha256"),
            "cell_count": row_payload.get("q09_cell_count"),
            "dispatch_binding_sha256": row_payload.get("q09_dispatch_binding_sha256"),
            "idempotent": True,
        }
    else:
        raise BackfillError(
            f"existing fresh-build row is {row_status} without a dispatch binding"
        )

    receipt = {
        "schema_version": "q09-live-news-fresh-build-rerun-receipt/v2",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "diagnostic_generation": FRESH_BUILD_GENERATION,
        "router_task_id": task_id,
        "work_item_id": new_id,
        "rerun_of": predecessor_id,
        "status": row_status,
        "inserted": inserted,
        "source_rank": int(source["rank"]),
        "queue_rank": int(source["rank"]) + FRESH_BUILD_QUEUE_OFFSET,
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "avoided_terminals": list(AVOID_TERMINALS),
        "baseline_setfile_path": str(baseline_path),
        "baseline_setfile_sha256": sha256_file(baseline_path),
        "live_preset_path": str((source_anchor.get("live_source_preset") or {})["path"]),
        "live_preset_sha256": str((source_anchor.get("live_source_preset") or {})["sha256"]),
        "fresh_ex5_path": str(fresh_ex5_path.resolve()),
        "fresh_ex5_sha256": fresh_ex5_sha256,
        "fresh_mq5_path": source_assessment["mq5_path"],
        "fresh_mq5_sha256": source_assessment["mq5_sha256"],
        "calendar_manifest_path": str(CALENDAR_MANIFEST.resolve()),
        "calendar_manifest_sha256": sha256_file(CALENDAR_MANIFEST),
        "calendar_bundle_id": "q09cal-20150101-20260809-0bb19b5bb9790b76",
        "source_anchor_path": str(source_anchor_path),
        "source_anchor_sha256": sha256_file(source_anchor_path),
        "anchor_path": str(anchor_path),
        "anchor_sha256": sha256_file(anchor_path),
        "plan_path": str(plan_path),
        "plan_file_sha256": plan_file_sha256,
        "plan_sha256": plan["plan_sha256"],
        "input_manifest_sha256": plan["input_manifest_sha256"],
        "cell_count": 40,
        "seeds": list(contract.SEEDS),
        "enqueued_at_utc": created_at,
        "binding": bound,
    }
    write_immutable(receipt_path, canonical_bytes(receipt))
    return {
        **receipt,
        "receipt_path": str(receipt_path.resolve()),
        "receipt_sha256": sha256_file(receipt_path),
    }


def enqueue_fresh_build_reruns(
    *,
    task_id: str,
    ea_id: str,
    fresh_ex5_path: str | Path,
    expected_fresh_ex5_sha256: str,
) -> dict[str, Any]:
    """Append generation-2 diagnostics for every campaign sleeve of one rebuilt EA."""

    task_id = task_id.strip()
    ea_id = ea_id.strip().upper()
    expected_hash = expected_fresh_ex5_sha256.strip().lower()
    if not task_id or not re.fullmatch(r"QM5_\d+", ea_id):
        raise BackfillError("router task id and canonical QM5 EA id are required")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
        raise BackfillError("expected fresh EX5 SHA-256 is invalid")
    ex5_path = Path(fresh_ex5_path).resolve()
    actual_hash = sha256_file(ex5_path)
    if actual_hash != expected_hash:
        raise BackfillError(
            f"fresh EX5 SHA-256 mismatch: expected {expected_hash}, got {actual_hash}"
        )
    source_assessment = _fresh_build_source_assessment(ex5_path, ea_id)

    campaign_path = ARTIFACT_ROOT / "campaign_plan.json"
    if not campaign_path.is_file():
        raise BackfillError(f"campaign plan is missing: {campaign_path}")
    campaign = json.loads(campaign_path.read_text(encoding="utf-8"))
    if (
        campaign.get("schema_version") != "q09-live-news-backfill-plan/v1"
        or campaign.get("campaign_id") != CAMPAIGN_ID
        or campaign.get("diagnostic_non_admission") is not True
    ):
        raise BackfillError("campaign plan contract is missing or contradictory")
    sources = sorted(
        [row for row in campaign.get("sleeves", []) if row.get("ea_id") == ea_id],
        key=lambda row: int(row["rank"]),
    )
    if not sources:
        raise BackfillError(f"{ea_id} is not a sealed live-book diagnostic source")

    batch_receipt_path = ARTIFACT_ROOT / "refresh_v2" / task_id / ea_id / "enqueue_receipt.json"
    if batch_receipt_path.is_file():
        receipt = json.loads(batch_receipt_path.read_text(encoding="utf-8"))
        if (
            receipt.get("ea_id") != ea_id
            or receipt.get("fresh_ex5_sha256") != expected_hash
            or receipt.get("router_task_id") != task_id
        ):
            raise BackfillError(f"fresh-build batch receipt contradicts request: {batch_receipt_path}")
        return {
            **receipt,
            "receipt_path": str(batch_receipt_path.resolve()),
            "receipt_sha256": sha256_file(batch_receipt_path),
            "idempotent": True,
        }

    rows = [
        _enqueue_fresh_build_rerun(
            task_id=task_id,
            source=source,
            fresh_ex5_path=ex5_path,
            source_assessment=source_assessment,
        )
        for source in sources
    ]
    receipt = {
        "schema_version": "q09-live-news-fresh-build-batch-receipt/v2",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "diagnostic_generation": FRESH_BUILD_GENERATION,
        "router_task_id": task_id,
        "ea_id": ea_id,
        "fresh_ex5_path": str(ex5_path),
        "fresh_ex5_sha256": expected_hash,
        "fresh_mq5_path": source_assessment["mq5_path"],
        "fresh_mq5_sha256": source_assessment["mq5_sha256"],
        "sleeve_count": len(rows),
        "work_item_ids": [row["work_item_id"] for row in rows],
        "rerun_of": [row["rerun_of"] for row in rows],
        "source_ranks": [row["source_rank"] for row in rows],
        "cell_count_per_sleeve": 40,
        "seeds": list(contract.SEEDS),
        "calendar_bundle_id": "q09cal-20150101-20260809-0bb19b5bb9790b76",
        "allowed_terminals": list(ALLOWED_TERMINALS),
        "avoided_terminals": list(AVOID_TERMINALS),
        "max_simultaneous_diagnostics": 5,
        "receipts": [
            {key: row[key] for key in (
                "work_item_id", "rerun_of", "source_rank", "queue_rank",
                "receipt_path", "receipt_sha256",
            )}
            for row in rows
        ],
        "enqueued_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    write_immutable(batch_receipt_path, canonical_bytes(receipt))
    return {
        **receipt,
        "receipt_path": str(batch_receipt_path.resolve()),
        "receipt_sha256": sha256_file(batch_receipt_path),
    }


def campaign_status() -> dict[str, Any]:
    ids = [sleeve.work_item_id for sleeve in SLEEVES]
    with farmctl.connect(FARM_ROOT) as connection:
        rows = connection.execute(
            "SELECT id,ea_id,symbol,status,verdict,claimed_by,evidence_path,payload_json,updated_at "
            "FROM work_items WHERE id IN (%s)" % ",".join("?" for _ in ids),
            tuple(ids),
        ).fetchall()
        refresh_rows = connection.execute(
            "SELECT id,ea_id,symbol,status,verdict,claimed_by,evidence_path,payload_json,updated_at "
            "FROM work_items WHERE json_valid(payload_json)=1 "
            "AND json_extract(payload_json,'$.diagnostic_campaign_id')=? "
            "AND json_extract(payload_json,'$.diagnostic_generation')=?",
            (CAMPAIGN_ID, FRESH_BUILD_GENERATION),
        ).fetchall()
        all_ids = ids + [str(row["id"]) for row in refresh_rows]
        canonical_rows = connection.execute(
            "SELECT work_item_id FROM q09_news_tests WHERE work_item_id IN (%s)"
            % ",".join("?" for _ in all_ids),
            tuple(all_ids),
        ).fetchall()
    if canonical_rows:
        raise BackfillError("diagnostic campaign polluted canonical q09_news_tests")
    by_id = {str(row["id"]): row for row in rows}
    detail: list[dict[str, Any]] = []
    counts: dict[str, int] = {}
    for sleeve in SLEEVES:
        row = by_id.get(sleeve.work_item_id)
        state = str(row["status"]) if row else "NOT_ENQUEUED"
        counts[state] = counts.get(state, 0) + 1
        detail.append({
            "rank": sleeve.rank,
            "ea_id": sleeve.ea_key,
            "symbol": sleeve.symbol_dwx,
            "period": sleeve.period,
            "weight": sleeve.weight,
            "work_item_id": sleeve.work_item_id,
            "status": state,
            "verdict": row["verdict"] if row else None,
            "claimed_by": row["claimed_by"] if row else None,
            "evidence_path": row["evidence_path"] if row else None,
            "updated_at": row["updated_at"] if row else None,
        })
    active = [item for item in detail if item["status"] == "active"]
    refresh_detail: list[dict[str, Any]] = []
    refresh_counts: dict[str, int] = {}
    for row in refresh_rows:
        payload = json.loads(row["payload_json"] or "{}")
        state = str(row["status"])
        refresh_counts[state] = refresh_counts.get(state, 0) + 1
        refresh_detail.append({
            "source_rank": int(payload.get("diagnostic_source_rank") or 0),
            "queue_rank": int(payload.get("diagnostic_queue_rank") or 0),
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "period": payload.get("host_timeframe"),
            "work_item_id": row["id"],
            "rerun_of": payload.get("rerun_of"),
            "fresh_ex5_sha256": payload.get("staged_ex5_sha256"),
            "status": state,
            "verdict": row["verdict"],
            "claimed_by": row["claimed_by"],
            "evidence_path": row["evidence_path"],
            "updated_at": row["updated_at"],
        })
    refresh_detail.sort(key=lambda item: (item["source_rank"], item["work_item_id"]))
    refresh_active = [item for item in refresh_detail if item["status"] == "active"]
    all_active = active + refresh_active
    if len(all_active) > 5 or any(
        item["claimed_by"] not in ALLOWED_TERMINALS for item in all_active
    ):
        raise BackfillError("diagnostic concurrency/terminal cap violated")
    status = {
        "schema_version": "q09-live-news-backfill-status/v1",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "canonical_q09_rows": 0,
        "counts": counts,
        "active_count": len(all_active),
        "max_simultaneous_diagnostics": 5,
        "sleeves": detail,
        "refresh_v2_counts": refresh_counts,
        "refresh_v2_sleeves": refresh_detail,
        "observed_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    write_status(ARTIFACT_ROOT / "campaign_status.json", status)
    return status


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    plan = sub.add_parser("plan")
    plan.add_argument("--task-id", required=True)
    apply = sub.add_parser("apply")
    apply.add_argument("--task-id", required=True)
    rerun = sub.add_parser("rerun")
    rerun.add_argument("--task-id", required=True)
    rerun.add_argument("--predecessor-id", required=True)
    rerun.add_argument("--avoid-terminal", required=True, choices=list(ALLOWED_TERMINALS))
    rerun.add_argument(
        "--launch-not-before-utc",
        help="Optional timezone-aware UTC claim deferral for staggered diagnostics",
    )
    refresh = sub.add_parser("refresh")
    refresh.add_argument("--task-id", required=True)
    refresh.add_argument("--ea", required=True)
    refresh.add_argument("--fresh-ex5", required=True)
    refresh.add_argument("--expected-fresh-ex5-sha256", required=True)
    sub.add_parser("status")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "status":
        result = campaign_status()
    elif args.command == "rerun":
        result = enqueue_append_only_rerun(
            task_id=args.task_id,
            predecessor_id=args.predecessor_id,
            avoid_terminal=args.avoid_terminal,
            launch_not_before_utc=args.launch_not_before_utc,
        )
    elif args.command == "refresh":
        result = enqueue_fresh_build_reruns(
            task_id=args.task_id,
            ea_id=args.ea,
            fresh_ex5_path=args.fresh_ex5,
            expected_fresh_ex5_sha256=args.expected_fresh_ex5_sha256,
        )
    else:
        campaign = prepare_campaign(args.task_id)
        result = campaign if args.command == "plan" else {
            "campaign": campaign,
            "enqueue": enqueue_campaign(campaign),
            "status": campaign_status(),
        }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
