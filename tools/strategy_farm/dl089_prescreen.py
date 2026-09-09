"""OWNER-declared B5/B2 staging. No database writes outside census.enqueue.

The full 154-arm/seven-year declaration survives. Receipts are unmeasured
dispositions; existing rows and their evidence are never rewritten.
"""
from __future__ import annotations

import datetime as dt
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import sqlite3

SCHEMA = "qm.dl089-prescreen/v1"
RECEIPT_SCHEMA = "qm.dl089-skipped-prescreen/v1"
VERDICT = "SKIPPED_PRESCREEN"
DECISION = "OWNER-DEC-D1-PRESCREEN-20260905"
YEARS = (2019, 2020)
THRESHOLD = 5
ROOT = Path(__file__).resolve().parents[2]
BAR_ROOT = Path("D:/QM/mt5/T_Export/MQL5/Files")
MANIFEST_ROOT = Path("D:/QM/reports/dl089_prescreen")
AUTHORITY = ROOT / "decisions/2026-09-02_owner_receipts_ceo_asks.md"
RETIREMENT_DECISION = "CEO-DEC-PATTERN-REPAIR-20260909"
# B2 tests net profit, not the sealed R2DD quorum. B5 is not a proof that
# an arm cannot pass that quorum either. Retain v1 for evidence replay only.
# No environment variable can opt a production writer back into this policy.
RETIRED = True


def enabled() -> bool:
    return not RETIRED and os.environ.get("QM_DL089_PRESCREEN", "0").strip() == "1"


def digest(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def create_contract(symbol: str, protected_years=(), *, bars_root=BAR_ROOT,
                    manifest_root=MANIFEST_ROOT, authority=AUTHORITY) -> dict:
    if RETIRED:
        raise ValueError("B2/B5 prescreen retired: " + RETIREMENT_DECISION)
    if not any(DECISION in line and "| 13 |" in line for line in authority.read_text(encoding="utf-8-sig").splitlines()):
        raise ValueError("prescreen OWNER receipt missing")
    if not symbol.endswith(".DWX") or any(c in symbol for c in "/\\:"):
        raise ValueError("invalid D1 export symbol")
    bars = Path(bars_root) / (symbol + "_D1.csv")
    manifest = {"schema": SCHEMA, "decision_id": DECISION, "safe_to_skip": True,
                "timestamp_basis": "MT5_SERVER_CIVIL_TIME", "symbol": symbol,
                "bars_path": str(bars.resolve()), "bars_sha256": sha(bars),
                "counter_sha256": sha(ROOT / "tools/strategy_farm/research/pattern_fire_count.py"),
                "authority_path": str(authority.resolve()), "authority_sha256": sha(authority)}
    manifest_root = Path(manifest_root); manifest_root.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    path = manifest_root / f"manifest_{stamp}.json"
    with path.open("x", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2); f.write("\n")
    contract = {"schema": SCHEMA, "decision_id": DECISION, "stage1_years": list(YEARS),
                "threshold": THRESHOLD, "net_profit_relative_uplift": "0.05",
                "relative_base_rule": "STRICTLY_POSITIVE_BASELINE_AS_EXISTING_SELECTOR",
                "declared_trial_count": 154, "protected_years": sorted(set(protected_years)),
                "manifest_path": str(path.resolve()), "manifest_sha256": sha(path)}
    contract["contract_sha256"] = digest(contract)
    return contract


def validate_contract_shape(contract: dict) -> None:
    unsigned = {k:v for k,v in contract.items() if k != "contract_sha256"}
    if (contract.get("schema") != SCHEMA or contract.get("decision_id") != DECISION
            or contract.get("stage1_years") != list(YEARS) or contract.get("threshold") != THRESHOLD
            or contract.get("declared_trial_count") != 154
            or contract.get("net_profit_relative_uplift") != "0.05"
            or contract.get("relative_base_rule") != "STRICTLY_POSITIVE_BASELINE_AS_EXISTING_SELECTOR"
            or not isinstance(contract.get("protected_years"), list)
            or any(type(y) is not int or y not in range(2019,2026) for y in contract.get("protected_years", []))
            or not isinstance(contract.get("manifest_path"),str)
            or len(str(contract.get("manifest_sha256", ""))) != 64
            or digest(unsigned) != contract.get("contract_sha256")):
        raise ValueError("prescreen contract mismatch")


def validate_contract(contract: dict, *, verify_bars: bool = True) -> dict:
    validate_contract_shape(contract)
    path = Path(contract["manifest_path"])
    if sha(path) != contract["manifest_sha256"]:
        raise ValueError("prescreen manifest hash mismatch")
    manifest = json.loads(path.read_text(encoding="utf-8"))
    if manifest.get("safe_to_skip") is not True or manifest.get("decision_id") != DECISION:
        raise ValueError("prescreen manifest lacks skip authority")
    if verify_bars and sha(Path(manifest["bars_path"])) != manifest["bars_sha256"]:
        raise ValueError("D1 export changed after manifest")
    if verify_bars and sha(ROOT / "tools/strategy_farm/research/pattern_fire_count.py") != manifest["counter_sha256"]:
        raise ValueError("counter changed after manifest")
    return manifest


def staged_keys(ledger: dict) -> set[str] | None:
    if not ledger.get("prescreen_contract"):
        return None
    # Claim/scheduling paths validate the sealed small contract, without D1 I/O.
    c = ledger["prescreen_contract"]
    validate_contract_shape(c)
    keys = ledger.get("prescreen_admitted_cell_keys")
    if not isinstance(keys, list) or len(keys) != len(set(keys)):
        raise ValueError("staged admission keys invalid")
    declared = ledger.get("cells") or []
    key_set = set(keys)
    if key_set - {cell["cell_key"] for cell in declared}:
        raise ValueError("staged admission contains undeclared keys")
    for arm in {cell["arm"] for cell in declared}:
        gap = False
        for cell in sorted((c for c in declared if c["arm"] == arm),key=lambda c:c["year"]):
            if cell["cell_key"] not in key_set: gap = True
            elif gap: raise ValueError("staged admission skips an earlier year")
    return set(keys)


def measured(row) -> dict | None:
    if not row or row["status"] != "done" or row["verdict"] != "MEASURED":
        return None
    path = Path(row["evidence_path"]); summary = json.loads(path.read_text(encoding="utf-8-sig"))
    runs = [r for r in summary.get("runs", []) if r.get("status") == "OK"]
    if len(runs) != 1:
        raise ValueError("prescreen needs exactly one native baseline/arm run")
    run = runs[0]; report = Path(run["report_canonical_path"])
    if sha(report) != run["report_sha256"]:
        raise ValueError("prescreen native report hash mismatch")
    net = Decimal(str(run["net_profit"]))
    if not net.is_finite():
        raise ValueError("nonfinite prescreen net profit")
    return {"work_item_id": row["id"], "summary_path": str(path), "summary_sha256": sha(path),
            "report_path": str(report), "report_sha256": sha(report), "net_profit": str(net)}


def qualifies(arm: dict | None, baseline: dict | None) -> bool:
    if not arm or not baseline:
        return False
    b, a = Decimal(baseline["net_profit"]), Decimal(arm["net_profit"])
    return b > 0 and a - b >= Decimal("0.05") * b


def plan_admission(plan: dict, conn: sqlite3.Connection, contract: dict, *, counts_reader=None, ledger=None) -> dict:
    manifest = validate_contract(contract, verify_bars=enabled())
    if manifest["symbol"] != plan["symbol"]:
        raise ValueError("prescreen manifest symbol mismatch")
    if counts_reader is None:
        try:
            from research import pattern_fire_count as counter
        except ModuleNotFoundError:
            try:
                from tools.strategy_farm.research import pattern_fire_count as counter
            except ModuleNotFoundError:
                from research import pattern_fire_count as counter  # script-style import (sys.path = tools/strategy_farm)
        def counts_reader(year, baseline):
            result = counter.count_program(plan["program_id"], plan["symbol"],
                {year:Path(baseline["report_path"])}, Path(manifest["bars_path"]))
            return result["counts_by_year"][str(year)]
    cells = plan["cells"]; by = {(int(c["year"]),c["arm"]):c for c in cells}
    rows = {}; metrics = {}; reruns = ((ledger or {}).get("driver") or {}).get("reruns") or {}
    for cell in cells:
        row = conn.execute("SELECT id,status,verdict,evidence_path,payload_json FROM work_items WHERE id=?",(cell["work_item_id"],)).fetchone()
        if row:
            value = dict(zip(("id","status","verdict","evidence_path","payload_json"),row)); rows[cell["cell_key"]] = value
            for wid in reruns.get(cell["cell_key"], []):
                newer = conn.execute("SELECT id,status,verdict,evidence_path,payload_json FROM work_items WHERE id=?",(wid,)).fetchone()
                if newer:value = dict(zip(("id","status","verdict","evidence_path","payload_json"),newer))
            metrics[(cell["year"],cell["arm"])] = value
    stage1_complete = all(metrics.get(k,{}).get("status") == "done" and metrics[k].get("verdict") in {"MEASURED","SKIPPED_EXCLUDED",VERDICT}
                          for k in by if k[0] in YEARS)
    metric_cache = {}
    def metric(key):
        if key not in metric_cache: metric_cache[key] = measured(metrics.get(key))
        return metric_cache[key]
    counts = {}; output = []
    for cell in cells:
        year, arm = int(cell["year"]), cell["arm"]
        action, reason, proof, fire = "WAIT", "BASELINE_PENDING", [], None
        if cell["cell_key"] in rows:
            action, reason = "EXISTING", "IMMUTABLE_EXISTING_ROW"
        elif year in contract["protected_years"] or not enabled():
            action, reason = "ENQUEUE", ("PRESCREEN_RETIRED" if RETIRED else "LEGACY_OR_KILL_SWITCH")
        elif year not in YEARS and not stage1_complete:
            reason = "STAGE1_PENDING"
        elif arm == "baseline":
            action, reason = "ENQUEUE", "ANNUAL_BASELINE"
        else:
            if year not in YEARS:
                pairs = [(metric((y,arm)),metric((y,"baseline"))) for y in YEARS]
                proof = [m for pair in pairs for m in pair if m]
                if not all(qualifies(a,b) for a,b in pairs):
                    action, reason = "SKIP", "B2_NOT_QUALIFIED"
            if action != "SKIP":
                baseline = metric((year,"baseline"))
                if baseline:
                    if year not in counts: counts[year] = counts_reader(year,baseline)
                    raw = counts[year].get(arm)
                    if type(raw) is not int or raw < 0: raise ValueError("missing/invalid fire count")
                    fire = raw; proof = [*proof,baseline]
                    action, reason = ("SKIP","B5_BELOW_THRESHOLD") if fire < THRESHOLD else ("ENQUEUE","B5_ADMITTED")
        output.append({"cell":cell,"action":action,"reason":reason,"fire_count":fire,"proof":proof})
    return {"stage1_complete":stage1_complete,"manifest":manifest,"decisions":output}


def skip_receipt(decision: dict, plan: dict, contract: dict, manifest: dict) -> dict:
    cell = decision["cell"]
    return {"schema":RECEIPT_SCHEMA,"decision_id":DECISION,"disposition":"unmeasured_prescreen",
            "program_id":plan["program_id"],"cell_key":cell["cell_key"],"work_item_id":cell["work_item_id"],
            "year":cell["year"],"arm":cell["arm"],"declared_trial_count":154,
            "reason":decision["reason"],"fire_count":decision["fire_count"],"threshold":THRESHOLD,
            "tool_version":SCHEMA,"tool_sha256":sha(Path(__file__)),"manifest_path":contract["manifest_path"],
            "counter_sha256":manifest["counter_sha256"],
            "manifest_sha256":contract["manifest_sha256"],"bars_sha256":manifest["bars_sha256"],
            "contract_sha256":contract["contract_sha256"],"proof":decision["proof"]}


def validate_receipt(path: Path, payload: dict) -> dict:
    binding = payload["skipped_prescreen"]
    if sha(path) != binding["receipt_sha256"]: raise ValueError("prescreen receipt hash mismatch")
    r = json.loads(path.read_text())
    if (r.get("schema") != RECEIPT_SCHEMA or r.get("decision_id") != DECISION
            or r.get("cell_key") != payload["cell_key"] or r.get("program_id") != payload["program_id"]
            or r.get("declared_trial_count") != 154 or r.get("threshold") != THRESHOLD
            or r.get("disposition") != "unmeasured_prescreen"):
        raise ValueError("prescreen receipt identity mismatch")
    if r["reason"] == "B5_BELOW_THRESHOLD":
        if type(r.get("fire_count")) is not int or not 0 <= r["fire_count"] < THRESHOLD:
            raise ValueError("invalid B5 count proof")
    elif r["reason"] != "B2_NOT_QUALIFIED": raise ValueError("unknown prescreen reason")
    return r


def enqueue_staged(census, plan: dict, *, db_path: Path, ledger_path: Path,
                   harness_id: str, q02_ea_id=None, parent_work_item_id=None,
                   declaration_sha256=None, runner_revision=None) -> dict:
    conn = sqlite3.connect(db_path, timeout=60)
    try:
        harness = census._harness_pass(conn,harness_id)
        q02 = census._q02_pass(conn,q02_ea_id or plan["ea_id"])
        old = json.loads(ledger_path.read_text()) if ledger_path.exists() else {}
        if old and (old.get("program_id") != plan["program_id"]
                    or old.get("q12_work_item_id") != parent_work_item_id
                    or old.get("q12_declaration_sha256") != declaration_sha256):
            raise ValueError("staged enqueue cannot rebind program owner")
        existing = {}
        for cell in plan["cells"]:
            row = conn.execute("SELECT phase,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE id=?",(cell["work_item_id"],)).fetchone()
            if row:
                payload = json.loads(row[4]); expected = (census.PHASE,plan["ea_id"],plan["symbol"],cell["setfile_path"],cell["cell_key"])
                if (*row[:4],payload.get("cell_key")) != expected:
                    raise ValueError("staged enqueue identity collision")
                existing[cell["cell_key"]] = cell
        contract = old.get("prescreen_contract") or plan.get("prescreen_contract")
        if not contract:
            contract = create_contract(plan["symbol"],{c["year"] for c in existing.values()})
        admission = plan_admission(plan,conn,contract,ledger=old)
        ledger = {**plan,**old,"prescreen_contract":contract,"cells":plan["cells"],
                  "q12_work_item_id":parent_work_item_id,"q12_declaration_sha256":declaration_sha256,
                  "matrix_runner_revision":runner_revision,"harness_evidence":harness,"q02_precondition":q02}
        inserted = skipped = 0; now = dt.datetime.now(dt.timezone.utc).isoformat()
        conn.execute("BEGIN IMMEDIATE")
        for choice in admission["decisions"]:
            action,cell = choice["action"],choice["cell"]
            if action in {"WAIT","EXISTING"}: continue
            payload = {"schema":census.SCHEMA,"program_id":plan["program_id"],
                       **{k:cell[k] for k in ("cell_key","year","arm","direction","predicate_id","from_date","to_date")},
                       "host_timeframe":plan["timeframe"],"opt_census_pool":True,"declared_trial_count":154,
                       "planned_trials":1085,"ledger_path":str(ledger_path.resolve()),
                       "q12_work_item_id":parent_work_item_id,"q12_declaration_sha256":declaration_sha256,
                       "matrix_runner_revision":runner_revision}
            payload["prescreen_admission"] = {
                "decision_id":DECISION,"contract_sha256":contract["contract_sha256"],
                "admission_policy_decision_id":RETIREMENT_DECISION if RETIRED else DECISION,
                "manifest_sha256":contract["manifest_sha256"],"reason":choice["reason"],
                "fire_count":choice["fire_count"],"threshold":THRESHOLD,"proof":choice["proof"]}
            evidence = None
            if action == "SKIP":
                receipt = skip_receipt(choice,plan,contract,admission["manifest"])
                path = ledger_path.parent / "prescreen_receipts" / (cell["work_item_id"] + ".json")
                path.parent.mkdir(parents=True,exist_ok=True)
                content = json.dumps(receipt,sort_keys=True,indent=2)+"\n"
                if path.exists():
                    if path.read_text() != content: raise ValueError("prescreen receipt overwrite refused")
                else:
                    with path.open("x",encoding="utf-8") as f:f.write(content)
                evidence = str(path.resolve());payload["skipped_prescreen"]={"receipt_sha256":sha(path)}
            else:
                census._atomic_write(Path(cell["setfile_path"]),census._render_cell_setfile(Path(plan["base_setfile_path"]),cell))
            cur = conn.execute("""INSERT OR IGNORE INTO work_items
                (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at)
                VALUES (?,?,?,?,?,?,?,?,0,?,?,NULL,?,?,?)""",
                (cell["work_item_id"],"backtest",census.PHASE,plan["ea_id"],plan["symbol"],cell["setfile_path"],
                 "done" if action=="SKIP" else "pending",VERDICT if action=="SKIP" else None,
                 parent_work_item_id,evidence,json.dumps(payload,sort_keys=True),now,now))
            inserted += cur.rowcount;skipped += cur.rowcount if action=="SKIP" else 0
        conn.commit()
        admitted = [c["cell_key"] for c in plan["cells"] if conn.execute("SELECT 1 FROM work_items WHERE id=?",(c["work_item_id"],)).fetchone()]
        ledger.update(status="ENQUEUED",prescreen_admitted_cell_keys=admitted,
                      prescreen_last_admission={"inserted":inserted,"skipped":skipped,"stage1_complete":admission["stage1_complete"]})
        census._atomic_write(ledger_path,json.dumps(ledger,sort_keys=True,indent=2)+"\n")
        return {"inserted":inserted,"existing":len(existing),"planned":1085,"skipped":skipped,
                "deferred":1085-len(admitted),"ledger_path":str(ledger_path.resolve())}
    except Exception:
        conn.rollback();raise
    finally:conn.close()
