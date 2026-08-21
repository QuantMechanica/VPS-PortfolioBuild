#!/usr/bin/env python3
"""Read-only filesystem inventory for the QuantMechanica VPS.

Walks a configured set of roots and emits a per-directory-node inventory
(JSON + markdown summary) up to a bounded report depth. For every emitted
node it records: aggregate size, file count, newest/oldest mtime, a CLASS,
an OWNER, a suggested RETENTION, and (for backup nodes) a restore-status
derived from the presence of manifest/hash sidecars.

DESIGN CONTRACT (QM-TODO-20260820-004 / router 7dc80bad):
  * DRY-RUN ONLY. This tool NEVER deletes, moves, writes into, or opens the
    content of any inventoried file. It only stat()s and scandir()s.
  * os.scandir aggregation, no hashing of large files (sidecar hashes are
    only *checked for existence*, never recomputed).
  * Skip junctions / reparse points (record, do not descend).
  * HARD-SKIP C:\\QM\\mt5\\T_Live contents -> node recorded as never_touch,
    size unknown, not descended.
  * Skip D:\\QM\\mt5\\T1..T10 (+ DEV/FTMO/T_Export) internals -> shallow
    (immediate-child) size only, marked not-descended.
  * Cap at MAX_ENTRIES_PER_ROOT entries per root; on hit, stop descending and
    record an EXPLICIT truncation note (no silent caps).
  * Runtime target < 15 min.

Classification is a pure function (`classify`) over a normalized path so it is
unit-testable without touching the filesystem. Rules are an explicit,
most-specific-first path-prefix table (RULES). Anything unmatched falls to
class=unknown / owner=unknown / retention=candidate_for_cleanup_review
(review, never keep and never a delete).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone

# --- enums (kept as plain strings for JSON friendliness) ---------------------
CLASS_ACTIVE_RUNTIME = "active_runtime"
CLASS_CANONICAL_EVIDENCE = "canonical_evidence"
CLASS_GENERATED_REPORT = "generated_report"
CLASS_BACKUP = "backup"
CLASS_SCRATCH = "scratch_or_temp"
CLASS_DEPLOY = "deploy"
CLASS_UNKNOWN = "unknown"

OWNER_FACTORY = "factory"
OWNER_PIPELINE = "pipeline"
OWNER_LIVE = "live"
OWNER_OPS = "ops"
OWNER_UNKNOWN = "unknown"

RET_KEEP = "keep"
RET_ARCHIVE = "archive"
RET_REVIEW = "candidate_for_cleanup_review"
RET_NEVER_TOUCH = "never_touch"

# Windows reparse-point attribute bit (junctions + symlinks).
FILE_ATTRIBUTE_REPARSE_POINT = 0x400

# Per-root entry cap (no silent truncation; recorded when hit).
MAX_ENTRIES_PER_ROOT = 200_000

# Default report depth (relative to each root). Nodes deeper than this still
# contribute their bytes to ancestor totals but are not emitted individually.
DEFAULT_REPORT_DEPTH = 4


def norm(path: str) -> str:
    """Normalize to lowercase forward-slash form for prefix matching."""
    return path.replace("\\", "/").rstrip("/").lower()


# --- classification rule table -----------------------------------------------
# Each rule: (normalized-prefix, class, owner, retention, no_descend_reason)
# no_descend_reason is None unless the node must NOT be descended into.
# Matched MOST-SPECIFIC-FIRST (longest prefix wins), so order here is only a
# tie-break aid; `classify` sorts by prefix length descending.
RULES: list[tuple[str, str, str, str, str | None]] = [
    # ---- live terminal: hard skip, never touch --------------------------
    ("c:/qm/mt5/t_live", CLASS_ACTIVE_RUNTIME, OWNER_LIVE, RET_NEVER_TOUCH,
     "T_Live is the isolated live terminal; contents never inventoried"),

    # ---- factory terminals: record shallow, do not descend internals ----
    ("d:/qm/mt5/t_live", CLASS_ACTIVE_RUNTIME, OWNER_LIVE, RET_NEVER_TOUCH,
     "live-adjacent terminal; internals not traversed"),
    ("d:/qm/mt5", CLASS_ACTIVE_RUNTIME, OWNER_FACTORY, RET_NEVER_TOUCH,
     "factory terminal (T1..T10/DEV/FTMO); internals not traversed"),

    # ---- backups (most specific first) ----------------------------------
    ("d:/qm/strategy_farm/state/backups", CLASS_BACKUP, OWNER_FACTORY, RET_ARCHIVE, None),
    ("d:/qm/strategy_farm/backups", CLASS_BACKUP, OWNER_FACTORY, RET_ARCHIVE, None),
    ("d:/qm/backups", CLASS_BACKUP, OWNER_OPS, RET_ARCHIVE, None),
    ("c:/qm/integration_backups", CLASS_BACKUP, OWNER_OPS, RET_ARCHIVE, None),
    ("g:/my drive/qm_backups", CLASS_BACKUP, OWNER_OPS, RET_KEEP, None),

    # ---- active runtime state -------------------------------------------
    # state/backups already carved out above (longer prefix wins).
    ("d:/qm/strategy_farm/state", CLASS_ACTIVE_RUNTIME, OWNER_FACTORY, RET_KEEP, None),
    ("d:/qm/strategy_farm", CLASS_ACTIVE_RUNTIME, OWNER_FACTORY, RET_KEEP, None),

    # ---- source / input data --------------------------------------------
    ("d:/qm/data", CLASS_ACTIVE_RUNTIME, OWNER_PIPELINE, RET_KEEP, None),
    ("d:/qm/research_sources", CLASS_ACTIVE_RUNTIME, OWNER_PIPELINE, RET_KEEP, None),

    # ---- canonical evidence (immutable) ---------------------------------
    ("d:/qm/reports/canonical", CLASS_CANONICAL_EVIDENCE, OWNER_PIPELINE, RET_KEEP, None),
    ("c:/qm/repo/docs/ops/evidence", CLASS_CANONICAL_EVIDENCE, OWNER_OPS, RET_KEEP, None),
    ("c:/qm/repo/decisions", CLASS_CANONICAL_EVIDENCE, OWNER_OPS, RET_KEEP, None),

    # ---- generated / reproducible reports -------------------------------
    ("d:/qm/reports/scratch", CLASS_SCRATCH, OWNER_PIPELINE, RET_REVIEW, None),
    ("d:/qm/reports/work", CLASS_GENERATED_REPORT, OWNER_PIPELINE, RET_REVIEW, None),
    ("d:/qm/reports/state", CLASS_GENERATED_REPORT, OWNER_PIPELINE, RET_KEEP, None),
    ("d:/qm/reports", CLASS_GENERATED_REPORT, OWNER_PIPELINE, RET_REVIEW, None),
    ("d:/qm/exports", CLASS_GENERATED_REPORT, OWNER_OPS, RET_REVIEW, None),
    ("d:/qm/audit_runs", CLASS_GENERATED_REPORT, OWNER_OPS, RET_REVIEW, None),
    ("d:/qm/audit_snapshots", CLASS_GENERATED_REPORT, OWNER_OPS, RET_REVIEW, None),
    ("d:/qm/build", CLASS_GENERATED_REPORT, OWNER_FACTORY, RET_REVIEW, None),

    # ---- archive --------------------------------------------------------
    ("d:/qm/archive", CLASS_BACKUP, OWNER_OPS, RET_ARCHIVE, None),
    ("c:/qm/archive", CLASS_BACKUP, OWNER_OPS, RET_ARCHIVE, None),

    # ---- deploy / releases ----------------------------------------------
    ("c:/qm/deploy", CLASS_DEPLOY, OWNER_OPS, RET_KEEP, None),
    ("c:/qm/staged", CLASS_DEPLOY, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/staging", CLASS_DEPLOY, OWNER_OPS, RET_REVIEW, None),

    # ---- repo (versioned code) ------------------------------------------
    ("c:/qm/repo", CLASS_ACTIVE_RUNTIME, OWNER_OPS, RET_KEEP, None),

    # ---- scratch / temp -------------------------------------------------
    ("c:/qm/scratch", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/tmp", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/temp", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/tasks", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/tmp_review", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/logs", CLASS_GENERATED_REPORT, OWNER_OPS, RET_REVIEW, None),
    ("d:/qm/scratch", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("d:/qm/tmp", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),

    # ---- runtime / worktrees under C:\QM --------------------------------
    ("c:/qm/_codex_worktrees", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/runtime_worktrees", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/worktrees", CLASS_SCRATCH, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/reports", CLASS_GENERATED_REPORT, OWNER_OPS, RET_REVIEW, None),
    ("c:/qm/mail-agent", CLASS_ACTIVE_RUNTIME, OWNER_OPS, RET_KEEP, None),
]


@dataclass
class Classification:
    cls: str
    owner: str
    retention: str
    no_descend_reason: str | None
    matched_prefix: str | None


# Pre-sort by prefix length (most specific first) once at import.
_SORTED_RULES = sorted(RULES, key=lambda r: len(r[0]), reverse=True)


def classify(path: str) -> Classification:
    """Pure classification of a filesystem path.

    Unmatched paths fall to unknown/unknown and RET_REVIEW (a review bucket) --
    never `keep`, never `never_touch`, and never a delete. This is the
    fail-safe: an unknown directory is surfaced for human review, not silently
    trusted or silently marked for cleanup.
    """
    n = norm(path)
    for prefix, cls, owner, ret, no_descend in _SORTED_RULES:
        if n == prefix or n.startswith(prefix + "/"):
            return Classification(cls, owner, ret, no_descend, prefix)
    return Classification(CLASS_UNKNOWN, OWNER_UNKNOWN, RET_REVIEW, None, None)


@dataclass
class Node:
    path: str
    depth: int
    cls: str
    owner: str
    retention: str
    size_bytes: int
    file_count: int
    dir_count: int
    newest_mtime: float | None
    oldest_mtime: float | None
    descended: bool
    note: str | None = None
    restore_status: dict | None = None


@dataclass
class RootResult:
    root: str
    exists: bool
    entries_scanned: int
    truncated: bool
    truncation_note: str | None
    elapsed_sec: float
    nodes: list[Node] = field(default_factory=list)


# --- backup restore-status ---------------------------------------------------
_SIDECAR_EXT = (".sha256", ".sha256sum", ".md5", ".manifest", ".manifest.json", ".sig")


def _iso(ts: float | None) -> str | None:
    if ts is None:
        return None
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def scan_backup_restore_status(dir_path: str) -> dict:
    """Existence-only restore check for a backup directory (no hashing).

    Reports, for each immediate archive/backup file, whether a manifest/hash
    sidecar exists next to it, plus the newest backup mtime. We only stat and
    read directory entries -- we never recompute a hash (contract: no hashing
    of large files).
    """
    archives: list[dict] = []
    newest_backup: float | None = None
    try:
        with os.scandir(dir_path) as it:
            entries = list(it)
    except OSError as exc:  # pragma: no cover - defensive
        return {"error": str(exc), "archives": [], "newest_backup_utc": None,
                "all_have_sidecar": None}

    names_lower = {e.name.lower() for e in entries if e.is_file(follow_symlinks=False)}

    for e in entries:
        try:
            if not e.is_file(follow_symlinks=False):
                continue
        except OSError:
            continue
        low = e.name.lower()
        if low.endswith(_SIDECAR_EXT):
            continue  # sidecar itself, not an archive
        if not low.endswith((".zip", ".7z", ".tar", ".gz", ".tgz", ".bundle",
                             ".sqlite", ".bak", ".dump")):
            continue
        try:
            st = e.stat(follow_symlinks=False)
        except OSError:
            continue
        if newest_backup is None or st.st_mtime > newest_backup:
            newest_backup = st.st_mtime
        sidecar = any((low + ext) in names_lower or
                      (os.path.splitext(low)[0] + ext) in names_lower
                      for ext in _SIDECAR_EXT)
        archives.append({
            "name": e.name,
            "size_bytes": st.st_size,
            "mtime_utc": _iso(st.st_mtime),
            "sidecar_present": sidecar,
        })

    all_have = (all(a["sidecar_present"] for a in archives) if archives else None)
    return {
        "archives": archives,
        "archive_count": len(archives),
        "newest_backup_utc": _iso(newest_backup),
        "all_have_sidecar": all_have,
    }


# --- reparse-point / junction detection --------------------------------------
def is_reparse(entry_or_stat) -> bool:
    """True if the dir entry / stat result is a reparse point (junction/symlink)."""
    try:
        st = (entry_or_stat.stat(follow_symlinks=False)
              if hasattr(entry_or_stat, "stat") else entry_or_stat)
        attrs = getattr(st, "st_file_attributes", 0)
        return bool(attrs & FILE_ATTRIBUTE_REPARSE_POINT)
    except OSError:
        return False


# --- the walker --------------------------------------------------------------
class _Walker:
    def __init__(self, root: str, report_depth: int, max_entries: int):
        self.root = root
        self.report_depth = report_depth
        self.max_entries = max_entries
        self.entries = 0
        self.truncated = False
        self.nodes: list[Node] = []

    def _agg(self, dir_path: str, depth: int):
        """Recurse; return (size, file_count, dir_count, newest, oldest).

        Emits a Node for dir_path when depth <= report_depth. Deeper subtree
        bytes still roll up into ancestors. Honors no-descend classification,
        reparse skipping, and the per-root entry cap.
        """
        cl = classify(dir_path)

        # --- no-descend nodes: record shallow, do not recurse -------------
        if cl.no_descend_reason is not None:
            size, fcount, dcount, newest, oldest, note = self._shallow(dir_path, cl)
            self._emit(dir_path, depth, cl, size, fcount, dcount, newest, oldest,
                       descended=False, note=cl.no_descend_reason + (f"; {note}" if note else ""))
            # Coalesce unknown (None) shallow values to 0 for ancestor roll-up
            # so an un-enumerated node (e.g. T_Live) does not poison parent sums;
            # the node record itself keeps size unknown (-1) via _emit.
            return (size or 0, fcount or 0, dcount or 0, newest, oldest)

        total_size = 0
        file_count = 0
        dir_count = 0
        newest: float | None = None
        oldest: float | None = None

        try:
            it = os.scandir(dir_path)
        except OSError as exc:
            self._emit(dir_path, depth, cl, 0, 0, 0, None, None, descended=False,
                       note=f"scandir_error: {exc}")
            return 0, 0, 0, None, None

        with it:
            for entry in it:
                if self.entries >= self.max_entries:
                    self.truncated = True
                    break
                self.entries += 1
                try:
                    st = entry.stat(follow_symlinks=False)
                except OSError:
                    continue

                # skip junctions/symlinks (record nothing, do not follow)
                if is_reparse(st):
                    if entry.is_dir(follow_symlinks=False):
                        dir_count += 1
                    continue

                is_dir = False
                try:
                    is_dir = entry.is_dir(follow_symlinks=False)
                except OSError:
                    is_dir = False

                if is_dir:
                    dir_count += 1
                    s, fc, dc, nw, ol = self._agg(entry.path, depth + 1)
                    total_size += s
                    file_count += fc
                    dir_count += dc
                    newest = _max(newest, nw)
                    oldest = _min(oldest, ol)
                else:
                    file_count += 1
                    total_size += st.st_size
                    newest = _max(newest, st.st_mtime)
                    oldest = _min(oldest, st.st_mtime)

        self._emit(dir_path, depth, cl, total_size, file_count, dir_count,
                   newest, oldest, descended=True)
        return total_size, file_count, dir_count, newest, oldest

    def _shallow(self, dir_path: str, cl: Classification):
        """Immediate-children-only scan for no-descend nodes.

        For T_Live (never_touch) we do not even enumerate: size unknown.
        For factory terminals we count immediate children + immediate file
        bytes only (fast, bounded), never descending into subdirectories.
        """
        if cl.retention == RET_NEVER_TOUCH and cl.owner == OWNER_LIVE:
            return None, None, None, None, None, "size unknown (not enumerated)"
        size = 0
        fcount = 0
        dcount = 0
        newest: float | None = None
        oldest: float | None = None
        capped = False
        try:
            with os.scandir(dir_path) as it:
                for entry in it:
                    if self.entries >= self.max_entries:
                        self.truncated = True
                        capped = True
                        break
                    self.entries += 1
                    try:
                        st = entry.stat(follow_symlinks=False)
                    except OSError:
                        continue
                    if is_reparse(st):
                        continue
                    try:
                        if entry.is_dir(follow_symlinks=False):
                            dcount += 1
                            continue
                    except OSError:
                        continue
                    fcount += 1
                    size += st.st_size
                    newest = _max(newest, st.st_mtime)
                    oldest = _min(oldest, st.st_mtime)
        except OSError as exc:
            return None, None, None, None, None, f"scandir_error: {exc}"
        note = "shallow immediate-level size only"
        if capped:
            note += " (entry cap hit)"
        return size, fcount, dcount, newest, oldest, note

    def _emit(self, path, depth, cl, size, fcount, dcount, newest, oldest,
              descended, note=None):
        if depth > self.report_depth:
            return
        restore = None
        if cl.cls == CLASS_BACKUP:
            restore = scan_backup_restore_status(path)
        self.nodes.append(Node(
            path=path, depth=depth, cls=cl.cls, owner=cl.owner,
            retention=cl.retention, size_bytes=size if size is not None else -1,
            file_count=fcount if fcount is not None else -1,
            dir_count=dcount if dcount is not None else -1,
            newest_mtime=newest, oldest_mtime=oldest, descended=descended,
            note=note, restore_status=restore,
        ))

    def run(self) -> RootResult:
        t0 = time.time()
        exists = os.path.isdir(self.root)
        if exists:
            self._agg(self.root, 0)
        trunc_note = None
        if self.truncated:
            trunc_note = (f"TRUNCATED: per-root entry cap {self.max_entries} reached; "
                          f"deeper entries not scanned (sizes below the cap are "
                          f"partial, not silently complete).")
        return RootResult(
            root=self.root, exists=exists, entries_scanned=self.entries,
            truncated=self.truncated, truncation_note=trunc_note,
            elapsed_sec=round(time.time() - t0, 2), nodes=self.nodes,
        )


def _max(a: float | None, b: float | None):
    if a is None:
        return b
    if b is None:
        return a
    return a if a > b else b


def _min(a: float | None, b: float | None):
    if a is None:
        return b
    if b is None:
        return a
    return a if a < b else b


DEFAULT_ROOTS = [
    "C:\\QM",
    "D:\\QM\\data",
    "D:\\QM\\reports",
    "D:\\QM\\exports",
    "D:\\QM\\strategy_farm",
    "G:\\My Drive\\QM_Backups",
]


def human(n: int) -> str:
    if n is None or n < 0:
        return "?"
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if n < 1024:
            return f"{n:.0f}{unit}" if unit == "B" else f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}PB"


def _age_days(ts: float | None) -> str:
    if ts is None:
        return "?"
    return f"{(time.time() - ts) / 86400:.0f}d"


def build_markdown(results: list[RootResult], top_n: int = 20) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines: list[str] = []
    lines.append("# QuantMechanica Filesystem Inventory (DRY-RUN)")
    lines.append("")
    lines.append(f"Generated: {now}  |  tool: `tools/ops/filesystem_inventory.py`")
    lines.append("")
    lines.append("**NO deletions were performed or scheduled. This is an inventory only.**")
    lines.append("")

    # roots summary
    lines.append("## Roots scanned")
    lines.append("")
    lines.append("| root | exists | entries | truncated | elapsed |")
    lines.append("|---|---|---|---|---|")
    for r in results:
        lines.append(f"| `{r.root}` | {r.exists} | {r.entries_scanned:,} | "
                     f"{'YES' if r.truncated else 'no'} | {r.elapsed_sec}s |")
    lines.append("")
    for r in results:
        if r.truncation_note:
            lines.append(f"> {r.truncation_note} (root `{r.root}`)")
            lines.append("")

    all_nodes = [n for r in results for n in r.nodes]

    def split(pred):
        return [n for n in all_nodes if pred(n)]

    active = split(lambda n: n.cls in (CLASS_ACTIVE_RUNTIME, CLASS_CANONICAL_EVIDENCE,
                                       CLASS_GENERATED_REPORT, CLASS_DEPLOY))
    backup_scratch = split(lambda n: n.cls in (CLASS_BACKUP, CLASS_SCRATCH))

    def node_table(nodes, limit=None):
        rows = ["| path | class | owner | retention | size | files | newest | oldest |",
                "|---|---|---|---|---|---|---|---|"]
        nodes = sorted(nodes, key=lambda n: (n.size_bytes if n.size_bytes >= 0 else -1),
                       reverse=True)
        if limit:
            nodes = nodes[:limit]
        for n in nodes:
            rows.append(
                f"| `{n.path}` | {n.cls} | {n.owner} | {n.retention} | "
                f"{human(n.size_bytes)} | {n.file_count if n.file_count>=0 else '?'} | "
                f"{_age_days(n.newest_mtime)} | {_age_days(n.oldest_mtime)} |")
        return rows

    lines.append("## ACTIVE RUNTIME / EVIDENCE / REPORTS (top nodes by size)")
    lines.append("")
    lines += node_table(active, limit=40)
    lines.append("")

    lines.append("## BACKUP / SCRATCH (top nodes by size)")
    lines.append("")
    lines += node_table(backup_scratch, limit=40)
    lines.append("")

    # top-20 overall size hogs
    lines.append(f"## Top-{top_n} size hogs (all classes)")
    lines.append("")
    lines += node_table(all_nodes, limit=top_n)
    lines.append("")

    # unknowns needing review
    unknowns = split(lambda n: n.cls == CLASS_UNKNOWN)
    lines.append(f"## Unknown / needs-review nodes ({len(unknowns)})")
    lines.append("")
    if unknowns:
        lines += node_table(unknowns, limit=40)
    else:
        lines.append("_none_")
    lines.append("")

    # backup restore status
    lines.append("## Backup restore-status (sidecar existence only, no re-hashing)")
    lines.append("")
    lines.append("Only backup nodes that actually contain archive files are listed "
                 "(the many empty backup-tree subdirectories are omitted here; they "
                 "are all in `inventory.json`).")
    lines.append("")
    lines.append("| backup node | archives | newest backup | all have sidecar |")
    lines.append("|---|---|---|---|")
    backup_with_archives = [n for n in all_nodes if n.cls == CLASS_BACKUP
                            and n.restore_status
                            and n.restore_status.get("archive_count")]
    for n in sorted(backup_with_archives,
                    key=lambda n: n.restore_status.get("archive_count", 0), reverse=True):
        rs = n.restore_status
        flag = rs.get("all_have_sidecar")
        mark = "" if flag else "  ⚠ MISSING SIDECAR" if flag is False else ""
        lines.append(f"| `{n.path}` | {rs.get('archive_count','?')} | "
                     f"{rs.get('newest_backup_utc') or '-'} | {flag}{mark} |")
    if not backup_with_archives:
        lines.append("| _(no archive files found in any backup node)_ | | | |")
    lines.append("")

    # retention rollup
    lines.append("## Retention rollup (emitted nodes)")
    lines.append("")
    roll: dict[str, int] = {}
    for n in all_nodes:
        roll[n.retention] = roll.get(n.retention, 0) + 1
    lines.append("| retention | node count |")
    lines.append("|---|---|")
    for k in (RET_KEEP, RET_ARCHIVE, RET_REVIEW, RET_NEVER_TOUCH):
        lines.append(f"| {k} | {roll.get(k, 0)} |")
    lines.append("")
    lines.append("_Retention values are SUGGESTIONS for OWNER review. Nothing acts on them._")
    lines.append("")
    return "\n".join(lines)


def run_inventory(roots, report_depth, max_entries):
    results = []
    for root in roots:
        results.append(_Walker(root, report_depth, max_entries).run())
    return results


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", action="append", dest="roots",
                    help="override root (repeatable); default = configured VPS roots")
    ap.add_argument("--depth", type=int, default=DEFAULT_REPORT_DEPTH,
                    help=f"report depth per root (default {DEFAULT_REPORT_DEPTH})")
    ap.add_argument("--max-entries", type=int, default=MAX_ENTRIES_PER_ROOT)
    ap.add_argument("--out-dir", default=None,
                    help="output dir; default D:\\QM\\reports\\state\\filesystem_inventory\\<ts>")
    ap.add_argument("--stdout", action="store_true",
                    help="also print markdown to stdout")
    args = ap.parse_args(argv)

    roots = args.roots or DEFAULT_ROOTS
    ts = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out_dir = args.out_dir or os.path.join(
        "D:\\QM\\reports\\state\\filesystem_inventory", ts)
    os.makedirs(out_dir, exist_ok=True)

    t0 = time.time()
    results = run_inventory(roots, args.depth, args.max_entries)
    elapsed = round(time.time() - t0, 2)

    payload = {
        "generated_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "tool": "tools/ops/filesystem_inventory.py",
        "dry_run": True,
        "report_depth": args.depth,
        "max_entries_per_root": args.max_entries,
        "total_elapsed_sec": elapsed,
        "roots": [
            {**{k: v for k, v in asdict(r).items() if k != "nodes"},
             "nodes": [asdict(n) for n in r.nodes]}
            for r in results
        ],
    }
    json_path = os.path.join(out_dir, "inventory.json")
    md_path = os.path.join(out_dir, "inventory_summary.md")
    with open(json_path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)
    md = build_markdown(results)
    with open(md_path, "w", encoding="utf-8") as fh:
        fh.write(md)

    print(f"[filesystem_inventory] DRY-RUN complete in {elapsed}s")
    for r in results:
        print(f"  {r.root}: {r.entries_scanned:,} entries, {len(r.nodes)} nodes, "
              f"{r.elapsed_sec}s{'  [TRUNCATED]' if r.truncated else ''}")
    print(f"  JSON: {json_path}")
    print(f"  MD  : {md_path}")
    if args.stdout:
        print("\n" + md)
    return 0


if __name__ == "__main__":
    sys.exit(main())
