"""Operator-facing listing helper for framework/EAs/.

Per DL-063 (2026-05-23): EA folder layout stays flat. Status / range
partitioning is done via this query helper, not by filesystem moves.

Joins:
- `framework/registry/ea_id_registry.csv` (status, slug, owner, created_at)
- `framework/EAs/QM5_<id>_<slug>/` filesystem presence

Common uses:
    python ea_view.py --status active
    python ea_view.py --status closed --since 2026-04-01
    python ea_view.py --range 1000-1999
    python ea_view.py --missing      # registered but no on-disk dir
    python ea_view.py --orphan       # on-disk dir but no registry row
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
EA_ROOT = REPO_ROOT / "framework" / "EAs"

_DIR_RE = re.compile(r"^QM5_(\d+)_(.+)$")


def load_registry() -> list[dict]:
    if not REGISTRY.exists():
        return []
    with REGISTRY.open(encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def scan_filesystem() -> dict[int, dict]:
    """Map ea_id -> {slug, path} from on-disk QM5_<id>_<slug>/ directories."""
    out: dict[int, dict] = {}
    if not EA_ROOT.exists():
        return out
    for d in EA_ROOT.iterdir():
        if not d.is_dir():
            continue
        m = _DIR_RE.match(d.name)
        if not m:
            continue
        ea_id = int(m.group(1))
        out[ea_id] = {"slug": m.group(2), "path": str(d)}
    return out


def parse_date(s: str) -> dt.date | None:
    try:
        return dt.datetime.strptime(s, "%Y-%m-%d").date()
    except (TypeError, ValueError):
        return None


def main() -> int:
    ap = argparse.ArgumentParser(description="EA listing helper (per DL-063)")
    ap.add_argument("--status", choices=["active", "closed", "revision", "archived", "all"],
                    default="all", help="Filter by registry status")
    ap.add_argument("--range", dest="id_range", help="ID range, e.g. 1000-1999")
    ap.add_argument("--since", help="Created on or after YYYY-MM-DD")
    ap.add_argument("--until", help="Created on or before YYYY-MM-DD")
    ap.add_argument("--missing", action="store_true",
                    help="Show EAs in registry but without on-disk dir")
    ap.add_argument("--orphan", action="store_true",
                    help="Show on-disk dirs without a registry row")
    ap.add_argument("--count-only", action="store_true",
                    help="Print only the count, not the table")
    args = ap.parse_args()

    rows = load_registry()
    fs = scan_filesystem()

    if args.orphan:
        reg_ids = {int(r["ea_id"]) for r in rows if r.get("ea_id", "").isdigit()}
        orphans = sorted(set(fs.keys()) - reg_ids)
        if args.count_only:
            print(len(orphans))
            return 0
        for ea_id in orphans:
            print(f"{ea_id:>5}  {fs[ea_id]['slug']:30}  {fs[ea_id]['path']}")
        return 0

    # Range filter
    lo, hi = 0, 10**9
    if args.id_range:
        try:
            lo_s, hi_s = args.id_range.split("-", 1)
            lo, hi = int(lo_s), int(hi_s)
        except ValueError:
            print(f"bad --range: {args.id_range}", file=sys.stderr)
            return 2

    since = parse_date(args.since) if args.since else None
    until = parse_date(args.until) if args.until else None

    out = []
    for r in rows:
        if not (r.get("ea_id") or "").isdigit():
            continue
        ea_id = int(r["ea_id"])
        if not (lo <= ea_id <= hi):
            continue
        if args.status != "all" and r.get("status") != args.status:
            continue
        created = parse_date(r.get("created_at", ""))
        if since and created and created < since:
            continue
        if until and created and created > until:
            continue
        on_disk = ea_id in fs
        if args.missing and on_disk:
            continue
        if not args.missing and not on_disk and args.status == "active":
            # active-but-missing is an inconsistency; still show but flag
            pass
        out.append({
            "ea_id": ea_id,
            "slug": r.get("slug", ""),
            "status": r.get("status", "?"),
            "owner": r.get("owner", "?"),
            "created_at": r.get("created_at", ""),
            "on_disk": "Y" if on_disk else "-",
        })

    out.sort(key=lambda x: x["ea_id"])

    if args.count_only:
        print(len(out))
        return 0

    print(f"{'EA_ID':>5}  {'STATUS':10}  {'DISK':4}  {'SLUG':30}  {'CREATED':10}  OWNER")
    print("-" * 75)
    for r in out:
        print(f"{r['ea_id']:>5}  {r['status']:10}  {r['on_disk']:4}  "
              f"{r['slug'][:30]:30}  {r['created_at']:10}  {r['owner']}")
    print("-" * 75)
    print(f"{len(out)} EAs (filter: status={args.status}, range={args.id_range or 'all'})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
