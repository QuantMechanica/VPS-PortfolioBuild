"""Generate the deterministic Freeze-v2 center/OAAT bundle for QM5_20009.

The detached ``manifest.sha256`` is the only object that hashes ``manifest.json``.
The manifest therefore never hashes itself.  Every set embeds a canonical
``freeze_inputs_sha256`` over sources, transitive framework includes, compile
evidence, data identities, news, costs, tester defaults and registries.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
from datetime import date
from pathlib import Path
from typing import Any, Iterable, Mapping


EA_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = EA_ROOT.parents[2]
SETS_ROOT = EA_ROOT / "sets"
EA_SOURCE = EA_ROOT / "QM5_20009_ict-liquidity-portfolio.mq5"
RULES_SOURCE = EA_ROOT / "ICT_LiquidityRules.mqh"
CONTRACT = EA_ROOT / "docs" / "strategy_contract.md"
SPEC = EA_ROOT / "SPEC.md"
PROTOCOL = EA_ROOT / "docs" / "research_protocol_v2.json"
GENERATOR = Path(__file__).resolve()
FRAMEWORK_INCLUDE_ROOT = REPO_ROOT / "framework" / "include"

MARKETS = (
    ("NDX.DWX", "M1", 0, 0, "index"),
    ("GDAXI.DWX", "M1", 1, 0, "index"),
    ("GBPUSD.DWX", "M5", 2, 1, "fx"),
    ("EURUSD.DWX", "M5", 5, 1, "fx"),
)

A_CENTER = {
    "strategy_a_pivot_wing": "2",
    "strategy_a_reclaim_bars": "3",
    "strategy_a_max_bars_to_mss": "9",
    "strategy_a_min_fvg_atr": "0.05",
    "strategy_a_sl_buffer_atr": "0.10",
    "strategy_a_min_rr": "2.0",
}
B_CENTER = {
    "strategy_b_pivot_wing": "2",
    "strategy_b_reclaim_bars": "3",
    "strategy_b_max_bars_to_mss": "12",
    "strategy_b_min_fvg_atr": "0.05",
    "strategy_b_sl_buffer_atr": "0.10",
    "strategy_b_min_rr": "2.0",
}
STARS = {
    "index": (
        ("pivot_low", "strategy_a_pivot_wing", "1"),
        ("pivot_high", "strategy_a_pivot_wing", "3"),
        ("reclaim_low", "strategy_a_reclaim_bars", "1"),
        ("reclaim_high", "strategy_a_reclaim_bars", "5"),
        ("mss_low", "strategy_a_max_bars_to_mss", "6"),
        ("mss_high", "strategy_a_max_bars_to_mss", "12"),
        ("fvg_low", "strategy_a_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_a_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_a_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_a_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_a_min_rr", "1.5"),
        ("rr_high", "strategy_a_min_rr", "2.5"),
    ),
    "fx": (
        ("pivot_low", "strategy_b_pivot_wing", "1"),
        ("pivot_high", "strategy_b_pivot_wing", "3"),
        ("reclaim_low", "strategy_b_reclaim_bars", "1"),
        ("reclaim_high", "strategy_b_reclaim_bars", "5"),
        ("mss_low", "strategy_b_max_bars_to_mss", "6"),
        ("mss_high", "strategy_b_max_bars_to_mss", "18"),
        ("fvg_low", "strategy_b_min_fvg_atr", "0.0"),
        ("fvg_high", "strategy_b_min_fvg_atr", "0.10"),
        ("stop_low", "strategy_b_sl_buffer_atr", "0.05"),
        ("stop_high", "strategy_b_sl_buffer_atr", "0.15"),
        ("rr_low", "strategy_b_min_rr", "1.5"),
        ("rr_high", "strategy_b_min_rr", "2.5"),
    ),
}

INCLUDE_RE = re.compile(r'^\s*#include\s*[<"]([^>"]+)[>"]', re.MULTILINE)
INPUT_RE = re.compile(r"^\s*input\s+(?!group\b)\S+\s+(\w+)\s*=", re.MULTILINE)
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class FreezeError(RuntimeError):
    """The requested bundle is not fully evidenced and must not be generated."""


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")


def _read_source(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def _decode_evidence_text(payload: bytes) -> str:
    if payload.startswith((b"\xff\xfe", b"\xfe\xff")):
        return payload.decode("utf-16")
    return payload.decode("utf-8-sig")


def _is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def _resolve_include(owner: Path, raw_include: str) -> Path | None:
    include = raw_include.replace("\\", "/")
    candidates = (owner.parent / include, FRAMEWORK_INCLUDE_ROOT / include)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def framework_include_closure() -> tuple[list[dict[str, object]], list[str]]:
    """Return every repo framework include reached by the EA, plus externals."""

    visited: set[Path] = set()
    external: set[str] = set()

    def scan(owner: Path) -> None:
        for raw_include in INCLUDE_RE.findall(_read_source(owner)):
            target = _resolve_include(owner, raw_include)
            if target is None:
                external.add(raw_include.replace("\\", "/"))
                continue
            if not _is_within(target, FRAMEWORK_INCLUDE_ROOT):
                # The local strategy include is hashed separately as RULES_SOURCE.
                if target == RULES_SOURCE.resolve():
                    scan(target)
                else:
                    external.add(raw_include.replace("\\", "/"))
                continue
            if target in visited:
                continue
            visited.add(target)
            scan(target)

    scan(EA_SOURCE)
    rows = [
        {
            "path": path.relative_to(REPO_ROOT).as_posix(),
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
        }
        for path in sorted(visited, key=lambda item: item.as_posix().lower())
    ]
    return rows, sorted(external)


def visible_input_names() -> list[str]:
    includes, _external = framework_include_closure()
    sources = [EA_SOURCE]
    sources.extend(REPO_ROOT / str(row["path"]) for row in includes)
    names: list[str] = []
    for source in sources:
        names.extend(INPUT_RE.findall(_read_source(source)))
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise FreezeError(f"duplicate visible input declarations: {','.join(duplicates)}")
    return names


def load_protocol(path: Path = PROTOCOL) -> dict[str, Any]:
    try:
        protocol = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise FreezeError(f"research protocol unreadable: {path}: {exc}") from exc
    validate_protocol(protocol)
    return protocol


def _parse_iso_date(value: object, label: str) -> date:
    try:
        return date.fromisoformat(str(value))
    except ValueError as exc:
        raise FreezeError(f"invalid {label}: {value!r}") from exc


def validate_protocol(protocol: Mapping[str, Any]) -> None:
    if protocol.get("schema_version") != 2 or protocol.get("ea_id") != 20009:
        raise FreezeError("research protocol schema/EA identity mismatch")
    markets = protocol.get("markets")
    if not isinstance(markets, list):
        raise FreezeError("research protocol markets must be a list")
    observed = tuple(
        (
            item.get("symbol"),
            item.get("timeframe"),
            item.get("slot"),
            item.get("mode"),
            item.get("kind"),
        )
        for item in markets
    )
    if observed != MARKETS:
        raise FreezeError(f"research protocol markets drifted: {observed!r}")
    for market in markets:
        start = _parse_iso_date(market.get("dev_from"), f"{market.get('symbol')} DEV from")
        end = _parse_iso_date(market.get("dev_to"), f"{market.get('symbol')} DEV to")
        if start > end or end >= date(2023, 1, 1):
            raise FreezeError(f"invalid DEV partition for {market.get('symbol')}")
    fx_starts = {item["dev_from"] for item in markets if item["kind"] == "fx"}
    if fx_starts != {"2017-10-01"}:
        raise FreezeError("FX DEV must start at honest Model-4 coverage 2017-10-01")

    phases = protocol.get("phases")
    if not isinstance(phases, list):
        raise FreezeError("research protocol phases must be a list")
    ids = [str(item.get("id")) for item in phases]
    required_ids = {
        "DEV",
        "OOS_2023_H1",
        "OOS_2023_H2",
        "OOS_2024_H1",
        "OOS_2024_H2",
        "OOS_2025_H1",
        "OOS_2025_H2",
        "RETRO_HOLDOUT_2026_H1",
        "PROSPECTIVE_OPERATIONAL",
    }
    if set(ids) != required_ids or len(ids) != len(set(ids)):
        raise FreezeError("research protocol phase set is incomplete or duplicated")
    for phase in phases:
        if phase.get("id") == "DEV":
            if phase.get("allowed_variants") != "ALL_13":
                raise FreezeError("DEV must allow the complete 13-point OAAT star")
            continue
        if phase.get("allowed_variants") != "CENTER_ONLY":
            raise FreezeError(f"later phase is not center-only: {phase.get('id')}")
        if not phase.get("requires_resolved_cost_axes"):
            raise FreezeError(f"later phase omits cost-resolution fence: {phase.get('id')}")
        _parse_iso_date(phase.get("from"), f"{phase.get('id')} from")
        _parse_iso_date(phase.get("to"), f"{phase.get('id')} to")

    tester = protocol.get("tester")
    if not isinstance(tester, Mapping) or tester.get("visible_input_count") != 35:
        raise FreezeError("tester visible_input_count must be 35")
    if tester.get("framework_inputs") != {
        "InpQMSimCommissionPerLot": 0.0,
        "qm_chartui_enabled": False,
        "qm_chartui_corner": 0,
    }:
        raise FreezeError("tester framework input freeze drifted")

    blockers = protocol.get("qualification_blocking_cost_axes")
    costs = protocol.get("costs")
    if blockers != ["slippage", "overnight_swap_proof"] or not isinstance(costs, Mapping):
        raise FreezeError("qualification cost blocker declaration drifted")
    for axis in blockers:
        row = costs.get(axis)
        if not isinstance(row, Mapping) or row.get("status") not in {"RESOLVED", "UNRESOLVED"}:
            raise FreezeError(f"invalid cost status for {axis}")

    artifacts = protocol.get("evidence_artifacts")
    if not isinstance(artifacts, list):
        raise FreezeError("evidence_artifacts must be a list")
    artifact_ids = [str(item.get("id")) for item in artifacts]
    if len(artifact_ids) != len(set(artifact_ids)):
        raise FreezeError("duplicate evidence artifact id")
    required_artifacts = {
        "ea_binary",
        "ea_binary_repo",
        "compile_evidence",
        "compiler_log",
        "compiler_binary",
        "compile_include_path_audit",
        "provisioning_tick_hash_manifest",
        "news_shared_primary",
        "news_shared_secondary",
        "news_qmdev1_common_primary",
        "news_qmdev1_common_secondary",
        "venue_cost_model",
        "live_commission_model",
        "slippage_calibration",
        "slippage_livefill_ledger",
        "tester_defaults",
        "commission_groups_canonical",
        "commission_groups_dev1",
        "registry_execution_contract",
    }
    missing = sorted(required_artifacts - set(artifact_ids))
    if missing:
        raise FreezeError(f"mandatory evidence artifacts missing: {','.join(missing)}")


def _artifact_path(raw_path: str) -> Path:
    path = Path(raw_path)
    return path if path.is_absolute() else REPO_ROOT / path


def _manifest_path(path: Path, declared_path: str, overridden: bool) -> str:
    if not overridden and not Path(declared_path).is_absolute():
        return declared_path.replace("\\", "/")
    return path.resolve().as_posix()


def _validate_artifact_payload(artifact_id: str, validation: str, path: Path) -> None:
    if path.stat().st_size <= 0:
        raise FreezeError(f"mandatory evidence artifact empty: {artifact_id}: {path}")
    if validation == "METAEDITOR_ZERO_ERRORS_ZERO_WARNINGS":
        text = _decode_evidence_text(path.read_bytes())
        if not re.search(r"Result:\s*0 errors,\s*0 warnings\b", text):
            raise FreezeError(f"compiler log is not clean: {path}")
    elif validation == "INCLUDE_PATH_AUDIT_ALL_ALLOWED":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or any(str(row.get("allowed", "")).lower() != "true" for row in rows):
            raise FreezeError(f"compile include audit contains an outside path: {path}")
    elif validation == "PROVISIONING_HASH_MANIFEST_ALL_MATCH":
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        if not rows or any(
            str(row.get("match", "")).lower() != "true"
            or str(row.get("source_sha256", "")).lower() != str(row.get("dest_sha256", "")).lower()
            or not SHA256_RE.fullmatch(str(row.get("dest_sha256", "")).lower())
            for row in rows
        ):
            raise FreezeError(f"provisioning hash manifest contains drift/invalid hashes: {path}")
    elif validation == "COMPILE_EVIDENCE_PASS":
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except json.JSONDecodeError as exc:
            raise FreezeError(f"compile evidence JSON invalid: {path}") from exc
        if payload.get("result") != "PASS" or payload.get("errors") != 0 or payload.get("warnings") != 0:
            raise FreezeError(f"compile evidence is not PASS/0/0: {path}")
    elif validation != "NONEMPTY":
        raise FreezeError(f"unknown evidence validation {validation!r} for {artifact_id}")


def evidence_hashes(
    protocol: Mapping[str, Any],
    overrides: Mapping[str, Path] | None = None,
) -> tuple[list[dict[str, object]], dict[str, Path]]:
    overrides = overrides or {}
    rows: list[dict[str, object]] = []
    paths: dict[str, Path] = {}
    groups: dict[str, list[dict[str, object]]] = {}
    for artifact in sorted(protocol["evidence_artifacts"], key=lambda item: str(item["id"])):
        artifact_id = str(artifact["id"])
        declared = str(artifact["path"])
        overridden = artifact_id in overrides
        path = Path(overrides[artifact_id]) if overridden else _artifact_path(declared)
        if not path.is_file():
            raise FreezeError(f"mandatory evidence artifact missing: {artifact_id}: {path}")
        validation = str(artifact.get("validation", "NONEMPTY"))
        _validate_artifact_payload(artifact_id, validation, path)
        row: dict[str, object] = {
            "id": artifact_id,
            "path": _manifest_path(path, declared, overridden),
            "size": path.stat().st_size,
            "sha256": sha256_file(path),
            "validation": validation,
        }
        if "version" in artifact:
            row["version"] = artifact["version"]
        if "equality_group" in artifact:
            group = str(artifact["equality_group"])
            row["equality_group"] = group
            groups.setdefault(group, []).append(row)
        rows.append(row)
        paths[artifact_id] = path
    for group, members in groups.items():
        if len(members) < 2 or len({str(row["sha256"]) for row in members}) != 1:
            raise FreezeError(f"equality group drift: {group}")
    _validate_compile_evidence(paths, rows)
    return rows, paths


def _validate_compile_evidence(paths: Mapping[str, Path], rows: Iterable[Mapping[str, object]]) -> None:
    evidence = json.loads(paths["compile_evidence"].read_text(encoding="utf-8-sig"))
    by_id = {str(row["id"]): row for row in rows}
    expected = {
        "source_sha256": sha256_file(EA_SOURCE),
        "local_include_sha256": sha256_file(RULES_SOURCE),
        "ex5_sha256": str(by_id["ea_binary"]["sha256"]),
        "metaeditor_sha256": str(by_id["compiler_binary"]["sha256"]),
        "compile_log_sha256": str(by_id["compiler_log"]["sha256"]),
    }
    for field, wanted in expected.items():
        if str(evidence.get(field, "")).lower() != wanted.lower():
            raise FreezeError(f"compile evidence {field} does not match frozen artifact")
    if evidence.get("outside_include_paths_count") != 0 or int(evidence.get("included_paths_count", 0)) <= 0:
        raise FreezeError("compile evidence include path audit is not clean")


def _month_range(start: str, end_yyyymm: str) -> list[str]:
    cursor = date.fromisoformat(start).replace(day=1)
    end = date(int(end_yyyymm[:4]), int(end_yyyymm[4:]), 1)
    months: list[str] = []
    while cursor <= end:
        months.append(cursor.strftime("%Y%m"))
        cursor = date(cursor.year + (cursor.month == 12), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return months


def model4_data_files(
    protocol: Mapping[str, Any], artifact_paths: Mapping[str, Path]
) -> list[dict[str, object]]:
    config = protocol["model4_data"]
    manifest = artifact_paths[str(config["provisioning_manifest_artifact_id"])]
    with manifest.open("r", encoding="utf-8-sig", newline="") as handle:
        source_rows = list(csv.DictReader(handle))
    by_relative = {
        str(row["relative_path"]).replace("\\", "/"): row for row in source_rows
    }
    required: set[str] = {str(config["symbol_definition_relative_path"])}
    frozen_through = str(config["frozen_through_month"])
    for market in protocol["markets"]:
        symbol = str(market["symbol"])
        for month in _month_range(str(market["dev_from"]), frozen_through):
            required.add(f"Custom/ticks/{symbol}/{month}.tkc")
        first_year = date.fromisoformat(str(market["dev_from"])).year
        last_year = int(frozen_through[:4])
        for year in range(first_year, last_year + 1):
            required.add(f"Custom/history/{symbol}/{year}.hcc")
    missing = sorted(required - set(by_relative))
    if missing:
        raise FreezeError(f"provisioning manifest lacks required Model-4 files: {','.join(missing[:8])}")
    destination_root = _artifact_path(str(config["destination_root"]))
    rows: list[dict[str, object]] = []
    for relative in sorted(required):
        source = by_relative[relative]
        digest = str(source["dest_sha256"]).lower()
        size = int(source["dest_length"])
        actual = destination_root / Path(relative)
        if not actual.is_file() or actual.stat().st_size != size:
            raise FreezeError(f"required Model-4 file missing/size drift: {actual}")
        rows.append({"relative_path": relative, "size": size, "sha256": digest})
    return rows


def build_freeze_inputs(
    protocol: Mapping[str, Any] | None = None,
    evidence_overrides: Mapping[str, Path] | None = None,
) -> dict[str, object]:
    protocol = dict(protocol or load_protocol())
    validate_protocol(protocol)
    includes, external_includes = framework_include_closure()
    evidence, artifact_paths = evidence_hashes(protocol, evidence_overrides)
    data_files = model4_data_files(protocol, artifact_paths)
    source_hashes = {
        "ea_sha256": sha256_file(EA_SOURCE),
        "rules_sha256": sha256_file(RULES_SOURCE),
        "contract_sha256": sha256_file(CONTRACT),
        "spec_sha256": sha256_file(SPEC),
        "protocol_sha256": sha256_file(PROTOCOL),
        "generator_sha256": sha256_file(GENERATOR),
    }
    return {
        "schema_version": 2,
        "protocol_id": protocol["protocol_id"],
        "contract_freeze": protocol["contract_freeze"],
        "source_hashes": source_hashes,
        "framework_includes": includes,
        "framework_include_tree_sha256": sha256_bytes(canonical_json_bytes(includes)),
        "external_compiler_includes": external_includes,
        "evidence_artifacts": evidence,
        "model4_data_files": data_files,
        "model4_data_tree_sha256": sha256_bytes(canonical_json_bytes(data_files)),
        "cost_axis_status": {
            axis: protocol["costs"][axis]["status"]
            for axis in protocol["qualification_blocking_cost_axes"]
        },
    }


def parameter_map(slot: int, mode: int) -> dict[str, str]:
    values = {
        "qm_ea_id": "20009",
        "qm_magic_slot_offset": str(slot),
        "qm_rng_seed": "42",
        "RISK_PERCENT": "0.0",
        "RISK_FIXED": "1000.0",
        "PORTFOLIO_WEIGHT": "1.0",
        "InpQMSimCommissionPerLot": "0.0",
        "qm_news_temporal": "3",
        "qm_news_compliance": "2",
        "qm_news_stale_max_hours": "336",
        "qm_news_min_impact": "high",
        "qm_news_mode_legacy": "0",
        "qm_friday_close_enabled": "true",
        "qm_friday_close_hour_broker": "23",
        "qm_stress_reject_probability": "0.0",
        "qm_chartui_enabled": "false",
        "qm_chartui_corner": "0",
        "strategy_mode": str(mode),
        "strategy_replay_bars_index": "2500",
        "strategy_replay_bars_fx": "10000",
        **A_CENTER,
        **B_CENTER,
        "strategy_governor_policy_id": "",
        "strategy_challenge_instance_id": "",
        "strategy_governor_heartbeat_max_age_seconds": "5",
    }
    discovered = set(visible_input_names())
    if set(values) != discovered:
        missing = sorted(discovered - set(values))
        extra = sorted(set(values) - discovered)
        raise FreezeError(f"set/input closure mismatch missing={missing} extra={extra}")
    return values


def variants(kind: str) -> list[tuple[str, str | None, str | None]]:
    return [("center", None, None), *STARS[kind]]


def filename(symbol: str, timeframe: str, kind: str, variant: str) -> str:
    return f"QM5_20009_{symbol.replace('.', '_')}_{timeframe}_{kind}_{variant}.set"


def render_set(
    symbol: str,
    timeframe: str,
    slot: int,
    mode: int,
    kind: str,
    variant: str,
    changed_parameter: str | None,
    changed_value: str | None,
    freeze_inputs: Mapping[str, object],
    freeze_inputs_sha256: str,
) -> bytes:
    values = parameter_map(slot, mode)
    if changed_parameter is not None:
        if changed_value is None:
            raise FreezeError(f"variant {variant} has no changed value")
        values[changed_parameter] = changed_value
    hashes = freeze_inputs["source_hashes"]
    evidence = {row["id"]: row for row in freeze_inputs["evidence_artifacts"]}
    lines = [
        ";==========================================================",
        "; QM5_20009 deterministic Freeze-v2 research set",
        f"; protocol_id: {freeze_inputs['protocol_id']}",
        f"; contract_freeze: {freeze_inputs['contract_freeze']}",
        f"; symbol: {symbol}",
        f"; timeframe: {timeframe}",
        f"; sleeve: {kind}",
        f"; variant: {variant}",
        f"; changed_parameter: {changed_parameter or 'none'}",
        f"; freeze_inputs_sha256: {freeze_inputs_sha256}",
        f"; ea_sha256: {hashes['ea_sha256']}",
        f"; rules_sha256: {hashes['rules_sha256']}",
        f"; contract_sha256: {hashes['contract_sha256']}",
        f"; protocol_sha256: {hashes['protocol_sha256']}",
        f"; generator_sha256: {hashes['generator_sha256']}",
        f"; ex5_sha256: {evidence['ea_binary']['sha256']}",
        ";==========================================================",
    ]
    lines.extend(f"{key}={value}" for key, value in values.items())
    return ("\r\n".join(lines) + "\r\n").encode("ascii")


def expected_files(
    protocol: Mapping[str, Any] | None = None,
    evidence_overrides: Mapping[str, Path] | None = None,
) -> tuple[dict[str, bytes], bytes]:
    protocol = dict(protocol or load_protocol())
    freeze_inputs = build_freeze_inputs(protocol, evidence_overrides)
    freeze_root = sha256_bytes(canonical_json_bytes(freeze_inputs))
    files: dict[str, bytes] = {}
    rows: list[dict[str, object]] = []
    for symbol, timeframe, slot, mode, kind in MARKETS:
        for variant, changed_parameter, changed_value in variants(kind):
            name = filename(symbol, timeframe, kind, variant)
            payload = render_set(
                symbol,
                timeframe,
                slot,
                mode,
                kind,
                variant,
                changed_parameter,
                changed_value,
                freeze_inputs,
                freeze_root,
            )
            files[name] = payload
            rows.append(
                {
                    "file": name,
                    "symbol": symbol,
                    "timeframe": timeframe,
                    "slot": slot,
                    "mode": mode,
                    "sleeve": kind,
                    "variant": variant,
                    "changed_parameter": changed_parameter,
                    "changed_value": changed_value,
                    "set_sha256": sha256_bytes(payload),
                }
            )
    manifest = {
        "schema_version": 2,
        "ea_id": 20009,
        "protocol_id": protocol["protocol_id"],
        "contract_freeze": protocol["contract_freeze"],
        "generation": "deterministic_no_wall_clock_no_git_head",
        "freeze_inputs_sha256": freeze_root,
        "freeze_inputs": freeze_inputs,
        "set_count": len(rows),
        "sets": rows,
    }
    manifest_bytes = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode("utf-8")
    return files, manifest_bytes


def detached_manifest_sha256(manifest: bytes) -> bytes:
    return f"{sha256_bytes(manifest)}  manifest.json\n".encode("ascii")


def check(evidence_overrides: Mapping[str, Path] | None = None) -> list[str]:
    files, manifest = expected_files(evidence_overrides=evidence_overrides)
    detached = detached_manifest_sha256(manifest)
    expected = {**files, "manifest.json": manifest, "manifest.sha256": detached}
    issues: list[str] = []
    actual_names = {path.name for path in SETS_ROOT.iterdir() if path.is_file()} if SETS_ROOT.is_dir() else set()
    for extra in sorted(actual_names - set(expected)):
        issues.append(f"unexpected:{extra}")
    for name, payload in expected.items():
        path = SETS_ROOT / name
        if not path.exists():
            issues.append(f"missing:{name}")
        elif path.read_bytes() != payload:
            issues.append(f"drift:{name}")
    return issues


def write(evidence_overrides: Mapping[str, Path] | None = None) -> None:
    files, manifest = expected_files(evidence_overrides=evidence_overrides)
    expected = {
        **files,
        "manifest.json": manifest,
        "manifest.sha256": detached_manifest_sha256(manifest),
    }
    SETS_ROOT.mkdir(parents=True, exist_ok=True)
    for stale in SETS_ROOT.iterdir():
        if stale.is_file() and stale.name not in expected:
            stale.unlink()
    for name, payload in expected.items():
        (SETS_ROOT / name).write_bytes(payload)


def parse_evidence_overrides(values: Iterable[str]) -> dict[str, Path]:
    overrides: dict[str, Path] = {}
    for value in values:
        artifact_id, separator, raw_path = value.partition("=")
        if not separator or not artifact_id or not raw_path:
            raise FreezeError(f"invalid --evidence override: {value!r}; expected ID=PATH")
        overrides[artifact_id] = Path(raw_path)
    return overrides


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument(
        "--evidence",
        action="append",
        default=[],
        metavar="ID=PATH",
        help="override a declared evidence path; the effective path is frozen in the manifest",
    )
    args = parser.parse_args(argv)
    try:
        overrides = parse_evidence_overrides(args.evidence)
        if args.check:
            issues = check(overrides)
            if issues:
                print("\n".join(issues))
                return 1
            print("PASS: 52 frozen research sets, manifest and detached hash match")
            return 0
        write(overrides)
    except FreezeError as exc:
        print(f"FREEZE_BLOCKED: {exc}")
        return 2
    print("WROTE: 52 frozen research sets, manifest and detached hash")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
