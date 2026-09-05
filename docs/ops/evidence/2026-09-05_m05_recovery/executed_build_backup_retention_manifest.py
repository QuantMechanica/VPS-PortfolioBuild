"""Build the phase-1 OWNER backup-retention classification manifest.

This tool is intentionally inventory-only.  It does not delete, move, compress,
touch, or chmod any operational file.  The manifest implements
OWNER-DEC-BACKUP-RETENTION-20260830 while retaining the stricter DL-090 guards:

* path-to-25 pairs keep their complete non-log evidence chain;
* other pairs keep the DL-090 artifact set for Q02 and Q04 only;
* logs are deletion candidates unless their work item is open;
* open work items, forbidden trees, and ambiguous files are kept;
* farm-state backups use the union of newest 10 and the trailing 14 days.

The CSV is an aggregate classification manifest, not an execution manifest.
Phase 2 must expand it into exact paths, revalidate the live database, perform
SQLite quick_check, quarantine before deletion, and emit per-batch receipts.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


DEFAULT_DB = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_REPORTS = Path("D:/QM/reports")
DEFAULT_LOGS = Path("D:/QM/strategy_farm/logs")
DEFAULT_RELOCATED = Path("C:/QM/backups_relocated")

OPEN_STATUSES = {"pending", "active", "claimed", "in_progress"}
PASS_PREFIX = "PASS"
REPORT_ARTIFACT_SUFFIXES = (".htm", ".html", ".json", ".ini", ".set")
LOG_SUFFIXES = (".log", ".jsonl")
EA_RE = re.compile(r"QM5[_-]?(\d+)", re.IGNORECASE)
NUMBER_TOKEN_RE = re.compile(r"(?<!\d)(\d{4,5})(?!\d)")
PHASE_RE = re.compile(r"(?<![A-Z0-9])(Q(?:0[1-9]|1[0-5])|P2)(?![A-Z0-9])", re.IGNORECASE)
UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class WorkItem:
    work_id: str
    ea_id: str
    symbol: str
    phase: str
    status: str
    verdict: str
    contract: str


@dataclass
class Snapshot:
    work_items: dict[str, WorkItem] = field(default_factory=dict)
    path_pairs: dict[tuple[str, str], set[str]] = field(default_factory=lambda: defaultdict(set))
    symbols_by_ea: dict[str, set[str]] = field(default_factory=lambda: defaultdict(set))
    db_quick_check: str = "not_run"
    db_max_updated_at: str = ""


@dataclass(frozen=True)
class Classification:
    ea_id: str
    symbol: str
    phase: str
    pair_class: str
    disposition: str
    reason: str


@dataclass
class Aggregate:
    file_count: int = 0
    bytes: int = 0
    projected_free_bytes: int = 0
    compression_candidate_bytes: int = 0


def _norm_symbol(value: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", value.upper())


def _json_pairs(value: object) -> set[tuple[str, str]]:
    text = json.dumps(value, sort_keys=True) if not isinstance(value, str) else value
    eas = {f"QM5_{m}" for m in EA_RE.findall(text)}
    symbols = set(re.findall(r"\b[A-Z]{3,12}(?:\.DWX)?\b", text.upper()))
    ignored = {
        "APPROVED", "BLOCKED", "COMPILE", "IN_PROGRESS", "PASSED", "PIPELINE",
        "RECOVERY", "REQUAL", "REVIEW", "RISK_FIXED", "RISK_PERCENT",
    }
    symbols -= ignored
    return {(ea, sym) for ea in eas for sym in symbols if sym != ea}


def load_snapshot(db_path: Path) -> Snapshot:
    uri = db_path.resolve().as_uri() + "?mode=ro"
    con = sqlite3.connect(uri, uri=True)
    snap = Snapshot()
    try:
        con.execute("BEGIN")
        qc = con.execute("PRAGMA quick_check").fetchone()
        snap.db_quick_check = str(qc[0]) if qc else "no_result"
        rows = con.execute(
            "SELECT id, ea_id, symbol, phase, status, COALESCE(verdict,''), "
            "COALESCE(gate_contract_version,'') FROM work_items"
        ).fetchall()
        for row in rows:
            wi = WorkItem(*(str(x or "") for x in row))
            snap.work_items[wi.work_id.lower()] = wi
            pair = (wi.ea_id, wi.symbol)
            snap.symbols_by_ea[wi.ea_id].add(wi.symbol)
            if wi.status.lower() in OPEN_STATUSES and (
                wi.phase.upper().startswith("Q") or wi.phase.upper() in {"P2", "OPT_CENSUS"}
            ):
                snap.path_pairs[pair].add("OPEN_PIPELINE_OR_OPT_ROW")
            if wi.phase.upper() == "OPT_CENSUS":
                snap.path_pairs[pair].add("OPT_FORK_PROGRAM")
            if wi.contract.lower() == "v4" and wi.verdict.upper().startswith(PASS_PREFIX):
                snap.path_pairs[pair].add("V4_PASS_LINEAGE")

        for ea_id, symbol, state in con.execute(
            "SELECT ea_id, symbol, state FROM portfolio_candidates"
        ):
            pair = (str(ea_id), str(symbol))
            snap.symbols_by_ea[pair[0]].add(pair[1])
            if str(state).upper() != "RETIRED":
                snap.path_pairs[pair].add("PORTFOLIO_CANDIDATE_NON_RETIRED")

        for task_type, state, payload_json in con.execute(
            "SELECT task_type, state, payload_json FROM agent_tasks "
            "WHERE state IN ('APPROVED','IN_PROGRESS','PIPELINE')"
        ):
            searchable = f"{task_type} {payload_json}".lower()
            if "requal" not in searchable and "recovery" not in searchable and "opt_fork" not in searchable:
                continue
            try:
                payload = json.loads(payload_json)
            except (TypeError, json.JSONDecodeError):
                payload = str(payload_json)
            for pair in _json_pairs(payload):
                if pair in snap.symbols_by_ea or pair[1] in snap.symbols_by_ea.get(pair[0], set()):
                    snap.path_pairs[pair].add("INFLIGHT_REQUAL_RECOVERY_OR_OPT_FORK")

        max_updated = con.execute("SELECT COALESCE(MAX(updated_at),'') FROM work_items").fetchone()
        snap.db_max_updated_at = str(max_updated[0]) if max_updated else ""
        con.rollback()
    finally:
        con.close()
    return snap


def _find_work_item(parts: Iterable[str], snap: Snapshot) -> WorkItem | None:
    for part in parts:
        token = part.lower()
        if UUID_RE.fullmatch(token) and token in snap.work_items:
            return snap.work_items[token]
    return None


def _infer_ea(path_text: str, snap: Snapshot) -> str:
    match = EA_RE.search(path_text)
    if match:
        ea = f"QM5_{match.group(1)}"
        return ea if ea in snap.symbols_by_ea else ""
    candidates = {
        f"QM5_{token}" for token in NUMBER_TOKEN_RE.findall(path_text)
        if f"QM5_{token}" in snap.symbols_by_ea
    }
    return next(iter(candidates)) if len(candidates) == 1 else ""


def _infer_symbol(path_text: str, ea_id: str, snap: Snapshot) -> str:
    if not ea_id:
        return ""
    norm_path = _norm_symbol(path_text)
    found = {symbol for symbol in snap.symbols_by_ea.get(ea_id, set()) if _norm_symbol(symbol) in norm_path}
    return next(iter(found)) if len(found) == 1 else ""


def _infer_phase(path_text: str) -> str:
    match = PHASE_RE.search(path_text.replace("_", " ").replace("-", " "))
    return match.group(1).upper() if match else ""


def _is_log(path: Path) -> bool:
    lower = path.name.lower()
    return lower.endswith(LOG_SUFFIXES) or lower.endswith(tuple(s + ".gz" for s in LOG_SUFFIXES))


def _is_compressed(path: Path) -> bool:
    return path.name.lower().endswith((".gz", ".zip", ".7z", ".bz2", ".xz"))


def _is_report_artifact(path: Path) -> bool:
    name = path.name.lower()
    if name.endswith(".gz"):
        name = name[:-3]
    return name.endswith(REPORT_ARTIFACT_SUFFIXES)


def classify_report(path: Path, scope: str, snap: Snapshot) -> Classification:
    parts = path.parts
    wi = _find_work_item(parts, snap)
    if wi:
        ea_id, symbol, phase = wi.ea_id, wi.symbol, wi.phase.upper()
        open_row = wi.status.lower() in OPEN_STATUSES
    else:
        text = str(path)
        ea_id = _infer_ea(text, snap)
        symbol = _infer_symbol(text, ea_id, snap)
        phase = _infer_phase(text)
        open_row = False

    pair = (ea_id, symbol)
    pair_reasons = snap.path_pairs.get(pair, set()) if ea_id and symbol else set()
    pair_class = "PATH_TO_25" if pair_reasons else ("OTHER" if ea_id and symbol else "AMBIGUOUS")

    if open_row:
        return Classification(ea_id, symbol, phase, pair_class, "KEEP_DL090_OPEN", "DL-090 open work item")
    if pair_class == "AMBIGUOUS":
        return Classification(ea_id, symbol, phase, pair_class, "KEEP_AMBIGUOUS", "unresolved pair identity; ambiguity=KEEP")
    if _is_log(path):
        return Classification(ea_id, symbol, phase, pair_class, "DELETE_LOG", "OWNER doctrine: logs need not be kept")
    if pair_class == "PATH_TO_25":
        reason = "+".join(sorted(pair_reasons))
        disposition = "KEEP_ALREADY_COMPRESSED" if _is_compressed(path) else "COMPRESS_KEEP_COMPLETE_CHAIN"
        return Classification(ea_id, symbol, phase, pair_class, disposition, reason)
    if phase not in {"Q02", "Q04"}:
        if not phase:
            return Classification(ea_id, symbol, phase, pair_class, "KEEP_AMBIGUOUS", "pair known but phase unresolved; ambiguity=KEEP")
        return Classification(ea_id, symbol, phase, pair_class, "DELETE_NONRETAINED", "non-path pair; phase is not Q02/Q04")
    if not _is_report_artifact(path):
        return Classification(ea_id, symbol, phase, pair_class, "DELETE_NONRETAINED", "Q02/Q04 file is outside DL-090 retained artifact set")
    disposition = "KEEP_ALREADY_COMPRESSED" if _is_compressed(path) else "COMPRESS_KEEP_Q02_Q04"
    return Classification(ea_id, symbol, phase, pair_class, disposition, "non-path pair retained Q02/Q04 artifact")


def _iter_files(root: Path, forbidden_names: set[str]) -> Iterable[tuple[Path, str | None]]:
    if not root.exists():
        return
    stack = [root]
    while stack:
        current = stack.pop()
        try:
            entries = list(os.scandir(current))
        except OSError:
            yield current, "unreadable directory; ambiguity=KEEP"
            continue
        for entry in entries:
            path = Path(entry.path)
            if entry.is_symlink():
                yield path, "symlink/reparse target not traversed; ambiguity=KEEP"
            elif entry.is_dir(follow_symlinks=False):
                if entry.name.lower() in forbidden_names:
                    yield path, "forbidden tree not traversed"
                else:
                    stack.append(path)
            elif entry.is_file(follow_symlinks=False):
                yield path, None


def _add(
    groups: dict[tuple[str, str, str, str, str, str], Aggregate],
    scope: str,
    classification: Classification,
    size: int,
) -> None:
    key = (
        scope,
        classification.ea_id or "UNRESOLVED",
        classification.symbol or "UNRESOLVED",
        classification.phase or "UNRESOLVED",
        classification.pair_class,
        classification.disposition + "|" + classification.reason,
    )
    agg = groups[key]
    agg.file_count += 1
    agg.bytes += max(0, size)
    if classification.disposition.startswith("DELETE_"):
        agg.projected_free_bytes += max(0, size)
    if classification.disposition.startswith("COMPRESS_"):
        agg.compression_candidate_bytes += max(0, size)


def build_inventory(
    snap: Snapshot,
    reports_root: Path,
    logs_root: Path,
    relocated_root: Path,
    now: dt.datetime,
) -> tuple[list[dict[str, object]], dict[str, object]]:
    groups: dict[tuple[str, str, str, str, str, str], Aggregate] = defaultdict(Aggregate)
    roots = [str(reports_root), str(logs_root), str(relocated_root)]

    # The pair census is explicit even when a pair currently has no surviving
    # file.  Zero-file rows prove that every database pair was tagged rather
    # than silently disappearing from an artifact-only inventory.
    for ea_id in sorted(snap.symbols_by_ea):
        for symbol in sorted(snap.symbols_by_ea[ea_id]):
            reasons = snap.path_pairs.get((ea_id, symbol), set())
            pair_class = "PATH_TO_25" if reasons else "OTHER"
            reason = "+".join(sorted(reasons)) if reasons else "no path-to-25 condition in snapshot"
            key = ("PAIR_CENSUS", ea_id, symbol, "ALL", pair_class, "PAIR_TAG_ONLY|" + reason)
            groups[key]  # materialize a zero-file census row

    # Reports: DL-090 forbids traversal of state; Custom_master and any T_Live
    # copy are likewise never enumerated into a deletion manifest.
    forbidden = {"state", "custom_master", "t_live"}
    for path, skip_reason in _iter_files(reports_root, forbidden):
        if skip_reason:
            c = Classification("", "", "", "FORBIDDEN", "NEVER_TOUCH", skip_reason)
            _add(groups, "D_REPORTS", c, 0)
            continue
        try:
            size = path.stat().st_size
        except OSError:
            size = 0
        _add(groups, "D_REPORTS", classify_report(path, "D_REPORTS", snap), size)

    # The dedicated log root is unambiguously log material under the OWNER
    # doctrine.  No operational mutation occurs here.
    for path, skip_reason in _iter_files(logs_root, {"custom_master", "t_live"}):
        if skip_reason:
            c = Classification("", "", "", "AMBIGUOUS", "KEEP_AMBIGUOUS", skip_reason)
            _add(groups, "D_FARM_LOGS", c, 0)
            continue
        try:
            size = path.stat().st_size
        except OSError:
            size = 0
        c = Classification("", "", "", "LOG_ROOT", "DELETE_LOG", "OWNER doctrine: dedicated farm logs need not be kept")
        _add(groups, "D_FARM_LOGS", c, size)

    backup_files: list[Path] = []
    relocated_entries = list(_iter_files(relocated_root, {"custom_master", "t_live"}))
    for path, skip_reason in relocated_entries:
        lower_parts = {p.lower() for p in path.parts}
        if skip_reason:
            c = Classification("", "", "", "AMBIGUOUS", "KEEP_AMBIGUOUS", skip_reason)
            _add(groups, "C_RELOCATED", c, 0)
        elif any(p.startswith("farm_state_backups_") for p in lower_parts) and path.suffix.lower() in {".sqlite", ".db"}:
            backup_files.append(path)

    backup_files.sort(key=lambda p: p.stat().st_mtime_ns, reverse=True)
    backup_file_set = set(backup_files)
    newest = set(backup_files[:10])
    cutoff = now - dt.timedelta(days=14)

    for path, skip_reason in relocated_entries:
        if skip_reason:
            continue
        try:
            stat = path.stat()
            size = stat.st_size
            modified = dt.datetime.fromtimestamp(stat.st_mtime, dt.UTC)
        except OSError:
            c = Classification("", "", "", "AMBIGUOUS", "KEEP_AMBIGUOUS", "stat failed; ambiguity=KEEP")
            _add(groups, "C_RELOCATED", c, 0)
            continue
        lower_parts = {p.lower() for p in path.parts}
        if path in backup_file_set:
            keep = path in newest or modified >= cutoff
            disposition = "KEEP_DB_ROTATION" if keep else "DELETE_DB_ROTATION"
            reason = "newest 10 or modified within 14 days" if keep else "older than 14 days and outside newest 10; phase-2 quick_check required"
            c = Classification("", "", "", "DB_BACKUP", disposition, reason)
        elif any("log" in p for p in lower_parts) and not any("card" in p for p in lower_parts):
            c = Classification("", "", "", "LOG_ARCHIVE", "DELETE_LOG", "OWNER doctrine: relocated logs need not be kept")
        elif "retention_quarantine" in lower_parts:
            c = classify_report(path, "C_RELOCATED_QUARANTINE", snap)
        else:
            c = Classification("", "", "", "OUT_OF_SCOPE", "KEEP_OUT_OF_SCOPE", "not a report, log, or farm-state backup")
        _add(groups, "C_RELOCATED", c, size)

    rows: list[dict[str, object]] = []
    for key in sorted(groups):
        scope, ea_id, symbol, phase, pair_class, disposition_reason = key
        disposition, reason = disposition_reason.split("|", 1)
        agg = groups[key]
        rows.append({
            "scope": scope,
            "ea_id": ea_id,
            "symbol": symbol,
            "phase": phase,
            "pair_class": pair_class,
            "disposition": disposition,
            "reason": reason,
            "file_count": agg.file_count,
            "bytes": agg.bytes,
            "projected_free_bytes": agg.projected_free_bytes,
            "compression_candidate_bytes": agg.compression_candidate_bytes,
        })
    summary = {
        "roots": roots,
        "row_count": len(rows),
        "file_count": sum(int(r["file_count"]) for r in rows),
        "bytes": sum(int(r["bytes"]) for r in rows),
        "projected_free_bytes": sum(int(r["projected_free_bytes"]) for r in rows),
        "compression_candidate_bytes": sum(int(r["compression_candidate_bytes"]) for r in rows),
        "path_to_25_pair_count": len(snap.path_pairs),
        "db_quick_check": snap.db_quick_check,
        "db_max_work_item_updated_at": snap.db_max_updated_at,
    }
    return rows, summary


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def write_outputs(
    rows: list[dict[str, object]],
    summary: dict[str, object],
    csv_path: Path,
    md_path: Path,
    seal_path: Path,
    generated_at: dt.datetime,
) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "scope", "ea_id", "symbol", "phase", "pair_class", "disposition", "reason",
        "file_count", "bytes", "projected_free_bytes", "compression_candidate_bytes",
    ]
    with csv_path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    csv_sha = _sha256(csv_path)

    by_disposition: dict[str, Aggregate] = defaultdict(Aggregate)
    for row in rows:
        agg = by_disposition[str(row["disposition"])]
        agg.file_count += int(row["file_count"])
        agg.bytes += int(row["bytes"])
        agg.projected_free_bytes += int(row["projected_free_bytes"])
        agg.compression_candidate_bytes += int(row["compression_candidate_bytes"])

    lines = [
        "# OWNER backup-retention phase-1 sealed classification manifest",
        "",
        f"Generated UTC: `{generated_at.replace(microsecond=0).isoformat()}`  ",
        "Authority: `OWNER-DEC-BACKUP-RETENTION-20260830`  ",
        f"CSV SHA-256: `{csv_sha}`",
        "",
        "## Verdict",
        "",
        "`REVIEW` — classification only. No report, log, backup, database row, live file, or terminal state was mutated. Phase 2 is forbidden until Orchestrator approval of this seal.",
        "",
        "## Measured inventory",
        "",
        f"- Aggregated manifest rows: {summary['row_count']:,}",
        f"- Files classified: {summary['file_count']:,}",
        f"- Bytes inventoried: {summary['bytes']:,}",
        f"- Projected deletable bytes: {summary['projected_free_bytes']:,} ({int(summary['projected_free_bytes']) / 1024**3:.2f} GiB)",
        f"- Retained bytes eligible for compression: {summary['compression_candidate_bytes']:,} ({int(summary['compression_candidate_bytes']) / 1024**3:.2f} GiB)",
        f"- Mechanically protected path-to-25 pairs: {summary['path_to_25_pair_count']:,}",
        f"- Live farm DB `PRAGMA quick_check`: `{summary['db_quick_check']}`",
        f"- Snapshot max `work_items.updated_at`: `{summary['db_max_work_item_updated_at']}`",
        "",
        "| disposition | files | bytes | projected free | compression candidate |",
        "|---|---:|---:|---:|---:|",
    ]
    for disposition in sorted(by_disposition):
        a = by_disposition[disposition]
        lines.append(f"| `{disposition}` | {a.file_count:,} | {a.bytes:,} | {a.projected_free_bytes:,} | {a.compression_candidate_bytes:,} |")
    lines += [
        "",
        "## Mechanical classification",
        "",
        "A pair is path-to-25 when at least one live snapshot condition holds: an open pipeline/optimization row; any OPT_CENSUS program row; a v4 PASS-family row; a non-retired portfolio-candidate row; or a resolvable in-flight REQUAL/recovery/opt-fork agent task. All non-log evidence for those pairs is retained. Other pairs retain only Q02/Q04 files in the DL-090 artifact set (`report.htm/html`, summary/aggregate JSON, tester INI, and setfiles). Logs are deletion candidates. Open work items override deletion. Unknown pair/phase identity is kept.",
        "",
        "Farm-state backups are classified by the union of the newest 10 and files modified in the trailing 14 days. A phase-2 executor must repeat `PRAGMA quick_check` immediately before any backup rotation; this phase-1 quick check is evidence, not future authorization.",
        "",
        "## Explicit exclusions and phase-2 gates",
        "",
        "- `D:/QM/reports/state`, any `Custom_master` tree, and any `T_Live` tree are not traversed into the deletion inventory.",
        "- Git-tracked decisions/evidence, live account artifacts, verdict rows, and terminal state are outside scope.",
        "- This CSV is aggregated evidence, not an exact-path deletion list. Phase 2 must expand exact paths, detect drift against this CSV seal, quarantine before deletion, and emit per-batch byte/hash receipts.",
        "- A locked, newly active, missing, changed, or unclassifiable path defaults to KEEP in phase 2.",
        "- No predicted compression saving is asserted; only the measured input bytes eligible for compression are reported.",
        "",
        "## Source roots",
        "",
    ]
    lines.extend(f"- `{root}`" for root in summary["roots"])
    md_path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    md_sha = _sha256(md_path)
    seal_path.write_text(
        f"{csv_sha}  {csv_path.name}\n{md_sha}  {md_path.name}\n",
        encoding="ascii",
        newline="\n",
    )


def _parse_now(value: str | None) -> dt.datetime:
    if not value:
        return dt.datetime.now(dt.UTC)
    parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--reports-root", type=Path, default=DEFAULT_REPORTS)
    parser.add_argument("--logs-root", type=Path, default=DEFAULT_LOGS)
    parser.add_argument("--relocated-root", type=Path, default=DEFAULT_RELOCATED)
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    parser.add_argument("--seal", type=Path, required=True)
    parser.add_argument("--now", help="UTC ISO timestamp; useful only for deterministic verification")
    args = parser.parse_args()
    now = _parse_now(args.now)
    snap = load_snapshot(args.db)
    rows, summary = build_inventory(snap, args.reports_root, args.logs_root, args.relocated_root, now)
    write_outputs(rows, summary, args.csv, args.markdown, args.seal, now)
    print(json.dumps({**summary, "csv_sha256": _sha256(args.csv), "markdown_sha256": _sha256(args.markdown)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
