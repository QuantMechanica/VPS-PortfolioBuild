#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def main() -> int:
    p = argparse.ArgumentParser(description="Check Kanban dispatch readiness for a Paperclip issue")
    p.add_argument("--csv", default="C:/QM/paperclip/kanban/company_kanban.csv")
    p.add_argument("--issue", default="QUA-212")
    p.add_argument("--assignee", default="cto")
    args = p.parse_args()

    path = Path(args.csv)
    if not path.exists():
        print(json.dumps({"status": "FAIL", "reason": "csv_missing", "csv": str(path)}))
        return 2

    matches = []
    with path.open("r", encoding="utf-8", newline="") as f:
        for row in csv.DictReader(f):
            if row.get("paperclip_issue_id", "").strip() != args.issue:
                continue
            if row.get("assignee", "").strip() != args.assignee:
                continue
            matches.append(
                {
                    "task_id": row.get("task_id", ""),
                    "status": row.get("status", ""),
                    "priority": row.get("priority", ""),
                    "title": row.get("title", ""),
                }
            )

    actionable = [m for m in matches if m["status"] in {"queued", "in_progress"}]
    payload = {
        "issue": args.issue,
        "assignee": args.assignee,
        "match_count": len(matches),
        "actionable_count": len(actionable),
        "matches": matches,
        "status": "PASS" if actionable else "FAIL",
    }
    print(json.dumps(payload, ensure_ascii=True))
    return 0 if actionable else 2


if __name__ == "__main__":
    raise SystemExit(main())
