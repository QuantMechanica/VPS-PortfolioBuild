"""Audit P3+ cascade rows that descend from unprofitable P2 PASS work_items.

Read-only by design: this reports candidates for OWNER review and does not
delete, update, or requeue anything.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


CASCADE_PHASES = ("P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8")


def audit(root: Path, ea_id: str | None = None) -> dict[str, Any]:
    if not farmctl.db_path(root).exists():
        return {
            "root": str(root),
            "ea_id": ea_id,
            "mode": "audit_only_no_mutation",
            "findings_count": 0,
            "findings": [],
            "warning": "farm_state.sqlite not found",
        }
    params: list[Any] = []
    ea_filter = ""
    if ea_id:
        ea_filter = " AND ea_id=?"
        params.append(ea_id)

    with farmctl.connect(root) as conn:
        p2_rows = conn.execute(
            f"""
            SELECT * FROM work_items
            WHERE phase='P2' AND status='done' AND verdict='PASS'{ea_filter}
            ORDER BY ea_id, symbol, updated_at
            """,
            params,
        ).fetchall()

        findings: list[dict[str, Any]] = []
        for p2 in p2_rows:
            net_profit = farmctl._work_item_p2_net_profit(p2)
            if net_profit is not None and net_profit > 0.0:
                continue
            descendants = conn.execute(
                f"""
                SELECT id, phase, status, verdict, parent_task_id, evidence_path, created_at, updated_at
                FROM work_items
                WHERE ea_id=? AND symbol=? AND setfile_path=?
                  AND phase IN ({",".join("?" for _ in CASCADE_PHASES)})
                ORDER BY created_at
                """,
                [p2["ea_id"], p2["symbol"], p2["setfile_path"], *CASCADE_PHASES],
            ).fetchall()
            if not descendants:
                continue
            findings.append({
                "ea_id": p2["ea_id"],
                "symbol": p2["symbol"],
                "setfile_path": p2["setfile_path"],
                "p2_work_item_id": p2["id"],
                "p2_net_profit": net_profit,
                "reason": farmctl.P2_UNPROFITABLE_SYMBOL_REASON,
                "descendants": [dict(row) for row in descendants],
            })

    return {
        "root": str(root),
        "ea_id": ea_id,
        "mode": "audit_only_no_mutation",
        "findings_count": len(findings),
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit unprofitable P2 symbols with P3+ cascade work_items.")
    parser.add_argument("--root", default=str(farmctl.DEFAULT_ROOT), help="strategy_farm root")
    parser.add_argument("--ea", help="optional EA filter, e.g. QM5_1056")
    args = parser.parse_args()

    print(json.dumps(audit(Path(args.root).resolve(), args.ea), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
