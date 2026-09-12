#!/usr/bin/env python3
"""Default-OFF admission gate for the governed monthly DWX tick refresh.

This controller never downloads, imports, copies, or starts MetaTrader.  Its
only apply operation creates a hash-bound admission receipt after the factory
is quiescent and an OWNER-signed manifest update authenticates.  The runbook
uses that receipt as the boundary for the separately reviewed P1-P4 commands.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
from pathlib import Path
from typing import Any, Mapping


SCHEMA = "qm.dukascopy-monthly-refresh-approval/v1"
ADMISSION_SCHEMA = "qm.dukascopy-monthly-refresh-admission/v1"
ENABLE_ENV = "QM_DUKASCOPY_MONTHLY_REFRESH_ENABLED"
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
PROTECTED_PARTS = ("\\mt5\\t_live", "/mt5/t_live")


class RefreshError(RuntimeError):
    pass


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(payload: Mapping[str, Any], *, omit: str | None = None) -> bytes:
    body = {key: value for key, value in payload.items() if key != omit}
    return json.dumps(body, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def parse_time(value: Any, field: str) -> dt.datetime:
    text = str(value or "").replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError as exc:
        raise RefreshError(f"{field} is not ISO-8601") from exc
    if parsed.tzinfo is None:
        raise RefreshError(f"{field} lacks an offset")
    return parsed.astimezone(dt.timezone.utc)


def previous_month(day: dt.date) -> str:
    first = day.replace(day=1)
    prior = first - dt.timedelta(days=1)
    return prior.strftime("%Y-%m")


def _assert_safe_path(path: Path, label: str) -> None:
    normalized = str(path.resolve()).replace("/", "\\").casefold()
    if any(part.replace("/", "\\") in normalized for part in PROTECTED_PARTS):
        raise RefreshError(f"{label} may not reference T_Live")


def validate_approval(
    path: Path,
    *,
    refresh_month: str,
    factory_off_path: Path,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    try:
        approval = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RefreshError(f"approval unreadable: {exc}") from exc
    if not isinstance(approval, dict) or approval.get("schema_version") != SCHEMA:
        raise RefreshError("approval schema mismatch")
    required_text = (
        "decision_id",
        "owner_signature",
        "claude_review_task_id",
        "signed_at_utc",
        "window_start_utc",
        "window_end_utc",
        "factory_off_sha256",
        "p3_summary_path",
        "p3_summary_sha256",
        "manifest_update_path",
        "manifest_update_sha256",
        "approval_sha256",
    )
    if any(not str(approval.get(key) or "").strip() for key in required_text):
        raise RefreshError("approval has missing required fields")
    if not str(approval["decision_id"]).startswith("OWNER-DEC-"):
        raise RefreshError("approval decision is not OWNER-bound")
    if approval.get("claude_review_verdict") != "APPROVED":
        raise RefreshError("Claude review is not APPROVED")
    if approval.get("refresh_month") != refresh_month:
        raise RefreshError("approval refresh month mismatch")
    if approval.get("archive_write_authorized") is not True:
        raise RefreshError("archive write is not authorized")
    expected_self = hashlib.sha256(canonical_bytes(approval, omit="approval_sha256")).hexdigest()
    if str(approval["approval_sha256"]).lower() != expected_self:
        raise RefreshError("approval self-hash mismatch")

    current = (now or dt.datetime.now(dt.timezone.utc)).astimezone(dt.timezone.utc)
    start = parse_time(approval["window_start_utc"], "window_start_utc")
    end = parse_time(approval["window_end_utc"], "window_end_utc")
    signed = parse_time(approval["signed_at_utc"], "signed_at_utc")
    if not (signed <= current and start <= current <= end):
        raise RefreshError("OWNER write window is not open")

    if not factory_off_path.is_file():
        raise RefreshError("FACTORY_OFF.flag is missing")
    if sha256_file(factory_off_path) != str(approval["factory_off_sha256"]).lower():
        raise RefreshError("FACTORY_OFF.flag hash mismatch")

    for prefix in ("p3_summary", "manifest_update"):
        artifact = Path(str(approval[f"{prefix}_path"]))
        _assert_safe_path(artifact, prefix)
        expected = str(approval[f"{prefix}_sha256"]).lower()
        if not artifact.is_file() or not SHA_RE.fullmatch(expected):
            raise RefreshError(f"{prefix} artifact/hash missing")
        if sha256_file(artifact) != expected:
            raise RefreshError(f"{prefix} hash mismatch")

    p3 = json.loads(Path(str(approval["p3_summary_path"])).read_text(encoding="utf-8-sig"))
    if p3.get("status") != "PASS" or int(p3.get("pass_count", -1)) != 37:
        raise RefreshError("P3 is not a 37/37 PASS")
    manifest = json.loads(
        Path(str(approval["manifest_update_path"])).read_text(encoding="utf-8-sig")
    )
    if (
        manifest.get("archive_write_authorized") is not True
        or manifest.get("refresh_month") != refresh_month
        or manifest.get("target_year") != int(refresh_month[:4])
    ):
        raise RefreshError("manifest update does not authorize this month/year")
    return approval


def active_claim_count(database: Path) -> int:
    uri = Path(database).resolve().as_uri() + "?mode=ro"
    with sqlite3.connect(uri, uri=True, timeout=10) as conn:
        return int(
            conn.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]
        )


def acquire_year_lock(lock_path: Path, payload: Mapping[str, Any]) -> int:
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(str(lock_path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise RefreshError(f"archive-year lock is already held: {lock_path}") from exc
    os.write(descriptor, canonical_bytes(payload) + b"\n")
    os.fsync(descriptor)
    return descriptor


def release_year_lock(lock_path: Path, descriptor: int) -> None:
    os.close(descriptor)
    Path(lock_path).unlink(missing_ok=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--refresh-month")
    parser.add_argument("--owner-approval", type=Path)
    parser.add_argument("--farm-root", type=Path, default=Path(r"D:\QM\strategy_farm"))
    parser.add_argument("--output", type=Path)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    refresh_month = args.refresh_month or previous_month(dt.datetime.now().date())
    if not re.fullmatch(r"20\d{2}-(?:0[1-9]|1[0-2])", refresh_month):
        raise RefreshError("invalid refresh month")
    base = {
        "schema_version": ADMISSION_SCHEMA,
        "observed_at_utc": utc_now(),
        "refresh_month": refresh_month,
        "archive_year": int(refresh_month[:4]),
        "archive_write_performed": False,
        "t_live_touched": False,
    }
    if not args.apply:
        print(json.dumps({**base, "status": "DEFAULT_OFF", "enabled": False}, sort_keys=True))
        return 0
    if os.environ.get(ENABLE_ENV) != "1":
        raise RefreshError(f"{ENABLE_ENV}=1 is required for apply")
    if args.owner_approval is None or args.output is None:
        raise RefreshError("apply requires --owner-approval and --output")
    _assert_safe_path(args.output, "output")
    database = args.farm_root / "state" / "farm_state.sqlite"
    factory_off = args.farm_root / "state" / "FACTORY_OFF.flag"
    approval = validate_approval(
        args.owner_approval,
        refresh_month=refresh_month,
        factory_off_path=factory_off,
    )
    claims = active_claim_count(database)
    if claims:
        raise RefreshError(f"governed pause is not quiescent: {claims} active claims")
    lock_path = args.farm_root / "state" / f"dukascopy_archive_year_{refresh_month[:4]}.lock"
    descriptor = acquire_year_lock(lock_path, base)
    try:
        receipt = {
            **base,
            "status": "AUTHORIZED_HANDOFF",
            "enabled": True,
            "active_claim_count": claims,
            "approval_path": str(args.owner_approval.resolve()),
            "approval_sha256": str(approval["approval_sha256"]),
            "factory_off_sha256": str(approval["factory_off_sha256"]),
            "archive_year_lock": str(lock_path),
            "next_boundary": "reviewed P1-P4 runbook; revalidate approval and reacquire this lock at every archive writer",
        }
        receipt["receipt_sha256"] = hashlib.sha256(canonical_bytes(receipt)).hexdigest()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    finally:
        release_year_lock(lock_path, descriptor)
    print(json.dumps(receipt, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
