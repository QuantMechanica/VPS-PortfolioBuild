#!/usr/bin/env python3
"""Plan/enqueue the 2026-Q1 single-window, non-admission regime diagnostic."""

from __future__ import annotations

import argparse
import hashlib
import json
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
    with farmctl.connect(FARM_ROOT) as conn:
        conn.execute("BEGIN IMMEDIATE")
        for row in campaign["runs"]:
            if conn.execute("SELECT 1 FROM work_items WHERE id=?",(row["work_item_id"],)).fetchone():
                existing.append(row["work_item_id"]); continue
            payload={"window_source":WINDOW_SOURCE,"diagnostic_non_admission":True,"diagnostic_contract":q09.DIAGNOSTIC_CONTRACT,
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
             "existing":existing,"count":55,"queue_policy":"behind census","enqueued_at_utc":now}
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
    args=parser.parse_args()
    if args.command == "repair-basket-payload":
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
