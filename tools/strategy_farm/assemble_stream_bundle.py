#!/usr/bin/env python3
"""Assemble a sealed daily-PnL stream bundle for the qualified book pool (D4).

Closes defect D4 of docs/ops/evidence/2026-09-03_book_path_rehearsal_5pair_pool.md:
the dual-venue book builders consume a sealed stream bundle laid out as
``<stream_root>/QM/q08_trades/<ea>_<symbol_with_dots_as_underscores>.jsonl``
(book_builder_common.load_daily -> portfolio_common.load_streams), yet the default
bundle ``D:/QM/reports/portfolio/dxz_final_20260719`` only covers a stale July
roster.  This tool binds each qualified (EA, symbol) pair to the sealed stream of
its CURRENT identity and copies it, byte-for-byte, into a caller-supplied ``--out``
bundle root.

Binding contract (fail-closed, never fabricates a stream):

1. Current identity = the ``ex5_sha256`` that carried the pair's terminal Q14
   head-to-head verdict (KEEP_INCUMBENT / PROMOTE_CHALLENGER / CHALLENGER_PROMOTED /
   ADMIT_BOTH -- the Q14 PASS-class of rebaseline_census.PASS_ECON).
2. The pair's most recent Q08 ``done`` work item of the census Q08 PASS-class
   (``PASS`` or ``FAIL_SOFT``; OWNER-DEC-BUNDLE-Q08-PASSCLASS-20260904) must carry a
   ``portfolio_stream`` block in its ``aggregate.json`` whose
   ``source_ex5_sha256`` equals that identity; that block pins the sealed
   ``content_sha256`` and the recorded stream path.
3. A physical stream file whose SHA-256 equals the pinned ``content_sha256`` must
   be located on disk.  It is copied verbatim.  Any pair for which any of these
   steps fails is REFUSED with a reason -- never synthesized.

Read-only against the farm DB (mode=ro URI); writes only under ``--out``.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import shutil
import sqlite3
import sys
from pathlib import Path
from typing import Any, Iterable, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.strategy_farm.portfolio.portfolio_common import _coerce_ea_int


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
BUNDLE_SUBDIR = ("QM", "q08_trades")
STREAM_SCHEMA = "qm.sealed_stream_bundle/v1"

# Q14 head-to-head outcomes whose surviving binary is the current identity.
# Mirrors the terminal requalification tokens in rebaseline_census.PASS_ECON.
TERMINAL_PASS_VERDICTS = frozenset({
    "KEEP_INCUMBENT",
    "PROMOTE_CHALLENGER",
    "CHALLENGER_PROMOTED",
    "ADMIT_BOTH",
})

# Q08 verdicts whose sealed stream is book evidence.  Mirrors the census rule
# rebaseline_census.GATE_SCOPED_PASS["Q08"] (OWNER-DEC-DL082-EXT Option D: a Q08
# Davey FAIL_SOFT is contiguous book evidence), aligned to the bundle by
# OWNER-DEC-BUNDLE-Q08-PASSCLASS-20260904 ("Bundle Regel an Census Regel
# angleichen, ja.", 2026-09-04).  Pair 8 (QM5_11910 NZDUSD) carried a sealed
# current-identity stream (work item 977a478e) that the PASS-only filter refused.
Q08_STREAM_PASS_VERDICTS = frozenset({"PASS", "FAIL_SOFT"})

# Identity-hash payload keys, in priority order (rebaseline_census.BUILD_HASH_KEYS).
BUILD_HASH_KEYS = (
    "expected_ex5_sha256",
    "ex5_sha256",
    "compiled_ex5_sha256",
    "staged_ex5_sha256",
    "expected_current_ex5_sha256",
    "build_hash",
)

# Roots searched (in addition to the paths recorded in the Q08 stream block) for a
# physical file matching the pinned content hash.  Sealed streams are written to
# sleeve_streams; frozen bundles and the volatile MT5 Common\Files dir are searched
# only as fallbacks and are accepted solely on an exact content-hash match.
DEFAULT_SEARCH_ROOTS = (
    Path(r"D:\QM\reports\portfolio\sleeve_streams"),
    Path(r"D:\QM\reports\portfolio\dxz_final_20260719"),
    Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files"),
)


class BundleError(ValueError):
    """Fail-closed configuration or provenance error."""


def open_ro(db_path: Path) -> sqlite3.Connection:
    """Open the farm DB strictly read-only via a mode=ro URI."""
    norm = str(db_path).replace("\\", "/")
    con = sqlite3.connect(f"file:{norm}?mode=ro", uri=True, timeout=5)
    con.execute("PRAGMA busy_timeout=3000")
    con.row_factory = sqlite3.Row
    return con


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def stream_filename(ea_int: int, symbol: str) -> str:
    """The bundle stream filename the builders' loader keys on."""
    return f"{ea_int}_{symbol.replace('.', '_')}.jsonl"


def parse_pair(token: str) -> tuple[str, str]:
    """Parse an ``ea:symbol`` CLI token into (ea_label 'QM5_<n>', symbol '<SYM>.DWX')."""
    raw = token.strip()
    if ":" not in raw:
        raise BundleError(f"pair token must be ea:symbol, got {token!r}")
    ea_raw, symbol_raw = raw.split(":", 1)
    ea_int = _coerce_ea_int(ea_raw)
    if ea_int is None:
        raise BundleError(f"pair token has an unparseable ea id: {token!r}")
    symbol = symbol_raw.strip().upper()
    if not symbol:
        raise BundleError(f"pair token has an empty symbol: {token!r}")
    if "." not in symbol:
        symbol += ".DWX"
    return f"QM5_{ea_int}", symbol


def _hash_from_row(row: Mapping[str, Any]) -> str:
    """Current-identity ex5 hash: typed column first, then payload_json keys."""
    typed = row["ex5_sha256"] if "ex5_sha256" in row.keys() else None
    if typed:
        value = str(typed).strip().lower()
        if value and value not in ("none", "null"):
            return value
    payload_raw = row["payload_json"] if "payload_json" in row.keys() else None
    if payload_raw:
        try:
            payload = json.loads(payload_raw)
        except (ValueError, TypeError):
            payload = None
        if isinstance(payload, Mapping):
            for key in BUILD_HASH_KEYS:
                value = payload.get(key)
                if value:
                    value = str(value).strip().lower()
                    if value and value not in ("none", "null"):
                        return value
    return ""


def resolve_identity(con: sqlite3.Connection, ea_label: str, symbol: str) -> dict[str, Any] | None:
    """The current identity from the pair's terminal Q14 PASS-class row."""
    rows = con.execute(
        "SELECT id, verdict, ex5_sha256, payload_json, evidence_path, updated_at "
        "FROM work_items WHERE ea_id=? AND symbol=? AND phase='Q14' AND status='done' "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC",
        (ea_label, symbol),
    ).fetchall()
    for row in rows:
        verdict = str(row["verdict"] or "").upper()
        if verdict in TERMINAL_PASS_VERDICTS:
            ex5 = _hash_from_row(row)
            if ex5:
                return {
                    "identity_ex5_sha256": ex5,
                    "q14_work_item_id": row["id"],
                    "q14_verdict": verdict,
                    "q14_evidence_path": row["evidence_path"],
                }
    return None


def _read_portfolio_stream(evidence_path: str | None) -> dict[str, Any] | None:
    if not evidence_path:
        return None
    path = Path(evidence_path)
    if not path.is_file():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    block = payload.get("portfolio_stream") if isinstance(payload, Mapping) else None
    return block if isinstance(block, Mapping) else None


def find_bound_q08(
    con: sqlite3.Connection, ea_label: str, symbol: str, identity_ex5: str
) -> dict[str, Any] | None:
    """Most recent Q08 PASS-class row whose sealed stream is bound to ``identity_ex5``."""
    verdicts = tuple(sorted(Q08_STREAM_PASS_VERDICTS))
    placeholders = ", ".join("?" for _ in verdicts)
    rows = con.execute(
        "SELECT id, verdict, evidence_path, updated_at FROM work_items "
        "WHERE ea_id=? AND symbol=? AND phase='Q08' AND status='done' "
        f"AND verdict IN ({placeholders}) "
        "ORDER BY julianday(updated_at) DESC, updated_at DESC, id DESC",
        (ea_label, symbol, *verdicts),
    ).fetchall()
    for row in rows:
        block = _read_portfolio_stream(row["evidence_path"])
        if not block:
            continue
        source_ex5 = str(block.get("source_ex5_sha256") or "").strip().lower()
        content_sha = str(block.get("content_sha256") or "").strip().lower()
        if source_ex5 == identity_ex5 and content_sha:
            return {
                "q08_work_item_id": row["id"],
                "seal_content_sha256": content_sha,
                "recorded_path": block.get("path"),
                "source_artifact_path": block.get("source_artifact_path"),
                "identity_status": block.get("identity_status"),
                "q08_evidence_path": row["evidence_path"],
            }
    return None


def _candidate_paths(
    filename: str,
    recorded_path: str | None,
    source_artifact_path: str | None,
    search_roots: Iterable[Path],
) -> list[Path]:
    candidates: list[Path] = []
    if recorded_path:
        candidates.append(Path(recorded_path))
    if source_artifact_path:
        candidates.append(Path(source_artifact_path))
    for root in search_roots:
        candidates.append(root / BUNDLE_SUBDIR[0] / BUNDLE_SUBDIR[1] / filename)
        candidates.append(root / "streams" / filename)
        candidates.append(root / filename)
    return candidates


def locate_sealed_bytes(
    seal_content_sha256: str,
    filename: str,
    recorded_path: str | None,
    source_artifact_path: str | None,
    search_roots: Iterable[Path],
) -> tuple[Path | None, list[str]]:
    """Return (path whose sha256 == seal, list of existing paths checked)."""
    checked: list[str] = []
    seen: set[str] = set()
    for candidate in _candidate_paths(filename, recorded_path, source_artifact_path, search_roots):
        try:
            resolved = str(candidate.resolve())
        except OSError:
            resolved = str(candidate)
        if resolved in seen:
            continue
        seen.add(resolved)
        if candidate.is_file():
            checked.append(str(candidate))
            if sha256_file(candidate) == seal_content_sha256:
                return candidate, checked
    return None, checked


def assemble_pair(
    con: sqlite3.Connection,
    ea_label: str,
    symbol: str,
    out_stream_dir: Path,
    search_roots: Iterable[Path],
) -> dict[str, Any]:
    """Bind and copy one pair's sealed stream, or return a structured refusal."""
    ea_int = _coerce_ea_int(ea_label)
    if ea_int is None:
        return {
            "ea_id": ea_label,
            "symbol": symbol,
            "outcome": "refused",
            "reason": "unparseable_ea_id",
            "detail": f"cannot coerce ea id from {ea_label!r}",
        }
    filename = stream_filename(ea_int, symbol)
    base: dict[str, Any] = {"ea_id": ea_label, "ea_int": ea_int, "symbol": symbol, "filename": filename}

    identity = resolve_identity(con, ea_label, symbol)
    if identity is None:
        return {
            **base,
            "outcome": "refused",
            "reason": "no_terminal_q14_identity",
            "detail": (
                "no Q14 done row with a terminal PASS-class verdict "
                f"({sorted(TERMINAL_PASS_VERDICTS)}) carrying an ex5 hash"
            ),
        }
    base.update(identity)

    bound = find_bound_q08(con, ea_label, symbol, identity["identity_ex5_sha256"])
    if bound is None:
        return {
            **base,
            "outcome": "refused",
            "reason": "no_q08_stream_bound_to_identity",
            "detail": (
                "no Q08 done/PASS-class (PASS, FAIL_SOFT) aggregate.json portfolio_stream whose source_ex5_sha256 "
                f"== current identity {identity['identity_ex5_sha256']}"
            ),
        }
    base.update({
        "q08_work_item_id": bound["q08_work_item_id"],
        "seal_content_sha256": bound["seal_content_sha256"],
        "recorded_path": bound["recorded_path"],
        "identity_status": bound["identity_status"],
    })

    located, checked = locate_sealed_bytes(
        bound["seal_content_sha256"],
        filename,
        bound["recorded_path"],
        bound["source_artifact_path"],
        search_roots,
    )
    if located is None:
        return {
            **base,
            "outcome": "refused",
            "reason": "sealed_stream_bytes_unavailable",
            "detail": (
                f"seal content_sha256={bound['seal_content_sha256']} recorded by Q08 "
                f"{bound['q08_work_item_id']} but no physical file with that content hash "
                "was found on disk"
            ),
            "searched_existing_files": checked,
        }

    out_stream_dir.mkdir(parents=True, exist_ok=True)
    destination = out_stream_dir / filename
    shutil.copyfile(located, destination)
    copied_sha = sha256_file(destination)
    if copied_sha != bound["seal_content_sha256"]:
        # Defensive: a copy that does not reproduce the seal is discarded, never kept.
        destination.unlink(missing_ok=True)
        return {
            **base,
            "outcome": "refused",
            "reason": "copy_hash_mismatch",
            "detail": (
                f"copied bytes hash {copied_sha} != seal {bound['seal_content_sha256']}"
            ),
        }

    return {
        **base,
        "outcome": "bound",
        "gate": "Q08",
        "source_path": str(located),
        "sha256": copied_sha,
        "bundle_path": str(destination),
    }


def _verify_loadable(out_root: Path, bound_keys: list[tuple[int, str]]) -> dict[str, Any]:
    """Confirm the builders' own loader accepts the assembled bundle."""
    if not bound_keys:
        return {"verified": None, "detail": "no bound streams to verify"}
    try:
        from tools.strategy_farm.portfolio.book_builder_common import load_daily
    except Exception as exc:  # pragma: no cover - import environment guard
        return {"verified": None, "detail": f"loader import failed: {exc}"}
    try:
        daily, provenance = load_daily(out_root, sorted(bound_keys))
    except Exception as exc:
        return {"verified": False, "detail": f"load_daily rejected the bundle: {exc}"}
    return {
        "verified": True,
        "stream_count": provenance.get("stream_count"),
        "days_per_sleeve": {f"{ea}:{sym}": len(daily[(ea, sym)]) for ea, sym in bound_keys},
    }


def resolve_qualified_pairs(db_path: Path) -> list[tuple[str, str]]:
    """Default pair set: the book guard's qualified (EA, symbol) census rows."""
    from tools.strategy_farm import book_build_guard, gate_manifest

    manifest = gate_manifest.load_gate_manifest()
    terminal_gate = manifest.terminal_requalification_gate
    rows = book_build_guard._qualified_pair_rows(db_path, terminal_gate)
    pairs: list[tuple[str, str]] = []
    for row in rows:
        ea_int = _coerce_ea_int(row["ea_id"])
        if ea_int is None:
            continue
        pairs.append((f"QM5_{ea_int}", str(row["symbol"])))
    return sorted(set(pairs))


def assemble_bundle(
    *,
    db_path: Path,
    out_root: Path,
    pairs: list[tuple[str, str]],
    search_roots: list[Path],
    verify_loadable: bool = True,
) -> dict[str, Any]:
    out_root = out_root.expanduser().resolve()
    out_stream_dir = out_root / BUNDLE_SUBDIR[0] / BUNDLE_SUBDIR[1]
    con = open_ro(db_path)
    try:
        results = [
            assemble_pair(con, ea_label, symbol, out_stream_dir, search_roots)
            for ea_label, symbol in pairs
        ]
    finally:
        con.close()

    bound_keys = [
        (item["ea_int"], item["symbol"]) for item in results if item["outcome"] == "bound"
    ]
    loader = _verify_loadable(out_root, bound_keys) if verify_loadable else {
        "verified": None, "detail": "verification skipped"
    }

    manifest = {
        "schema": STREAM_SCHEMA,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "generator": "tools/strategy_farm/assemble_stream_bundle.py",
        "db_path": str(db_path),
        "db_mode": "ro",
        "out_root": str(out_root),
        "bundle_stream_dir": str(out_stream_dir),
        "search_roots": [str(root) for root in search_roots],
        "pairs_requested": [f"{ea}:{sym}" for ea, sym in pairs],
        "bound_count": sum(1 for item in results if item["outcome"] == "bound"),
        "refused_count": sum(1 for item in results if item["outcome"] == "refused"),
        "loader_verification": loader,
        "results": results,
    }
    out_stream_dir.mkdir(parents=True, exist_ok=True)
    return manifest


def _default_manifest_path(out_root: Path) -> Path:
    return out_root.expanduser().resolve() / "bundle_manifest.json"


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0] if __doc__ else None)
    parser.add_argument("--out", required=True, type=Path, help="scratch bundle root (writes only here)")
    parser.add_argument("--db-path", type=Path, default=DEFAULT_DB_PATH, help="farm DB (opened mode=ro)")
    parser.add_argument(
        "--pairs",
        default=None,
        help="comma-separated ea:symbol tokens; default resolves the book guard's qualified pool",
    )
    parser.add_argument(
        "--search-root",
        action="append",
        type=Path,
        default=None,
        help="extra root to search for sealed stream bytes (repeatable)",
    )
    parser.add_argument("--manifest", type=Path, default=None, help="manifest output path (default <out>/bundle_manifest.json)")
    parser.add_argument("--no-verify-loadable", action="store_true", help="skip the builders' loader acceptance check")
    parser.add_argument("--json", action="store_true", help="print the manifest as JSON to stdout")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_arg_parser().parse_args(argv)

    if not Path(args.db_path).exists():
        print(f"ERROR: farm DB not found: {args.db_path}", file=sys.stderr)
        return 2

    try:
        if args.pairs:
            pairs = [parse_pair(token) for token in args.pairs.split(",") if token.strip()]
        else:
            pairs = resolve_qualified_pairs(Path(args.db_path))
    except BundleError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if not pairs:
        print("ERROR: no pairs to assemble (empty --pairs and empty qualified census)", file=sys.stderr)
        return 2

    search_roots = list(args.search_root) if args.search_root else list(DEFAULT_SEARCH_ROOTS)

    manifest = assemble_bundle(
        db_path=Path(args.db_path),
        out_root=Path(args.out),
        pairs=pairs,
        search_roots=search_roots,
        verify_loadable=not args.no_verify_loadable,
    )

    manifest_path = args.manifest if args.manifest is not None else _default_manifest_path(Path(args.out))
    manifest_path = Path(manifest_path)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if args.json:
        print(json.dumps(manifest, indent=2, sort_keys=True))
    else:
        print(f"bundle root : {manifest['out_root']}")
        print(f"manifest    : {manifest_path}")
        print(f"bound       : {manifest['bound_count']}   refused: {manifest['refused_count']}")
        print(f"loader      : {manifest['loader_verification'].get('verified')}")
        for item in manifest["results"]:
            if item["outcome"] == "bound":
                print(f"  BOUND    {item['ea_id']}:{item['symbol']}  <- {item['source_path']}")
            else:
                print(f"  REFUSED  {item['ea_id']}:{item['symbol']}  {item['reason']}: {item.get('detail', '')}")

    if manifest["refused_count"] > 0:
        return 3
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
