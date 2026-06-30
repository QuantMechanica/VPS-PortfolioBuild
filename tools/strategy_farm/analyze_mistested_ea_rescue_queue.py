"""Build a prioritized rescue queue for likely mis-tested EAs.

The report joins the static strategy-conformance audit with the live farm DB.
It does not mutate farm state or enqueue work. The goal is to separate:

- likely implementation/test-harness mistakes,
- late infra failures worth retrying,
- active work that should be watched instead of duplicated,
- portfolio rejects that should not be rerun unchanged.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_CONFORMANCE_JSON = Path(r"D:\QM\reports\strategy_conformance_20260626.json")
DEFAULT_MARKDOWN = Path("docs/ops/MIS_TESTED_EA_RESCUE_QUEUE_2026-06-27.md")

EA_ID_RE = re.compile(r"QM5_\d+")
PHASE_RANK = {
    "P2": 1,
    "Q02": 2,
    "Q03": 3,
    "Q04": 4,
    "Q05": 5,
    "Q06": 6,
    "Q07": 7,
    "Q08": 8,
    "Q09": 9,
    "Q09_PORTFOLIO": 10,
    "Q10": 11,
}
LATE_PHASES = {"Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q09_PORTFOLIO", "Q10"}
TIME_KEYWORDS = (
    "asian",
    "break",
    "breakout",
    "london",
    "ny",
    "open",
    "orb",
    "range",
    "session",
    "sweep",
    "time",
)
PORTFOLIO_GAP_SYMBOL_TOKENS = (
    "AUD",
    "CAD",
    "CHF",
    "EUR",
    "GBP",
    "JPY",
    "NZD",
    "USD",
    "XAG",
    "XNG",
    "XTI",
)


def normalize_ea_id(value: str | None) -> str:
    match = EA_ID_RE.search(str(value or ""))
    return match.group(0) if match else str(value or "")


def phase_rank(value: str | None) -> int:
    return PHASE_RANK.get(str(value or ""), 0)


def row_dict(row: sqlite3.Row | None) -> dict[str, Any]:
    return dict(row) if row is not None else {}


def read_json(path: str | Path | None) -> dict[str, Any]:
    if not path:
        return {}
    try:
        text = Path(path).read_text(encoding="utf-8", errors="ignore")
        data = json.loads(text)
    except (OSError, json.JSONDecodeError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def compact_reason(row: sqlite3.Row | dict[str, Any] | None) -> str:
    data = row_dict(row) if isinstance(row, sqlite3.Row) else dict(row or {})
    evidence = read_json(data.get("evidence_path"))
    for key in ("reason", "failure_reason", "fail_reason", "decision_reason"):
        if evidence.get(key):
            return str(evidence[key])
    payload_raw = data.get("payload_json") or ""
    try:
        payload = json.loads(payload_raw) if payload_raw else {}
    except json.JSONDecodeError:
        payload = {}
    for key in ("final_failure", "prior_failure", "reason", "note"):
        if payload.get(key):
            return str(payload[key])
    return str(data.get("verdict") or data.get("status") or "")


def load_conformance(path: Path) -> dict[str, dict[str, Any]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    grouped: dict[str, dict[str, Any]] = {}
    for finding in raw:
        ea_id = normalize_ea_id(finding.get("ea"))
        item = grouped.setdefault(
            ea_id,
            {
                "ea_id": ea_id,
                "audit_names": set(),
                "codes": Counter(),
                "severity": Counter(),
                "symbols": set(),
                "details": Counter(),
                "setfiles": [],
            },
        )
        item["audit_names"].add(str(finding.get("ea") or ea_id))
        item["codes"][str(finding.get("code") or "")] += 1
        item["severity"][str(finding.get("severity") or "")] += 1
        if finding.get("symbol"):
            item["symbols"].add(str(finding["symbol"]))
        if finding.get("detail"):
            item["details"][str(finding["detail"])] += 1
        if finding.get("setfile") and len(item["setfiles"]) < 3:
            item["setfiles"].append(str(finding["setfile"]))
    return grouped


def load_db(db_path: Path) -> dict[str, Any]:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        """
        SELECT id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
               attempt_count, parent_task_id, evidence_path, claimed_by,
               payload_json, created_at, updated_at
        FROM work_items
        """
    ).fetchall()
    portfolio_rows = conn.execute(
        """
        SELECT ea_id, symbol, q11_work_item_id, state, evidence_path,
               first_seen_at, updated_at
        FROM portfolio_candidates
        """
    ).fetchall()
    conn.close()

    by_ea: dict[str, list[sqlite3.Row]] = defaultdict(list)
    by_pair: dict[tuple[str, str], list[sqlite3.Row]] = defaultdict(list)
    for row in rows:
        ea_id = normalize_ea_id(row["ea_id"])
        by_ea[ea_id].append(row)
        by_pair[(ea_id, row["symbol"] or "")].append(row)

    highest_by_ea: dict[str, sqlite3.Row] = {}
    latest_by_pair: dict[tuple[str, str], sqlite3.Row] = {}
    highest_by_pair: dict[tuple[str, str], sqlite3.Row] = {}
    for ea_id, ea_rows in by_ea.items():
        highest_by_ea[ea_id] = max(
            ea_rows,
            key=lambda r: (phase_rank(r["phase"]), str(r["updated_at"] or "")),
        )
    for key, pair_rows in by_pair.items():
        latest_by_pair[key] = max(pair_rows, key=lambda r: str(r["updated_at"] or ""))
        highest_by_pair[key] = max(
            pair_rows,
            key=lambda r: (phase_rank(r["phase"]), str(r["updated_at"] or "")),
        )

    q12_ready = {
        (normalize_ea_id(row["ea_id"]), row["symbol"] or "")
        for row in portfolio_rows
        if row["state"] == "Q12_REVIEW_READY"
    }
    q12_ready_eas = {ea_id for ea_id, _ in q12_ready}

    return {
        "rows": rows,
        "portfolio_rows": portfolio_rows,
        "by_ea": by_ea,
        "by_pair": by_pair,
        "highest_by_ea": highest_by_ea,
        "latest_by_pair": latest_by_pair,
        "highest_by_pair": highest_by_pair,
        "q12_ready": q12_ready,
        "q12_ready_eas": q12_ready_eas,
    }


def conformance_score(summary: dict[str, Any], current: sqlite3.Row | None) -> int:
    codes: Counter = summary["codes"]
    severity: Counter = summary["severity"]
    score = (
        severity["high"] * 2
        + codes["MISSING_STRATEGY_PARAMS_IN_SETFILE"] * 3
        + codes["TIME_SENSITIVE_DEFAULTS_ONLY"] * 5
        + codes["SPEC_HAS_TIMES_BUT_SETFILE_HAS_NO_STRATEGY_PARAMS"] * 6
        + codes["PARTIAL_STRATEGY_PARAM_SET"]
        + codes["SPEC_DEFAULT_SETFILE_MISMATCH"]
    )
    if current is not None:
        score += phase_rank(current["phase"]) * 18
        if phase_rank(current["phase"]) >= phase_rank("Q04"):
            score += 50
        if phase_rank(current["phase"]) >= phase_rank("Q05"):
            score += 40
        if current["status"] in {"active", "pending"}:
            score += 8
    haystack = " ".join(summary["audit_names"]).lower()
    if any(token in haystack for token in TIME_KEYWORDS):
        score += 45
    if any(any(token in symbol for token in PORTFOLIO_GAP_SYMBOL_TOKENS) for symbol in summary["symbols"]):
        score += 15
    return score


def build_conformance_queue(conformance: dict[str, dict[str, Any]], db: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    queue = []
    for ea_id, summary in conformance.items():
        if summary["severity"]["high"] <= 0:
            continue
        if ea_id in db["q12_ready_eas"]:
            continue
        current = db["highest_by_ea"].get(ea_id)
        codes: Counter = summary["codes"]
        if not (
            codes["MISSING_STRATEGY_PARAMS_IN_SETFILE"]
            or codes["TIME_SENSITIVE_DEFAULTS_ONLY"]
            or codes["SPEC_HAS_TIMES_BUT_SETFILE_HAS_NO_STRATEGY_PARAMS"]
            or codes["PARTIAL_STRATEGY_PARAM_SET"]
        ):
            continue
        action = "REBUILD_SETFILES_FIRST"
        if current is not None and current["status"] in {"active", "pending"}:
            action = "WAIT_THEN_VALIDATE_REBUILD"
        elif current is not None and current["verdict"] == "FAIL_HARD":
            action = "REBUILD_BEFORE_ANY_RERUN"
        elif current is not None and current["verdict"] == "INFRA_FAIL":
            action = "REBUILD_THEN_INFRA_RETRY"
        queue.append(
            {
                "score": conformance_score(summary, current),
                "ea_id": ea_id,
                "name": sorted(summary["audit_names"])[0],
                "high_findings": summary["severity"]["high"],
                "codes": summary["codes"],
                "symbols": sorted(summary["symbols"])[:6],
                "current": current,
                "action": action,
            }
        )
    return sorted(queue, key=lambda item: (-item["score"], item["ea_id"]))[:limit]


def build_basket_queue(db: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    latest: dict[tuple[str, str], sqlite3.Row] = {}
    for row in db["rows"]:
        payload = row["payload_json"] or ""
        symbol = row["symbol"] or ""
        if "basket_manifest" not in payload and not symbol.startswith("QM5_"):
            continue
        key = (normalize_ea_id(row["ea_id"]), symbol)
        if key not in latest or str(row["updated_at"] or "") > str(latest[key]["updated_at"] or ""):
            latest[key] = row
    queue = []
    for row in latest.values():
        action = "BASKET_HARNESS_REVIEW"
        if row["status"] in {"active", "pending"}:
            action = "WAIT_ACTIVE_BASKET"
        elif row["verdict"] == "INFRA_FAIL":
            action = "FIX_HISTORY_OR_RUNNER_INFRA"
        elif row["verdict"] == "FAIL":
            action = "VERIFY_COMBINED_BASKET_PNL"
        queue.append(
            {
                "score": phase_rank(row["phase"]) * 20 + (25 if row["verdict"] in {"FAIL", "INFRA_FAIL"} else 0),
                "row": row,
                "reason": compact_reason(row),
                "action": action,
            }
        )
    return sorted(queue, key=lambda item: (-item["score"], str(item["row"]["updated_at"] or "")))[:limit]


def build_late_infra_queue(db: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    queue = []
    for key, row in db["highest_by_pair"].items():
        if row["phase"] not in {"Q05", "Q06", "Q07", "Q08"}:
            continue
        if row["verdict"] != "INFRA_FAIL":
            continue
        if (normalize_ea_id(row["ea_id"]), row["symbol"] or "") in db["q12_ready"]:
            continue
        latest = db["latest_by_pair"].get(key)
        if latest is not None and latest["status"] in {"active", "pending"}:
            continue
        queue.append(
            {
                "score": phase_rank(row["phase"]) * 25 + (10 if row["status"] == "failed" else 0),
                "row": row,
                "reason": compact_reason(row),
                "action": "RETRY_INFRA_AFTER_LOG_REVIEW",
            }
        )
    return sorted(queue, key=lambda item: (-item["score"], str(item["row"]["updated_at"] or "")))[:limit]


def build_portfolio_rejects(db: dict[str, Any], limit: int) -> list[dict[str, Any]]:
    latest: dict[tuple[str, str], sqlite3.Row] = {}
    for row in db["rows"]:
        if row["phase"] != "Q09_PORTFOLIO":
            continue
        key = (normalize_ea_id(row["ea_id"]), row["symbol"] or "")
        if key not in latest or str(row["updated_at"] or "") > str(latest[key]["updated_at"] or ""):
            latest[key] = row
    queue = []
    for row in latest.values():
        if row["verdict"] not in {"FAIL_PORTFOLIO", "NEED_MORE_DATA"}:
            continue
        queue.append(
            {
                "score": 100 if row["verdict"] == "FAIL_PORTFOLIO" else 50,
                "row": row,
                "reason": compact_reason(row),
                "action": "DO_NOT_RERUN_UNCHANGED" if row["verdict"] == "FAIL_PORTFOLIO" else "EXTEND_STREAM_OR_RECHECK_DATA",
            }
        )
    return sorted(queue, key=lambda item: (-item["score"], str(item["row"]["updated_at"] or "")))[:limit]


def build_watchlist(db: dict[str, Any], limit: int) -> list[sqlite3.Row]:
    rows = [
        row
        for row in db["rows"]
        if row["status"] in {"active", "pending"} and row["phase"] in LATE_PHASES
    ]
    return sorted(rows, key=lambda r: (phase_rank(r["phase"]), str(r["updated_at"] or "")), reverse=True)[:limit]


def build_q12_ready(db: dict[str, Any]) -> list[sqlite3.Row]:
    rows = [row for row in db["portfolio_rows"] if row["state"] == "Q12_REVIEW_READY"]
    return sorted(rows, key=lambda r: str(r["updated_at"] or ""), reverse=True)


def code_summary(counter: Counter, limit: int = 4) -> str:
    parts = [f"{key}:{value}" for key, value in counter.most_common(limit)]
    return ", ".join(parts)


def fmt_row_status(row: sqlite3.Row | None) -> str:
    if row is None:
        return "no work_items"
    verdict = row["verdict"] or "-"
    return f"{row['symbol']} {row['phase']} {row['status']}/{verdict}"


def markdown_table(headers: list[str], rows: list[list[str]]) -> list[str]:
    lines = ["| " + " | ".join(headers) + " |"]
    lines.append("|" + "|".join("---" for _ in headers) + "|")
    for row in rows:
        escaped = [str(cell).replace("|", "\\|").replace("\n", " ") for cell in row]
        lines.append("| " + " | ".join(escaped) + " |")
    return lines


def write_markdown(
    path: Path,
    *,
    db_path: Path,
    conformance_path: Path,
    conformance_queue: list[dict[str, Any]],
    basket_queue: list[dict[str, Any]],
    late_infra_queue: list[dict[str, Any]],
    portfolio_rejects: list[dict[str, Any]],
    watchlist: list[sqlite3.Row],
    q12_ready: list[sqlite3.Row],
) -> None:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    lines: list[str] = [
        "# Mis-Tested EA Rescue Queue (2026-06-27)",
        "",
        f"Generated: {now}",
        "",
        "Sources:",
        f"- Farm DB: `{db_path}`",
        f"- Conformance snapshot: `{conformance_path}`",
        "- Evidence JSONs referenced by `work_items.evidence_path`",
        "",
        "Scope: read-only triage. This report does not enqueue, cancel, or mutate farm work.",
        "",
        "## Executive Readout",
        "",
        "- Highest-confidence implementation issue: basket/logical-symbol handling. Validate combined basket PnL before treating these as edge failures.",
        "- Highest-confidence setfile issue: EAs with missing strategy parameters and time/session defaults in backtest setfiles. Rebuild setfiles from card/spec before reruns.",
        "- Do not rerun Q09 portfolio rejects unchanged when the latest reason is `q08_regime_catastrophe`; that needs a strategy or regime-filter repair.",
        "- Active/pending late-phase jobs are listed first so operators do not duplicate farm work.",
        "",
        "## Active / Pending Late-Phase Work",
        "",
    ]
    if watchlist:
        lines.extend(
            markdown_table(
                ["EA", "symbol", "phase", "status", "claimed_by", "updated"],
                [
                    [
                        row["ea_id"],
                        row["symbol"] or "",
                        row["phase"],
                        row["status"],
                        row["claimed_by"] or "",
                        row["updated_at"] or "",
                    ]
                    for row in watchlist
                ],
            )
        )
    else:
        lines.append("No active/pending late-phase rows found.")
    lines.extend(["", "## Current Q12-Ready Portfolio Candidates", ""])
    lines.extend(
        markdown_table(
            ["EA", "symbol", "state", "updated", "evidence"],
            [
                [
                    row["ea_id"],
                    row["symbol"] or "",
                    row["state"],
                    row["updated_at"] or "",
                    row["evidence_path"] or "",
                ]
                for row in q12_ready
            ],
        )
    )
    lines.extend(["", "## Basket / Logical-Symbol Harness Queue", ""])
    lines.extend(
        markdown_table(
            ["score", "EA", "symbol", "phase", "status", "verdict", "reason", "action"],
            [
                [
                    str(item["score"]),
                    item["row"]["ea_id"],
                    item["row"]["symbol"] or "",
                    item["row"]["phase"],
                    item["row"]["status"],
                    item["row"]["verdict"] or "-",
                    item["reason"],
                    item["action"],
                ]
                for item in basket_queue
            ],
        )
    )
    lines.extend(["", "## Conformance Rebuild Queue", ""])
    lines.extend(
        markdown_table(
            ["score", "EA", "audit name", "current", "high", "top codes", "symbols", "action"],
            [
                [
                    str(item["score"]),
                    item["ea_id"],
                    item["name"],
                    fmt_row_status(item["current"]),
                    str(item["high_findings"]),
                    code_summary(item["codes"]),
                    ", ".join(item["symbols"]),
                    item["action"],
                ]
                for item in conformance_queue
            ],
        )
    )
    lines.extend(["", "## Late Infra Retry Queue", ""])
    lines.extend(
        markdown_table(
            ["score", "EA", "symbol", "phase", "status", "reason", "action"],
            [
                [
                    str(item["score"]),
                    item["row"]["ea_id"],
                    item["row"]["symbol"] or "",
                    item["row"]["phase"],
                    f"{item['row']['status']}/{item['row']['verdict'] or '-'}",
                    item["reason"],
                    item["action"],
                ]
                for item in late_infra_queue
            ],
        )
    )
    lines.extend(["", "## Portfolio Rejects / Do Not Rerun Unchanged", ""])
    lines.extend(
        markdown_table(
            ["score", "EA", "symbol", "verdict", "reason", "updated", "action"],
            [
                [
                    str(item["score"]),
                    item["row"]["ea_id"],
                    item["row"]["symbol"] or "",
                    item["row"]["verdict"] or "-",
                    item["reason"],
                    item["row"]["updated_at"] or "",
                    item["action"],
                ]
                for item in portfolio_rejects
            ],
        )
    )
    lines.extend(
        [
            "",
            "## Recommended Operator Order",
            "",
            "1. Let active Q04/Q07/Q08 rows finish; harvest their evidence before adding duplicate work.",
            "2. Investigate the basket/logical-symbol rows first. If combined-basket PnL is not what Q04/Q02 evaluated, repair harness behavior before any edge judgment.",
            "3. For conformance rows, regenerate backtest setfiles from card/spec and compare strategy_* inputs before rerunning pipeline phases.",
            "4. For late infra rows, read the work-item log/evidence first; retry only after the launch/report/history failure is understood.",
            "5. Treat Q09 `q08_regime_catastrophe` rejects as strategy-repair work, not as admission retries.",
            "",
        ]
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--conformance-json", type=Path, default=DEFAULT_CONFORMANCE_JSON)
    parser.add_argument("--markdown", type=Path, default=DEFAULT_MARKDOWN)
    parser.add_argument("--limit", type=int, default=15)
    args = parser.parse_args()

    conformance = load_conformance(args.conformance_json)
    db = load_db(args.db)
    write_markdown(
        args.markdown,
        db_path=args.db,
        conformance_path=args.conformance_json,
        conformance_queue=build_conformance_queue(conformance, db, args.limit),
        basket_queue=build_basket_queue(db, args.limit),
        late_infra_queue=build_late_infra_queue(db, args.limit),
        portfolio_rejects=build_portfolio_rejects(db, args.limit),
        watchlist=build_watchlist(db, args.limit),
        q12_ready=build_q12_ready(db),
    )
    print(str(args.markdown))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
