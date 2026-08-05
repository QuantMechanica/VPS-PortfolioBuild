#!/usr/bin/env python3
"""Plan, enqueue, and inspect the OWNER-requested live-book Q09 diagnostic.

This lane deliberately reuses the sealed Q09 7x1 execution machinery while
remaining outside canonical Q09 admission storage.  It reads T_Live artifacts,
never modifies them, stages the exact deployed EX5 through the resident terminal
worker, and constrains execution to T1-T5.
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
from datetime import datetime, timezone
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


def campaign_status() -> dict[str, Any]:
    ids = [sleeve.work_item_id for sleeve in SLEEVES]
    with farmctl.connect(FARM_ROOT) as connection:
        rows = connection.execute(
            "SELECT id,ea_id,symbol,status,verdict,claimed_by,evidence_path,payload_json,updated_at "
            "FROM work_items WHERE id IN (%s)" % ",".join("?" for _ in ids),
            tuple(ids),
        ).fetchall()
        canonical_rows = connection.execute(
            "SELECT work_item_id FROM q09_news_tests WHERE work_item_id IN (%s)"
            % ",".join("?" for _ in ids),
            tuple(ids),
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
    if len(active) > 5 or any(item["claimed_by"] not in ALLOWED_TERMINALS for item in active):
        raise BackfillError("diagnostic concurrency/terminal cap violated")
    status = {
        "schema_version": "q09-live-news-backfill-status/v1",
        "campaign_id": CAMPAIGN_ID,
        "diagnostic_non_admission": True,
        "canonical_q09_rows": 0,
        "counts": counts,
        "active_count": len(active),
        "max_simultaneous_diagnostics": 5,
        "sleeves": detail,
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
    sub.add_parser("status")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command == "status":
        result = campaign_status()
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
