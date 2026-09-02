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
import json
import time
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
        PROVISIONED_FACTORY_TERMINALS,
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
        PROVISIONED_FACTORY_TERMINALS,
        sha256_file,
        validate_manifest,
        write_json_atomic,
    )
    from tools.strategy_farm import custom_history_master


RECEIPT_SCHEMA = "qm.custom-history-copy-on-claim/v1"


# Copy-on-claim failure classes (2026-09-02). The worker reads ``reason_code`` to
# decide the blast radius of a failed privatization:
#
#   INTEGRITY   - a genuine isolation-integrity breach: private/family archive
#                 content does not match the signed manifest, a family hardlink is
#                 still shared after privatization, an inode has an unexpected link
#                 count, or a manifest path escapes the terminal Custom root. These
#                 facts are fleet-wide (the shared archive is wrong for everyone) or
#                 prove the isolation invariant is broken, so they MUST engage
#                 fleet-wide containment.
#   CLAIM_LOCAL - a claim-/config-local condition scoped to THIS terminal+claim:
#                 the claim declares no Custom symbols, the manifest has no rows for
#                 the claimed symbols, the terminal is outside the provisioned set,
#                 the Custom root is missing, a claimed/master archive file is
#                 absent, or a prepared prestage binding does not match. Nothing
#                 cross-terminal is proven, so containment MUST NOT engage.
#   TRANSIENT   - a copy race artifact: a freshly written temporary archive does not
#                 match the manifest size/SHA. Retryable and terminal-local; MUST NOT
#                 engage containment.
#
# INTEGRITY is the default so a new raise site that forgets to classify itself
# fails safe (engages containment) rather than silently widening the
# no-containment path.
INTEGRITY = "INTEGRITY"
CLAIM_LOCAL = "CLAIM_LOCAL"
TRANSIENT = "TRANSIENT"


class CustomHistoryCopyOnClaimError(RuntimeError):
    """The claimed archive set could not be proven safe for dispatch.

    ``reason_code`` (INTEGRITY / CLAIM_LOCAL / TRANSIENT) classifies whether the
    failure is a fleet-wide isolation breach or a terminal-local condition, so the
    worker can fail one claim closed without serializing the whole factory.
    """

    def __init__(self, *args: object, reason_code: str = INTEGRITY) -> None:
        super().__init__(*args)
        self.reason_code = reason_code


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


# One validated symbol index per manifest OBJECT (2026-08-16 regression fix).
# The admission gate (commit 7df940703) calls this once per card during the
# router's ready-card inventory; each call re-validated all 3946 manifest rows
# and re-parsed every relative_path, so agent_router froze on the 600s wall
# clock every run from ~03:42 and the whole agent lane stopped dispatching.
# Memoization only: a DIFFERENT manifest object is still fully validated, so
# the fail-closed contract is unchanged. The cache pins its key object, which
# keeps id() stable, and holds exactly one entry (the active manifest).
_VALIDATED_INDEX_CACHE: dict[int, tuple[Mapping[str, Any], dict[str, list[tuple[int, dict[str, Any]]]]]] = {}


def _validated_symbol_index(
    manifest: Mapping[str, Any],
) -> dict[str, list[tuple[int, dict[str, Any]]]]:
    cached = _VALIDATED_INDEX_CACHE.get(id(manifest))
    if cached is not None and cached[0] is manifest:
        return cached[1]
    validated = validate_manifest(manifest, require_owner_approval=True)
    index: dict[str, list[tuple[int, dict[str, Any]]]] = {}
    for position, source_row in enumerate(validated["files"]):
        symbol = _archive_symbol(str(source_row["relative_path"]))
        if symbol is None:
            continue
        index.setdefault(symbol, []).append((position, dict(source_row)))
    _VALIDATED_INDEX_CACHE.clear()
    _VALIDATED_INDEX_CACHE[id(manifest)] = (manifest, index)
    return index


def select_archive_rows_for_symbols(
    manifest: Mapping[str, Any],
    symbols: Sequence[object],
) -> tuple[list[dict[str, Any]], list[str], list[str]]:
    """Return canonical manifest rows for the real Custom symbols in a claim."""

    index = _validated_symbol_index(manifest)
    requested = _unique_symbols(symbols)
    # Synthetic basket labels and broker symbols do not name Custom archive
    # directories.  The farm's governed history surface is the .DWX set.
    selected_symbols = [symbol for symbol in requested if symbol.endswith(".DWX")]
    ignored_symbols = [symbol for symbol in requested if symbol not in selected_symbols]
    if not selected_symbols:
        raise CustomHistoryCopyOnClaimError(
            "claim declares no .DWX host/conversion/basket history symbols",
            reason_code=CLAIM_LOCAL,
        )

    wanted = set(selected_symbols)
    matched: set[str] = set()
    positioned: list[tuple[int, dict[str, Any]]] = []
    for symbol in wanted:
        symbol_rows = index.get(symbol)
        if not symbol_rows:
            continue
        matched.add(symbol)
        positioned.extend(symbol_rows)
    # Manifest order is preserved via the recorded positions, so callers see
    # exactly the sequence the pre-index implementation produced.
    positioned.sort(key=lambda item: item[0])
    rows: list[dict[str, Any]] = [dict(row) for _, row in positioned]

    missing = sorted(wanted - matched)
    if missing:
        raise CustomHistoryCopyOnClaimError(
            "manifest has no archive rows for claimed symbols: " + ",".join(missing),
            reason_code=CLAIM_LOCAL,
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
            f"manifest path escapes terminal Custom root: {relative}",
            reason_code=INTEGRITY,
        ) from exc
    return target


# 2026-09-02 (CEO throughput): every claim re-hashed the terminal's already
# private archive subset (108 files / 2.04 GB for one XAU claim; ~40 claims/h
# fleet-wide -> multi-GB/s bursts, D: queue length 35-45, testers and the pump
# starved).  A per-terminal verification cache remembers the (file_id, size,
# mtime_ns, sha256, manifest) tuple of every file this terminal hashed and skips
# the re-hash while the identity is unchanged and the entry is younger than the
# TTL.  Cheap checks (size, private inode, link_count == 1) still run on every
# claim; the first claim after a copy, a manifest change or TTL expiry hashes
# again.  Kill switch: QM_CUSTOM_HISTORY_VERIFY_CACHE=0 (old behaviour).
VERIFY_CACHE_SCHEMA = "custom_history_verify_cache.v1"
VERIFY_CACHE_DEFAULT_TTL_SECONDS = 4 * 3600


def _verify_cache_enabled() -> bool:
    raw = str(os.environ.get("QM_CUSTOM_HISTORY_VERIFY_CACHE", "1")).strip().lower()
    return raw not in {"0", "false", "no", "off"}


def _verify_cache_ttl_seconds() -> int:
    raw = str(os.environ.get("QM_CUSTOM_HISTORY_VERIFY_TTL_SECONDS", "")).strip()
    try:
        value = int(raw) if raw else VERIFY_CACHE_DEFAULT_TTL_SECONDS
    except ValueError:
        value = VERIFY_CACHE_DEFAULT_TTL_SECONDS
    return max(0, value)


def _verify_cache_path(farm_root: Path | str, terminal: str) -> Path:
    return Path(farm_root) / "state" / "custom_history_verify_cache" / f"{terminal}.json"


def _load_verify_cache(path: Path) -> dict[str, dict[str, Any]]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    if not isinstance(payload, dict) or payload.get("schema_version") != VERIFY_CACHE_SCHEMA:
        return {}
    entries = payload.get("entries")
    return dict(entries) if isinstance(entries, dict) else {}


def _save_verify_cache(path: Path, entries: Mapping[str, Mapping[str, Any]]) -> None:
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json_atomic(
            path,
            {
                "schema_version": VERIFY_CACHE_SCHEMA,
                "written_at_utc": _utc_now(),
                "entries": dict(entries),
            },
        )
    except OSError:
        # The cache is an accelerator only; losing it means re-hashing.
        pass


def _verify_cache_hit(
    entry: Mapping[str, Any] | None,
    *,
    identity: Mapping[str, Any],
    expected_sha256: str,
    manifest_sha256: str,
    ttl_seconds: int,
    now_epoch: float,
) -> bool:
    if not isinstance(entry, dict):
        return False
    try:
        return (
            str(entry.get("file_id")) == str(identity["file_id"])
            and int(entry.get("size", -1)) == int(identity["size"])
            and int(entry.get("mtime_ns", -1)) == int(identity["mtime_ns"])
            and str(entry.get("sha256", "")).casefold() == expected_sha256
            and str(entry.get("manifest_sha256", "")) == manifest_sha256
            and (now_epoch - float(entry.get("verified_at_epoch", 0.0))) <= ttl_seconds
        )
    except (TypeError, ValueError):
        return False


def _verified_private_identity(
    path: Path,
    *,
    expected_sha256: str,
    expected_size: int,
    manifest_file_id: str,
    cached_digest: str | None = None,
) -> tuple[dict[str, Any], str]:
    identity = file_identity(path)
    if int(identity["size"]) != int(expected_size):
        raise CustomHistoryCopyOnClaimError(
            f"archive size mismatch after privatization: {path}",
            reason_code=INTEGRITY,
        )
    digest = cached_digest if cached_digest is not None else sha256_file(path)
    if digest != expected_sha256:
        raise CustomHistoryCopyOnClaimError(
            f"archive SHA-256 mismatch after privatization: {path}",
            reason_code=INTEGRITY,
        )
    if str(identity["file_id"]) == manifest_file_id:
        raise CustomHistoryCopyOnClaimError(
            f"archive path is still the family hardlink after privatization: {path}",
            reason_code=INTEGRITY,
        )
    if int(identity["link_count"]) != 1:
        raise CustomHistoryCopyOnClaimError(
            f"terminal-private archive inode has link_count={identity['link_count']}: {path}",
            reason_code=INTEGRITY,
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
    prepared_sources: Mapping[str, Mapping[str, Any]] | None = None,
    prestage_token_sha256: str | None = None,
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
    if target_terminal not in PROVISIONED_FACTORY_TERMINALS:
        raise CustomHistoryCopyOnClaimError(
            f"terminal is outside the provisioned factory set: {target_terminal}",
            reason_code=CLAIM_LOCAL,
        )
    rows, selected_symbols, ignored_symbols = select_archive_rows_for_symbols(
        validated, symbols
    )
    custom_root = Path(mt5_root) / target_terminal / "Bases" / "Custom"
    if not custom_root.is_dir():
        raise CustomHistoryCopyOnClaimError(
            f"terminal Custom root is missing: {custom_root}",
            reason_code=CLAIM_LOCAL,
        )

    file_results: list[dict[str, Any]] = []
    copied = 0
    already_private = 0
    verify_cache_path: Path | None = None
    verify_cache: dict[str, dict[str, Any]] = {}
    verify_cache_dirty = False
    verify_ttl = _verify_cache_ttl_seconds()
    if farm_root is not None and _verify_cache_enabled() and verify_ttl > 0:
        verify_cache_path = _verify_cache_path(farm_root, target_terminal)
        verify_cache = _load_verify_cache(verify_cache_path)
    manifest_sha256_value = str(validated["manifest_sha256"])
    cached_verifications = 0
    prepared_cache_files = 0
    prepared_by_relative = {
        normalize_relative_path(str(key)): dict(value)
        for key, value in (prepared_sources or {}).items()
    }
    for manifest_row in rows:
        relative = str(manifest_row["relative_path"])
        expected_sha256 = str(manifest_row["sha256"]).casefold()
        expected_size = int(manifest_row["size"])
        manifest_file_id = str(manifest_row["file_id"])
        target = _target_path(custom_root, relative)
        if not target.is_file():
            raise CustomHistoryCopyOnClaimError(
                f"claimed archive file is missing: {target}",
                reason_code=CLAIM_LOCAL,
            )
        before = file_identity(target)
        if int(before["size"]) != expected_size:
            raise CustomHistoryCopyOnClaimError(
                f"claimed archive size differs from manifest: {target}",
                reason_code=INTEGRITY,
            )

        verify_mode = "hashed"
        if str(before["file_id"]) != manifest_file_id:
            cached_digest: str | None = None
            if verify_cache_path is not None and _verify_cache_hit(
                verify_cache.get(relative),
                identity=before,
                expected_sha256=expected_sha256,
                manifest_sha256=manifest_sha256_value,
                ttl_seconds=verify_ttl,
                now_epoch=time.time(),
            ):
                cached_digest = expected_sha256
                verify_mode = "cached"
            after, digest = _verified_private_identity(
                target,
                expected_sha256=expected_sha256,
                expected_size=expected_size,
                manifest_file_id=manifest_file_id,
                cached_digest=cached_digest,
            )
            action = "ALREADY_PRIVATE_VERIFIED"
            already_private += 1
            if verify_mode == "cached":
                cached_verifications += 1
        else:
            copy_source_mode = "family_inode"
            if master_root is not None:
                copy_source = custom_history_master.master_file_path(
                    master_root, relative
                )
                if not copy_source.is_file():
                    raise CustomHistoryCopyOnClaimError(
                        f"master archive file missing for privatization: {copy_source}",
                        reason_code=CLAIM_LOCAL,
                    )
                copy_source_mode = "verified_master"
            else:
                copy_source = target
            authoritative_copy_source = copy_source
            prepared = prepared_by_relative.get(normalize_relative_path(relative))
            if prepared is not None:
                prepared_path = Path(str(prepared.get("cache_path") or ""))
                if (
                    str(prepared.get("sha256") or "").casefold() != expected_sha256
                    or int(prepared.get("source_size", -1)) != expected_size
                    or not prepared_path.is_file()
                    or prepared_path.stat().st_size != expected_size
                ):
                    raise CustomHistoryCopyOnClaimError(
                        f"prepared archive binding mismatch: {relative}",
                        reason_code=CLAIM_LOCAL,
                    )
                copy_source = prepared_path
                copy_source_mode = "prestage_cache_from_verified_master"
                prepared_cache_files += 1
            temporary = target.parent / (
                f".{target.name}.copy-on-claim.{os.getpid()}.{uuid.uuid4().hex}.tmp"
            )
            try:
                # copyfile intentionally does not clone the source file ACL.  The
                # new file inherits the terminal-private directory policy.
                shutil.copyfile(copy_source, temporary)
                temp_identity = file_identity(temporary)
                digest = (
                    sha256_file(temporary)
                    if int(temp_identity["size"]) == expected_size
                    else ""
                )
                if (
                    copy_source_mode == "prestage_cache_from_verified_master"
                    and (
                        int(temp_identity["size"]) != expected_size
                        or digest != expected_sha256
                    )
                ):
                    # The detached cache has no authority. A damaged cache falls
                    # back to the same verified-master copy the cold path would
                    # have used; it must never engage containment or fail the row.
                    shutil.copyfile(authoritative_copy_source, temporary)
                    temp_identity = file_identity(temporary)
                    digest = (
                        sha256_file(temporary)
                        if int(temp_identity["size"]) == expected_size
                        else ""
                    )
                    copy_source_mode = "prestage_cache_invalid_fallback_master"
                if int(temp_identity["size"]) != expected_size:
                    raise CustomHistoryCopyOnClaimError(
                        f"temporary archive size differs from manifest: {relative}",
                        reason_code=TRANSIENT,
                    )
                if digest != expected_sha256:
                    raise CustomHistoryCopyOnClaimError(
                        f"temporary archive SHA-256 differs from manifest: {relative}",
                        reason_code=TRANSIENT,
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
                "copy_source_mode": (
                    copy_source_mode if action == "COPIED_AND_REPLACED" else "already_private"
                ),
                "verify_mode": verify_mode,
            }
        )
        if verify_cache_path is not None and verify_mode == "hashed":
            verify_cache[relative] = {
                "file_id": str(after["file_id"]),
                "size": int(after["size"]),
                "mtime_ns": int(after["mtime_ns"]),
                "sha256": digest,
                "manifest_sha256": manifest_sha256_value,
                "verified_at_epoch": time.time(),
                "verified_at_utc": _utc_now(),
            }
            verify_cache_dirty = True

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
        "cached_verification_file_count": cached_verifications,
        "verify_cache_ttl_seconds": verify_ttl if verify_cache_path is not None else 0,
        "prepared_cache_file_count": prepared_cache_files,
        "prestage_token_sha256": (
            str(prestage_token_sha256) if prepared_cache_files else None
        ),
        "files": file_results,
    }
    if verify_cache_path is not None and verify_cache_dirty:
        _save_verify_cache(verify_cache_path, verify_cache)
    receipt["receipt_sha256"] = hashlib.sha256(canonical_bytes(receipt)).hexdigest()
    if receipt_path is not None:
        destination = Path(receipt_path)
        write_json_atomic(destination, receipt)
        receipt["receipt_path"] = str(destination.absolute())
        receipt["receipt_file_sha256"] = sha256_file(destination)
    return receipt

