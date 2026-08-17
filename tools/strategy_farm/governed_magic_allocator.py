#!/usr/bin/env python3
"""Bounded, serial magic-row allocation for governed EA worklists.

The allocator is deliberately separate from the build and pipeline lanes.  It
creates a missing EA directory and card-of-record first, appends the EA's magic
rows second, regenerates the canonical resolver third, and finally proves that
every new row survived regeneration.  No EA is built, enqueued, or promoted.

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
DEFAULT_FLEET_WORKLIST = REPO_ROOT / "artifacts" / "fleet_magic_allocation_worklist_20260817.json"
DEFAULT_CENTURY_WORKLIST = REPO_ROOT / "artifacts" / "century_prebuild_worklist_20260817.json"
EA_ID_REGISTRY = Path("framework/registry/ea_id_registry.csv")
MAGIC_REGISTRY = Path("framework/registry/magic_numbers.csv")
MAGIC_RESOLVER = Path("framework/include/QM/QM_MagicResolver.mqh")
REGENERATOR = Path("framework/scripts/update_magic_resolver.py")
SYMBOL_MATRIX = Path("framework/registry/dwx_symbol_matrix.csv")
DEFAULT_LOCK = Path("D:/QM/strategy_farm/state/governed_magic_allocator.lock")
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
    return Candidate(ea_id, slug, stage, directory, card, symbols, symbol_policy)


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


def _candidate_issue_for_repo(repo: Path, candidate: Candidate, registry_row: dict[str, str] | None) -> str | None:
    issue = _candidate_issue_without_directory(candidate, registry_row)
    if issue:
        return issue
    if not _safe_ea_directory(repo, candidate):
        return "unsafe_ea_directory"
    return None


def _candidate_issue_without_directory(candidate: Candidate, registry_row: dict[str, str] | None) -> str | None:
    if candidate.ea_id in WITHHELD_EA_IDS:
        return "withheld"
    prohibited = [token for token in PROHIBITED_SLUG_TOKENS if token in candidate.slug.lower()]
    if prohibited:
        return "prohibited_technique:" + ",".join(prohibited)
    if registry_row is None:
        return "ea_id_not_registered"
    if str(registry_row.get("status") or "").strip().lower() != "active":
        return "ea_id_not_active"
    registered_slug = str(registry_row.get("slug") or "").strip()
    if registered_slug != candidate.slug:
        return f"slug_mismatch:{registered_slug}"
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


def build_plan(
    repo: Path,
    candidates: Sequence[Candidate],
    ea_registry: dict[int, dict[str, str]],
    magic_rows: Sequence[dict[str, str]],
    *,
    max_eas: int,
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

    decisions: list[dict] = []
    planned: list[Candidate] = []
    eligible = 0
    for item in candidates:
        issue = _candidate_issue_for_repo(repo, item, ea_registry.get(item.ea_id))
        existing = by_ea.get(item.ea_id, [])
        active = [row for row in existing if str(row.get("status") or "").strip().lower() != "retired"]
        retired = [row for row in existing if str(row.get("status") or "").strip().lower() == "retired"]
        decision = {
            "ea_id": f"QM5_{item.ea_id}",
            "slug": item.slug,
            "stage": item.stage,
            "symbols": list(item.symbols),
            "symbol_policy": item.symbol_policy,
        }
        if issue:
            decision.update(action="skip", reason=issue)
        elif active:
            eligible += 1
            decision.update(action="skip", reason="already_allocated", existing_rows=len(active))
        else:
            eligible += 1
            if max_eas and len(planned) >= max_eas:
                decision.update(action="defer", reason="batch_cap")
            else:
                planned.append(item)
                decision.update(
                    action="allocate",
                    reason="eligible",
                    rows=len(item.symbols),
                    retired_rows_to_delete=len(retired),
                    create_directory=not item.directory.is_dir(),
                    copy_card=not (item.directory / "docs/strategy_card.md").is_file(),
                )
        decisions.append(decision)

    allocated_before = sum(
        1
        for item in candidates
        if _candidate_issue_for_repo(repo, item, ea_registry.get(item.ea_id)) is None
        and any(
            str(row.get("status") or "").strip().lower() != "retired"
            for row in by_ea.get(item.ea_id, [])
        )
    )
    return {
        "schema": "qm.governed-magic-allocation/v1",
        "stage_order": list(STAGE_ORDER),
        "batch_cap": max_eas,
        "eligible": eligible,
        "allocated_before": allocated_before,
        "planned": planned,
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


def _write_magic_registry(path: Path, fieldnames: Sequence[str], rows: Sequence[dict[str, str]]) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(fieldnames), extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


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
    registry_path = repo / MAGIC_REGISTRY
    resolver_path = repo / MAGIC_RESOLVER
    registry_before = registry_path.read_bytes()
    resolver_before = resolver_path.read_bytes()
    resolver_rows_before = len(_resolver_rows(resolver_path))
    created_dirs: list[Path] = []
    created_cards: list[Path] = []
    now = dt.datetime.now(dt.UTC).date().isoformat()
    new_rows: list[dict[str, str]] = []
    selected_ids = {item.ea_id for item in planned}
    retained_rows = [
        row
        for row in magic_rows
        if not (
            _numeric_ea_id(row.get("ea_id")) in selected_ids
            and str(row.get("status") or "").strip().lower() == "retired"
        )
    ]
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

        _write_magic_registry(registry_path, magic_fields, retained_rows + new_rows)
        regenerate(repo)
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
        "registry_rows_before": len(magic_rows),
        "registry_rows_after": len(retained_rows) + len(new_rows),
        "resolver_rows_before": resolver_rows_before,
        "resolver_rows_after": resolver_rows_after,
        "retired_rows_deleted": len(magic_rows) - len(retained_rows),
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
    parser.add_argument("--lock-path", type=Path, default=DEFAULT_LOCK)
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args(argv)
    repo = args.repo.resolve()
    if args.max_eas < 0 or (args.max_eas == 0 and not args.dry_run):
        parser.error("--max-eas 0 is allowed only with --dry-run")
    try:
        with serial_lock(args.lock_path):
            dirty = dirty_registry_paths(repo)
            if dirty:
                raise AllocationError("dirty_registry_abort:" + "|".join(dirty))
            candidates = load_candidates(repo, args.fleet_worklist, args.century_worklist)
            dl087_verified = None
            if args.scope == "dl087":
                candidates = [item for item in candidates if item.symbol_policy == DL087_POLICY]
                if len(candidates) != DL087_EXPECTED_EAS:
                    raise AllocationError(
                        f"dl087_candidate_count_mismatch:expected={DL087_EXPECTED_EAS}:actual={len(candidates)}"
                    )
                dl087_verified = validate_dl087_symbols(repo)
            ea_registry = _active_ea_registry(repo / EA_ID_REGISTRY)
            magic_fields, magic_rows = _read_csv(repo / MAGIC_REGISTRY)
            if magic_fields != MAGIC_FIELDS:
                raise AllocationError(f"unexpected_magic_registry_columns:{magic_fields}")
            plan = build_plan(repo, candidates, ea_registry, magic_rows, max_eas=args.max_eas)
            result = None if args.dry_run else apply_plan(repo, plan, magic_fields, magic_rows)
            report = _public_report(plan, dry_run=args.dry_run, result=result)
            report["scope"] = args.scope
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
