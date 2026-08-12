#!/usr/bin/env python3
"""Provision the frozen WS30.DWX research corpus from T1 to DEV2.

This is an offline, byte-exact historical research transport.  It never starts
MT5, never touches T6, never edits a symbol/alias registry, and never claims
broker/live-parity validation.  A successful receipt means only that the exact
preregistered 8 HCC and 90 TKC files were copied as independent files and that
the ordered source/target byte ledger passed the bound WS30 auditor.

The production CLI has no path overrides.  Tests may monkeypatch the module
constants, but a real invocation is pinned to the T1, DEV2 and evidence paths
in ``audit_tv_nq_ict_ob_ws30.py``.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import stat
import sys
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
AUDITOR_PATH = TOOL_PATH.with_name("audit_tv_nq_ict_ob_ws30.py")

_AUDITOR_SPEC = importlib.util.spec_from_file_location(
    "qm10834_ws30_provision_bound_auditor", AUDITOR_PATH
)
if _AUDITOR_SPEC is None or _AUDITOR_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load bound WS30 auditor: {AUDITOR_PATH}")
A = importlib.util.module_from_spec(_AUDITOR_SPEC)
sys.modules[_AUDITOR_SPEC.name] = A
_AUDITOR_SPEC.loader.exec_module(A)


SYMBOL = "WS30.DWX"
SOURCE_DATA_ROOT = Path(r"D:\QM\mt5\T1\Bases\Custom")
TARGET_DATA_ROOT = Path(r"D:\QM\mt5\DEV2\Bases\Custom")
EVIDENCE_ROOT = Path(
    r"D:\QM\reports\setup\tick-data-timezone\WS30.DWX_DEV2_TRANSPORT_001"
)
MANIFEST_PATH = EVIDENCE_ROOT / "provision_manifest.json"
RECEIPT_PATH = EVIDENCE_ROOT / "provision_receipt.json"
COPY_CHUNK_BYTES = 4 * 1024 * 1024
HISTORY_PERIODS = tuple(str(year) for year in range(2018, 2026))
TICK_PERIODS = tuple(
    f"{year}{month:02d}"
    for year in range(2018, 2026)
    for month in range(1, 13)
    if (year, month) >= (2018, 7)
)
EXPECTED_FILE_ORDER = (
    *(("history", period) for period in HISTORY_PERIODS),
    *(("ticks", period) for period in TICK_PERIODS),
)
EXPECTED_COVERAGE = {
    "from_date": "2018-07-02",
    "to_date": "2025-12-31",
    "history_year_first": 2018,
    "history_year_last": 2025,
    "history_file_count": 8,
    "tick_month_first": "201807",
    "tick_month_last": "202512",
    "tick_file_count": 90,
}
OUTCOME_FENCE = {
    "mt5_terminal_started": False,
    "metatester_started": False,
    "native_reports_opened": False,
    "strategy_outcomes_read": False,
}
SYMBOL_VALIDATION_STATUS = "FAIL_RESEARCH_HISTORICAL_ONLY"


class ProvisionError(RuntimeError):
    """The offline transport cannot produce trustworthy evidence."""


@dataclass(frozen=True)
class FileIdentity:
    device: int
    inode: int
    size: int
    mtime_ns: int
    ctime_ns: int
    links: int


@dataclass(frozen=True)
class DirectoryIdentity:
    device: int
    inode: int


@dataclass(frozen=True)
class SourceSnapshot:
    kind: str
    period: str
    source_path: Path
    target_path: Path
    identity: FileIdentity


def _utc_text(value: datetime | None = None) -> str:
    observed = value or datetime.now(timezone.utc)
    if observed.tzinfo is None:
        raise ProvisionError("UTC evidence timestamp must be timezone-aware")
    return observed.astimezone(timezone.utc).isoformat(timespec="microseconds").replace(
        "+00:00", "Z"
    )


def _lexical_path(path: Path | str) -> Path:
    return Path(os.path.abspath(os.path.normpath(os.fspath(path))))


def _path_is_reparse(path: Path) -> bool:
    try:
        observed = os.lstat(path)
    except OSError:
        return False
    attributes = int(getattr(observed, "st_file_attributes", 0))
    reparse_flag = int(getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))
    return stat.S_ISLNK(observed.st_mode) or bool(attributes & reparse_flag)


def _assert_no_reparse_components(path: Path | str, label: str) -> Path:
    lexical = _lexical_path(path)
    for component in reversed((lexical, *lexical.parents)):
        if os.path.lexists(component) and _path_is_reparse(component):
            raise ProvisionError(f"{label} contains a reparse component: {component}")
    return lexical


def _identity_from_stat(observed: os.stat_result) -> FileIdentity:
    return FileIdentity(
        device=int(observed.st_dev),
        inode=int(observed.st_ino),
        size=int(observed.st_size),
        mtime_ns=int(observed.st_mtime_ns),
        ctime_ns=int(observed.st_ctime_ns),
        links=int(observed.st_nlink),
    )


def _regular_file_identity(path: Path | str, label: str) -> tuple[Path, FileIdentity]:
    lexical = _assert_no_reparse_components(path, label)
    try:
        observed = os.lstat(lexical)
    except OSError as exc:
        raise ProvisionError(f"missing {label}: {lexical}") from exc
    if not stat.S_ISREG(observed.st_mode):
        raise ProvisionError(f"{label} is not a regular file: {lexical}")
    identity = _identity_from_stat(observed)
    if identity.size <= 0:
        raise ProvisionError(f"{label} is empty: {lexical}")
    if identity.links != 1:
        raise ProvisionError(
            f"{label} has forbidden hardlink count {identity.links}: {lexical}"
        )
    return lexical, identity


def _directory_identity(
    path: Path | str,
    label: str,
    expected: DirectoryIdentity | None = None,
) -> tuple[Path, DirectoryIdentity]:
    lexical = _assert_no_reparse_components(path, label)
    try:
        observed = os.lstat(lexical)
    except OSError as exc:
        raise ProvisionError(f"missing {label}: {lexical}") from exc
    if not stat.S_ISDIR(observed.st_mode):
        raise ProvisionError(f"{label} is not a directory: {lexical}")
    identity = DirectoryIdentity(int(observed.st_dev), int(observed.st_ino))
    if expected is not None and identity != expected:
        raise ProvisionError(f"{label} directory identity changed: {lexical}")
    return lexical, identity


def _assert_absent(path: Path | str, label: str) -> Path:
    lexical = _lexical_path(path)
    _assert_no_reparse_components(lexical.parent, f"{label} parent")
    if os.path.lexists(lexical):
        raise ProvisionError(f"{label} already exists; refusing to replace: {lexical}")
    return lexical


def _mkdir_exclusive(path: Path | str, label: str) -> tuple[Path, DirectoryIdentity]:
    lexical = _assert_absent(path, label)
    parent, parent_identity = _directory_identity(lexical.parent, f"{label} parent")
    try:
        os.mkdir(lexical)
    except FileExistsError as exc:
        raise ProvisionError(f"{label} appeared during exclusive create: {lexical}") from exc
    except OSError as exc:
        raise ProvisionError(f"cannot create {label}: {lexical}") from exc
    _directory_identity(parent, f"{label} parent", parent_identity)
    return _directory_identity(lexical, label)


def _stable_binding(path: Path | str, label: str) -> tuple[dict[str, Any], FileIdentity]:
    lexical, before = _regular_file_identity(path, label)
    flags = os.O_RDONLY | int(getattr(os, "O_BINARY", 0))
    try:
        descriptor = os.open(lexical, flags)
    except OSError as exc:
        raise ProvisionError(f"cannot open {label}: {lexical}") from exc
    digest = hashlib.sha256()
    try:
        handle_before = _identity_from_stat(os.fstat(descriptor))
        if handle_before != before:
            raise ProvisionError(f"{label} changed while opening: {lexical}")
        while True:
            chunk = os.read(descriptor, COPY_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
        handle_after = _identity_from_stat(os.fstat(descriptor))
    finally:
        os.close(descriptor)
    _, after = _regular_file_identity(lexical, label)
    if before != handle_after or before != after:
        raise ProvisionError(f"{label} changed while hashing: {lexical}")
    return (
        {"path": str(lexical), "size": before.size, "sha256": digest.hexdigest()},
        before,
    )


def _write_all(descriptor: int, payload: bytes) -> None:
    view = memoryview(payload)
    offset = 0
    while offset < len(view):
        written = os.write(descriptor, view[offset:])
        if written <= 0:
            raise ProvisionError("short write while publishing WS30 evidence")
        offset += written


def _atomic_publish_existing_file(temporary: Path, destination: Path, label: str) -> None:
    _assert_absent(destination, label)
    try:
        os.link(temporary, destination)
    except FileExistsError as exc:
        raise ProvisionError(f"{label} appeared during atomic publish: {destination}") from exc
    except OSError as exc:
        raise ProvisionError(f"cannot atomically publish {label}: {destination}") from exc
    try:
        os.unlink(temporary)
    except OSError as exc:
        raise ProvisionError(f"cannot retire {label} staging name: {temporary}") from exc


def _atomic_json_create(
    path: Path,
    payload: Mapping[str, Any],
    *,
    parent_identity: DirectoryIdentity,
    label: str,
) -> dict[str, Any]:
    destination = _assert_absent(path, label)
    parent, _ = _directory_identity(destination.parent, f"{label} parent", parent_identity)
    encoded = (
        json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")
    temporary = parent / f".{destination.name}.{uuid.uuid4().hex}.tmp"
    _assert_absent(temporary, f"{label} temporary")
    flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | int(getattr(os, "O_BINARY", 0))
    )
    descriptor: int | None = None
    try:
        descriptor = os.open(temporary, flags, 0o600)
        _write_all(descriptor, encoded)
        os.fsync(descriptor)
        os.close(descriptor)
        descriptor = None
        temporary_binding, _ = _stable_binding(temporary, f"{label} temporary")
        if (
            temporary_binding["size"] != len(encoded)
            or temporary_binding["sha256"] != hashlib.sha256(encoded).hexdigest()
        ):
            raise ProvisionError(f"{label} temporary bytes drifted")
        _directory_identity(parent, f"{label} parent", parent_identity)
        _atomic_publish_existing_file(temporary, destination, label)
        binding, _ = _stable_binding(destination, label)
        _directory_identity(parent, f"{label} parent", parent_identity)
        return binding
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if os.path.lexists(temporary):
            try:
                os.unlink(temporary)
            except OSError:
                pass


def _assert_source_target_distinct(
    source: Path,
    target: Path,
    source_identity: FileIdentity,
    target_identity: FileIdentity,
    label: str,
) -> None:
    try:
        same_file = os.path.samefile(source, target)
    except OSError as exc:
        raise ProvisionError(f"cannot compare source/target identity for {label}") from exc
    if same_file or (
        source_identity.device,
        source_identity.inode,
    ) == (target_identity.device, target_identity.inode):
        raise ProvisionError(f"source/target hardlink or same-file alias for {label}")


def _copy_file_atomic(
    snapshot: SourceSnapshot,
    *,
    source_parent_identity: DirectoryIdentity,
    target_parent_identity: DirectoryIdentity,
) -> tuple[dict[str, Any], FileIdentity]:
    label = f"WS30 {snapshot.kind} {snapshot.period}"
    source_parent, _ = _directory_identity(
        snapshot.source_path.parent,
        f"{label} source parent",
        source_parent_identity,
    )
    target_parent, _ = _directory_identity(
        snapshot.target_path.parent,
        f"{label} target parent",
        target_parent_identity,
    )
    source, current_identity = _regular_file_identity(
        snapshot.source_path, f"{label} source"
    )
    if current_identity != snapshot.identity:
        raise ProvisionError(f"{label} source changed after preflight")
    target = _assert_absent(snapshot.target_path, f"{label} target")
    temporary = target_parent / f".{target.name}.{uuid.uuid4().hex}.tmp"
    _assert_absent(temporary, f"{label} temporary")

    source_flags = os.O_RDONLY | int(getattr(os, "O_BINARY", 0))
    target_flags = (
        os.O_WRONLY
        | os.O_CREAT
        | os.O_EXCL
        | int(getattr(os, "O_BINARY", 0))
    )
    source_descriptor: int | None = None
    target_descriptor: int | None = None
    digest = hashlib.sha256()
    copied = 0
    try:
        source_descriptor = os.open(source, source_flags)
        if _identity_from_stat(os.fstat(source_descriptor)) != snapshot.identity:
            raise ProvisionError(f"{label} source changed while opening")
        target_descriptor = os.open(temporary, target_flags, 0o600)
        while True:
            chunk = os.read(source_descriptor, COPY_CHUNK_BYTES)
            if not chunk:
                break
            digest.update(chunk)
            copied += len(chunk)
            _write_all(target_descriptor, chunk)
        os.fsync(target_descriptor)
        if _identity_from_stat(os.fstat(source_descriptor)) != snapshot.identity:
            raise ProvisionError(f"{label} source changed while copying")
        os.close(target_descriptor)
        target_descriptor = None
        os.close(source_descriptor)
        source_descriptor = None

        if copied != snapshot.identity.size:
            raise ProvisionError(f"{label} source size changed while copying")
        source_binding = {
            "path": str(source),
            "size": copied,
            "sha256": digest.hexdigest(),
        }
        temporary_binding, _ = _stable_binding(temporary, f"{label} temporary")
        if (
            temporary_binding["size"] != source_binding["size"]
            or temporary_binding["sha256"] != source_binding["sha256"]
        ):
            raise ProvisionError(f"{label} staged target byte drift")
        _directory_identity(source_parent, f"{label} source parent", source_parent_identity)
        _directory_identity(target_parent, f"{label} target parent", target_parent_identity)
        _atomic_publish_existing_file(temporary, target, f"{label} target")
        target_path, target_identity = _regular_file_identity(target, f"{label} target")
        _assert_source_target_distinct(
            source, target_path, snapshot.identity, target_identity, label
        )
        _, source_after = _regular_file_identity(source, f"{label} source")
        if source_after != snapshot.identity:
            raise ProvisionError(f"{label} source changed after copying")
        _directory_identity(source_parent, f"{label} source parent", source_parent_identity)
        _directory_identity(target_parent, f"{label} target parent", target_parent_identity)
        return source_binding, target_identity
    finally:
        if target_descriptor is not None:
            os.close(target_descriptor)
        if source_descriptor is not None:
            os.close(source_descriptor)
        if os.path.lexists(temporary):
            try:
                os.unlink(temporary)
            except OSError:
                pass


def _normcase(path: Path | str) -> str:
    return os.path.normcase(str(_lexical_path(path)))


def _assert_fixed_contract(
) -> tuple[list[tuple[str, str, Path]], list[tuple[str, str, Path]]]:
    expected = {
        "symbol": (SYMBOL, A.RESEARCH_SYMBOL),
        "source root": (_normcase(SOURCE_DATA_ROOT), _normcase(A.PROVISION_SOURCE_DATA_ROOT)),
        "target root": (_normcase(TARGET_DATA_ROOT), _normcase(A.PROVISION_TARGET_DATA_ROOT)),
        "evidence root": (_normcase(EVIDENCE_ROOT), _normcase(A.PROVISION_ROOT)),
        "manifest": (_normcase(MANIFEST_PATH), _normcase(A.PROVISION_MANIFEST_PATH)),
        "receipt": (_normcase(RECEIPT_PATH), _normcase(A.PROVISION_RECEIPT_PATH)),
    }
    drift = [label for label, (actual, bound) in expected.items() if actual != bound]
    if drift:
        raise ProvisionError(f"bound WS30 provision contract drift: {sorted(drift)}")
    if _normcase(SOURCE_DATA_ROOT) == _normcase(TARGET_DATA_ROOT):
        raise ProvisionError("WS30 source and target roots must be distinct")
    if any(
        part.casefold() == "t6"
        for path in (SOURCE_DATA_ROOT, TARGET_DATA_ROOT, EVIDENCE_ROOT)
        for part in _lexical_path(path).parts
    ):
        raise ProvisionError("T6 is forbidden for WS30 historical provisioning")
    if MANIFEST_PATH.parent != EVIDENCE_ROOT or RECEIPT_PATH.parent != EVIDENCE_ROOT:
        raise ProvisionError("WS30 evidence paths escaped the fixed evidence root")

    try:
        source_files = A._expected_data_files(SYMBOL, SOURCE_DATA_ROOT)
        target_files = A._expected_data_files(SYMBOL, TARGET_DATA_ROOT)
    except A.B.InvalidEvidence as exc:
        raise ProvisionError(str(exc)) from exc
    if len(source_files) != 98 or len(target_files) != 98:
        raise ProvisionError("WS30 provision must contain exactly 98 expected files")
    source_order = tuple(row[:2] for row in source_files)
    target_order = tuple(row[:2] for row in target_files)
    if source_order != EXPECTED_FILE_ORDER or target_order != EXPECTED_FILE_ORDER:
        raise ProvisionError("WS30 exact 2018/201807..202512 file order drift")
    if A.B._data_coverage_contract() != EXPECTED_COVERAGE:
        raise ProvisionError("WS30 exact historical coverage contract drift")
    return source_files, target_files


def _preflight(
    source_files: Sequence[tuple[str, str, Path]],
    target_files: Sequence[tuple[str, str, Path]],
) -> tuple[
    list[SourceSnapshot],
    dict[Path, DirectoryIdentity],
    DirectoryIdentity,
]:
    source_root, _ = _directory_identity(SOURCE_DATA_ROOT, "WS30 T1 Custom root")
    target_root, _ = _directory_identity(TARGET_DATA_ROOT, "WS30 DEV2 Custom root")
    try:
        if os.path.samefile(source_root, target_root):
            raise ProvisionError("WS30 source and target roots resolve to the same directory")
    except OSError as exc:
        raise ProvisionError("cannot compare WS30 source/target root identity") from exc

    source_parents: dict[Path, DirectoryIdentity] = {}
    for kind in ("history", "ticks"):
        source_parent, source_parent_identity = _directory_identity(
            source_root / kind / SYMBOL, f"WS30 T1 {kind} symbol directory"
        )
        target_namespace, _ = _directory_identity(
            target_root / kind, f"WS30 DEV2 {kind} namespace"
        )
        target_symbol = target_namespace / SYMBOL
        _assert_absent(target_symbol, f"WS30 DEV2 {kind} symbol directory")
        source_parents[source_parent] = source_parent_identity

    evidence_parent, evidence_parent_identity = _directory_identity(
        EVIDENCE_ROOT.parent, "WS30 provision evidence parent"
    )
    _assert_absent(EVIDENCE_ROOT, "WS30 provision evidence root")
    _assert_absent(MANIFEST_PATH, "WS30 provision manifest")
    _assert_absent(RECEIPT_PATH, "WS30 provision receipt")
    _directory_identity(evidence_parent, "WS30 provision evidence parent", evidence_parent_identity)

    snapshots: list[SourceSnapshot] = []
    for (source_kind, source_period, source_path), (
        target_kind,
        target_period,
        target_path,
    ) in zip(source_files, target_files):
        if (source_kind, source_period) != (target_kind, target_period):
            raise ProvisionError("WS30 source/target ordered ledger drift")
        source_lexical, source_identity = _regular_file_identity(
            source_path, f"WS30 source {source_kind} {source_period}"
        )
        _assert_absent(target_path, f"WS30 target {target_kind} {target_period}")
        snapshots.append(
            SourceSnapshot(
                source_kind,
                source_period,
                source_lexical,
                _lexical_path(target_path),
                source_identity,
            )
        )
    return snapshots, source_parents, evidence_parent_identity


def _manifest(created_utc: str) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_10834_WS30_DEV2_PROVISION_MANIFEST",
        "created_utc": created_utc,
        "symbol": SYMBOL,
        "source_terminal": "T1",
        "source_data_root": str(_lexical_path(SOURCE_DATA_ROOT)),
        "target_terminal": "DEV2",
        "target_data_root": str(_lexical_path(TARGET_DATA_ROOT)),
        "coverage": dict(EXPECTED_COVERAGE),
        "expected_history_files": 8,
        "expected_tick_files": 90,
        "expected_total_files": 98,
        "operation": "BYTE_EXACT_OFFLINE_FILE_TRANSPORT",
        "outcome_fence": dict(OUTCOME_FENCE),
    }


def provision_historical_transport() -> dict[str, Any]:
    source_files, target_files = _assert_fixed_contract()
    (
        snapshots,
        source_parent_identities,
        evidence_parent_identity,
    ) = _preflight(source_files, target_files)

    created_at = datetime.now(timezone.utc)
    evidence_root, evidence_root_identity = _mkdir_exclusive(
        EVIDENCE_ROOT, "WS30 provision evidence root"
    )
    manifest_binding = _atomic_json_create(
        MANIFEST_PATH,
        _manifest(_utc_text(created_at)),
        parent_identity=evidence_root_identity,
        label="WS30 provision manifest",
    )

    target_parent_identities: dict[Path, DirectoryIdentity] = {}
    for kind in ("history", "ticks"):
        target_parent, target_parent_identity = _mkdir_exclusive(
            TARGET_DATA_ROOT / kind / SYMBOL,
            f"WS30 DEV2 {kind} symbol directory",
        )
        target_parent_identities[target_parent] = target_parent_identity

    copied_source_bindings: dict[tuple[str, str], dict[str, Any]] = {}
    copied_target_identities: dict[tuple[str, str], FileIdentity] = {}
    for snapshot in snapshots:
        source_parent = _lexical_path(snapshot.source_path.parent)
        target_parent = _lexical_path(snapshot.target_path.parent)
        source_binding, target_identity = _copy_file_atomic(
            snapshot,
            source_parent_identity=source_parent_identities[source_parent],
            target_parent_identity=target_parent_identities[target_parent],
        )
        key = (snapshot.kind, snapshot.period)
        copied_source_bindings[key] = source_binding
        copied_target_identities[key] = target_identity

    file_rows: list[dict[str, Any]] = []
    source_basis: list[dict[str, Any]] = []
    target_basis: list[dict[str, Any]] = []
    for snapshot in snapshots:
        key = (snapshot.kind, snapshot.period)
        source_binding, source_identity = _stable_binding(
            snapshot.source_path, f"WS30 ledger source {snapshot.kind} {snapshot.period}"
        )
        target_binding, target_identity = _stable_binding(
            snapshot.target_path, f"WS30 ledger target {snapshot.kind} {snapshot.period}"
        )
        if source_identity != snapshot.identity:
            raise ProvisionError(
                f"WS30 ledger source identity drift: {snapshot.kind} {snapshot.period}"
            )
        if source_binding != copied_source_bindings[key]:
            raise ProvisionError(
                f"WS30 ledger source byte drift: {snapshot.kind} {snapshot.period}"
            )
        if target_identity != copied_target_identities[key]:
            raise ProvisionError(
                f"WS30 ledger target identity drift: {snapshot.kind} {snapshot.period}"
            )
        if (
            source_binding["size"] != target_binding["size"]
            or source_binding["sha256"] != target_binding["sha256"]
        ):
            raise ProvisionError(
                f"WS30 ledger source/target byte drift: {snapshot.kind} {snapshot.period}"
            )
        _assert_source_target_distinct(
            snapshot.source_path,
            snapshot.target_path,
            source_identity,
            target_identity,
            f"{snapshot.kind} {snapshot.period}",
        )
        file_rows.append(
            {
                "kind": snapshot.kind,
                "period": snapshot.period,
                "source": source_binding,
                "target": target_binding,
            }
        )
        source_basis.append(
            {
                "kind": snapshot.kind,
                "period": snapshot.period,
                "size": source_binding["size"],
                "sha256": source_binding["sha256"],
            }
        )
        target_basis.append(
            {
                "kind": snapshot.kind,
                "period": snapshot.period,
                "size": target_binding["size"],
                "sha256": target_binding["sha256"],
            }
        )

    source_file_set_sha256 = A.B.canonical_sha256(source_basis)
    target_file_set_sha256 = A.B.canonical_sha256(target_basis)
    if source_file_set_sha256 != target_file_set_sha256:
        raise ProvisionError("WS30 aggregate source/target file-set hash drift")
    completed_at = datetime.now(timezone.utc)
    if completed_at < created_at:
        raise ProvisionError("WS30 provision system clock moved backwards")
    receipt = {
        "schema_version": 1,
        "artifact_type": "QM5_10834_WS30_DEV2_PROVISION_RECEIPT",
        "status": "PASS",
        "completed_utc": _utc_text(completed_at),
        "manifest": manifest_binding,
        "symbol": SYMBOL,
        "source_terminal": "T1",
        "target_terminal": "DEV2",
        "target_data_root": str(_lexical_path(TARGET_DATA_ROOT)),
        "history_files": 8,
        "tick_files": 90,
        "file_count": 98,
        "files": file_rows,
        "source_file_set_sha256": source_file_set_sha256,
        "target_file_set_sha256": target_file_set_sha256,
        "source_target_sha256_equal": True,
        "outcome_fence": dict(OUTCOME_FENCE),
    }
    _directory_identity(evidence_root, "WS30 provision evidence root", evidence_root_identity)
    receipt_binding = _atomic_json_create(
        RECEIPT_PATH,
        receipt,
        parent_identity=evidence_root_identity,
        label="WS30 provision receipt",
    )

    audit = A.validate_data_provision_contract(SYMBOL, RECEIPT_PATH, MANIFEST_PATH)
    if audit.get("status") != "PASS" or audit.get("files") != 98:
        raise ProvisionError("bound WS30 provision auditor did not accept the receipt")
    return {
        "status": "PASS",
        "artifact_type": "QM5_10834_WS30_DEV2_HISTORICAL_TRANSPORT_RESULT",
        "symbol": SYMBOL,
        "operation": "BYTE_EXACT_OFFLINE_FILE_TRANSPORT",
        "research_historical_only": True,
        "symbol_validation_status": SYMBOL_VALIDATION_STATUS,
        "live_parity_claim": False,
        "registry_updated": False,
        "mt5_started": False,
        "source_terminal": "T1",
        "target_terminal": "DEV2",
        "history_files": 8,
        "tick_files": 90,
        "file_count": 98,
        "file_set_sha256": source_file_set_sha256,
        "manifest": manifest_binding,
        "receipt": receipt_binding,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    provision = sub.add_parser(
        "provision", help="perform the fixed offline T1-to-DEV2 historical transport"
    )
    provision.add_argument("--symbol", required=True)
    provision.add_argument(
        "--acknowledge-research-historical-only",
        action="store_true",
        help="confirm this is not live-parity validation and cannot mark registry PASS",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.symbol != SYMBOL:
            raise ProvisionError(f"only the fixed research symbol {SYMBOL} is eligible")
        if not args.acknowledge_research_historical_only:
            raise ProvisionError(
                "explicit --acknowledge-research-historical-only is required"
            )
        result = provision_historical_transport()
        print(json.dumps(result, indent=2, sort_keys=True))
        return 0
    except (ProvisionError, A.B.InvalidEvidence, OSError, ValueError, KeyError) as exc:
        rejection = {
            "status": "REJECT",
            "artifact_type": "QM5_10834_WS30_DEV2_HISTORICAL_TRANSPORT_REJECTION",
            "symbol": SYMBOL,
            "research_historical_only": True,
            "symbol_validation_status": SYMBOL_VALIDATION_STATUS,
            "live_parity_claim": False,
            "registry_updated": False,
            "mt5_started": False,
            "error_type": type(exc).__name__,
            "error": str(exc),
        }
        print(json.dumps(rejection, indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
