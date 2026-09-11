#!/usr/bin/env python3
"""Build the fail-closed evidence exclusion plan for tester-cache purges.

The scheduled PowerShell purge deletes only regenerable MT5 ``Tester`` targets,
but an ``Agent-*`` target can also contain a gate JSON artifact awaiting durable
ingestion.  This helper binds the current portfolio register and OWNER-signed
live manifest, then identifies top-level purge targets that must be retained.

Any source/read/scan error is fatal: the caller must skip the purge rather than
continue with an incomplete exclusion set.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path
from typing import Mapping, Any, Iterable


SCHEMA = "qm.tester-cache-purge-guard/v1"
DEFAULT_DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_LIVE_PULSE = Path(r"D:/QM/reports/state/live_book_pulse.json")
DEFAULT_MT5_ROOT = Path(r"D:/QM/mt5")
DEFAULT_RESEARCH_CENSUS_ROOT = Path(r"D:/QM/strategy_farm/artifacts/opt_census")
DEFAULT_CAMPAIGN_PLAN = Path(
    r"D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json"
)
DEFAULT_NATIVE_EXPORT_ROOT = Path(r"D:/QM/mt5/T_Export/MQL5/Files")
TERMINALS = tuple(f"T{number}" for number in range(1, 11))
EA_PATTERN = re.compile(r"(?i)QM5[_-]?(\d+)(?!\d)")
Q_PHASE_PATTERN = re.compile(r"(?i)(?:^|[\\/_.-])Q(?:0\d|1[0-6])(?:$|[\\/_.-])")
MAX_JSON_BYTES = 32 * 1024 * 1024
NATIVE_EXPORT_PATTERNS = (
    "T_EXPORT_*_HIGH_2018_2025_NATIVE.csv",
    "*.DWX_M5.csv",
    "*.DWX_D1.csv",
)


Pair = tuple[str, str]


class GuardError(RuntimeError):
    """A condition that makes the purge exclusion set untrustworthy."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _retention_source_targets(campaign_plan: Path, native_export_root: Path) -> list[dict[str, Any]]:
    """Bind non-regenerable DL-090 sources into every purge exclusion plan."""
    campaign = campaign_plan.resolve()
    export_root = native_export_root.resolve()
    if not campaign.is_file():
        raise GuardError(f"campaign_plan_missing:{campaign}")
    if not export_root.is_dir():
        raise GuardError(f"native_export_root_missing:{export_root}")
    discovered: dict[Path, str] = {campaign: "dl090_campaign_plan_spawn_binding"}
    for pattern in NATIVE_EXPORT_PATTERNS:
        matches = sorted(path.resolve() for path in export_root.glob(pattern) if path.is_file())
        if not matches:
            raise GuardError(f"native_export_class_missing:{export_root}:{pattern}")
        reason = (
            "dl090_native_calendar_export"
            if pattern.startswith("T_EXPORT_")
            else "dl090_native_bar_export"
        )
        for path in matches:
            discovered[path] = reason
    return [
        {
            "terminal": "DL090_RETENTION_SOURCE",
            "path": str(path),
            "reasons": [{
                "artifact": str(path), "reason": reason, "pairs": [],
                "sha256": _sha256(path),
            }],
        }
        for path, reason in sorted(discovered.items(), key=lambda item: str(item[0]).lower())
    ]


def _load_json(path: Path, label: str) -> Any:
    if not path.is_file():
        raise GuardError(f"{label}_missing:{path}")
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise GuardError(f"{label}_unreadable:{path}:{exc}") from exc


def normalize_ea_id(value: Any) -> str:
    if isinstance(value, bool) or value is None:
        raise GuardError(f"invalid_ea_id:{value!r}")
    if isinstance(value, int):
        number = value
    else:
        text = str(value).strip()
        match = EA_PATTERN.search(text)
        if match:
            number = int(match.group(1))
        elif text.isdigit():
            number = int(text)
        else:
            raise GuardError(f"invalid_ea_id:{value!r}")
    if number <= 0:
        raise GuardError(f"invalid_ea_id:{value!r}")
    return str(number)


def normalize_symbol(value: Any) -> str:
    if value is None:
        raise GuardError("invalid_symbol:None")
    symbol = str(value).strip().upper().replace("_DWX", ".DWX")
    if symbol.endswith(".DWX"):
        symbol = symbol[:-4]
    if not symbol or not re.fullmatch(r"[A-Z0-9][A-Z0-9._-]{0,127}", symbol):
        raise GuardError(f"invalid_symbol:{value!r}")
    return symbol


def ledger_symbol(ledger: Mapping[str, Any]) -> Any:
    """Symbol of a research/census ledger.

    2026-09-11: config_sweep ledgers (schema qm.window-sweep.v1, e.g.
    WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025) carry no top-level ``symbol``;
    the guard then raised invalid_symbol:None on every purge run and the
    10-minute purge was fail-closed for ~10 h (D: 58 GB).  Fall back to the
    ``<SYMBOL>_DWX_<from>_<to>`` suffix of the program id; still None when the
    program id does not carry it, so the fail-closed behaviour is unchanged.
    """
    symbol = ledger.get("symbol")
    if symbol is not None:
        return symbol
    match = re.search(r"_([A-Z0-9]+)_DWX_\d{4}_\d{4}$", str(ledger.get("program_id") or ""))
    return f"{match.group(1)}.DWX" if match else None


def canonical_pair(ea_id: Any, symbol: Any) -> Pair:
    return normalize_ea_id(ea_id), normalize_symbol(symbol)


def display_symbol(symbol: str) -> str:
    """Render normal host symbols with DWX while preserving basket identifiers."""
    return symbol if symbol.startswith("QM5_") else f"{symbol}.DWX"


def _read_portfolio_pairs(db_path: Path) -> set[Pair]:
    if not db_path.is_file():
        raise GuardError(f"farm_db_missing:{db_path}")
    try:
        uri = db_path.resolve().as_uri() + "?mode=ro"
        connection = sqlite3.connect(uri, uri=True, timeout=10)
        try:
            table = connection.execute(
                "SELECT 1 FROM sqlite_master WHERE type='table' AND name='portfolio_candidates'"
            ).fetchone()
            if table is None:
                raise GuardError("portfolio_candidates_table_missing")
            columns = {
                row[1] for row in connection.execute("PRAGMA table_info(portfolio_candidates)")
            }
            if not {"ea_id", "symbol"}.issubset(columns):
                raise GuardError("portfolio_candidates_schema_invalid")
            rows = connection.execute(
                "SELECT ea_id, symbol FROM portfolio_candidates ORDER BY ea_id, symbol"
            ).fetchall()
        finally:
            connection.close()
    except GuardError:
        raise
    except sqlite3.Error as exc:
        raise GuardError(f"farm_db_unreadable:{db_path}:{exc}") from exc

    pairs: set[Pair] = set()
    for ea_id, symbol in rows:
        pairs.add(canonical_pair(ea_id, symbol))
    return pairs


def _manifest_pairs(rows: Any, label: str) -> set[Pair]:
    if not isinstance(rows, list) or not rows:
        raise GuardError(f"{label}_sleeves_missing")
    pairs: set[Pair] = set()
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise GuardError(f"{label}_sleeve_invalid:{index}")
        try:
            pairs.add(canonical_pair(row.get("ea_id"), row.get("symbol")))
        except GuardError as exc:
            raise GuardError(f"{label}_sleeve_invalid:{index}:{exc}") from exc
    return pairs


def _read_research_pairs(db_path: Path, census_root: Path) -> set[Pair]:
    """Protect historical Q11 successes and declared DL-089 dependencies too.

    A cache purge cannot adjudicate whether an old successful witness will be
    needed again. Extra protection is conservative; it grants no gate authority.
    """
    try:
        from tools.strategy_farm import rebaseline_census as census
    except ModuleNotFoundError:
        import rebaseline_census as census
    if not census_root.is_dir():
        raise GuardError(f"research_census_root_missing:{census_root}")
    connection = sqlite3.connect(db_path.resolve().as_uri() + "?mode=ro", uri=True, timeout=10)
    try:
        rows = connection.execute(
            "SELECT ea_id,symbol,phase,gate_contract_version,verdict FROM work_items "
            "WHERE status='done' AND ea_id IS NOT NULL AND symbol IS NOT NULL"
        ).fetchall()
    except sqlite3.Error as exc:
        raise GuardError(f"research_frontier_unreadable:{exc}") from exc
    finally:
        connection.close()
    pairs: set[Pair] = set()
    resolved: dict[tuple, str | None] = {}
    for ea, symbol, phase, version, verdict in rows:
        key = (phase, version)
        if key not in resolved:
            resolved[key] = census.canonical_gate(phase, version)
        gate = resolved[key]
        if gate == "Q11" and census.vclass(verdict, gate) == "PASS":
            pairs.add(canonical_pair(ea, symbol))
    for path in sorted(census_root.glob("*/ledger.json")):
        ledger = _load_json(path, "research_census_ledger")
        if not isinstance(ledger, dict) or not ledger.get("program_id"):
            raise GuardError(f"research_census_ledger_invalid:{path}")
        symbol = ledger_symbol(ledger)
        pairs.add(canonical_pair(ledger.get("subject_ea_id") or ledger.get("ea_id"), symbol))
        pairs.add(canonical_pair(ledger.get("ea_id"), symbol))
    return pairs


def _read_live_manifest_binding(pulse_path: Path) -> tuple[set[Pair], Path, str, str]:
    pulse = _load_json(pulse_path, "live_pulse")
    if not isinstance(pulse, dict):
        raise GuardError("live_pulse_not_object")
    binding = pulse.get("book_manifest")
    if not isinstance(binding, dict):
        raise GuardError("live_pulse_book_manifest_missing")
    if binding.get("enabled") is not True:
        raise GuardError("live_manifest_not_enabled")
    if binding.get("loaded") is not True or binding.get("exists") is not True:
        raise GuardError("live_manifest_not_loaded")
    if binding.get("error") not in (None, ""):
        raise GuardError(f"live_manifest_binding_error:{binding.get('error')}")
    if str(binding.get("status") or "").upper() != "LIVE":
        raise GuardError(f"live_manifest_binding_not_live:{binding.get('status')}")

    manifest_raw = binding.get("path")
    expected_hash = str(binding.get("sha256") or "").lower()
    if not manifest_raw or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
        raise GuardError("live_manifest_binding_incomplete")
    manifest_path = Path(str(manifest_raw))
    if not manifest_path.is_absolute():
        manifest_path = pulse_path.parent / manifest_path
    if not manifest_path.is_file():
        raise GuardError(f"live_manifest_missing:{manifest_path}")
    actual_hash = _sha256(manifest_path)
    if actual_hash != expected_hash:
        raise GuardError(
            f"live_manifest_hash_mismatch:expected={expected_hash}:actual={actual_hash}"
        )

    manifest = _load_json(manifest_path, "live_manifest")
    if not isinstance(manifest, dict):
        raise GuardError("live_manifest_not_object")
    if str(manifest.get("status") or "").upper() != "LIVE":
        raise GuardError(f"live_manifest_not_live:{manifest.get('status')}")
    if not str(manifest.get("approved_by") or "").strip():
        raise GuardError("live_manifest_approval_missing")

    manifest_rows = manifest.get("sleeves")
    manifest_pairs = _manifest_pairs(manifest_rows, "live_manifest")
    declared_count = manifest.get("n_sleeves")
    if isinstance(declared_count, bool) or not isinstance(declared_count, int):
        raise GuardError("live_manifest_count_invalid")
    if declared_count != len(manifest_rows):
        raise GuardError(
            f"live_manifest_count_mismatch:declared={declared_count}:actual={len(manifest_rows)}"
        )

    pulse_pairs = _manifest_pairs(binding.get("sleeves"), "live_pulse")
    if pulse_pairs != manifest_pairs:
        raise GuardError("live_pulse_manifest_pair_mismatch")
    pulse_count = binding.get("actual_manifest_sleeve_count")
    if pulse_count != len(manifest_rows):
        raise GuardError(
            f"live_pulse_manifest_count_mismatch:pulse={pulse_count}:actual={len(manifest_rows)}"
        )

    return manifest_pairs, manifest_path.resolve(), actual_hash, _sha256(pulse_path)


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _purge_targets(mt5_root: Path, terminals: Iterable[str]) -> list[tuple[str, Path]]:
    root = mt5_root.resolve()
    targets: list[tuple[str, Path]] = []
    for terminal in terminals:
        if terminal not in TERMINALS:
            raise GuardError(f"invalid_terminal:{terminal}")
        tester_root = (root / terminal / "Tester").resolve()
        if not tester_root.is_dir():
            continue
        bases = tester_root / "bases"
        try:
            if bases.is_dir():
                for child in sorted(bases.iterdir(), key=lambda path: path.name.casefold()):
                    target = child.resolve()
                    if not _is_within(target, tester_root):
                        raise GuardError(f"purge_target_outside_tester_root:{target}")
                    targets.append((terminal, target))
            for child in sorted(tester_root.glob("Agent-*"), key=lambda path: path.name.casefold()):
                if not child.is_dir():
                    continue
                target = child.resolve()
                if not _is_within(target, tester_root):
                    raise GuardError(f"purge_target_outside_tester_root:{target}")
                targets.append((terminal, target))
        except OSError as exc:
            raise GuardError(f"purge_target_enumeration_failed:{tester_root}:{exc}") from exc
    return targets


def _contains_key(node: Any, wanted: str) -> bool:
    if isinstance(node, dict):
        for key, value in node.items():
            if str(key).casefold() == wanted:
                return True
            if _contains_key(value, wanted):
                return True
    elif isinstance(node, list):
        return any(_contains_key(item, wanted) for item in node)
    return False


def _collect_identity_values(node: Any) -> tuple[set[str], set[str]]:
    ea_ids: set[str] = set()
    symbols: set[str] = set()

    def visit(value: Any) -> None:
        if isinstance(value, dict):
            for raw_key, child in value.items():
                key = str(raw_key).casefold()
                if key in {"ea_id", "eaid"}:
                    try:
                        ea_ids.add(normalize_ea_id(child))
                    except GuardError:
                        pass
                elif key in {
                    "symbol",
                    "symbol_norm",
                    "host_symbol",
                    "chart_symbol",
                    "requested_symbol",
                    "candidate_symbol",
                }:
                    try:
                        symbols.add(normalize_symbol(child))
                    except GuardError:
                        pass
                if isinstance(child, str):
                    for match in EA_PATTERN.finditer(child):
                        ea_ids.add(str(int(match.group(1))))
                visit(child)
        elif isinstance(value, list):
            for child in value:
                visit(child)
        elif isinstance(value, str):
            for match in EA_PATTERN.finditer(value):
                ea_ids.add(str(int(match.group(1))))

    visit(node)
    return ea_ids, symbols


def _path_identity(path: Path, protected_pairs: set[Pair]) -> tuple[set[str], set[str]]:
    text = str(path).upper()
    ea_ids = {str(int(match.group(1))) for match in EA_PATTERN.finditer(text)}
    tokenized = "_" + re.sub(r"[^A-Z0-9]+", "_", text).strip("_") + "_"
    known_symbols = {symbol for _, symbol in protected_pairs}
    symbols = {
        symbol
        for symbol in known_symbols
        if f"_{re.sub(r'[^A-Z0-9]+', '_', symbol)}_" in tokenized
    }
    return ea_ids, symbols


def _artifact_match(
    artifact: Path,
    document: Any | None,
    protected_pairs: set[Pair],
) -> tuple[set[Pair], bool]:
    path_eas, path_symbols = _path_identity(artifact, protected_pairs)
    doc_eas: set[str] = set()
    doc_symbols: set[str] = set()
    if document is not None:
        doc_eas, doc_symbols = _collect_identity_values(document)
    ea_ids = path_eas | doc_eas
    symbols = path_symbols | doc_symbols
    if not ea_ids or not symbols:
        return set(), False
    candidates = {(ea_id, symbol) for ea_id in ea_ids for symbol in symbols}
    return candidates & protected_pairs, True


def _scan_target(target: Path, protected_pairs: set[Pair]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    artifacts: list[dict[str, Any]] = []
    protections: list[dict[str, Any]] = []

    def on_error(error: OSError) -> None:
        raise error

    try:
        for directory, child_dirs, filenames in os.walk(
            target, topdown=True, onerror=on_error, followlinks=False
        ):
            # Do not follow links or junction-like symlinks out of the governed target.
            child_dirs[:] = [
                name for name in child_dirs if not (Path(directory) / name).is_symlink()
            ]
            for filename in filenames:
                artifact = Path(directory) / filename
                if artifact.suffix.casefold() != ".json":
                    continue
                name = artifact.name.casefold()
                strong_name = name == "aggregate.json" or "verdict" in artifact.stem.casefold()
                phase_hint = Q_PHASE_PATTERN.search(str(artifact)) is not None
                try:
                    size = artifact.stat().st_size
                except OSError as exc:
                    if strong_name or phase_hint:
                        raise GuardError(f"gate_artifact_stat_failed:{artifact}:{exc}") from exc
                    continue
                if size > MAX_JSON_BYTES:
                    if strong_name or phase_hint:
                        protections.append(
                            {
                                "artifact": str(artifact.resolve()),
                                "reason": "unclassified_gate_artifact_too_large",
                                "pairs": [],
                            }
                        )
                    continue
                try:
                    document = json.loads(artifact.read_text(encoding="utf-8-sig"))
                except (OSError, UnicodeError, json.JSONDecodeError) as exc:
                    if strong_name or phase_hint:
                        protections.append(
                            {
                                "artifact": str(artifact.resolve()),
                                "reason": f"unclassified_gate_artifact_unreadable:{type(exc).__name__}",
                                "pairs": [],
                            }
                        )
                    continue
                is_gate_artifact = strong_name or _contains_key(document, "verdict")
                if not is_gate_artifact:
                    continue
                matches, identity_complete = _artifact_match(
                    artifact, document, protected_pairs
                )
                artifact_record = {
                    "artifact": str(artifact.resolve()),
                    "identity_complete": identity_complete,
                    "protected_pairs": [
                        {"ea_id": f"QM5_{ea_id}", "symbol": display_symbol(symbol)}
                        for ea_id, symbol in sorted(matches)
                    ],
                }
                artifacts.append(artifact_record)
                if matches:
                    protections.append(
                        {
                            "artifact": artifact_record["artifact"],
                            "reason": "protected_pair_gate_evidence",
                            "pairs": artifact_record["protected_pairs"],
                        }
                    )
                elif not identity_complete:
                    protections.append(
                        {
                            "artifact": artifact_record["artifact"],
                            "reason": "unclassified_gate_evidence_fail_closed",
                            "pairs": [],
                        }
                    )
    except GuardError:
        raise
    except OSError as exc:
        raise GuardError(f"purge_target_scan_failed:{target}:{exc}") from exc
    return artifacts, protections


def build_plan(
    db_path: Path,
    live_pulse_path: Path,
    mt5_root: Path,
    terminals: Iterable[str] = TERMINALS,
    campaign_plan: Path | None = None,
    native_export_root: Path | None = None,
    research_census_root: Path | None = None,
) -> dict[str, Any]:
    db_path = db_path.resolve()
    live_pulse_path = live_pulse_path.resolve()
    mt5_root = mt5_root.resolve()
    selected_terminals = tuple(dict.fromkeys(str(item).upper() for item in terminals))

    db_pairs = _read_portfolio_pairs(db_path)
    live_pairs, manifest_path, manifest_hash, pulse_hash = _read_live_manifest_binding(
        live_pulse_path
    )
    protected_pairs = db_pairs | live_pairs
    research_pairs = _read_research_pairs(db_path, research_census_root) if research_census_root is not None else set()
    protected_pairs |= research_pairs
    sources: dict[Pair, set[str]] = defaultdict(set)
    for pair in db_pairs:
        sources[pair].add("portfolio_candidates")
    for pair in live_pairs:
        sources[pair].add("live_manifest")
    for pair in research_pairs:
        sources[pair].add("Q11_or_DL089_dependency")

    targets = _purge_targets(mt5_root, selected_terminals)
    protected_targets: list[dict[str, Any]] = []
    evidence_artifacts_scanned = 0
    for terminal, target in targets:
        artifacts, protections = _scan_target(target, protected_pairs)
        evidence_artifacts_scanned += len(artifacts)
        if protections:
            protected_targets.append(
                {
                    "terminal": terminal,
                    "path": str(target),
                    "reasons": protections,
                }
            )

    retention_sources: list[dict[str, Any]] = []
    if campaign_plan is not None or native_export_root is not None:
        if campaign_plan is None or native_export_root is None:
            raise GuardError("retention_source_configuration_incomplete")
        retention_sources = _retention_source_targets(campaign_plan, native_export_root)
        protected_targets.extend(retention_sources)

    return {
        "schema": SCHEMA,
        "status": "PASS",
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "db_path": str(db_path),
        "live_pulse_path": str(live_pulse_path),
        "live_pulse_sha256": pulse_hash,
        "live_manifest_path": str(manifest_path),
        "live_manifest_sha256": manifest_hash,
        "mt5_root": str(mt5_root),
        "terminals": list(selected_terminals),
        "counts": {
            "portfolio_candidate_pairs": len(db_pairs),
            "live_manifest_pairs": len(live_pairs),
            "research_dependency_pairs": len(research_pairs),
            "protected_union_pairs": len(protected_pairs),
            "purge_targets_scanned": len(targets),
            "gate_evidence_artifacts_scanned": evidence_artifacts_scanned,
            "protected_targets": len(protected_targets),
            "retention_source_targets": len(retention_sources),
            "unprotected_targets": len(targets) - (len(protected_targets) - len(retention_sources)),
        },
        "protected_pairs": [
            {
                "ea_id": f"QM5_{ea_id}",
                "symbol": display_symbol(symbol),
                "sources": sorted(sources[(ea_id, symbol)]),
            }
            for ea_id, symbol in sorted(protected_pairs, key=lambda pair: (int(pair[0]), pair[1]))
        ],
        "protected_targets": protected_targets,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate the fail-closed tester-cache evidence exclusion plan."
    )
    parser.add_argument("--db-path", type=Path, default=DEFAULT_DB)
    parser.add_argument("--live-pulse", type=Path, default=DEFAULT_LIVE_PULSE)
    parser.add_argument("--mt5-root", type=Path, default=DEFAULT_MT5_ROOT)
    parser.add_argument("--campaign-plan", type=Path, default=DEFAULT_CAMPAIGN_PLAN)
    parser.add_argument("--native-export-root", type=Path, default=DEFAULT_NATIVE_EXPORT_ROOT)
    parser.add_argument("--research-census-root", type=Path, default=DEFAULT_RESEARCH_CENSUS_ROOT)
    parser.add_argument("--terminal", action="append", choices=TERMINALS)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        plan = build_plan(
            args.db_path,
            args.live_pulse,
            args.mt5_root,
            args.terminal or TERMINALS,
            args.campaign_plan,
            args.native_export_root,
            args.research_census_root,
        )
    except Exception as exc:
        error = {
            "schema": SCHEMA,
            "status": "ERROR",
            "error_type": type(exc).__name__,
            "reason": str(exc),
        }
        print(json.dumps(error, indent=2, sort_keys=True))
        return 2
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
