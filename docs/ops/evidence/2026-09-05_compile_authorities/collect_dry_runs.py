"""Canonical CLI dry runs plus the isolated branch's read-only predicate preview."""
import concurrent.futures
import json
from pathlib import Path
import sqlite3
import subprocess
import sys

REPO = Path("C:/QM/repo")
BRANCH = Path("C:/QM/worktrees/codex-compile-authorities-20260905")
OUT = REPO / "docs/ops/evidence/2026-09-05_compile_authorities"
ROOT = Path("D:/QM/strategy_farm")
sys.path.insert(0, str(BRANCH))
from tools.strategy_farm import compile_work_items as cwi


def read_only(root):
    conn = sqlite3.connect((root / "state/farm_state.sqlite").as_uri() + "?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA query_only=ON")
    return conn


cwi._connect = read_only
inventory = cwi._inventory(ROOT, REPO)
registrations = json.loads((OUT / "source_bindings.json").read_text())["registrations"]


def collect(entry):
    label, authority, ea = entry["ea_label"], entry["authority"], entry["ea_id"]
    request = OUT / ("QM5_" + ea + "_compile_request.txt")
    request.write_text(label + "\n", encoding="utf-8")
    command = [sys.executable, str(REPO / "tools/strategy_farm/farmctl.py"), "enqueue-compile",
               "--from-file", str(request), "--source-repair-authority", authority]
    assert "--apply" not in command
    proc = subprocess.run(command, cwd=REPO, capture_output=True, text=True, encoding="utf-8", timeout=180)
    result = json.loads(proc.stdout) if proc.stdout.strip().startswith("{") else None
    receipt = {"command": command, "exit_code": proc.returncode, "stdout": result or proc.stdout, "stderr": proc.stderr}
    (OUT / ("QM5_" + ea + "_canonical_dry_run.json")).write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    if result is not None:
        assert result.get("enqueued", 0) in (0, [])
    preview = cwi.classify_candidate(ROOT, REPO, label, inventory, source_repair_authority=authority)
    selected_authorized = cwi._source_repair_authorized(label, authority, repo_root=REPO, ea_id=ea,
                                                      source_sha=entry["source_sha256"], inventory=inventory)
    (OUT / ("QM5_" + ea + "_branch_preview.json")).write_text(json.dumps(
        {"selected_source_predicate_authorized": selected_authorized, "candidate": preview}, indent=2) + "\n", encoding="utf-8")
    return {"ea_id": "QM5_" + ea, "selected_source_predicate_authorized": selected_authorized,
            "working_source_matches_selected": entry["working_source_sha256"] == entry["source_sha256"],
            "branch_preview_reason": preview["reason"], "branch_eligible": preview["eligible"],
            "canonical_exit_code": proc.returncode, "canonical_dry_run": "QM5_" + ea + "_canonical_dry_run.json"}


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
    results = list(executor.map(collect, registrations))
summary = {"schema": "qm.compile-authority-review/v1", "no_apply": True,
           "canonical_policy_integration": "PENDING_CEO_REVIEW", "registrations": results}
(OUT / "verification.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
print(json.dumps(summary, indent=2))
