#!/usr/bin/env python3
"""Build the Q09_NEWS include closure for one EA.

Why this exists
---------------
``q09_news_runner.py plan`` requires ``--include-closure``: a file whose SHA-256 becomes
part of the run identity, so that a Q09 verdict is bound to the exact source tree the
binary was compiled from.  Nothing in the repository produced that file.  Two closures
existed, both hand-built (QM5_11422 on 2026-08-04, QM5_13036), which is why Q09 could
only ever be operated by hand for those two candidates.

This closes that gap.  The output is byte-compatible with the hand-built schema
``qm-q09-include-closure/v1`` so existing artifacts stay comparable.

Resolution rules (identical to the documented hand method)
----------------------------------------------------------
* ``#include <x.mqh>``   -> ``framework/include/x.mqh``, else the MT5 stdlib under
  ``MQL5/Include/`` of the reference terminal
* ``#include "x.mqh"``   -> relative to the including file first, then the include root
* recursion over everything found, each file visited once
* **fail-closed**: an include that resolves nowhere aborts the build.  A closure with a
  silently missing file would bind a Q09 verdict to an incomplete source set, which is
  worse than having no closure at all.

Read-only over the source tree; writes exactly one JSON file.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(r"C:\QM\repo")
INCLUDE_ROOT = REPO / "framework" / "include"
STDLIB_TERMINAL = Path(r"D:\QM\mt5\T1")
STDLIB_ROOT = STDLIB_TERMINAL / "MQL5" / "Include"
OUT_DIR = Path(r"D:\QM\reports\pipeline\_q09_include_closures")
SCHEMA = "qm-q09-include-closure/v1"

INCLUDE_RE = re.compile(r'^\s*#include\s+([<"])([^">]+)[">]', re.MULTILINE)
# Line comments and block comments are stripped before scanning so that a commented-out
# include does not enter the closure and change the identity hash.
BLOCK_COMMENT_RE = re.compile(r"/\*.*?\*/", re.DOTALL)
LINE_COMMENT_RE = re.compile(r"//[^\n]*")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def strip_comments(text: str) -> str:
    return LINE_COMMENT_RE.sub("", BLOCK_COMMENT_RE.sub("", text))


def resolve(kind: str, name: str, including: Path) -> tuple[Path, str] | None:
    """Return (path, origin) or None. origin is 'repo' or 'mt5_stdlib_T1'."""
    name = name.replace("\\", "/")
    if kind == '"':
        candidates = [including.parent / name, INCLUDE_ROOT / name]
    else:
        candidates = [INCLUDE_ROOT / name, STDLIB_ROOT / name]
    for cand in candidates:
        if cand.is_file():
            origin = "repo" if REPO in cand.parents or cand.is_relative_to(REPO) else "mt5_stdlib_T1"
            return cand, origin
    return None


def relative_label(path: Path, origin: str) -> str:
    if origin == "repo":
        return path.relative_to(REPO).as_posix()
    return path.relative_to(STDLIB_TERMINAL).as_posix()


def walk(root_mq5: Path) -> list[tuple[Path, str]]:
    seen: dict[Path, str] = {}
    stack = [(root_mq5, "repo")]
    unresolved: list[str] = []
    while stack:
        path, origin = stack.pop()
        resolved = path.resolve()
        if resolved in seen:
            continue
        seen[resolved] = origin
        try:
            text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))
        except OSError as exc:
            raise SystemExit(f"cannot read {path}: {exc}")
        for kind, name in INCLUDE_RE.findall(text):
            hit = resolve(kind, name, path)
            if hit is None:
                unresolved.append(f"{name!r} included from {path}")
                continue
            stack.append(hit)
    if unresolved:
        print("FAIL-CLOSED: unresolved includes:", file=sys.stderr)
        for u in unresolved:
            print("  " + u, file=sys.stderr)
        raise SystemExit(2)
    return [(p, o) for p, o in seen.items()]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea-id", required=True, help="e.g. QM5_11294")
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR)
    ap.add_argument("--force", action="store_true",
                    help="overwrite an existing closure (default: refuse)")
    args = ap.parse_args()

    matches = sorted((REPO / "framework" / "EAs").glob(f"{args.ea_id}_*"))
    if len(matches) != 1:
        raise SystemExit(f"expected exactly one EA directory for {args.ea_id}, found {len(matches)}")
    ea_dir = matches[0]
    root_mq5 = ea_dir / f"{ea_dir.name}.mq5"
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    for p in (root_mq5, ex5):
        if not p.is_file():
            raise SystemExit(f"missing {p}")

    out_path = args.out_dir / f"{args.ea_id}_include_closure.json"
    if out_path.exists() and not args.force:
        raise SystemExit(f"refusing to overwrite existing closure: {out_path}")

    files = []
    for path, origin in walk(root_mq5):
        files.append({
            "origin": origin,
            "relative_path": relative_label(path, origin),
            "sha256": sha256_file(path),
            "size_bytes": path.stat().st_size,
        })
    files.sort(key=lambda f: (f["origin"] != "repo", f["relative_path"]))

    payload = {
        "schema": SCHEMA,
        "ea_id": args.ea_id,
        "root_source": root_mq5.relative_to(REPO).as_posix(),
        "ex5_path": ex5.relative_to(REPO).as_posix(),
        "ex5_sha256": sha256_file(ex5),
        "file_count": len(files),
        "files": files,
        "generated_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "method": ("recursive #include parse; <...> vs framework/include then MT5 stdlib, "
                   "\"...\" vs including file then include root; comments stripped; "
                   "fail-closed on unresolved includes"),
        "reviewed_by": f"generated by {Path(__file__).name}",
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"{args.ea_id}: {len(files)} files "
          f"({sum(1 for f in files if f['origin'] == 'repo')} repo, "
          f"{sum(1 for f in files if f['origin'] != 'repo')} stdlib)")
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
