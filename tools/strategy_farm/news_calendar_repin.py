"""Receipt-bound news-calendar dependency repinning.

The mutating ``record`` command is intentionally callable only by the regular
``refresh_news_calendar.ps1`` process.  It requires the already-committed
publication receipt and journal, verifies that their bundle contains the exact
active calendar-pair bytes, rejects regressing calendar state, updates only
calendar identity fields in the execution-contract registry, and appends one
create-only canonical SHA-256 receipt to a hash chain.

The public ``verify`` command is read-only.  It checks every receipt, every
link, the live calendar, and the current registry pin end to end.
"""

from __future__ import annotations

import argparse
import copy
import csv
import datetime as dt
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import sys
from typing import Any, Mapping, Sequence


LEGACY_SCHEMA_VERSION = "qm.news-calendar-repin-receipt/v1"
SCHEMA_VERSION = "qm.news-calendar-repin-receipt/v2"
PRIMARY_NAME = "news_calendar_2015_2025.csv"
SECONDARY_NAME = "forex_factory_calendar_clean.csv"
CALENDAR_NAMES = (PRIMARY_NAME, SECONDARY_NAME)
REFRESH_TASK_NAME = "QM_NewsCalendar_Refresh"
OWNER_DECISION_ID = "OWNER-DEC-CALENDAR-REPIN"
OWNER_DECISION_REF = "decisions/2026-08-22_owner_decisions_evening_batch.md#8-owner-dec-calendar-repin"
DEFAULT_CALENDAR = Path(r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv")
DEFAULT_REGISTRY = Path(r"C:\QM\repo\framework\registry\dxz23_execution_contracts.json")
DEFAULT_RECEIPT_DIR = Path(r"D:\QM\reports\news_calendar\repin_receipts")
DEFAULT_BUNDLE_ROOT = Path(r"D:\QM\data\news_calendar\.news_calendar_bundles")
DEFAULT_REFRESH_SCRIPT = Path(r"C:\QM\repo\tools\strategy_farm\refresh_news_calendar.ps1")
DEFAULT_LOCK = Path(r"D:\QM\strategy_farm\state\locks\news_calendar_repin.lock")

_SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
_UTC_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$")
_RECEIPT_NAME_RE = re.compile(r"^(\d{6})_([0-9a-f]{64})\.json$")


def _calendar_object_re(calendar_name: str) -> re.Pattern[str]:
    return re.compile(
        r'\{[^{}]*"path"\s*:\s*"[^"]*'
        + re.escape(calendar_name)
        + r'"[^{}]*\}',
        re.DOTALL,
    )


class RepinError(RuntimeError):
    """A refresh, calendar, registry, receipt, or chain precondition failed."""


def _duplicate_key_guard(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise RepinError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(
            path.read_text(encoding="utf-8"), object_pairs_hook=_duplicate_key_guard
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RepinError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RepinError(f"JSON root must be an object: {path}")
    return value


def _canonical_json_bytes(value: Mapping[str, Any]) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")


def _receipt_hash(receipt: Mapping[str, Any]) -> str:
    unsigned = copy.deepcopy(dict(receipt))
    unsigned.pop("receipt_sha256", None)
    return hashlib.sha256(_canonical_json_bytes(unsigned)).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise RepinError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def _utc_mtime(path: Path) -> str:
    stamp = dt.datetime.fromtimestamp(path.stat().st_mtime, tz=dt.timezone.utc)
    return stamp.strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def _parse_date(raw: str, *, path: Path, row_number: int) -> dt.date:
    text = raw.strip()
    if not text:
        raise RepinError(f"calendar row {row_number} has an empty date: {path}")
    try:
        return dt.date.fromisoformat(text[:10].replace(".", "-"))
    except ValueError as exc:
        raise RepinError(
            f"calendar row {row_number} has invalid date {text!r}: {path}"
        ) from exc


def calendar_state(path: Path, *, allow_empty: bool = False) -> dict[str, Any]:
    if not path.is_file():
        raise RepinError(f"calendar is missing: {path}")
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = {
                str(field).strip().casefold(): str(field)
                for field in (reader.fieldnames or [])
                if field
            }
            date_field = next(
                (
                    fields[name]
                    for name in ("datetime", "datetime_utc", "date")
                    if name in fields
                ),
                None,
            )
            if date_field is None:
                raise RepinError(f"calendar has no supported date column: {path}")
            rows = 0
            earliest: dt.date | None = None
            latest: dt.date | None = None
            for row_number, row in enumerate(reader, start=2):
                value = _parse_date(
                    str(row.get(date_field) or ""), path=path, row_number=row_number
                )
                rows += 1
                earliest = value if earliest is None or value < earliest else earliest
                latest = value if latest is None or value > latest else latest
    except (OSError, UnicodeError, csv.Error) as exc:
        raise RepinError(f"cannot parse calendar {path}: {exc}") from exc
    if rows == 0 and not allow_empty:
        raise RepinError(f"calendar contains no data rows: {path}")
    stat = path.stat()
    return {
        "path": str(path.resolve()),
        "sha256": _sha256_file(path),
        "size_bytes": stat.st_size,
        "row_count": rows,
        "coverage_start": earliest.isoformat() if earliest else None,
        "coverage_end": latest.isoformat() if latest else None,
        "mtime_utc": _utc_mtime(path),
    }


def _is_calendar_record(value: Mapping[str, Any], calendar_name: str) -> bool:
    path = str(value.get("path") or "").replace("\\", "/")
    return path.endswith("/" + calendar_name) and "sha256" in value


def _collect_calendar_records(
    value: Any, calendar_name: str, *, path: str = "$"
) -> list[tuple[str, dict[str, Any]]]:
    records: list[tuple[str, dict[str, Any]]] = []
    if isinstance(value, dict):
        if _is_calendar_record(value, calendar_name):
            records.append((path, value))
        for key, child in value.items():
            records.extend(
                _collect_calendar_records(child, calendar_name, path=f"{path}.{key}")
            )
    elif isinstance(value, list):
        for index, child in enumerate(value):
            records.extend(
                _collect_calendar_records(
                    child, calendar_name, path=f"{path}[{index}]"
                )
            )
    return records


def registry_pin_state(
    registry: Mapping[str, Any], calendar_name: str = PRIMARY_NAME
) -> tuple[str, str | None, str | None, list[str]]:
    records = _collect_calendar_records(registry, calendar_name)
    if not records:
        raise RepinError(
            f"registry has no news-calendar dependency records for {calendar_name}"
        )
    hashes = {str(record.get("sha256") or "") for _, record in records}
    starts = {record.get("coverage_start") for _, record in records}
    ends = {record.get("coverage_end") for _, record in records}
    if len(hashes) != 1 or any(_SHA256_RE.fullmatch(value) is None for value in hashes):
        raise RepinError(
            f"{calendar_name} registry hashes disagree or are invalid: {hashes}"
        )
    if len(starts) != 1 or len(ends) != 1:
        raise RepinError(f"{calendar_name} registry coverage metadata disagrees")
    start = next(iter(starts))
    end = next(iter(ends))
    for name, value in (("coverage_start", start), ("coverage_end", end)):
        if value is not None:
            try:
                dt.date.fromisoformat(str(value))
            except ValueError as exc:
                raise RepinError(f"registry {name} is invalid: {value!r}") from exc
    return next(iter(hashes)), start, end, [path for path, _ in records]


def _json_leaf_diffs(before: Any, after: Any, *, path: str = "$") -> list[str]:
    if type(before) is not type(after):
        return [path]
    if isinstance(before, dict):
        if set(before) != set(after):
            return [path]
        diffs: list[str] = []
        for key in before:
            diffs.extend(_json_leaf_diffs(before[key], after[key], path=f"{path}.{key}"))
        return diffs
    if isinstance(before, list):
        if len(before) != len(after):
            return [path]
        diffs: list[str] = []
        for index, (left, right) in enumerate(zip(before, after)):
            diffs.extend(_json_leaf_diffs(left, right, path=f"{path}[{index}]"))
        return diffs
    return [] if before == after else [path]


def render_registry_update(
    raw: bytes,
    *,
    calendar_name: str = PRIMARY_NAME,
    old_hash: str,
    new_hash: str,
    old_start: str | None,
    new_start: str,
    old_end: str | None,
    new_end: str,
    target_paths: Sequence[str],
) -> bytes:
    try:
        text = raw.decode("utf-8")
        before = json.loads(text, object_pairs_hook=_duplicate_key_guard)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise RepinError(f"registry is not valid UTF-8 JSON: {exc}") from exc
    replacements = 0

    def replace_object(match: re.Match[str]) -> str:
        nonlocal replacements
        original = match.group(0)
        try:
            record = json.loads(original, object_pairs_hook=_duplicate_key_guard)
        except json.JSONDecodeError as exc:
            raise RepinError(f"cannot parse primary dependency object: {exc}") from exc
        if not _is_calendar_record(record, calendar_name):
            return original
        if record.get("sha256") != old_hash:
            raise RepinError(
                f"{calendar_name} dependency object changed during registry rendering"
            )
        if record.get("coverage_start") != old_start or record.get("coverage_end") != old_end:
            raise RepinError(
                f"{calendar_name} dependency coverage changed during registry rendering"
            )
        updated, hash_count = re.subn(
            r'("sha256"\s*:\s*")' + re.escape(old_hash) + r'(")',
            lambda found: found.group(1) + new_hash + found.group(2),
            original,
            count=1,
        )
        if hash_count != 1:
            raise RepinError(
                f"{calendar_name} dependency hash token was not replaced exactly once"
            )
        if old_start != new_start:
            if old_start is None:
                updated, start_count = re.subn(
                    r'("coverage_start"\s*:\s*)null',
                    lambda found: found.group(1) + json.dumps(new_start),
                    updated,
                    count=1,
                )
            else:
                updated, start_count = re.subn(
                    r'("coverage_start"\s*:\s*")' + re.escape(old_start) + r'(")',
                    lambda found: found.group(1) + new_start + found.group(2),
                    updated,
                    count=1,
                )
            if start_count != 1:
                raise RepinError(
                    f"{calendar_name} dependency coverage_start was not replaced once"
                )
        if old_end != new_end:
            if old_end is None:
                updated, end_count = re.subn(
                    r'("coverage_end"\s*:\s*)null',
                    lambda found: found.group(1) + json.dumps(new_end),
                    updated,
                    count=1,
                )
            else:
                updated, end_count = re.subn(
                    r'("coverage_end"\s*:\s*")' + re.escape(old_end) + r'(")',
                    lambda found: found.group(1) + new_end + found.group(2),
                    updated,
                    count=1,
                )
            if end_count != 1:
                raise RepinError(
                    f"{calendar_name} dependency coverage_end was not replaced once"
                )
        replacements += 1
        return updated

    updated_text = _calendar_object_re(calendar_name).sub(replace_object, text)
    if replacements != len(target_paths):
        raise RepinError(
            f"registry target count changed: parsed={len(target_paths)} rendered={replacements}"
        )
    try:
        after = json.loads(updated_text, object_pairs_hook=_duplicate_key_guard)
    except json.JSONDecodeError as exc:
        raise RepinError(f"rendered registry is invalid JSON: {exc}") from exc
    allowed = {
        f"{path}.{field}"
        for path in target_paths
        for field in ("sha256", "coverage_start", "coverage_end")
    }
    diffs = set(_json_leaf_diffs(before, after))
    expected = {f"{path}.sha256" for path in target_paths}
    if old_start != new_start:
        expected.update(f"{path}.coverage_start" for path in target_paths)
    if old_end != new_end:
        expected.update(f"{path}.coverage_end" for path in target_paths)
    if diffs != expected or not diffs.issubset(allowed):
        raise RepinError(
            f"registry update escaped the calendar identity fields: diffs={sorted(diffs)}"
        )
    new_pin, start, end, paths = registry_pin_state(after, calendar_name)
    if (new_pin, start, end, paths) != (new_hash, new_start, new_end, list(target_paths)):
        raise RepinError("rendered registry does not carry the expected new calendar identity")
    return updated_text.encode("utf-8")


def _same_path(left: str | Path, right: str | Path) -> bool:
    return os.path.normcase(str(Path(left).resolve())) == os.path.normcase(
        str(Path(right).resolve())
    )


def validate_publication_proof(
    *,
    publication_receipt_path: Path,
    publication_journal_path: Path,
    calendar_path: Path,
    refresh_script_path: Path,
    expected_operation_id: str,
) -> tuple[dict[str, Any], dict[str, Any]]:
    receipt = _read_json(publication_receipt_path)
    journal = _read_json(publication_journal_path)
    if _SHA256_RE.fullmatch(expected_operation_id) is None:
        raise RepinError("refresh operation id is not a SHA-256 identifier")
    required_receipt = {
        "ok": True,
        "status": "committed",
        "published": True,
        "committed": True,
        "lock_release_succeeded": True,
    }
    for field, expected in required_receipt.items():
        if receipt.get(field) != expected:
            raise RepinError(f"publication receipt {field} is not {expected!r}")
    if journal.get("committed") is not True or journal.get("state") != "COMMITTED_RECEIPTED":
        raise RepinError("publication journal is not a receipted commit")
    for field in ("operation_id", "plan_sha256", "bundle_id"):
        if not receipt.get(field) or receipt.get(field) != journal.get(field):
            raise RepinError(f"publication receipt/journal {field} mismatch")
    if receipt.get("operation_id") != expected_operation_id:
        raise RepinError("publication operation id does not match refresh process context")
    if not _same_path(receipt.get("receipt_path", ""), publication_receipt_path):
        raise RepinError("publication receipt path is not self-bound")
    if not _same_path(journal.get("receipt_path", ""), publication_receipt_path):
        raise RepinError("publication journal points to another receipt")
    if not _same_path(receipt.get("journal_path", ""), publication_journal_path):
        raise RepinError("publication receipt points to another journal")
    if not _same_path(journal.get("source_dir", ""), calendar_path.parent):
        raise RepinError("publication journal source directory differs from active calendar")
    provenance = journal.get("provenance")
    if not isinstance(provenance, dict):
        raise RepinError("publication journal has no provenance object")
    provenance_kind = provenance.get("kind")
    test_provenance_allowed = (
        os.environ.get("QM_CALENDAR_REPIN_TEST_MODE") == "1"
        and provenance_kind == "test-injected-refresh-script"
    )
    if provenance_kind != "scheduled-refresh-script" and not test_provenance_allowed:
        raise RepinError("publication was not produced by the scheduled refresh script")
    if not _same_path(provenance.get("path", ""), refresh_script_path):
        raise RepinError("publication provenance points to another refresh script")
    if provenance.get("sha256") != _sha256_file(refresh_script_path):
        raise RepinError("publication refresh-script hash does not match current bytes")
    bundle_dirs = receipt.get("bundle_dirs")
    if not isinstance(bundle_dirs, dict):
        raise RepinError("publication receipt has no bundle directory map")
    source_bundle: Path | None = None
    for source, bundle in bundle_dirs.items():
        if _same_path(source, calendar_path.parent):
            source_bundle = Path(str(bundle))
            break
    if source_bundle is None:
        raise RepinError("publication receipt has no source-calendar bundle")
    for calendar_name in CALENDAR_NAMES:
        active_calendar = calendar_path.parent / calendar_name
        bundled_calendar = source_bundle / calendar_name
        if not bundled_calendar.is_file():
            raise RepinError(
                f"published source bundle is missing the calendar: {bundled_calendar}"
            )
        if _sha256_file(bundled_calendar) != _sha256_file(active_calendar):
            raise RepinError(
                f"active {calendar_name} bytes differ from the committed publication bundle"
            )
    preflights = receipt.get("preflights")
    if not isinstance(preflights, list) or not preflights:
        raise RepinError("publication receipt has no principal preflight evidence")
    for preflight in preflights:
        if not isinstance(preflight, dict) or preflight.get("ok") is not True:
            raise RepinError("publication receipt contains a failed principal preflight")
        if preflight.get("mismatches") or preflight.get("missing_common_paths"):
            raise RepinError("publication receipt contains copy drift")
    return receipt, journal


def _validate_calendar_state(
    state: Any, *, label: str, path: Path
) -> Mapping[str, Any]:
    if not isinstance(state, dict):
        raise RepinError(f"receipt {label} is not an object: {path}")
    if _SHA256_RE.fullmatch(str(state.get("sha256") or "")) is None:
        raise RepinError(f"receipt {label} hash is invalid: {path}")
    if not isinstance(state.get("row_count"), int) or state["row_count"] < 0:
        raise RepinError(f"receipt {label} row count is invalid: {path}")
    for field in ("coverage_start", "coverage_end"):
        value = state.get(field)
        if value is not None:
            try:
                dt.date.fromisoformat(str(value))
            except ValueError as exc:
                raise RepinError(
                    f"receipt {label} {field} is invalid: {path}"
                ) from exc
    return state


def _receipt_source_transitions(
    receipt: Mapping[str, Any], *, path: Path
) -> list[tuple[str, Mapping[str, Any], Mapping[str, Any]]]:
    if receipt.get("schema_version") == LEGACY_SCHEMA_VERSION:
        return [
            (
                PRIMARY_NAME,
                _validate_calendar_state(receipt.get("before"), label="before", path=path),
                _validate_calendar_state(receipt.get("after"), label="after", path=path),
            )
        ]
    sources = receipt.get("sources")
    if not isinstance(sources, list) or len(sources) != len(CALENDAR_NAMES):
        raise RepinError(f"receipt calendar source set is incomplete: {path}")
    transitions: list[tuple[str, Mapping[str, Any], Mapping[str, Any]]] = []
    seen: set[str] = set()
    for index, source in enumerate(sources):
        if not isinstance(source, dict) or set(source) != {
            "name",
            "before",
            "after",
            "registry_target_json_paths",
        }:
            raise RepinError(f"receipt source shape is invalid at index {index}: {path}")
        name = str(source.get("name") or "")
        if name not in CALENDAR_NAMES or name in seen:
            raise RepinError(f"receipt source name is invalid or duplicated: {path}")
        targets = source.get("registry_target_json_paths")
        if (
            not isinstance(targets, list)
            or not targets
            or any(not isinstance(value, str) or not value for value in targets)
        ):
            raise RepinError(f"receipt source targets are invalid: {path}")
        seen.add(name)
        transitions.append(
            (
                name,
                _validate_calendar_state(
                    source.get("before"), label=f"sources[{index}].before", path=path
                ),
                _validate_calendar_state(
                    source.get("after"), label=f"sources[{index}].after", path=path
                ),
            )
        )
    if seen != set(CALENDAR_NAMES):
        raise RepinError(f"receipt calendar source names are incomplete: {path}")
    return transitions


def _validate_receipt_shape(receipt: Mapping[str, Any], *, path: Path) -> None:
    common = {
        "schema_version",
        "sequence",
        "receipt_id",
        "previous_receipt_sha256",
        "registry",
        "refresh",
        "authority",
        "signer",
        "created_at_utc",
        "receipt_sha256",
    }
    schema = receipt.get("schema_version")
    expected = (
        common | {"before", "after"}
        if schema == LEGACY_SCHEMA_VERSION
        else common | {"sources"}
    )
    if schema not in {LEGACY_SCHEMA_VERSION, SCHEMA_VERSION}:
        raise RepinError(f"unsupported receipt schema: {path}")
    if set(receipt) != expected:
        raise RepinError(f"receipt key set mismatch: {path}")
    if not isinstance(receipt.get("sequence"), int) or receipt["sequence"] < 1:
        raise RepinError(f"invalid receipt sequence: {path}")
    if _SHA256_RE.fullmatch(str(receipt.get("receipt_id") or "")) is None:
        raise RepinError(f"invalid receipt_id: {path}")
    previous = receipt.get("previous_receipt_sha256")
    if previous is not None and _SHA256_RE.fullmatch(str(previous)) is None:
        raise RepinError(f"invalid previous receipt hash: {path}")
    if _SHA256_RE.fullmatch(str(receipt.get("receipt_sha256") or "")) is None:
        raise RepinError(f"invalid receipt hash: {path}")
    if not hmac.compare_digest(str(receipt["receipt_sha256"]), _receipt_hash(receipt)):
        raise RepinError(f"receipt signature mismatch: {path}")
    if _UTC_RE.fullmatch(str(receipt.get("created_at_utc") or "")) is None:
        raise RepinError(f"invalid receipt timestamp: {path}")
    _receipt_source_transitions(receipt, path=path)
    authority = receipt.get("authority")
    if not isinstance(authority, dict) or authority.get("decision_id") != OWNER_DECISION_ID:
        raise RepinError(f"receipt lacks OWNER decision binding: {path}")
    signer = receipt.get("signer")
    if not isinstance(signer, dict) or signer.get("kind") != "scheduled-refresh-script":
        raise RepinError(f"receipt signer is invalid: {path}")


def load_receipt_chain(receipt_dir: Path) -> list[tuple[Path, dict[str, Any]]]:
    if not receipt_dir.exists():
        return []
    if not receipt_dir.is_dir():
        raise RepinError(f"receipt path is not a directory: {receipt_dir}")
    files = sorted(receipt_dir.glob("*.json"), key=lambda item: item.name)
    chain: list[tuple[Path, dict[str, Any]]] = []
    previous: str | None = None
    previous_after: dict[str, Mapping[str, Any]] = {}
    for expected_sequence, path in enumerate(files, start=1):
        match = _RECEIPT_NAME_RE.fullmatch(path.name)
        if match is None or int(match.group(1)) != expected_sequence:
            raise RepinError(f"receipt chain has a missing or invalid sequence at {path.name}")
        receipt = _read_json(path)
        _validate_receipt_shape(receipt, path=path)
        if receipt["sequence"] != expected_sequence:
            raise RepinError(f"receipt payload sequence disagrees with filename: {path}")
        if receipt["receipt_id"] != match.group(2):
            raise RepinError(f"receipt id disagrees with filename: {path}")
        if receipt["previous_receipt_sha256"] != previous:
            raise RepinError(f"receipt chain link is broken: {path}")
        for name, before, after in _receipt_source_transitions(receipt, path=path):
            if name in previous_after:
                for field in ("sha256", "row_count", "coverage_start", "coverage_end"):
                    if before.get(field) != previous_after[name].get(field):
                        raise RepinError(
                            f"receipt state continuity broke at {path}: {name}.{field}"
                        )
            previous_after[name] = after
        previous = receipt["receipt_sha256"]
        chain.append((path, receipt))
    return chain


def _chain_tail_states(
    chain: Sequence[tuple[Path, Mapping[str, Any]]]
) -> dict[str, tuple[Path, Mapping[str, Any]]]:
    states: dict[str, tuple[Path, Mapping[str, Any]]] = {}
    for path, receipt in chain:
        for name, _before, after in _receipt_source_transitions(receipt, path=path):
            states[name] = (path, after)
    return states


def _find_prior_calendar(
    bundle_root: Path, calendar_name: str, expected_hash: str
) -> Path:
    if not bundle_root.is_dir():
        raise RepinError(f"bundle archive is missing: {bundle_root}")
    matches = [
        path
        for path in bundle_root.rglob(calendar_name)
        if path.is_file() and _sha256_file(path) == expected_hash
    ]
    if not matches:
        raise RepinError(
            f"cannot reconstruct the currently pinned {calendar_name} "
            f"{expected_hash} from {bundle_root}"
        )
    return sorted(matches, key=lambda item: str(item).casefold())[0]


def _assert_plausible(before: Mapping[str, Any], after: Mapping[str, Any]) -> None:
    if int(after["row_count"]) <= 0:
        raise RepinError("refusing to repin an empty calendar")
    if int(after["row_count"]) < int(before["row_count"]):
        raise RepinError(
            f"calendar row count shrank: {before['row_count']} -> {after['row_count']}"
        )
    before_start = before.get("coverage_start")
    after_start = after.get("coverage_start")
    before_end = before.get("coverage_end")
    after_end = after.get("coverage_end")
    if not after_start or not after_end:
        raise RepinError("refusing to repin a calendar without date coverage")
    if before_start and dt.date.fromisoformat(str(after_start)) > dt.date.fromisoformat(
        str(before_start)
    ):
        raise RepinError(f"calendar coverage start moved forward: {before_start} -> {after_start}")
    if before_end and dt.date.fromisoformat(str(after_end)) < dt.date.fromisoformat(
        str(before_end)
    ):
        raise RepinError(f"calendar coverage end moved backward: {before_end} -> {after_end}")


def _write_create_only(path: Path, payload: bytes) -> None:
    if not path.parent.is_dir():
        path.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    try:
        descriptor = os.open(path, flags, 0o600)
    except FileExistsError as exc:
        raise RepinError(f"refusing to overwrite receipt: {path}") from exc
    try:
        with os.fdopen(descriptor, "wb") as handle:
            descriptor = -1
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def _atomic_replace(path: Path, *, expected_before: bytes, after: bytes) -> None:
    temporary = path.with_name(f".{path.name}.tmp.{os.getpid()}")
    try:
        _write_create_only(temporary, after)
        if path.read_bytes() != expected_before:
            raise RepinError("registry changed before atomic replacement")
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def _acquire_lock(path: Path) -> int:
    if not path.parent.is_dir():
        raise RepinError(f"repin lock directory is missing: {path.parent}")
    payload = (_canonical_json_bytes({"pid": os.getpid(), "created_at_utc": _utc_now()}) + b"\n")
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
    try:
        descriptor = os.open(path, flags, 0o600)
    except FileExistsError as exc:
        raise RepinError(f"repin lock is already held: {path}") from exc
    os.write(descriptor, payload)
    os.fsync(descriptor)
    return descriptor


def _release_lock(path: Path, descriptor: int) -> None:
    os.close(descriptor)
    try:
        path.unlink()
    except FileNotFoundError:
        pass


def verify_chain(
    *, receipt_dir: Path, registry_path: Path, calendar_path: Path
) -> dict[str, Any]:
    chain = load_receipt_chain(receipt_dir)
    if not chain:
        raise RepinError("receipt chain is empty")
    registry = _read_json(registry_path)
    tail_states = _chain_tail_states(chain)
    tail_path, tail = chain[-1]
    calendars: dict[str, Any] = {}
    target_count = 0
    for calendar_name in CALENDAR_NAMES:
        if calendar_name not in tail_states:
            raise RepinError(
                f"receipt chain has no binding for current calendar {calendar_name}"
            )
        current = calendar_state(calendar_path.parent / calendar_name)
        _source_receipt_path, tail_after = tail_states[calendar_name]
        for field, actual in (
            ("sha256", current["sha256"]),
            ("row_count", current["row_count"]),
            ("coverage_start", current["coverage_start"]),
            ("coverage_end", current["coverage_end"]),
        ):
            if tail_after.get(field) != actual:
                raise RepinError(
                    f"receipt tail does not match current {calendar_name}: {field}"
                )
        pin_hash, pin_start, pin_end, target_paths = registry_pin_state(
            registry, calendar_name
        )
        if (pin_hash, pin_start, pin_end) != (
            current["sha256"],
            current["coverage_start"],
            current["coverage_end"],
        ):
            raise RepinError(
                f"current registry pin does not match receipt-chain tail/{calendar_name}"
            )
        target_count += len(target_paths)
        calendars[calendar_name] = {
            "sha256": current["sha256"],
            "row_count": current["row_count"],
            "coverage_start": current["coverage_start"],
            "coverage_end": current["coverage_end"],
            "registry_target_count": len(target_paths),
        }
    primary = calendars[PRIMARY_NAME]
    return {
        "ok": True,
        "status": "PASS",
        "schema_version": SCHEMA_VERSION,
        "receipt_count": len(chain),
        "tail_receipt": str(tail_path.resolve()),
        "tail_receipt_sha256": tail["receipt_sha256"],
        "calendar_sha256": primary["sha256"],
        "calendar_row_count": primary["row_count"],
        "coverage_start": primary["coverage_start"],
        "coverage_end": primary["coverage_end"],
        "calendars": calendars,
        "registry_target_count": target_count,
        "registry_pin_matches": True,
    }


def record_repin(
    *,
    publication_receipt_path: Path,
    publication_journal_path: Path,
    calendar_path: Path,
    registry_path: Path,
    receipt_dir: Path,
    bundle_root: Path,
    refresh_script_path: Path,
    lock_path: Path,
    expected_operation_id: str,
    reason: str,
) -> dict[str, Any]:
    if not reason or reason != reason.strip():
        raise RepinError("repin reason must be a non-blank trimmed string")
    descriptor = _acquire_lock(lock_path)
    try:
        publication_receipt, publication_journal = validate_publication_proof(
            publication_receipt_path=publication_receipt_path,
            publication_journal_path=publication_journal_path,
            calendar_path=calendar_path,
            refresh_script_path=refresh_script_path,
            expected_operation_id=expected_operation_id,
        )
        registry_before_bytes = registry_path.read_bytes()
        registry_before_sha = hashlib.sha256(registry_before_bytes).hexdigest()
        registry_before = _read_json(registry_path)
        chain = load_receipt_chain(receipt_dir)
        tail_states = _chain_tail_states(chain)
        if chain:
            previous_receipt = chain[-1][1]
            previous_hash = previous_receipt["receipt_sha256"]
            sequence = previous_receipt["sequence"] + 1
        else:
            previous_hash = None
            sequence = 1

        source_states: dict[str, dict[str, Any]] = {}
        changed_names: list[str] = []
        for calendar_name in CALENDAR_NAMES:
            old_hash, old_start, old_end, target_paths = registry_pin_state(
                registry_before, calendar_name
            )
            after = calendar_state(calendar_path.parent / calendar_name)
            if calendar_name in tail_states:
                source_receipt_path, previous_after = tail_states[calendar_name]
                if (
                    previous_after.get("sha256"),
                    previous_after.get("coverage_start"),
                    previous_after.get("coverage_end"),
                ) != (old_hash, old_start, old_end):
                    raise RepinError(
                        f"{calendar_name} registry pin does not continue from "
                        "the receipt-chain tail"
                    )
                before = {
                    **dict(previous_after),
                    "source": str(source_receipt_path.resolve()),
                }
            else:
                prior_path = _find_prior_calendar(
                    bundle_root, calendar_name, old_hash
                )
                before = {
                    **calendar_state(prior_path, allow_empty=True),
                    "source": str(prior_path.resolve()),
                }
            if (before.get("coverage_start"), before.get("coverage_end")) != (
                old_start,
                old_end,
            ):
                raise RepinError(
                    f"reconstructed pinned {calendar_name} coverage differs from registry"
                )
            _assert_plausible(before, after)
            changed = (old_hash, old_start, old_end) != (
                after["sha256"],
                after["coverage_start"],
                after["coverage_end"],
            )
            if changed:
                changed_names.append(calendar_name)
            source_states[calendar_name] = {
                "before": before,
                "after": after,
                "old_hash": old_hash,
                "old_start": old_start,
                "old_end": old_end,
                "target_paths": target_paths,
                "changed": changed,
            }

        full_pair_already_bound = set(CALENDAR_NAMES).issubset(tail_states)
        if not changed_names and full_pair_already_bound:
            verify_chain(
                receipt_dir=receipt_dir,
                registry_path=registry_path,
                calendar_path=calendar_path,
            )
            return {
                "ok": True,
                "status": "NO_CHANGE",
                "calendar_sha256": source_states[PRIMARY_NAME]["after"]["sha256"],
                "receipt_written": False,
                "registry_updated": False,
            }

        registry_after_bytes = registry_before_bytes
        for calendar_name in changed_names:
            state = source_states[calendar_name]
            after = state["after"]
            registry_after_bytes = render_registry_update(
                registry_after_bytes,
                calendar_name=calendar_name,
                old_hash=state["old_hash"],
                new_hash=after["sha256"],
                old_start=state["old_start"],
                new_start=str(after["coverage_start"]),
                old_end=state["old_end"],
                new_end=str(after["coverage_end"]),
                target_paths=state["target_paths"],
            )
        registry_after_sha = hashlib.sha256(registry_after_bytes).hexdigest()
        receipt: dict[str, Any] = {
            "schema_version": SCHEMA_VERSION,
            "sequence": sequence,
            "receipt_id": expected_operation_id,
            "previous_receipt_sha256": previous_hash,
            "sources": [
                {
                    "name": calendar_name,
                    "before": source_states[calendar_name]["before"],
                    "after": source_states[calendar_name]["after"],
                    "registry_target_json_paths": source_states[calendar_name][
                        "target_paths"
                    ],
                }
                for calendar_name in CALENDAR_NAMES
            ],
            "registry": {
                "path": str(registry_path.resolve()),
                "changed_source_names": changed_names,
                "changed_target_json_paths": {
                    calendar_name: source_states[calendar_name]["target_paths"]
                    for calendar_name in changed_names
                },
                "changed_target_count": sum(
                    len(source_states[calendar_name]["target_paths"])
                    for calendar_name in changed_names
                ),
                "before_file_sha256": registry_before_sha,
                "after_file_sha256": registry_after_sha,
                "changed_fields": ["sha256", "coverage_start", "coverage_end"],
                "policy_or_threshold_changes": 0,
            },
            "refresh": {
                "task_name": REFRESH_TASK_NAME,
                "operation_id": expected_operation_id,
                "publication_receipt_path": str(publication_receipt_path.resolve()),
                "publication_receipt_sha256": _sha256_file(publication_receipt_path),
                "publication_journal_path": str(publication_journal_path.resolve()),
                "publication_journal_sha256": _sha256_file(publication_journal_path),
                "plan_sha256": publication_receipt["plan_sha256"],
                "bundle_id": publication_receipt["bundle_id"],
                "journal_state": publication_journal["state"],
                "reason": reason,
            },
            "authority": {
                "authority": "OWNER",
                "decision_id": OWNER_DECISION_ID,
                "decision_ref": OWNER_DECISION_REF,
                "authorized_scope": "calendar_dependency_identity_repin_only",
            },
            "signer": {
                "kind": "scheduled-refresh-script",
                "path": str(refresh_script_path.resolve()),
                "sha256": _sha256_file(refresh_script_path),
                "signature_algorithm": "SHA256_CANONICAL_JSON_CHAIN_V1",
            },
            "created_at_utc": _utc_now(),
        }
        receipt["receipt_sha256"] = _receipt_hash(receipt)
        receipt_path = receipt_dir / f"{sequence:06d}_{expected_operation_id}.json"
        receipt_bytes = json.dumps(
            receipt, ensure_ascii=False, sort_keys=True, indent=2
        ).encode("utf-8") + b"\n"
        _write_create_only(receipt_path, receipt_bytes)
        try:
            _atomic_replace(
                registry_path,
                expected_before=registry_before_bytes,
                after=registry_after_bytes,
            )
        except Exception:
            if receipt_path.is_file() and receipt_path.read_bytes() == receipt_bytes:
                receipt_path.unlink()
            raise
        immediate_registry_hash = _sha256_file(registry_path)
        if immediate_registry_hash != registry_after_sha:
            raise RepinError("registry bytes differ immediately after atomic replacement")
        verified = verify_chain(
            receipt_dir=receipt_dir,
            registry_path=registry_path,
            calendar_path=calendar_path,
        )
        return {
            "ok": True,
            "status": "REPINNED",
            "old_sha256": source_states[PRIMARY_NAME]["old_hash"],
            "new_sha256": source_states[PRIMARY_NAME]["after"]["sha256"],
            "row_count": source_states[PRIMARY_NAME]["after"]["row_count"],
            "coverage_start": source_states[PRIMARY_NAME]["after"]["coverage_start"],
            "coverage_end": source_states[PRIMARY_NAME]["after"]["coverage_end"],
            "changed_source_names": changed_names,
            "registry_target_count": sum(
                len(source_states[calendar_name]["target_paths"])
                for calendar_name in changed_names
            ),
            "registry_updated": bool(changed_names),
            "receipt_written": True,
            "receipt_path": str(receipt_path.resolve()),
            "receipt_sha256": receipt["receipt_sha256"],
            "chain_verification": verified["status"],
        }
    finally:
        _release_lock(lock_path, descriptor)


def _require_refresh_parent(expected_operation_id: str) -> None:
    parent = os.environ.get("QM_NEWS_CALENDAR_REFRESH_PARENT_PID", "")
    operation = os.environ.get("QM_NEWS_CALENDAR_REFRESH_OPERATION_ID", "")
    if not parent.isdigit() or int(parent) != os.getppid():
        raise RepinError(
            "record is internal to the live refresh process; parent-process proof is absent"
        )
    if operation != expected_operation_id:
        raise RepinError("refresh operation proof is absent or mismatched")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    record = subparsers.add_parser(
        "record", help="internal: repin from one committed refresh publication"
    )
    record.add_argument("--publication-receipt", type=Path, required=True)
    record.add_argument("--publication-journal", type=Path, required=True)
    record.add_argument("--calendar", type=Path, default=DEFAULT_CALENDAR)
    record.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    record.add_argument("--receipt-dir", type=Path, default=DEFAULT_RECEIPT_DIR)
    record.add_argument("--bundle-root", type=Path, default=DEFAULT_BUNDLE_ROOT)
    record.add_argument("--refresh-script", type=Path, default=DEFAULT_REFRESH_SCRIPT)
    record.add_argument("--lock", type=Path, default=DEFAULT_LOCK)
    record.add_argument("--operation-id", required=True)
    record.add_argument("--reason", required=True)

    verify = subparsers.add_parser("verify", help="verify the receipt chain read-only")
    verify.add_argument("--calendar", type=Path, default=DEFAULT_CALENDAR)
    verify.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    verify.add_argument("--receipt-dir", type=Path, default=DEFAULT_RECEIPT_DIR)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "verify":
            result = verify_chain(
                receipt_dir=args.receipt_dir,
                registry_path=args.registry,
                calendar_path=args.calendar,
            )
        else:
            _require_refresh_parent(args.operation_id)
            result = record_repin(
                publication_receipt_path=args.publication_receipt,
                publication_journal_path=args.publication_journal,
                calendar_path=args.calendar,
                registry_path=args.registry,
                receipt_dir=args.receipt_dir,
                bundle_root=args.bundle_root,
                refresh_script_path=args.refresh_script,
                lock_path=args.lock,
                expected_operation_id=args.operation_id,
                reason=args.reason,
            )
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (RepinError, OSError, ValueError, TypeError) as exc:
        print(json.dumps({"ok": False, "status": "REFUSED", "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
