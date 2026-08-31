"""Verify phase-2 backup-retention receipts and current retained attributes."""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
from collections import Counter
from pathlib import Path

import execute_backup_retention_phase2 as phase2


EXPECTED_MANIFEST_SHA256 = phase2.EXPECTED_MANIFEST_SHA256


def _read_inventory(path: Path) -> tuple[list[dict[str, object]], str]:
    entries: list[dict[str, object]] = []
    digest = hashlib.sha256()
    with gzip.open(path, "rb") as fh:
        for line in fh:
            digest.update(line)
            entries.append(json.loads(line))
    return entries, digest.hexdigest()


def _recovery_map(receipt_dir: Path, errors: list[str]) -> dict[str, str]:
    resolved: dict[str, str] = {}
    for summary_path in sorted(receipt_dir.glob("recovery_*_quarantine.json")):
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
        exact_path = receipt_dir / str(summary["exact_paths_file"])
        if phase2._sha256(exact_path) != str(summary["exact_paths_gzip_sha256"]):
            errors.append(f"recovery gzip hash mismatch: {exact_path}")
            continue
        entries, canonical_sha = _read_inventory(exact_path)
        if canonical_sha != str(summary["exact_paths_canonical_sha256"]):
            errors.append(f"recovery canonical hash mismatch: {exact_path}")
        for entry in entries:
            status = str(entry.get("status", ""))
            if status in {"RESTORED", "DRIFT_ARCHIVED"}:
                resolved[str(entry["quarantine"]).lower()] = status
    return resolved


def verify_directory(receipt_dir: Path) -> dict[str, object]:
    errors: list[str] = []
    warnings: list[str] = []
    counts: Counter[str] = Counter()
    bytes_: Counter[str] = Counter()
    recovery = _recovery_map(receipt_dir, errors)
    run_ids: set[str] = set()

    for receipt_path in sorted(receipt_dir.glob("batch_*.json")):
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        run_ids.add(str(receipt["run_id"]))
        if str(receipt.get("manifest_sha256", "")).lower() != EXPECTED_MANIFEST_SHA256:
            errors.append(f"manifest hash mismatch in {receipt_path.name}")
        exact_path = receipt_dir / str(receipt["exact_paths_file"])
        if not exact_path.is_file():
            errors.append(f"missing exact inventory: {exact_path}")
            continue
        if phase2._sha256(exact_path) != str(receipt["exact_paths_gzip_sha256"]):
            errors.append(f"gzip hash mismatch: {exact_path}")
            continue
        entries, canonical_sha = _read_inventory(exact_path)
        if canonical_sha != str(receipt["exact_paths_canonical_sha256"]):
            errors.append(f"canonical hash mismatch: {exact_path}")
        if len(entries) != int(receipt["requested_files"]):
            errors.append(
                f"entry count mismatch {receipt_path.name}: {len(entries)} != {receipt['requested_files']}"
            )
        action = str(receipt["action"])
        counts[f"batch:{action}"] += 1
        for entry in entries:
            status = str(entry.get("status", ""))
            counts[f"entry:{status}"] += 1
            bytes_[f"entry:{status}"] += int(entry.get("size", 0))
            source = Path(str(entry["source"]))
            if action == "NTFS_COMPRESS" and status == "COMPRESSED":
                if not source.is_file():
                    errors.append(f"compressed retained file missing: {source}")
                    continue
                try:
                    attributes = phase2._get_file_attributes(source)
                    current_size = source.stat().st_size
                except OSError as exc:
                    errors.append(f"compressed retained file unreadable: {source}: {exc}")
                    continue
                if not attributes & phase2.FILE_ATTRIBUTE_COMPRESSED:
                    errors.append(f"compressed attribute absent: {source}")
                if current_size != int(entry["size"]):
                    errors.append(f"compressed logical size drift: {source}")
            elif action == "DELETE_VIA_QUARANTINE":
                quarantine = Path(str(entry["quarantine"]))
                if status == "DELETED" and quarantine.exists():
                    errors.append(f"deleted quarantine still exists: {quarantine}")
                elif status.startswith("QUARANTINED"):
                    resolution = recovery.get(str(quarantine).lower())
                    if resolution:
                        counts[f"recovery:{resolution}"] += 1
                    elif quarantine.exists():
                        errors.append(f"unresolved recoverable quarantine: {quarantine}")
                    else:
                        errors.append(f"recoverable quarantine vanished without recovery receipt: {quarantine}")
                elif status.startswith("HELD") and not source.exists():
                    warnings.append(f"held source subsequently absent: {source}")
        if receipt_path.name.endswith("db_rotation.json") and receipt.get("fresh_db_quick_check") != "ok":
            errors.append(f"DB rotation lacks quick_check=ok: {receipt_path.name}")

    quarantine_files = 0
    for run_id in run_ids:
        for root in (
            Path(f"D:/QM/reports/maintenance/retention_quarantine_{run_id}"),
            Path(f"C:/QM/backups_relocated/retention_quarantine_{run_id}"),
        ):
            if root.is_dir():
                quarantine_files += sum(1 for path in root.rglob("*") if path.is_file())
    if quarantine_files:
        errors.append(f"run quarantine still contains {quarantine_files} file(s)")

    return {
        "receipt_dir": str(receipt_dir),
        "run_ids": sorted(run_ids),
        "counts": dict(sorted(counts.items())),
        "bytes": dict(sorted(bytes_.items())),
        "recovery_receipt_entries": len(recovery),
        "remaining_quarantine_files": quarantine_files,
        "errors": errors,
        "warnings": warnings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt-dir", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    results = [verify_directory(path.resolve()) for path in args.receipt_dir]
    payload = {
        "schema": "qm.backup-retention.phase2-verification.v1",
        "authority": "OWNER-DEC-BACKUP-RETENTION-20260830",
        "manifest_sha256": EXPECTED_MANIFEST_SHA256,
        "verified_at": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "results": results,
        "error_count": sum(len(result["errors"]) for result in results),
        "warning_count": sum(len(result["warnings"]) for result in results),
    }
    phase2._atomic_json(args.output, payload)
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 1 if payload["error_count"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
