#!/usr/bin/env python3
"""Find automations that exist as runnable code but have nothing that runs them.

Three of these surfaced within one month, each the same shape: a mechanism whose design assumes an
operator, and no operator.

  * the stranded-INFRA sweep - the reaper's own comment says INFRA_FAIL exists "so the stranded-INFRA
    sweep can requeue the pair"; nothing calls it
  * QM_StrategyFarm_Repair_Hourly - present, Disabled
  * the poison-pill quarantine refresh - restored earlier this session after the same finding

None of the three announced itself. They present as backlog, as a stuck row, as a queue that never
drains - symptoms that look like capacity problems and get treated as such.

Method
------
A script counts as *recurring-operator shaped* if its name carries a maintenance verb (sweep, purge,
requeue, reconcile, refresh, prune, heal, monitor, watch, guard, governor, pacer, drain, cleanup).
One-shot analysis tools are deliberately out of scope: nothing is supposed to call them.

For each candidate the scan asks two questions:
  1. does any Windows scheduled task's action mention it, and is that task enabled?
  2. does any other file in the repo reference it by name (import, subprocess, documentation)?

A candidate with neither is an orphan. A candidate whose only caller is a Disabled task is worse
than an orphan, because the surface says it is covered.

Findings are reported, not fixed. Something may be deliberately parked.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

ROOT = Path(r"C:\QM\repo")
FARM = ROOT / "tools" / "strategy_farm"
VERBS = ("sweep", "purge", "requeue", "reconcile", "refresh", "prune", "heal",
         "monitor", "watch", "guard", "governor", "pacer", "drain", "cleanup",
         "clean", "reclaim", "dedupe", "repair", "recover")
SCHEMA = "qm.orphaned-mechanisms/v1"


def scheduled_task_actions() -> list[dict[str, Any]]:
    ps = (
        "Get-ScheduledTask | ForEach-Object { "
        "  $a = ($_.Actions | ForEach-Object { \"$($_.Execute) $($_.Arguments)\" }) -join ' '; "
        "  [pscustomobject]@{ name=$_.TaskName; state=[string]$_.State; action=$a } "
        "} | ConvertTo-Json -Compress -Depth 3"
    )
    try:
        out = subprocess.run(["powershell", "-NoProfile", "-Command", ps],
                             capture_output=True, text=True, timeout=180,
                             creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        data = json.loads(out.stdout or "[]")
    except Exception as exc:  # pragma: no cover
        return [{"name": "<scheduler unreadable>", "state": "unknown", "action": repr(exc)}]
    return data if isinstance(data, list) else [data]


def candidates() -> list[Path]:
    out = []
    for p in sorted(FARM.glob("*.py")) + sorted(FARM.glob("*.ps1")):
        name = p.stem.casefold()
        if any(v in name for v in VERBS):
            out.append(p)
    return out


_CORPUS: list[tuple[str, str]] | None = None


def _corpus() -> list[tuple[str, str]]:
    """Read every text file once. Rebuilding the walk per candidate is O(scripts x repo) and the
    repo has thousands of EA directories -- the first version of this scan did not finish."""
    global _CORPUS
    if _CORPUS is not None:
        return _CORPUS
    out: list[tuple[str, str]] = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.casefold() not in {".py", ".ps1", ".md", ".json", ".xml", ".bat", ".cmd"}:
            continue
        parts = set(p.parts)
        if ".git" in parts or "__pycache__" in parts:
            continue
        try:
            out.append((str(p.relative_to(ROOT)), p.read_text(encoding="utf-8",
                                                              errors="ignore").casefold()))
        except OSError:
            continue
    _CORPUS = out
    return out


def repo_references(name: str, self_path: Path) -> list[str]:
    """Files other than the script itself that mention it by name."""
    needle = name.casefold()
    me = str(self_path.relative_to(ROOT))
    return [rel for rel, text in _corpus() if rel != me and needle in text][:12]


def classify(refs: list[str], tasks: list[dict[str, Any]]) -> str:
    enabled = [t for t in tasks if str(t.get("state", "")).casefold() not in {"disabled", "3"}]
    if enabled:
        return "scheduled"
    if tasks:
        return "scheduled_but_disabled"
    code_refs = [r for r in refs if r.endswith((".py", ".ps1", ".bat", ".cmd"))]
    if code_refs:
        return "called_from_code"
    if refs:
        return "documented_only"
    return "orphan"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json-out", type=Path)
    args = ap.parse_args()

    tasks = scheduled_task_actions()
    rows = []
    for p in candidates():
        name = p.name
        matched = [t for t in tasks if name.casefold() in str(t.get("action", "")).casefold()]
        refs = repo_references(name, p)
        rows.append({
            "script": str(p.relative_to(ROOT)),
            "status": classify(refs, matched),
            "tasks": [{"name": t["name"], "state": t.get("state")} for t in matched],
            "repo_references": refs[:6],
            "reference_count": len(refs),
        })
    order = {"orphan": 0, "scheduled_but_disabled": 1, "documented_only": 2,
             "called_from_code": 3, "scheduled": 4}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["script"]))
    summary: dict[str, int] = {}
    for r in rows:
        summary[r["status"]] = summary.get(r["status"], 0) + 1
    out = {"schema_version": SCHEMA, "candidates": len(rows), "summary": summary, "rows": rows}
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(out, indent=1, sort_keys=True) + "\n",
                                 encoding="utf-8")
    print(json.dumps(summary, indent=1))
    print()
    for r in rows:
        if r["status"] in {"orphan", "scheduled_but_disabled", "documented_only"}:
            t = ", ".join(f"{x['name']}({x['state']})" for x in r["tasks"]) or "-"
            print(f"  {r['status']:24} {Path(r['script']).name:46} tasks={t}  refs={r['reference_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
