"""Fail-closed MT5 news-calendar preflight and atomic pair publisher.

The preflight is deliberately read-only: it never creates directories, touches
files, writes logs, or opens the farm database.  It validates the two calendar
files used by ``QM_NewsFilter`` for the executing Windows principal and keeps
the legacy ``run_smoke.ps1`` status taxonomy.

Publishing is a separate, explicit mutation path.  Maintenance publication is
guarded by the exact SHA-256 of an existing ``FACTORY_OFF.flag``.  The routine
multi-principal publisher may also run while the Factory is ON, but only while
the OFF flag remains absent.  Both modes hold the shared factory mutation lock
and revalidate their Factory generation throughout the operation.  Immutable
version directories are installed first; active files are replaced per root
with the manifest last and the shared source root last.  Readers therefore see
one valid generation or fail closed during a cross-root transition.
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
import time
import uuid
from dataclasses import asdict, dataclass, replace
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, Sequence

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
MULTI_PLAN_SCHEMA = "qm-news-calendar-multi-principal-publication-plan/v1"
JOURNAL_SCHEMA = "qm-news-calendar-publication-journal/v1"
DEFAULT_SOURCE_DIR = Path(r"D:\QM\data\news_calendar")
PRODUCTION_COMMON_DIRS = (
    Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files"),
    Path(
        r"C:\Windows\System32\config\systemprofile\AppData\Roaming\MetaQuotes"
        r"\Terminal\Common\Files"
    ),
    Path(r"C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files"),
)
PRODUCTION_FACTORY_OFF_FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
PRODUCTION_EVIDENCE_DIR = Path(r"D:\QM\reports\state")
PRODUCTION_GATE_SCRIPT = Path(r"C:\QM\repo\tools\strategy_farm\news_calendar_gate.py")
PRODUCTION_REFRESH_SCRIPT = Path(
    r"C:\QM\repo\tools\strategy_farm\refresh_news_calendar.ps1"
)
PRODUCTION_PROVENANCE_KIND = "scheduled-refresh-script"
PRODUCTION_PROTECTED_ROOTS = (
    Path(r"C:\QM\repo"),
    Path(r"D:\QM\strategy_farm\state"),
    Path(r"D:\QM\reports\state"),
    Path(r"D:\QM\mt5"),
)
_PRODUCTION_STAGING_RE = re.compile(r"^news-calendar-staging-[0-9a-f]{32}$")

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
class _PublicationPolicy:
    source_dir: Path
    common_dirs: tuple[Path, ...]
    factory_off_flag: Path
    refresh_script: Path
    provenance_kind: str
    evidence_dir: Path
    protected_roots: tuple[Path, ...]
    test_injected: bool = False


_PRODUCTION_POLICY = _PublicationPolicy(
    source_dir=DEFAULT_SOURCE_DIR,
    common_dirs=PRODUCTION_COMMON_DIRS,
    factory_off_flag=PRODUCTION_FACTORY_OFF_FLAG,
    refresh_script=PRODUCTION_REFRESH_SCRIPT,
    provenance_kind=PRODUCTION_PROVENANCE_KIND,
    evidence_dir=PRODUCTION_EVIDENCE_DIR,
    protected_roots=PRODUCTION_PROTECTED_ROOTS,
)


def _test_publication_policy(
    *,
    source_dir: Path | str,
    common_dirs: Sequence[Path | str],
    factory_off_flag: Path | str,
    refresh_script: Path | str,
    evidence_dir: Path | str,
    protected_roots: Sequence[Path | str] = (),
) -> _PublicationPolicy:
    """Construct an explicitly test-injected authority unavailable to the CLI."""

    return _PublicationPolicy(
        source_dir=Path(source_dir),
        common_dirs=tuple(Path(path) for path in common_dirs),
        factory_off_flag=Path(factory_off_flag),
        refresh_script=Path(refresh_script),
        provenance_kind="test-injected-refresh-script",
        evidence_dir=Path(evidence_dir),
        protected_roots=tuple(Path(path) for path in protected_roots),
        test_injected=True,
    )


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


def _json_object_without_duplicates(pairs: Sequence[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON key: {key}")
        value[key] = item
    return value


def _json_loads_without_duplicates(raw: str) -> Any:
    return json.loads(raw, object_pairs_hook=_json_object_without_duplicates)


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
    extra = sorted(set(manifest) - required)
    if extra:
        raise CalendarParseError(f"{path}: unexpected manifest fields {','.join(extra)}")
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
        parsed = _json_loads_without_duplicates(raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
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


def _validate_plan_hash(plan: Mapping[str, Any], *, schema: str) -> str:
    if plan.get("schema") != schema:
        raise NewsCalendarError("unsupported calendar publication plan schema")
    plan_without_hash = dict(plan)
    expected_plan_sha = str(plan_without_hash.pop("plan_sha256", ""))
    actual_plan_sha = _sha256_bytes(_canonical_json_bytes(plan_without_hash))
    if not expected_plan_sha or expected_plan_sha != actual_plan_sha:
        raise NewsCalendarError("calendar publication plan SHA-256 mismatch")
    return expected_plan_sha


def _validate_plan_material(
    plan: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, _ParsedCalendar]]:
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
        if set(entry) != {"name", "path", "sha256", "size_bytes"}:
            raise NewsCalendarError("publication candidate fields are invalid")
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


def _validate_plan(plan: Mapping[str, Any]) -> tuple[dict[str, Any], dict[str, _ParsedCalendar]]:
    _validate_plan_hash(plan, schema=PLAN_SCHEMA)
    return _validate_plan_material(plan)


def _absolute_lexical_path(path: Path | str) -> Path:
    candidate = Path(path).expanduser()
    if not candidate.is_absolute():
        candidate = Path.cwd() / candidate
    return Path(os.path.abspath(candidate))


def _is_link_or_reparse(path: Path) -> bool:
    try:
        stat = path.lstat()
    except FileNotFoundError:
        return False
    except OSError as exc:
        raise NewsCalendarError(f"cannot inspect path for link/reparse state: {path}: {exc}") from exc
    return path.is_symlink() or bool(getattr(stat, "st_file_attributes", 0) & 0x400)


def _reject_link_components(path: Path | str, *, label: str) -> Path:
    absolute = _absolute_lexical_path(path)
    current = Path(absolute.anchor)
    for part in absolute.parts[1:]:
        current /= part
        if os.path.lexists(current) and _is_link_or_reparse(current):
            raise NewsCalendarError(f"{label} contains a symlink/reparse component: {current}")
    return absolute


def _canonical_target(path: Path | str, *, label: str = "path") -> Path:
    lexical = _reject_link_components(path, label=label)
    return lexical.resolve(strict=False)


def _path_identity(path: Path) -> str:
    return os.path.normcase(os.path.normpath(str(path))).casefold()


def _paths_overlap(first: Path, second: Path) -> bool:
    try:
        common = Path(os.path.commonpath((str(first), str(second))))
    except ValueError:
        return False
    identity = _path_identity(common)
    return identity in {_path_identity(first), _path_identity(second)}


def _validated_policy(policy: _PublicationPolicy) -> _PublicationPolicy:
    source = _canonical_target(policy.source_dir, label="publication source root")
    commons = tuple(
        _canonical_target(path, label=f"publication Common root[{index}]")
        for index, path in enumerate(policy.common_dirs)
    )
    flag = _canonical_target(policy.factory_off_flag, label="FACTORY_OFF flag")
    refresh = _canonical_target(policy.refresh_script, label="refresh provenance")
    evidence = _canonical_target(policy.evidence_dir, label="publication evidence root")
    protected = tuple(
        _canonical_target(path, label=f"protected root[{index}]")
        for index, path in enumerate(policy.protected_roots)
    )
    if not policy.test_injected:
        running_gate = _canonical_target(Path(__file__), label="production gate script")
        expected_gate = _canonical_target(
            PRODUCTION_GATE_SCRIPT, label="canonical production gate script"
        )
        expected_source = _canonical_target(
            DEFAULT_SOURCE_DIR, label="canonical production source root"
        )
        expected_commons = tuple(
            _canonical_target(path, label=f"canonical Common root[{index}]")
            for index, path in enumerate(PRODUCTION_COMMON_DIRS)
        )
        expected_flag = _canonical_target(
            PRODUCTION_FACTORY_OFF_FLAG, label="canonical FACTORY_OFF flag"
        )
        expected_refresh = _canonical_target(
            PRODUCTION_REFRESH_SCRIPT, label="canonical refresh provenance"
        )
        expected_evidence = _canonical_target(
            PRODUCTION_EVIDENCE_DIR, label="canonical publication evidence root"
        )
        expected_protected = tuple(
            _canonical_target(path, label=f"canonical protected root[{index}]")
            for index, path in enumerate(PRODUCTION_PROTECTED_ROOTS)
        )
        if _path_identity(running_gate) != _path_identity(expected_gate):
            raise NewsCalendarError(
                "production CLI is not the canonical C:\\QM\\repo news-calendar gate"
            )
        if (
            source != expected_source
            or commons != expected_commons
            or flag != expected_flag
            or refresh != expected_refresh
            or evidence != expected_evidence
            or protected != expected_protected
            or policy.provenance_kind != PRODUCTION_PROVENANCE_KIND
        ):
            raise NewsCalendarError(
                "non-test publication policy differs from canonical production authority"
            )
    if not commons:
        raise NewsCalendarError("publication policy requires Common roots")
    if not refresh.is_file():
        raise NewsCalendarError(f"refresh provenance is missing: {refresh}")
    publication_roots = (source, *commons)
    authority_roots = (*publication_roots, flag.parent, evidence)
    for index, root in enumerate(authority_roots):
        for other in authority_roots[index + 1 :]:
            if _paths_overlap(root, other):
                raise NewsCalendarError(
                    f"publication authority roots overlap by equality/ancestry: {root} | {other}"
                )
    for root in publication_roots:
        for protected_root in protected:
            if _paths_overlap(root, protected_root):
                raise NewsCalendarError(
                    f"publication authority root overlaps protected root: {root} | {protected_root}"
                )
        if _paths_overlap(root, refresh):
            raise NewsCalendarError(
                f"publication authority root overlaps refresh provenance: {root} | {refresh}"
            )
    return _PublicationPolicy(
        source_dir=source,
        common_dirs=commons,
        factory_off_flag=flag,
        refresh_script=refresh,
        provenance_kind=policy.provenance_kind,
        evidence_dir=evidence,
        protected_roots=protected,
        test_injected=policy.test_injected,
    )


def _policy_provenance(policy: _PublicationPolicy) -> dict[str, str]:
    return {
        "kind": policy.provenance_kind,
        "path": str(policy.refresh_script),
        "sha256": _sha256_file(policy.refresh_script),
    }


def _validate_candidate_pair(
    primary_candidate: Path | str,
    secondary_candidate: Path | str,
    policy: _PublicationPolicy,
) -> tuple[Path, Path]:
    primary = _canonical_target(primary_candidate, label="primary candidate")
    secondary = _canonical_target(secondary_candidate, label="secondary candidate")
    if primary.name != PRIMARY_NAME or secondary.name != SECONDARY_NAME:
        raise NewsCalendarError("calendar candidate filenames are not canonical")
    if primary.parent != secondary.parent:
        raise NewsCalendarError("calendar candidates must share one directory")
    if not policy.test_injected:
        parent = primary.parent
        is_active_source = parent == policy.source_dir
        is_staging = (
            parent.parent == policy.evidence_dir
            and _PRODUCTION_STAGING_RE.fullmatch(parent.name) is not None
        )
        if not (is_active_source or is_staging):
            raise NewsCalendarError(
                "production candidates must be the exact D source pair or one canonical state staging pair"
            )
    return primary, secondary


def _validate_evidence_output(
    path: Path | str,
    policy: _PublicationPolicy,
    *,
    kind: str,
) -> Path:
    target = _canonical_target(path, label=f"{kind} output")
    if target.parent != policy.evidence_dir:
        raise NewsCalendarError(f"{kind} output must be a direct child of {policy.evidence_dir}")
    patterns = {
        "plan": r"^news_calendar_publication_plan_[0-9TZ-]+[0-9a-f]{32}\.json$",
        "journal": r"^news_calendar_publication_journal_[0-9TZ-]+[0-9a-f]{32}\.json$",
        "receipt": r"^news_calendar_publication_receipt_[0-9TZ-]+[0-9a-f]{32}\.json$",
    }
    if re.fullmatch(patterns[kind], target.name) is None:
        raise NewsCalendarError(f"{kind} output filename is not canonical: {target.name}")
    return target


def build_multi_principal_publication_plan(
    primary_candidate: Path | str,
    secondary_candidate: Path | str,
    *,
    generated_at: dt.datetime | str | None = None,
    _policy: _PublicationPolicy | None = None,
) -> dict[str, Any]:
    """Build a read-only plan under production or explicit test authority."""

    policy = _validated_policy(_policy or _PRODUCTION_POLICY)
    primary, secondary = _validate_candidate_pair(
        primary_candidate,
        secondary_candidate,
        policy,
    )
    base = build_publication_plan(
        primary,
        secondary,
        generated_at=generated_at,
    )

    plan_without_hash = {
        "schema": MULTI_PLAN_SCHEMA,
        "created_at": base["created_at"],
        "candidates": base["candidates"],
        "manifest": base["manifest"],
        "targets": [
            {"role": "source", "path": str(policy.source_dir)},
            *({"role": "common", "path": str(path)} for path in policy.common_dirs),
        ],
        "provenance": _policy_provenance(policy),
    }
    return {
        **plan_without_hash,
        "plan_sha256": _sha256_bytes(_canonical_json_bytes(plan_without_hash)),
    }


def _validate_multi_plan(
    plan: Mapping[str, Any],
    policy: _PublicationPolicy,
) -> tuple[
    dict[str, Any],
    dict[str, _ParsedCalendar],
    Path,
    list[Path],
]:
    if set(plan) != {
        "schema",
        "created_at",
        "candidates",
        "manifest",
        "targets",
        "provenance",
        "plan_sha256",
    }:
        raise NewsCalendarError("multi-principal plan fields are invalid")
    _validate_plan_hash(plan, schema=MULTI_PLAN_SCHEMA)
    candidate_entries = plan.get("candidates")
    if (
        not isinstance(candidate_entries, list)
        or len(candidate_entries) != 2
        or not all(isinstance(entry, dict) for entry in candidate_entries)
    ):
        raise NewsCalendarError("multi-principal candidate list is invalid")
    _validate_candidate_pair(
        str(candidate_entries[0].get("path") or ""),
        str(candidate_entries[1].get("path") or ""),
        policy,
    )
    manifest, parsed = _validate_plan_material(plan)
    targets = plan.get("targets")
    if not isinstance(targets, list) or len(targets) < 2:
        raise NewsCalendarError("multi-principal plan must bind one source and Common roots")
    expected_roles = ["source", *("common" for _ in targets[1:])]
    roles = [str(entry.get("role") or "") for entry in targets if isinstance(entry, dict)]
    if roles != expected_roles or len(roles) != len(targets):
        raise NewsCalendarError("multi-principal target order/roles are invalid")
    paths: list[Path] = []
    for entry in targets:
        if set(entry) != {"role", "path"}:
            raise NewsCalendarError("multi-principal target fields are invalid")
        raw_path = str(entry.get("path") or "")
        path = Path(raw_path)
        if (
            not raw_path
            or not path.is_absolute()
            or _canonical_target(path, label="planned publication root") != path
        ):
            raise NewsCalendarError("multi-principal targets must be canonical absolute paths")
        paths.append(path)
    identities = [_path_identity(path) for path in paths]
    if len(set(identities)) != len(identities):
        raise NewsCalendarError("multi-principal publication roots must be distinct")
    if paths[0] != policy.source_dir or tuple(paths[1:]) != policy.common_dirs:
        raise NewsCalendarError("publication plan targets differ from pinned authority")
    provenance = plan.get("provenance")
    if not isinstance(provenance, dict):
        raise NewsCalendarError("multi-principal provenance must be an object")
    if provenance != _policy_provenance(policy):
        raise NewsCalendarError("multi-principal provenance differs from pinned authority")
    return manifest, parsed, paths[0], paths[1:]


def _require_expected_plan_sha256(
    plan: Mapping[str, Any], expected_plan_sha256: str,
) -> str:
    expected = str(expected_plan_sha256 or "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise NewsCalendarError("expected_plan_sha256 must be an exact lowercase SHA-256")
    declared = str(plan.get("plan_sha256") or "")
    if declared != expected:
        raise NewsCalendarError(
            f"publication plan differs from independently expected SHA-256 {expected}"
        )
    return expected


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


# A running MT5 tester can hold an active calendar CSV open; os.replace then
# raises a sharing violation and the 03:30Z publication dies fail-closed,
# leaving the fleet deferring on a stale-Common mismatch until manual repair
# (2026-08-11: WinError 5 on forex_factory_calendar_clean.csv, throughput
# 37/h -> 1/h). Those very deferrals drain the testers, so a bounded retry
# almost always lands in a released-handle window.
ACTIVE_REPLACE_RETRY_ATTEMPTS = 18
ACTIVE_REPLACE_RETRY_DELAY_SECONDS = 50.0


def _replace_active_file(
    root: Path,
    name: str,
    raw: bytes,
    *,
    sleeper: Callable[[float], None] = time.sleep,
) -> bool:
    root = _canonical_target(root, label="active publication root")
    root.mkdir(parents=True, exist_ok=True)
    destination = root / name
    if destination.is_symlink() or _is_link_or_reparse(destination):
        raise NewsCalendarError(f"active publication target is a link/reparse point: {destination}")
    if destination.is_file() and _sha256_file(destination) == _sha256_bytes(raw):
        # Byte-identical refreshes must not advance CSV mtime freshness.
        return False
    temp = root / f".{name}.{uuid.uuid4().hex}.tmp"
    try:
        _write_fsynced(temp, raw)
        if _sha256_file(temp) != _sha256_bytes(raw):
            raise NewsCalendarError(f"temporary publication hash mismatch: {temp}")
        for attempt in range(ACTIVE_REPLACE_RETRY_ATTEMPTS):
            try:
                os.replace(temp, destination)
                break
            except PermissionError:
                if attempt + 1 >= ACTIVE_REPLACE_RETRY_ATTEMPTS:
                    raise
                sleeper(ACTIVE_REPLACE_RETRY_DELAY_SECONDS)
        _fsync_directory(root)
    finally:
        temp.unlink(missing_ok=True)
    return True


def _inject_fault(fault_after: str | None, stage: str) -> None:
    if fault_after and fault_after.upper() == stage:
        raise InjectedPublishFailure(f"injected calendar publication failure after {stage}")


def _publication_factory_mode(
    flag: Path,
    *,
    expected_factory_off_sha256: str | None,
    allow_factory_on: bool,
) -> tuple[str, str | None]:
    expected = str(expected_factory_off_sha256 or "").strip().lower()
    if allow_factory_on and expected:
        raise NewsCalendarError(
            "allow_factory_on and expected_factory_off_sha256 are mutually exclusive"
        )
    if allow_factory_on:
        if flag.exists():
            raise NewsCalendarError(
                f"Factory ON publication requires an absent FACTORY_OFF flag: {flag}"
            )
        return "ON_ABSENT_FLAG", None
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise NewsCalendarError(
            "OFF publication requires an exact lowercase expected_factory_off_sha256"
        )
    if not flag.is_file():
        raise NewsCalendarError(f"FACTORY_OFF flag missing: {flag}")
    actual = _sha256_file(flag)
    if actual != expected:
        raise NewsCalendarError(
            f"FACTORY_OFF SHA-256 mismatch: expected {expected}, actual {actual}"
        )
    return "OFF_HASH_BOUND", expected


def _assert_factory_generation(
    flag: Path,
    *,
    mode: str,
    expected_factory_off_sha256: str | None,
    stage: str,
) -> None:
    if mode == "ON_ABSENT_FLAG":
        if flag.exists():
            raise NewsCalendarError(
                f"FACTORY_OFF flag appeared during calendar publication ({stage})"
            )
        return
    if not flag.is_file():
        raise NewsCalendarError(
            f"FACTORY_OFF flag disappeared during calendar publication ({stage})"
        )
    actual = _sha256_file(flag)
    if actual != expected_factory_off_sha256:
        raise NewsCalendarError(
            f"FACTORY_OFF flag changed during calendar publication ({stage})"
        )


def validate_multi_principal_publication(
    plan: Mapping[str, Any],
    *,
    expected_plan_sha256: str,
    expected_factory_off_sha256: str | None = None,
    allow_factory_on: bool = False,
    _policy: _PublicationPolicy | None = None,
) -> dict[str, Any]:
    """Read-only validation used by CLI WhatIf and operator reconciliation."""

    policy = _validated_policy(_policy or _PRODUCTION_POLICY)
    expected_plan_sha = _require_expected_plan_sha256(plan, expected_plan_sha256)
    manifest, _parsed, source, commons = _validate_multi_plan(plan, policy)
    flag = policy.factory_off_flag
    mode, expected = _publication_factory_mode(
        flag,
        expected_factory_off_sha256=expected_factory_off_sha256,
        allow_factory_on=allow_factory_on,
    )
    return {
        "published": False,
        "what_if": True,
        "plan_sha256": expected_plan_sha,
        "bundle_id": manifest["bundle_id"],
        "source_dir": str(source),
        "common_dirs": [str(path) for path in commons],
        "factory_mode": mode,
        "factory_off_flag": str(flag),
        "factory_off_sha256": expected,
    }


def publish_calendar_bundle_multi(
    plan: Mapping[str, Any],
    *,
    expected_plan_sha256: str,
    expected_factory_off_sha256: str | None = None,
    allow_factory_on: bool = False,
    fault_after: str | None = None,
    _policy: _PublicationPolicy | None = None,
) -> dict[str, Any]:
    """Atomically publish one plan to the source and every bound Common root."""

    policy = _validated_policy(_policy or _PRODUCTION_POLICY)
    # Parse/hash candidates and validate all target identities before the lock or
    # any target-directory creation.
    expected_plan_sha = _require_expected_plan_sha256(plan, expected_plan_sha256)
    manifest, parsed, source, commons = _validate_multi_plan(plan, policy)
    flag = policy.factory_off_flag
    mode, expected = _publication_factory_mode(
        flag,
        expected_factory_off_sha256=expected_factory_off_sha256,
        allow_factory_on=allow_factory_on,
    )
    manifest_raw = _canonical_json_bytes(manifest) + b"\n"
    lock = FactoryMutationLock(
        path_for_factory_flag(flag),
        owner=f"news_calendar_multi_publish:{manifest['bundle_id']}",
    )
    bundle_dirs: dict[str, str] = {}
    verifications: list[dict[str, Any]] = []

    with lock:
        _assert_factory_generation(
            flag,
            mode=mode,
            expected_factory_off_sha256=expected,
            stage="LOCK_ACQUIRED",
        )

        # Install every immutable generation before any active pointer changes.
        for index, root in enumerate([source, *commons]):
            bundle = _install_immutable_bundle(root, manifest, parsed, manifest_raw)
            bundle_dirs[str(root)] = str(bundle)
            role = "SOURCE" if index == 0 else f"COMMON_{index - 1}"
            _inject_fault(fault_after, f"{role}_BUNDLE_INSTALLED")
            _assert_factory_generation(
                flag,
                mode=mode,
                expected_factory_off_sha256=expected,
                stage=f"{role}_BUNDLE_INSTALLED",
            )

        # Common generations move first. The source generation moves last, so a
        # partial transition can never look globally accepted to preflight.
        for index, common in enumerate(commons):
            prefix = f"COMMON_{index}"
            for name, label, raw in (
                (PRIMARY_NAME, "PRIMARY", parsed[PRIMARY_NAME].raw),
                (SECONDARY_NAME, "SECONDARY", parsed[SECONDARY_NAME].raw),
                (ACTIVE_MANIFEST_NAME, "MANIFEST", manifest_raw),
            ):
                _replace_active_file(common, name, raw)
                stage = f"{prefix}_{label}_REPLACED"
                _inject_fault(fault_after, stage)
                _assert_factory_generation(
                    flag,
                    mode=mode,
                    expected_factory_off_sha256=expected,
                    stage=stage,
                )

        for name, label, raw in (
            (PRIMARY_NAME, "PRIMARY", parsed[PRIMARY_NAME].raw),
            (SECONDARY_NAME, "SECONDARY", parsed[SECONDARY_NAME].raw),
            (ACTIVE_MANIFEST_NAME, "MANIFEST", manifest_raw),
        ):
            _replace_active_file(source, name, raw)
            stage = f"SOURCE_{label}_REPLACED"
            _inject_fault(fault_after, stage)
            _assert_factory_generation(
                flag,
                mode=mode,
                expected_factory_off_sha256=expected,
                stage=stage,
            )

        for common in commons:
            verification = preflight_news_calendar(
                source,
                common,
                max_age_hours=MAX_AGE_HOURS,
                use_cache=False,
            )
            verifications.append(verification.as_dict())
            if not verification.ok:
                raise NewsCalendarError(
                    "published multi-principal calendar failed verification for "
                    f"{common}: {verification.status}: {verification.detail}"
                )
        _assert_factory_generation(
            flag,
            mode=mode,
            expected_factory_off_sha256=expected,
            stage="VERIFIED",
        )

    clear_preflight_cache()
    lock_ok = lock.release_succeeded
    status = "committed" if lock_ok else "committed_lock_retained"
    return {
        "ok": lock_ok,
        "status": status,
        "committed": True,
        "published": True,
        "plan_sha256": expected_plan_sha,
        "bundle_id": manifest["bundle_id"],
        "bundle_identity_sha256": manifest["bundle_identity_sha256"],
        "manifest_sha256": manifest["manifest_sha256"],
        "generated_at": manifest["generated_at"],
        "source_dir": str(source),
        "common_dirs": [str(path) for path in commons],
        "bundle_dirs": bundle_dirs,
        "factory_mode": mode,
        "factory_off_flag": str(flag),
        "factory_off_sha256": expected,
        "preflights": verifications,
        "lock_release_status": lock.release_status,
        "lock_release_succeeded": lock_ok,
    }


def _read_plan(path: Path) -> dict[str, Any]:
    try:
        value = _json_loads_without_duplicates(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise NewsCalendarError(f"cannot read publication plan {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise NewsCalendarError("publication plan must be a JSON object")
    return value


def _write_json_atomic_output(path: Path | str, payload: Mapping[str, Any]) -> Path:
    """Persist an explicitly requested plan/receipt without shell redirection."""

    target = _canonical_target(path, label="JSON evidence output")
    raw = _pretty_json_bytes(payload)
    if target.is_symlink():
        raise NewsCalendarError(f"JSON output target must not be a symbolic link: {target}")
    if target.exists():
        if not target.is_file():
            raise NewsCalendarError(f"JSON output target is not a file: {target}")
        if target.read_bytes() == raw:
            return target
        raise NewsCalendarError(f"refusing to overwrite differing JSON evidence: {target}")
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.parent / f".{target.name}.{uuid.uuid4().hex}.tmp"
    try:
        _write_fsynced(temporary, raw)
        try:
            # A same-volume hard link publishes the already-fsynced bytes with
            # create-only semantics. A concurrent differing artifact wins and
            # is never overwritten.
            os.link(temporary, target)
        except FileExistsError:
            if target.is_file() and not target.is_symlink() and target.read_bytes() == raw:
                return target
            raise NewsCalendarError(
                f"refusing to overwrite concurrent differing JSON evidence: {target}"
            )
        _fsync_directory(target.parent)
        if target.read_bytes() != raw:
            raise NewsCalendarError(f"atomic JSON output verification failed: {target}")
    finally:
        temporary.unlink(missing_ok=True)
    return target


def _pretty_json_bytes(payload: Mapping[str, Any]) -> bytes:
    return (
        json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True).encode("utf-8")
        + b"\n"
    )


def _replace_json_atomic_expected(
    path: Path,
    payload: Mapping[str, Any],
    *,
    expected_raw: bytes,
) -> bytes:
    target = _canonical_target(path, label="publication journal")
    if target.is_symlink() or _is_link_or_reparse(target):
        raise NewsCalendarError(f"publication journal is a link/reparse point: {target}")
    try:
        actual = target.read_bytes()
    except OSError as exc:
        raise NewsCalendarError(f"cannot read pre-reserved publication journal: {exc}") from exc
    if actual != expected_raw:
        raise NewsCalendarError("publication journal changed outside the operation")
    raw = _pretty_json_bytes(payload)
    temporary = target.parent / f".{target.name}.{uuid.uuid4().hex}.tmp"
    try:
        _write_fsynced(temporary, raw)
        if target.read_bytes() != expected_raw:
            raise NewsCalendarError("publication journal changed before state transition")
        os.replace(temporary, target)
        _fsync_directory(target.parent)
        if target.read_bytes() != raw:
            raise NewsCalendarError("publication journal transition verification failed")
    finally:
        temporary.unlink(missing_ok=True)
    return raw


def _journal_record(
    *,
    state: str,
    operation_id: str,
    plan: Mapping[str, Any],
    policy: _PublicationPolicy,
    receipt_path: Path,
    committed: bool,
    detail: Mapping[str, Any] | None = None,
    prepared_at: str,
) -> dict[str, Any]:
    return {
        "schema": JOURNAL_SCHEMA,
        "operation_id": operation_id,
        "state": state,
        "committed": committed,
        "prepared_at": prepared_at,
        "updated_at": _iso_utc(_utc_now()),
        "plan_sha256": plan["plan_sha256"],
        "bundle_id": plan["manifest"]["bundle_id"],
        "source_dir": str(policy.source_dir),
        "common_dirs": [str(path) for path in policy.common_dirs],
        "factory_off_flag": str(policy.factory_off_flag),
        "lock_path": str(path_for_factory_flag(policy.factory_off_flag)),
        "provenance": _policy_provenance(policy),
        "receipt_path": str(receipt_path),
        "detail": dict(detail or {}),
    }


def execute_multi_principal_publication(
    plan: Mapping[str, Any],
    *,
    expected_plan_sha256: str,
    expected_factory_off_sha256: str | None = None,
    allow_factory_on: bool = False,
    journal_output: Path | str,
    receipt_output: Path | str,
    _policy: _PublicationPolicy | None = None,
    _fault_after: str | None = None,
) -> dict[str, Any]:
    """Execute a journaled publication and return an unambiguous outcome."""

    policy = _validated_policy(_policy or _PRODUCTION_POLICY)
    journal_path = _validate_evidence_output(journal_output, policy, kind="journal")
    receipt_path = _validate_evidence_output(receipt_output, policy, kind="receipt")
    if journal_path == receipt_path:
        raise NewsCalendarError("journal and receipt outputs must be distinct")
    what_if = validate_multi_principal_publication(
        plan,
        expected_plan_sha256=expected_plan_sha256,
        expected_factory_off_sha256=expected_factory_off_sha256,
        allow_factory_on=allow_factory_on,
        _policy=policy,
    )
    prepared_at = _iso_utc(_utc_now())
    operation_material = {
        "plan_sha256": expected_plan_sha256,
        "journal_path": str(journal_path),
        "receipt_path": str(receipt_path),
        "factory_mode": what_if["factory_mode"],
    }
    operation_id = _sha256_bytes(_canonical_json_bytes(operation_material))
    prepared = _journal_record(
        state="PREPARED",
        operation_id=operation_id,
        plan=plan,
        policy=policy,
        receipt_path=receipt_path,
        committed=False,
        detail={"factory_mode": what_if["factory_mode"]},
        prepared_at=prepared_at,
    )
    _write_json_atomic_output(journal_path, prepared)
    journal_raw = _pretty_json_bytes(prepared)
    try:
        result = publish_calendar_bundle_multi(
            plan,
            expected_plan_sha256=expected_plan_sha256,
            expected_factory_off_sha256=expected_factory_off_sha256,
            allow_factory_on=allow_factory_on,
            fault_after=_fault_after,
            _policy=policy,
        )
    except BaseException as exc:
        failed = _journal_record(
            state="FAILED_FAIL_CLOSED_MUTATION_POSSIBLE",
            operation_id=operation_id,
            plan=plan,
            policy=policy,
            receipt_path=receipt_path,
            committed=False,
            detail={"error": str(exc), "mutation_possible": True},
            prepared_at=prepared_at,
        )
        _replace_json_atomic_expected(journal_path, failed, expected_raw=journal_raw)
        raise

    pending_state = (
        "COMMITTED_PENDING_RECEIPT"
        if result["lock_release_succeeded"]
        else "COMMITTED_LOCK_RETAINED_PENDING_RECEIPT"
    )
    pending = _journal_record(
        state=pending_state,
        operation_id=operation_id,
        plan=plan,
        policy=policy,
        receipt_path=receipt_path,
        committed=True,
        detail={"publication": result},
        prepared_at=prepared_at,
    )
    try:
        journal_raw = _replace_json_atomic_expected(
            journal_path,
            pending,
            expected_raw=journal_raw,
        )
    except BaseException as exc:
        return {
            **result,
            "ok": False,
            "status": "committed_journal_failed",
            "committed": True,
            "journal_path": str(journal_path),
            "receipt_path": str(receipt_path),
            "journal_error": str(exc),
        }

    receipt = {
        **result,
        "journal_path": str(journal_path),
        "receipt_path": str(receipt_path),
        "operation_id": operation_id,
    }
    try:
        _write_json_atomic_output(receipt_path, receipt)
    except BaseException as exc:
        failure = {
            **receipt,
            "ok": False,
            "status": "committed_receipt_failed",
            "committed": True,
            "receipt_error": str(exc),
        }
        failed_record = _journal_record(
            state="COMMITTED_RECEIPT_FAILED",
            operation_id=operation_id,
            plan=plan,
            policy=policy,
            receipt_path=receipt_path,
            committed=True,
            detail={"outcome": failure},
            prepared_at=prepared_at,
        )
        try:
            _replace_json_atomic_expected(
                journal_path,
                failed_record,
                expected_raw=journal_raw,
            )
        except BaseException as journal_exc:
            # Mutation is already committed.  Never let a secondary evidence
            # failure collapse this into a generic, apparently-unapplied error.
            failure["journal_error"] = str(journal_exc)
        return failure

    final_state = (
        "COMMITTED_RECEIPTED"
        if result["lock_release_succeeded"]
        else "COMMITTED_LOCK_RETAINED_RECEIPTED"
    )
    final_record = _journal_record(
        state=final_state,
        operation_id=operation_id,
        plan=plan,
        policy=policy,
        receipt_path=receipt_path,
        committed=True,
        detail={"outcome": receipt},
        prepared_at=prepared_at,
    )
    try:
        _replace_json_atomic_expected(
            journal_path,
            final_record,
            expected_raw=journal_raw,
        )
    except BaseException as exc:
        return {
            **receipt,
            "ok": False,
            "status": "committed_journal_finalize_failed",
            "committed": True,
            "journal_error": str(exc),
        }
    return receipt


def _publication_outcome_exit_code(result: Mapping[str, Any]) -> int:
    """Map committed outcomes to stable CLI status without hiding success hazards."""

    status = str(result.get("status") or "")
    if status == "committed" and result.get("ok") is True:
        return 0
    return {
        "committed_lock_retained": 3,
        "committed_receipt_failed": 4,
        "committed_journal_failed": 5,
        "committed_journal_finalize_failed": 5,
    }.get(status, 2)


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

    multi_plan = subparsers.add_parser("multi-plan")
    multi_plan.add_argument("--primary-candidate", type=Path, required=True)
    multi_plan.add_argument("--secondary-candidate", type=Path, required=True)
    multi_plan.add_argument("--generated-at")
    multi_plan.add_argument("--output", type=Path)

    multi_publish = subparsers.add_parser("multi-publish")
    multi_publish.add_argument("--plan", type=Path, required=True)
    multi_publish.add_argument("--expected-plan-sha256", required=True)
    generation = multi_publish.add_mutually_exclusive_group(required=True)
    generation.add_argument("--expected-factory-off-sha256")
    generation.add_argument("--allow-factory-on", action="store_true")
    multi_publish.add_argument("--apply", action="store_true")
    multi_publish.add_argument("--journal-output", type=Path)
    multi_publish.add_argument("--receipt-output", type=Path)

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
        if args.command == "multi-plan":
            policy = _validated_policy(_PRODUCTION_POLICY)
            result = build_multi_principal_publication_plan(
                args.primary_candidate,
                args.secondary_candidate,
                generated_at=args.generated_at,
                _policy=policy,
            )
            if args.output is not None:
                output = _validate_evidence_output(args.output, policy, kind="plan")
                _write_json_atomic_output(output, result)
            print(json.dumps(result, indent=2, sort_keys=True))
            return 0

        if args.command == "multi-publish":
            policy = _validated_policy(_PRODUCTION_POLICY)
            plan_path = _validate_evidence_output(args.plan, policy, kind="plan")
            plan = _read_plan(plan_path)
            if not args.apply:
                if args.journal_output is not None or args.receipt_output is not None:
                    raise NewsCalendarError(
                        "journal/receipt outputs require --apply; WhatIf remains read-only"
                    )
                result = validate_multi_principal_publication(
                    plan,
                    expected_plan_sha256=args.expected_plan_sha256,
                    expected_factory_off_sha256=args.expected_factory_off_sha256,
                    allow_factory_on=args.allow_factory_on,
                    _policy=policy,
                )
                print(json.dumps(result, indent=2, sort_keys=True))
                return 0
            else:
                if args.journal_output is None or args.receipt_output is None:
                    raise NewsCalendarError(
                        "--apply requires both --journal-output and --receipt-output"
                    )
                result = execute_multi_principal_publication(
                    plan,
                    expected_plan_sha256=args.expected_plan_sha256,
                    expected_factory_off_sha256=args.expected_factory_off_sha256,
                    allow_factory_on=args.allow_factory_on,
                    journal_output=args.journal_output,
                    receipt_output=args.receipt_output,
                    _policy=policy,
                )
            print(json.dumps(result, indent=2, sort_keys=True))
            return _publication_outcome_exit_code(result)
    except (NewsCalendarError, OSError, RuntimeError, ValueError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
