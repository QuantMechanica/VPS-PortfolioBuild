from __future__ import annotations

import json
import sqlite3
import subprocess
from pathlib import Path

from tools.strategy_farm import classify_summary_missing as stranded
from tools.strategy_farm import close_q02_bypass_hold as close_hold
from tools.strategy_farm import public_snapshot_incident_guard as guard


WORK_ITEMS_SQL = """
CREATE TABLE work_items(
 id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,
 status TEXT,verdict TEXT,attempt_count INTEGER,parent_task_id TEXT,evidence_path TEXT,
 claimed_by TEXT,payload_json TEXT,created_at TEXT,updated_at TEXT,
 verdict_taxonomy_stored TEXT,clean_status_stored TEXT,gate_contract_version TEXT
)
"""


def _base_db(path: Path) -> sqlite3.Connection:
    con = sqlite3.connect(path)
    con.execute(WORK_ITEMS_SQL)
    con.execute(
        "CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT,ts TEXT,entity_type TEXT,"
        "entity_id TEXT,event TEXT,detail_json TEXT)"
    )
    return con


def test_owner_stranded_plan_appends_invalid_without_overwriting_history(
    tmp_path: Path, monkeypatch
) -> None:
    db = tmp_path / "farm.sqlite"
    con = _base_db(db)
    payload = json.dumps({
        "failure_class": stranded.CLASS_DETERMINISTIC,
        "failure_subclass": "never_worked",
        "final_failure": stranded.GRAVEYARD_TAG,
    }, sort_keys=True)
    for pair in range(2):
        for attempt in range(12):
            con.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (f"source-{pair}-{attempt}", "backtest", "Q02", f"QM5_{pair+1}",
                 "EURUSD.DWX", "x.set", "failed", "INFRA_FAIL", attempt, None,
                 None, None, payload,
                 f"2026-01-01T00:{attempt:02d}:00+00:00",
                 f"2026-01-01T00:{attempt:02d}:00+00:00", "infra", "infra", "legacy"),
            )
    con.commit()
    con.close()
    decision = tmp_path / "decision.md"
    decision.write_text(
        "OWNER-DEC-STRANDED-182 / alle drei genehmigt", encoding="utf-8"
    )
    monkeypatch.setattr(stranded, "OWNER_DECISION_PATH", decision)
    plan = stranded._owner_disposition_plan(db, expected_count=2)
    assert len(plan["targets"]) == 2
    assert plan["historical_verdict_rows_updated"] == 0

    monkeypatch.setattr(stranded, "OWNER_EXPECTED_PAIR_COUNT", 2)
    monkeypatch.setattr(stranded, "MUTATION_LOCK", tmp_path / "mutation.lock")
    plan_sha = stranded._sha256_bytes(stranded._canonical_bytes(plan))
    receipt = stranded._apply_owner_dispositions(
        db, plan, plan_sha, tmp_path / "receipt.json"
    )
    assert receipt["inserted_count"] == 2
    with sqlite3.connect(db) as check:
        assert check.execute(
            "SELECT COUNT(*) FROM work_items WHERE verdict='INFRA_FAIL'"
        ).fetchone()[0] == 24
        assert check.execute(
            "SELECT COUNT(*) FROM work_items WHERE verdict='INVALID'"
        ).fetchone()[0] == 2
        assert check.execute(
            "SELECT COUNT(*) FROM work_items WHERE verdict='INVALID' "
            "AND verdict_taxonomy_stored='invalid' AND clean_status_stored='failed'"
        ).fetchone()[0] == 2
        assert check.execute(
            "SELECT COUNT(*) FROM events WHERE event="
            "'owner_stranded_summary_missing_invalid_appended'"
        ).fetchone()[0] == 2


def test_q02_bypass_close_is_hash_bound_append_audited_and_guard_reopens(
    tmp_path: Path, monkeypatch
) -> None:
    db = tmp_path / "farm.sqlite"
    con = _base_db(db)
    con.execute(
        """CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,released_at TEXT,
          release_note TEXT)"""
    )
    con.execute(
        """CREATE TABLE work_item_transition_ledger(
          seq INTEGER PRIMARY KEY AUTOINCREMENT,idempotency_key TEXT UNIQUE,ts TEXT,
          work_item_id TEXT,action TEXT,from_status TEXT,to_status TEXT,from_verdict TEXT,
          to_verdict TEXT,from_claimed_by TEXT,to_claimed_by TEXT,reason TEXT,run_id TEXT,
          detail_json TEXT)"""
    )
    evidence = tmp_path / "summary.json"
    evidence.write_text(json.dumps({
        "result": "PASS", "reason_classes": ["OK"],
        "runs": [{"status": "OK", "total_trades": 94}],
        "execution_identity": {"expert_binary": {
            "required_sha256": close_hold.EXPECTED_RECOVERY_EX5,
            "stable_during_run": True,
        }},
    }), encoding="utf-8")
    held_values = (
        close_hold.HOLD_WORK_ITEM_ID, "backtest", "Q02", close_hold.EXPECTED_EA,
        close_hold.EXPECTED_SYMBOL, "held.set", "failed", "BLOCKED_STALE_BUILD_RESULT",
        0, None, "EVIDENCE_UNAVAILABLE:held", None, "{}", "2026-07-29", "2026-07-29",
        "infra", "invalid", "legacy",
    )
    recovery_values = (
        close_hold.RECOVERY_WORK_ITEM_ID, "backtest", "Q02", close_hold.EXPECTED_EA,
        close_hold.EXPECTED_SYMBOL, "fresh.set", "done", "PASS", 0, None,
        str(evidence), None, json.dumps({
            "requalification_old_work_item_id": close_hold.HOLD_WORK_ITEM_ID,
            "expected_ex5_sha256": close_hold.EXPECTED_RECOVERY_EX5,
        }), "2026-08-21", "2026-08-21", "strategy", "done", "legacy",
    )
    con.executemany(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [held_values, recovery_values],
    )
    con.execute(
        "INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?,?,?)",
        (close_hold.HOLD_WORK_ITEM_ID, close_hold.HOLD_CODE, "stale", 1, 0,
         "2026-07-29", "2026-07-29", None, None),
    )
    con.commit()
    con.close()
    decision = tmp_path / "decision.md"
    decision.write_text(
        "OWNER-DEC-Q02-BYPASS-88ba4560 / alle drei genehmigt", encoding="utf-8"
    )
    monkeypatch.setattr(close_hold, "DECISION_PATH", decision)
    disposition = close_hold.inspect(db)
    disposition_sha = close_hold.sha256_bytes(close_hold.canonical_bytes(disposition))
    receipt = close_hold.apply(
        db, disposition, disposition_sha, tmp_path / "receipt.json",
        tmp_path / "snapshot.sqlite", tmp_path / "mutation.lock",
    )
    assert receipt["active_after"] is False
    assert receipt["deleted_rows"] == 0
    with sqlite3.connect(db) as check:
        assert check.execute(
            "SELECT active FROM work_item_holds WHERE work_item_id=?",
            (close_hold.HOLD_WORK_ITEM_ID,),
        ).fetchone()[0] == 0
        assert check.execute(
            "SELECT COUNT(*) FROM work_item_transition_ledger WHERE action="
            "'release_q02_bypass_hold'"
        ).fetchone()[0] == 1
        assert check.execute(
            "SELECT COUNT(*) FROM events WHERE event='q02_bypass_hold_closed'"
        ).fetchone()[0] == 1
    guarded = guard.inspect_public_snapshot_incident_holds(db)
    assert guarded["valid"] is True
    assert guarded["publication_allowed"] is True


def test_public_snapshot_gate_key_enumerator_ignores_dictionary_adapters() -> None:
    repo_root = Path(__file__).resolve().parents[3]
    script = repo_root / "scripts" / "export_public_snapshot.ps1"
    command = rf"""
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    '{script}', [ref]$tokens, [ref]$errors)
$function = $ast.Find({{
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Get-ObjectKeys'
}}, $true)
if ($null -eq $function) {{ throw 'Get-ObjectKeys not found' }}
Invoke-Expression $function.Extent.Text
$gateMap = [ordered]@{{gate_contract_version = 'v4'; Q00 = 1; Q17 = 0}}
$keys = @(Get-ObjectKeys -Target $gateMap)
if (($keys -join ',') -ne 'gate_contract_version,Q00,Q17') {{
    throw "unexpected keys: $($keys -join ',')"
}}
"""
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        cwd=repo_root,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
