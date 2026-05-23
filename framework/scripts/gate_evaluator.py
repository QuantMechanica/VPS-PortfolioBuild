#!/usr/bin/env python3
"""Evaluate completed MT5 worker-pool jobs and drive next actions.

Scope (QUA-1579):
- PASS path: mark processed and enqueue next-phase job(s)
- FAIL/INVALID infra path: bounded retry + terminal failure state
- FAIL strategy path (MIN_TRADES_NOT_MET): block + dispatch zero-trades escalation
"""

from __future__ import annotations

import argparse
import json
import sqlite3
import subprocess
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PHASE_SEQUENCE = ["P0", "P1", "P2", "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8"]
INFRA_RETRY_TOKENS = ("no_summary_json:rc=1", "REPORT_MISSING", "missing_verdict")
ZERO_TRADES_TOKEN = "MIN_TRADES_NOT_MET"
ZERO_TRADES_AGENT_ID = "8ba981d2-a750-4566-9681-e237fa66261f"
DEFAULT_TESTER_DEFAULTS = Path(r"C:\QM\repo\framework\registry\tester_defaults.json")
DEFAULT_ZERO_TRADES_TEMPLATE = Path(r"C:\QM\repo\framework\registry\zero_trades_dispatch_template.md")
VERIFY_BUILD_DEPLOYMENT_SCRIPT = Path(r"C:\QM\repo\framework\scripts\verify_build_deployment.py")


@dataclass
class EvalResult:
    processed: int = 0
    pass_count: int = 0
    requeued_count: int = 0
    failed_terminal_count: int = 0
    blocked_strategy_count: int = 0
    escalations_created: int = 0
    pass_gate_failed_count: int = 0
    rollforward_failed_count: int = 0


def utc_now_iso() -> str:
    return datetime.now(tz=timezone.utc).isoformat()


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    rows = conn.execute(f"PRAGMA table_info({table})").fetchall()
    return any(str(row[1]) == column for row in rows)


def ensure_columns(conn: sqlite3.Connection) -> None:
    if not _column_exists(conn, "jobs", "verdict_processed_at"):
        conn.execute("ALTER TABLE jobs ADD COLUMN verdict_processed_at TEXT")
    if not _column_exists(conn, "jobs", "escalation_issue_id"):
        conn.execute("ALTER TABLE jobs ADD COLUMN escalation_issue_id TEXT")
    if not _column_exists(conn, "jobs", "source_issue_id"):
        conn.execute("ALTER TABLE jobs ADD COLUMN source_issue_id TEXT")
    conn.commit()


def next_phase(phase: str) -> str | None:
    normalized = str(phase or "").strip()
    try:
        idx = PHASE_SEQUENCE.index(normalized)
    except ValueError:
        return None
    if idx >= len(PHASE_SEQUENCE) - 1:
        return None
    return PHASE_SEQUENCE[idx + 1]


def is_infra_retry_reason(text: str) -> bool:
    blob = str(text or "")
    return any(token in blob for token in INFRA_RETRY_TOKENS)


def is_zero_trades_reason(text: str) -> bool:
    return ZERO_TRADES_TOKEN in str(text or "")


def load_tester_defaults(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _extract_metric(summary: dict[str, Any], keys: list[str]) -> float | None:
    for key in keys:
        if key in summary:
            try:
                return float(summary[key])
            except Exception:
                return None
    return None


def evaluate_pass_gate(summary_path: str, tester_defaults: dict[str, Any]) -> tuple[bool, str]:
    if not summary_path:
        return False, "gate_eval:no_summary_path"
    p = Path(summary_path)
    if p.is_dir():
        p = p / "summary.json"
    if not p.exists():
        return False, "gate_eval:summary_missing"
    try:
        summary = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return False, "gate_eval:summary_unparseable"

    anti = tester_defaults.get("anti_theater_gates", {}) if isinstance(tester_defaults, dict) else {}
    min_trades = int(anti.get("min_trade_count", 1))
    trades = _extract_metric(summary, ["trade_count", "trades", "total_trades", "num_trades"])
    if trades is None:
        return False, "gate_eval:trade_count_missing"
    if trades < min_trades:
        return False, f"gate_eval:trades_below_min:{int(trades)}<{min_trades}"

    # Optional stricter thresholds if present in tester_defaults.json.
    # This keeps compatibility with current file while allowing future PF/DD constraints.
    criteria = tester_defaults.get("phase_gate_criteria", {}) if isinstance(tester_defaults, dict) else {}
    min_pf = criteria.get("min_profit_factor")
    max_dd = criteria.get("max_drawdown_pct")
    if min_pf is not None:
        pf = _extract_metric(summary, ["profit_factor", "pf"])
        if pf is None:
            return False, "gate_eval:profit_factor_missing"
        if pf < float(min_pf):
            return False, f"gate_eval:pf_below_min:{pf:.4f}<{float(min_pf):.4f}"
    if max_dd is not None:
        dd = _extract_metric(summary, ["max_drawdown_pct", "drawdown_pct", "max_dd_pct"])
        if dd is None:
            return False, "gate_eval:max_drawdown_missing"
        if dd > float(max_dd):
            return False, f"gate_eval:dd_above_max:{dd:.4f}>{float(max_dd):.4f}"

    return True, ""


def run_rollforward_scripts(
    *, ea_id: str, setfile_path: str, symbol: str, period: str, next_phase: str, dry_run: bool
) -> tuple[bool, str]:
    if dry_run:
        return True, ""
    # Best-effort EA slug resolution from setfile path or ea_id.
    ea_slug = infer_ea_slug(setfile_path=setfile_path, ea_id=ea_id)
    ex5_path = rf"C:\QM\repo\framework\EAs\{ea_slug}\{ea_slug}.ex5"
    # Script names/params are deterministic; if wrappers evolve, keep this as the call boundary.
    gen_cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        r"C:\QM\repo\framework\scripts\gen_setfile.ps1",
        "-EaSlug",
        ea_slug,
        "-Symbol",
        symbol,
        "-TF",
        period,
        "-Env",
        "backtest",
    ]
    dep_cmd = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        r"C:\QM\repo\framework\scripts\deploy_ea_to_all_terminals.ps1",
        "-EaPath",
        ex5_path,
    ]
    try:
        gen = subprocess.run(gen_cmd, capture_output=True, text=True, check=False)
        if int(gen.returncode) != 0:
            return False, f"rollforward:setfile_failed:rc={gen.returncode}"
        dep = subprocess.run(dep_cmd, capture_output=True, text=True, check=False)
        if int(dep.returncode) != 0:
            return False, f"rollforward:deploy_failed:rc={dep.returncode}"
    except Exception as exc:
        return False, f"rollforward:exception:{exc}"
    return True, ""


def _normalize_ea_numeric_id(ea_id: str) -> str:
    raw = str(ea_id or "").strip()
    if raw.startswith("QM5_"):
        parts = raw.split("_", 2)
        if len(parts) >= 2:
            return parts[1]
    return raw


def run_build_deployment_verifier(
    *,
    ea_id: str,
    setfile_path: str,
    dry_run: bool,
) -> tuple[bool, str, dict[str, Any]]:
    if dry_run:
        return True, "", {"verdict": "PASS", "exit_code": 0, "dry_run": True}
    if not VERIFY_BUILD_DEPLOYMENT_SCRIPT.exists():
        return False, "build_verify:script_missing", {"verdict": "VERIFY_SCRIPT_MISSING"}
    ea_slug = infer_ea_slug(setfile_path=setfile_path, ea_id=ea_id)
    ea_dir_glob = f"{ea_slug}*"
    cmd = [
        "python",
        str(VERIFY_BUILD_DEPLOYMENT_SCRIPT),
        "--json",
        "--ea-id",
        _normalize_ea_numeric_id(ea_id),
        "--ea-dir-glob",
        ea_dir_glob,
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except Exception as exc:
        return False, f"build_verify:exception:{exc}", {"verdict": "VERIFY_EXCEPTION"}
    payload: dict[str, Any]
    try:
        payload = json.loads(proc.stdout or "{}")
    except Exception:
        payload = {"stdout": (proc.stdout or "")[:1000], "stderr": (proc.stderr or "")[:1000]}
    verdict = str(payload.get("verdict") or "").strip().upper()
    if int(proc.returncode) == 0 and verdict == "PASS":
        return True, "", payload
    reason = f"build_verify:{verdict or 'FAILED'}:rc={int(proc.returncode)}"
    return False, reason, payload


def infer_ea_slug(setfile_path: str, ea_id: str) -> str:
    text = str(setfile_path or "")
    norm = text.replace("\\", "/")
    parts = [p for p in norm.split("/") if p]
    for part in parts:
        if part.startswith("QM5_"):
            return part
    if str(ea_id).startswith("QM5_"):
        return str(ea_id)
    return f"QM5_{str(ea_id)}"


def create_zero_trades_issue(
    *,
    base_url: str,
    company_id: str,
    project_id: str,
    parent_issue_id: str | None,
    job: dict[str, Any],
    template_path: Path,
    dry_run: bool,
) -> str | None:
    title = f"Zero-Trades recovery: {job['ea_id']} {job['phase']} {job['symbol']}"
    inline_body = (
        "Auto-created by gate_evaluator.py after strategy-level FAIL.\n\n"
        f"- ea_id: {job['ea_id']}\n"
        f"- phase: {job['phase']}\n"
        f"- symbol: {job['symbol']}\n"
        f"- reason: {job.get('invalidation_reason') or job.get('verdict')}\n"
        f"- result_path: {job.get('result_path') or ''}\n"
        f"- source_job_id: {job['job_id']}\n"
    )
    body = inline_body
    if template_path.exists():
        try:
            tmpl = template_path.read_text(encoding="utf-8")
            body = (
                tmpl.replace("{ea_id}", str(job["ea_id"]))
                .replace("{phase}", str(job["phase"]))
                .replace("{symbol}", str(job["symbol"]))
                .replace("{reason}", str(job.get("invalidation_reason") or job.get("verdict") or ""))
                .replace("{result_path}", str(job.get("result_path") or ""))
                .replace("{source_job_id}", str(job["job_id"]))
            )
        except Exception:
            body = inline_body
    if dry_run:
        return "DRY_RUN"
    payload: dict[str, Any] = {
        "companyId": company_id,
        "projectId": project_id,
        "parentId": parent_issue_id,
        "title": title,
        "description": body,
        "priority": "high",
        "assigneeAgentId": ZERO_TRADES_AGENT_ID,
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/issues",
        data=data,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            response = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return None
    return str(response.get("id") or response.get("identifier") or "")


def reopen_issue_and_comment(
    *,
    base_url: str,
    issue_id: str,
    verifier_payload: dict[str, Any],
    dry_run: bool,
) -> bool:
    issue_key = str(issue_id or "").strip()
    if not issue_key:
        return False
    if dry_run:
        return True
    patch_req = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/issues/{issue_key}",
        data=json.dumps({"status": "in_progress"}).encode("utf-8"),
        method="PATCH",
        headers={"Content-Type": "application/json"},
    )
    comment_body = (
        "build_deployment_verifier failed for completed P0 job.\n\n"
        "```json\n"
        f"{json.dumps(verifier_payload, ensure_ascii=False, indent=2)}\n"
        "```"
    )
    comment_req = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/issues/{issue_key}/comments",
        data=json.dumps({"body": comment_body}).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(patch_req, timeout=10):
            pass
        with urllib.request.urlopen(comment_req, timeout=10):
            pass
        return True
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
        return False


def _fetch_ready_rows(conn: sqlite3.Connection, limit: int) -> list[dict[str, Any]]:
    has_vpa = _column_exists(conn, "jobs", "verdict_processed_at")
    has_eid = _column_exists(conn, "jobs", "escalation_issue_id")
    has_sid = _column_exists(conn, "jobs", "source_issue_id")
    select_vpa = "verdict_processed_at" if has_vpa else "NULL AS verdict_processed_at"
    select_eid = "escalation_issue_id" if has_eid else "'' AS escalation_issue_id"
    select_sid = "source_issue_id" if has_sid else "'' AS source_issue_id"
    where_vpa = "AND verdict_processed_at IS NULL" if has_vpa else ""
    rows = conn.execute(
        f"""
        SELECT
          job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash,
          setfile_path, status, verdict, invalidation_reason, retry_count, result_path, {select_eid}, {select_sid}, {select_vpa}
        FROM jobs
        WHERE status='done' {where_vpa}
        ORDER BY finished_at ASC, enqueued_at ASC
        LIMIT ?
        """,
        (max(1, int(limit)),),
    ).fetchall()
    payload: list[dict[str, Any]] = []
    for row in rows:
        payload.append(
            {
                "job_id": str(row[0]),
                "ea_id": str(row[1]),
                "version": str(row[2]),
                "symbol": str(row[3]),
                "period": str(row[4]),
                "year": int(row[5]),
                "phase": str(row[6]),
                "sub_gate_config_hash": str(row[7]),
                "setfile_path": str(row[8]),
                "status": str(row[9]),
                "verdict": str(row[10] or ""),
                "invalidation_reason": str(row[11] or ""),
                "retry_count": int(row[12] or 0),
                "result_path": str(row[13] or ""),
                "escalation_issue_id": str(row[14] or ""),
                "source_issue_id": str(row[15] or ""),
                "verdict_processed_at": str(row[16] or ""),
            }
        )
    return payload


def _enqueue_next_job(conn: sqlite3.Connection, row: dict[str, Any], next_p: str, ts: str) -> None:
    next_hash = f"{row['ea_id']}|{row['version']}|{row['symbol']}|{next_p}|{row['year']}"
    new_job_id = f"{row['job_id']}::{next_p}"
    conn.execute(
        """
        INSERT OR IGNORE INTO jobs
        (job_id, ea_id, version, symbol, period, year, phase, sub_gate_config_hash, setfile_path,
         status, retry_count, enqueued_at, enqueued_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'queued', 0, ?, 'gate_evaluator')
        """,
        (
            new_job_id,
            row["ea_id"],
            row["version"],
            row["symbol"],
            row["period"],
            row["year"],
            next_p,
            next_hash,
            row["setfile_path"],
            ts,
        ),
    )


def evaluate(
    *,
    sqlite_path: Path,
    max_retries: int,
    limit: int,
    paperclip_base: str,
    company_id: str,
    project_id: str,
    parent_issue_id: str | None,
    tester_defaults_path: Path,
    zero_trades_template_path: Path,
    dry_run: bool,
) -> EvalResult:
    result = EvalResult()
    conn = sqlite3.connect(str(sqlite_path))
    try:
        if not dry_run:
            ensure_columns(conn)
        tester_defaults = load_tester_defaults(tester_defaults_path)
        rows = _fetch_ready_rows(conn, limit)
        now = utc_now_iso()
        for row in rows:
            verdict = row["verdict"].upper()
            reason = row["invalidation_reason"]
            if not verdict:
                reason = reason or "missing_verdict"
                verdict = "INVALID"
            if verdict == "PASS":
                if row["phase"] == "P0":
                    verify_ok, verify_reason, verify_payload = run_build_deployment_verifier(
                        ea_id=row["ea_id"],
                        setfile_path=row["setfile_path"],
                        dry_run=dry_run,
                    )
                    if not verify_ok:
                        source_issue_id = str(row.get("source_issue_id") or "").strip()
                        reopen_issue_and_comment(
                            base_url=paperclip_base,
                            issue_id=source_issue_id,
                            verifier_payload=verify_payload,
                            dry_run=dry_run,
                        )
                        if not dry_run:
                            conn.execute(
                                "UPDATE jobs SET status='invalid', verdict=?, invalidation_reason=?, result_path=?, verdict_processed_at=? WHERE job_id=?",
                                (
                                    str(verify_payload.get("verdict") or "GHOST_BUILD"),
                                    verify_reason,
                                    json.dumps(verify_payload, ensure_ascii=False),
                                    now,
                                    row["job_id"],
                                ),
                            )
                        result.pass_gate_failed_count += 1
                        result.processed += 1
                        continue
                if row["phase"] != "P0":
                    pass_ok, pass_reason = evaluate_pass_gate(row.get("result_path", ""), tester_defaults)
                    if not pass_ok:
                        if not dry_run:
                            conn.execute(
                                "UPDATE jobs SET status='invalid', verdict='INVALID', invalidation_reason=?, verdict_processed_at=? WHERE job_id=?",
                                (pass_reason, now, row["job_id"]),
                            )
                        result.pass_gate_failed_count += 1
                        result.processed += 1
                        continue
                nxt = next_phase(row["phase"])
                if nxt is not None:
                    ok, roll_reason = run_rollforward_scripts(
                        ea_id=row["ea_id"],
                        setfile_path=row["setfile_path"],
                        symbol=row["symbol"],
                        period=row["period"],
                        next_phase=nxt,
                        dry_run=dry_run,
                    )
                    if not ok:
                        if not dry_run:
                            conn.execute(
                                "UPDATE jobs SET status='failed_terminal', invalidation_reason=?, verdict_processed_at=? WHERE job_id=?",
                                (roll_reason, now, row["job_id"]),
                            )
                        result.rollforward_failed_count += 1
                        result.processed += 1
                        continue
                    if not dry_run:
                        _enqueue_next_job(conn, row, nxt, now)
                if not dry_run:
                    conn.execute(
                        "UPDATE jobs SET verdict_processed_at=? WHERE job_id=?",
                        (now, row["job_id"]),
                    )
                result.pass_count += 1
                result.processed += 1
                continue

            if verdict in {"FAIL", "INVALID"} and is_infra_retry_reason(reason):
                retries = int(row["retry_count"]) + 1
                if retries < max_retries:
                    if not dry_run:
                        conn.execute(
                            """
                            UPDATE jobs
                            SET status='queued', retry_count=?, claimed_by=NULL, claimed_at=NULL,
                                started_at=NULL, finished_at=NULL, verdict=NULL, invalidation_reason=NULL,
                                result_path=NULL, verdict_processed_at=NULL
                            WHERE job_id=?
                            """,
                            (retries, row["job_id"]),
                        )
                    result.requeued_count += 1
                else:
                    if not dry_run:
                        conn.execute(
                            "UPDATE jobs SET status='failed_terminal', retry_count=?, verdict_processed_at=? WHERE job_id=?",
                            (retries, now, row["job_id"]),
                        )
                    result.failed_terminal_count += 1
                result.processed += 1
                continue

            if verdict == "FAIL" and is_zero_trades_reason(reason):
                issue_id = row.get("escalation_issue_id") or ""
                if not issue_id:
                    issue_id = create_zero_trades_issue(
                        base_url=paperclip_base,
                        company_id=company_id,
                        project_id=project_id,
                        parent_issue_id=parent_issue_id,
                        job=row,
                        template_path=zero_trades_template_path,
                        dry_run=dry_run,
                    ) or ""
                if not dry_run:
                    conn.execute(
                        "UPDATE jobs SET status='blocked_strategy', escalation_issue_id=?, verdict_processed_at=? WHERE job_id=?",
                        (issue_id, now, row["job_id"]),
                    )
                result.blocked_strategy_count += 1
                if issue_id:
                    result.escalations_created += 1
                result.processed += 1
                continue

            if not dry_run:
                conn.execute("UPDATE jobs SET verdict_processed_at=? WHERE job_id=?", (now, row["job_id"]))
            result.processed += 1

        if not dry_run:
            conn.commit()
    finally:
        conn.close()
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Process completed MT5 queue jobs and roll gate decisions forward.")
    parser.add_argument("--sqlite", required=True, help="Path to mt5_queue.db")
    parser.add_argument("--max-retries", type=int, default=3, help="Infra retry cap")
    parser.add_argument("--limit", type=int, default=200, help="Max completed rows per tick")
    parser.add_argument("--paperclip-base", default="http://127.0.0.1:3100", help="Paperclip API base URL")
    parser.add_argument("--company-id", default="03d4dcc8-4cea-4133-9f68-90c0d99628fb")
    parser.add_argument("--project-id", default="71b6d994-70ba-4a28-bd62-732b42a9ea58")
    parser.add_argument("--parent-issue-id", default="", help="Optional parent issue for escalation issues")
    parser.add_argument("--tester-defaults", default=str(DEFAULT_TESTER_DEFAULTS))
    parser.add_argument("--zero-trades-template", default=str(DEFAULT_ZERO_TRADES_TEMPLATE))
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = evaluate(
        sqlite_path=Path(args.sqlite),
        max_retries=max(1, int(args.max_retries)),
        limit=max(1, int(args.limit)),
        paperclip_base=str(args.paperclip_base),
        company_id=str(args.company_id),
        project_id=str(args.project_id),
        parent_issue_id=str(args.parent_issue_id or "") or None,
        tester_defaults_path=Path(str(args.tester_defaults)),
        zero_trades_template_path=Path(str(args.zero_trades_template)),
        dry_run=bool(args.dry_run),
    )
    print(json.dumps(summary.__dict__, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
