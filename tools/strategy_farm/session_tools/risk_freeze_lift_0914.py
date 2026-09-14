"""Transcribe the OWNER's written lift of the live risk freeze into the durable state (2026-09-14).

The freeze (risk_freeze.py) has no lift subcommand on purpose: the lift is the OWNER's written
sentence.  This tool is the transcription step and nothing more.  It refuses unless
  * the decision file exists, is committed in git, and contains the OWNER's verbatim sentence
    ("Dann setz den Lift Satz um!") and the literal marker line ``## The OWNER's written lift (verbatim)``;
  * the current state is ACTIVE (never re-lifts, never lifts an unknown state);
  * a backup of the state file was written first.
It then writes status LIFTED with ``lift_authority`` (verbatim sentence + decision file path + sha256),
``lifted_at_utc``, ``lifted_by`` and ``lift_scope_note``; every other field (scope, baseline, conditions,
armed_at) is preserved so ``risk_freeze.py verify``/``status`` keep their history.  Rollback: ``risk_freeze.py arm``.
Default = dry-run.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

REPO = Path("C:/QM/repo")
STATE = Path("D:/QM/reports/state/live_risk_freeze.json")
DECISION = REPO / "decisions" / "2026-09-14_owner_risk_freeze_lift.md"
SENTENCE = "Dann setz den Lift Satz um!"
MARKER = "## The OWNER's written lift (verbatim)"
BACKUP_DIR = Path("D:/QM/reports/state/backups")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    text = DECISION.read_text(encoding="utf-8")
    if MARKER not in text or SENTENCE not in text:
        print("REFUSED: decision file lacks the OWNER sentence or the verbatim marker"); return 2
    tracked = subprocess.run(["git", "-C", str(REPO), "log", "-1", "--format=%H", "--", str(DECISION.relative_to(REPO))],
                             capture_output=True, text=True).stdout.strip()
    if not tracked:
        print("REFUSED: decision file is not committed (the OWNER signs by the commit with an explicit pathspec)"); return 2
    state = json.loads(STATE.read_text(encoding="utf-8"))
    if str(state.get("status")) != "ACTIVE":
        print(f"REFUSED: freeze status is {state.get('status')!r}, only ACTIVE can be lifted"); return 2
    now = dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    decision_sha = hashlib.sha256(DECISION.read_bytes()).hexdigest()
    verbatim_start = text.index(MARKER)
    verbatim = text[verbatim_start:verbatim_start + 700].split("\n\n")[1].strip()
    new_state = dict(state)
    new_state.update({
        "status": "LIFTED",
        "lift_authority": f"OWNER written lift (chat 2026-09-14, transcribed): {verbatim} | decision file decisions/2026-09-14_owner_risk_freeze_lift.md sha256 {decision_sha} commit {tracked[:12]}",
        "lifted_at_utc": now,
        "lifted_by": "OWNER (chat 2026-09-14), transcribed by Orchestrator Claude",
        "lift_decision_path": str(DECISION),
        "lift_decision_sha256": decision_sha,
        "lift_decision_commit": tracked,
        "lift_scope_note": "Condition 1 satisfied by attestation (receipt 424fb9d6); condition 3 ratified (policy f2baf21a, activation 5ab3b819), enforce inside the cutover; condition 2 (NEWS-CONTRACT-V2) explicitly carried as Nacharbeit by the OWNER lift - tickets 01870d4c/53bf70a3. AutoTrading toggle untouched (Hard Rule).",
        "previous_status": "ACTIVE",
    })
    print("state:", state.get("status"), "->", new_state["status"]); print("lift_authority:", new_state["lift_authority"][:160], "...")
    if not args.apply:
        print("dry-run: nothing written"); return 0
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    backup = BACKUP_DIR / f"live_risk_freeze_before_lift_{now.replace(':', '')}.json"
    shutil.copy2(STATE, backup)
    tmp = STATE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(new_state, indent=2), encoding="utf-8")
    tmp.replace(STATE)
    print("written:", STATE, "| backup:", backup)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
