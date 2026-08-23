#!/usr/bin/env python3
"""Bounded, serial identity and magic allocation for approved Strategy Cards.

The allocator is deliberately separate from the build and pipeline lanes.  It
discovers the live approved-card source, creates a missing EA directory and
card-of-record first, writes governed registry rows second, regenerates the
canonical resolver third, and finally proves that every new row survived
regeneration.  No EA is built, enqueued, or promoted.

The default real-run cap is five EAs.  ``--max-eas 0`` is accepted only with
``--dry-run`` so a full-inventory report cannot accidentally become an
unbounded registry mutation.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterator, Sequence


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_APPROVED_CARDS = Path("D:/QM/strategy_farm/artifacts/cards_approved")
DEFAULT_FLEET_WORKLIST = REPO_ROOT / "artifacts" / "fleet_magic_allocation_worklist_20260817.json"
DEFAULT_CENTURY_WORKLIST = REPO_ROOT / "artifacts" / "century_prebuild_worklist_20260817.json"
EA_ID_REGISTRY = Path("framework/registry/ea_id_registry.csv")
MAGIC_REGISTRY = Path("framework/registry/magic_numbers.csv")
MAGIC_RESOLVER = Path("framework/include/QM/QM_MagicResolver.mqh")
REGENERATOR = Path("framework/scripts/update_magic_resolver.py")
SYMBOL_MATRIX = Path("framework/registry/dwx_symbol_matrix.csv")
DEFAULT_LOCK = Path("D:/QM/strategy_farm/state/governed_magic_allocator.lock")
EA_ID_FIELDS = [
    "ea_id",
    "slug",
    "strategy_id",
    "status",
    "owner",
    "created_at",
    "retired_at",
    "retired_reason",
    "retired_evidence",
]
MAGIC_FIELDS = [
    "ea_id",
    "ea_slug",
    "symbol_slot",
    "symbol",
    "magic",
    "reserved_at",
    "reserved_by",
    "status",
]
SYMBOL_RE = re.compile(r"^[A-Z0-9]+\.DWX$")
EA_ID_RE = re.compile(r"^(?:QM5_)?(\d+)$")
WITHHELD_EA_IDS = {31003}
PROHIBITED_SLUG_TOKENS = ("grid", "martingale", "hft", "neural", "perceptr", "machine-learning")
STAGE_ORDER = ("compiled_ready", "century", "sourced_not_compiled", "card_only")
DL087_POLICY = "DL-087_BROAD_DISCOVERY"
DL087_EXPECTED_EAS = 105
DL087_SYMBOLS = (
    "GDAXI.DWX",
    "NDX.DWX",
    "SP500.DWX",
    "UK100.DWX",
    "WS30.DWX",
    "XAUUSD.DWX",
    "EURUSD.DWX",
    "GBPUSD.DWX",
    "USDJPY.DWX",
    "USDCHF.DWX",
    "AUDUSD.DWX",
    "USDCAD.DWX",
    "NZDUSD.DWX",
)
DL087_ASSET_CLASSES = {
    **{symbol: "indices" for symbol in DL087_SYMBOLS[:5]},
    "XAUUSD.DWX": "commodities",
    **{symbol: "forex" for symbol in DL087_SYMBOLS[6:]},
}
DL087_DISCOVERY_PAYLOAD = {
    "allocation_authority": "DL-087",
    "exploratory_symbol_assignment": True,
    "result_authorization": "DISCOVERY_NOT_CARD_VALIDATED",
    "requires_card_amendment_for_downstream": True,
}


class AllocationError(RuntimeError):
    """A fail-closed allocator precondition or verification failure."""


@dataclass(frozen=True)
class Candidate:
    ea_id: int
    slug: str
    stage: str
    directory: Path
    card: Path
    symbols: tuple[str, ...]
    symbol_policy: str = "CARD_DECLARED"
    strategy_id: str = ""


def _read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AllocationError(f"cannot_read_worklist:{path}:{exc}") from exc
    if not isinstance(value, dict):
        raise AllocationError(f"worklist_not_object:{path}")
    return value


def _numeric_ea_id(value: object) -> int | None:
    match = EA_ID_RE.fullmatch(str(value or "").strip())
    return int(match.group(1)) if match else None


def _candidate(raw: dict, stage: str, repo: Path, *, dl087: bool = False) -> Candidate | None:
    ea_id = _numeric_ea_id(raw.get("ea_id"))
    slug = str(raw.get("slug") or "").strip()
    if ea_id is None or not slug:
        return None
    directory_raw = raw.get("directory")
    directory = Path(str(directory_raw)) if directory_raw else Path("framework/EAs") / f"QM5_{ea_id}_{slug}"
    if not directory.is_absolute():
        directory = repo / directory
    card = Path(str(raw.get("card") or ""))
    if not card.is_absolute():
        card = repo / card
    symbols_raw = raw.get("target_symbols_from_card")
    if symbols_raw is None:
        symbols_raw = raw.get("target_symbols")
    symbols = tuple(str(value).strip() for value in (symbols_raw or []) if str(value).strip())
    symbol_policy = "CARD_DECLARED"
    if dl087:
        symbols = DL087_SYMBOLS
        symbol_policy = DL087_POLICY
    return Candidate(
        ea_id,
        slug,
        stage,
        directory,
        card,
        symbols,
        symbol_policy,
        str(raw.get("source_id") or raw.get("strategy_id") or "").strip(),
    )


def _card_target_symbols(value: object) -> tuple[str, ...]:
    if isinstance(value, (list, tuple)):
        values = list(value)
    else:
        text = str(value or "").strip()
        if text.startswith("[") and text.endswith("]"):
            text = text[1:-1]
        values = text.split(",") if text else []
    result: list[str] = []
    for item in values:
        symbol = str(item).strip().strip('"').strip("'").upper()
        if symbol and symbol not in result:
            result.append(symbol)
    return tuple(result)


def candidate_from_card(repo: Path, card_path: Path, *, stage: str = "exact_card") -> Candidate:
    """Build one allocator candidate from an explicit approved card."""
    try:
        try:
            import farmctl
        except ModuleNotFoundError:
            from tools.strategy_farm import farmctl
        card = card_path.resolve()
        fm = farmctl.parse_card_frontmatter(card)
    except (OSError, UnicodeError, ValueError) as exc:
        raise AllocationError(f"cannot_read_exact_card:{card_path}:{exc}") from exc
    if str(fm.get("g0_status") or "").strip().upper() != "APPROVED":
        raise AllocationError(f"exact_card_not_approved:{card}")
    ea_id = _numeric_ea_id(fm.get("ea_id"))
    slug = str(fm.get("slug") or "").strip()
    if ea_id is None or not slug:
        raise AllocationError(f"exact_card_identity_missing:{card}")
    if str(fm.get("g0_status") or "").strip().upper() != "APPROVED":
        raise AllocationError(f"exact_card_not_approved:{card}")
    symbols = _card_target_symbols(fm.get("target_symbols"))
    return Candidate(
        ea_id=ea_id,
        slug=slug,
        stage=stage,
        directory=repo / "framework" / "EAs" / f"QM5_{ea_id}_{slug}",
        card=card,
        symbols=symbols,
        strategy_id=str(fm.get("source_id") or "").strip(),
    )


def load_approved_card_candidates(
    repo: Path,
    cards_dir: Path,
) -> tuple[list[Candidate], list[dict[str, object]]]:
    """Discover the live approved-card corpus without a frozen worklist.

    Duplicate card identities are excluded as a group rather than selecting an
    arbitrary winner.  That keeps allocation deterministic while allowing
    unrelated, valid cards to continue through a bounded batch.
    """
    source = cards_dir.resolve()
    if not source.is_dir():
        raise AllocationError(f"approved_cards_dir_missing:{source}")
    parsed: list[Candidate] = []
    findings: list[dict[str, object]] = []
    for card in sorted(source.glob("QM5_*.md"), key=lambda path: path.name.casefold()):
        try:
            parsed.append(candidate_from_card(repo, card, stage="approved_live"))
        except AllocationError as exc:
            findings.append(
                {
                    "card": str(card),
                    "classification": "card_discovery_refused",
                    "reason": str(exc),
                }
            )

    by_id: dict[int, list[Candidate]] = {}
    by_slug: dict[str, list[Candidate]] = {}
    for item in parsed:
        by_id.setdefault(item.ea_id, []).append(item)
        by_slug.setdefault(item.slug.casefold(), []).append(item)
    conflicted = {
        item
        for group in list(by_id.values()) + list(by_slug.values())
        if len(group) > 1
        for item in group
    }
    for item in sorted(conflicted, key=lambda value: (value.ea_id, value.slug, str(value.card))):
        findings.append(
            {
                "card": str(item.card),
                "ea_id": f"QM5_{item.ea_id}",
                "slug": item.slug,
                "classification": "duplicate_approved_card_identity",
            }
        )
    candidates = sorted(
        (item for item in parsed if item not in conflicted),
        key=lambda item: (item.ea_id, item.slug.casefold(), item.card.name.casefold()),
    )
    return candidates, findings


def load_candidates(repo: Path, fleet_worklist: Path, century_worklist: Path) -> list[Candidate]:
    """Return deduplicated candidates in the OWNER-required payoff order."""
    fleet = _read_json(fleet_worklist)
    century = _read_json(century_worklist)
    fleet_groups = fleet.get("groups") or {}
    fleet_rows = [
        raw
        for stage in ("compiled_ready", "sourced_not_compiled", "card_only")
        for raw in list(fleet_groups.get(stage) or [])
        if isinstance(raw, dict)
    ]
    dl087_ids = {
        _numeric_ea_id(raw.get("ea_id"))
        for raw in fleet_rows
        if not list(raw.get("target_symbols_from_card") or [])
    }
    dl087_ids.discard(None)
    if len(dl087_ids) != DL087_EXPECTED_EAS:
        raise AllocationError(
            f"dl087_scope_count_mismatch:expected={DL087_EXPECTED_EAS}:actual={len(dl087_ids)}"
        )
    raw_stages: list[tuple[str, Sequence[dict]]] = [
        ("compiled_ready", list(fleet_groups.get("compiled_ready") or [])),
        ("century", list(century.get("ready_to_allocate") or [])),
        ("sourced_not_compiled", list(fleet_groups.get("sourced_not_compiled") or [])),
        ("card_only", list(fleet_groups.get("card_only") or [])),
    ]
    result: list[Candidate] = []
    seen: set[int] = set()
    for stage, rows in raw_stages:
        for raw in rows:
            if not isinstance(raw, dict):
                continue
            raw_id = _numeric_ea_id(raw.get("ea_id"))
            item = _candidate(raw, stage, repo, dl087=stage != "century" and raw_id in dl087_ids)
            if item is None or item.ea_id in seen:
                continue
            result.append(item)
            seen.add(item.ea_id)
    return result


def validate_dl087_symbols(repo: Path) -> dict[str, str]:
    """Revalidate the exact DL-087 ordered universe against the live matrix."""
    _, rows = _read_csv(repo / SYMBOL_MATRIX)
    by_symbol = {str(row.get("symbol") or "").strip(): row for row in rows}
    verified: dict[str, str] = {}
    for symbol in DL087_SYMBOLS:
        row = by_symbol.get(symbol)
        if row is None:
            raise AllocationError(f"dl087_symbol_missing_from_matrix:{symbol}")
        asset_class = str(row.get("asset_class") or "").strip().lower()
        if asset_class != DL087_ASSET_CLASSES[symbol]:
            raise AllocationError(
                f"dl087_asset_class_mismatch:{symbol}:expected={DL087_ASSET_CLASSES[symbol]}:actual={asset_class}"
            )
        if str(row.get("canonical_name_verified") or "").strip().lower() != "true":
            raise AllocationError(f"dl087_symbol_not_canonical_verified:{symbol}")
        verified[symbol] = asset_class
    return verified


def _read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        return list(reader.fieldnames or []), [dict(row) for row in reader]


def _active_ea_registry(path: Path) -> dict[int, dict[str, str]]:
    _, rows = _read_csv(path)
    result: dict[int, dict[str, str]] = {}
    for row in rows:
        ea_id = _numeric_ea_id(row.get("ea_id"))
        if ea_id is not None:
            result[ea_id] = row
    return result


def _safe_ea_directory(repo: Path, candidate: Candidate) -> bool:
    ea_root = (repo / "framework/EAs").resolve()
    directory = candidate.directory.resolve()
    try:
        directory.relative_to(ea_root)
    except ValueError:
        return False
    return not any(part.startswith("_obsolete_") for part in directory.parts)


def _candidate_issue_for_repo(repo: Path, candidate: Candidate) -> str | None:
    issue = _candidate_issue_without_directory(candidate)
    if issue:
        return issue
    if not _safe_ea_directory(repo, candidate):
        return "unsafe_ea_directory"
    return None


def _candidate_issue_without_directory(candidate: Candidate) -> str | None:
    if candidate.ea_id in WITHHELD_EA_IDS:
        return "withheld"
    prohibited = [token for token in PROHIBITED_SLUG_TOKENS if token in candidate.slug.lower()]
    if prohibited:
        return "prohibited_technique:" + ",".join(prohibited)
    if not candidate.symbols:
        return "card_missing_target_symbols"
    invalid = [symbol for symbol in candidate.symbols if not SYMBOL_RE.fullmatch(symbol)]
    if invalid:
        return "invalid_card_target_symbols:" + ",".join(invalid)
    if len(set(candidate.symbols)) != len(candidate.symbols):
        return "duplicate_card_target_symbols"
    if not candidate.card.is_file():
        return f"approved_card_missing:{candidate.card}"
    return None


def _magic_row_contract_issue(
    candidate: Candidate,
    rows: Sequence[dict[str, str]],
) -> str | None:
    if len(rows) != len(candidate.symbols):
        return f"active_magic_row_count_mismatch:expected={len(candidate.symbols)}:actual={len(rows)}"
    by_slot: dict[int, dict[str, str]] = {}
    for row in rows:
        try:
            slot = int(str(row.get("symbol_slot") or ""))
            magic = int(str(row.get("magic") or ""))
        except ValueError:
            return "active_magic_row_numeric_field_invalid"
        if slot in by_slot:
            return f"active_magic_duplicate_slot:{slot}"
        by_slot[slot] = row
        expected_magic = candidate.ea_id * 10_000 + slot
        if magic != expected_magic:
            return f"active_magic_formula_mismatch:slot={slot}:expected={expected_magic}:actual={magic}"
        if str(row.get("ea_slug") or "").strip() != candidate.slug:
            return f"active_magic_slug_mismatch:slot={slot}"
    expected_slots = set(range(len(candidate.symbols)))
    if set(by_slot) != expected_slots:
        return "active_magic_slots_not_contiguous_from_zero"
    for slot, symbol in enumerate(candidate.symbols):
        actual = str(by_slot[slot].get("symbol") or "").strip().upper()
        if actual != symbol:
            return f"active_magic_symbol_mismatch:slot={slot}:expected={symbol}:actual={actual}"
    return None


def build_plan(
    repo: Path,
    candidates: Sequence[Candidate],
    ea_registry: dict[int, dict[str, str]],
    magic_rows: Sequence[dict[str, str]],
    *,
    max_eas: int,
    refuse_retired_reallocation: bool = True,
    ea_registry_rows: Sequence[dict[str, str]] | None = None,
) -> dict:
    by_ea: dict[int, list[dict[str, str]]] = {}
    retired_rows: list[dict[str, str]] = []
    for row in magic_rows:
        ea_id = _numeric_ea_id(row.get("ea_id"))
        if ea_id is None:
            continue
        by_ea.setdefault(ea_id, []).append(dict(row))
        if str(row.get("status") or "").strip().lower() == "retired":
            retired_rows.append(dict(row))

    identity_rows = list(ea_registry_rows) if ea_registry_rows is not None else list(ea_registry.values())
    identity_by_id: dict[int, list[dict[str, str]]] = {}
    slug_rows: dict[str, list[dict[str, str]]] = {}
    for row in identity_rows:
        numeric = _numeric_ea_id(row.get("ea_id"))
        if numeric is not None:
            identity_by_id.setdefault(numeric, []).append(row)
        slug_rows.setdefault(str(row.get("slug") or "").strip().casefold(), []).append(row)

    decisions: list[dict] = []
    planned: list[Candidate] = []
    planned_identity_ids: set[int] = set()
    eligible = 0
    allocated_before = 0
    for item in candidates:
        issue = _candidate_issue_for_repo(repo, item)
        registered_rows = identity_by_id.get(item.ea_id, [])
        registry_row = registered_rows[0] if len(registered_rows) == 1 else None
        reserve_identity = False
        if issue is None and len(registered_rows) > 1:
            issue = f"ea_id_registry_ambiguous:rows={len(registered_rows)}"
        elif issue is None and registry_row is None:
            slug_conflicts = slug_rows.get(item.slug.casefold(), [])
            if slug_conflicts:
                conflict_ids = sorted(
                    str(row.get("ea_id") or "").strip() for row in slug_conflicts
                )
                issue = "ea_slug_already_registered:" + ",".join(conflict_ids)
            elif not item.strategy_id:
                issue = "card_missing_source_id_for_identity_reservation"
            else:
                reserve_identity = True
        elif issue is None and registry_row is not None:
            status = str(registry_row.get("status") or "").strip().lower()
            registered_slug = str(registry_row.get("slug") or "").strip()
            if status != "active":
                issue = f"ea_id_not_active:{status or '<blank>'}"
            elif registered_slug != item.slug:
                issue = f"slug_mismatch:{registered_slug}"

        existing = by_ea.get(item.ea_id, [])
        active = [
            row
            for row in existing
            if str(row.get("status") or "").strip().lower() == "active"
        ]
        retired = [row for row in existing if str(row.get("status") or "").strip().lower() == "retired"]
        other_status = [
            row
            for row in existing
            if str(row.get("status") or "").strip().lower() not in {"active", "retired"}
        ]
        decision = {
            "ea_id": f"QM5_{item.ea_id}",
            "slug": item.slug,
            "stage": item.stage,
            "symbols": list(item.symbols),
            "symbol_policy": item.symbol_policy,
            "identity_registered": bool(registered_rows),
            "identity_registry_rows": len(registered_rows),
        }
        if issue:
            decision.update(action="skip", reason=issue)
        elif reserve_identity and existing:
            decision.update(
                action="skip",
                reason="orphan_magic_rows_without_ea_identity",
                existing_rows=len(existing),
            )
        elif retired and refuse_retired_reallocation:
            decision.update(
                action="skip",
                reason="retired_magic_history_requires_review_do_not_unretire",
                retired_rows=len(retired),
            )
        elif other_status:
            decision.update(
                action="skip",
                reason="non_active_magic_history_requires_review",
                rows=len(other_status),
            )
        elif active:
            row_issue = _magic_row_contract_issue(item, active)
            if row_issue:
                decision.update(
                    action="skip",
                    reason="active_magic_contract_mismatch:" + row_issue,
                    existing_rows=len(active),
                )
                decisions.append(decision)
                continue
            eligible += 1
            allocated_before += 1
            decision.update(action="skip", reason="already_allocated", existing_rows=len(active))
        else:
            eligible += 1
            if max_eas and len(planned) >= max_eas:
                decision.update(action="defer", reason="batch_cap")
            else:
                planned.append(item)
                if reserve_identity:
                    planned_identity_ids.add(item.ea_id)
                decision.update(
                    action="allocate",
                    reason="eligible",
                    rows=len(item.symbols),
                    reserve_identity=reserve_identity,
                    retired_rows_to_delete=0,
                    create_directory=not item.directory.is_dir(),
                    copy_card=not (item.directory / "docs/strategy_card.md").is_file(),
                )
        decisions.append(decision)

    return {
        "schema": "qm.governed-magic-allocation/v1",
        "stage_order": list(STAGE_ORDER),
        "batch_cap": max_eas,
        "eligible": eligible,
        "allocated_before": allocated_before,
        "planned": planned,
        "planned_identity_ids": sorted(planned_identity_ids),
        "decisions": decisions,
        "retired_rows_found": retired_rows,
    }


def dirty_registry_paths(repo: Path) -> list[str]:
    command = [
        "git",
        "-C",
        str(repo),
        "status",
        "--porcelain",
        "--",
        EA_ID_REGISTRY.as_posix(),
        MAGIC_REGISTRY.as_posix(),
        MAGIC_RESOLVER.as_posix(),
    ]
    completed = subprocess.run(command, text=True, capture_output=True, check=False)
    if completed.returncode != 0:
        raise AllocationError(f"git_status_failed:{completed.stderr.strip()}")
    return [line.rstrip() for line in completed.stdout.splitlines() if line.strip()]


@contextmanager
def serial_lock(path: Path) -> Iterator[None]:
    """Hold a non-blocking OS lock for one complete allocation transaction."""
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+b")
    handle.seek(0)
    if handle.read(1) == b"":
        handle.seek(0)
        handle.write(b"0")
        handle.flush()
    try:
        handle.seek(0)
        if os.name == "nt":
            import msvcrt

            try:
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            except OSError as exc:
                raise AllocationError(f"allocator_lock_busy:{path}") from exc
        else:
            import fcntl

            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except OSError as exc:
                raise AllocationError(f"allocator_lock_busy:{path}") from exc
        yield
    finally:
        try:
            handle.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl

                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        finally:
            handle.close()


def _write_registry(path: Path, fieldnames: Sequence[str], rows: Sequence[dict[str, str]]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


def _write_magic_registry(path: Path, fieldnames: Sequence[str], rows: Sequence[dict[str, str]]) -> None:
    _write_registry(path, fieldnames, rows)


@contextmanager
def identity_registry_lock(path: Path) -> Iterator[None]:
    """Coordinate exact-ID writes with farmctl's O_EXCL identity lock."""
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(str(path), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError as exc:
        raise AllocationError(f"ea_id_registry_lock_busy:{path}") from exc
    try:
        os.write(
            descriptor,
            json.dumps(
                {
                    "pid": os.getpid(),
                    "created_at": dt.datetime.now(dt.UTC).isoformat(),
                    "writer": "governed_magic_allocator",
                },
                sort_keys=True,
            ).encode("utf-8"),
        )
        yield
    finally:
        os.close(descriptor)
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def _status_aware_magic_collisions(rows: Sequence[dict[str, str]]) -> list[dict[str, object]]:
    by_magic: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        if str(row.get("status") or "").strip().lower() not in {"active", "reserved"}:
            continue
        by_magic.setdefault(str(row.get("magic") or "").strip(), []).append(dict(row))
    return [
        {"magic": magic, "rows": grouped}
        for magic, grouped in sorted(by_magic.items())
        if not magic or len(grouped) > 1
    ]


def _identity_collision_counts(rows: Sequence[dict[str, str]]) -> dict[str, int]:
    by_id: dict[str, int] = {}
    by_slug: dict[str, int] = {}
    for row in rows:
        ea_id = str(row.get("ea_id") or "").strip()
        slug = str(row.get("slug") or "").strip().casefold()
        by_id[ea_id] = by_id.get(ea_id, 0) + 1
        by_slug[slug] = by_slug.get(slug, 0) + 1
    return {
        "duplicate_ea_ids": sum(count > 1 for key, count in by_id.items() if key),
        "duplicate_slugs": sum(count > 1 for key, count in by_slug.items() if key),
    }


def _run_regenerator(repo: Path) -> None:
    completed = subprocess.run(
        [sys.executable, str(repo / REGENERATOR)],
        cwd=repo,
        text=True,
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise AllocationError(f"resolver_regeneration_failed:{detail}")


def _resolver_rows(path: Path) -> list[tuple[int, int, str, int]]:
    text = path.read_text(encoding="utf-8")

    def values(name: str, convert: Callable[[str], object]) -> list:
        match = re.search(rf"{name}\[[^\]]+\]\s*=\s*\{{([^}}]*)\}};", text)
        if not match:
            raise AllocationError(f"resolver_array_missing:{name}")
        raw = [value.strip() for value in match.group(1).split(",") if value.strip()]
        return [convert(value) for value in raw]

    ea_ids = values("QM_MAGIC_REG_EA_ID", int)
    slots = values("QM_MAGIC_REG_SLOT", int)
    symbols = values("QM_MAGIC_REG_SYMBOL", lambda value: value.strip('"'))
    magics = values("QM_MAGIC_REG_MAGIC", int)
    if not (len(ea_ids) == len(slots) == len(symbols) == len(magics)):
        raise AllocationError("resolver_parallel_array_length_mismatch")
    rows = list(zip(ea_ids, slots, symbols, magics))
    keys = [ea_id * 10_000 + slot for ea_id, slot, _, _ in rows]
    if any(left >= right for left, right in zip(keys, keys[1:])):
        raise AllocationError("resolver_composite_key_order_invalid")
    return rows


def apply_plan(
    repo: Path,
    plan: dict,
    magic_fields: Sequence[str],
    magic_rows: list[dict[str, str]],
    *,
    regenerate: Callable[[Path], None] = _run_regenerator,
) -> dict:
    planned: list[Candidate] = list(plan["planned"])
    identity_path = repo / EA_ID_REGISTRY
    registry_path = repo / MAGIC_REGISTRY
    resolver_path = repo / MAGIC_RESOLVER
    identity_before = identity_path.read_bytes()
    registry_before = registry_path.read_bytes()
    resolver_before = resolver_path.read_bytes()
    resolver_rows_before = len(_resolver_rows(resolver_path))
    identity_fields, identity_rows = _read_csv(identity_path)
    required_identity_fields = set(EA_ID_FIELDS[:6])
    if not required_identity_fields.issubset(identity_fields):
        raise AllocationError(f"unexpected_ea_id_registry_columns:{identity_fields}")
    identity_collisions_before = _identity_collision_counts(identity_rows)
    magic_collisions_before = _status_aware_magic_collisions(magic_rows)
    if magic_collisions_before:
        raise AllocationError(
            f"status_aware_magic_collision_preexisting:{len(magic_collisions_before)}"
        )
    created_dirs: list[Path] = []
    created_cards: list[Path] = []
    now = dt.datetime.now(dt.UTC).date().isoformat()
    new_identity_rows: list[dict[str, str]] = []
    new_rows: list[dict[str, str]] = []
    planned_identity_ids = set(plan.get("planned_identity_ids") or [])
    try:
        # Ordering invariant: directory and durable card exist before any row is written.
        for item in planned:
            if not item.directory.exists():
                item.directory.mkdir(parents=True)
                created_dirs.append(item.directory)
            docs = item.directory / "docs"
            docs.mkdir(parents=True, exist_ok=True)
            card_target = docs / "strategy_card.md"
            if not card_target.exists():
                shutil.copyfile(item.card, card_target)
                created_cards.append(card_target)
            if item.ea_id in planned_identity_ids:
                new_identity_rows.append(
                    {
                        "ea_id": str(item.ea_id),
                        "slug": item.slug,
                        "strategy_id": item.strategy_id,
                        "status": "active",
                        "owner": "Research",
                        "created_at": now,
                        "retired_at": "",
                        "retired_reason": "",
                        "retired_evidence": "",
                    }
                )
            for slot, symbol in enumerate(item.symbols):
                new_rows.append(
                    {
                        "ea_id": str(item.ea_id),
                        "ea_slug": item.slug,
                        "symbol_slot": str(slot),
                        "symbol": symbol,
                        "magic": str(item.ea_id * 10_000 + slot),
                        "reserved_at": now,
                        "reserved_by": "Codex governed allocator",
                        "status": "active",
                    }
                )

        # Both CSV writes happen only after every directory/card-of-record is durable.
        _write_registry(identity_path, identity_fields, identity_rows + new_identity_rows)
        _write_magic_registry(registry_path, magic_fields, magic_rows + new_rows)
        regenerate(repo)

        _, identity_after_rows = _read_csv(identity_path)
        identity_collisions_after = _identity_collision_counts(identity_after_rows)
        if identity_collisions_after != identity_collisions_before:
            raise AllocationError(
                "ea_identity_collision_delta:"
                f"before={identity_collisions_before}:after={identity_collisions_after}"
            )
        identity_by_id: dict[int, list[dict[str, str]]] = {}
        for row in identity_after_rows:
            numeric = _numeric_ea_id(row.get("ea_id"))
            if numeric is not None:
                identity_by_id.setdefault(numeric, []).append(row)
        for item in planned:
            rows = identity_by_id.get(item.ea_id, [])
            matching = [
                row
                for row in rows
                if str(row.get("slug") or "").strip() == item.slug
                and str(row.get("status") or "").strip().lower() == "active"
            ]
            if len(matching) != 1:
                raise AllocationError(
                    f"active_identity_verification_failed:QM5_{item.ea_id}:rows={len(matching)}"
                )

        _, magic_after_rows = _read_csv(registry_path)
        magic_collisions_after = _status_aware_magic_collisions(magic_after_rows)
        if magic_collisions_after:
            raise AllocationError(
                f"status_aware_magic_collision_after_write:{len(magic_collisions_after)}"
            )
        generated = set(_resolver_rows(resolver_path))
        expected = {
            (int(row["ea_id"]), int(row["symbol_slot"]), row["symbol"], int(row["magic"]))
            for row in new_rows
        }
        missing = sorted(expected - generated)
        if missing:
            raise AllocationError(f"allocated_rows_missing_after_regeneration:{missing}")
        resolver_rows_after = len(generated)
        if resolver_rows_after - resolver_rows_before != len(new_rows):
            raise AllocationError(
                "resolver_row_delta_mismatch:"
                f"before={resolver_rows_before}:after={resolver_rows_after}:new={len(new_rows)}"
            )
    except Exception:
        identity_path.write_bytes(identity_before)
        registry_path.write_bytes(registry_before)
        resolver_path.write_bytes(resolver_before)
        for path in reversed(created_cards):
            if path.exists():
                path.unlink()
        for path in reversed(created_dirs):
            if path.exists():
                shutil.rmtree(path)
        raise

    return {
        "allocated_eas": len(planned),
        "allocated_rows": len(new_rows),
        "allocated_ids": [f"QM5_{item.ea_id}" for item in planned],
        "identity_rows_added": len(new_identity_rows),
        "identity_ids_added": [f"QM5_{row['ea_id']}" for row in new_identity_rows],
        "ea_registry_rows_before": len(identity_rows),
        "ea_registry_rows_after": len(identity_rows) + len(new_identity_rows),
        "identity_collision_counts_before": identity_collisions_before,
        "identity_collision_counts_after": identity_collisions_after,
        "registry_rows_before": len(magic_rows),
        "registry_rows_after": len(magic_rows) + len(new_rows),
        "status_aware_magic_collisions_before": len(magic_collisions_before),
        "status_aware_magic_collisions_after": len(magic_collisions_after),
        "resolver_rows_before": resolver_rows_before,
        "resolver_rows_after": resolver_rows_after,
        "retired_rows_deleted": 0,
    }


def _public_report(plan: dict, *, dry_run: bool, result: dict | None = None) -> dict:
    planned = list(plan["planned"])
    allocated_after = plan["allocated_before"] + (0 if dry_run else len(planned))
    dl087_eas = sum(item.symbol_policy == DL087_POLICY for item in planned)
    dl087_rows = sum(len(item.symbols) for item in planned if item.symbol_policy == DL087_POLICY)
    return {
        "schema": plan["schema"],
        "mode": "dry_run" if dry_run else "apply",
        "stage_order": plan["stage_order"],
        "batch_cap": plan["batch_cap"],
        "planned_eas": len(planned),
        "planned_rows": sum(len(item.symbols) for item in planned),
        "planned_identity_rows": len(plan.get("planned_identity_ids") or []),
        "progress": {
            "allocated": allocated_after,
            "eligible": plan["eligible"],
            "display": f"{allocated_after}/{plan['eligible']}",
        },
        "retired_rows_found": plan["retired_rows_found"],
        "decisions": plan["decisions"],
        "result": result,
        "dl087": {
            "planned_eas": dl087_eas,
            "allocated_rows": 0 if dry_run else dl087_rows,
            "enqueued_rows": 0,
            "discovery_payload_contract": DL087_DISCOVERY_PAYLOAD,
        },
    }


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=REPO_ROOT)
    parser.add_argument(
        "--cards-dir",
        type=Path,
        default=DEFAULT_APPROVED_CARDS,
        help="Live approved-card source used by default discovery",
    )
    parser.add_argument("--fleet-worklist", type=Path, default=DEFAULT_FLEET_WORKLIST)
    parser.add_argument("--century-worklist", type=Path, default=DEFAULT_CENTURY_WORKLIST)
    parser.add_argument("--max-eas", type=int, default=5, help="Bounded EAs per run; 0 means full dry-run only")
    parser.add_argument(
        "--scope",
        choices=("all", "dl087"),
        default="all",
        help="Restrict selection to the 105 DL-087 legacy-card EAs",
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--card",
        type=Path,
        action="append",
        help="Exact APPROVED card to allocate; repeat for a bounded explicit batch",
    )
    parser.add_argument("--lock-path", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args(argv)
    repo = args.repo.resolve()
    if args.max_eas < 0 or (args.max_eas == 0 and not args.dry_run):
        parser.error("--max-eas 0 is allowed only with --dry-run")
    try:
        with serial_lock(args.lock_path), identity_registry_lock(
            repo / "framework" / "registry" / ".ea_id_registry.lock"
        ):
            dirty = dirty_registry_paths(repo)
            if dirty:
                raise AllocationError("dirty_registry_abort:" + "|".join(dirty))
            exact_card_mode = bool(args.card)
            if exact_card_mode and args.scope != "all":
                raise AllocationError("exact_card_mode_does_not_accept_scope")
            discovery_findings: list[dict[str, object]] = []
            if exact_card_mode:
                candidates = [candidate_from_card(repo, card) for card in args.card]
                discovery_source = {
                    "mode": "exact_card",
                    "cards": [str(item.card) for item in candidates],
                }
            elif args.scope == "dl087":
                candidates = load_candidates(repo, args.fleet_worklist, args.century_worklist)
                discovery_source = {
                    "mode": "dl087_owner_worklist",
                    "fleet_worklist": str(args.fleet_worklist),
                    "century_worklist": str(args.century_worklist),
                }
            else:
                candidates, discovery_findings = load_approved_card_candidates(
                    repo, args.cards_dir
                )
                discovery_source = {
                    "mode": "live_approved_cards",
                    "cards_dir": str(args.cards_dir.resolve()),
                }
            dl087_verified = None
            if args.scope == "dl087":
                candidates = [item for item in candidates if item.symbol_policy == DL087_POLICY]
                if len(candidates) != DL087_EXPECTED_EAS:
                    raise AllocationError(
                        f"dl087_candidate_count_mismatch:expected={DL087_EXPECTED_EAS}:actual={len(candidates)}"
                    )
                dl087_verified = validate_dl087_symbols(repo)
            ea_fields, ea_rows = _read_csv(repo / EA_ID_REGISTRY)
            if not set(EA_ID_FIELDS[:6]).issubset(ea_fields):
                raise AllocationError(f"unexpected_ea_id_registry_columns:{ea_fields}")
            ea_registry = {
                numeric: row
                for row in ea_rows
                if (numeric := _numeric_ea_id(row.get("ea_id"))) is not None
            }
            magic_fields, magic_rows = _read_csv(repo / MAGIC_REGISTRY)
            if magic_fields != MAGIC_FIELDS:
                raise AllocationError(f"unexpected_magic_registry_columns:{magic_fields}")
            plan = build_plan(
                repo,
                candidates,
                ea_registry,
                magic_rows,
                max_eas=args.max_eas,
                refuse_retired_reallocation=True,
                ea_registry_rows=ea_rows,
            )
            if exact_card_mode:
                plan["stage_order"] = ["exact_card"]
            elif args.scope != "dl087":
                plan["stage_order"] = ["approved_live"]
            result = None if args.dry_run else apply_plan(repo, plan, magic_fields, magic_rows)
            report = _public_report(plan, dry_run=args.dry_run, result=result)
            report["scope"] = args.scope
            report["discovery"] = {
                **discovery_source,
                "candidate_count": len(candidates),
                "finding_count": len(discovery_findings),
                "findings": discovery_findings,
            }
            if dl087_verified is not None:
                report["dl087"]["matrix_verified"] = dl087_verified
    except AllocationError as exc:
        report = {"schema": "qm.governed-magic-allocation/v1", "status": "aborted", "reason": str(exc)}
        rendered = json.dumps(report, indent=2, sort_keys=True)
        print(rendered)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(rendered + "\n", encoding="utf-8")
        return 2
    rendered = json.dumps(report, indent=2, sort_keys=True)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
