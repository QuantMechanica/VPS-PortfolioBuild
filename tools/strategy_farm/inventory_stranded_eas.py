#!/usr/bin/env python3
"""Read-only inventory of EAs stranded between authoring and Q-pipeline work."""

from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
from typing import Any, Iterable


SCHEMA = "qm.stranded-ea-inventory/v1"
TASK_ID = "74bff206-cd82-4fef-ac48-c26536b9cc3c"
EA_DIR_RE = re.compile(r"^QM5_(\d+)_(.+)$", re.IGNORECASE)
FRONT_MATTER_RE = re.compile(r"\A\s*---\s*\n(.*?)\n---", re.DOTALL)
FIELD_RE_TEMPLATE = r"(?mi)^\s*{field}\s*:\s*(.*?)\s*$"


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def _field(front_matter: str, name: str) -> str | None:
    match = re.search(FIELD_RE_TEMPLATE.format(field=re.escape(name)), front_matter)
    if not match:
        return None
    value = match.group(1).strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    return value


def _parse_symbols(front_matter: str) -> list[str]:
    inline = _field(front_matter, "target_symbols")
    if inline is None:
        return []
    if inline.startswith("[") and inline.endswith("]"):
        values = inline[1:-1].split(",")
        return sorted({value.strip().strip("'\"") for value in values if value.strip()})
    if inline:
        return [inline.strip().strip("'\"")]

    lines = front_matter.splitlines()
    start = next(
        (index for index, line in enumerate(lines) if re.match(r"^\s*target_symbols\s*:\s*$", line)),
        None,
    )
    if start is None:
        return []
    values = []
    for line in lines[start + 1 :]:
        match = re.match(r"^\s+-\s*(.*?)\s*$", line)
        if not match:
            if line.strip():
                break
            continue
        values.append(match.group(1).strip().strip("'\""))
    return sorted(set(values))


def _parse_card(path: Path, repo_root: Path | None = None) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    match = FRONT_MATTER_RE.search(text)
    if not match:
        return None
    front = match.group(1)
    raw_ea_id = _field(front, "ea_id")
    slug = _field(front, "slug")
    status = (_field(front, "g0_status") or "").upper()
    if raw_ea_id is None or slug is None or status != "APPROVED":
        return None
    ea_match = re.fullmatch(r"(?:QM5_)?(\d+)", raw_ea_id, re.IGNORECASE)
    if not ea_match:
        return None
    return {
        "ea_id_numeric": int(ea_match.group(1)),
        "ea_id": f"QM5_{int(ea_match.group(1))}",
        "slug": slug,
        "target_symbols": _parse_symbols(front),
        "path": str(path if repo_root is None else path.relative_to(repo_root)),
        "sha256": sha256_file(path),
    }


def _csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _numeric_ea_id(raw: str) -> int:
    match = re.fullmatch(r"(?:QM5_)?(\d+)", str(raw).strip(), re.IGNORECASE)
    if not match:
        raise ValueError(f"invalid EA ID: {raw!r}")
    return int(match.group(1))


def _extract_array(source: str, name: str) -> str:
    match = re.search(
        rf"\b{name}\s*\[[^\]]+\]\s*=\s*\{{(.*?)\}}\s*;",
        source,
        re.DOTALL,
    )
    if not match:
        raise ValueError(f"resolver array missing: {name}")
    return match.group(1)


def _parse_resolver(path: Path) -> list[dict[str, Any]]:
    source = path.read_text(encoding="utf-8-sig", errors="strict")
    ea_ids = [int(value.strip()) for value in _extract_array(source, "QM_MAGIC_REG_EA_ID").split(",") if value.strip()]
    slots = [int(value.strip()) for value in _extract_array(source, "QM_MAGIC_REG_SLOT").split(",") if value.strip()]
    symbols = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', _extract_array(source, "QM_MAGIC_REG_SYMBOL"))
    magics = [int(value.strip()) for value in _extract_array(source, "QM_MAGIC_REG_MAGIC").split(",") if value.strip()]
    lengths = {len(ea_ids), len(slots), len(symbols), len(magics)}
    if len(lengths) != 1:
        raise ValueError(
            f"resolver array length mismatch: ea={len(ea_ids)} slot={len(slots)} "
            f"symbol={len(symbols)} magic={len(magics)}"
        )
    return [
        {"ea_id_numeric": ea_id, "symbol_slot": slot, "symbol": symbol, "magic": magic}
        for ea_id, slot, symbol, magic in zip(ea_ids, slots, symbols, magics)
    ]


def _git_lines(repo_root: Path, *args: str, zero_terminated: bool = False) -> list[str]:
    result = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        check=True,
        capture_output=True,
    )
    separator = b"\0" if zero_terminated else b"\n"
    return [part.decode("utf-8", errors="surrogateescape") for part in result.stdout.split(separator) if part]


def _work_item_counts(db: Path) -> dict[str, int]:
    if not db.is_file():
        raise FileNotFoundError(f"farm database missing: {db}")
    with sqlite3.connect(f"file:{db.resolve().as_posix()}?mode=ro", uri=True) as conn:
        return {
            str(ea_id): int(count)
            for ea_id, count in conn.execute(
                "SELECT ea_id, COUNT(*) FROM work_items GROUP BY ea_id"
            ).fetchall()
        }


def _relative_paths(paths: Iterable[Path], root: Path) -> list[str]:
    return [path.relative_to(root).as_posix() for path in sorted(paths)]


def build_inventory(repo_root: Path, farm_root: Path) -> dict[str, Any]:
    repo_root = repo_root.resolve()
    farm_root = farm_root.resolve()
    eas_root = repo_root / "framework" / "EAs"
    ea_registry_path = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    magic_registry_path = repo_root / "framework" / "registry" / "magic_numbers.csv"
    resolver_path = repo_root / "framework" / "include" / "QM" / "QM_MagicResolver.mqh"
    cards_root = farm_root / "artifacts" / "cards_approved"
    db_path = farm_root / "state" / "farm_state.sqlite"

    tracked_files = set(_git_lines(repo_root, "ls-files", "-z", "--", "framework/EAs", zero_terminated=True))
    tracked_by_dir: Counter[str] = Counter()
    for relative in tracked_files:
        parts = Path(relative).parts
        if len(parts) >= 3:
            tracked_by_dir[parts[2]] += 1

    ea_registry = [
        row for row in _csv_rows(ea_registry_path)
        if row.get("status", "").casefold() != "retired"
    ]
    ea_registry_by_id: dict[int, list[dict[str, str]]] = defaultdict(list)
    for row in ea_registry:
        ea_registry_by_id[_numeric_ea_id(row["ea_id"])].append(row)

    # The resolver generator includes both ``reserved`` and ``active`` rows;
    # only ``retired`` is excluded.  Inventory must use that same contract or
    # it falsely reports every pre-build reservation as absent.
    magic_rows = [
        row for row in _csv_rows(magic_registry_path)
        if row.get("status", "").casefold() != "retired"
    ]
    magic_by_id: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in magic_rows:
        numeric_magic_ea_id = _numeric_ea_id(row["ea_id"])
        magic_by_id[numeric_magic_ea_id].append(
            {
                "ea_id_numeric": numeric_magic_ea_id,
                "ea_slug": row["ea_slug"],
                "symbol_slot": int(row["symbol_slot"]),
                "symbol": row["symbol"],
                "magic": int(row["magic"]),
            }
        )
    for rows in magic_by_id.values():
        rows.sort(key=lambda row: (row["symbol_slot"], row["symbol"], row["magic"]))

    resolver_rows = _parse_resolver(resolver_path)
    resolver_by_id: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for row in resolver_rows:
        resolver_by_id[int(row["ea_id_numeric"])].append(row)
    resolver_set = {
        (row["ea_id_numeric"], row["symbol_slot"], row["symbol"], row["magic"])
        for row in resolver_rows
    }

    cards = []
    for path in sorted(cards_root.glob("*.md"), key=lambda item: item.name.casefold()):
        card = _parse_card(path)
        if card is not None:
            card["path"] = str(path)
            cards.append(card)
    cards_by_identity: dict[tuple[int, str], list[dict[str, Any]]] = defaultdict(list)
    for card in cards:
        cards_by_identity[(card["ea_id_numeric"], card["slug"])].append(card)

    work_counts = _work_item_counts(db_path)
    ea_directories = [
        path for path in sorted(eas_root.iterdir(), key=lambda item: item.name.casefold())
        if path.is_dir() and EA_DIR_RE.match(path.name)
    ]
    entries: dict[str, dict[str, Any]] = {}
    for directory in ea_directories:
        match = EA_DIR_RE.match(directory.name)
        if not match:
            continue
        numeric_id = int(match.group(1))
        slug = match.group(2)
        sources = sorted(directory.glob("*.mq5"))
        binaries = sorted(directory.glob("*.ex5"))
        setfiles = sorted((directory / "sets").glob("*.set")) if (directory / "sets").is_dir() else []
        classes: list[str] = []
        missing: list[dict[str, Any]] = []
        if sources and not binaries:
            classes.append("authored_not_built")
            missing.append(
                {
                    "component": "compiled_binary",
                    "expected": "at least one top-level .ex5 beside the authored .mq5",
                    "actual_count": 0,
                }
            )
        work_item_count = work_counts.get(f"QM5_{numeric_id}", 0)
        if binaries and setfiles and work_item_count == 0:
            classes.append("built_not_dispatched")
            missing.append(
                {
                    "component": "work_items",
                    "expected": "at least one row for the EA ID",
                    "actual_count": 0,
                }
            )
        tracked_count = int(tracked_by_dir[directory.name])
        if tracked_count == 0:
            classes.append("untracked_in_git")
            missing.append(
                {
                    "component": "git_tracking",
                    "expected": "at least one tracked path beneath the EA directory",
                    "actual_count": 0,
                }
            )
        entries[directory.name] = {
            "key": directory.name,
            "ea_id": f"QM5_{numeric_id}",
            "ea_id_numeric": numeric_id,
            "slug": slug,
            "directory": directory.relative_to(repo_root).as_posix(),
            "classes": classes,
            "missing": missing,
            "state": {
                "mq5": _relative_paths(sources, repo_root),
                "ex5": _relative_paths(binaries, repo_root),
                "setfiles": _relative_paths(setfiles, repo_root),
                "work_item_count": work_item_count,
                "git_tracked_file_count": tracked_count,
            },
        }

    # Registry blocking is card identity scoped and can exist before an EA
    # directory is authored (QM5_36005 is the reference case).
    for (numeric_id, slug), identity_cards in sorted(cards_by_identity.items()):
        registry_rows = ea_registry_by_id.get(numeric_id, [])
        if not registry_rows:
            continue  # outside the requested "ea_id row exists" class
        expected_symbols = sorted(
            {symbol for card in identity_cards for symbol in card["target_symbols"]}
        )
        registry_magic = magic_by_id.get(numeric_id, [])
        actual_symbols = {row["symbol"] for row in registry_magic}
        missing_symbols = sorted(set(expected_symbols) - actual_symbols)
        missing_resolver = [
            row
            for row in registry_magic
            if (numeric_id, row["symbol_slot"], row["symbol"], row["magic"]) not in resolver_set
        ]
        registry_missing: list[dict[str, Any]] = []
        if not registry_magic:
            registry_missing.append(
                {
                    "component": "magic_numbers.non_retired_rows",
                    "expected": "one or more deterministic reserved/active rows",
                    "actual_count": 0,
                }
            )
        if missing_symbols:
            registry_missing.append(
                {
                    "component": "magic_numbers.target_symbols",
                    "missing_symbols": missing_symbols,
                    "expected_symbols": expected_symbols,
                    "actual_symbols": sorted(actual_symbols),
                }
            )
        if missing_resolver:
            registry_missing.append(
                {
                    "component": "generated_resolver.entries",
                    "missing_rows": missing_resolver,
                }
            )
        if not registry_missing:
            continue

        key = f"QM5_{numeric_id}_{slug}"
        entry = entries.get(key)
        if entry is None:
            entry = {
                "key": key,
                "ea_id": f"QM5_{numeric_id}",
                "ea_id_numeric": numeric_id,
                "slug": slug,
                "directory": None,
                "classes": [],
                "missing": [],
                "state": {
                    "mq5": [],
                    "ex5": [],
                    "setfiles": [],
                    "work_item_count": work_counts.get(f"QM5_{numeric_id}", 0),
                    "git_tracked_file_count": 0,
                },
            }
            entries[key] = entry
        entry["classes"].append("blocked_on_registry")
        entry["missing"].extend(registry_missing)
        entry["state"].update(
            {
                "approved_cards": [
                    {
                        "path": card["path"],
                        "sha256": card["sha256"],
                        "target_symbols": card["target_symbols"],
                    }
                    for card in identity_cards
                ],
                "ea_id_registry_rows": registry_rows,
                "registry_magic_rows": registry_magic,
                "generated_resolver_rows": resolver_by_id.get(numeric_id, []),
            }
        )

    stranded = []
    for entry in entries.values():
        entry["classes"] = sorted(set(entry["classes"]))
        if entry["classes"]:
            stranded.append(entry)
    stranded.sort(key=lambda row: (row["ea_id_numeric"], row["slug"], row["key"]))
    class_counts = Counter(class_name for row in stranded for class_name in row["classes"])

    relevant_work_rows = sorted((ea_id, count) for ea_id, count in work_counts.items())
    card_fingerprint = sha256_bytes(
        "".join(f"{card['path']}\0{card['sha256']}\n" for card in cards).encode("utf-8")
    )
    return {
        "schema": SCHEMA,
        "task_id": TASK_ID,
        "scope": {
            "repo_root": str(repo_root),
            "farm_root": str(farm_root),
            "classes": {
                "authored_not_built": "EA directory has top-level .mq5 and no top-level .ex5",
                "built_not_dispatched": "EA directory has .ex5 and setfiles, but its EA ID has zero work_items",
                "blocked_on_registry": (
                    "APPROVED card and non-retired ea_id_registry row exist, but non-retired magic rows, "
                    "card target-symbol rows, or exact generated resolver entries are missing"
                ),
                "untracked_in_git": "EA directory exists on disk with zero tracked paths beneath it",
            },
            "overlap_rule": "classes are independent; one EA can appear in multiple classes",
            "mutation_policy": "read-only inventory; no repair/build/enqueue performed",
        },
        "counts": {
            "stranded_entries": len(stranded),
            "class_memberships": dict(sorted(class_counts.items())),
            "ea_directories_scanned": len(ea_directories),
            "approved_cards_parsed": len(cards),
            "non_retired_ea_id_registry_rows": len(ea_registry),
            "non_retired_magic_rows": len(magic_rows),
            "generated_resolver_rows": len(resolver_rows),
        },
        "provenance": {
            "git_tracked_ea_paths_sha256": sha256_bytes(
                "\n".join(sorted(tracked_files)).encode("utf-8")
            ),
            "approved_cards_fingerprint_sha256": card_fingerprint,
            "ea_id_registry_sha256": sha256_file(ea_registry_path),
            "magic_numbers_sha256": sha256_file(magic_registry_path),
            "magic_resolver_sha256": sha256_file(resolver_path),
            "work_item_counts_sha256": sha256_bytes(
                json.dumps(relevant_work_rows, separators=(",", ":")).encode("utf-8")
            ),
        },
        "eas": stranded,
    }


def render_inventory(inventory: dict[str, Any]) -> bytes:
    return (json.dumps(inventory, indent=2, sort_keys=True) + "\n").encode("utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--farm-root", type=Path, default=Path(r"D:\QM\strategy_farm"))
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    rendered = render_inventory(build_inventory(args.repo_root, args.farm_root))
    output = args.output.resolve()
    if args.check:
        if not output.is_file() or output.read_bytes() != rendered:
            print(f"STALE: {output}")
            return 1
        print(f"PASS: {output} ({sha256_bytes(rendered)})")
        return 0
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(rendered)
    print(f"WROTE: {output} ({sha256_bytes(rendered)})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
