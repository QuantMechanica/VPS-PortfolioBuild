"""Fail-closed MT5 news-calendar preflight and atomic pair publisher.

The preflight is deliberately read-only: it never creates directories, touches
files, writes logs, or opens the farm database.  It validates the two calendar
files used by ``QM_NewsFilter`` for the executing Windows principal and keeps
the legacy ``run_smoke.ps1`` status taxonomy.

Publishing is a separate, explicit mutation path.  It is guarded by the exact
SHA-256 of an existing ``FACTORY_OFF.flag`` and the shared factory mutation
lock.  Each publication first creates immutable version directories, then
atomically replaces the active files, with the manifest replaced last.  A
reader can therefore see an old bundle or a fail-closed mixed-bundle diagnosis,
but never accepts a partially published pair.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import getpass
import hashlib
import io
import json
import os
import re
import threading
import uuid
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

try:
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ModuleNotFoundError:  # package import (``tools.strategy_farm``)
    from tools.strategy_farm.factory_mutation_lock import (
        FactoryMutationLock,
        path_for_factory_flag,
    )


PRIMARY_NAME = "news_calendar_2015_2025.csv"
SECONDARY_NAME = "forex_factory_calendar_clean.csv"
CALENDAR_NAMES = (PRIMARY_NAME, SECONDARY_NAME)
ACTIVE_MANIFEST_NAME = "news_calendar_bundle_manifest.json"
BUNDLE_DIRECTORY_NAME = ".news_calendar_bundles"
MAX_AGE_HOURS = 24 * 14
MANIFEST_SCHEMA = "qm-news-calendar-pair/v1"
PLAN_SCHEMA = "qm-news-calendar-publication-plan/v1"
DEFAULT_SOURCE_DIR = Path(r"D:\QM\data\news_calendar")

STATUS_OK = "OK"
STATUS_MISSING_SOURCE = "MISSING_SOURCE"
STATUS_MISSING_COMMON = "MISSING_COMMON"
STATUS_STALE_COMMON = "STALE_COMMON"
STATUS_COMMON_MISMATCH = "COMMON_MISMATCH"
STATUS_PARSE_INVALID = "PARSE_INVALID"

_BUNDLE_ID_RE = re.compile(r"^news-calendar-[0-9a-f]{64}$")
_CACHE_LOCK = threading.Lock()
_PREFLIGHT_CACHE: dict[
    tuple[str, str, str, int], tuple[tuple[Any, ...], "CalendarPreflightResult"]
] = {}


class NewsCalendarError(RuntimeError):
    """Base exception for invalid calendars and unsafe publications."""


class CalendarParseError(NewsCalendarError):
    """A calendar or manifest cannot satisfy the deterministic contract."""


class InjectedPublishFailure(NewsCalendarError):
    """Deterministic fault used only by interrupted-publication tests."""


@dataclass(frozen=True)
class CalendarPreflightResult:
    status: str
    principal: str
    source_dir: str
    common_dir: str
    primary_path: str
    secondary_path: str
    checked_at: str
    missing_source_paths: tuple[str, ...] = ()
    missing_common_paths: tuple[str, ...] = ()
    mismatches: tuple[dict[str, Any], ...] = ()
    latest_modified_utc: str | None = None
    age_hours: float | None = None
    max_age_hours: int = MAX_AGE_HOURS
    parse_invalid_path: str | None = None
    detail: str | None = None
    bundle_id: str | None = None
    bundle_identity_sha256: str | None = None
    manifest_sha256: str | None = None
    legacy_flat_files: bool = False
    cache_hit: bool = False

    @property
    def ok(self) -> bool:
        return self.status == STATUS_OK

    def as_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["ok"] = self.ok
        # JSON callers historically expose arrays, not tuple implementation details.
        payload["missing_source_paths"] = list(self.missing_source_paths)
        payload["missing_common_paths"] = list(self.missing_common_paths)
        payload["mismatches"] = list(self.mismatches)
        return payload


@dataclass(frozen=True)
class _ParsedCalendar:
    name: str
    sha256: str
    size_bytes: int
    row_count: int
    first_event_utc: str
    last_event_utc: str
    raw: bytes

    def manifest_entry(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "sha256": self.sha256,
            "size_bytes": self.size_bytes,
            "row_count": self.row_count,
            "first_event_utc": self.first_event_utc,
            "last_event_utc": self.last_event_utc,
        }


def _canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _utc_now() -> dt.datetime:
    return dt.datetime.now(dt.UTC)


def _as_utc(value: dt.datetime | str | None) -> dt.datetime:
    if value is None:
        return _utc_now()
    if isinstance(value, str):
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    else:
        parsed = value
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def _iso_utc(value: dt.datetime) -> str:
    return value.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")


def executing_principal() -> str:
    domain = str(os.environ.get("USERDOMAIN") or "").strip()
    user = str(os.environ.get("USERNAME") or os.environ.get("USER") or "").strip()
    if not user:
        try:
            user = getpass.getuser().strip()
        except Exception:
            user = "<unknown>"
    return f"{domain}\\{user}" if domain else user


def resolve_source_dir(source_dir: Path | str | None = None) -> Path:
    if source_dir is not None:
        return Path(source_dir)
    override = str(os.environ.get("QM_NEWS_CALENDAR_SOURCE_DIR") or "").strip()
    return Path(override) if override else DEFAULT_SOURCE_DIR


def resolve_common_dir(common_dir: Path | str | None = None) -> Path:
    if common_dir is not None:
        return Path(common_dir)
    override = str(os.environ.get("QM_NEWS_CALENDAR_COMMON_DIR") or "").strip()
    if override:
        return Path(override)
    appdata = str(os.environ.get("APPDATA") or "").strip()
    if not appdata:
        # The sentinel deliberately cannot resolve to a valid principal Common
        # directory.  The caller receives MISSING_COMMON with the diagnostic path.
        return Path("<APPDATA_UNSET>") / "MetaQuotes" / "Terminal" / "Common" / "Files"
    return Path(appdata) / "MetaQuotes" / "Terminal" / "Common" / "Files"


def _parse_event_time(value: str, formats: Sequence[str], path: Path, row_number: int) -> dt.datetime:
    candidate = str(value or "").strip()
    for fmt in formats:
        try:
            return dt.datetime.strptime(candidate, fmt).replace(tzinfo=dt.UTC)
        except ValueError:
            continue
    raise CalendarParseError(
        f"{path}: row {row_number} has invalid event time {candidate!r}"
    )


def _parse_calendar_bytes(name: str, raw: bytes, *, path: Path) -> _ParsedCalendar:
    if not raw:
        raise CalendarParseError(f"{path}: empty calendar")
    if b"\x00" in raw:
        raise CalendarParseError(f"{path}: NUL byte in CSV")
    try:
        text = raw.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        raise CalendarParseError(f"{path}: CSV is not UTF-8: {exc}") from exc

    if name == PRIMARY_NAME:
        required = ("datetime", "currency", "event_name", "impact")
        time_column = "datetime"
        event_column = "event_name"
        time_formats = ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M")
    elif name == SECONDARY_NAME:
        required = ("DateTime_UTC", "Currency", "Impact", "Event")
        time_column = "DateTime_UTC"
        event_column = "Event"
        time_formats = ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M")
    else:
        raise CalendarParseError(f"unsupported calendar filename: {name}")

    try:
        reader = csv.DictReader(io.StringIO(text, newline=""), strict=True)
        headers = list(reader.fieldnames or [])
        if not headers:
            raise CalendarParseError(f"{path}: missing CSV header")
        if len(set(headers)) != len(headers):
            raise CalendarParseError(f"{path}: duplicate CSV header")
        missing_headers = [field for field in required if field not in headers]
        if missing_headers:
            raise CalendarParseError(
                f"{path}: missing required columns {','.join(missing_headers)}"
            )

        row_count = 0
        first_event: dt.datetime | None = None
        last_event: dt.datetime | None = None
        for row_number, row in enumerate(reader, start=2):
            if None in row:
                raise CalendarParseError(f"{path}: row {row_number} has extra columns")
            if any(value is None for value in row.values()):
                raise CalendarParseError(f"{path}: row {row_number} has missing columns")
            currency_key = "currency" if name == PRIMARY_NAME else "Currency"
            impact_key = "impact" if name == PRIMARY_NAME else "Impact"
            for field in (currency_key, impact_key, event_column):
                if not str(row.get(field) or "").strip():
                    raise CalendarParseError(
                        f"{path}: row {row_number} has empty required field {field}"
                    )
            event_time = _parse_event_time(
                str(row.get(time_column) or ""), time_formats, path, row_number
            )
            first_event = event_time if first_event is None else min(first_event, event_time)
            last_event = event_time if last_event is None else max(last_event, event_time)
            row_count += 1
    except csv.Error as exc:
        raise CalendarParseError(f"{path}: malformed CSV: {exc}") from exc

    if row_count == 0 or first_event is None or last_event is None:
        raise CalendarParseError(f"{path}: calendar has no event rows")
    return _ParsedCalendar(
        name=name,
        sha256=_sha256_bytes(raw),
        size_bytes=len(raw),
        row_count=row_count,
        first_event_utc=_iso_utc(first_event),
        last_event_utc=_iso_utc(last_event),
        raw=raw,
    )


def _parse_calendar_file(path: Path, name: str) -> _ParsedCalendar:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise CalendarParseError(f"{path}: cannot read calendar: {exc}") from exc
    return _parse_calendar_bytes(name, raw, path=path)


def _manifest_without_hash(manifest: Mapping[str, Any]) -> dict[str, Any]:
    value = dict(manifest)
    value.pop("manifest_sha256", None)
    return value


def _validate_manifest(manifest: Any, *, path: Path) -> dict[str, Any]:
    if not isinstance(manifest, dict):
        raise CalendarParseError(f"{path}: manifest must be a JSON object")
    required = {
        "schema",
        "bundle_id",
        "bundle_identity_sha256",
        "generated_at",
        "files",
        "manifest_sha256",
    }
    missing = sorted(required - set(manifest))
    if missing:
        raise CalendarParseError(f"{path}: missing manifest fields {','.join(missing)}")
    if manifest.get("schema") != MANIFEST_SCHEMA:
        raise CalendarParseError(f"{path}: unsupported manifest schema")
    bundle_id = str(manifest.get("bundle_id") or "")
    if not _BUNDLE_ID_RE.fullmatch(bundle_id):
        raise CalendarParseError(f"{path}: invalid bundle_id")
    try:
        generated_at = _as_utc(str(manifest.get("generated_at")))
    except (TypeError, ValueError) as exc:
        raise CalendarParseError(f"{path}: invalid generated_at") from exc
    if _iso_utc(generated_at) != str(manifest.get("generated_at")):
        raise CalendarParseError(f"{path}: generated_at is not canonical UTC")

    files = manifest.get("files")
    if not isinstance(files, list) or len(files) != len(CALENDAR_NAMES):
        raise CalendarParseError(f"{path}: manifest must bind exactly two files")
    names = [str(entry.get("name") or "") for entry in files if isinstance(entry, dict)]
    if names != list(CALENDAR_NAMES):
        raise CalendarParseError(f"{path}: manifest file order/names are invalid")
    for entry in files:
        if not isinstance(entry, dict):
            raise CalendarParseError(f"{path}: invalid file entry")
        expected_keys = {
            "name",
            "sha256",
            "size_bytes",
            "row_count",
            "first_event_utc",
            "last_event_utc",
        }
        if set(entry) != expected_keys:
            raise CalendarParseError(f"{path}: invalid file-entry fields")
        sha = str(entry.get("sha256") or "")
        if not re.fullmatch(r"[0-9a-f]{64}", sha):
            raise CalendarParseError(f"{path}: invalid file SHA-256")
        try:
            size_bytes = int(entry.get("size_bytes") or 0)
            row_count = int(entry.get("row_count") or 0)
        except (TypeError, ValueError) as exc:
            raise CalendarParseError(f"{path}: invalid file size/row count") from exc
        if size_bytes <= 0 or row_count <= 0:
            raise CalendarParseError(f"{path}: invalid file size/row count")
        try:
            _as_utc(str(entry.get("first_event_utc")))
            _as_utc(str(entry.get("last_event_utc")))
        except (TypeError, ValueError) as exc:
            raise CalendarParseError(f"{path}: invalid event coverage") from exc

    identity = {
        "schema": manifest["schema"],
        "generated_at": manifest["generated_at"],
        "files": manifest["files"],
    }
    identity_sha = _sha256_bytes(_canonical_json_bytes(identity))
    if str(manifest.get("bundle_identity_sha256")) != identity_sha:
        raise CalendarParseError(f"{path}: bundle identity SHA-256 mismatch")
    if bundle_id != f"news-calendar-{identity_sha}":
        raise CalendarParseError(f"{path}: bundle_id is not identity-addressed")
    actual_manifest_sha = _sha256_bytes(_canonical_json_bytes(_manifest_without_hash(manifest)))
    if str(manifest.get("manifest_sha256")) != actual_manifest_sha:
        raise CalendarParseError(f"{path}: manifest SHA-256 mismatch")
    return dict(manifest)


def _load_manifest(path: Path) -> tuple[dict[str, Any], bytes]:
    try:
        raw = path.read_bytes()
        parsed = json.loads(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CalendarParseError(f"{path}: invalid manifest: {exc}") from exc
    return _validate_manifest(parsed, path=path), raw


def _stat_signature(paths: Iterable[Path]) -> tuple[Any, ...]:
    signature: list[Any] = []
    for path in paths:
        try:
            stat = path.stat()
            signature.append((str(path), True, stat.st_size, stat.st_mtime_ns, stat.st_ino))
        except OSError:
            signature.append((str(path), False, None, None, None))
    return tuple(signature)


def clear_preflight_cache() -> None:
    with _CACHE_LOCK:
        _PREFLIGHT_CACHE.clear()


def _preflight_result(
    status: str,
    *,
    principal: str,
    source_dir: Path,
    common_dir: Path,
    checked_at: dt.datetime,
    **kwargs: Any,
) -> CalendarPreflightResult:
    return CalendarPreflightResult(
        status=status,
        principal=principal,
        source_dir=str(source_dir),
        common_dir=str(common_dir),
        primary_path=str(common_dir / PRIMARY_NAME),
        secondary_path=str(common_dir / SECONDARY_NAME),
        checked_at=_iso_utc(checked_at),
        **kwargs,
    )


def _manifest_file_map(manifest: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    return {str(entry["name"]): entry for entry in manifest["files"]}


def _verify_manifest_material(
    manifest: Mapping[str, Any],
    parsed: Mapping[str, _ParsedCalendar],
    *,
    path: Path,
) -> None:
    entries = _manifest_file_map(manifest)
    for name in CALENDAR_NAMES:
        actual = parsed[name].manifest_entry()
        if dict(entries[name]) != actual:
            raise CalendarParseError(f"{path}: manifest does not match active {name}")


def _verify_immutable_bundle(root: Path, manifest: Mapping[str, Any]) -> None:
    bundle_dir = root / BUNDLE_DIRECTORY_NAME / str(manifest["bundle_id"])
    manifest_path = bundle_dir / ACTIVE_MANIFEST_NAME
    loaded, raw = _load_manifest(manifest_path)
    if loaded != dict(manifest):
        raise CalendarParseError(f"{manifest_path}: immutable manifest differs from active manifest")
    expected_manifest_raw = _canonical_json_bytes(manifest) + b"\n"
    if raw != expected_manifest_raw:
        raise CalendarParseError(f"{manifest_path}: immutable manifest bytes are not canonical")
    parsed: dict[str, _ParsedCalendar] = {}
    for name in CALENDAR_NAMES:
        parsed[name] = _parse_calendar_file(bundle_dir / name, name)
    _verify_manifest_material(manifest, parsed, path=manifest_path)


def _full_preflight(
    source_dir: Path,
    common_dir: Path,
    *,
    principal: str,
    checked_at: dt.datetime,
    max_age_hours: int,
) -> CalendarPreflightResult:
    source_paths = {name: source_dir / name for name in CALENDAR_NAMES}
    common_paths = {name: common_dir / name for name in CALENDAR_NAMES}
    missing_source = tuple(str(path) for path in source_paths.values() if not path.is_file())
    if missing_source:
        return _preflight_result(
            STATUS_MISSING_SOURCE,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            missing_source_paths=missing_source,
        )
    missing_common = tuple(str(path) for path in common_paths.values() if not path.is_file())
    if missing_common:
        return _preflight_result(
            STATUS_MISSING_COMMON,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            missing_common_paths=missing_common,
        )

    source_manifest_path = source_dir / ACTIVE_MANIFEST_NAME
    common_manifest_path = common_dir / ACTIVE_MANIFEST_NAME
    source_manifest_exists = source_manifest_path.is_file()
    common_manifest_exists = common_manifest_path.is_file()
    if source_manifest_exists and not common_manifest_exists:
        return _preflight_result(
            STATUS_MISSING_COMMON,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            missing_common_paths=(str(common_manifest_path),),
            detail="source bundle manifest exists but Common manifest is missing",
        )
    if common_manifest_exists and not source_manifest_exists:
        return _preflight_result(
            STATUS_MISSING_SOURCE,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            missing_source_paths=(str(source_manifest_path),),
            detail="Common bundle manifest exists but source manifest is missing",
        )

    parsed_source: dict[str, _ParsedCalendar] = {}
    parsed_common: dict[str, _ParsedCalendar] = {}
    try:
        for name in CALENDAR_NAMES:
            parsed_source[name] = _parse_calendar_file(source_paths[name], name)
            parsed_common[name] = _parse_calendar_file(common_paths[name], name)
    except CalendarParseError as exc:
        message = str(exc)
        invalid_path = message.split(": ", 1)[0]
        return _preflight_result(
            STATUS_PARSE_INVALID,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            parse_invalid_path=invalid_path,
            detail=message,
        )

    mismatches: list[dict[str, Any]] = []
    for name in CALENDAR_NAMES:
        source_file = parsed_source[name]
        common_file = parsed_common[name]
        if source_file.sha256 != common_file.sha256:
            mismatches.append(
                {
                    "name": name,
                    "source_sha256": source_file.sha256,
                    "common_sha256": common_file.sha256,
                }
            )
    if mismatches:
        return _preflight_result(
            STATUS_COMMON_MISMATCH,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            mismatches=tuple(mismatches),
        )

    manifest: dict[str, Any] | None = None
    if source_manifest_exists and common_manifest_exists:
        try:
            source_manifest, source_manifest_raw = _load_manifest(source_manifest_path)
            common_manifest, common_manifest_raw = _load_manifest(common_manifest_path)
            if source_manifest_raw != common_manifest_raw or source_manifest != common_manifest:
                return _preflight_result(
                    STATUS_COMMON_MISMATCH,
                    principal=principal,
                    source_dir=source_dir,
                    common_dir=common_dir,
                    checked_at=checked_at,
                    max_age_hours=max_age_hours,
                    mismatches=(
                        {
                            "name": ACTIVE_MANIFEST_NAME,
                            "source_sha256": _sha256_bytes(source_manifest_raw),
                            "common_sha256": _sha256_bytes(common_manifest_raw),
                        },
                    ),
                )
            manifest = source_manifest
            _verify_manifest_material(manifest, parsed_source, path=source_manifest_path)
            _verify_manifest_material(manifest, parsed_common, path=common_manifest_path)
            _verify_immutable_bundle(source_dir, manifest)
            _verify_immutable_bundle(common_dir, manifest)
        except CalendarParseError as exc:
            message = str(exc)
            return _preflight_result(
                STATUS_PARSE_INVALID,
                principal=principal,
                source_dir=source_dir,
                common_dir=common_dir,
                checked_at=checked_at,
                max_age_hours=max_age_hours,
                parse_invalid_path=message.split(": ", 1)[0],
                detail=message,
            )

    try:
        oldest_common = min(path.stat().st_mtime for path in common_paths.values())
    except OSError as exc:
        return _preflight_result(
            STATUS_MISSING_COMMON,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            max_age_hours=max_age_hours,
            missing_common_paths=tuple(str(path) for path in common_paths.values()),
            detail=f"Common calendar stat failed: {exc}",
        )
    latest_modified = dt.datetime.fromtimestamp(oldest_common, tz=dt.UTC)
    age_hours = max(0.0, (checked_at - latest_modified).total_seconds() / 3600.0)
    common_kwargs = {
        "latest_modified_utc": _iso_utc(latest_modified),
        "age_hours": round(age_hours, 6),
        "max_age_hours": max_age_hours,
        "bundle_id": str(manifest["bundle_id"]) if manifest else None,
        "bundle_identity_sha256": (
            str(manifest["bundle_identity_sha256"]) if manifest else None
        ),
        "manifest_sha256": str(manifest["manifest_sha256"]) if manifest else None,
        "legacy_flat_files": manifest is None,
    }
    if age_hours > max_age_hours:
        return _preflight_result(
            STATUS_STALE_COMMON,
            principal=principal,
            source_dir=source_dir,
            common_dir=common_dir,
            checked_at=checked_at,
            **common_kwargs,
        )
    return _preflight_result(
        STATUS_OK,
        principal=principal,
        source_dir=source_dir,
        common_dir=common_dir,
        checked_at=checked_at,
        **common_kwargs,
    )


def preflight_news_calendar(
    source_dir: Path | str | None = None,
    common_dir: Path | str | None = None,
    *,
    now: dt.datetime | str | None = None,
    max_age_hours: int = MAX_AGE_HOURS,
    use_cache: bool = True,
) -> CalendarPreflightResult:
    """Validate the executing principal's source/Common calendar pair read-only."""
    if int(max_age_hours) <= 0 or int(max_age_hours) > MAX_AGE_HOURS:
        raise ValueError(f"max_age_hours must be in 1..{MAX_AGE_HOURS}")
    source = resolve_source_dir(source_dir)
    common = resolve_common_dir(common_dir)
    principal = executing_principal()
    checked_at = _as_utc(now)
    paths = [
        *(source / name for name in CALENDAR_NAMES),
        source / ACTIVE_MANIFEST_NAME,
        *(common / name for name in CALENDAR_NAMES),
        common / ACTIVE_MANIFEST_NAME,
    ]
    cache_key = (str(source), str(common), principal, int(max_age_hours))
    signature = _stat_signature(paths)
    # Explicit historical times are test/replay inputs and must never reuse a
    # wall-clock cache entry.
    cache_allowed = use_cache and now is None
    if cache_allowed:
        with _CACHE_LOCK:
            cached = _PREFLIGHT_CACHE.get(cache_key)
        if cached and cached[0] == signature:
            result = cached[1]
            if result.latest_modified_utc:
                modified = _as_utc(result.latest_modified_utc)
                age = max(0.0, (checked_at - modified).total_seconds() / 3600.0)
                if result.status == STATUS_OK and age > max_age_hours:
                    result = replace(
                        result,
                        status=STATUS_STALE_COMMON,
                        checked_at=_iso_utc(checked_at),
                        age_hours=round(age, 6),
                        cache_hit=True,
                    )
                else:
                    result = replace(
                        result,
                        checked_at=_iso_utc(checked_at),
                        age_hours=round(age, 6),
                        cache_hit=True,
                    )
            else:
                result = replace(result, checked_at=_iso_utc(checked_at), cache_hit=True)
            return result

    result = _full_preflight(
        source,
        common,
        principal=principal,
        checked_at=checked_at,
        max_age_hours=int(max_age_hours),
    )
    if cache_allowed:
        with _CACHE_LOCK:
            _PREFLIGHT_CACHE[cache_key] = (signature, result)
    return result


def build_publication_plan(
    primary_candidate: Path | str,
    secondary_candidate: Path | str,
    *,
    generated_at: dt.datetime | str | None = None,
) -> dict[str, Any]:
    """Parse both candidates and return a hash-bound, JSON-serializable plan."""
    candidates = {
        PRIMARY_NAME: Path(primary_candidate),
        SECONDARY_NAME: Path(secondary_candidate),
    }
    parsed = {
        name: _parse_calendar_file(path, name) for name, path in candidates.items()
    }
    generated = _iso_utc(_as_utc(generated_at))
    identity = {
        "schema": MANIFEST_SCHEMA,
        "generated_at": generated,
        "files": [parsed[name].manifest_entry() for name in CALENDAR_NAMES],
    }
    identity_sha = _sha256_bytes(_canonical_json_bytes(identity))
    manifest_without_hash = {
        **identity,
        "bundle_id": f"news-calendar-{identity_sha}",
        "bundle_identity_sha256": identity_sha,
    }
    manifest = {
        **manifest_without_hash,
        "manifest_sha256": _sha256_bytes(_canonical_json_bytes(manifest_without_hash)),
    }
    plan_without_hash = {
        "schema": PLAN_SCHEMA,
        "created_at": generated,
        "candidates": [
            {
                "name": name,
                "path": str(candidates[name]),
                "sha256": parsed[name].sha256,
                "size_bytes": parsed[name].size_bytes,
            }
            for name in CALENDAR_NAMES
        ],
        "manifest": manifest,
    }
    return {
        **plan_without_hash,
        "plan_sha256": _sha256_bytes(_canonical_json_bytes(plan_without_hash)),
    }


def _validate_plan(plan: Mapping[str, Any]) -> tuple[dict[str, Any], dict[str, _ParsedCalendar]]:
    if plan.get("schema") != PLAN_SCHEMA:
        raise NewsCalendarError("unsupported calendar publication plan schema")
    plan_without_hash = dict(plan)
    expected_plan_sha = str(plan_without_hash.pop("plan_sha256", ""))
    actual_plan_sha = _sha256_bytes(_canonical_json_bytes(plan_without_hash))
    if not expected_plan_sha or expected_plan_sha != actual_plan_sha:
        raise NewsCalendarError("calendar publication plan SHA-256 mismatch")
    manifest = _validate_manifest(
        plan.get("manifest"), path=Path("<publication-plan-manifest>")
    )
    candidates = plan.get("candidates")
    if not isinstance(candidates, list) or len(candidates) != len(CALENDAR_NAMES):
        raise NewsCalendarError("publication plan must bind exactly two candidates")
    parsed: dict[str, _ParsedCalendar] = {}
    for expected_name, entry in zip(CALENDAR_NAMES, candidates):
        if not isinstance(entry, dict) or str(entry.get("name")) != expected_name:
            raise NewsCalendarError("publication candidate order/names are invalid")
        path = Path(str(entry.get("path") or ""))
        calendar = _parse_calendar_file(path, expected_name)
        if calendar.sha256 != str(entry.get("sha256") or ""):
            raise NewsCalendarError(f"candidate changed after planning: {path}")
        if calendar.size_bytes != int(entry.get("size_bytes") or -1):
            raise NewsCalendarError(f"candidate size changed after planning: {path}")
        parsed[expected_name] = calendar
    _verify_manifest_material(
        manifest, parsed, path=Path("<publication-plan-manifest>")
    )
    return manifest, parsed


def _write_fsynced(path: Path, raw: bytes) -> None:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_BINARY"):
        flags |= os.O_BINARY
    fd = os.open(path, flags, 0o600)
    try:
        view = memoryview(raw)
        while view:
            written = os.write(fd, view)
            if written <= 0:
                raise OSError(f"short write to {path}")
            view = view[written:]
        os.fsync(fd)
    finally:
        os.close(fd)


def _fsync_directory(path: Path) -> None:
    # POSIX supports directory fsync. Windows FlushFileBuffers rejects directory
    # handles opened through os.open, so file fsync + atomic replace remains the
    # durable boundary there.
    try:
        fd = os.open(path, os.O_RDONLY)
    except OSError:
        return
    try:
        os.fsync(fd)
    except OSError:
        pass
    finally:
        os.close(fd)


def _remove_known_staging(staging: Path) -> None:
    if not staging.exists():
        return
    for name in (*CALENDAR_NAMES, ACTIVE_MANIFEST_NAME):
        (staging / name).unlink(missing_ok=True)
    try:
        staging.rmdir()
    except OSError:
        # Never recursively delete an unexpected path/content. A leaked uniquely
        # named staging directory is safer and makes the anomaly inspectable.
        pass


def _install_immutable_bundle(
    root: Path,
    manifest: Mapping[str, Any],
    parsed: Mapping[str, _ParsedCalendar],
    manifest_raw: bytes,
) -> Path:
    bundle_root = root / BUNDLE_DIRECTORY_NAME
    bundle_root.mkdir(parents=True, exist_ok=True)
    final = bundle_root / str(manifest["bundle_id"])
    if final.exists():
        _verify_immutable_bundle(root, manifest)
        return final
    # Keep the same-volume staging name short enough for Windows' legacy
    # MAX_PATH environments; the final immutable identity remains the full hash.
    staging = bundle_root / f".stg-{uuid.uuid4().hex[:12]}"
    staging.mkdir()
    try:
        for name in CALENDAR_NAMES:
            _write_fsynced(staging / name, parsed[name].raw)
        _write_fsynced(staging / ACTIVE_MANIFEST_NAME, manifest_raw)
        # Verify the exact staged material before the atomic directory rename.
        staged_parsed = {
            name: _parse_calendar_file(staging / name, name) for name in CALENDAR_NAMES
        }
        _verify_manifest_material(manifest, staged_parsed, path=staging / ACTIVE_MANIFEST_NAME)
        loaded, raw = _load_manifest(staging / ACTIVE_MANIFEST_NAME)
        if loaded != dict(manifest) or raw != manifest_raw:
            raise NewsCalendarError(f"staged immutable manifest verification failed: {staging}")
        _fsync_directory(staging)
        try:
            os.replace(staging, final)
        except OSError:
            if not final.exists():
                raise
            _verify_immutable_bundle(root, manifest)
            _remove_known_staging(staging)
        _fsync_directory(bundle_root)
        return final
    except BaseException:
        _remove_known_staging(staging)
        raise


def _replace_active_file(root: Path, name: str, raw: bytes) -> None:
    root.mkdir(parents=True, exist_ok=True)
    temp = root / f".{name}.{uuid.uuid4().hex}.tmp"
    try:
        _write_fsynced(temp, raw)
        if _sha256_file(temp) != _sha256_bytes(raw):
            raise NewsCalendarError(f"temporary publication hash mismatch: {temp}")
        os.replace(temp, root / name)
        _fsync_directory(root)
    finally:
        temp.unlink(missing_ok=True)


def _inject_fault(fault_after: str | None, stage: str) -> None:
    if fault_after and fault_after.upper() == stage:
        raise InjectedPublishFailure(f"injected calendar publication failure after {stage}")


def publish_calendar_bundle(
    plan: Mapping[str, Any],
    *,
    source_dir: Path | str,
    common_dir: Path | str,
    factory_off_flag: Path | str,
    expected_factory_off_sha256: str,
    fault_after: str | None = None,
) -> dict[str, Any]:
    """Apply a planned publication under a hash-bound FACTORY_OFF interlock."""
    source = Path(source_dir)
    common = Path(common_dir)
    flag = Path(factory_off_flag)
    expected_flag_sha = str(expected_factory_off_sha256 or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected_flag_sha):
        raise NewsCalendarError("expected_factory_off_sha256 must be an exact lowercase SHA-256")

    # Parse and hash both candidates before taking the mutation lock or creating
    # publication directories.
    manifest, parsed = _validate_plan(plan)
    manifest_raw = _canonical_json_bytes(manifest) + b"\n"
    if not flag.is_file():
        raise NewsCalendarError(f"FACTORY_OFF flag missing: {flag}")
    actual_flag_sha = _sha256_file(flag)
    if actual_flag_sha != expected_flag_sha:
        raise NewsCalendarError(
            f"FACTORY_OFF SHA-256 mismatch: expected {expected_flag_sha}, actual {actual_flag_sha}"
        )

    lock_path = path_for_factory_flag(flag)
    with FactoryMutationLock(
        lock_path,
        owner=f"news_calendar_publish:{manifest['bundle_id']}",
    ):
        if not flag.is_file() or _sha256_file(flag) != expected_flag_sha:
            raise NewsCalendarError("FACTORY_OFF flag changed before calendar publication")

        source_bundle = _install_immutable_bundle(source, manifest, parsed, manifest_raw)
        _inject_fault(fault_after, "SOURCE_BUNDLE_INSTALLED")
        common_bundle = _install_immutable_bundle(common, manifest, parsed, manifest_raw)
        _inject_fault(fault_after, "COMMON_BUNDLE_INSTALLED")

        _replace_active_file(source, PRIMARY_NAME, parsed[PRIMARY_NAME].raw)
        _inject_fault(fault_after, "SOURCE_PRIMARY_REPLACED")
        _replace_active_file(source, SECONDARY_NAME, parsed[SECONDARY_NAME].raw)
        _inject_fault(fault_after, "SOURCE_SECONDARY_REPLACED")
        _replace_active_file(source, ACTIVE_MANIFEST_NAME, manifest_raw)
        _inject_fault(fault_after, "SOURCE_MANIFEST_REPLACED")

        _replace_active_file(common, PRIMARY_NAME, parsed[PRIMARY_NAME].raw)
        _inject_fault(fault_after, "COMMON_PRIMARY_REPLACED")
        _replace_active_file(common, SECONDARY_NAME, parsed[SECONDARY_NAME].raw)
        _inject_fault(fault_after, "COMMON_SECONDARY_REPLACED")
        _replace_active_file(common, ACTIVE_MANIFEST_NAME, manifest_raw)
        _inject_fault(fault_after, "COMMON_MANIFEST_REPLACED")

        if not flag.is_file() or _sha256_file(flag) != expected_flag_sha:
            raise NewsCalendarError("FACTORY_OFF flag changed during calendar publication")
        verification = preflight_news_calendar(
            source,
            common,
            max_age_hours=MAX_AGE_HOURS,
            use_cache=False,
        )
        if not verification.ok:
            raise NewsCalendarError(
                f"published calendar failed verification: {verification.status}: {verification.detail}"
            )

    clear_preflight_cache()
    return {
        "published": True,
        "bundle_id": manifest["bundle_id"],
        "bundle_identity_sha256": manifest["bundle_identity_sha256"],
        "manifest_sha256": manifest["manifest_sha256"],
        "generated_at": manifest["generated_at"],
        "source_dir": str(source),
        "common_dir": str(common),
        "source_bundle_dir": str(source_bundle),
        "common_bundle_dir": str(common_bundle),
        "factory_off_flag": str(flag),
        "factory_off_sha256": expected_flag_sha,
        "preflight": verification.as_dict(),
    }


def _read_plan(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise NewsCalendarError(f"cannot read publication plan {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise NewsCalendarError("publication plan must be a JSON object")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser("preflight")
    check.add_argument("--source-dir", type=Path)
    check.add_argument("--common-dir", type=Path)
    check.add_argument("--no-cache", action="store_true")

    plan_parser = subparsers.add_parser("plan")
    plan_parser.add_argument("--primary-candidate", type=Path, required=True)
    plan_parser.add_argument("--secondary-candidate", type=Path, required=True)
    plan_parser.add_argument("--generated-at")

    publish = subparsers.add_parser("publish")
    publish.add_argument("--plan", type=Path, required=True)
    publish.add_argument("--source-dir", type=Path, required=True)
    publish.add_argument("--common-dir", type=Path, required=True)
    publish.add_argument("--factory-off-flag", type=Path, required=True)
    publish.add_argument("--expected-factory-off-sha256", required=True)
    publish.add_argument("--apply", action="store_true")

    args = parser.parse_args(argv)
    try:
        if args.command == "preflight":
            result = preflight_news_calendar(
                args.source_dir,
                args.common_dir,
                use_cache=not args.no_cache,
            )
            print(json.dumps(result.as_dict(), indent=2, sort_keys=True))
            return 0 if result.ok else 2
        if args.command == "plan":
            result = build_publication_plan(
                args.primary_candidate,
                args.secondary_candidate,
                generated_at=args.generated_at,
            )
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        plan = _read_plan(args.plan)
        if not args.apply:
            print(
                json.dumps(
                    {
                        "published": False,
                        "what_if": True,
                        "plan_sha256": plan.get("plan_sha256"),
                        "source_dir": str(args.source_dir),
                        "common_dir": str(args.common_dir),
                        "factory_off_flag": str(args.factory_off_flag),
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        result = publish_calendar_bundle(
            plan,
            source_dir=args.source_dir,
            common_dir=args.common_dir,
            factory_off_flag=args.factory_off_flag,
            expected_factory_off_sha256=args.expected_factory_off_sha256,
        )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (NewsCalendarError, OSError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
