#!/usr/bin/env python3
"""Build and verify immutable, content-addressed Q09 tester calendars.

Live trading continues to use the native MQL5 calendar.  These bundles exist
only to make tester evidence reproducible.  Publishing is WhatIf-only unless
``--apply`` is supplied; an existing bundle is verified and reused, never
appended or overwritten.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import shutil
import tempfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

try:
    from q09_news_contract import canonical_json_bytes, sha256_bytes, sha256_file
except ModuleNotFoundError:
    from tools.strategy_farm.q09_news_contract import (
        canonical_json_bytes,
        sha256_bytes,
        sha256_file,
    )


MANIFEST_SCHEMA = "q09-news-calendar-bundle/v2"
PUBLICATION_REASONS = {"INITIAL", "HORIZON_EXTENSION", "APPROVED_CORRECTION"}


class CalendarBundleError(RuntimeError):
    """Raised when calendar provenance, coverage, or bytes are invalid."""


def _utc_text(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def _parse_utc(value: str, field: str) -> datetime:
    text = value.strip()
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    formats = ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M")
    parsed: datetime | None = None
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        for fmt in formats:
            try:
                parsed = datetime.strptime(text, fmt)
                break
            except ValueError:
                continue
    if parsed is None:
        raise CalendarBundleError(f"{field} is not a supported UTC timestamp: {value!r}")
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _find_column(fieldnames: Sequence[str], names: Sequence[str], role: str) -> str:
    normalized = {name.strip().lower(): name for name in fieldnames}
    for candidate in names:
        if candidate.lower() in normalized:
            return normalized[candidate.lower()]
    raise CalendarBundleError(f"calendar CSV has no {role} column; got {fieldnames!r}")


def canonicalize_events(source: Path) -> tuple[bytes, dict[str, Any]]:
    """Validate, de-duplicate, and deterministically order a calendar CSV."""

    if not source.is_file():
        raise CalendarBundleError(f"calendar source missing: {source}")
    raw = source.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        try:
            text = raw.decode("cp1252")
        except UnicodeDecodeError as exc:
            raise CalendarBundleError("calendar CSV is neither UTF-8 nor cp1252") from exc
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        raise CalendarBundleError("calendar CSV has no header")
    fieldnames = [field.strip() for field in reader.fieldnames]
    datetime_column = _find_column(
        fieldnames,
        ("datetime_utc", "datetime", "timestamp_utc", "event_utc", "date_time_utc"),
        "UTC datetime",
    )
    currency_column = _find_column(fieldnames, ("currency", "ccy"), "currency")
    impact_column = _find_column(fieldnames, ("impact", "importance"), "impact")
    event_column = _find_column(fieldnames, ("event", "event_name", "name", "title"), "event")
    canonical_rows: dict[tuple[str, str, str, str], dict[str, str]] = {}
    event_times: list[datetime] = []
    for index, input_row in enumerate(reader, start=2):
        row = {(key or "").strip(): (value or "").strip() for key, value in input_row.items()}
        timestamp = _parse_utc(row.get(datetime_column, ""), f"row {index} datetime")
        normalized_time = _utc_text(timestamp)
        currency = row.get(currency_column, "").upper()
        impact = row.get(impact_column, "").upper()
        event = row.get(event_column, "")
        if not currency or not impact or not event:
            raise CalendarBundleError(f"row {index} has empty currency, impact, or event")
        row[datetime_column] = normalized_time
        row[currency_column] = currency
        row[impact_column] = impact
        key = (normalized_time, currency, impact, event.casefold())
        existing = canonical_rows.get(key)
        if existing is not None and existing != row:
            raise CalendarBundleError(f"contradictory duplicate calendar event at row {index}: {key}")
        canonical_rows[key] = row
        event_times.append(timestamp)
    if not canonical_rows:
        raise CalendarBundleError("calendar CSV contains no events")
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fieldnames, lineterminator="\n", extrasaction="raise")
    writer.writeheader()
    for key in sorted(canonical_rows):
        writer.writerow({field: canonical_rows[key].get(field, "") for field in fieldnames})
    data = output.getvalue().encode("utf-8")
    return data, {
        "row_count": len(canonical_rows),
        "event_from_utc": _utc_text(min(event_times)),
        "event_to_utc": _utc_text(max(event_times)),
        "datetime_column": datetime_column,
        "currency_column": currency_column,
        "impact_column": impact_column,
        "event_column": event_column,
    }


def _load_approval_receipt(path: Path) -> tuple[dict[str, Any], bytes]:
    if not path.is_file():
        raise CalendarBundleError(f"approval/publisher receipt missing: {path}")
    data = path.read_bytes()
    try:
        receipt = json.loads(data.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CalendarBundleError("approval/publisher receipt must be valid UTF-8 JSON") from exc
    for field in ("approved_by", "approved_at", "reason"):
        if not isinstance(receipt.get(field), str) or not receipt[field].strip():
            raise CalendarBundleError(f"approval/publisher receipt missing {field}")
    _parse_utc(receipt["approved_at"], "receipt.approved_at")
    return receipt, data


def _load_parent_manifest(path: Path | None) -> Mapping[str, Any] | None:
    if path is None:
        return None
    try:
        parent = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CalendarBundleError(f"cannot read parent manifest: {exc}") from exc
    if parent.get("schema_version") != MANIFEST_SCHEMA:
        raise CalendarBundleError("parent manifest is not a Q09 v2 calendar bundle")
    return parent


def build_bundle_plan(
    *,
    source_csv: Path,
    receipt_path: Path,
    coverage_from_utc: str,
    coverage_to_utc: str,
    publication_reason: str,
    parent_manifest_path: Path | None = None,
) -> dict[str, Any]:
    reason = publication_reason.strip().upper()
    if reason not in PUBLICATION_REASONS:
        raise CalendarBundleError(f"publication_reason must be one of {sorted(PUBLICATION_REASONS)}")
    coverage_from = _parse_utc(coverage_from_utc, "coverage_from_utc")
    coverage_to = _parse_utc(coverage_to_utc, "coverage_to_utc")
    if coverage_from >= coverage_to:
        raise CalendarBundleError("coverage_from_utc must precede coverage_to_utc")
    events_data, event_meta = canonicalize_events(source_csv)
    receipt, receipt_data = _load_approval_receipt(receipt_path)
    parent = _load_parent_manifest(parent_manifest_path)
    if reason == "INITIAL" and parent is not None:
        raise CalendarBundleError("INITIAL publication cannot have a parent bundle")
    if reason != "INITIAL" and parent is None:
        raise CalendarBundleError(f"{reason} requires --parent-manifest")
    if parent is not None:
        parent_to = _parse_utc(str(parent["coverage_to_utc"]), "parent.coverage_to_utc")
        parent_from = _parse_utc(str(parent["coverage_from_utc"]), "parent.coverage_from_utc")
        if reason == "HORIZON_EXTENSION" and not (coverage_from <= parent_from and coverage_to > parent_to):
            raise CalendarBundleError("HORIZON_EXTENSION must retain the start and extend coverage_to_utc")
        if reason == "APPROVED_CORRECTION" and not receipt.get("correction_reason"):
            raise CalendarBundleError("APPROVED_CORRECTION receipt requires correction_reason")
    content_hash = sha256_bytes(events_data)
    identity_material = {
        "content_sha256": content_hash,
        "coverage_from_utc": _utc_text(coverage_from),
        "coverage_to_utc": _utc_text(coverage_to),
        "publication_reason": reason,
        "parent_bundle_id": parent.get("bundle_id") if parent else None,
        "publisher_evidence_sha256": sha256_bytes(receipt_data),
    }
    bundle_identity_hash = sha256_bytes(canonical_json_bytes(identity_material))
    bundle_id = f"q09cal-{coverage_from:%Y%m%d}-{coverage_to:%Y%m%d}-{bundle_identity_hash[:16]}"
    manifest: dict[str, Any] = {
        "schema_version": MANIFEST_SCHEMA,
        "bundle_id": bundle_id,
        "bundle_identity_sha256": bundle_identity_hash,
        "content_sha256": content_hash,
        "coverage_from_utc": _utc_text(coverage_from),
        "coverage_to_utc": _utc_text(coverage_to),
        "event_from_utc": event_meta["event_from_utc"],
        "event_to_utc": event_meta["event_to_utc"],
        "row_count": event_meta["row_count"],
        "publication_reason": reason,
        "parent_bundle_id": parent.get("bundle_id") if parent else None,
        "publisher_evidence_path": "publisher_receipt.json",
        "publisher_evidence_sha256": sha256_bytes(receipt_data),
        "approved_by": receipt["approved_by"],
        "approved_at": receipt["approved_at"],
        "correction_reason": receipt.get("correction_reason"),
        "files": [
            {
                "role": "EVENTS",
                "relative_path": "events.csv",
                "sha256": content_hash,
                "size_bytes": len(events_data),
                "row_count": event_meta["row_count"],
                "event_from_utc": event_meta["event_from_utc"],
                "event_to_utc": event_meta["event_to_utc"],
            },
            {
                "role": "PUBLISHER_RECEIPT",
                "relative_path": "publisher_receipt.json",
                "sha256": sha256_bytes(receipt_data),
                "size_bytes": len(receipt_data),
                "row_count": 0,
                "event_from_utc": None,
                "event_to_utc": None,
            },
        ],
    }
    return {
        "manifest": manifest,
        "events_data": events_data,
        "receipt_data": receipt_data,
        "bundle_id": bundle_id,
    }


def _safe_bundle_file(bundle_dir: Path, relative: str) -> Path:
    pure = PurePosixPath(relative.replace("\\", "/"))
    if pure.is_absolute() or ".." in pure.parts or ":" in relative:
        raise CalendarBundleError(f"unsafe bundle relative path: {relative!r}")
    candidate = (bundle_dir / Path(*pure.parts)).resolve()
    try:
        candidate.relative_to(bundle_dir.resolve())
    except ValueError as exc:
        raise CalendarBundleError(f"bundle path escapes root: {relative!r}") from exc
    return candidate


def verify_bundle(bundle_dir: Path) -> dict[str, Any]:
    bundle_dir = bundle_dir.resolve()
    manifest_path = bundle_dir / "manifest.json"
    if not manifest_path.is_file():
        raise CalendarBundleError(f"bundle manifest missing: {manifest_path}")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CalendarBundleError(f"bundle manifest invalid: {exc}") from exc
    if manifest.get("schema_version") != MANIFEST_SCHEMA:
        raise CalendarBundleError("unsupported calendar bundle schema")
    if manifest.get("bundle_id") != bundle_dir.name:
        raise CalendarBundleError("bundle directory name does not match bundle_id")
    files = manifest.get("files")
    if not isinstance(files, list) or not files:
        raise CalendarBundleError("bundle file manifest is empty")
    for item in files:
        path = _safe_bundle_file(bundle_dir, str(item["relative_path"]))
        if not path.is_file():
            raise CalendarBundleError(f"bundle file missing: {item['relative_path']}")
        if path.stat().st_size != int(item["size_bytes"]):
            raise CalendarBundleError(f"bundle file size mismatch: {item['relative_path']}")
        if sha256_file(path) != item["sha256"]:
            raise CalendarBundleError(f"bundle file SHA-256 mismatch: {item['relative_path']}")
    events = next((item for item in files if item.get("role") == "EVENTS"), None)
    if events is None or events["sha256"] != manifest.get("content_sha256"):
        raise CalendarBundleError("EVENTS file is not the manifest content identity")
    canonical_events, event_meta = canonicalize_events(_safe_bundle_file(bundle_dir, events["relative_path"]))
    if sha256_bytes(canonical_events) != manifest.get("content_sha256"):
        raise CalendarBundleError("EVENTS file is not canonical")
    for field in ("row_count", "event_from_utc", "event_to_utc"):
        if event_meta[field] != manifest.get(field):
            raise CalendarBundleError(f"calendar manifest {field} contradicts EVENTS bytes")
    coverage_from = _parse_utc(manifest["coverage_from_utc"], "coverage_from")
    coverage_to = _parse_utc(manifest["coverage_to_utc"], "coverage_to")
    if coverage_from >= coverage_to:
        raise CalendarBundleError("calendar coverage interval is invalid")
    if (
        _parse_utc(manifest["event_from_utc"], "event_from") < coverage_from
        or _parse_utc(manifest["event_to_utc"], "event_to") > coverage_to
    ):
        raise CalendarBundleError("calendar events fall outside claimed coverage")
    identity_material = {
        "content_sha256": manifest["content_sha256"],
        "coverage_from_utc": manifest["coverage_from_utc"],
        "coverage_to_utc": manifest["coverage_to_utc"],
        "publication_reason": manifest["publication_reason"],
        "parent_bundle_id": manifest.get("parent_bundle_id"),
        "publisher_evidence_sha256": manifest["publisher_evidence_sha256"],
    }
    identity_hash = sha256_bytes(canonical_json_bytes(identity_material))
    if manifest.get("bundle_identity_sha256") != identity_hash:
        raise CalendarBundleError("bundle identity SHA-256 mismatch")
    expected_id = (
        f"q09cal-{coverage_from:%Y%m%d}-{coverage_to:%Y%m%d}-{identity_hash[:16]}"
    )
    if expected_id != manifest["bundle_id"]:
        raise CalendarBundleError("bundle_id is not derived from coverage/content")
    return {
        **manifest,
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_file(manifest_path),
        "verified": True,
    }


def publish_bundle(plan: Mapping[str, Any], bundle_root: Path) -> dict[str, Any]:
    bundle_root = bundle_root.resolve()
    bundle_root.mkdir(parents=True, exist_ok=True)
    destination = bundle_root / str(plan["bundle_id"])
    if destination.exists():
        verified = verify_bundle(destination)
        expected_manifest = plan["manifest"]
        if any(verified.get(key) != expected_manifest.get(key) for key in expected_manifest):
            raise CalendarBundleError("existing content-addressed bundle contradicts publication plan")
        return {**verified, "publication_status": "ALREADY_PRESENT"}
    staging_root = Path(tempfile.mkdtemp(prefix=f".{plan['bundle_id']}.", dir=str(bundle_root)))
    staging = staging_root / str(plan["bundle_id"])
    try:
        staging.mkdir()
        (staging / "events.csv").write_bytes(plan["events_data"])
        (staging / "publisher_receipt.json").write_bytes(plan["receipt_data"])
        (staging / "manifest.json").write_bytes(canonical_json_bytes(plan["manifest"]))
        verify_bundle(staging)
        try:
            staging.rename(destination)
        except FileExistsError:
            verify_bundle(destination)
        shutil.rmtree(staging_root, ignore_errors=True)
        for path in destination.iterdir():
            if path.is_file():
                path.chmod(0o444)
        destination.chmod(0o555)
    except BaseException:
        if staging_root.exists():
            shutil.rmtree(staging_root, ignore_errors=True)
        raise
    return {**verify_bundle(destination), "publication_status": "PUBLISHED"}


def provision_to_common(bundle_dir: Path, common_root: Path, relative_path: str) -> dict[str, Any]:
    """Copy immutable EVENTS bytes to a content-addressed tester path."""

    verified = verify_bundle(bundle_dir)
    relative = PurePosixPath(relative_path.replace("\\", "/"))
    if relative.is_absolute() or ".." in relative.parts or ":" in relative_path:
        raise CalendarBundleError("Common path must be safe and relative")
    destination = (common_root.resolve() / Path(*relative.parts)).resolve()
    try:
        destination.relative_to(common_root.resolve())
    except ValueError as exc:
        raise CalendarBundleError("Common path escapes its root") from exc
    expected = str(verified["content_sha256"])
    if destination.exists():
        if not destination.is_file() or sha256_file(destination) != expected:
            raise CalendarBundleError("existing Common file contradicts immutable calendar content")
        return {"status": "ALREADY_PRESENT", "path": str(destination), "sha256": expected}
    destination.parent.mkdir(parents=True, exist_ok=True)
    events = bundle_dir.resolve() / "events.csv"
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    shutil.copyfile(events, temporary)
    if sha256_file(temporary) != expected:
        temporary.unlink(missing_ok=True)
        raise CalendarBundleError("provisioned Common file failed SHA-256 verification")
    temporary.replace(destination)
    destination.chmod(0o444)
    return {"status": "PROVISIONED", "path": str(destination), "sha256": expected}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("plan", "publish"):
        command = sub.add_parser(name)
        command.add_argument("--source-csv", required=True, type=Path)
        command.add_argument("--receipt", required=True, type=Path)
        command.add_argument("--coverage-from-utc", required=True)
        command.add_argument("--coverage-to-utc", required=True)
        command.add_argument("--publication-reason", required=True, choices=sorted(PUBLICATION_REASONS))
        command.add_argument("--parent-manifest", type=Path)
        if name == "publish":
            command.add_argument("--bundle-root", required=True, type=Path)
            command.add_argument("--apply", action="store_true")
    verify = sub.add_parser("verify")
    verify.add_argument("--bundle", required=True, type=Path)
    provision = sub.add_parser("provision")
    provision.add_argument("--bundle", required=True, type=Path)
    provision.add_argument("--common-root", required=True, type=Path)
    provision.add_argument("--relative-path", required=True)
    provision.add_argument("--apply", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.command in {"plan", "publish"}:
        plan = build_bundle_plan(
            source_csv=args.source_csv,
            receipt_path=args.receipt,
            coverage_from_utc=args.coverage_from_utc,
            coverage_to_utc=args.coverage_to_utc,
            publication_reason=args.publication_reason,
            parent_manifest_path=args.parent_manifest,
        )
        safe_plan = {key: value for key, value in plan.items() if not key.endswith("_data")}
        if args.command == "plan" or not args.apply:
            print(json.dumps({"mode": "WhatIf", **safe_plan}, indent=2, sort_keys=True))
            return 0
        result = publish_bundle(plan, args.bundle_root)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    if args.command == "verify":
        print(json.dumps(verify_bundle(args.bundle), indent=2, sort_keys=True))
        return 0
    if not args.apply:
        print(json.dumps({"mode": "WhatIf", "would_provision": True}, indent=2))
        return 0
    result = provision_to_common(args.bundle, args.common_root, args.relative_path)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
