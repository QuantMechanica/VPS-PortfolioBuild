#!/usr/bin/env python3
"""Privatize only the Custom-history archives needed by one claimed run.

Variant A initially fans each immutable archive inode out to T1-T10 with
hardlinks.  MT5 nevertheless opens archive files for write, so a governed
claim must replace the selected terminal paths with verified private files
before the tester is launched.  This module performs that bounded mutation:
copy beside the target, verify the manifest SHA-256, then atomically replace
the hardlink.  Repeating the operation on an already-private verified file is
safe and makes no further mutation.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import os
from pathlib import Path, PurePosixPath
import shutil
from typing import Any, Iterable, Mapping, Sequence
import uuid

try:
    from custom_history_contract import (
        canonical_bytes,
        file_identity,
        normalize_relative_path,
        sha256_file,
        validate_manifest,
        write_json_atomic,
    )
    import custom_history_master
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import (
        canonical_bytes,
        file_identity,
        normalize_relative_path,
        sha256_file,
        validate_manifest,
        write_json_atomic,
    )
    from tools.strategy_farm import custom_history_master


RECEIPT_SCHEMA = "qm.custom-history-copy-on-claim/v1"


class CustomHistoryCopyOnClaimError(RuntimeError):
    """The claimed archive set could not be proven safe for dispatch."""


def _utc_now() -> str:
    return dt.datetime.now(dt.UTC).isoformat()


def _unique_symbols(values: Iterable[object]) -> list[str]:
    symbols: list[str] = []
    seen: set[str] = set()
    for value in values:
        symbol = str(value or "").strip().upper()
        if not symbol or symbol in seen:
            continue
        seen.add(symbol)
        symbols.append(symbol)
    return symbols


def _archive_symbol(relative_path: str) -> str | None:
    parts = PurePosixPath(normalize_relative_path(relative_path)).parts
    if len(parts) != 3 or parts[0].casefold() not in {"history", "ticks"}:
        return None
    return parts[1].upper()


def select_archive_rows_for_symbols(
    manifest: Mapping[str, Any],
    symbols: Sequence[object],
) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    """Return canonical manifest rows for the real Custom symbols in a claim."""

    validated = validate_manifest(manifest, require_owner_approval=True)
    requested = _unique_symbols(symbols)
    # Synthetic basket labels and broker symbols do not name Custom archive
    # directories.  The farm's governed history surface is the .DWX set.
    selected_symbols = [symbol for symbol in requested if symbol.endswith(".DWX")]
    ignored_symbols = [symbol for symbol in requested if symbol not in selected_symbols]
    if not selected_symbols:
        raise CustomHistoryCopyOnClaimError(
            "claim declares no .DWX host/conversion/basket history symbols"
        )

    wanted = set(selected_symbols)
    matched: set[str] = set()
    rows: list[dict[str, Any]] = []
    for source_row in validated["files"]:
        row = dict(source_row)
        symbol = _archive_symbol(str(row["relative_path"]))
        if symbol not in wanted:
            continue
        matched.add(symbol)
        rows.append(row)

    missing = sorted(wanted - matched)
    if missing:
        raise CustomHistoryCopyOnClaimError(
            "manifest has no archive rows for claimed symbols: " + ",".join(missing)
        )
    return rows, selected_symbols, ignored_symbols


def _target_path(custom_root: Path, relative_path: str) -> Path:
    relative = normalize_relative_path(relative_path)
    target = custom_root.joinpath(*PurePosixPath(relative).parts)
    root_resolved = custom_root.resolve(strict=True)
    parent_resolved = target.parent.resolve(strict=True)
    try:
        parent_resolved.relative_to(root_resolved)
    except ValueError as exc:
        raise CustomHistoryCopyOnClaimError(
            f"manifest path escapes terminal Custom root: {relative}"
        ) from exc
    return target


def _verified_private_identity(
    path: Path,
    *,
    expected_sha256: str,
    expected_size: int,
    manifest_file_id: str,
) -> tuple[dict[str, Any], str]:
    identity = file_identity(path)
    if int(identity["size"]) != int(expected_size):
        raise CustomHistoryCopyOnClaimError(
            f"archive size mismatch after privatization: {path}"
        )
    digest = sha256_file(path)
    if digest != expected_sha256:
        raise CustomHistoryCopyOnClaimError(
            f"archive SHA-256 mismatch after privatization: {path}"
        )
    if str(identity["file_id"]) == manifest_file_id:
        raise CustomHistoryCopyOnClaimError(
            f"archive path is still the family hardlink after privatization: {path}"
        )
    if int(identity["link_count"]) != 1:
        raise CustomHistoryCopyOnClaimError(
            f"terminal-private archive inode has link_count={identity['link_count']}: {path}"
        )
    return identity, digest


def privatize_terminal_archives(
    *,
    manifest: Mapping[str, Any],
    mt5_root: Path | str,
    terminal: str,
    symbols: Sequence[object],
    receipt_path: Path | str | None = None,
    farm_root: Path | str | None = None,
) -> dict[str, Any]:
    """Copy and atomically privatize one terminal's claimed archive subset.

    With ``farm_root`` given (production), the copy READS from the standalone
    verified master tree (DL-085) instead of from the cross-terminal shared
    family inode: a data-open of the family inode collides with the exclusive
    opens of other terminals' running MT5 processes (error-32 discard class,
    2026-08-14 forensics). Master problems fail closed. Without ``farm_root``
    the legacy family-inode read is kept (hermetic tests).
    """

    validated = validate_manifest(manifest, require_owner_approval=True)
    master_root: Path | None = None
    if farm_root is not None:
        master_root = custom_history_master.load_master_state(
            farm_root, manifest=validated
        )["master_root"]
    target_terminal = str(terminal or "").strip().upper()
    if target_terminal not in validated["runner_terminals"]:
        raise CustomHistoryCopyOnClaimError(
            f"terminal is outside the manifest runner set: {target_terminal}"
        )
    rows, selected_symbols, ignored_symbols = select_archive_rows_for_symbols(
        validated, symbols
    )
    custom_root = Path(mt5_root) / target_terminal / "Bases" / "Custom"
    if not custom_root.is_dir():
        raise CustomHistoryCopyOnClaimError(
            f"terminal Custom root is missing: {custom_root}"
        )

    file_results: list[dict[str, Any]] = []
    copied = 0
    already_private = 0
    for manifest_row in rows:
        relative = str(manifest_row["relative_path"])
        expected_sha256 = str(manifest_row["sha256"]).casefold()
        expected_size = int(manifest_row["size"])
        manifest_file_id = str(manifest_row["file_id"])
        target = _target_path(custom_root, relative)
        if not target.is_file():
            raise CustomHistoryCopyOnClaimError(
                f"claimed archive file is missing: {target}"
            )
        before = file_identity(target)
        if int(before["size"]) != expected_size:
            raise CustomHistoryCopyOnClaimError(
                f"claimed archive size differs from manifest: {target}"
            )

        if str(before["file_id"]) != manifest_file_id:
            after, digest = _verified_private_identity(
                target,
                expected_sha256=expected_sha256,
                expected_size=expected_size,
                manifest_file_id=manifest_file_id,
            )
            action = "ALREADY_PRIVATE_VERIFIED"
            already_private += 1
        else:
            if master_root is not None:
                copy_source = custom_history_master.master_file_path(
                    master_root, relative
                )
                if not copy_source.is_file():
                    raise CustomHistoryCopyOnClaimError(
                        f"master archive file missing for privatization: {copy_source}"
                    )
            else:
                copy_source = target
            temporary = target.parent / (
                f".{target.name}.copy-on-claim.{os.getpid()}.{uuid.uuid4().hex}.tmp"
            )
            try:
                # copyfile intentionally does not clone the source file ACL.  The
                # new file inherits the terminal-private directory policy.
                shutil.copyfile(copy_source, temporary)
                temp_identity = file_identity(temporary)
                if int(temp_identity["size"]) != expected_size:
                    raise CustomHistoryCopyOnClaimError(
                        f"temporary archive size differs from manifest: {relative}"
                    )
                digest = sha256_file(temporary)
                if digest != expected_sha256:
                    raise CustomHistoryCopyOnClaimError(
                        f"temporary archive SHA-256 differs from manifest: {relative}"
                    )
                os.replace(temporary, target)
            finally:
                try:
                    temporary.unlink()
                except FileNotFoundError:
                    pass
            after, digest = _verified_private_identity(
                target,
                expected_sha256=expected_sha256,
                expected_size=expected_size,
                manifest_file_id=manifest_file_id,
            )
            action = "COPIED_AND_REPLACED"
            copied += 1

        file_results.append(
            {
                "relative_path": relative,
                "action": action,
                "manifest_file_id": manifest_file_id,
                "before_file_id": str(before["file_id"]),
                "after_file_id": str(after["file_id"]),
                "after_link_count": int(after["link_count"]),
                "size": int(after["size"]),
                "sha256": digest,
            }
        )

    receipt: dict[str, Any] = {
        "schema_version": RECEIPT_SCHEMA,
        "status": "PASS_PRIVATIZED",
        "runtime_action": "COPY_ON_CLAIM",
        "privatization_source": "master" if master_root is not None else "family_inode",
        "recorded_at_utc": _utc_now(),
        "terminal": target_terminal,
        "manifest_sha256": validated["manifest_sha256"],
        "symbols": selected_symbols,
        "ignored_non_custom_symbols": ignored_symbols,
        "selected_file_count": len(rows),
        "copied_file_count": copied,
        "already_private_file_count": already_private,
        "files": file_results,
    }
    receipt["receipt_sha256"] = hashlib.sha256(canonical_bytes(receipt)).hexdigest()
    if receipt_path is not None:
        destination = Path(receipt_path)
        write_json_atomic(destination, receipt)
        receipt["receipt_path"] = str(destination.absolute())
        receipt["receipt_file_sha256"] = sha256_file(destination)
    return receipt

