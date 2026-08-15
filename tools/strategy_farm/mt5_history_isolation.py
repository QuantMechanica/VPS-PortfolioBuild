#!/usr/bin/env python3
"""Read-only MT5 tester/history topology audit.

The filesystem layer resolves every runner terminal's mutable ``Tester`` and
history directories. A separate pure evaluator detects exact and nested
mutable-store overlaps across terminals/components and rejects live-adjacent
aliases. It never creates, relinks, copies, or removes a directory.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping, Sequence

try:
    from custom_history_contract import (
        DEFAULT_RUNNER_TERMINALS as CONTRACT_RUNNER_TERMINALS,
        archive_acl_write_denied,
        canonical_bytes as contract_canonical_bytes,
        classify_relative_path,
        file_identity,
        load_manifest,
        normalize_relative_path,
        sha256_file,
        validate_manifest,
    )
except ImportError:  # pragma: no cover - package import path
    from tools.strategy_farm.custom_history_contract import (
        DEFAULT_RUNNER_TERMINALS as CONTRACT_RUNNER_TERMINALS,
        archive_acl_write_denied,
        canonical_bytes as contract_canonical_bytes,
        classify_relative_path,
        file_identity,
        load_manifest,
        normalize_relative_path,
        sha256_file,
        validate_manifest,
    )


SCHEMA_VERSION = "mt5-history-isolation-audit/v2"
DEFAULT_MT5_ROOT = Path(r"D:\QM\mt5")
# T5 is an active factory runner and is inside the OWNER-ratified T1-T10
# migration set.  The pre-decision v1 default incorrectly listed it as a
# protected root while also describing a ten-runner cutover.
DEFAULT_RUNNER_TERMINALS = CONTRACT_RUNNER_TERMINALS
DEFAULT_PROTECTED_ROOTS = (
    Path(r"C:\QM\mt5\T_Live"),
    Path(r"D:\QM\mt5\T_Live"),
    Path(r"D:\QM\mt5\FTMO_STREAM1"),
    Path(r"D:\QM\mt5\FTMO_STREAM2"),
    Path(r"D:\QM\mt5\DEV1"),
    Path(r"D:\QM\mt5\DEV2"),
    Path(r"D:\QM\mt5\T_Export"),
)
MUTABLE_COMPONENTS = ("Tester", "Bases", "Bases/Custom")
# Transient worker-owned privatization copies (custom_history_copy_on_claim):
# ".<name>.copy-on-claim.<pid>.<hex>.tmp"
COPY_ON_CLAIM_TEMP_MARKER = ".copy-on-claim."


def _canonical_bytes(payload: Mapping[str, Any]) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _identity(path: Path) -> str:
    # strict=False still resolves existing junction/symlink prefixes while
    # keeping missing components representable for a fail-closed finding.
    return os.path.normcase(str(path.resolve(strict=False))).rstrip("\\/")


def _normalize_identity_text(value: str) -> str:
    return os.path.normcase(os.path.normpath(value)).casefold().rstrip("\\/")


def _is_within(path_identity: str, root_identity: str) -> bool:
    try:
        return os.path.commonpath([path_identity, root_identity]) == root_identity
    except ValueError:
        return False


def _strictly_within(path_identity: str, root_identity: str) -> bool:
    return path_identity != root_identity and _is_within(path_identity, root_identity)


def _expected_same_terminal_nesting(
    left: Mapping[str, Any], right: Mapping[str, Any]
) -> bool:
    """Allow only the designed ``Bases`` -> ``Bases/Custom`` nesting."""

    if str(left["terminal"]).casefold() != str(right["terminal"]).casefold():
        return False
    components = {
        str(left["component"]).casefold(),
        str(right["component"]).casefold(),
    }
    if components != {"bases", "bases/custom"}:
        return False
    bases = left if str(left["component"]).casefold() == "bases" else right
    custom = right if bases is left else left
    return _strictly_within(
        str(custom["resolved_identity"]), str(bases["resolved_identity"])
    )


def evaluate_inventory(
    rows: Sequence[Mapping[str, Any]], *, protected_root_identities: Iterable[str]
) -> dict[str, Any]:
    """Evaluate already-resolved identity strings without filesystem access."""

    normalized_rows = []
    for source_row in rows:
        row = dict(source_row)
        missing = {
            key
            for key in ("terminal", "component", "path", "exists", "resolved_identity")
            if key not in row
        }
        if missing:
            raise ValueError(f"inventory row missing fields: {sorted(missing)}")
        if not str(row["terminal"]).strip() or not str(row["component"]).strip():
            raise ValueError("inventory terminal and component must be non-empty")
        row["resolved_identity"] = _normalize_identity_text(
            str(row["resolved_identity"])
        )
        if not row["resolved_identity"]:
            raise ValueError("inventory resolved_identity must be non-empty")
        normalized_rows.append(row)
    normalized_rows = sorted(
        normalized_rows,
        key=lambda row: (
            str(row["terminal"]).casefold(),
            str(row["component"]).casefold(),
            str(row["resolved_identity"]),
            str(row["path"]).casefold(),
            bool(row["exists"]),
        ),
    )
    findings: list[dict[str, Any]] = []
    identities: dict[tuple[str, str], list[str]] = {}

    for row in normalized_rows:
        terminal = str(row["terminal"])
        component = str(row["component"])
        exists = bool(row["exists"])
        identity = str(row["resolved_identity"])
        if not exists:
            findings.append(
                {
                    "code": "MUTABLE_STORE_MISSING",
                    "component": component,
                    "terminals": [terminal],
                    "resolved_identity": identity,
                }
            )
            continue
        if bool(row.get("is_reparse_point")):
            findings.append(
                {
                    "code": "MUTABLE_STORE_REPARSE_POINT",
                    "component": component,
                    "terminals": [terminal],
                    "resolved_identity": identity,
                }
            )
        identities.setdefault((component.casefold(), identity.casefold()), []).append(
            terminal
        )

    for (component, identity), terminals in sorted(identities.items()):
        unique = sorted(set(terminals))
        if len(unique) > 1:
            findings.append(
                {
                    "code": "CROSS_TERMINAL_MUTABLE_STORE_COLLISION",
                    "component": component,
                    "terminals": unique,
                    "resolved_identity": identity,
                }
            )

    # Exact cross-component aliases and ancestor/descendant aliases are unsafe
    # even when the component labels differ. The sole expected nesting is a
    # terminal's own Bases/Custom directory beneath that same terminal's Bases.
    existing_rows = [row for row in normalized_rows if bool(row["exists"])]
    for left_index, left in enumerate(existing_rows):
        for right in existing_rows[left_index + 1 :]:
            left_component = str(left["component"])
            right_component = str(right["component"])
            left_terminal = str(left["terminal"])
            right_terminal = str(right["terminal"])
            left_identity = str(left["resolved_identity"])
            right_identity = str(right["resolved_identity"])
            same_identity = left_identity == right_identity

            # The existing grouped finding is the compact representation for
            # exact same-component sharing across terminals.
            if (
                same_identity
                and left_component.casefold() == right_component.casefold()
                and left_terminal.casefold() != right_terminal.casefold()
            ):
                continue
            if _expected_same_terminal_nesting(left, right):
                continue

            left_contains_right = _strictly_within(right_identity, left_identity)
            right_contains_left = _strictly_within(left_identity, right_identity)
            if not (same_identity or left_contains_right or right_contains_left):
                continue

            components = sorted(
                {left_component.casefold(), right_component.casefold()}
            )
            terminals = sorted({left_terminal, right_terminal})
            if same_identity:
                code = (
                    "DUPLICATE_MUTABLE_STORE_INVENTORY_ROW"
                    if left_terminal.casefold() == right_terminal.casefold()
                    and left_component.casefold() == right_component.casefold()
                    else "CROSS_COMPONENT_MUTABLE_STORE_COLLISION"
                )
                relationship = "EXACT_IDENTITY"
                ancestor = None
                descendant = None
            else:
                code = (
                    "CROSS_TERMINAL_MUTABLE_STORE_OVERLAP"
                    if left_terminal.casefold() != right_terminal.casefold()
                    else (
                        "CROSS_COMPONENT_MUTABLE_STORE_OVERLAP"
                        if left_component.casefold() != right_component.casefold()
                        else "MUTABLE_STORE_ANCESTOR_OVERLAP"
                    )
                )
                relationship = "ANCESTOR_DESCENDANT"
                ancestor_row, descendant_row = (
                    (left, right) if left_contains_right else (right, left)
                )
                ancestor = {
                    "terminal": str(ancestor_row["terminal"]),
                    "component": str(ancestor_row["component"]),
                    "resolved_identity": str(ancestor_row["resolved_identity"]),
                }
                descendant = {
                    "terminal": str(descendant_row["terminal"]),
                    "component": str(descendant_row["component"]),
                    "resolved_identity": str(descendant_row["resolved_identity"]),
                }
            finding: dict[str, Any] = {
                "code": code,
                "component": " <-> ".join(components),
                "components": components,
                "terminals": terminals,
                "resolved_identity": (
                    left_identity
                    if same_identity
                    else str(ancestor["resolved_identity"])
                ),
                "relationship": relationship,
            }
            if ancestor is not None and descendant is not None:
                finding["ancestor"] = ancestor
                finding["descendant"] = descendant
            findings.append(finding)

    protected = sorted(
        {_normalize_identity_text(str(root)) for root in protected_root_identities}
    )
    for row in normalized_rows:
        if not row["exists"]:
            continue
        identity = str(row["resolved_identity"])
        overlaps = []
        for root in protected:
            if identity == root:
                relationship = "EXACT_IDENTITY"
            elif _strictly_within(identity, root):
                relationship = "MUTABLE_WITHIN_PROTECTED"
            elif _strictly_within(root, identity):
                relationship = "PROTECTED_WITHIN_MUTABLE"
            else:
                continue
            overlaps.append({"protected_root": root, "relationship": relationship})
        if overlaps:
            findings.append(
                {
                    "code": "LIVE_ADJACENT_STORE_ALIAS",
                    "component": str(row["component"]),
                    "terminals": [str(row["terminal"])],
                    "resolved_identity": identity,
                    "protected_roots": [
                        overlap["protected_root"] for overlap in overlaps
                    ],
                    "protected_root_overlaps": overlaps,
                }
            )

    findings.sort(
        key=lambda finding: (
            finding["code"],
            finding["component"],
            tuple(finding["terminals"]),
            finding["resolved_identity"],
        )
    )
    payload: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "audit_mode": "READ_ONLY",
        "runtime_action": "NONE",
        "status": "PASS_ISOLATED" if not findings else "FAIL_CLOSED",
        "runner_terminals": sorted({str(row["terminal"]) for row in normalized_rows}),
        "protected_roots": protected,
        "inventory": normalized_rows,
        "findings": findings,
    }
    payload["audit_sha256"] = hashlib.sha256(_canonical_bytes(payload)).hexdigest()
    return payload


def collect_inventory(
    *,
    mt5_root: Path | str = DEFAULT_MT5_ROOT,
    terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
) -> list[dict[str, Any]]:
    """Resolve the current topology. This function performs reads only."""

    root = Path(mt5_root)
    rows: list[dict[str, Any]] = []
    for terminal in sorted(set(terminals)):
        terminal_root = root / terminal
        for component in MUTABLE_COMPONENTS:
            path = terminal_root.joinpath(*component.split("/"))
            rows.append(
                {
                    "terminal": terminal,
                    "component": component,
                    "path": str(path),
                    "exists": path.is_dir(),
                    "resolved_identity": _identity(path),
                    "is_reparse_point": _is_reparse_point(path),
                }
            )
    return rows


def _is_reparse_point(path: Path) -> bool:
    try:
        stat = Path(path).lstat()
    except OSError:
        return False
    attributes = int(getattr(stat, "st_file_attributes", 0))
    return bool(attributes & 0x400)  # FILE_ATTRIBUTE_REPARSE_POINT


def _manifest_rows(manifest: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        str(row["relative_path"]).casefold(): dict(row)
        for row in manifest["files"]
    }


def _archive_symbol(relative_path: str) -> str | None:
    parts = tuple(normalize_relative_path(relative_path).split("/"))
    if len(parts) != 3 or parts[0].casefold() not in {"history", "ticks"}:
        return None
    return parts[1].upper()


def _required_archive_paths(
    manifest: Mapping[str, Any], required_symbols: Sequence[object]
) -> tuple[set[str], list[str]]:
    requested = sorted(
        {
            str(value or "").strip().upper()
            for value in required_symbols
            if str(value or "").strip().upper().endswith(".DWX")
        }
    )
    wanted = set(requested)
    matched: set[str] = set()
    paths: set[str] = set()
    for row in manifest["files"]:
        symbol = _archive_symbol(str(row["relative_path"]))
        if symbol not in wanted:
            continue
        matched.add(symbol)
        paths.add(str(row["relative_path"]).casefold())
    missing = sorted(wanted - matched)
    if missing:
        raise ValueError(
            "manifest has no archive rows for required symbols: " + ",".join(missing)
        )
    return paths, requested


def load_acl_evidence(
    path: Path,
    *,
    manifest: Mapping[str, Any],
) -> dict[str, Any]:
    try:
        raw = Path(path).read_bytes()
        payload = json.loads(raw.decode("utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid archive ACL evidence {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise ValueError("archive ACL evidence root must be an object")
    if payload.get("schema_version") != "qm.custom-history-archive-acl/v1":
        raise ValueError("archive ACL evidence schema mismatch")
    if payload.get("status") != "PASS" or payload.get("mode") not in {"VERIFY", "APPLY"}:
        raise ValueError("archive ACL evidence is not a passing apply/verify receipt")
    if payload.get("manifest_sha256") != manifest["manifest_sha256"]:
        raise ValueError("archive ACL evidence manifest mismatch")
    if payload.get("runner_identity") != manifest["runner_identity"]:
        raise ValueError("archive ACL evidence runner identity mismatch")
    if int(payload.get("archive_file_count", -1)) != int(manifest["file_count"]):
        raise ValueError("archive ACL evidence file count mismatch")
    if int(payload.get("verified", -1)) != int(manifest["file_count"]):
        raise ValueError("archive ACL evidence did not verify every manifest file")
    if payload.get("failures") not in ([], None):
        raise ValueError("archive ACL evidence contains failures")
    return {
        "path": str(Path(path).absolute()),
        "file_sha256": hashlib.sha256(raw).hexdigest(),
        "mode": payload["mode"],
        "runner_sid": payload.get("runner_sid"),
        "verified": payload.get("verified"),
    }


def collect_variant_a_file_inventory(
    *,
    mt5_root: Path | str,
    terminals: Sequence[str],
    manifest: Mapping[str, Any],
    verify_archive_hashes: bool,
    hash_private_terminals: Sequence[str] | None = None,
    acl_probe: Callable[[Path, str], Mapping[str, Any]] = archive_acl_write_denied,
) -> list[dict[str, Any]]:
    """Read file IDs and the hashes required by the mixed archive contract.

    ``hash_private_terminals`` limits terminal-private content hashing to the
    listed terminals; other terminals' private inodes are recorded STAT_ONLY.
    A running terminal's MT5 holds its privatized archives write-open, so a
    concurrent dispatch gate must not open them for read — content equality
    for those inodes is bound by their own claim-time copy-on-claim proof and
    by the quiescent full audits (``None`` keeps full hashing everywhere).
    """

    validated = validate_manifest(manifest, require_owner_approval=False)
    archive_rows = _manifest_rows(validated)
    archive_years = tuple(int(value) for value in validated["archive_years"])
    current_year = int(validated["current_year"])
    hash_private_set = (
        None
        if hash_private_terminals is None
        else {str(value).upper() for value in hash_private_terminals}
    )
    hash_cache: dict[tuple[str, int, int], str] = {}
    rows: list[dict[str, Any]] = []
    root = Path(mt5_root)

    for terminal in sorted({str(value).upper() for value in terminals}):
        custom = root / terminal / "Bases" / "Custom"
        observed_archive: set[str] = set()
        if not custom.is_dir():
            for manifest_row in validated["files"]:
                rows.append(
                    {
                        "terminal": terminal,
                        "relative_path": manifest_row["relative_path"],
                        "path": str(custom / Path(*Path(manifest_row["relative_path"]).parts)),
                        "exists": False,
                        "file_class": "ARCHIVE_IMMUTABLE",
                        "manifest_present": True,
                    }
                )
            continue

        for path in sorted(
            (candidate for candidate in custom.rglob("*") if candidate.is_file()),
            key=lambda candidate: str(candidate).casefold(),
        ):
            if COPY_ON_CLAIM_TEMP_MARKER in path.name:
                # Worker-owned transient privatization copy; never part of the
                # contract and may vanish mid-scan via os.replace.
                continue
            relative = normalize_relative_path(path.relative_to(custom).as_posix())
            folded = relative.casefold()
            classification = classify_relative_path(
                relative,
                archive_years=archive_years,
                current_year=current_year,
            )
            try:
                identity = file_identity(path)
            except FileNotFoundError:
                # Vanished between enumeration and stat (concurrent atomic
                # replace). A genuinely deleted manifest file is still caught
                # by the missing-path synthesis below.
                continue
            manifest_row = archive_rows.get(folded)
            row: dict[str, Any] = {
                "terminal": terminal,
                "relative_path": relative,
                "path": str(path),
                "exists": True,
                "file_class": classification["file_class"],
                "year": classification["year"],
                "manifest_present": manifest_row is not None,
                **identity,
            }
            if classification["file_class"] == "ARCHIVE_IMMUTABLE":
                observed_archive.add(folded)
                if manifest_row is not None:
                    family_hardlink = str(identity["file_id"]) == str(
                        manifest_row["file_id"]
                    )
                    row["archive_storage_mode"] = (
                        "FAMILY_HARDLINK" if family_hardlink else "TERMINAL_PRIVATE"
                    )
                    # A terminal-private inode is valid by its manifest digest.
                    # The dispatch gate content-hashes only the claiming
                    # terminal's own private files: a concurrently running
                    # terminal's MT5 holds its archives write-open and a read
                    # open would raise a sharing violation. Foreign private
                    # inodes stay bound by claim-time proof + full audits.
                    needs_hash = verify_archive_hashes or (
                        not family_hardlink
                        and (hash_private_set is None or terminal in hash_private_set)
                    )
                    if needs_hash:
                        cache_key = (
                            str(identity["file_id"]),
                            int(identity["size"]),
                            int(identity["mtime_ns"]),
                        )
                        if cache_key not in hash_cache:
                            try:
                                hash_cache[cache_key] = sha256_file(path)
                            except FileNotFoundError:
                                # Replaced mid-hash; missing-path synthesis
                                # keeps genuine deletions fail-closed.
                                continue
                        row["sha256"] = hash_cache[cache_key]
                    elif not family_hardlink:
                        row["sha256_verification"] = "STAT_ONLY"
            rows.append(row)

        for folded, manifest_row in archive_rows.items():
            if folded in observed_archive:
                continue
            relative = str(manifest_row["relative_path"])
            rows.append(
                {
                    "terminal": terminal,
                    "relative_path": relative,
                    "path": str(custom.joinpath(*relative.split("/"))),
                    "exists": False,
                    "file_class": "ARCHIVE_IMMUTABLE",
                    "manifest_present": True,
                }
            )
    return sorted(
        rows,
        key=lambda row: (
            str(row["terminal"]).casefold(),
            str(row["relative_path"]).casefold(),
        ),
    )


def evaluate_variant_a_file_inventory(
    rows: Sequence[Mapping[str, Any]],
    *,
    manifest: Mapping[str, Any],
    verify_archive_hashes: bool,
    sparse_contract: bool = False,
    claim_terminal: str | None = None,
    required_symbols: Sequence[object] = (),
    allow_required_restore: bool = False,
) -> dict[str, Any]:
    """Pure evaluator for mutable-file isolation and archive manifest equality."""

    validated = validate_manifest(manifest, require_owner_approval=False)
    archive_rows = _manifest_rows(validated)
    terminals = tuple(sorted({str(value).upper() for value in validated["runner_terminals"]}))
    target = str(claim_terminal or "").strip().upper()
    if sparse_contract and target not in terminals:
        raise ValueError(f"sparse claim terminal is outside the manifest runner set: {target}")
    if not sparse_contract and (target or required_symbols or allow_required_restore):
        raise ValueError("claim-scoped archive options require sparse_contract=True")
    required_paths, normalized_required_symbols = (
        _required_archive_paths(validated, required_symbols)
        if sparse_contract
        else (set(), [])
    )
    findings: list[dict[str, Any]] = []
    observations: list[dict[str, Any]] = []
    mutable_identities: dict[str, list[dict[str, str]]] = {}
    mutable_paths_by_terminal: dict[str, dict[str, int]] = {
        terminal: {} for terminal in terminals
    }
    archive_ids = {str(row["file_id"]) for row in validated["files"]}
    observed_archive_ids: set[str] = set()
    family_links_by_path: dict[str, int] = {relative: 0 for relative in archive_rows}
    private_archive_locations: dict[str, list[dict[str, str]]] = {}
    observed_by_terminal: dict[str, set[str]] = {terminal: set() for terminal in terminals}

    # Link-count minima must shrink as individual terminals become private.
    # Count the still-observed members of each manifest inode family first so
    # every row is judged against the same mixed-topology snapshot.
    for source_row in rows:
        if not bool(source_row.get("exists")):
            continue
        if str(source_row.get("file_class") or "") != "ARCHIVE_IMMUTABLE":
            continue
        relative = normalize_relative_path(str(source_row.get("relative_path") or ""))
        folded = relative.casefold()
        manifest_row = archive_rows.get(folded)
        file_id = str(source_row.get("file_id") or "")
        if manifest_row is None or not file_id:
            continue
        observed_archive_ids.add(file_id)
        terminal = str(source_row.get("terminal") or "").upper()
        if file_id == str(manifest_row["file_id"]):
            family_links_by_path[folded] += 1
        else:
            private_archive_locations.setdefault(file_id, []).append(
                {"terminal": terminal, "relative_path": relative}
            )

    for source_row in rows:
        row = dict(source_row)
        terminal = str(row.get("terminal") or "").upper()
        relative = normalize_relative_path(str(row.get("relative_path") or ""))
        folded = relative.casefold()
        file_class = str(row.get("file_class") or "")
        if terminal not in observed_by_terminal:
            findings.append(
                {
                    "code": "UNAUTHORIZED_RUNNER_TERMINAL",
                    "terminal": terminal,
                    "relative_path": relative,
                }
            )
            continue
        if not bool(row.get("exists")):
            if sparse_contract:
                if terminal != target or folded not in required_paths:
                    observations.append(
                        {
                            "code": "PRUNED_BY_DESIGN",
                            "terminal": terminal,
                            "relative_path": relative,
                        }
                    )
                    continue
                if allow_required_restore:
                    observations.append(
                        {
                            "code": "RESTORE_ON_DEMAND_REQUIRED",
                            "terminal": terminal,
                            "relative_path": relative,
                        }
                    )
                    continue
            findings.append(
                {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": terminal,
                    "relative_path": relative,
                }
            )
            continue
        file_id = str(row.get("file_id") or "")
        if not file_id:
            findings.append(
                {
                    "code": "FILE_ID_UNAVAILABLE",
                    "terminal": terminal,
                    "relative_path": relative,
                }
            )
            continue
        if file_class == "ARCHIVE_IMMUTABLE":
            manifest_row = archive_rows.get(folded)
            if manifest_row is None:
                findings.append(
                    {
                        "code": "ARCHIVE_FILE_NOT_IN_MANIFEST",
                        "terminal": terminal,
                        "relative_path": relative,
                        "file_id": file_id,
                    }
                )
                continue
            observed_by_terminal[terminal].add(folded)
            family_hardlink = file_id == str(manifest_row["file_id"])
            stat_only = (
                str(row.get("sha256_verification") or "") == "STAT_ONLY"
                and not family_hardlink
                and not verify_archive_hashes
            )
            comparisons = {
                "size": (int(row.get("size", -1)), int(manifest_row["size"])),
            }
            if (verify_archive_hashes or not family_hardlink) and not stat_only:
                comparisons["sha256"] = (
                    str(row.get("sha256") or "").casefold(),
                    str(manifest_row["sha256"]).casefold(),
                )
            mismatches = {
                key: {"actual": actual, "expected": expected}
                for key, (actual, expected) in comparisons.items()
                if actual != expected
            }
            if mismatches:
                findings.append(
                    {
                        "code": "ARCHIVE_MANIFEST_MISMATCH",
                        "terminal": terminal,
                        "relative_path": relative,
                        "mismatches": mismatches,
                    }
                )
            if family_hardlink:
                minimum_links = int(manifest_row["link_count_at_build"]) + int(
                    family_links_by_path[folded]
                )
                if int(row.get("link_count", 0)) < minimum_links:
                    findings.append(
                        {
                            "code": "ARCHIVE_LINK_COUNT_TOO_LOW",
                            "terminal": terminal,
                            "relative_path": relative,
                            "storage_mode": "FAMILY_HARDLINK",
                            "actual": int(row.get("link_count", 0)),
                            "minimum": minimum_links,
                        }
                    )
            else:
                # A different manifest inode is not a terminal-private copy; it
                # is a cross-path family alias and must remain fail-closed.
                if file_id in archive_ids:
                    findings.append(
                        {
                            "code": "ARCHIVE_FILE_ID_REUSED_ACROSS_PATHS",
                            "terminal": terminal,
                            "relative_path": relative,
                            "file_id": file_id,
                        }
                    )
                if int(row.get("link_count", 0)) != 1:
                    findings.append(
                        {
                            "code": "PRIVATE_ARCHIVE_LINK_COUNT_INVALID",
                            "terminal": terminal,
                            "relative_path": relative,
                            "file_id": file_id,
                            "actual": int(row.get("link_count", 0)),
                            "expected": 1,
                        }
                    )
        else:
            mutable_identities.setdefault(file_id, []).append(
                {"terminal": terminal, "relative_path": relative}
            )
            mutable_paths_by_terminal[terminal][folded] = int(row.get("size", -1))
            if file_id in observed_archive_ids:
                findings.append(
                    {
                        "code": "MUTABLE_FILE_ALIASES_ARCHIVE",
                        "terminal": terminal,
                        "relative_path": relative,
                        "file_id": file_id,
                    }
                )

    if sparse_contract:
        # A selected path can disappear after enumeration but before its hash
        # completes. The collector intentionally omits that torn row; enforce
        # claim completeness from the evaluator's observed set so the post-copy
        # dispatch audit cannot pass such a race.
        for folded in sorted(required_paths - observed_by_terminal[target]):
            if allow_required_restore:
                observation = {
                    "code": "RESTORE_ON_DEMAND_REQUIRED",
                    "terminal": target,
                    "relative_path": archive_rows[folded]["relative_path"],
                }
                if observation not in observations:
                    observations.append(observation)
            else:
                finding = {
                    "code": "MANIFEST_ARCHIVE_FILE_MISSING",
                    "terminal": target,
                    "relative_path": archive_rows[folded]["relative_path"],
                }
                if finding not in findings:
                    findings.append(finding)
    else:
        expected_paths = set(archive_rows)
        for terminal in terminals:
            for folded in sorted(expected_paths - observed_by_terminal[terminal]):
                finding = {
                    "code": "TERMINAL_MANIFEST_INCOMPLETE",
                    "terminal": terminal,
                    "relative_path": archive_rows[folded]["relative_path"],
                }
                if finding not in findings:
                    findings.append(finding)

    for file_id, locations in sorted(mutable_identities.items()):
        distinct_terminals = sorted({row["terminal"] for row in locations})
        if len(distinct_terminals) > 1:
            findings.append(
                {
                    "code": "CROSS_TERMINAL_MUTABLE_FILE_ID",
                    "file_id": file_id,
                    "terminals": distinct_terminals,
                    "locations": sorted(
                        locations,
                        key=lambda row: (row["terminal"], row["relative_path"].casefold()),
                    ),
                }
            )
    if verify_archive_hashes:
        expected_mutable_paths = set().union(
            *(set(rows) for rows in mutable_paths_by_terminal.values())
        )
        for terminal in terminals:
            missing = sorted(
                expected_mutable_paths - set(mutable_paths_by_terminal[terminal])
            )
            for relative in missing:
                findings.append(
                    {
                        "code": "TERMINAL_MUTABLE_FILE_MISSING",
                        "terminal": terminal,
                        "relative_path": relative,
                    }
                )
        for relative in sorted(expected_mutable_paths):
            sizes = {
                size
                for rows_by_path in mutable_paths_by_terminal.values()
                if (size := rows_by_path.get(relative)) is not None
            }
            if len(sizes) > 1:
                findings.append(
                    {
                        "code": "TERMINAL_MUTABLE_SIZE_MISMATCH",
                        "relative_path": relative,
                        "sizes": sorted(sizes),
                    }
                )
    for file_id, locations in sorted(private_archive_locations.items()):
        if len(locations) > 1:
            findings.append(
                {
                    "code": "PRIVATE_ARCHIVE_FILE_ID_SHARED",
                    "file_id": file_id,
                    "terminals": sorted({row["terminal"] for row in locations}),
                    "locations": sorted(
                        locations,
                        key=lambda row: (
                            row["terminal"],
                            row["relative_path"].casefold(),
                        ),
                    ),
                }
            )

    findings.sort(
        key=lambda finding: (
            str(finding["code"]),
            str(finding.get("terminal") or ""),
            str(finding.get("relative_path") or ""),
            str(finding.get("file_id") or ""),
        )
    )
    observations.sort(
        key=lambda observation: (
            str(observation["code"]),
            str(observation.get("terminal") or ""),
            str(observation.get("relative_path") or ""),
        )
    )
    summary_rows = []
    for terminal in terminals:
        terminal_rows = [row for row in rows if str(row.get("terminal", "")).upper() == terminal]
        mutable = [row for row in terminal_rows if row.get("file_class") != "ARCHIVE_IMMUTABLE" and row.get("exists")]
        archive = [row for row in terminal_rows if row.get("file_class") == "ARCHIVE_IMMUTABLE" and row.get("exists")]
        family_archive = [
            row for row in archive if row.get("archive_storage_mode") == "FAMILY_HARDLINK"
        ]
        private_archive = [
            row for row in archive if row.get("archive_storage_mode") == "TERMINAL_PRIVATE"
        ]
        digest_rows = [
            {
                "relative_path": row.get("relative_path"),
                "file_id": row.get("file_id"),
                "size": row.get("size"),
                "link_count": row.get("link_count"),
                "sha256": row.get("sha256"),
                "archive_storage_mode": row.get("archive_storage_mode"),
            }
            for row in terminal_rows
            if row.get("exists")
        ]
        summary = {
            "terminal": terminal,
            "archive_files": len(archive),
            "family_archive_files": len(family_archive),
            "private_archive_files": len(private_archive),
            "mutable_files": len(mutable),
            "inventory_sha256": hashlib.sha256(
                contract_canonical_bytes({"files": digest_rows})
            ).hexdigest(),
        }
        if sparse_contract:
            summary["pruned_by_design_files"] = sum(
                1
                for observation in observations
                if observation["code"] == "PRUNED_BY_DESIGN"
                and observation["terminal"] == terminal
            )
        summary_rows.append(summary)
    stat_only_private = any(
        str(row.get("sha256_verification") or "") == "STAT_ONLY"
        and row.get("archive_storage_mode") == "TERMINAL_PRIVATE"
        and row.get("exists")
        for row in rows
    )
    payload: dict[str, Any] = {
        "status": "PASS_ISOLATED" if not findings else "FAIL_CLOSED",
        "manifest_sha256": validated["manifest_sha256"],
        "archive_hash_verification": "FULL" if verify_archive_hashes else "BOUND_DUAL_AUDIT_RECEIPT",
        "terminal_private_hash_verification": (
            "CLAIMING_TERMINAL_ONLY" if stat_only_private else "FULL"
        ),
        "runner_terminals": list(terminals),
        "terminal_summaries": summary_rows,
        "findings": findings,
    }
    if sparse_contract:
        payload["sparse_contract"] = {
            "enabled": True,
            "claim_terminal": target,
            "required_symbols": normalized_required_symbols,
            "allow_required_restore": bool(allow_required_restore),
        }
        payload["observations"] = observations
    payload["file_audit_sha256"] = hashlib.sha256(contract_canonical_bytes(payload)).hexdigest()
    return payload


def resolve_protected_root_identities(
    protected_roots: Iterable[Path | str],
) -> tuple[str, ...]:
    """Filesystem boundary for protected roots; performs resolution reads only."""

    return tuple(
        sorted(
            {
                _normalize_identity_text(_identity(Path(root)))
                for root in protected_roots
            }
        )
    )


def reconcile_archive_link_count_findings(
    *,
    mt5_root: Path | str,
    terminals: Sequence[str],
    manifest: Mapping[str, Any],
    findings: Sequence[Mapping[str, Any]],
    sparse_contract: bool = False,
    claim_terminal: str | None = None,
    required_symbols: Sequence[object] = (),
    allow_required_restore: bool = False,
    attempts: int = 5,
    delay_seconds: float = 0.05,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    """Per-path instantaneous recount for torn ARCHIVE_LINK_COUNT_TOO_LOW findings.

    A copy-on-claim privatization of a large symbol family takes minutes while a
    full inventory pass spans many seconds, so whole-audit retries keep tearing
    for the entire privatization window. Statting one family across all
    terminals is microsecond-scale: the family is consistent iff, in a single
    tight pass, every non-member row is a valid private inode (nlink==1,
    manifest size) and the members' shared inode reports exactly
    link_count_at_build + member_count links. Anything else — deleted rollback
    link, cross-terminal private alias, missing file, persistent deficit —
    keeps its finding and stays fail-closed.
    """

    validated = validate_manifest(manifest, require_owner_approval=False)
    archive_rows = _manifest_rows(validated)
    root = Path(mt5_root)
    terms = tuple(sorted({str(value).upper() for value in terminals}))
    target = str(claim_terminal or "").strip().upper()
    if sparse_contract and target not in terms:
        raise ValueError(f"sparse claim terminal is outside the runner set: {target}")
    required_paths, _ = (
        _required_archive_paths(validated, required_symbols)
        if sparse_contract
        else (set(), [])
    )
    cleared: list[dict[str, Any]] = []
    remaining: list[dict[str, Any]] = []
    recounts: list[dict[str, Any]] = []
    by_path: dict[str, list[dict[str, Any]]] = {}
    for finding in findings:
        if str(finding.get("code")) != "ARCHIVE_LINK_COUNT_TOO_LOW":
            remaining.append(dict(finding))
            continue
        folded = normalize_relative_path(
            str(finding.get("relative_path") or "")
        ).casefold()
        by_path.setdefault(folded, []).append(dict(finding))

    for folded, flagged in sorted(by_path.items()):
        manifest_row = archive_rows.get(folded)
        if manifest_row is None:
            remaining.extend(flagged)
            continue
        relative_parts = str(manifest_row["relative_path"]).split("/")
        consistent = False
        recount: dict[str, Any] = {}
        for attempt in range(max(1, int(attempts))):
            members = 0
            member_links: set[int] = set()
            valid = True
            for terminal in terms:
                path = root / terminal / "Bases" / "Custom"
                path = path.joinpath(*relative_parts)
                try:
                    identity = file_identity(path)
                except FileNotFoundError:
                    if sparse_contract and (
                        terminal != target
                        or folded not in required_paths
                        or allow_required_restore
                    ):
                        continue
                    valid = False
                    break
                except OSError:
                    valid = False
                    break
                if int(identity["size"]) != int(manifest_row["size"]):
                    valid = False
                    break
                if str(identity["file_id"]) == str(manifest_row["file_id"]):
                    members += 1
                    member_links.add(int(identity["link_count"]))
                elif int(identity["link_count"]) != 1:
                    # A non-manifest inode shared by more than one directory
                    # entry is a cross-terminal alias, never a benign tear.
                    valid = False
                    break
            if valid:
                if members == 0:
                    # Every terminal privatized this path in valid isolation;
                    # no family row remains for the finding to bind to.
                    consistent = True
                elif len(member_links) == 1 and member_links == {
                    int(manifest_row["link_count_at_build"]) + members
                }:
                    consistent = True
            if consistent:
                recount = {
                    "relative_path": str(manifest_row["relative_path"]),
                    "family_members": members,
                    "link_count": next(iter(member_links), 0),
                    "expected": int(manifest_row["link_count_at_build"]) + members,
                    "attempts": attempt + 1,
                }
                break
            if attempt + 1 < max(1, int(attempts)):
                sleeper(delay_seconds)
        if consistent:
            cleared.extend(flagged)
            recounts.append(recount)
        else:
            remaining.extend(flagged)
    return {"cleared": cleared, "remaining": remaining, "recounts": recounts}


def audit_history_isolation(
    *,
    mt5_root: Path | str = DEFAULT_MT5_ROOT,
    terminals: Sequence[str] = DEFAULT_RUNNER_TERMINALS,
    protected_roots: Sequence[Path | str] = DEFAULT_PROTECTED_ROOTS,
    manifest_path: Path | str | None = None,
    require_owner_approval: bool = False,
    verify_archive_hashes: bool = True,
    hash_private_terminals: Sequence[str] | None = None,
    sparse_contract: bool = False,
    claim_terminal: str | None = None,
    required_symbols: Sequence[object] = (),
    allow_required_restore: bool = False,
    acl_probe: Callable[[Path, str], Mapping[str, Any]] = archive_acl_write_denied,
    acl_evidence_path: Path | str | None = None,
) -> dict[str, Any]:
    topology = evaluate_inventory(
        collect_inventory(mt5_root=mt5_root, terminals=terminals),
        protected_root_identities=resolve_protected_root_identities(protected_roots),
    )
    if manifest_path is None:
        return topology
    manifest = load_manifest(
        Path(manifest_path),
        require_owner_approval=require_owner_approval,
    )
    acl_binding = None
    if acl_evidence_path is not None:
        acl_binding = load_acl_evidence(Path(acl_evidence_path), manifest=manifest)
        acl_probe = lambda path, identity: {
            "supported": True,
            "write_denied": True,
            "source": "bound_acl_verification_receipt",
            "evidence_file_sha256": acl_binding["file_sha256"],
            "path": str(path),
            "runner_identity": identity,
        }
    file_rows = collect_variant_a_file_inventory(
        mt5_root=mt5_root,
        terminals=terminals,
        manifest=manifest,
        verify_archive_hashes=verify_archive_hashes,
        hash_private_terminals=hash_private_terminals,
        acl_probe=acl_probe,
    )
    file_audit = evaluate_variant_a_file_inventory(
        file_rows,
        manifest=manifest,
        verify_archive_hashes=verify_archive_hashes,
        sparse_contract=sparse_contract,
        claim_terminal=claim_terminal,
        required_symbols=required_symbols,
        allow_required_restore=allow_required_restore,
    )
    payload = dict(topology)
    payload["topology_audit_sha256"] = payload.pop("audit_sha256")
    payload["variant_a_file_audit"] = file_audit
    payload["manifest_path"] = str(Path(manifest_path).absolute())
    payload["archive_acl_evidence"] = acl_binding
    # Honest labeling (2026-08-14): with a bound receipt the per-row ACL probe
    # is a static voucher, NOT a live check — live ACLs may have eroded (they
    # had, fleet-wide, since the 08-10 Variant-A migration). Live enforcement
    # returns with the identity-separation project.
    payload["acl_probe_mode"] = (
        "receipt_bound_static" if acl_binding is not None else "live"
    )
    payload["status"] = (
        "PASS_ISOLATED"
        if topology["status"] == "PASS_ISOLATED"
        and file_audit["status"] == "PASS_ISOLATED"
        else "FAIL_CLOSED"
    )
    payload["audit_sha256"] = hashlib.sha256(_canonical_bytes(payload)).hexdigest()
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    parser.add_argument("--terminal", action="append", dest="terminals")
    parser.add_argument("--protected-root", action="append", dest="protected_roots")
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--acl-evidence", type=Path)
    parser.add_argument("--require-owner-approval", action="store_true")
    parser.add_argument(
        "--skip-archive-hash",
        action="store_true",
        help="metadata-only scoped check; valid only with independently bound dual full-audit receipts",
    )
    parser.add_argument(
        "--farm-root",
        type=Path,
        default=Path(r"D:\QM\strategy_farm"),
        help="farm root used for the factory-quiescence guard",
    )
    parser.add_argument(
        "--allow-live-full-hash",
        action="store_true",
        help=(
            "override the quiescence guard. DANGEROUS: full hashing data-opens "
            "every archive file; against a live fleet this collides with "
            "exclusive MT5 opens and MT5 discards custom year files "
            "(error-32 class, 2026-08-14 forensics)"
        ),
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not args.skip_archive_hash and not args.allow_live_full_hash:
        off_flag = Path(args.farm_root) / "state" / "FACTORY_OFF.flag"
        if not off_flag.exists():
            print(
                json.dumps(
                    {
                        "status": "REFUSED_FACTORY_LIVE",
                        "detail": (
                            "full-hash audit requires factory quiescence: "
                            f"{off_flag} absent. Data-opening archive files while "
                            "MT5 testers run triggers the error-32 discard class "
                            "(DL-085). Stop the factory or pass "
                            "--allow-live-full-hash if you have proven quiescence "
                            "another way."
                        ),
                    },
                    indent=2,
                )
            )
            return 3
    payload = audit_history_isolation(
        mt5_root=args.mt5_root,
        terminals=tuple(args.terminals or DEFAULT_RUNNER_TERMINALS),
        protected_roots=tuple(
            Path(value)
            for value in (args.protected_roots or DEFAULT_PROTECTED_ROOTS)
        ),
        manifest_path=args.manifest,
        require_owner_approval=args.require_owner_approval,
        verify_archive_hashes=not args.skip_archive_hash,
        acl_evidence_path=args.acl_evidence,
    )
    rendered = json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8", newline="\n")
    print(rendered, end="")
    return 0 if payload["status"] == "PASS_ISOLATED" else 2


if __name__ == "__main__":
    raise SystemExit(main())
