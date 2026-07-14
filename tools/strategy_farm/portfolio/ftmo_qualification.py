"""Fail-closed FTMO Challenge qualification inventory.

The DXZ portfolio-rescue route intentionally accepts selected Q08 soft fails.
That state is useful for portfolio research but is not sufficient evidence for
a paid prop challenge. This tool keeps the two contracts separate and never
modifies the factory database.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import sqlite3
from pathlib import Path
from typing import Any, Iterable

try:
    from .portfolio_common import DEFAULT_CANDIDATES_DB, DEFAULT_COMMON_DIR
except ImportError:  # pragma: no cover - direct script execution
    from portfolio_common import DEFAULT_CANDIDATES_DB, DEFAULT_COMMON_DIR  # type: ignore


DEFAULT_REPO_ROOT = Path(r"C:\QM\repo")
STRICT_PHASES = ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q10")
RESEARCH_LEAD_Q08_VERDICTS = {"FAIL_SOFT"}
KEY_RE = re.compile(r"^(?:QM5_)?(?P<ea_id>\d+):(?P<symbol>.+)$", re.IGNORECASE)


def normalize_ea_label(value: Any) -> str:
    match = re.search(r"(?:QM5_)?(\d+)", str(value or ""), re.IGNORECASE)
    if not match:
        raise ValueError(f"invalid EA id: {value!r}")
    return f"QM5_{int(match.group(1))}"


def parse_keys(raw: str | None) -> list[tuple[str, str]] | None:
    if raw is None or not raw.strip():
        return None
    keys: list[tuple[str, str]] = []
    for token in raw.split(","):
        match = KEY_RE.match(token.strip())
        if not match:
            raise ValueError(f"invalid key {token!r}; expected EA_ID:SYMBOL")
        keys.append((normalize_ea_label(match.group("ea_id")), match.group("symbol").strip().upper()))
    return keys


def discover_keys(conn: sqlite3.Connection) -> list[tuple[str, str]]:
    rows = conn.execute(
        """
        SELECT DISTINCT ea_id, symbol
        FROM work_items
        WHERE phase IN ('Q07', 'Q08', 'Q10')
          AND status='done'
        ORDER BY ea_id, symbol
        """
    ).fetchall()
    return [(normalize_ea_label(row[0]), str(row[1] or "").upper()) for row in rows]


def _latest_phase_row(
    conn: sqlite3.Connection,
    ea_id: str,
    symbol: str,
    phase: str,
) -> sqlite3.Row | None:
    return conn.execute(
        """
        SELECT * FROM work_items
        WHERE ea_id=? AND symbol=? AND phase=? AND status='done'
        ORDER BY updated_at DESC, created_at DESC, id DESC
        LIMIT 1
        """,
        (ea_id, symbol, phase),
    ).fetchone()


def _active_magic_registered(registry_path: Path, ea_id: str, symbol: str) -> bool:
    if not registry_path.exists():
        return False
    numeric = str(int(ea_id.removeprefix("QM5_")))
    with registry_path.open(encoding="utf-8-sig", newline="") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("ea_id") or "").strip() != numeric:
                continue
            if str(row.get("symbol") or "").strip().upper() != symbol:
                continue
            if str(row.get("status") or "").strip().lower() == "active":
                return True
    return False


def _mtime_utc(path: Path) -> str | None:
    try:
        return dt.datetime.fromtimestamp(path.stat().st_mtime, tz=dt.UTC).isoformat()
    except OSError:
        return None


def _build_evidence(repo_root: Path, ea_id: str) -> tuple[bool, str | None, int | None]:
    dirs = sorted((repo_root / "framework" / "EAs").glob(f"{ea_id}_*"))
    if len(dirs) != 1:
        return False, f"ea_dir_count:{len(dirs)}", None
    ex5_files = list(dirs[0].glob("*.ex5"))
    if len(ex5_files) != 1:
        return False, f"ex5_count:{len(ex5_files)}", None
    try:
        modified_ns = ex5_files[0].stat().st_mtime_ns
    except OSError:
        return False, f"ex5_stat_failed:{ex5_files[0]}", None
    return True, str(ex5_files[0]), modified_ns


def _stream_path(common_dir: Path, ea_id: str, symbol: str) -> Path:
    numeric = int(ea_id.removeprefix("QM5_"))
    return common_dir / "QM" / "q08_trades" / f"{numeric}_{symbol.replace('.', '_')}.jsonl"


def _stream_evidence(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {
            "path": str(path),
            "exists": False,
            "trade_count": 0,
            "fresh_mae": False,
            "modified_at_utc": None,
        }
    trade_count = 0
    invalid_rows = 0
    missing_mae_rows = 0
    with path.open(encoding="utf-8", errors="replace") as handle:
        for line in handle:
            if not line.strip():
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                invalid_rows += 1
                continue
            if str(row.get("event") or "TRADE_CLOSED") != "TRADE_CLOSED":
                continue
            trade_count += 1
            if row.get("entry_time") is None or row.get("mae_acct") is None:
                missing_mae_rows += 1
    return {
        "path": str(path),
        "exists": True,
        "trade_count": trade_count,
        "invalid_rows": invalid_rows,
        "missing_mae_rows": missing_mae_rows,
        "fresh_mae": trade_count > 0 and invalid_rows == 0 and missing_mae_rows == 0,
        "modified_at_utc": _mtime_utc(path),
    }


def _q08_baseline_stream(evidence_path: Path | None) -> tuple[Path | None, str | None]:
    """Resolve the durable baseline stream linked by the Q08 aggregate.

    Common\\Files is a volatile tester workspace. Q08.5 neighborhood runs reuse
    the same filename and leave the final perturbation there, so it cannot prove
    which parameter set produced the strict Q08 verdict.
    """
    if evidence_path is None or not evidence_path.exists():
        return None, "q08_evidence_unavailable"
    try:
        aggregate = json.loads(evidence_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None, "q08_evidence_unreadable"
    portfolio_stream = aggregate.get("portfolio_stream")
    if not isinstance(portfolio_stream, dict):
        return None, "portfolio_stream_missing"
    if portfolio_stream.get("persisted") is not True:
        return None, "portfolio_stream_not_persisted"
    raw_path = portfolio_stream.get("path")
    if not raw_path:
        return None, "portfolio_stream_path_missing"
    return Path(str(raw_path)), None


def evaluate_candidate(
    conn: sqlite3.Connection,
    ea_id: str,
    symbol: str,
    *,
    repo_root: Path = DEFAULT_REPO_ROOT,
    common_dir: Path = DEFAULT_COMMON_DIR,
    min_trades: int = 50,
) -> dict[str, Any]:
    ea_id = normalize_ea_label(ea_id)
    symbol = symbol.upper()
    blockers: list[str] = []
    phases: dict[str, Any] = {}

    build_ok, build_detail, build_modified_ns = _build_evidence(repo_root, ea_id)
    if not build_ok:
        blockers.append(f"build_not_clean:{build_detail}")

    registry_path = repo_root / "framework" / "registry" / "magic_numbers.csv"
    registry_ok = _active_magic_registered(registry_path, ea_id, symbol)
    if not registry_ok:
        blockers.append("active_magic_missing")

    q08_verdict = None
    q08_evidence_path: Path | None = None
    for phase in STRICT_PHASES:
        row = _latest_phase_row(conn, ea_id, symbol, phase)
        if row is None:
            phases[phase] = {"verdict": None, "evidence_path": None, "evidence_exists": False}
            blockers.append(f"{phase.lower()}_pass_missing")
            continue
        verdict = str(row["verdict"] or "")
        evidence_path = Path(row["evidence_path"]) if row["evidence_path"] else None
        evidence_exists = bool(evidence_path and evidence_path.exists())
        evidence_modified_ns = evidence_path.stat().st_mtime_ns if evidence_exists and evidence_path else None
        evidence_predates_build = bool(
            build_modified_ns is not None
            and evidence_modified_ns is not None
            and evidence_modified_ns < build_modified_ns
        )
        phases[phase] = {
            "verdict": verdict,
            "work_item_id": row["id"],
            "evidence_path": str(evidence_path) if evidence_path else None,
            "evidence_exists": evidence_exists,
            "evidence_modified_at_utc": _mtime_utc(evidence_path) if evidence_path else None,
            "evidence_predates_build": evidence_predates_build,
            "updated_at": row["updated_at"],
        }
        if phase == "Q08":
            q08_verdict = verdict
            q08_evidence_path = evidence_path
        if verdict != "PASS":
            blockers.append(f"{phase.lower()}_not_pass:{verdict or 'missing'}")
        if not evidence_exists:
            blockers.append(f"{phase.lower()}_evidence_missing")
        elif evidence_predates_build:
            blockers.append(f"{phase.lower()}_evidence_predates_build")

    fallback_stream_path = _stream_path(common_dir, ea_id, symbol)
    linked_stream_path, linked_stream_error = _q08_baseline_stream(q08_evidence_path)
    stream_path = linked_stream_path or fallback_stream_path
    stream = _stream_evidence(stream_path)
    stream["source"] = "q08_durable_baseline" if linked_stream_path else "common_volatile_fallback"
    stream["baseline_linked"] = linked_stream_path is not None
    stream["link_error"] = linked_stream_error
    try:
        stream_modified_ns = stream_path.stat().st_mtime_ns if stream["exists"] else None
    except OSError:
        stream_modified_ns = None
    stream["predates_build"] = bool(
        build_modified_ns is not None
        and stream_modified_ns is not None
        and stream_modified_ns < build_modified_ns
    )
    if linked_stream_path is None:
        blockers.append(f"q08_baseline_stream_unlinked:{linked_stream_error}")
    if not stream["fresh_mae"]:
        blockers.append("fresh_intraday_mae_stream_missing")
    elif stream["predates_build"]:
        blockers.append("intraday_mae_stream_predates_build")
    if int(stream["trade_count"]) < min_trades:
        blockers.append(f"trade_count_below_{min_trades}:{stream['trade_count']}")

    ready = not blockers
    state = "CHALLENGE_READY" if ready else "NOT_QUALIFIED"
    if not ready and q08_verdict in RESEARCH_LEAD_Q08_VERDICTS:
        non_research_blockers = [
            blocker for blocker in blockers
            if not blocker.startswith("q08_not_pass:") and not blocker.startswith("q10_pass_missing")
        ]
        if not non_research_blockers:
            state = "RESEARCH_LEAD"

    return {
        "ea_id": ea_id,
        "symbol": symbol,
        "state": state,
        "challenge_ready": ready,
        "blockers": blockers,
        "build": {
            "ok": build_ok,
            "detail": build_detail,
            "modified_at_utc": _mtime_utc(Path(build_detail)) if build_ok and build_detail else None,
        },
        "active_magic_registered": registry_ok,
        "phases": phases,
        "stream": stream,
    }


def build_inventory(
    db_path: Path = DEFAULT_CANDIDATES_DB,
    *,
    keys: Iterable[tuple[str, str]] | None = None,
    repo_root: Path = DEFAULT_REPO_ROOT,
    common_dir: Path = DEFAULT_COMMON_DIR,
    min_trades: int = 50,
) -> dict[str, Any]:
    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        selected = list(keys) if keys is not None else discover_keys(conn)
        candidates = [
            evaluate_candidate(
                conn,
                ea_id,
                symbol,
                repo_root=repo_root,
                common_dir=common_dir,
                min_trades=min_trades,
            )
            for ea_id, symbol in selected
        ]
    counts: dict[str, int] = {}
    for row in candidates:
        counts[row["state"]] = counts.get(row["state"], 0) + 1
    return {
        "schema_version": 1,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "contract": {
            "strict_phases": list(STRICT_PHASES),
            "required_verdict": "PASS",
            "min_trades": min_trades,
            "requires_fresh_entry_time_and_mae_acct": True,
            "requires_q08_linked_durable_baseline_stream": True,
            "requires_evidence_not_older_than_binary": True,
            "read_only": True,
        },
        "counts": counts,
        "challenge_ready_count": sum(1 for row in candidates if row["challenge_ready"]),
        "candidates": candidates,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--repo-root", type=Path, default=DEFAULT_REPO_ROOT)
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--keys", help="Comma-separated EA_ID:SYMBOL pairs")
    parser.add_argument("--min-trades", type=int, default=50)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--require-ready", action="store_true")
    args = parser.parse_args(argv)
    if args.min_trades < 1:
        parser.error("--min-trades must be >= 1")
    artifact = build_inventory(
        args.db,
        keys=parse_keys(args.keys),
        repo_root=args.repo_root,
        common_dir=args.common_dir,
        min_trades=args.min_trades,
    )
    rendered = json.dumps(artifact, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(rendered + "\n", encoding="utf-8")
        print(f"wrote {args.out} ready={artifact['challenge_ready_count']}")
    else:
        print(rendered)
    return 2 if args.require_ready and artifact["challenge_ready_count"] == 0 else 0


if __name__ == "__main__":
    raise SystemExit(main())
