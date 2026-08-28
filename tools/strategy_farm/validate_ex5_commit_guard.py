"""Fail-closed guard: refuse a commit that stages a framework/EAs/**/*.ex5
change (added or modified) unless a governed COMPILE_EA receipt exists for
the exact staged bytes.

A receipt is a `work_items` row with kind='compile', phase='COMPILE_EA',
status='done', verdict='COMPILE_OK', whose ex5_sha256 matches the staged
.ex5 blob and whose mq5_sha256 (when the row has one) matches the staged
.mq5 sibling. On Windows, a receipt may instead bind the raw CRLF working
copy MetaEditor compiled, but only when replacing CRLF byte pairs with LF
reproduces the staged Git blob exactly. BOMs, standalone CRs, whitespace,
and every other byte remain significant. This closes the class of violation
documented 2026-08-24:
fresh .ex5 bytes compiled ad hoc (idle MetaEditor, disposable profile, a
non-canonical worker path) after the governed wrapper failed closed with
LIVE_FACTORY_AD_HOC_COMPILE_REFUSED, then committed anyway (39001 x2,
38001, 38008, 9914, 9947, 35008).

A stale-news INIT failure or any other build-time gate is out of scope —
this guard only checks binary/source provenance, never gate criteria.
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sqlite3
import subprocess
from pathlib import Path
from typing import Any

_EA_DIR_RE = re.compile(r"^framework/EAs/(QM5_([0-9]+)_[A-Za-z0-9_-]+)/")


def default_db_path() -> Path:
    return Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")


def staged_ex5_changes(repo_root: Path) -> list[tuple[str, str]]:
    """Return (git_status, path) for staged added/modified .ex5 files under framework/EAs/."""
    out = subprocess.run(
        ["git", "diff", "--cached", "--name-status", "--diff-filter=ACMR"],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    changes: list[tuple[str, str]] = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        status, path = parts[0], parts[-1]
        path = path.replace("\\", "/")
        if path.startswith("framework/EAs/") and path.endswith(".ex5"):
            changes.append((status, path))
    return changes


def _staged_blob_bytes(repo_root: Path, path: str) -> bytes | None:
    result = subprocess.run(
        ["git", "show", f":{path}"],
        cwd=repo_root,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    return result.stdout


def _worktree_blob_bytes(repo_root: Path, path: str) -> bytes | None:
    candidate = repo_root / Path(path)
    try:
        if candidate.is_symlink() or not candidate.is_file():
            return None
        return candidate.read_bytes()
    except OSError:
        return None


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def find_receipt(
    db_path: Path,
    ea_id: str,
    ex5_sha256: str,
    mq5_sha256: str | None,
) -> dict[str, Any] | None:
    if not db_path.is_file():
        return None
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    try:
        row = conn.execute(
            "SELECT id, ea_id, ex5_sha256, mq5_sha256, status, verdict, updated_at "
            "FROM work_items "
            "WHERE kind='compile' AND phase='COMPILE_EA' AND ea_id=? "
            "AND status='done' AND verdict='COMPILE_OK' AND ex5_sha256=? "
            "ORDER BY updated_at DESC, id DESC LIMIT 1",
            (ea_id, ex5_sha256),
        ).fetchone()
    finally:
        conn.close()
    if row is None:
        return None
    if mq5_sha256 and row["mq5_sha256"] and row["mq5_sha256"] != mq5_sha256:
        return None
    return dict(row)


def _find_source_bound_receipt(
    repo_root: Path,
    db_path: Path,
    ea_id: str,
    ex5_sha256: str,
    mq5_path: str,
    staged_mq5_bytes: bytes | None,
) -> tuple[dict[str, Any] | None, str | None, str | None]:
    """Find an exact or provably line-ending-equivalent compile receipt.

    Git stores text as LF in the index while MetaEditor compiles the raw
    Windows working copy. The fallback is deliberately narrow: only CRLF byte
    pairs are mapped to LF, the transformed bytes must equal the staged blob,
    and the receipt must bind the exact untransformed working-copy hash.
    """
    staged_mq5_sha256 = (
        _sha256_bytes(staged_mq5_bytes) if staged_mq5_bytes is not None else None
    )
    receipt = find_receipt(db_path, ea_id, ex5_sha256, staged_mq5_sha256)
    if receipt is not None:
        binding = (
            "RECEIPT_MQ5_UNBOUND"
            if not receipt.get("mq5_sha256")
            else "STAGED_MQ5_EXACT"
        )
        return receipt, binding, None

    if staged_mq5_bytes is None:
        return None, None, None
    worktree_mq5_bytes = _worktree_blob_bytes(repo_root, mq5_path)
    if (
        worktree_mq5_bytes is None
        or b"\r\n" not in worktree_mq5_bytes
        or worktree_mq5_bytes.replace(b"\r\n", b"\n") != staged_mq5_bytes
    ):
        return None, None, None

    worktree_mq5_sha256 = _sha256_bytes(worktree_mq5_bytes)
    receipt = find_receipt(db_path, ea_id, ex5_sha256, worktree_mq5_sha256)
    if receipt is None:
        return None, None, worktree_mq5_sha256
    return receipt, "WORKTREE_CRLF_TO_STAGED_LF", worktree_mq5_sha256


def evaluate(repo_root: Path, db_path: Path) -> dict[str, Any]:
    """Evaluate every staged .ex5 change in repo_root against db_path receipts."""
    results: list[dict[str, Any]] = []
    ok = True
    for status, path in staged_ex5_changes(repo_root):
        match = _EA_DIR_RE.match(path)
        if not match:
            results.append(
                {"path": path, "git_status": status, "ok": False, "reason": "EA_LABEL_UNPARSEABLE"}
            )
            ok = False
            continue
        ea_label, numeric_id = match.group(1), match.group(2)
        ea_id = f"QM5_{numeric_id}"
        ex5_bytes = _staged_blob_bytes(repo_root, path)
        if ex5_bytes is None:
            results.append(
                {"path": path, "git_status": status, "ok": False, "reason": "STAGED_BLOB_UNREADABLE"}
            )
            ok = False
            continue
        ex5_sha256 = _sha256_bytes(ex5_bytes)
        mq5_path = f"framework/EAs/{ea_label}/{ea_label}.mq5"
        mq5_bytes = _staged_blob_bytes(repo_root, mq5_path)
        mq5_sha256 = _sha256_bytes(mq5_bytes) if mq5_bytes is not None else None
        receipt, mq5_binding, mq5_worktree_sha256 = _find_source_bound_receipt(
            repo_root,
            db_path,
            ea_id,
            ex5_sha256,
            mq5_path,
            mq5_bytes,
        )
        entry: dict[str, Any] = {
            "path": path,
            "git_status": status,
            "ea_id": ea_id,
            "ex5_sha256": ex5_sha256,
            "mq5_sha256": mq5_sha256,
        }
        if receipt is None:
            entry["ok"] = False
            entry["reason"] = "NO_GOVERNED_COMPILE_EA_RECEIPT"
            ok = False
        else:
            entry["ok"] = True
            entry["receipt_work_item_id"] = receipt["id"]
            entry["mq5_binding"] = mq5_binding
            if mq5_worktree_sha256 is not None:
                entry["mq5_worktree_sha256"] = mq5_worktree_sha256
        results.append(entry)
    return {"ok": ok, "changes": results}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--db-path", type=Path, default=default_db_path())
    args = parser.parse_args(argv)
    report = evaluate(args.repo_root.resolve(), args.db_path)
    if not report["changes"]:
        print("PASS: no staged .ex5 change under framework/EAs/")
    for entry in report["changes"]:
        if entry["ok"]:
            print(
                f"PASS {entry['path']} ea_id={entry['ea_id']} "
                f"receipt_work_item_id={entry['receipt_work_item_id']}"
            )
        else:
            print(f"REJECT {entry['path']} reason={entry['reason']}")
    if not report["ok"]:
        print(
            "EX5_COMMIT_GUARD_REFUSED: staged .ex5 change(s) lack a governed COMPILE_EA "
            "receipt (status=done, verdict=COMPILE_OK, matching ex5_sha256 + mq5_sha256). "
            "Fix: refresh via `python tools/strategy_farm/farmctl.py enqueue-compile "
            "<EA_LABEL>` and let the governed worker compile it. Never compile ad hoc "
            "after a LIVE_FACTORY_AD_HOC_COMPILE_REFUSED refusal — wait for an idle "
            "window or the governed COMPILE_EA queue."
        )
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
