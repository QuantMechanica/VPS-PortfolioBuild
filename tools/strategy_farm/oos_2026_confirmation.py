#!/usr/bin/env python3
"""Plan/enqueue the 2026-Q1 single-window, non-admission regime diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from tools.strategy_farm import farmctl, q09_news_contract as contract, q09_news_runner as q09
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock

FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPO_ROOT = Path(r"C:\QM\repo")
PULSE = Path(r"D:\QM\reports\state\live_book_pulse.json")
LIVE_EXPERTS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs")
CALENDAR_MANIFEST = Path(r"D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\manifest.json")
CALENDAR_COMMON = "QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv"
ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\oos_2026_confirmation_v1")
FARM_DB = FARM_ROOT / "state" / "farm_state.sqlite"
FACTORY_MUTATION_LOCK = FARM_ROOT / "state" / "FACTORY_MUTATION.lock"
CAMPAIGN_ID = "oos-2026-confirmation-v1"
WINDOW_SOURCE = "oos_2026"
FROM_UTC = "2026-01-01T00:00:00Z"
TO_UTC = "2026-04-06T23:59:59Z"
SEED = 20250301
ALLOWED = ["T1", "T2", "T3", "T4", "T5"]
AVOID = ["T6", "T7", "T8", "T9", "T10"]
BASKET_REPAIR_MARKER = "oos_2026_basket_payload_repair"
BASKET_REPAIR_REASON = "restore_manifest_bound_multisymbol_history_scope"
CAMPAIGN_PLAN_PATH = ARTIFACT_ROOT / "campaign_plan.json"
WINDOW_REPAIR_MARKER = "oos_window_repair"
WINDOW_REPAIR_SCHEMA = "qm.oos-2026-window-repair/v1"
WINDOW_HOLD_CODE = "OOS_WINDOW_MISMATCH"
WINDOW_REPAIR_TASK_REF = "e544e3b8"
SUPERSEDES_SOURCE_ENCODING = "repair:oos-2026-window/v1"
SUPERSEDES_RECORDED_BY = "oos_2026_confirmation.apply_oos_window_repair"
WINDOW_KEYS = ("from_date", "to_date", "window_from_utc", "window_to_utc")
# Payload keys a completed run writes back (claim, spawn bindings, runner
# results). A minted append-only successor is a FRESH pending row, so none of
# the previous execution's residue may travel with it -- above all the stale
# ``expected_from_date``/``expected_to_date`` of the mismeasured 2024 run.
# Derived from the exact key delta between a completed and a freshly enqueued
# OOS-2026 row (2026-09-04).
RUNTIME_RESIDUE_PAYLOAD_KEYS = frozenset({
    "artifact_identity", "claimed_at_iso", "claimed_by_worker_pid",
    "commit_reservation_class", "commit_reservation_gb",
    "commit_reservation_until_utc", "custom_history_copy_on_claim",
    "custom_history_post_copy_audit_sha256",
    "custom_history_pre_copy_audit_sha256", "diagnostic_underlying_q09_verdict",
    "dispatch_ex5_verified_at", "ea_dir_name", "effective_min_trades",
    "evidence_binding_required", "evidence_provenance", "expected_ex5_path",
    "expected_ex5_sha256", "expected_expert", "expected_from_date",
    "expected_mq5_sha256", "expected_period", "expected_setfile_sha256",
    "expected_symbol", "expected_to_date",
    "expected_trades_per_year_per_symbol", "finished_at_iso",
    "job_object_assigned", "job_object_mode", "job_object_registry_key",
    "log_path", "p2_run_stage", "phase_evidence_path", "phase_runner", "pid",
    "primary_thread_resumed", "process_creation_key", "process_image_path",
    "process_started_at_epoch", "process_started_suspended",
    "q09_plan_bound_at", "q09_sidecar_verification", "report_root",
    "run_smoke_exit_code", "smoke_year_count", "staged_ex5", "started_at_iso",
    "summary_path", "terminal", "timeout_seconds", "verdict_reason",
    "verdict_taxonomy",
})

FRONTIER = (
    (10145,"XAUUSD"),(10513,"XAUUSD"),(10706,"GBPUSD"),(11422,"USDCAD"),
    (11881,"GBPUSD"),(12849,"XTIUSD"),(12855,"XTIUSD"),(13054,"XTIUSD"),
    (1537,"XAGUSD"),(20048,"XTIUSD"),(20266,"XTIUSD"),(21505,"XAGUSD"),
    (9641,"WS30"),(11288,"USDJPY"),(13128,"NDX"),(11421,"EURUSD"),
    (13213,"USDJPY"),(13013,"NDX"),(20188,"USDJPY"),(21501,"USDJPY"),
    (10123,"XAUUSD"),(10142,"SP500"),(10146,"AUDUSD"),(11294,"GDAXI"),
    (12623,"XAUUSD"),(12708,"XAUUSD"),(41161,"GBPUSD"),(10128,"XAUUSD"),
    (10183,"XAUUSD"),(11881,"SP500"),(13036,"GDAXI"),
)


class OOS2026Error(RuntimeError):
    pass


def sha(path: Path) -> str:
    return contract.sha256_file(path)


def write_json(path: Path, value: dict[str, Any]) -> None:
    value = {"window_source": WINDOW_SOURCE, **value}
    data = contract.canonical_json_bytes(value)
    if path.exists() and path.read_bytes() != data:
        raise OOS2026Error(f"immutable artifact contradiction: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        path.write_bytes(data)


def tester_date_from_utc(value: Any, *, field: str) -> str:
    """Map a campaign-plan ISO-8601 UTC bound to an MT5 tester ``YYYY.MM.DD`` date.

    Inclusive end-day convention (documented 2026-09-04): the MetaTrader 5
    strategy tester treats ``ToDate`` as the INCLUSIVE last calendar day of the
    run -- it tests through the end of that day, it does not stop at its
    midnight boundary. The campaign plan therefore states the closing bound as
    an end-of-day instant (``full_to_utc = 2026-04-06T23:59:59Z``) and the
    tester date is the DATE PART of that instant (``2026.04.06``), never the
    following day. The opening bound maps the same way: ``full_from_utc =
    2026-01-01T00:00:00Z`` -> ``FromDate = 2026.01.01``.
    """
    text = str(value or "").strip()
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise OOS2026Error(f"{field} is not an ISO-8601 UTC instant: {value!r}") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc).strftime("%Y.%m.%d")


def campaign_window(campaign: dict[str, Any]) -> dict[str, str]:
    """Return the campaign plan's single measurement window in both spellings."""
    from_utc = str(campaign.get("full_from_utc") or "")
    to_utc = str(campaign.get("full_to_utc") or "")
    from_date = tester_date_from_utc(from_utc, field="full_from_utc")
    to_date = tester_date_from_utc(to_utc, field="full_to_utc")
    if from_date > to_date:
        raise OOS2026Error(f"campaign window is inverted: {from_date} > {to_date}")
    return {
        "from_date": from_date,
        "to_date": to_date,
        "window_from_utc": from_utc,
        "window_to_utc": to_utc,
    }


def campaign_plan_binding(campaign: dict[str, Any]) -> dict[str, str]:
    """The tamper-evident (path, sha256) pointer at the plan a row is bound to.

    ``prepare`` writes the immutable campaign plan and returns both fields; a
    campaign dict without them cannot produce governed rows, so this fails
    closed rather than guessing a default path.
    """
    path = str(campaign.get("campaign_plan_path") or "").strip()
    digest = str(campaign.get("campaign_plan_sha256") or "").strip().lower()
    if not path or len(digest) != 64:
        raise OOS2026Error(
            "campaign is missing campaign_plan_path/campaign_plan_sha256; "
            "refusing to enqueue rows whose window is unbound"
        )
    return {
        "diagnostic_campaign_plan_path": path,
        "diagnostic_campaign_plan_sha256": digest,
    }


FROM_DATE = tester_date_from_utc(FROM_UTC, field="full_from_utc")
TO_DATE = tester_date_from_utc(TO_UTC, field="full_to_utc")


def _period(value: str) -> str:
    aliases = {"HOURLY":"H1", "DAILY":"D1", "240":"H4", "60":"H1", "1440":"D1"}
    raw = str(value or "").strip().upper()
    return aliases.get(raw, raw) if aliases.get(raw, raw) in q09.VALID_TESTER_PERIODS else "D1"


def _find_ex5(ea_id: int, preferred_label: str | None = None) -> Path:
    if preferred_label:
        live = LIVE_EXPERTS / f"{preferred_label}.ex5"
        if live.is_file():
            return live.resolve()
    live_matches = sorted(LIVE_EXPERTS.glob(f"QM5_{ea_id}_*.ex5"))
    if len(live_matches) == 1:
        return live_matches[0].resolve()
    repo_matches = sorted((REPO_ROOT / "framework" / "EAs").glob(f"QM5_{ea_id}_*/QM5_{ea_id}_*.ex5"))
    if len(repo_matches) == 1:
        return repo_matches[0].resolve()
    raise OOS2026Error(f"QM5_{ea_id}: exact EX5 unresolved ({len(live_matches)} live/{len(repo_matches)} repo)")


def _symbol_list(value: Any, *, field: str, required: bool = False) -> list[str]:
    if value is None and not required:
        return []
    if not isinstance(value, list):
        raise OOS2026Error(f"basket manifest {field} must be a list")
    symbols = [str(item or "").strip().upper() for item in value]
    if (required and not symbols) or any(not symbol for symbol in symbols):
        raise OOS2026Error(f"basket manifest {field} is empty or malformed")
    if len(symbols) != len(set(symbols)):
        raise OOS2026Error(f"basket manifest {field} contains duplicates")
    if any(not symbol.endswith(".DWX") for symbol in symbols):
        raise OOS2026Error(f"basket manifest {field} contains a non-.DWX symbol")
    return symbols


def _basket_payload(
    ea_id: str,
    expected_symbol: str,
    expected_period: str,
    *,
    repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    """Return fail-closed runtime context for an EA that declares a basket."""
    ea_dirs = sorted((repo_root / "framework" / "EAs").glob(f"{ea_id}_*"))
    manifests = [path / "basket_manifest.json" for path in ea_dirs if (path / "basket_manifest.json").is_file()]
    if not manifests:
        return {}
    if len(manifests) != 1:
        raise OOS2026Error(f"{ea_id}: exact basket manifest unresolved ({len(manifests)} matches)")

    manifest_path = manifests[0].resolve()
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise OOS2026Error(f"{ea_id}: unreadable basket manifest: {exc}") from exc
    if not isinstance(manifest, dict):
        raise OOS2026Error(f"{ea_id}: basket manifest root must be an object")

    logical_symbol = str(manifest.get("logical_symbol") or "").strip()
    host_symbol = str(manifest.get("host_symbol") or "").strip().upper()
    host_timeframe_raw = str(manifest.get("host_timeframe") or "").strip().upper()
    valid_period_tokens = set(q09.VALID_TESTER_PERIODS) | {
        "HOURLY", "DAILY", "240", "60", "1440",
    }
    if host_timeframe_raw not in valid_period_tokens:
        raise OOS2026Error(f"{ea_id}: basket host_timeframe is missing or invalid")
    host_timeframe = _period(host_timeframe_raw)
    expected_symbol = str(expected_symbol or "").strip().upper()
    expected_period = _period(expected_period)
    if not logical_symbol or host_symbol != expected_symbol or host_timeframe != expected_period:
        raise OOS2026Error(
            f"{ea_id}: basket host mismatch: manifest={host_symbol}/{host_timeframe} "
            f"work_item={expected_symbol}/{expected_period}"
        )

    basket_symbols = _symbol_list(manifest.get("basket_symbols"), field="basket_symbols", required=True)
    if len(basket_symbols) < 2 or host_symbol not in basket_symbols:
        raise OOS2026Error(f"{ea_id}: basket_symbols must include the host and at least one other symbol")
    traded_symbols = _symbol_list(manifest.get("traded_symbols"), field="traded_symbols")
    conversion_symbols = _symbol_list(manifest.get("conversion_symbols"), field="conversion_symbols")
    if traded_symbols and not set(traded_symbols).issubset(basket_symbols):
        raise OOS2026Error(f"{ea_id}: traded_symbols are not a subset of basket_symbols")
    if conversion_symbols and not set(conversion_symbols).issubset(basket_symbols):
        raise OOS2026Error(f"{ea_id}: conversion_symbols are not a subset of basket_symbols")
    if traded_symbols and not conversion_symbols:
        conversion_symbols = [symbol for symbol in basket_symbols if symbol not in traded_symbols]

    payload: dict[str, Any] = {
        "basket_manifest": str(manifest_path),
        "basket_manifest_sha256": sha(manifest_path),
        "basket_symbol_count": len(basket_symbols),
        "basket_symbols": basket_symbols,
        "host_symbol": host_symbol,
        "host_timeframe": host_timeframe,
        "logical_symbol": logical_symbol,
        "portfolio_scope": "basket",
    }
    if traded_symbols:
        payload["traded_symbols"] = traded_symbols
    if conversion_symbols:
        payload["conversion_symbols"] = conversion_symbols
    tester_currency = str(manifest.get("tester_currency") or "").strip().upper()
    if tester_currency:
        payload["tester_currency"] = tester_currency
    if manifest.get("tester_deposit") not in (None, ""):
        payload["tester_deposit"] = manifest["tester_deposit"]
    return payload


def universe() -> list[dict[str, Any]]:
    pulse = json.loads(PULSE.read_text(encoding="utf-8-sig"))
    presets = {(int(p["ea_id"]), str(p["symbol_norm"])): p for p in pulse["live_presets"]["presets"]}
    live: list[dict[str, Any]] = []
    for sleeve in pulse["book_manifest"]["sleeves"]:
        key = (int(sleeve["ea_id"]), str(sleeve["symbol_norm"]))
        preset = presets.get(key)
        if not preset or not Path(preset["path"]).is_file():
            raise OOS2026Error(f"live preset unresolved: {key}")
        live.append({"cohort":"live", "ea_id":key[0], "symbol":key[1],
                     "period":_period(preset.get("preset_tf_norm")), "baseline":Path(preset["path"]).resolve(),
                     "ex5":_find_ex5(key[0], sleeve.get("ea_label"))})
    frontier: list[dict[str, Any]] = []
    with farmctl.connect(FARM_ROOT) as conn:
        for ea_id, symbol in FRONTIER:
            rows = conn.execute(
                "SELECT setfile_path,payload_json FROM work_items WHERE ea_id=? AND symbol IN (?,?) AND phase IN ('Q07','Q08','Q09','Q09_NEWS','Q10_NEWS','Q11') ORDER BY updated_at DESC",
                (f"QM5_{ea_id}", symbol, f"{symbol}.DWX"),
            ).fetchall()
            chosen = next((r for r in rows if Path(str(r["setfile_path"] or "")).is_file()), None)
            if not chosen:
                raise OOS2026Error(f"frontier baseline unresolved: {ea_id}/{symbol}")
            payload = json.loads(chosen["payload_json"] or "{}")
            period = _period(payload.get("host_timeframe") or payload.get("period") or "D1")
            frontier.append({"cohort":"frontier", "ea_id":ea_id, "symbol":symbol,
                             "period":period, "baseline":Path(chosen["setfile_path"]).resolve(),
                             "ex5":_find_ex5(ea_id)})
    if len(live) != 24 or len(frontier) != 31:
        raise OOS2026Error(f"universe cardinality mismatch: {len(live)} live/{len(frontier)} frontier")
    return live + frontier


def build_one(item: dict[str, Any], rank: int, task_id: str) -> dict[str, Any]:
    key = f"{item['cohort']}:{item['ea_id']}:{item['symbol']}"
    wid = str(uuid.uuid5(uuid.NAMESPACE_URL, f"quantmechanica:{CAMPAIGN_ID}:{key}"))
    root = ARTIFACT_ROOT / f"{rank:02d}_{item['cohort']}_QM5_{item['ea_id']}_{item['symbol']}"
    source_text, encoding, bom = q09._decode_setfile(item["baseline"].read_bytes())
    updated = q09._replace_set_values(source_text, {
        "RISK_FIXED":"1000", "RISK_PERCENT":"0", "qm_rng_seed":str(SEED),
        "qm_news_calendar_bundle_id":"q09cal-20150101-20260809-0bb19b5bb9790b76",
        "qm_news_calendar_common_relative_path":CALENDAR_COMMON,
    })
    setfile = root / "cell" / "inputs.set"
    setfile.parent.mkdir(parents=True, exist_ok=True)
    set_bytes = bom + ("; window_source: oos_2026\n" + updated).encode(encoding)
    if setfile.exists() and setfile.read_bytes() != set_bytes:
        raise OOS2026Error(f"immutable setfile contradiction: {setfile}")
    if not setfile.exists(): setfile.write_bytes(set_bytes)
    anchor = root / "diagnostic_anchor.json"
    anchor_doc = {"schema_version":"qm.oos-2026-anchor/v1", "diagnostic_non_admission":True,
                  "router_task_id":task_id, "work_item_id":wid, "cohort":item["cohort"],
                  "ea_id":f"QM5_{item['ea_id']}", "symbol":f"{item['symbol']}.DWX", "period":item["period"],
                  "source_baseline":{"path":str(item["baseline"]),"sha256":sha(item["baseline"])},
                  "staged_ex5":{"path":str(item["ex5"]),"sha256":sha(item["ex5"])},
                  "data_provenance":"unsigned mutable 2026 ticks; directional non-admission only"}
    write_json(anchor, anchor_doc)
    identities = {"q08_work_item_id":f"oos-anchor:{wid}", "q08_evidence_sha256":sha(anchor),
                  "baseline_setfile_sha256":sha(setfile), "ex5_sha256":sha(item["ex5"]),
                  "include_closure_sha256":sha(anchor)}
    paired = hashlib.sha256(contract.canonical_json_bytes({"work_item_id":wid,"identities":identities,"window_source":WINDOW_SOURCE})).hexdigest()
    identities["paired_base_identity_sha256"] = paired
    manifest = root / "input_manifest.json"
    manifest_doc = {"schema_version":q09.INPUT_MANIFEST_SCHEMA, "contract_version":contract.SCHEMA_VERSION,
                    "diagnostic_non_admission":True, "diagnostic_single_window":True,
                    "work_item_id":wid, "candidate_lineage_key":sha(anchor), "deployment_target":"DXZ",
                    "target_compliance":"DXZ", "source_paths":{"q08_evidence":str(anchor),"baseline_setfile":str(setfile),
                    "ex5":str(item["ex5"]),"include_closure":str(anchor),"calendar_manifest":str(CALENDAR_MANIFEST)},
                    "identities":identities, "calendar_bundle":{"bundle_id":"q09cal-20150101-20260809-0bb19b5bb9790b76",
                    "manifest_sha256":sha(CALENDAR_MANIFEST),"content_sha256":json.loads(CALENDAR_MANIFEST.read_text())["content_sha256"],
                    "coverage_from_utc":"2015-01-01T00:00:00Z","coverage_to_utc":"2026-08-09T23:59:59Z","common_relative_path":CALENDAR_COMMON},
                    "windows":{"full_from_utc":FROM_UTC,"full_to_utc":TO_UTC,"selection_from_utc":FROM_UTC,
                    "selection_to_utc":TO_UTC,"holdout_from_utc":FROM_UTC,"holdout_to_utc":TO_UTC,
                    "complete_months":3,"holdout_complete_months":3,"holdout_sealed":False},
                    "tester_model":"REAL_TICKS","cost_profile":"DXZ_CANONICAL_REAL_TICKS_V1",
                    "matrix_scope":"oos_2026_single_config_single_seed"}
    write_json(manifest, manifest_doc)
    cell = {"window_source":WINDOW_SOURCE,"paired_base_identity_sha256":paired,"arm":"POLICY_ON",
            "temporal_mode":"PRE30_POST30","compliance_mode":"DXZ","seed":SEED,
            "run_identity_sha256":hashlib.sha256(f"{paired}:{SEED}".encode()).hexdigest(),
            "setfile_path":str(setfile),"setfile_sha256":sha(setfile),
            "receipt_path":str(root / "cell" / "cell_receipt.json")}
    plan_path = root / "run_plan.json"
    plan = {"window_source":WINDOW_SOURCE,"schema_version":q09.PLAN_SCHEMA,"contract_version":contract.SCHEMA_VERSION,
            "work_item_id":wid,"candidate_lineage_key":sha(anchor),"input_manifest_path":str(manifest),
            "input_manifest_sha256":sha(manifest),"matrix_scope":"oos_2026_single_config_single_seed",
            "target_compliance":"DXZ","cell_count":1,"window_count":1,"cells":[cell]}
    plan["plan_sha256"] = q09._plan_hash(plan)
    write_json(plan_path, plan)
    q09.load_authenticated_plan(plan_path, expected_file_sha256=sha(plan_path))
    return {"window_source":WINDOW_SOURCE,"rank":rank,"cohort":item["cohort"],"ea_id":f"QM5_{item['ea_id']}",
            "symbol":f"{item['symbol']}.DWX","period":item["period"],"work_item_id":wid,
            "baseline_setfile_path":str(setfile),"staged_ex5_path":str(item["ex5"]),"staged_ex5_sha256":sha(item["ex5"]),
            "anchor_path":str(anchor),"anchor_sha256":sha(anchor),"run_plan_path":str(plan_path),"run_plan_file_sha256":sha(plan_path)}


def prepare(task_id: str) -> dict[str, Any]:
    rows = [build_one(item, i + 1, task_id) for i, item in enumerate(universe())]
    campaign = {"schema_version":"qm.oos-2026-campaign/v1","campaign_id":CAMPAIGN_ID,
                "router_task_id":task_id,"diagnostic_non_admission":True,"diagnostic_single_window":True,
                "full_from_utc":FROM_UTC,"full_to_utc":TO_UTC,"single_seed":SEED,"single_config":"deployed",
                "tester_model":"REAL_TICKS","cost_profile":"DXZ_CANONICAL_REAL_TICKS_V1",
                "t_live_read_only":True,"allowed_terminals":ALLOWED,"avoid_terminals":AVOID,
                "queue_policy":"diagnostic rank behind census","live_count":24,"frontier_count":31,"run_count":55,"runs":rows}
    path = ARTIFACT_ROOT / "campaign_plan.json"; write_json(path, campaign)
    return {**campaign,"campaign_plan_path":str(path),"campaign_plan_sha256":sha(path)}


def enqueue(campaign: dict[str, Any]) -> dict[str, Any]:
    now = datetime.now(timezone.utc).isoformat(); inserted=[]; existing=[]
    # EXPLICIT WINDOW CONTRACT (2026-09-04): every diagnostic row carries the
    # campaign window in its payload. Without it farmctl's spawn builder found
    # no window, and terminal_worker._resolved_evidence_window silently
    # substituted DEFAULT_RUN_SMOKE_YEAR (2024) -- the whole first wave measured
    # 2024 and was labelled 2026 out-of-sample. from_date/to_date are the MT5
    # tester bounds; window_from_utc/window_to_utc keep the plan's own source
    # instants for audit.
    window = campaign_window(campaign)
    # The window is invisible to every stored binding hash (the dispatch-binding
    # material and the sealed run plan are both window-blind), so each row also
    # names the plan file it was derived from.  farmctl's spawn builder re-reads
    # that file, checks the sha256 and refuses to launch if the payload window
    # and the plan disagree.
    plan_binding = campaign_plan_binding(campaign)
    with farmctl.connect(FARM_ROOT) as conn:
        conn.execute("BEGIN IMMEDIATE")
        for row in campaign["runs"]:
            if conn.execute("SELECT 1 FROM work_items WHERE id=?",(row["work_item_id"],)).fetchone():
                existing.append(row["work_item_id"]); continue
            payload={"window_source":WINDOW_SOURCE,**window,**plan_binding,"diagnostic_non_admission":True,"diagnostic_contract":q09.DIAGNOSTIC_CONTRACT,
                     "diagnostic_single_window":True,"diagnostic_campaign_id":CAMPAIGN_ID,"diagnostic_queue_rank":10000+row["rank"],
                     "host_symbol":row["symbol"],"host_timeframe":row["period"],"risk_fixed":1000.0,"risk_percent":0.0,
                     "staged_ex5_path":row["staged_ex5_path"],"staged_ex5_sha256":row["staged_ex5_sha256"],
                     "diagnostic_anchor_path":row["anchor_path"],"diagnostic_anchor_sha256":row["anchor_sha256"],
                     "diagnostic_allowed_terminals":ALLOWED,"diagnostic_concurrency_cap":5,"avoid_terminals":AVOID,
                     "router_task_id":campaign["router_task_id"],"protected_chain_exclusion":["OPT_CENSUS","Q09_PORTFOLIO","Q10"]}
            payload.update({"q09_binding_version":"q09-news-dispatch-binding/v1","q09_activation_state":"RUNNABLE_BOUND",
                            "q09_run_plan_path":row["run_plan_path"],"q09_run_plan_file_sha256":row["run_plan_file_sha256"],
                            "q09_run_plan_sha256":json.loads(Path(row["run_plan_path"]).read_text())["plan_sha256"],
                            "q09_input_manifest_sha256":json.loads(Path(row["run_plan_path"]).read_text())["input_manifest_sha256"],
                            "q09_q08_work_item_id":f"oos-anchor:{row['work_item_id']}","q09_q08_evidence_sha256":row["anchor_sha256"],
                            "q09_q07_work_item_id":f"oos-anchor:{row['work_item_id']}","q09_q07_evidence_path":row["anchor_path"],
                            "q09_q07_evidence_sha256":row["anchor_sha256"],"q09_cell_count":1,
                            "q09_cell_timeout_sec":q09.DEFAULT_CELL_TIMEOUT_SEC,"timeout_min":q09.required_factory_timeout_min(1,window_count=1)})
            payload.update(_basket_payload(row["ea_id"], row["symbol"], row["period"]))
            payload["q09_dispatch_binding_sha256"]=q09._dispatch_binding_sha256(payload)
            conn.execute("INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES(?,'backtest','Q09_NEWS',?,?,?,'pending',0,?,?,?)",
                         (row["work_item_id"],row["ea_id"],row["symbol"],row["baseline_setfile_path"],json.dumps(payload,sort_keys=True),now,now))
            inserted.append(row["work_item_id"])
        conn.commit()
    receipt={"schema_version":"qm.oos-2026-enqueue/v1","diagnostic_non_admission":True,"inserted":inserted,
             "existing":existing,"count":55,"queue_policy":"behind census","enqueued_at_utc":now,
             "tester_window":window,**plan_binding}
    path=ARTIFACT_ROOT/"enqueue_receipt.json"; write_json(path,receipt)
    return {**receipt,"receipt_path":str(path),"receipt_sha256":sha(path)}


def _payload_sha256(payload_json: str | None) -> str:
    return hashlib.sha256((payload_json or "").encode("utf-8")).hexdigest()


def _basket_repair_plan(
    conn: sqlite3.Connection,
    work_item_id: str,
    *,
    repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT id,kind,phase,ea_id,symbol,status,claimed_by,payload_json,updated_at "
        "FROM work_items WHERE id=?",
        (work_item_id,),
    ).fetchone()
    if row is None:
        raise OOS2026Error(f"{work_item_id}: work item not found")
    if row["kind"] != "backtest" or row["phase"] != "Q09_NEWS":
        raise OOS2026Error(f"{work_item_id}: only a Q09_NEWS backtest may be repaired")
    if row["status"] != "pending" or row["claimed_by"] is not None:
        raise OOS2026Error(
            f"{work_item_id}: repair requires an unclaimed pending row "
            f"(status={row['status']!r}, claimed_by={row['claimed_by']!r})"
        )
    try:
        payload = json.loads(row["payload_json"] or "{}")
    except json.JSONDecodeError as exc:
        raise OOS2026Error(f"{work_item_id}: payload is not valid JSON") from exc
    if not isinstance(payload, dict):
        raise OOS2026Error(f"{work_item_id}: payload root must be an object")
    if (
        payload.get("diagnostic_non_admission") is not True
        or payload.get("diagnostic_campaign_id") != CAMPAIGN_ID
        or payload.get("q09_activation_state") != "RUNNABLE_BOUND"
    ):
        raise OOS2026Error(f"{work_item_id}: row is outside the authenticated OOS-2026 diagnostic lane")

    context = _basket_payload(
        str(row["ea_id"]),
        str(payload.get("host_symbol") or row["symbol"] or ""),
        str(payload.get("host_timeframe") or ""),
        repo_root=repo_root,
    )
    if not context:
        raise OOS2026Error(f"{work_item_id}: EA does not declare a basket manifest")
    contradictions = {
        key: {"actual": payload[key], "expected": value}
        for key, value in context.items()
        if key in payload and payload[key] != value
    }
    if contradictions:
        raise OOS2026Error(
            f"{work_item_id}: existing basket payload contradicts the manifest: "
            + json.dumps(contradictions, sort_keys=True)
        )
    added_keys = sorted(key for key in context if key not in payload)
    return {
        "mode": "DRY_RUN",
        "status": "READY_FOR_APPLY" if added_keys else "NOTHING_TO_DO",
        "work_item_id": work_item_id,
        "ea_id": row["ea_id"],
        "symbol": row["symbol"],
        "phase": row["phase"],
        "row_status": row["status"],
        "claimed_by": row["claimed_by"],
        "updated_at": row["updated_at"],
        "before_payload_sha256": _payload_sha256(row["payload_json"]),
        "added_keys": added_keys,
        "basket_context": context,
    }


def plan_basket_payload_repair(
    db: Path,
    work_item_id: str,
    *,
    repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    conn = sqlite3.connect(f"file:{db.resolve()}?mode=ro", uri=True, timeout=30)
    try:
        return _basket_repair_plan(conn, work_item_id, repo_root=repo_root)
    finally:
        conn.close()


def apply_basket_payload_repair(
    db: Path,
    mutation_lock: Path,
    work_item_id: str,
    journal_out: Path,
    *,
    repo_root: Path = REPO_ROOT,
) -> dict[str, Any]:
    if journal_out.exists():
        raise OOS2026Error(f"refusing to overwrite repair journal: {journal_out}")
    preflight = plan_basket_payload_repair(db, work_item_id, repo_root=repo_root)
    if preflight["status"] != "READY_FOR_APPLY":
        raise OOS2026Error(f"repair preflight is {preflight['status']}; refusing to mutate")

    applied_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    with FactoryMutationLock(mutation_lock, owner=f"oos-2026-basket-repair:{work_item_id}"):
        conn = sqlite3.connect(str(db), timeout=60)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute("BEGIN IMMEDIATE")
            locked = _basket_repair_plan(conn, work_item_id, repo_root=repo_root)
            if locked["before_payload_sha256"] != preflight["before_payload_sha256"]:
                raise OOS2026Error(f"{work_item_id}: payload changed after preflight")
            row = conn.execute("SELECT payload_json FROM work_items WHERE id=?", (work_item_id,)).fetchone()
            payload = json.loads(row["payload_json"] or "{}")
            payload.update(locked["basket_context"])
            payload[BASKET_REPAIR_MARKER] = {
                "applied_at_utc": applied_at,
                "manifest_sha256": locked["basket_context"]["basket_manifest_sha256"],
                "pre_image_payload_sha256": locked["before_payload_sha256"],
                "reason": BASKET_REPAIR_REASON,
                "schema_version": "qm.oos-2026-basket-payload-repair/v1",
            }
            payload["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(payload)
            new_payload_json = json.dumps(payload, sort_keys=True)
            after_sha256 = _payload_sha256(new_payload_json)
            cursor = conn.execute(
                "UPDATE work_items SET payload_json=?,updated_at=? "
                "WHERE id=? AND status='pending' AND claimed_by IS NULL AND payload_json=?",
                (new_payload_json, applied_at, work_item_id, row["payload_json"]),
            )
            if cursor.rowcount != 1:
                raise OOS2026Error(f"{work_item_id}: guarded update changed {cursor.rowcount} rows")
            journal = {
                "schema_version": "qm.oos-2026-basket-payload-repair-journal/v1",
                "applied_at_utc": applied_at,
                "reason": BASKET_REPAIR_REASON,
                "diagnostic_non_admission": True,
                "database": str(db.resolve()),
                "changed_rows": 1,
                "entry": {
                    "work_item_id": work_item_id,
                    "ea_id": locked["ea_id"],
                    "symbol": locked["symbol"],
                    "phase": locked["phase"],
                    "added_keys": locked["added_keys"],
                    "before_payload_sha256": locked["before_payload_sha256"],
                    "after_payload_sha256": after_sha256,
                    "basket_context": locked["basket_context"],
                },
            }
            journal_out.parent.mkdir(parents=True, exist_ok=True)
            journal_out.write_text(json.dumps(journal, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            conn.commit()
            return {
                "mode": "APPLY",
                "status": "APPLIED",
                "changed_rows": 1,
                "work_item_id": work_item_id,
                "after_payload_sha256": after_sha256,
                "journal": str(journal_out.resolve()),
            }
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()


# --------------------------------------------------------------------------
# OOS-2026 explicit-window repair (Astra task e544e3b8, 2026-09-04)
# --------------------------------------------------------------------------
# The campaign plan declared 2026-01-01..2026-04-06, but ``enqueue`` never wrote
# the window into the work-item payloads. farmctl's spawn builder found none,
# and terminal_worker._resolved_evidence_window substituted the default calendar
# year: all 15 completed rows measured 2024. The 40 unstarted rows were held
# with hold_code OOS_WINDOW_MISMATCH. This repair (a) patches the held pending
# rows with the plan window and releases exactly those holds, and (b) mints one
# append-only successor per mismeasured completed row and records the
# supersession in ``work_item_supersedes`` so no consumer keeps reading the 2024
# measurement as a valid oos-2026 result. Verdicts, trade streams and historical
# rows are never rewritten.
#
# Governance (review 2026-09-04): the classifier scan runs OUTSIDE the write
# transaction and outside the mutation lock; the writer uses farmctl's short
# mutation-lock busy envelope with jittered transaction retry; a governed
# pre-mutation state backup is minted before the lock and recorded in the
# ledger, the events rows and the receipt; and the receipt is published only
# after the commit returns.


def _load_campaign_plan(path: Path) -> tuple[dict[str, Any], str]:
    try:
        document = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise OOS2026Error(f"unreadable campaign plan: {path}: {exc}") from exc
    if not isinstance(document, dict):
        raise OOS2026Error(f"campaign plan root must be an object: {path}")
    if str(document.get("campaign_id") or "") != CAMPAIGN_ID:
        raise OOS2026Error(
            f"campaign plan is not {CAMPAIGN_ID}: {document.get('campaign_id')!r}"
        )
    return document, sha(path)


def _successor_work_item_id(source_id: str) -> str:
    """Deterministic successor id: a second repair run mints nothing new."""
    return str(
        uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"quantmechanica:{CAMPAIGN_ID}:window-repair:{source_id}",
        )
    )


def _row_value(row: sqlite3.Row, key: str) -> Any:
    return row[key] if key in row.keys() else None


def _measured_window(row: sqlite3.Row, payload: dict[str, Any]) -> tuple[str | None, str | None]:
    """The window a completed row actually ran, as bound at spawn time."""
    measured_from = payload.get("expected_from_date") or _row_value(row, "data_window_start")
    measured_to = payload.get("expected_to_date") or _row_value(row, "data_window_end")
    return (
        str(measured_from) if measured_from else None,
        str(measured_to) if measured_to else None,
    )


def _rerun_reason(window: dict[str, str], measured: tuple[str | None, str | None]) -> str:
    measured_from, measured_to = measured
    return (
        "OOS-2026 window mismatch: the completed run measured "
        f"{measured_from or 'UNKNOWN'}..{measured_to or 'UNKNOWN'} (default run_smoke "
        "year 2024, substituted because the payload carried no from_date/to_date) "
        f"instead of the campaign window {window['from_date']}..{window['to_date']} "
        f"declared by {CAMPAIGN_ID}; append-only successor minted by "
        f"oos_2026_confirmation repair-oos-window (Astra task {WINDOW_REPAIR_TASK_REF})"
    )


def _window_repair_audit(
    window: dict[str, str],
    *,
    at_utc: str,
    campaign_plan_path: Path,
    campaign_plan_sha256: str,
    source_work_item_id: str | None = None,
    superseded_window: tuple[str | None, str | None] | None = None,
) -> dict[str, Any]:
    """The audit block a repaired payload carries.

    ``campaign_plan_path``/``campaign_plan_sha256`` are not decoration: farmctl's
    spawn builder reads exactly these two fields back, re-hashes the plan file
    and refuses the spawn unless the payload window still equals the plan window.
    Recording the sha without the path would leave nothing to re-derive from.
    """
    audit: dict[str, Any] = {
        "at_utc": at_utc,
        "campaign_plan_path": str(campaign_plan_path),
        "campaign_plan_sha256": campaign_plan_sha256,
        "from": window["from_date"],
        "schema_version": WINDOW_REPAIR_SCHEMA,
        "task_ref": WINDOW_REPAIR_TASK_REF,
        "to": window["to_date"],
        "window_from_utc": window["window_from_utc"],
        "window_to_utc": window["window_to_utc"],
    }
    if source_work_item_id:
        audit["source_work_item_id"] = source_work_item_id
    if superseded_window is not None:
        audit["superseded_measured_window"] = {
            "from": superseded_window[0],
            "to": superseded_window[1],
        }
    return audit


def _successor_payload(
    payload: dict[str, Any],
    *,
    window: dict[str, str],
    source_id: str,
    lineage: list[str],
    measured: tuple[str | None, str | None],
    at_utc: str,
    campaign_plan_path: Path,
    campaign_plan_sha256: str,
) -> dict[str, Any]:
    successor = {
        key: value
        for key, value in payload.items()
        if key not in RUNTIME_RESIDUE_PAYLOAD_KEYS
    }
    successor.update(window)
    successor.update({
        "append_only_rerun": True,
        "append_only_rerun_of_work_item": source_id,
        "append_only_rerun_lineage_work_items": lineage,
        "historical_work_item_preserved": True,
        "rerun_reason": _rerun_reason(window, measured),
        WINDOW_REPAIR_MARKER: _window_repair_audit(
            window,
            at_utc=at_utc,
            campaign_plan_path=campaign_plan_path,
            campaign_plan_sha256=campaign_plan_sha256,
            source_work_item_id=source_id,
            superseded_window=measured,
        ),
    })
    successor["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(successor)
    return successor


def _campaign_binding_is_current(
    payload: dict[str, Any], *, campaign_plan_sha256: str
) -> bool:
    """True when the row already names the campaign plan the spawn will verify.

    Two spellings satisfy the spawn-time check: the dispatcher's
    ``diagnostic_campaign_plan_*`` keys on a freshly enqueued row, and the
    repair's ``oos_window_repair`` audit block on a patched one.
    """
    expected = campaign_plan_sha256.lower()
    marker = payload.get(WINDOW_REPAIR_MARKER)
    if isinstance(marker, dict):
        return bool(str(marker.get("campaign_plan_path") or "").strip()) and (
            str(marker.get("campaign_plan_sha256") or "").strip().lower() == expected
        )
    return bool(str(payload.get("diagnostic_campaign_plan_path") or "").strip()) and (
        str(payload.get("diagnostic_campaign_plan_sha256") or "").strip().lower() == expected
    )


def _supersedes_row(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    try:
        return conn.execute(
            "SELECT * FROM work_item_supersedes "
            "WHERE work_item_id=? AND source_encoding=?",
            (work_item_id, SUPERSEDES_SOURCE_ENCODING),
        ).fetchone()
    except sqlite3.OperationalError:
        return None


def _active_window_hold(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    try:
        return conn.execute(
            "SELECT * FROM work_item_holds "
            "WHERE work_item_id=? AND hold_code=? AND active=1",
            (work_item_id, WINDOW_HOLD_CODE),
        ).fetchone()
    except sqlite3.OperationalError:
        return None


def _window_repair_plan(
    conn: sqlite3.Connection,
    *,
    window: dict[str, str],
    campaign_plan_path: Path,
    campaign_plan_sha256: str,
    at_utc: str,
    work_item_ids: tuple[str, ...] | None = None,
) -> dict[str, Any]:
    conn.row_factory = sqlite3.Row
    requested_ids = tuple(sorted(set(work_item_ids or ())))
    where = "WHERE json_extract(payload_json,'$.diagnostic_campaign_id')=? "
    params: tuple[Any, ...] = (CAMPAIGN_ID,)
    if requested_ids:
        where += f"AND id IN ({','.join('?' for _ in requested_ids)}) "
        params += requested_ids
    rows = conn.execute(
        "SELECT * FROM work_items "
        + where
        + "ORDER BY COALESCE(json_extract(payload_json,'$.diagnostic_queue_rank'),0), created_at",
        params,
    ).fetchall()
    if requested_ids:
        found_ids = {str(row["id"]) for row in rows}
        missing_ids = sorted(set(requested_ids) - found_ids)
        if missing_ids:
            raise OOS2026Error(
                "requested work item is absent or outside the OOS-2026 campaign: "
                + ", ".join(missing_ids)
            )

    pending_patches: list[dict[str, Any]] = []
    successors: list[dict[str, Any]] = []
    unchanged: list[dict[str, Any]] = []
    skipped: list[dict[str, Any]] = []

    for row in rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError:
            payload = None
        base = {
            "work_item_id": row["id"],
            "ea_id": row["ea_id"],
            "symbol": row["symbol"],
            "status": row["status"],
            "verdict": _row_value(row, "verdict"),
        }
        if not isinstance(payload, dict):
            skipped.append({**base, "reason": "payload_not_an_object"})
            continue
        if payload.get("diagnostic_non_admission") is not True:
            skipped.append({**base, "reason": "outside_diagnostic_non_admission_lane"})
            continue

        if row["status"] == "pending":
            if _row_value(row, "claimed_by") is not None:
                skipped.append({**base, "reason": "pending_row_is_claimed"})
                continue
            contradictions = {
                key: {"actual": payload[key], "expected": window[key]}
                for key in WINDOW_KEYS
                if key in payload and payload[key] != window[key]
            }
            if contradictions:
                skipped.append({
                    **base,
                    "reason": "pending_window_contradiction",
                    "contradictions": contradictions,
                })
                continue
            missing = [key for key in WINDOW_KEYS if key not in payload]
            binding_stale = not _campaign_binding_is_current(
                payload, campaign_plan_sha256=campaign_plan_sha256
            )
            hold = _active_window_hold(conn, str(row["id"]))
            if not missing and not binding_stale and hold is None:
                unchanged.append({**base, "reason": "already_repaired"})
                continue
            pending_patches.append({
                **base,
                "before": {key: payload.get(key) for key in WINDOW_KEYS},
                "after": {key: window[key] for key in WINDOW_KEYS},
                "added_keys": sorted(
                    missing + ([WINDOW_REPAIR_MARKER] if binding_stale else [])
                ),
                "payload_change": bool(missing or binding_stale),
                "before_payload_sha256": _payload_sha256(row["payload_json"]),
                "hold_release": hold is not None,
                "hold_code": WINDOW_HOLD_CODE if hold is not None else None,
            })
            continue

        if row["status"] == "done":
            measured = _measured_window(row, payload)
            if measured == (window["from_date"], window["to_date"]):
                unchanged.append({
                    **base,
                    "reason": "done_window_matches_plan",
                    "measured_window": {"from": measured[0], "to": measured[1]},
                })
                continue
            existing_supersede = _supersedes_row(conn, str(row["id"]))
            if existing_supersede is not None:
                unchanged.append({
                    **base,
                    "reason": "supersession_already_recorded",
                    "successor_work_item_id": existing_supersede["superseded_by_work_item_id"],
                })
                continue
            prior = conn.execute(
                "SELECT id,status FROM work_items "
                "WHERE json_extract(payload_json,'$.append_only_rerun_of_work_item')=?",
                (row["id"],),
            ).fetchone()
            if prior is not None:
                unchanged.append({
                    **base,
                    "reason": "append_only_successor_exists",
                    "successor_work_item_id": prior["id"],
                    "successor_status": prior["status"],
                })
                continue
            successor_id = _successor_work_item_id(str(row["id"]))
            if conn.execute(
                "SELECT 1 FROM work_items WHERE id=?", (successor_id,)
            ).fetchone():
                unchanged.append({
                    **base,
                    "reason": "successor_id_already_present",
                    "successor_work_item_id": successor_id,
                })
                continue
            lineage = farmctl._append_only_rerun_lineage_work_item_ids(conn, row)
            successor_payload = _successor_payload(
                payload,
                window=window,
                source_id=str(row["id"]),
                lineage=lineage,
                measured=measured,
                at_utc=at_utc,
                campaign_plan_path=campaign_plan_path,
                campaign_plan_sha256=campaign_plan_sha256,
            )
            successors.append({
                **base,
                "successor_work_item_id": successor_id,
                "before_payload_sha256": _payload_sha256(row["payload_json"]),
                "measured_window": {"from": measured[0], "to": measured[1]},
                "before": {
                    "expected_from_date": measured[0],
                    "expected_to_date": measured[1],
                    **{key: payload.get(key) for key in WINDOW_KEYS},
                },
                "after": {key: successor_payload[key] for key in WINDOW_KEYS},
                "added_keys": sorted(set(successor_payload) - set(payload)),
                "dropped_keys": sorted(set(payload) - set(successor_payload)),
                "append_only_rerun_lineage_work_items": lineage,
                "rerun_reason": successor_payload["rerun_reason"],
                "successor_payload": successor_payload,
                "phase": row["phase"],
                "setfile_path": row["setfile_path"],
                "gate_contract_version": _row_value(row, "gate_contract_version"),
            })
            continue

        skipped.append({**base, "reason": f"status_not_repairable:{row['status']}"})

    return {
        "schema_version": WINDOW_REPAIR_SCHEMA,
        "mode": "DRY_RUN",
        "at_utc": at_utc,
        "campaign_id": CAMPAIGN_ID,
        "campaign_plan_path": str(campaign_plan_path),
        "campaign_plan_sha256": campaign_plan_sha256,
        "diagnostic_non_admission": True,
        "requested_work_item_ids": list(requested_ids) if requested_ids else None,
        "window": dict(window),
        "counts": {
            "campaign_rows": len(rows),
            "pending_to_patch": sum(1 for e in pending_patches if e["payload_change"]),
            "holds_to_release": sum(1 for e in pending_patches if e["hold_release"]),
            "done_to_succeed": len(successors),
            "unchanged": len(unchanged),
            "skipped": len(skipped),
        },
        "pending_patches": pending_patches,
        "successors": successors,
        "unchanged": unchanged,
        "skipped": skipped,
    }


def _stripped_plan(plan: dict[str, Any]) -> dict[str, Any]:
    """Receipt view: keep every decision field, drop the bulky successor payloads."""
    return {
        **plan,
        "successors": [
            {key: value for key, value in entry.items() if key != "successor_payload"}
            for entry in plan["successors"]
        ],
    }


def plan_oos_window_repair(
    db: Path,
    *,
    campaign_plan_path: Path = CAMPAIGN_PLAN_PATH,
    at_utc: str | None = None,
    work_item_ids: tuple[str, ...] | None = None,
) -> dict[str, Any]:
    """Read-only dry run: exactly what the repair would change, and nothing else."""
    campaign, campaign_plan_sha256 = _load_campaign_plan(campaign_plan_path)
    window = campaign_window(campaign)
    now = at_utc or datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    conn = sqlite3.connect(f"file:{db.resolve()}?mode=ro", uri=True, timeout=30)
    try:
        return _window_repair_plan(
            conn,
            window=window,
            campaign_plan_path=campaign_plan_path,
            campaign_plan_sha256=campaign_plan_sha256,
            at_utc=now,
            work_item_ids=work_item_ids,
        )
    finally:
        conn.close()


def _connect_under_mutation_lock(db: Path) -> sqlite3.Connection:
    """Open the farm DB with the SHORT busy envelope the mutation lock demands.

    farmctl.py:1312-1324 (2026-09-02): "a governed writer that already holds the
    global factory mutation lock must never wait minutes for the SQLite write
    lock - every idle worker declines claims while the lock is held".  A long
    ``timeout=`` here would reproduce the 09:28-09:36Z fleet starvation, so the
    writer uses ``MUTATION_LOCK_DB_TIMEOUT_SECONDS`` and the caller retries the
    whole transaction after jittered backoff instead of sleeping in the C call.
    """
    conn = sqlite3.connect(str(db), timeout=farmctl.MUTATION_LOCK_DB_TIMEOUT_SECONDS)
    conn.row_factory = sqlite3.Row
    return farmctl.configure_sqlite_connection(conn)


def _record_hold_release_ledger(
    conn: sqlite3.Connection,
    *,
    work_item_id: str,
    released_at: str,
    release_note: str,
    backup_path: str | None,
    backup_sha256: str | None,
) -> tuple[bool, str]:
    """Mirror farmctl.release_work_item_hold's append-only ledger row.

    The canonical writer swallows exactly one failure -- a duplicate
    idempotency key (``IntegrityError``) -- and lets every other SQLite error
    propagate, so a ledger-schema drift can never release a hold in silence.
    It also records the pre-mutation backup anchor in ``detail_json``; without
    it a released hold has no rollback pointer.
    """
    row = conn.execute(
        "SELECT status,verdict FROM work_items WHERE id=?", (work_item_id,)
    ).fetchone()
    status = row["status"] if row is not None else None
    verdict = row["verdict"] if row is not None else None
    ledger_key = f"hold_release:{work_item_id}:{WINDOW_HOLD_CODE}:{released_at}"
    detail = {
        "hold_code": WINDOW_HOLD_CODE,
        "expected_hold_code": WINDOW_HOLD_CODE,
        "released_at": released_at,
        "released_by": SUPERSEDES_RECORDED_BY,
    }
    if backup_path:
        detail["backup_path"] = backup_path
    if backup_sha256:
        detail["backup_sha256"] = backup_sha256
    try:
        conn.execute(
            "INSERT INTO work_item_transition_ledger("
            "idempotency_key, ts, work_item_id, action, from_status, to_status,"
            " from_verdict, to_verdict, reason, run_id, detail_json)"
            " VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            (
                ledger_key, released_at, work_item_id, "work_item_hold_released",
                status, status, verdict, verdict, release_note, None,
                json.dumps(detail, sort_keys=True),
            ),
        )
    except sqlite3.IntegrityError:
        return False, ledger_key
    return True, ledger_key


def _write_receipt_atomically(out: Path, receipt: dict[str, Any]) -> None:
    """Publish the receipt only once the transaction has actually committed.

    Writing it inside the transaction produced an on-disk artifact claiming 95
    mutations for a transaction that could still roll back -- and the overwrite
    guard then blocked the retry.  Temp file + os.replace keeps the receipt
    atomic and truthful.
    """
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_name(out.name + ".tmp")
    tmp.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(tmp, out)


def _apply_window_repair_locked(
    conn: sqlite3.Connection,
    *,
    plan: dict[str, Any],
    window: dict[str, str],
    applied_at: str,
    release_note: str,
    campaign_plan_path: Path,
    campaign_plan_sha256: str,
    backup_path: str | None,
    backup_sha256: str | None,
    receipt_path: Path,
) -> dict[str, Any]:
    """Mutate exactly the rows the preflight named, addressed by primary key.

    Deliberately NO classifier scan in here: the preflight already decided, and
    re-running its unindexed ``json_extract`` scan inside ``BEGIN IMMEDIATE``
    held the exclusive write lock for ~30 s on an uncontended copy.  Every row
    is re-read by id and re-verified against its recorded payload sha, so a row
    that moved between preflight and lock fails the apply closed instead of
    being rewritten blind.
    """
    patched: list[str] = []
    released: list[str] = []
    minted: list[str] = []
    superseded: list[dict[str, str]] = []

    for entry in plan["pending_patches"]:
        work_item_id = str(entry["work_item_id"])
        row = conn.execute(
            "SELECT payload_json,status,claimed_by FROM work_items WHERE id=?",
            (work_item_id,),
        ).fetchone()
        if row is None:
            raise OOS2026Error(f"{work_item_id}: row vanished between preflight and lock")
        if _payload_sha256(row["payload_json"]) != entry["before_payload_sha256"]:
            raise OOS2026Error(f"{work_item_id}: payload changed between preflight and lock")
        if row["status"] != "pending" or row["claimed_by"] is not None:
            raise OOS2026Error(
                f"{work_item_id}: no longer an unclaimed pending row "
                f"(status={row['status']!r}, claimed_by={row['claimed_by']!r})"
            )
        if entry["payload_change"]:
            payload = json.loads(row["payload_json"] or "{}")
            payload.update(window)
            payload[WINDOW_REPAIR_MARKER] = _window_repair_audit(
                window,
                at_utc=applied_at,
                campaign_plan_path=campaign_plan_path,
                campaign_plan_sha256=campaign_plan_sha256,
            )
            payload["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(payload)
            new_payload_json = json.dumps(payload, sort_keys=True)
            cursor = conn.execute(
                "UPDATE work_items SET payload_json=?,updated_at=? "
                "WHERE id=? AND status='pending' AND claimed_by IS NULL "
                "AND payload_json=?",
                (new_payload_json, applied_at, work_item_id, row["payload_json"]),
            )
            if cursor.rowcount != 1:
                raise OOS2026Error(
                    f"{work_item_id}: guarded payload update changed {cursor.rowcount} rows"
                )
            entry["after_payload_sha256"] = _payload_sha256(new_payload_json)
            patched.append(work_item_id)
        if entry["hold_release"]:
            cursor = conn.execute(
                "UPDATE work_item_holds "
                "SET active=0, updated_at=?, released_at=?, release_note=? "
                "WHERE work_item_id=? AND hold_code=? AND active=1",
                (applied_at, applied_at, release_note, work_item_id, WINDOW_HOLD_CODE),
            )
            if cursor.rowcount != 1:
                raise OOS2026Error(
                    f"{work_item_id}: hold release CAS changed {cursor.rowcount} rows"
                )
            ledger_written, ledger_key = _record_hold_release_ledger(
                conn,
                work_item_id=work_item_id,
                released_at=applied_at,
                release_note=release_note,
                backup_path=backup_path,
                backup_sha256=backup_sha256,
            )
            farmctl.event(conn, "work_item", work_item_id, "work_item_hold_released", {
                "hold_code": WINDOW_HOLD_CODE,
                "release_note": release_note,
                "released_at": applied_at,
                "backup_path": backup_path,
                "backup_sha256": backup_sha256,
                "ledger_idempotency_key": ledger_key,
            })
            entry["release_note"] = release_note
            entry["released_at"] = applied_at
            entry["ledger_written"] = ledger_written
            entry["ledger_idempotency_key"] = ledger_key
            released.append(work_item_id)

    for entry in plan["successors"]:
        source_id = str(entry["work_item_id"])
        successor_id = str(entry["successor_work_item_id"])
        source = conn.execute(
            "SELECT payload_json,status FROM work_items WHERE id=?", (source_id,)
        ).fetchone()
        if source is None:
            raise OOS2026Error(f"{source_id}: row vanished between preflight and lock")
        if _payload_sha256(source["payload_json"]) != entry["before_payload_sha256"]:
            raise OOS2026Error(f"{source_id}: payload changed between preflight and lock")
        if source["status"] != "done":
            raise OOS2026Error(
                f"{source_id}: no longer a completed row (status={source['status']!r})"
            )
        if conn.execute("SELECT 1 FROM work_items WHERE id=?", (successor_id,)).fetchone():
            raise OOS2026Error(f"{successor_id}: successor already present under lock")
        conn.execute(
            "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,"
            "status,attempt_count,payload_json,created_at,updated_at,"
            "gate_contract_version) VALUES(?,'backtest',?,?,?,?,'pending',0,?,?,?,?)",
            (
                successor_id, entry["phase"], entry["ea_id"], entry["symbol"],
                entry["setfile_path"],
                json.dumps(entry["successor_payload"], sort_keys=True),
                applied_at, applied_at, entry["gate_contract_version"],
            ),
        )
        minted.append(successor_id)
        # The forward pointer.  Without it every surface keyed on
        # (diagnostic_campaign_id, status='done') keeps reading the 2024
        # measurement as a valid oos-2026 result, indistinguishable from a
        # correct one except by re-deriving expected_from_date.
        measured = entry["measured_window"]
        supersede_reason = (
            "OOS-2026 window mismatch: measured "
            f"{measured['from'] or 'UNKNOWN'}..{measured['to'] or 'UNKNOWN'} instead of "
            f"the campaign window {window['from_date']}..{window['to_date']}; superseded "
            f"by the append-only rerun (Astra task {WINDOW_REPAIR_TASK_REF})"
        )
        conn.execute(
            "INSERT INTO work_item_supersedes("
            "work_item_id,superseded_by_work_item_id,reason,source_encoding,"
            "evidence_path,recorded_by,recorded_at) VALUES(?,?,?,?,?,?,?)",
            (
                source_id, successor_id, supersede_reason, SUPERSEDES_SOURCE_ENCODING,
                str(receipt_path), SUPERSEDES_RECORDED_BY, applied_at,
            ),
        )
        farmctl.event(conn, "work_item", source_id, "work_item_superseded", {
            "superseded_by_work_item_id": successor_id,
            "reason": supersede_reason,
            "source_encoding": SUPERSEDES_SOURCE_ENCODING,
            "evidence_path": str(receipt_path),
            "recorded_by": SUPERSEDES_RECORDED_BY,
            "campaign_plan_sha256": campaign_plan_sha256,
        })
        entry["supersede_reason"] = supersede_reason
        superseded.append({
            "work_item_id": source_id,
            "superseded_by_work_item_id": successor_id,
        })

    return {
        **_stripped_plan(plan),
        "mode": "APPLY",
        "applied_at_utc": applied_at,
        "patched_work_items": patched,
        "released_holds": released,
        "minted_successors": minted,
        "superseded_work_items": superseded,
        "state_backup": {"path": backup_path, "sha256": backup_sha256},
    }


def apply_oos_window_repair(
    db: Path,
    mutation_lock: Path,
    out: Path,
    *,
    campaign_plan_path: Path = CAMPAIGN_PLAN_PATH,
    farm_root: Path = FARM_ROOT,
    work_item_ids: tuple[str, ...] | None = None,
) -> dict[str, Any]:
    """Apply the repair: governed backup, short-lock transaction, receipt after commit."""
    if out.exists():
        raise OOS2026Error(f"refusing to overwrite repair receipt: {out}")
    campaign, campaign_plan_sha256 = _load_campaign_plan(campaign_plan_path)
    window = campaign_window(campaign)
    applied_at = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
    # Classification first, OUTSIDE the mutation lock and outside any write
    # transaction: it is an unindexed full-table scan of work_items (~15 s on
    # the live DB).  Under the lock only the named rows are touched, by id.
    plan = plan_oos_window_repair(
        db,
        campaign_plan_path=campaign_plan_path,
        at_utc=applied_at,
        work_item_ids=work_item_ids,
    )
    release_note = (
        f"OOS-2026 explicit window contract repaired: {window['from_date']}.."
        f"{window['to_date']} written into the payload; "
        f"campaign_plan_sha256={campaign_plan_sha256}; "
        f"Astra task {WINDOW_REPAIR_TASK_REF}"
    )
    mutates = bool(
        plan["counts"]["pending_to_patch"]
        or plan["counts"]["holds_to_release"]
        or plan["counts"]["done_to_succeed"]
    )
    backup_path: str | None = None
    backup_sha256: str | None = None
    if mutates:
        # Pre-mutation rollback anchor, minted BEFORE the fleet-wide lock so the
        # (slow) online backup never runs inside it -- exactly how
        # farmctl.release_work_item_hold orders the same two steps.  A no-op
        # apply mints nothing, so a refused repair cannot litter the directory.
        backup, digest = farmctl._governed_state_backup(farm_root, WINDOW_REPAIR_MARKER)
        backup_path, backup_sha256 = str(backup), digest

    with FactoryMutationLock(mutation_lock, owner=f"oos-2026-window-repair:{CAMPAIGN_ID}"):
        def _transaction() -> dict[str, Any]:
            conn = _connect_under_mutation_lock(db)
            try:
                if plan["successors"]:
                    # executescript commits implicitly: DDL before BEGIN.
                    farmctl.ensure_work_item_supersedes_schema(conn)
                conn.execute("BEGIN IMMEDIATE")
                receipt = _apply_window_repair_locked(
                    conn,
                    plan=plan,
                    window=window,
                    applied_at=applied_at,
                    release_note=release_note,
                    campaign_plan_path=campaign_plan_path,
                    campaign_plan_sha256=campaign_plan_sha256,
                    backup_path=backup_path,
                    backup_sha256=backup_sha256,
                    receipt_path=out,
                )
                conn.commit()
                return receipt
            except Exception:
                conn.rollback()
                raise
            finally:
                conn.close()

        receipt = farmctl.retry_sqlite_busy(
            _transaction, attempts=farmctl.MUTATION_LOCK_DB_ATTEMPTS
        )
        receipt["database"] = str(db.resolve())
        receipt["receipt_path"] = str(out.resolve())
        # Only now, with the transaction committed, is the receipt true.
        _write_receipt_atomically(out, receipt)
    return receipt


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__); sub=parser.add_subparsers(dest="command",required=True)
    for name in ("plan","apply"):
        p=sub.add_parser(name); p.add_argument("--router-task-id",required=True)
    repair=sub.add_parser("repair-basket-payload")
    repair.add_argument("--work-item-id",required=True)
    repair.add_argument("--db",type=Path,default=FARM_DB)
    repair.add_argument("--mutation-lock",type=Path,default=FACTORY_MUTATION_LOCK)
    repair.add_argument("--journal-out",type=Path)
    repair.add_argument("--apply",action="store_true")
    window_repair=sub.add_parser(
        "repair-oos-window",
        help="Dry-run by default: patch the campaign window into held pending rows "
             "and mint append-only successors for rows measured on the wrong window",
    )
    window_repair.add_argument("--db",type=Path,default=FARM_DB)
    window_repair.add_argument("--campaign-plan",type=Path,default=CAMPAIGN_PLAN_PATH)
    window_repair.add_argument("--mutation-lock",type=Path,default=FACTORY_MUTATION_LOCK)
    window_repair.add_argument("--out",type=Path,help="receipt path (required with --apply)")
    window_repair.add_argument("--farm-root",type=Path,default=FARM_ROOT,
                               help="farm root the pre-mutation state backup is taken from")
    window_repair.add_argument(
        "--work-item-id",
        action="append",
        dest="work_item_ids",
        help="repair only this exact campaign work item (repeatable; fail-closed)",
    )
    window_repair.add_argument("--apply",action="store_true")
    args=parser.parse_args()
    if args.command == "repair-oos-window":
        if args.apply:
            if not args.out:
                raise OOS2026Error("--apply requires --out")
            result=apply_oos_window_repair(
                args.db,args.mutation_lock,args.out,campaign_plan_path=args.campaign_plan,
                farm_root=args.farm_root,work_item_ids=tuple(args.work_item_ids or ()) or None,
            )
        else:
            result=_stripped_plan(
                plan_oos_window_repair(
                    args.db,campaign_plan_path=args.campaign_plan,
                    work_item_ids=tuple(args.work_item_ids or ()) or None,
                )
            )
            if args.out:
                args.out.parent.mkdir(parents=True,exist_ok=True)
                args.out.write_text(
                    json.dumps(result,indent=2,sort_keys=True)+"\n",encoding="utf-8",
                )
                result={**result,"receipt_path":str(args.out.resolve())}
    elif args.command == "repair-basket-payload":
        if args.apply:
            if not args.journal_out:
                raise OOS2026Error("--apply requires --journal-out")
            result=apply_basket_payload_repair(
                args.db,args.mutation_lock,args.work_item_id,args.journal_out,
            )
        else:
            result=plan_basket_payload_repair(args.db,args.work_item_id)
    else:
        campaign=prepare(args.router_task_id)
        result={"campaign":campaign} if args.command=="plan" else {"campaign":campaign,"enqueue":enqueue(campaign)}
    print(json.dumps(result,indent=2,sort_keys=True)); return 0


if __name__ == "__main__": raise SystemExit(main())
