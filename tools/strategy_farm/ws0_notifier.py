"""One-shot WS-0 clear notifier.

This is intentionally separate from the recurring health alarm. It sends at
most once, then persists a sentinel so pump/health cycles cannot spam OWNER.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import sqlite3
from pathlib import Path
from typing import Any, Callable


CUTOFF_UTC = "2026-05-22T07:41:37+00:00"
SENTINEL_REL = Path("state") / "ws0_notified.json"
REAL_WS0_VERDICTS = {"PASS", "FAIL", "ZERO_TRADES"}


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def _db_path(root: Path) -> Path:
    return root / "state" / "farm_state.sqlite"


def _write_json_atomic(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(f"{path.name}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(path)


def _first_real_ws0_verdict(root: Path, cutoff_utc: str = CUTOFF_UTC) -> dict[str, Any] | None:
    db = _db_path(root)
    if not db.exists():
        return None
    con = sqlite3.connect(db, timeout=30)
    con.row_factory = sqlite3.Row
    try:
        row = con.execute(
            """
            SELECT id, ea_id, symbol, verdict, evidence_path, updated_at
            FROM work_items
            WHERE status='done'
              AND phase IN ('P2', 'Q02')
              AND UPPER(COALESCE(verdict, '')) IN ('PASS', 'FAIL', 'ZERO_TRADES')
              AND updated_at > ?
            ORDER BY updated_at ASC
            LIMIT 1
            """,
            (cutoff_utc,),
        ).fetchone()
    finally:
        con.close()
    return dict(row) if row else None


def _default_send_mail(subject: str, body: str) -> dict[str, Any]:
    try:
        from gmail_alarm import _send_mail
    except ModuleNotFoundError:
        from tools.strategy_farm.gmail_alarm import _send_mail
    return _send_mail(subject, body)


def check_and_notify(
    root: Path,
    *,
    send_mail: Callable[[str, str], dict[str, Any]] | None = None,
    cutoff_utc: str = CUTOFF_UTC,
) -> dict[str, Any]:
    """Send the WS-0 clear email once after the first real P2/Q02 verdict."""
    sentinel = root / SENTINEL_REL
    if sentinel.exists():
        try:
            payload = json.loads(sentinel.read_text(encoding="utf-8"))
        except Exception:
            payload = {"sentinel": str(sentinel), "unreadable": True}
        return {"triggered": False, "reason": "already_disarmed", "sentinel": str(sentinel), "payload": payload}

    verdict_row = _first_real_ws0_verdict(root, cutoff_utc=cutoff_utc)
    if not verdict_row:
        return {"triggered": False, "reason": "no_real_ws0_verdict_after_cutoff", "cutoff_utc": cutoff_utc}

    subject = "WS-0 cleared"
    body = (
        "WS-0 cleared: first real P2/Q02 verdict recorded.\n\n"
        f"EA: {verdict_row.get('ea_id')}\n"
        f"Symbol: {verdict_row.get('symbol')}\n"
        f"Verdict: {verdict_row.get('verdict')}\n"
        f"Work item: {verdict_row.get('id')}\n"
        f"Updated at: {verdict_row.get('updated_at')}\n"
        f"Evidence: {verdict_row.get('evidence_path') or ''}\n"
    )

    payload: dict[str, Any] = {
        "disarmed_at": _utc_now(),
        "event": "ws0_cleared",
        "cutoff_utc": cutoff_utc,
        "subject": subject,
        "work_item": verdict_row,
        "mail_result": {"sent": False, "reason": "not attempted"},
    }
    _write_json_atomic(sentinel, payload)

    sender = send_mail or _default_send_mail
    mail_result = sender(subject, body)
    payload["mail_result"] = mail_result
    payload["mail_attempted_at"] = _utc_now()
    _write_json_atomic(sentinel, payload)
    return {"triggered": True, "sentinel": str(sentinel), "work_item": verdict_row, "mail_result": mail_result}
