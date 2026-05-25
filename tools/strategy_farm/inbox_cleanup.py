"""Inbox stale-cleanup — move files older than N days from codex_inbox/
into codex_inbox/.archive/skipped_stale/.

Why: pump emits ~10 auto-build + ~10 auto-r-eval bridge tasks per cycle.
Codex picks 5 per orchestration cycle. The gap accumulates over days.
On 2026-05-24 we found 2 431 inbox files with median age 110h (4.6d) and
1 417 files >72h old. Stale files cost disk + slow inbox scans + can
confuse Codex if picked (the underlying card/EA may have moved on).

Default policy: anything not picked up within 7 days is presumed unwanted
(R-eval task whose card was deleted, auto-build for a card that got
rejected after emission, etc.). Move to .archive/skipped_stale/ for
audit; never deleted outright.

Usage:
    python inbox_cleanup.py             # default 7-day threshold, do it
    python inbox_cleanup.py --dry-run   # just report, no moves
    python inbox_cleanup.py --days 14   # custom threshold
"""

from __future__ import annotations

import argparse
import datetime as dt
import shutil
import sys
import time
from pathlib import Path

INBOX = Path("D:/QM/strategy_farm/codex_inbox")
ARCHIVE = INBOX / ".archive" / "skipped_stale"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--days", type=int, default=7,
                    help="files older than this (in days) are archived (default 7)")
    ap.add_argument("--dry-run", action="store_true",
                    help="list what would move; do not actually move")
    ap.add_argument("--inbox", type=Path, default=INBOX,
                    help="override inbox dir")
    args = ap.parse_args(argv)

    inbox = args.inbox
    if not inbox.is_dir():
        print(f"inbox not found: {inbox}", file=sys.stderr)
        return 2
    archive = inbox / ".archive" / "skipped_stale"
    archive.mkdir(parents=True, exist_ok=True)

    cutoff_ts = time.time() - args.days * 86400
    stale: list[Path] = []
    for f in inbox.glob("*.md"):
        try:
            if f.stat().st_mtime < cutoff_ts:
                stale.append(f)
        except OSError:
            continue

    moved = 0
    failed = 0
    ts = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    for f in stale:
        if args.dry_run:
            print(f"  DRY-RUN would move: {f.name}")
            continue
        # Tag the destination with the cleanup run timestamp so we can
        # tell when a given file was archived.
        dst = archive / f"{ts}_{f.name}"
        try:
            shutil.move(str(f), str(dst))
            moved += 1
        except OSError as exc:
            print(f"  failed to move {f.name}: {exc!r}", file=sys.stderr)
            failed += 1

    print(f"stale files (>{args.days}d old): {len(stale)}")
    if args.dry_run:
        print(f"dry-run mode: 0 actual moves")
    else:
        print(f"moved to archive:               {moved}")
        if failed:
            print(f"failed to move:                 {failed}")
        print(f"archive dir:                    {archive}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
