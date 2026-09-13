"""Park the FREE (unheld) rows of docs/ops/evidence/2026-09-13_artifact_binding_drift/plan.json (Orchestrator 2026-09-13).

Their pinned artifact SHAs differ from the committed files (C2A: committed regeneration after enqueue; C2B: another
agent's uncommitted .set edits). A claim would raise in _prepare_staged_ex5 and burn INFRA_FAIL, so they are parked with
the governed hold tool (backup + ledger + events; status untouched) until the governed rebind path exists (Codex ticket).
requalify-q02 is NOT applicable to pending rows (dry-run 2026-09-13: source_not_eligible_q02_pending_or_terminal).
Default = dry-run listing; --apply parks. Journal: <evidence dir>/hold_journal.jsonl.
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
JOURNAL = EVID / "hold_journal.jsonl"
HOLD_CODE = "ARTIFACT_BINDING_CONTENT_CHANGED"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    plan = json.loads(PLAN.read_text(encoding="utf-8"))
    rows = plan.get("rows") or plan
    seen: set[str] = set()
    n_ok = n_fail = 0
    for r in rows:
        wid = r.get("id")
        cluster = str(r.get("cause_cluster") or "")
        if not wid or wid in seen or cluster.startswith("C1") or r.get("held"):
            continue
        seen.add(wid)
        cmd = ["python", "-X", "utf8", "tools/strategy_farm/governed_work_item_hold.py", "apply",
               "--target", f"{wid}={r.get('symbol')}", "--ea-id", str(r.get("ea")), "--phase", str(r.get("phase")),
               "--hold-code", HOLD_CODE,
               "--reason", f"2026-09-13 artifact binding drift ({cluster}): pinned {r.get('kind')} sha differs from the committed file; a claim would burn INFRA_FAIL in _prepare_staged_ex5; parked until the governed rebind path lands (Codex ticket)",
               "--release-condition", "successor row with fresh artifact bindings exists, or the pinned artifacts are restored byte-exact"]
        print(("APPLY " if args.apply else "DRY   "), wid[:8], r.get("ea"), r.get("phase"), r.get("symbol"), cluster[:3])
        if not args.apply:
            continue
        rr = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(REPO))
        out = ((rr.stdout or "") + (rr.stderr or "")).strip()
        ok = rr.returncode == 0
        n_ok += ok
        n_fail += (not ok)
        with JOURNAL.open("a", encoding="utf-8") as fh:
            fh.write(json.dumps({"at_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "row": wid, "ea": r.get("ea"), "phase": r.get("phase"),
                                 "cluster": cluster, "rc": rr.returncode, "out": out[-500:]}) + "\n")
        print("   ->", "ok" if ok else "FAILED", out.replace("\n", " ")[-160:])
    print(f"rows {len(seen)} applied_ok {n_ok} failed {n_fail} mode {'apply' if args.apply else 'dry-run'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
