"""Recover an interrupted legacy-layout phase-2 retention quarantine.

This helper is intentionally narrow: it understands the pre-flat layout
``<quarantine>/<scope>/<source-relative-path>`` used by the interrupted
2026-08-31 run.  If the original source path is vacant, the file is restored.
If a live process recreated the source, the quarantined copy is retained in a
flat, hashed ``retention_drift_keep`` archive on the same volume.  Nothing is
deleted and no existing source is overwritten.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
from pathlib import Path

import execute_backup_retention_phase2 as phase2


SOURCE_ROOTS = {
    "D_REPORTS": Path("D:/QM/reports"),
    "D_FARM_LOGS": Path("D:/QM/strategy_farm/logs"),
    "C_RELOCATED": Path("C:/QM/backups_relocated"),
}


def _quarantine_roots(run_id: str) -> list[Path]:
    return [
        Path(f"D:/QM/reports/maintenance/retention_quarantine_{run_id}"),
        Path(f"C:/QM/backups_relocated/retention_quarantine_{run_id}"),
    ]


def _within(path: Path, root: Path) -> bool:
    try:
        path.resolve(strict=False).relative_to(root.resolve(strict=False))
        return True
    except ValueError:
        return False


def _files(root: Path) -> list[Path]:
    found: list[Path] = []
    if not root.is_dir():
        return found
    for current, _dirs, names in os.walk(root):
        for name in names:
            found.append(Path(current) / name)
    return found


def _archive_destination(source: Path, scope: str, run_id: str) -> Path:
    token = hashlib.sha256(f"{scope}\0{source}".encode("utf-8")).hexdigest()
    suffix = "".join(source.suffixes[-2:])[-24:]
    if scope in {"D_REPORTS", "D_FARM_LOGS"}:
        root = Path(f"D:/QM/reports/maintenance/retention_drift_keep_{run_id}")
    else:
        root = Path(f"C:/QM/backups_relocated/retention_drift_keep_{run_id}")
    return root / scope / token[:2] / f"{token}{suffix}"


def plan(run_id: str) -> list[dict[str, object]]:
    entries: list[dict[str, object]] = []
    for qroot in _quarantine_roots(run_id):
        resolved_qroot = qroot.resolve(strict=False)
        expected_parent = (
            Path("D:/QM/reports/maintenance").resolve()
            if qroot.drive.upper() == "D:"
            else Path("C:/QM/backups_relocated").resolve()
        )
        if not _within(resolved_qroot, expected_parent):
            raise ValueError(f"quarantine root escaped expected parent: {qroot}")
        for quarantined in _files(qroot):
            relative = quarantined.relative_to(qroot)
            if len(relative.parts) < 2 or relative.parts[0] not in SOURCE_ROOTS:
                entries.append({
                    "quarantine": str(quarantined),
                    "status": "UNMAPPABLE_KEEP",
                    "detail": "legacy scope/relative layout not recognized",
                })
                continue
            scope = relative.parts[0]
            source_root = SOURCE_ROOTS[scope]
            source = source_root.joinpath(*relative.parts[1:])
            if not _within(source, source_root):
                entries.append({
                    "quarantine": str(quarantined),
                    "status": "UNMAPPABLE_KEEP",
                    "detail": "reconstructed source escaped allowed root",
                })
                continue
            stat = quarantined.stat()
            archive = _archive_destination(source, scope, run_id)
            entries.append({
                "scope": scope,
                "quarantine": str(quarantined),
                "source": str(source),
                "archive": str(archive),
                "size": int(stat.st_size),
                "mtime_ns": int(stat.st_mtime_ns),
                "inode": int(stat.st_ino),
                "status": "WOULD_ARCHIVE_COLLISION" if source.exists() else "WOULD_RESTORE",
            })
    entries.sort(key=lambda entry: str(entry.get("quarantine", "")).lower())
    return entries


def plan_flat(run_id: str, receipt_dir: Path) -> list[dict[str, object]]:
    """Recover flat hashed quarantine files using their exact-path receipts."""
    entries: list[dict[str, object]] = []
    seen: set[str] = set()
    for receipt_path in sorted(receipt_dir.glob("batch_*.json")):
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if int(receipt.get("recoverable_quarantine_files", 0)) < 1:
            continue
        exact_path = receipt_dir / str(receipt["exact_paths_file"])
        with gzip.open(exact_path, "rt", encoding="utf-8") as fh:
            for line in fh:
                raw = json.loads(line)
                if not str(raw.get("status", "")).startswith("QUARANTINED"):
                    continue
                quarantined = Path(str(raw["quarantine"]))
                if str(quarantined).lower() in seen:
                    continue
                seen.add(str(quarantined).lower())
                scope = str(raw["scope"])
                source = Path(str(raw["source"]))
                source_root = SOURCE_ROOTS.get(scope)
                expected_qroots = _quarantine_roots(run_id)
                if source_root is None or not _within(source, source_root) or not any(
                    _within(quarantined, root) for root in expected_qroots
                ):
                    entries.append({
                        "scope": scope,
                        "quarantine": str(quarantined),
                        "source": str(source),
                        "status": "UNMAPPABLE_KEEP",
                        "detail": "flat receipt path escaped an allowed source/quarantine root",
                    })
                    continue
                if not quarantined.exists():
                    entries.append({
                        "scope": scope,
                        "quarantine": str(quarantined),
                        "source": str(source),
                        "status": "ALREADY_RESOLVED",
                        "detail": "receipt named a recoverable path that is no longer present",
                    })
                    continue
                stat = quarantined.stat()
                archive = _archive_destination(source, scope, run_id)
                entries.append({
                    "scope": scope,
                    "quarantine": str(quarantined),
                    "source": str(source),
                    "archive": str(archive),
                    "size": int(stat.st_size),
                    "mtime_ns": int(stat.st_mtime_ns),
                    "inode": int(stat.st_ino),
                    "status": "WOULD_ARCHIVE_COLLISION" if source.exists() else "WOULD_RESTORE",
                    "source_receipt": receipt_path.name,
                })
    entries.sort(key=lambda entry: str(entry.get("quarantine", "")).lower())
    return entries


def _prune_empty(root: Path) -> None:
    if not root.is_dir():
        return
    for current, _dirs, _files_list in os.walk(root, topdown=False):
        try:
            Path(current).rmdir()
        except OSError:
            pass


def apply(entries: list[dict[str, object]], run_id: str) -> None:
    for entry in entries:
        if not str(entry["status"]).startswith("WOULD_"):
            continue
        quarantined = Path(str(entry["quarantine"]))
        source = Path(str(entry["source"]))
        archive = Path(str(entry["archive"]))
        try:
            before = quarantined.stat()
        except OSError as exc:
            entry["status"] = "ERROR_KEEP"
            entry["detail"] = f"quarantine_stat_failed:{exc}"
            continue
        destination = source if not source.exists() else archive
        if destination == archive and archive.exists():
            entry["status"] = "ERROR_KEEP"
            entry["detail"] = "drift_archive_collision"
            continue
        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            # os.rename is deliberately used on Windows: unlike os.replace it
            # fails if a live writer recreated the destination in this narrow
            # race window, so recovery can never overwrite current data.
            os.rename(quarantined, destination)
            after = destination.stat()
        except FileExistsError:
            if destination != source or archive.exists():
                entry["status"] = "ERROR_KEEP"
                entry["detail"] = "destination_recreated_during_recovery"
                continue
            try:
                archive.parent.mkdir(parents=True, exist_ok=True)
                os.rename(quarantined, archive)
                destination = archive
                after = destination.stat()
            except OSError as exc:
                entry["status"] = "ERROR_KEEP"
                entry["detail"] = f"recovery_archive_after_race_failed:{exc}"
                continue
        except OSError as exc:
            entry["status"] = "ERROR_KEEP"
            entry["detail"] = f"recovery_move_failed:{exc}"
            continue
        if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
            if not quarantined.exists():
                try:
                    quarantined.parent.mkdir(parents=True, exist_ok=True)
                    os.replace(destination, quarantined)
                except OSError:
                    pass
            entry["status"] = "ERROR_KEEP"
            entry["detail"] = "post_move_identity_mismatch"
            continue
        entry["destination"] = str(destination)
        if destination == source:
            entry["status"] = "RESTORED"
            entry["detail"] = "source vacant; original path restored"
        else:
            entry["status"] = "DRIFT_ARCHIVED"
            entry["detail"] = "source recreated; quarantined version retained without overwrite"
    for root in _quarantine_roots(run_id):
        _prune_empty(root)


def summary(entries: list[dict[str, object]], run_id: str, mode: str) -> dict[str, object]:
    counts: dict[str, int] = {}
    bytes_by_status: dict[str, int] = {}
    for entry in entries:
        status = str(entry["status"])
        counts[status] = counts.get(status, 0) + 1
        bytes_by_status[status] = bytes_by_status.get(status, 0) + int(entry.get("size", 0))
    return {
        "schema": "qm.backup-retention.phase2-recovery.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "run_id": run_id,
        "mode": mode,
        "files": len(entries),
        "bytes": sum(int(entry.get("size", 0)) for entry in entries),
        "counts": dict(sorted(counts.items())),
        "bytes_by_status": dict(sorted(bytes_by_status.items())),
        "completed_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--receipt-dir", type=Path)
    parser.add_argument("--layout", choices=("legacy", "flat"), default="legacy")
    args = parser.parse_args()
    if args.layout == "flat" and not args.receipt_dir:
        parser.error("--layout flat requires --receipt-dir")
    entries = plan_flat(args.run_id, args.receipt_dir) if args.layout == "flat" else plan(args.run_id)
    if args.apply:
        if not args.receipt_dir:
            parser.error("--apply requires --receipt-dir")
        canonical = Path("C:/QM/repo/docs/ops/evidence").resolve()
        receipt_dir = args.receipt_dir.resolve()
        if not _within(receipt_dir, canonical):
            raise ValueError(f"receipt directory must be under {canonical}")
        apply(entries, args.run_id)
        stem = f"recovery_{args.layout}_quarantine"
        exact = receipt_dir / f"{stem}_exact_paths.jsonl.gz"
        canonical_sha, gzip_sha, gzip_bytes = phase2._write_exact_inventory(exact, entries)
        result = summary(entries, args.run_id, "APPLY")
        result.update({
            "exact_paths_file": exact.name,
            "exact_paths_canonical_sha256": canonical_sha,
            "exact_paths_gzip_sha256": gzip_sha,
            "exact_paths_gzip_bytes": gzip_bytes,
        })
        phase2._atomic_json(receipt_dir / f"{stem}.json", result)
    else:
        result = summary(entries, args.run_id, "DRY_RUN")
    print(json.dumps(result, indent=2, sort_keys=True))
    return 2 if any(str(entry["status"]).startswith(("ERROR", "UNMAPPABLE")) for entry in entries) else 0


if __name__ == "__main__":
    raise SystemExit(main())
