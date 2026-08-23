"""Role-based service metrics and adjudication inspection for the news gate."""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path
from typing import Any, Iterable


EXPANSION_REASON = "expanded_7x4_matrix_required"
CONCLUSIVE_VERDICTS = frozenset({"CONFIG_LOCKED"})


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verified_expansion_adjudication(
    aggregate_path: str | Path | None,
    aggregate_sha256: str | None,
) -> dict[str, Any] | None:
    """Return an authenticated expansion request, otherwise ``None``.

    The aggregate is immutable contract evidence.  A missing file, hash drift,
    malformed JSON, or any additional/different reason is not an expansion
    authorization and therefore fails closed.
    """

    raw_path = str(aggregate_path or "").strip()
    expected = str(aggregate_sha256 or "").strip().lower()
    if not raw_path or len(expected) != 64:
        return None
    path = Path(raw_path)
    try:
        if not path.is_file() or _sha256_file(path).lower() != expected:
            return None
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    if not isinstance(payload, dict):
        return None
    if payload.get("verdict") != "REVIEW_REQUIRED":
        return None
    if payload.get("reason_codes") != [EXPANSION_REASON]:
        return None
    return payload


def expansion_requests(
    connection: sqlite3.Connection,
    *,
    news_phases: Iterable[str],
) -> list[dict[str, Any]]:
    """Return the newest authenticated expansion request per exact identity."""

    phases = tuple(dict.fromkeys(str(value) for value in news_phases))
    if not phases:
        return []
    placeholders = ",".join("?" for _ in phases)
    rows = connection.execute(
        f"""
        SELECT w.id,w.phase,w.ea_id,w.symbol,w.setfile_path,w.status,w.verdict,
               w.payload_json,w.created_at,w.updated_at,w.gate_contract_version,
               t.aggregate_path,t.aggregate_sha256,t.contract_version
        FROM work_items w
        JOIN q09_news_tests t ON t.work_item_id=w.id
        WHERE w.phase IN ({placeholders})
          AND w.status='done' AND w.verdict='REVIEW_REQUIRED'
        ORDER BY w.updated_at DESC,w.id DESC
        """,
        phases,
    ).fetchall()
    requests: list[dict[str, Any]] = []
    seen: set[tuple[str, str, str]] = set()
    for row in rows:
        candidate = dict(row)
        identity = (
            str(candidate["ea_id"]),
            str(candidate["symbol"]),
            str(candidate["setfile_path"]),
        )
        if identity in seen:
            continue
        adjudication = verified_expansion_adjudication(
            candidate.get("aggregate_path"), candidate.get("aggregate_sha256")
        )
        if adjudication is None:
            continue
        seen.add(identity)
        candidate["adjudication"] = adjudication
        requests.append(candidate)
    return requests


def service_metrics(
    connection: sqlite3.Connection,
    *,
    news_phases: Iterable[str],
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Measure gate conclusions, unresolved expansions, and legacy placeholders."""

    phases = tuple(dict.fromkeys(str(value) for value in news_phases))
    if not phases:
        raise ValueError("at least one news storage phase is required")
    placeholders = ",".join("?" for _ in phases)
    observed_at = now or dt.datetime.now(dt.timezone.utc)
    if observed_at.tzinfo is None:
        observed_at = observed_at.replace(tzinfo=dt.timezone.utc)
    cutoff = (observed_at.astimezone(dt.timezone.utc) - dt.timedelta(days=1)).isoformat()
    verdict_placeholders = ",".join("?" for _ in CONCLUSIVE_VERDICTS)
    conclusive = int(
        connection.execute(
            f"""
            SELECT count(*) FROM work_items
            WHERE phase IN ({placeholders}) AND status='done'
              AND verdict IN ({verdict_placeholders}) AND updated_at>=?
            """,
            (*phases, *sorted(CONCLUSIVE_VERDICTS), cutoff),
        ).fetchone()[0]
    )
    placeholder_count = int(
        connection.execute(
            f"SELECT count(*) FROM work_items WHERE phase IN ({placeholders}) "
            "AND status='done' AND verdict='PENDING_RUNNER'",
            phases,
        ).fetchone()[0]
    )
    requests = expansion_requests(connection, news_phases=phases)
    pending: list[dict[str, Any]] = []
    for request in requests:
        children = connection.execute(
            """
            SELECT id,status,verdict FROM work_items
            WHERE json_valid(payload_json)=1
              AND json_extract(payload_json,'$.news_expansion_of_work_item')=?
            ORDER BY created_at DESC,id DESC
            """,
            (request["id"],),
        ).fetchall()
        concluded = any(
            str(child["status"]) == "done"
            and str(child["verdict"]) in CONCLUSIVE_VERDICTS
            for child in children
        )
        if not concluded:
            pending.append(
                {
                    "source_work_item_id": request["id"],
                    "ea_id": request["ea_id"],
                    "symbol": request["symbol"],
                    "children": [dict(child) for child in children],
                }
            )
    return {
        "window_hours": 24,
        "conclusive_verdicts_per_day": conclusive,
        "expansions_pending": len(pending),
        "expansion_pending_rows": pending,
        "pending_runner_count": placeholder_count,
    }
