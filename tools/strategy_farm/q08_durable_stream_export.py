#!/usr/bin/env python3
"""Durable-stream export + self-verification for the Q08 portfolio_stream seal.

Context
-------
A Q08 ``done``/``PASS`` work item seals a ``portfolio_stream`` block into its
``aggregate.json``.  That block records

    path               = D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/<ea>_<sym>.jsonl
    content_sha256     = sha256 of the graded stream bytes
    source_artifact_path = the volatile MT5 Common\\Files copy the run wrote

``framework/scripts/q08_davey/aggregate._persist_durable_sleeve_stream`` writes the
recorded durable ``path`` at seal time and ``_bind_portfolio_stream_identity`` hashes
those bytes into ``content_sha256``.  What was missing is a step that, at the seal
point, (a) confirms a durable file with exactly those bytes is present, (b) records
that fact on the block (``durable_path`` / ``durable_sha256`` / ``exported_at``), and
(c) never destroys a differently-hashed durable file already on disk -- so a later
re-grade of the same (ea, symbol) that overwrites the mutable ``<ea>_<sym>.jsonl``
pointer, or a crisis cleanup that removes it, cannot silently strand an earlier seal.
Any such loss can then be repaired from the still-present ``source_artifact_path`` via
:func:`backfill_work_item`.

Guarantees
----------
* **Additive and fail-open.**  :func:`export_sealed_stream` mutates the block in place
  with additive fields only, never raises, and never touches the Q08 verdict.  An
  export fault is captured as ``durable_export_status`` + ``durable_export_warning``
  and the seal proceeds unchanged.
* **Append-only identities.**  A durable file is written to the recorded ``path`` only
  when that path is absent or already holds the exact sealed bytes.  When the recorded
  ``path`` holds *different* bytes it is never overwritten; the sealed bytes go to a
  content-addressed sibling ``<name>.<sha16>.jsonl`` instead, and that sibling is the
  recorded ``durable_path``.
* **Verified.**  The bytes copied are always re-hashed and required to equal
  ``content_sha256`` before the durable location is recorded; a copy that does not
  reproduce the seal is discarded.

The backfill CLI is strictly read-only against the farm DB (``mode=ro`` URI) and
writes only the durable stream file -- never the aggregate.json, never the DB.
Stdlib-only by design, so importing it at the Q08 seal point carries no third-party
or intra-repo import risk.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
import shutil
import sqlite3
import sys
from pathlib import Path
from typing import Any, Callable, Mapping

DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")

# Additive keys this module writes onto the portfolio_stream block.  Listed so callers
# and tests can assert nothing else on the seal is touched.
ADDITIVE_FIELDS = (
    "durable_path",
    "durable_sha256",
    "exported_at",
    "durable_export_status",
    "durable_export_warning",
)

LogSink = Callable[[dict], None]


def _default_logger(record: dict) -> None:
    """Emit one structured warning line to stderr; never raises."""
    try:
        sys.stderr.write("Q08_DURABLE_EXPORT " + json.dumps(record, sort_keys=True) + "\n")
    except Exception:  # pragma: no cover - logging must never break the seal
        pass


def _emit(logger: LogSink | None, **fields: Any) -> None:
    sink = logger if logger is not None else _default_logger
    try:
        sink(dict(fields))
    except Exception:  # pragma: no cover - a bad sink must never break the seal
        pass


def _iso(now: dt.datetime | None) -> str:
    moment = now if now is not None else dt.datetime.now(dt.timezone.utc)
    return moment.isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _sha_if_file(path: Path) -> str | None:
    try:
        if path.is_file():
            return sha256_file(path)
    except OSError:
        return None
    return None


def _atomic_copyfile(src: Path, dst: Path) -> None:
    """Copy ``src`` to a temp sibling of ``dst`` then os.replace into place (atomic)."""
    tmp = dst.with_name(f"{dst.name}.export.{os.getpid()}.tmp")
    try:
        shutil.copyfile(src, tmp)
        os.replace(tmp, dst)
    finally:
        try:
            if tmp.exists():
                tmp.unlink()
        except OSError:
            pass


def _sibling_path(target: Path, content_sha: str) -> Path:
    """Content-addressed sibling of ``target`` -- immutable, sha-suffixed identity."""
    suffix = "".join(target.suffixes) or ".jsonl"
    stem = target.name[: len(target.name) - len(suffix)] if suffix else target.name
    return target.with_name(f"{stem}.{content_sha[:16]}{suffix}")


def _ensure_durable(
    target: Path, sealed_src: Path, content_sha: str
) -> tuple[Path, str, bool] | None:
    """Guarantee a durable file whose sha256 == ``content_sha`` exists, append-only.

    Returns ``(durable_path, durable_sha256, is_sibling)`` on success, else ``None``.
    Never overwrites a durable file whose bytes differ from ``content_sha``.
    """
    target.parent.mkdir(parents=True, exist_ok=True)

    # Case A -- the recorded path already holds exactly the sealed bytes (the common
    # seal-time path: _persist_durable_sleeve_stream just wrote it).  Idempotent no-op.
    if _sha_if_file(target) == content_sha:
        return (target, content_sha, False)

    # Case B -- the recorded path is absent: write the sealed bytes there and verify.
    if not target.exists():
        _atomic_copyfile(sealed_src, target)
        got = _sha_if_file(target)
        if got == content_sha:
            return (target, content_sha, False)
        # A copy that does not reproduce the seal is discarded (we created it here).
        try:
            target.unlink()
        except OSError:
            pass
        return None

    # Case C -- the recorded path exists with DIFFERENT bytes: never overwrite it.
    # Route the sealed bytes to an immutable content-addressed sibling.
    sibling = _sibling_path(target, content_sha)
    existing = _sha_if_file(sibling)
    if existing == content_sha:
        return (sibling, content_sha, True)
    if sibling.exists():
        # Name encodes the sha, so a differing sibling should be impossible; refuse
        # rather than clobber it.
        return None
    _atomic_copyfile(sealed_src, sibling)
    got = _sha_if_file(sibling)
    if got == content_sha:
        return (sibling, content_sha, True)
    try:
        sibling.unlink()
    except OSError:
        pass
    return None


def _locate_sealed_bytes(
    content_sha: str, target: Path, source_artifact: str | None
) -> Path | None:
    """A readable file whose sha256 == ``content_sha`` (recorded path, then source)."""
    if _sha_if_file(target) == content_sha:
        return target
    if source_artifact:
        src = Path(str(source_artifact))
        if _sha_if_file(src) == content_sha:
            return src
    return None


def _record(
    block: dict,
    *,
    status: str,
    warning: str | None = None,
    logger: LogSink | None = None,
    **log_fields: Any,
) -> None:
    block["durable_export_status"] = status
    if warning:
        block["durable_export_warning"] = warning
        _emit(logger, event="q08_durable_export", status=status, warning=warning, **log_fields)


def export_sealed_stream(
    portfolio_stream: Any,
    *,
    now: dt.datetime | None = None,
    logger: LogSink | None = None,
) -> Any:
    """Confirm + record the durable presence of a sealed Q08 stream (additive, fail-open).

    ``portfolio_stream`` is the aggregate's block AFTER identity binding (it carries
    ``persisted`` / ``path`` / ``content_sha256`` / ``source_artifact_path``).  The
    block is mutated in place with additive fields and returned.  Never raises; never
    changes the verdict.
    """
    try:
        return _export_sealed_stream_impl(portfolio_stream, now=now, logger=logger)
    except Exception as exc:  # noqa: BLE001 - export must never break the seal
        if isinstance(portfolio_stream, dict):
            _record(
                portfolio_stream,
                status="EXPORT_ERROR",
                warning=f"{type(exc).__name__}:{exc}",
                logger=logger,
            )
        return portfolio_stream


def _export_sealed_stream_impl(
    portfolio_stream: Any,
    *,
    now: dt.datetime | None,
    logger: LogSink | None,
) -> Any:
    if not isinstance(portfolio_stream, dict):
        return portfolio_stream

    if not portfolio_stream.get("persisted"):
        _record(portfolio_stream, status="SKIPPED_NOT_PERSISTED")
        return portfolio_stream

    content_sha = str(portfolio_stream.get("content_sha256") or "").strip().lower()
    recorded_path = portfolio_stream.get("path")
    if not content_sha:
        _record(portfolio_stream, status="SKIPPED_NO_CONTENT_SHA")
        return portfolio_stream
    if not recorded_path:
        _record(portfolio_stream, status="SKIPPED_NO_PATH")
        return portfolio_stream

    target = Path(str(recorded_path))
    source_artifact = portfolio_stream.get("source_artifact_path")

    sealed_src = _locate_sealed_bytes(content_sha, target, source_artifact)
    if sealed_src is None:
        _record(
            portfolio_stream,
            status="WARN_SEALED_BYTES_UNAVAILABLE",
            warning=(
                "no readable file (recorded path or source_artifact_path) hashes to "
                f"content_sha256={content_sha}"
            ),
            logger=logger,
            recorded_path=str(target),
            source_artifact_path=str(source_artifact) if source_artifact else None,
        )
        return portfolio_stream

    durable = _ensure_durable(target, sealed_src, content_sha)
    if durable is None:
        _record(
            portfolio_stream,
            status="WARN_DURABLE_VERIFY_FAILED",
            warning=(
                "durable copy did not reproduce content_sha256 or a differing sibling "
                "blocked the write"
            ),
            logger=logger,
            recorded_path=str(target),
            content_sha256=content_sha,
        )
        return portfolio_stream

    durable_path, durable_sha, is_sibling = durable
    portfolio_stream["durable_path"] = str(durable_path)
    portfolio_stream["durable_sha256"] = durable_sha
    portfolio_stream["exported_at"] = _iso(now)
    portfolio_stream["durable_export_status"] = (
        "EXPORTED_SIBLING" if is_sibling else "EXPORTED"
    )
    portfolio_stream.pop("durable_export_warning", None)
    return portfolio_stream


# --------------------------------------------------------------------------- #
# Backfill: recover a lost durable stream from its still-present source artifact.
# --------------------------------------------------------------------------- #

def open_ro(db_path: Path) -> sqlite3.Connection:
    """Open the farm DB strictly read-only via a mode=ro URI."""
    norm = str(db_path).replace("\\", "/")
    con = sqlite3.connect(f"file:{norm}?mode=ro", uri=True, timeout=5)
    con.execute("PRAGMA busy_timeout=3000")
    con.row_factory = sqlite3.Row
    return con


def _read_portfolio_stream(evidence_path: str | None) -> dict[str, Any] | None:
    """Read the ``portfolio_stream`` block from an aggregate.json (or .json.gz)."""
    if not evidence_path:
        return None
    path = Path(str(evidence_path))
    candidates = [path]
    if not path.is_file():
        candidates.append(path.with_name(path.name + ".gz"))
    for candidate in candidates:
        if not candidate.is_file():
            continue
        try:
            if candidate.suffix == ".gz":
                raw = gzip.decompress(candidate.read_bytes()).decode("utf-8-sig")
            else:
                raw = candidate.read_text(encoding="utf-8-sig")
            payload = json.loads(raw)
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue
        block = payload.get("portfolio_stream") if isinstance(payload, Mapping) else None
        if isinstance(block, Mapping):
            return dict(block)
    return None


def backfill_work_item(
    work_item_id: str,
    *,
    db_path: Path = DEFAULT_DB_PATH,
    now: dt.datetime | None = None,
    logger: LogSink | None = None,
) -> dict[str, Any]:
    """Re-export a Q08 seal's durable stream from its ``source_artifact_path``.

    Read-only against the farm DB; writes only the durable stream file.  The source
    artifact is used ONLY when it still exists and its sha256 equals the seal's
    ``content_sha256`` -- otherwise the pair is refused, never synthesized.
    """
    result: dict[str, Any] = {"work_item_id": work_item_id}
    con = open_ro(Path(db_path))
    try:
        row = con.execute(
            "SELECT id, phase, ea_id, symbol, status, verdict, evidence_path "
            "FROM work_items WHERE id=? AND phase='Q08'",
            (work_item_id,),
        ).fetchone()
    finally:
        con.close()

    if row is None:
        result.update(outcome="refused", reason="no_q08_work_item")
        return result

    result.update(ea_id=row["ea_id"], symbol=row["symbol"], evidence_path=row["evidence_path"])
    block = _read_portfolio_stream(row["evidence_path"])
    if block is None:
        result.update(outcome="refused", reason="no_portfolio_stream_block")
        return result

    content_sha = str(block.get("content_sha256") or "").strip().lower()
    recorded_path = block.get("path")
    source_artifact = block.get("source_artifact_path")
    result.update(content_sha256=content_sha or None, recorded_path=recorded_path)

    if not content_sha or not recorded_path:
        result.update(outcome="refused", reason="seal_missing_content_sha_or_path")
        return result
    if not source_artifact:
        result.update(outcome="refused", reason="no_source_artifact_path")
        return result

    src = Path(str(source_artifact))
    result["source_artifact_path"] = str(src)
    src_sha = _sha_if_file(src)
    if src_sha is None:
        result.update(outcome="refused", reason="source_artifact_missing")
        return result
    if src_sha != content_sha:
        result.update(outcome="refused", reason="source_artifact_sha_mismatch", source_sha256=src_sha)
        return result

    durable = _ensure_durable(Path(str(recorded_path)), src, content_sha)
    if durable is None:
        result.update(outcome="refused", reason="durable_verify_failed")
        _emit(logger, event="q08_durable_backfill", status="durable_verify_failed", **result)
        return result

    durable_path, durable_sha, is_sibling = durable
    result.update(
        outcome="exported",
        durable_path=str(durable_path),
        durable_sha256=durable_sha,
        sibling=is_sibling,
        exported_at=_iso(now),
    )
    return result


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    sub = parser.add_subparsers(dest="command", required=True)

    bf = sub.add_parser(
        "backfill",
        help="re-export one Q08 work item's durable stream from its source artifact",
    )
    bf.add_argument("--work-item-id", required=True, help="Q08 work_items.id to repair")
    bf.add_argument("--db-path", type=Path, default=DEFAULT_DB_PATH, help="farm DB (opened mode=ro)")
    bf.add_argument("--json", action="store_true", help="print the result as JSON to stdout")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

    if args.command == "backfill":
        if not Path(args.db_path).exists():
            print(f"ERROR: farm DB not found: {args.db_path}", file=sys.stderr)
            return 2
        result = backfill_work_item(args.work_item_id, db_path=Path(args.db_path))
        if args.json:
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            outcome = result.get("outcome")
            if outcome == "exported":
                print(
                    f"EXPORTED  {result.get('ea_id')}:{result.get('symbol')}  "
                    f"-> {result['durable_path']}  (sibling={result['sibling']})"
                )
            else:
                print(
                    f"REFUSED   {result.get('ea_id')}:{result.get('symbol')}  "
                    f"{result.get('reason')}"
                )
        return 0 if result.get("outcome") == "exported" else 3

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
