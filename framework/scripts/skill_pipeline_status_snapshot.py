#!/usr/bin/env python3
"""Deterministic snapshot generator for qm-pipeline-status."""
from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
import urllib.error
import urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

API_BASE = "http://127.0.0.1:3100/api"
COMPANY_ID = "03d4dcc8-4cea-4133-9f68-90c0d99628fb"
PIPELINE_ROOT = Path("D:/QM/reports/pipeline")
KANBAN_CMD = [sys.executable, "C:/QM/paperclip/tools/ops/next_task.py", "--agent", "ceo", "--json"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Collect deterministic pipeline status snapshot")
    parser.add_argument("--output", help="Optional output JSON path")
    return parser.parse_args()


def fetch_json(url: str) -> list[dict]:
    with urllib.request.urlopen(url, timeout=15) as response:
        return json.loads(response.read().decode("utf-8"))


def collect_phase_snapshot() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    if not PIPELINE_ROOT.exists():
        return rows
    for ea_dir in sorted([p for p in PIPELINE_ROOT.iterdir() if p.is_dir() and p.name.startswith("QM5_")]):
        phases = sorted([p.name for p in ea_dir.iterdir() if p.is_dir()])
        p2_report = ea_dir / "P2" / "report.csv"
        pass_count = 0
        if p2_report.exists():
            with p2_report.open("r", encoding="utf-8", newline="") as fh:
                rdr = csv.DictReader(fh)
                pass_count = sum(1 for r in rdr if r.get("verdict") == "PASS")
        rows.append({"ea": ea_dir.name, "phases": phases, "p2_pass_symbols": pass_count})
    return rows


def main() -> int:
    args = parse_args()
    now = datetime.now(timezone.utc).isoformat()

    result: dict[str, object] = {
        "timestamp_utc": now,
        "status": "ok",
        "checks": {},
    }

    try:
        issues = fetch_json(f"{API_BASE}/companies/{COMPANY_ID}/issues?limit=200")
        result["issue_counts"] = dict(Counter(i.get("status", "unknown") for i in issues))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        result["status"] = "warning"
        result["issue_error"] = str(exc)

    result["pipeline"] = collect_phase_snapshot()

    terminals = subprocess.run(
        ["tasklist", "/fi", "imagename eq terminal64.exe", "/fo", "csv"],
        capture_output=True,
        text=True,
    )
    terminal_count = max(0, terminals.stdout.count("terminal64.exe"))
    result["terminal64_count"] = terminal_count

    kanban = subprocess.run(KANBAN_CMD, capture_output=True, text=True)
    if kanban.returncode == 0:
        try:
            result["kanban"] = json.loads(kanban.stdout)
        except json.JSONDecodeError:
            result["status"] = "warning"
            result["kanban_parse_error"] = "invalid_json"
    else:
        result["status"] = "warning"
        result["kanban_error"] = kanban.stderr[-2000:]

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
