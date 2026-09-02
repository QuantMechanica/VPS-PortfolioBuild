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

FARM_ROOT = Path(r"D:\QM\strategy_farm")
REPO_ROOT = Path(r"C:\QM\repo")
PULSE = Path(r"D:\QM\reports\state\live_book_pulse.json")
LIVE_EXPERTS = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs")
CALENDAR_MANIFEST = Path(r"D:\QM\data\news_calendar\q09_bundles\q09cal-20150101-20260809-0bb19b5bb9790b76\manifest.json")
CALENDAR_COMMON = "QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv"
ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\oos_2026_confirmation_v1")
CAMPAIGN_ID = "oos-2026-confirmation-v1"
WINDOW_SOURCE = "oos_2026"
FROM_UTC = "2026-01-01T00:00:00Z"
TO_UTC = "2026-04-06T23:59:59Z"
SEED = 20250301
ALLOWED = ["T1", "T2", "T3", "T4", "T5"]
AVOID = ["T6", "T7", "T8", "T9", "T10"]

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
            payload["q09_dispatch_binding_sha256"]=q09._dispatch_binding_sha256(payload)
            conn.execute("INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,payload_json,created_at,updated_at) VALUES(?,'backtest','Q09_NEWS',?,?,?,'pending',0,?,?,?)",
                         (row["work_item_id"],row["ea_id"],row["symbol"],row["baseline_setfile_path"],json.dumps(payload,sort_keys=True),now,now))
            inserted.append(row["work_item_id"])
        conn.commit()
    receipt={"schema_version":"qm.oos-2026-enqueue/v1","diagnostic_non_admission":True,"inserted":inserted,
             "existing":existing,"count":55,"queue_policy":"behind census","enqueued_at_utc":now}
    path=ARTIFACT_ROOT/"enqueue_receipt.json"; write_json(path,receipt)
    return {**receipt,"receipt_path":str(path),"receipt_sha256":sha(path)}


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__); sub=parser.add_subparsers(dest="command",required=True)
    for name in ("plan","apply"):
        p=sub.add_parser(name); p.add_argument("--router-task-id",required=True)
    args=parser.parse_args(); campaign=prepare(args.router_task_id)
    result={"campaign":campaign} if args.command=="plan" else {"campaign":campaign,"enqueue":enqueue(campaign)}
    print(json.dumps(result,indent=2,sort_keys=True)); return 0


if __name__ == "__main__": raise SystemExit(main())
