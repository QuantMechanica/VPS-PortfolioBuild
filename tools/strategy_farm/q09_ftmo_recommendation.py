"""Read-only presentation projection for the Q09 FTMO recommendation.

The decision itself is delegated unchanged to
``portfolio.ftmo_q09_admission.evaluate_ftmo_q09_admission``.  This module only
turns those per-pair decisions into stable aggregate/detail rows for operator
surfaces; it never writes a verdict, work item, or evidence record.
"""

from __future__ import annotations

import sqlite3
from collections import Counter
from typing import Any, Iterable

try:
    from tools.strategy_farm.portfolio.ftmo_q09_admission import (
        evaluate_ftmo_q09_admission,
    )
except ModuleNotFoundError:  # direct script/import execution
    from portfolio.ftmo_q09_admission import evaluate_ftmo_q09_admission


SCHEMA_VERSION = "qm.q09-ftmo-recommendation/v1"


def _normalized_pairs(
    conn: sqlite3.Connection,
    *,
    ea_id: str | None,
    symbols: Iterable[str] | None,
) -> list[tuple[str, str]]:
    if symbols is not None:
        if ea_id is None:
            raise ValueError("ea_id is required when symbols are supplied")
        return sorted(
            {
                (str(ea_id).strip().upper(), str(symbol).strip().upper())
                for symbol in symbols
                if str(symbol).strip()
            }
        )
    if ea_id is not None:
        rows = conn.execute(
            """
            SELECT DISTINCT ea_id,upper(symbol)
            FROM work_items
            WHERE ea_id=? AND trim(COALESCE(symbol,''))<>''
            ORDER BY ea_id,upper(symbol)
            """,
            (str(ea_id).strip().upper(),),
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT DISTINCT ea_id,upper(symbol)
            FROM work_items
            WHERE upper(phase)='Q09_NEWS' AND lower(status)='done'
              AND trim(COALESCE(symbol,''))<>''
            ORDER BY ea_id,upper(symbol)
            """
        ).fetchall()
    return [(str(row[0]).strip().upper(), str(row[1]).strip().upper()) for row in rows]


def collect(
    conn: sqlite3.Connection,
    *,
    ea_id: str | None = None,
    symbols: Iterable[str] | None = None,
) -> dict[str, Any]:
    """Evaluate and summarize Q09 FTMO suitability without changing criteria."""

    output: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "available": False,
        "criteria_source": (
            "portfolio.ftmo_q09_admission.evaluate_ftmo_q09_admission"
        ),
        "total": 0,
        "suitable_yes": 0,
        "suitable_no": 0,
        "reason_counts": {},
        "rows": [],
        "error": None,
    }
    try:
        pairs = _normalized_pairs(conn, ea_id=ea_id, symbols=symbols)
    except (sqlite3.DatabaseError, ValueError) as exc:
        output["error"] = f"{type(exc).__name__}:{exc}"
        return output

    reason_counts: Counter[str] = Counter()
    rendered_rows: list[dict[str, Any]] = []
    for pair_ea, symbol in pairs:
        try:
            decision = evaluate_ftmo_q09_admission(conn, pair_ea, symbol)
        except (sqlite3.DatabaseError, OSError, ValueError) as exc:
            decision = {
                "admitted": False,
                "reason_code": f"PRESENTATION_EVALUATION_ERROR:{type(exc).__name__}",
                "q09_news_work_item_id": None,
                "chosen_temporal": None,
            }
        admitted = decision.get("admitted") is True
        reason = str(decision.get("reason_code") or "FTMO_Q09_EVIDENCE_MISSING")
        reason_counts[reason] += 1
        rendered_rows.append(
            {
                "ea_id": pair_ea,
                "symbol": symbol,
                "suitable": admitted,
                "recommendation": "YES" if admitted else "NO",
                "reason_code": reason,
                "q09_news_work_item_id": decision.get("q09_news_work_item_id"),
                "chosen_temporal": decision.get("chosen_temporal"),
            }
        )

    yes = sum(1 for row in rendered_rows if row["suitable"])
    output.update(
        {
            "available": True,
            "total": len(rendered_rows),
            "suitable_yes": yes,
            "suitable_no": len(rendered_rows) - yes,
            "reason_counts": dict(sorted(reason_counts.items())),
            "rows": rendered_rows,
        }
    )
    return output


__all__ = ["SCHEMA_VERSION", "collect"]
