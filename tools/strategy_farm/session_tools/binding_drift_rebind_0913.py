"""Execute the safe part of docs/ops/evidence/2026-09-13_artifact_binding_drift/plan.json (Orchestrator 2026-09-13).

C2A rows (committed regeneration made the pinned mq5/set/ex5 SHAs stale) with a concrete current ex5 sha are rebound
append-only through the governed ``farmctl requalify-q02`` path (old row stays as evidence; successor carries fresh
bindings). Rows whose ex5 is missing (placeholder <CURRENT_EX5_SHA>) need a recompile -> ROT, skipped and listed.
C2B rows (bindings drifted because of ANOTHER agent's uncommitted working-tree .set edits) are never rebound here.
FREE rows (no active hold) that cannot be rebound are parked with governed_work_item_hold so a claim does not burn
INFRA_FAIL. Default = dry-run; ``--apply`` executes. Journal: <evidence dir>/rebind_journal.jsonl (append-only).
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
from pathlib import Path

REPO = Path("C:/QM/repo")
EVID = REPO / "docs" / "ops" / "evidence" / "2026-09-13_artifact_binding_drift"
PLAN = EVID / "plan.json"
JOURNAL = EVID / "rebind_journal.jsonl"
HOLD_CODE = "ARTIFACT_BINDING_CONTENT_CHANGED"


def run(cmd: list[str]) -> tuple[int, str]:
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(REPO))
    return r.returncode, ((r.stdout or "") + (r.stderr or "")).strip()


def journal(entry: dict) -> None:
    entry["at_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    with JOURNAL.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, default=str) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    rows = plan.get("rows") or plan.get("plan") or plan
    if isinstance(rows, dict):
        rows = rows.get("rows") or list(rows.values())
    seen: set[str] = set()
    summary = {"rebind_ok": 0, "rebind_refused": 0, "rot_recompile": 0, "c2b_skipped": 0, "held_free": 0, "hold_failed": 0}
    for r in rows:
        wid = r.get("id")
        cluster = str(r.get("cause_cluster") or "")
        if not wid or wid in seen or cluster.startswith("C1"):
            continue
        seen.add(wid)
        cmd_text = str(r.get("command") or "")
        if cluster.startswith("C2B"):
            summary["c2b_skipped"] += 1
            journal({"row": wid, "cluster": cluster, "action": "skip_uncommitted_setfile_edit"})
            continue
        if "<CURRENT_EX5_SHA>" in cmd_text or "requalify-q02" not in cmd_text:
            summary["rot_recompile"] += 1
            journal({"row": wid, "cluster": cluster, "action": "skip_recompile_required_ROT"})
            continue
        sha = cmd_text.split("--expected-current-ex5-sha256")[1].split()[0].strip()
        cmd = ["python", "-X", "utf8", "tools/strategy_farm/farmctl.py", "requalify-q02", "--old-work-item-id", wid,
               "--expected-current-ex5-sha256", sha, "--reason", "artifact binding drift rebind 2026-09-13 (committed regeneration after enqueue)",
               "--apply" if args.apply else "--dry-run"]
        rc, out = run(cmd)
        ok = rc == 0 and ("refus" not in out.lower()) and ("error" not in out.lower()[:400])
        summary["rebind_ok" if ok else "rebind_refused"] += 1
        journal({"row": wid, "cluster": cluster, "ea": r.get("ea"), "phase": r.get("phase"), "action": "requalify-q02",
                 "mode": "apply" if args.apply else "dry-run", "rc": rc, "ok": ok, "out": out[-600:]})
        print(("OK " if ok else "REFUSED "), wid[:8], r.get("ea"), r.get("phase"), out.replace("\n", " ")[-160:])
        if not ok and not r.get("held") and args.apply:
            hcmd = ["python", "-X", "utf8", "tools/strategy_farm/governed_work_item_hold.py", "apply", "--target", f"{wid}={r.get('symbol')}",
                    "--ea-id", str(r.get("ea")), "--phase", str(r.get("phase")), "--hold-code", HOLD_CODE,
                    "--reason", "2026-09-13 artifact binding drift: pinned artifact sha differs from the committed file; rebind refused; parked so a claim does not burn INFRA_FAIL",
                    "--release-condition", "successor row with fresh bindings exists (requalify-q02) or OWNER decides the recompile"]
            hrc, hout = run(hcmd)
            summary["held_free" if hrc == 0 else "hold_failed"] += 1
            journal({"row": wid, "action": "governed_hold", "rc": hrc, "out": hout[-400:]})
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
