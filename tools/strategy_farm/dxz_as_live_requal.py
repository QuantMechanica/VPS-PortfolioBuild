"""Requalify a Darwinex Zero book with the exact deployed EX5 and live preset.

The runner is deliberately restricted to account-less ``DXZ_Truth_*`` portable
MT5 sandboxes.  ``T1``-``T10`` and ``T_Live`` are never accepted as execution
roots.  T_Live is a read-only source for binaries and presets.

Each run produces a native MT5 report plus a report-derived trade stream.  The
V5 framework also writes its richer Q08 stream to MT5's machine-wide Common
folder.  That file is captured and restored with compare-and-swap semantics so
this audit cannot silently replace the Factory's current stream.
"""

from __future__ import annotations

import argparse
import collections
import concurrent.futures
import contextlib
import dataclasses
import datetime as dt
import getpass
import hashlib
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
import uuid
from decimal import Decimal, InvalidOperation
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
# When this file is executed directly, Python puts ``tools/strategy_farm`` on
# sys.path rather than the repository root.  The report parser lives in the
# top-level ``framework`` package, so make the invocation mode deterministic.
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))
DEFAULT_MANIFEST = Path(
    r"D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json"
)
DEFAULT_LIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
KNOWN_LIVE_COMMON = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)
DEFAULT_COMMON = (
    Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    / "MetaQuotes"
    / "Terminal"
    / "Common"
    / "Files"
)
DEFAULT_OUTPUT = Path(r"D:\QM\reports\portfolio\dxz23_as_live_requal")
DEFAULT_COST_REGISTRY = REPO_ROOT / "framework" / "registry" / "live_commission.json"
SAFE_SANDBOX_RE = re.compile(r"^DXZ_Truth_(?:\d+|[A-Za-z0-9_-]+)$", re.IGNORECASE)
TF_RE = re.compile(r"^(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)$", re.IGNORECASE)
PROMOTION_SYMBOL_RE = re.compile(r"^[A-Z][A-Z0-9]{1,15}\.DWX$")
VARIANT_ID_RE = re.compile(r"^[A-Z][A-Z0-9_]{0,63}$")
SCHEMA_VERSION = 2
AS_LIVE_REQUAL = "AS_LIVE_REQUAL"
TARGET_BINARY_REQUAL = "TARGET_BINARY_REQUAL"
QUALIFICATION_MODES = {
    AS_LIVE_REQUAL,
    TARGET_BINARY_REQUAL,
    "DISCOVERY_RECONCILED",
    "DISCOVERY_COMPLETE_UNREFERENCED",
}
QUALIFYING_MODES = {AS_LIVE_REQUAL, TARGET_BINARY_REQUAL}
DISCOVERY_MODES = QUALIFICATION_MODES - QUALIFYING_MODES
TARGET_ARTIFACT_SOURCE = "SHA_BOUND_TARGET_BINARY_OVERRIDE"
TARGET_ARTIFACT_MANIFEST_TYPE = "DXZ_TARGET_BINARY_REQUAL_ARTIFACT_MANIFEST"
TARGET_SINGLE_RUN_STATUS = "REPRODUCIBILITY_PENDING"
TARGET_SANDBOX_DERIVATION_TYPE = "QM_BASE_DERIVED_SANDBOX"
TARGET_SANDBOX_DERIVATION_MARKER = ".qm_base_derivation.json"
EXECUTION_COST_AXES = (
    "commission",
    "historical_tester_spread",
    "current_broker_spread_parity",
    "current_broker_swap_rate_parity",
    "slippage_stress",
)
EXECUTION_COST_MANIFEST_TYPE = "DXZ_EXECUTION_COST_EVIDENCE_MANIFEST"
EXECUTION_COST_AXIS_ARTIFACT_TYPE = "DXZ_EXECUTION_COST_AXIS_EVIDENCE"
EXECUTION_COST_SCOPES = {"PER_SLEEVE", "GLOBAL"}
EXECUTION_COST_EVIDENCE_TYPES = {
    "commission": {"DXZ_COMMISSION_TRADE_REPLAY_V1"},
    "historical_tester_spread": {"MT5_REAL_TICK_SPREAD_REPLAY_V1"},
    "current_broker_spread_parity": {"DXZ_CURRENT_BROKER_SPREAD_PARITY_V1"},
    "current_broker_swap_rate_parity": {"DXZ_CURRENT_BROKER_SWAP_PARITY_V1"},
    "slippage_stress": {"DXZ_ADVERSE_SLIPPAGE_STRESS_V1"},
}
WINDOW_FIELDS = (
    "requested_from_date",
    "requested_to_date",
    "effective_from_date",
    "effective_to_date",
)


class RequalError(RuntimeError):
    pass


def normalize_variant_id(value: Any, *, label: str) -> str | None:
    """Return one canonical optional variant identifier without coercion."""

    if value is None:
        return None
    if not isinstance(value, str) or not VARIANT_ID_RE.fullmatch(value):
        raise RequalError(f"{label} variant_id must match {VARIANT_ID_RE.pattern}")
    return value


def promotion_identity_key(
    ea_id: int,
    symbol: str,
    timeframe: str,
    variant_id: str | None = None,
) -> str:
    """Build the exact, case-stable promotion identity for a sleeve."""

    normalized_symbol = str(symbol).upper()
    normalized_timeframe = str(timeframe).upper()
    if (
        not isinstance(ea_id, int)
        or isinstance(ea_id, bool)
        or ea_id <= 0
        or not PROMOTION_SYMBOL_RE.fullmatch(normalized_symbol)
    ):
        raise RequalError(
            f"promotion identity invalid: {ea_id}:{normalized_symbol}:{normalized_timeframe}"
        )
    if not TF_RE.fullmatch(normalized_timeframe):
        raise RequalError(f"promotion identity timeframe invalid: {normalized_timeframe}")
    normalized_variant = normalize_variant_id(
        variant_id, label="promotion identity"
    )
    base = f"{ea_id}:{normalized_symbol}:{normalized_timeframe}"
    return f"{base}:{normalized_variant}" if normalized_variant else base


def _path_identity(path: Path) -> str:
    return str(path.resolve()).replace("/", "\\").casefold()


def _parse_date(value: str, *, label: str) -> dt.date:
    text = str(value).strip().replace(".", "-")
    try:
        return dt.date.fromisoformat(text)
    except ValueError as exc:
        raise RequalError(f"invalid {label} date (expected YYYY.MM.DD): {value!r}") from exc


def build_window_contract(
    from_date: str,
    to_date: str,
    *,
    effective_from: str | None = None,
    effective_to: str | None = None,
) -> dict[str, Any]:
    requested_from = _parse_date(from_date, label="from")
    requested_to = _parse_date(to_date, label="to")
    effective_start = _parse_date(effective_from or from_date, label="effective-from")
    effective_end = _parse_date(effective_to or to_date, label="effective-to")
    if requested_from > requested_to:
        raise RequalError("requested from-date is after to-date")
    if effective_start > effective_end:
        raise RequalError("effective-from is after effective-to")
    if effective_start < requested_from or effective_end > requested_to:
        raise RequalError("effective window must be contained in the requested tester window")
    return {
        "requested_from_date": requested_from.isoformat(),
        "requested_to_date": requested_to.isoformat(),
        "effective_from_date": effective_start.isoformat(),
        "effective_to_date": effective_end.isoformat(),
    }


def validate_qualification_contract(
    *,
    qualification_mode: str,
    live_root: Path,
    reference_stream_root: Path | None,
    artifact_override_manifest: Path | None,
) -> None:
    if qualification_mode not in QUALIFICATION_MODES:
        raise RequalError(f"unsupported qualification mode: {qualification_mode}")
    has_reference = reference_stream_root is not None
    if qualification_mode in QUALIFYING_MODES:
        if _path_identity(live_root) != _path_identity(DEFAULT_LIVE_ROOT):
            raise RequalError(
                f"{qualification_mode} pins the canonical read-only T_Live root exactly: "
                f"{DEFAULT_LIVE_ROOT}"
            )
        if not has_reference:
            raise RequalError(f"{qualification_mode} requires a sealed reference snapshot")
        if qualification_mode == AS_LIVE_REQUAL and artifact_override_manifest is not None:
            raise RequalError("AS_LIVE_REQUAL forbids artifact overrides")
        if qualification_mode == TARGET_BINARY_REQUAL and artifact_override_manifest is None:
            raise RequalError(
                "TARGET_BINARY_REQUAL requires --artifact-override-manifest"
            )
        return
    if artifact_override_manifest is None:
        raise RequalError(f"{qualification_mode} requires --artifact-override-manifest")
    if qualification_mode == "DISCOVERY_RECONCILED" and not has_reference:
        raise RequalError("DISCOVERY_RECONCILED requires a sealed reference snapshot")
    if qualification_mode == "DISCOVERY_COMPLETE_UNREFERENCED" and has_reference:
        raise RequalError(
            "unreferenced discovery forbids --reference-stream-root; use "
            "DISCOVERY_RECONCILED when a reference exists"
        )


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_json_sha(payload: Any) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _parse_utc_datetime(value: Any, *, label: str) -> dt.datetime:
    text = str(value or "").strip().replace("Z", "+00:00")
    try:
        parsed = dt.datetime.fromisoformat(text)
    except ValueError as exc:
        raise RequalError(f"invalid {label} UTC timestamp: {value!r}") from exc
    if parsed.tzinfo is None:
        raise RequalError(f"{label} must include a UTC offset")
    return parsed.astimezone(dt.UTC)


def _load_json_object(path: Path, *, label: str) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig", errors="strict"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RequalError(f"invalid {label} JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise RequalError(f"{label} must be a JSON object: {path}")
    return payload


def _tier_path_is_forbidden(path: Path) -> bool:
    return any(
        part.casefold() == "t_live"
        or re.fullmatch(r"t(?:10|[1-9])", part, re.IGNORECASE)
        for part in path.resolve().parts
    )


def _cost_path_is_forbidden(path: Path) -> bool:
    return _tier_path_is_forbidden(path)


def _read_immutable_sidecar(path: Path, *, label: str, file_sha: str) -> dict[str, str]:
    sidecar = path.with_name(path.name + ".sha256")
    if not sidecar.is_file():
        raise RequalError(f"{label} immutable sidecar missing: {sidecar}")
    try:
        tokens = sidecar.read_text(encoding="ascii", errors="strict").split()
    except (OSError, UnicodeError) as exc:
        raise RequalError(f"{label} sidecar invalid: {sidecar}") from exc
    if not tokens or tokens[0].lower() != file_sha:
        raise RequalError(f"{label} sidecar hash mismatch: {sidecar}")
    return {
        "sidecar_path": str(sidecar.resolve()),
        "sidecar_sha256": sha256_file(sidecar),
    }


def snapshot_live_source_artifacts(live_root: Path) -> dict[str, Any]:
    """Hash the deployed EX5/set source surfaces without touching T_Live.

    Logs and terminal state are intentionally excluded because a running live
    terminal may update them independently.  These are the only T_Live trees
    from which this runner is permitted to source qualification artifacts.
    """

    resolved = live_root.resolve()
    if not resolved.is_dir():
        raise RequalError(f"canonical T_Live root missing: {resolved}")
    roots = (
        resolved / "MQL5" / "Experts" / "Live EAs",
        resolved / "MQL5" / "Presets",
    )
    rows: list[dict[str, Any]] = []
    for root in roots:
        if not root.is_dir():
            raise RequalError(f"canonical T_Live artifact tree missing: {root}")
        for artifact in sorted(
            (item for item in root.rglob("*") if item.is_file()),
            key=lambda item: str(item).casefold(),
        ):
            stat = artifact.stat()
            rows.append(
                {
                    "relative_path": artifact.relative_to(resolved).as_posix(),
                    "bytes": stat.st_size,
                    "sha256": sha256_file(artifact),
                }
            )
    return {
        "root": str(resolved),
        "trees": [str(root.relative_to(resolved).as_posix()) for root in roots],
        "file_count": len(rows),
        "aggregate_sha256": canonical_json_sha(rows),
        "files": rows,
    }


def load_target_sandbox_derivation(sandbox: Path) -> dict[str, Any]:
    """Verify immutable proof that a target-mode sandbox was cloned from Base."""

    resolved = sandbox.resolve()
    marker = resolved / TARGET_SANDBOX_DERIVATION_MARKER
    if not marker.is_file():
        raise RequalError(f"target sandbox Base-derivation marker missing: {marker}")
    marker_sha = sha256_file(marker)
    sidecar = _read_immutable_sidecar(
        marker, label="target sandbox Base-derivation marker", file_sha=marker_sha
    )
    payload = _load_json_object(marker, label="target sandbox Base-derivation marker")
    if payload.get("schema_version") != 1:
        raise RequalError("target sandbox derivation schema_version must be 1")
    if payload.get("artifact_type") != TARGET_SANDBOX_DERIVATION_TYPE:
        raise RequalError("target sandbox derivation artifact_type invalid")
    declared_payload_sha = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    if (
        not re.fullmatch(r"[0-9a-f]{64}", declared_payload_sha)
        or canonical_json_sha(unsigned) != declared_payload_sha
    ):
        raise RequalError("target sandbox derivation canonical payload SHA-256 invalid")
    source_text = payload.get("source_base_root")
    if not isinstance(source_text, str) or not source_text.strip():
        raise RequalError("target sandbox derivation source_base_root missing")
    source_base = Path(source_text).resolve()
    if _tier_path_is_forbidden(source_base):
        raise RequalError("target sandbox Base source must be outside T_Live/T1-T10")
    if source_base.name.casefold() not in {"base", "mt5_base"}:
        raise RequalError("target sandbox derivation source must name a Base root")
    source_terminal = source_base / "terminal64.exe"
    sandbox_terminal = resolved / "terminal64.exe"
    if not source_terminal.is_file():
        raise RequalError(f"target sandbox source Base terminal missing: {source_terminal}")
    source_sha = sha256_file(source_terminal)
    sandbox_sha = sha256_file(sandbox_terminal)
    declared_source_sha = str(payload.get("source_terminal_sha256") or "").lower()
    declared_sandbox_sha = str(payload.get("sandbox_terminal_sha256") or "").lower()
    if source_sha != declared_source_sha:
        raise RequalError("target sandbox source Base terminal hash mismatch")
    if sandbox_sha != declared_sandbox_sha or sandbox_sha != source_sha:
        raise RequalError("target sandbox terminal is not byte-identical to declared Base")
    declared_sandbox_root = payload.get("sandbox_root")
    if (
        not isinstance(declared_sandbox_root, str)
        or _path_identity(Path(declared_sandbox_root)) != _path_identity(resolved)
    ):
        raise RequalError("target sandbox derivation sandbox_root mismatch")
    return {
        "sandbox_root": str(resolved),
        "marker_path": str(marker),
        "marker_sha256": marker_sha,
        **sidecar,
        "artifact_payload_sha256": declared_payload_sha,
        "artifact_type": TARGET_SANDBOX_DERIVATION_TYPE,
        "source_base_root": str(source_base),
        "source_terminal_path": str(source_terminal),
        "source_terminal_sha256": source_sha,
        "sandbox_terminal_path": str(sandbox_terminal),
        "sandbox_terminal_sha256": sandbox_sha,
    }


def verify_target_sandbox_derivations_unchanged(
    bindings: Iterable[Mapping[str, Any]],
) -> tuple[list[dict[str, Any]], list[str]]:
    end: list[dict[str, Any]] = []
    errors: list[str] = []
    for binding in bindings:
        sandbox = Path(str(binding.get("sandbox_root") or ""))
        try:
            current = load_target_sandbox_derivation(sandbox)
        except (RequalError, OSError, ValueError) as exc:
            errors.append(f"TARGET_SANDBOX_DERIVATION_CHANGED:{sandbox}:{exc}")
            continue
        end.append(current)
        if current != dict(binding):
            errors.append(f"TARGET_SANDBOX_DERIVATION_CHANGED:{sandbox}")
    return end, sorted(set(errors))


def _normalize_cost_sleeves(raw: Any, *, label: str) -> list[dict[str, Any]]:
    if not isinstance(raw, list) or not raw:
        raise RequalError(f"{label} covered_sleeves must be a non-empty array")
    normalized: list[dict[str, Any]] = []
    identities: set[tuple[int, str, str, str | None]] = set()
    variant_presence: set[bool] = set()
    for item in raw:
        if not isinstance(item, dict):
            raise RequalError(f"{label} covered sleeve must be an object")
        try:
            ea_id = int(item.get("ea_id"))
        except (TypeError, ValueError) as exc:
            raise RequalError(f"{label} covered sleeve ea_id invalid") from exc
        symbol = str(item.get("symbol") or "").upper()
        timeframe = str(item.get("timeframe") or "").upper()
        has_variant = "variant_id" in item
        variant_presence.add(has_variant)
        if has_variant and item.get("variant_id") is None:
            raise RequalError(f"{label} covered sleeve variant_id cannot be null")
        variant_id = normalize_variant_id(
            item.get("variant_id"), label=f"{label} covered sleeve"
        )
        if ea_id <= 0 or not symbol.endswith(".DWX") or not TF_RE.fullmatch(timeframe):
            raise RequalError(
                f"{label} covered sleeve identity invalid: {ea_id}:{symbol}:{timeframe}"
            )
        identity = (ea_id, symbol, timeframe, variant_id)
        if identity in identities:
            raise RequalError(f"{label} covered_sleeves contains duplicates")
        identities.add(identity)
        normalized_row: dict[str, Any] = {
            "ea_id": ea_id,
            "symbol": symbol,
            "timeframe": timeframe,
        }
        if has_variant:
            normalized_row["variant_id"] = variant_id
        normalized.append(normalized_row)
    if len(variant_presence) > 1:
        raise RequalError(
            f"{label} covered_sleeves cannot mix legacy and four-part identities"
        )
    return sorted(
        normalized,
        key=lambda item: (
            item["ea_id"],
            item["symbol"],
            item["timeframe"],
            str(item.get("variant_id") or ""),
        ),
    )


def _cost_sleeve_key(item: Mapping[str, Any]) -> str:
    if "variant_id" in item:
        return promotion_identity_key(
            int(item["ea_id"]),
            str(item["symbol"]).upper(),
            str(item["timeframe"]).upper(),
            normalize_variant_id(
                item.get("variant_id"), label="execution-cost sleeve"
            ),
        )
    return f"{int(item['ea_id'])}:{str(item['symbol']).upper()}"


def _validate_evaluation_window(raw: Any, *, label: str) -> dict[str, str]:
    if not isinstance(raw, dict) or set(raw) != set(WINDOW_FIELDS):
        raise RequalError(f"{label} evaluation_window must contain exactly {list(WINDOW_FIELDS)}")
    result = {field: str(raw.get(field) or "") for field in WINDOW_FIELDS}
    requested_from = _parse_date(result["requested_from_date"], label=f"{label} requested-from")
    requested_to = _parse_date(result["requested_to_date"], label=f"{label} requested-to")
    effective_from = _parse_date(result["effective_from_date"], label=f"{label} effective-from")
    effective_to = _parse_date(result["effective_to_date"], label=f"{label} effective-to")
    if not requested_from <= effective_from <= effective_to <= requested_to:
        raise RequalError(f"{label} evaluation_window bounds invalid")
    return {
        "requested_from_date": requested_from.isoformat(),
        "requested_to_date": requested_to.isoformat(),
        "effective_from_date": effective_from.isoformat(),
        "effective_to_date": effective_to.isoformat(),
    }


def _finite_number(value: Any, *, label: str, minimum: float | None = None) -> float:
    if isinstance(value, bool):
        raise RequalError(f"{label} must be numeric")
    try:
        result = float(value)
    except (TypeError, ValueError) as exc:
        raise RequalError(f"{label} must be numeric") from exc
    if not (-float("inf") < result < float("inf")):
        raise RequalError(f"{label} must be finite")
    if minimum is not None and result < minimum:
        raise RequalError(f"{label} must be >= {minimum}")
    return result


def _positive_int(value: Any, *, label: str, minimum: int = 1) -> int:
    if isinstance(value, bool):
        raise RequalError(f"{label} must be an integer")
    try:
        result = int(value)
    except (TypeError, ValueError) as exc:
        raise RequalError(f"{label} must be an integer") from exc
    if result < minimum or result != value:
        raise RequalError(f"{label} must be an integer >= {minimum}")
    return result


def _scenario_rows(raw: Any, *, axis: str) -> list[dict[str, Any]]:
    if not isinstance(raw, list) or not raw or any(not isinstance(row, dict) for row in raw):
        raise RequalError(f"execution-cost artifact {axis} scenarios must be non-empty objects")
    rows = [dict(row) for row in raw]
    if any(row.get("status") != "PASS" for row in rows):
        raise RequalError(f"execution-cost artifact {axis} scenario status must be PASS")
    return rows


def _validate_axis_semantics(
    axis: str,
    *,
    parameters: Any,
    scenarios: Any,
    results: Any,
    covered_sleeves: list[dict[str, Any]],
) -> tuple[dict[str, Any], list[dict[str, Any]], dict[str, Any]]:
    if not isinstance(parameters, dict) or not isinstance(results, dict):
        raise RequalError(f"execution-cost artifact {axis} parameters/results invalid")
    params = dict(parameters)
    rows = _scenario_rows(scenarios, axis=axis)
    outcome = dict(results)
    covered_symbols = {str(item["symbol"]).upper() for item in covered_sleeves}
    covered_keys = {_cost_sleeve_key(item) for item in covered_sleeves}

    def scenario_key(row: Mapping[str, Any]) -> str:
        key = str(row.get("covered_key") or "").upper()
        if key not in covered_keys:
            raise RequalError(f"execution-cost artifact {axis} scenario covered_key invalid")
        expected_symbol = next(
            item["symbol"] for item in covered_sleeves if _cost_sleeve_key(item) == key
        )
        declared_symbol = str(row.get("symbol") or expected_symbol).upper()
        if declared_symbol != expected_symbol:
            raise RequalError(f"execution-cost artifact {axis} scenario symbol/key mismatch")
        return key

    if axis == "commission":
        if params.get("conservative") is not True:
            raise RequalError("commission evidence must set conservative=true")
        if params.get("charge_basis") not in {
            "ROUND_TRIP_NOTIONAL_BPS",
            "ROUND_TRIP_PER_LOT",
            "DEAL_LEVEL_ACTUAL",
        }:
            raise RequalError("commission charge_basis is not an approved conservative basis")
        base_rate = _finite_number(params.get("rate"), label="commission rate", minimum=0.0)
        if base_rate <= 0.0 or not re.fullmatch(r"[A-Z]{3}", str(params.get("currency") or "")):
            raise RequalError("commission rate/currency invalid")
        scenario_keys: set[str] = set()
        for row in rows:
            scenario_keys.add(scenario_key(row))
            if not str(row.get("name") or "").strip():
                raise RequalError("commission scenario name missing")
            applied = _finite_number(
                row.get("applied_rate"), label="commission applied_rate", minimum=0.0
            )
            if applied < base_rate:
                raise RequalError("commission scenario is less conservative than the bound rate")
        if scenario_keys != covered_keys:
            raise RequalError("commission scenarios do not cover every bound sleeve")
        if (
            outcome.get("all_trades_costed") is not True
            or outcome.get("unknown_symbols") != []
            or outcome.get("degraded_symbols") != []
        ):
            raise RequalError("commission evidence has uncosted/degraded trades")

    elif axis == "historical_tester_spread":
        if (
            params.get("conservative") is not True
            or params.get("tester_model") != "EVERY_TICK_BASED_ON_REAL_TICKS"
            or " ".join(str(params.get("history_quality") or "").split()).casefold()
            != "100% real ticks"
            or params.get("spread_embedded") is not True
        ):
            raise RequalError("historical tester spread parameters are not real-tick conservative")
        scenario_keys = set()
        for row in rows:
            scenario_keys.add(scenario_key(row))
            spread_multiplier = _finite_number(
                row.get("spread_multiplier"),
                label="historical spread_multiplier",
                minimum=1.0,
            )
            observed = _finite_number(
                row.get("observed_spread_points"),
                label="historical observed spread",
                minimum=0.0,
            )
            applied = _finite_number(
                row.get("applied_spread_points"),
                label="historical applied spread",
                minimum=0.0,
            )
            if observed <= 0.0 or applied <= 0.0:
                raise RequalError("historical spread measurements must be strictly positive")
            if applied + 1e-12 < observed * spread_multiplier:
                raise RequalError("historical spread scenario understates observed spread")
        if scenario_keys != covered_keys:
            raise RequalError("historical spread scenarios do not cover every bound sleeve")
        if outcome.get("all_reports_bound") is not True or outcome.get("missing_reports") != []:
            raise RequalError("historical tester spread evidence has unbound reports")

    elif axis == "current_broker_spread_parity":
        minimum_samples = _positive_int(
            params.get("minimum_samples_per_symbol"),
            label="spread minimum_samples_per_symbol",
            minimum=100,
        )
        quantile = _finite_number(params.get("quantile"), label="spread quantile", minimum=0.95)
        multiplier = _finite_number(
            params.get("minimum_applied_to_observed_multiplier"),
            label="spread conservative multiplier",
            minimum=1.0,
        )
        if quantile > 1.0:
            raise RequalError("spread quantile must be <= 1")
        scenario_keys = set()
        for row in rows:
            key = scenario_key(row)
            symbol = str(row.get("symbol") or "").upper()
            samples = _positive_int(row.get("samples"), label="spread samples")
            observed = _finite_number(
                row.get("observed_quantile_points"), label="observed spread", minimum=0.0
            )
            applied = _finite_number(
                row.get("applied_spread_points"), label="applied spread", minimum=0.0
            )
            if symbol not in covered_symbols or samples < minimum_samples or observed <= 0.0:
                raise RequalError("spread parity scenario coverage/sample invalid")
            if applied + 1e-12 < observed * multiplier:
                raise RequalError("spread parity applied scenario understates observed spread")
            scenario_keys.add(key)
        if scenario_keys != covered_keys or outcome.get("all_symbols_pass") is not True:
            raise RequalError("spread parity does not cover every bound sleeve")

    elif axis == "current_broker_swap_rate_parity":
        minimum_days = _positive_int(
            params.get("minimum_observation_days"),
            label="swap minimum_observation_days",
            minimum=5,
        )
        max_age = _positive_int(
            params.get("maximum_rate_age_days"),
            label="swap maximum_rate_age_days",
        )
        multiplier = _finite_number(
            params.get("minimum_adverse_multiplier"),
            label="swap conservative multiplier",
            minimum=1.0,
        )
        if (
            max_age > 7
            or params.get("include_long_and_short") is not True
            or params.get("include_triple_swap") is not True
        ):
            raise RequalError("swap evidence omits a required conservative dimension")
        observed_sides: dict[str, set[str]] = {key: set() for key in covered_keys}
        triple_keys: set[str] = set()
        for row in rows:
            key = scenario_key(row)
            symbol = str(row.get("symbol") or "").upper()
            side = str(row.get("side") or "").upper()
            days = _positive_int(row.get("observation_days"), label="swap observation_days")
            rollover = _finite_number(
                row.get("rollover_multiplier"), label="swap rollover_multiplier", minimum=1.0
            )
            observed = _finite_number(
                row.get("observed_cost_account_ccy"), label="observed swap cost", minimum=0.0
            )
            applied = _finite_number(
                row.get("applied_cost_account_ccy"), label="applied swap cost", minimum=0.0
            )
            if symbol not in covered_symbols or side not in {"LONG", "SHORT"} or days < minimum_days:
                raise RequalError("swap scenario coverage/side/sample invalid")
            if observed <= 0.0 or applied <= 0.0:
                raise RequalError("swap measurements must be strictly positive adverse costs")
            if applied + 1e-12 < observed * multiplier:
                raise RequalError("swap applied scenario understates observed adverse cost")
            observed_sides[key].add(side)
            if rollover >= 3.0:
                triple_keys.add(key)
        if (
            any(sides != {"LONG", "SHORT"} for sides in observed_sides.values())
            or triple_keys != covered_keys
            or outcome.get("all_symbols_sides_pass") is not True
        ):
            raise RequalError("swap evidence does not cover both sides and triple rollover")

    elif axis == "slippage_stress":
        minimum_samples = _positive_int(
            params.get("minimum_samples_per_symbol"),
            label="slippage minimum_samples_per_symbol",
            minimum=30,
        )
        quantile = _finite_number(params.get("quantile"), label="slippage quantile", minimum=0.95)
        multiplier = _finite_number(
            params.get("minimum_adverse_multiplier"),
            label="slippage conservative multiplier",
            minimum=1.0,
        )
        if quantile > 1.0 or params.get("include_gap_stress") is not True:
            raise RequalError("slippage evidence omits conservative quantile/gap stress")
        modes: dict[str, set[str]] = {key: set() for key in covered_keys}
        for row in rows:
            key = scenario_key(row)
            symbol = str(row.get("symbol") or "").upper()
            scenario = str(row.get("scenario") or "").upper()
            samples = _positive_int(row.get("samples"), label="slippage samples")
            observed = _finite_number(
                row.get("observed_adverse_points"), label="observed slippage", minimum=0.0
            )
            applied = _finite_number(
                row.get("applied_adverse_points"), label="applied slippage", minimum=0.0
            )
            if (
                symbol not in covered_symbols
                or scenario not in {"ADVERSE_QUANTILE", "GAP_STRESS"}
                or samples < minimum_samples
            ):
                raise RequalError("slippage scenario coverage/sample invalid")
            if observed <= 0.0 or applied <= 0.0:
                raise RequalError("slippage measurements must be strictly positive")
            if applied + 1e-12 < observed * multiplier:
                raise RequalError("slippage stress understates observed adverse slippage")
            modes[key].add(scenario)
        if (
            any(value != {"ADVERSE_QUANTILE", "GAP_STRESS"} for value in modes.values())
            or outcome.get("all_symbols_scenarios_pass") is not True
        ):
            raise RequalError("slippage evidence does not cover quantile and gap scenarios")
    else:  # pragma: no cover - guarded by EXECUTION_COST_AXES
        raise RequalError(f"unsupported execution-cost axis: {axis}")
    return params, rows, outcome


def _resolve_evidence_artifact(
    binding: Any,
    *,
    manifest_dir: Path,
    axis: str,
    source_manifest_sha256: str,
    as_of_utc: dt.datetime,
    covered_sleeves: list[dict[str, Any]],
    evaluation_window: Mapping[str, str],
) -> dict[str, Any]:
    if not isinstance(binding, dict):
        raise RequalError(f"execution-cost axis {axis} evidence binding missing")
    path_text = binding.get("path")
    expected_sha = str(binding.get("sha256") or "").lower()
    expected_type = str(binding.get("evidence_type") or "")
    if not isinstance(path_text, str) or not path_text.strip():
        raise RequalError(f"execution-cost axis {axis} evidence path missing")
    if expected_type not in EXECUTION_COST_EVIDENCE_TYPES[axis]:
        raise RequalError(f"execution-cost axis {axis} evidence_type is not allowed")
    if not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        raise RequalError(f"execution-cost axis {axis} evidence SHA-256 invalid")
    path = Path(path_text)
    if not path.is_absolute():
        path = manifest_dir / path
    path = path.resolve()
    if _cost_path_is_forbidden(path):
        raise RequalError(f"execution-cost axis {axis} evidence must be outside T_Live/T1-T10")
    if not path.is_file():
        raise RequalError(f"execution-cost axis {axis} evidence missing: {path}")
    actual_sha = sha256_file(path)
    if actual_sha != expected_sha:
        raise RequalError(
            f"execution-cost axis {axis} evidence hash mismatch: "
            f"expected={expected_sha} actual={actual_sha}"
        )
    sidecar_binding = _read_immutable_sidecar(
        path, label=f"execution-cost axis {axis} evidence", file_sha=actual_sha
    )
    payload = _load_json_object(path, label=f"execution-cost axis {axis} evidence")
    if payload.get("schema_version") != 1:
        raise RequalError(f"execution-cost axis {axis} evidence schema_version must be 1")
    if payload.get("artifact_type") != EXECUTION_COST_AXIS_ARTIFACT_TYPE:
        raise RequalError(f"execution-cost axis {axis} evidence artifact_type invalid")
    if payload.get("axis") != axis or payload.get("evidence_type") != expected_type:
        raise RequalError(f"execution-cost axis {axis} evidence axis/type mismatch")
    if payload.get("status") != "PASS":
        raise RequalError(f"execution-cost axis {axis} evidence status must be PASS")
    declared_payload_sha = str(payload.get("artifact_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("artifact_payload_sha256", None)
    if (
        not re.fullmatch(r"[0-9a-f]{64}", declared_payload_sha)
        or canonical_json_sha(unsigned) != declared_payload_sha
    ):
        raise RequalError(f"execution-cost axis {axis} canonical payload SHA-256 invalid")
    if payload.get("source_manifest_sha256") != source_manifest_sha256:
        raise RequalError(f"execution-cost axis {axis} source manifest mismatch")
    artifact_sleeves = _normalize_cost_sleeves(
        payload.get("covered_sleeves"), label=f"execution-cost axis {axis}"
    )
    if artifact_sleeves != covered_sleeves:
        raise RequalError(f"execution-cost axis {axis} sleeve/symbol/timeframe coverage mismatch")
    artifact_window = _validate_evaluation_window(
        payload.get("evaluation_window"), label=f"execution-cost axis {axis}"
    )
    if artifact_window != dict(evaluation_window):
        raise RequalError(f"execution-cost axis {axis} evaluation window mismatch")
    valid_from = _parse_utc_datetime(
        payload.get("valid_from_utc"), label=f"execution-cost axis {axis} valid_from_utc"
    )
    valid_until = _parse_utc_datetime(
        payload.get("valid_until_utc"), label=f"execution-cost axis {axis} valid_until_utc"
    )
    if valid_from > valid_until or not valid_from <= as_of_utc <= valid_until:
        raise RequalError(f"execution-cost axis {axis} evidence expired/not-yet-valid")
    if axis in {
        "current_broker_spread_parity",
        "current_broker_swap_rate_parity",
    } and valid_until - valid_from > dt.timedelta(days=7):
        raise RequalError(
            f"execution-cost axis {axis} validity exceeds the fixed seven-day freshness limit"
        )
    assertion = str(payload.get("assertion") or "").strip()
    methodology = str(payload.get("methodology") or "").strip()
    if not assertion or not methodology:
        raise RequalError(f"execution-cost axis {axis} evidence assertion/methodology missing")
    parameters, scenarios, results = _validate_axis_semantics(
        axis,
        parameters=payload.get("parameters"),
        scenarios=payload.get("scenarios"),
        results=payload.get("results"),
        covered_sleeves=artifact_sleeves,
    )
    declared_binding_payload_sha = binding.get("artifact_payload_sha256")
    if declared_binding_payload_sha not in (None, declared_payload_sha):
        raise RequalError(f"execution-cost axis {axis} binding payload SHA-256 mismatch")
    return {
        "path": str(path),
        "sha256": actual_sha,
        **sidecar_binding,
        "schema_version": 1,
        "artifact_type": EXECUTION_COST_AXIS_ARTIFACT_TYPE,
        "axis": axis,
        "evidence_type": expected_type,
        "status": "PASS",
        "artifact_payload_sha256": declared_payload_sha,
        "source_manifest_sha256": source_manifest_sha256,
        "covered_sleeves": artifact_sleeves,
        "evaluation_window": artifact_window,
        "valid_from_utc": valid_from.isoformat(),
        "valid_until_utc": valid_until.isoformat(),
        "assertion": assertion,
        "methodology": methodology,
        "parameters": parameters,
        "scenarios": scenarios,
        "results": results,
    }


def _validate_execution_cost_axes(
    raw_axes: Any,
    *,
    manifest_dir: Path,
    context: str,
    source_manifest_sha256: str,
    as_of_utc: dt.datetime,
    covered_sleeves: list[dict[str, Any]],
    evaluation_window: Mapping[str, str],
) -> dict[str, dict[str, Any]]:
    if not isinstance(raw_axes, dict) or set(raw_axes) != set(EXECUTION_COST_AXES):
        raise RequalError(
            f"{context} must declare exactly these execution-cost axes: "
            f"{list(EXECUTION_COST_AXES)}"
        )
    axes: dict[str, dict[str, Any]] = {}
    for axis in EXECUTION_COST_AXES:
        raw = raw_axes.get(axis)
        if not isinstance(raw, dict):
            raise RequalError(f"{context} axis {axis} must be an object")
        if set(raw) - {"status", "evidence"}:
            raise RequalError(
                f"{context} axis {axis} may only bind status and structured evidence"
            )
        if raw.get("status") != "PASS":
            raise RequalError(f"{context} axis {axis} status must be PASS")
        evidence = _resolve_evidence_artifact(
            raw.get("evidence"),
            manifest_dir=manifest_dir,
            axis=axis,
            source_manifest_sha256=source_manifest_sha256,
            as_of_utc=as_of_utc,
            covered_sleeves=covered_sleeves,
            evaluation_window=evaluation_window,
        )
        axes[axis] = {
            "status": "PASS",
            "assertion": evidence["assertion"],
            "methodology": evidence["methodology"],
            "parameters": dict(evidence["parameters"]),
            "scenarios": list(evidence["scenarios"]),
            "results": dict(evidence["results"]),
            "evidence": {
                key: value
                for key, value in evidence.items()
                if key not in {"assertion", "methodology", "parameters", "scenarios", "results"}
            },
        }
    return axes


def load_execution_cost_evidence_manifest(
    path: Path,
    *,
    source_manifest_sha256: str,
    as_of_utc: dt.datetime,
    required_sleeves: Iterable[Mapping[str, Any]] | None = None,
    window_contract: Mapping[str, Any] | None = None,
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    """Load an immutable five-axis execution-cost qualification contract."""

    if as_of_utc.tzinfo is None:
        raise RequalError("execution-cost as_of_utc must include a UTC offset")
    as_of_utc = as_of_utc.astimezone(dt.UTC)
    resolved = path.resolve()
    lowered_parts = {part.casefold() for part in resolved.parts}
    if "t_live" in lowered_parts or any(
        re.fullmatch(r"t(?:10|[1-9])", part) for part in lowered_parts
    ):
        raise RequalError("execution-cost evidence manifest must be outside T_Live/T1-T10")
    payload = _load_json_object(resolved, label="execution-cost evidence manifest")
    if payload.get("schema_version") != 1:
        raise RequalError("execution-cost evidence manifest schema_version must be 1")
    if payload.get("artifact_type") != EXECUTION_COST_MANIFEST_TYPE:
        raise RequalError(
            f"execution-cost artifact_type must be {EXECUTION_COST_MANIFEST_TYPE}"
        )
    if payload.get("status") != "PASS":
        raise RequalError("execution-cost evidence manifest status must be PASS")
    declared_payload_sha = str(payload.get("manifest_payload_sha256") or "").lower()
    unsigned = dict(payload)
    unsigned.pop("manifest_payload_sha256", None)
    if not re.fullmatch(r"[0-9a-f]{64}", declared_payload_sha) or canonical_json_sha(
        unsigned
    ) != declared_payload_sha:
        raise RequalError("execution-cost manifest embedded payload SHA-256 invalid")
    file_sha = sha256_file(resolved)
    sidecar = resolved.with_name(resolved.name + ".sha256")
    if not sidecar.is_file():
        raise RequalError(f"execution-cost manifest immutable sidecar missing: {sidecar}")
    try:
        sidecar_token = sidecar.read_text(encoding="ascii", errors="strict").split()[0].lower()
    except (OSError, UnicodeError, IndexError) as exc:
        raise RequalError(f"execution-cost manifest sidecar invalid: {sidecar}") from exc
    if sidecar_token != file_sha:
        raise RequalError("execution-cost manifest sidecar hash mismatch")
    if payload.get("source_manifest_sha256") != source_manifest_sha256:
        raise RequalError("execution-cost manifest source manifest SHA-256 mismatch")
    valid_from = _parse_utc_datetime(payload.get("valid_from_utc"), label="valid_from_utc")
    valid_until = _parse_utc_datetime(payload.get("valid_until_utc"), label="valid_until_utc")
    if valid_from > valid_until or not valid_from <= as_of_utc <= valid_until:
        raise RequalError("execution-cost evidence manifest is outside its validity window")
    scope = str(payload.get("scope") or "").upper()
    if scope not in EXECUTION_COST_SCOPES:
        raise RequalError(f"execution-cost manifest scope invalid: {scope}")
    covered_keys_raw = payload.get("covered_keys")
    if not isinstance(covered_keys_raw, list) or not covered_keys_raw:
        raise RequalError("execution-cost manifest covered_keys must be non-empty")
    covered_keys = [str(item).upper() for item in covered_keys_raw]
    if len(covered_keys) != len(set(covered_keys)):
        raise RequalError("execution-cost manifest covered_keys contains duplicates")
    covered_sleeves = _normalize_cost_sleeves(
        payload.get("covered_sleeves"), label="execution-cost manifest"
    )
    sleeve_keys = [_cost_sleeve_key(item) for item in covered_sleeves]
    if len(sleeve_keys) != len(set(sleeve_keys)) or set(sleeve_keys) != set(covered_keys):
        raise RequalError(
            "execution-cost manifest covered_keys must exactly match unique covered_sleeves"
        )
    evaluation_window = _validate_evaluation_window(
        payload.get("evaluation_window"), label="execution-cost manifest"
    )
    if required_sleeves is not None:
        normalized_required = _normalize_cost_sleeves(
            [dict(item) for item in required_sleeves], label="required execution-cost"
        )
        required_identities = {
            (
                item["ea_id"],
                item["symbol"],
                item["timeframe"],
                item.get("variant_id") if "variant_id" in item else None,
                "variant_id" in item,
            )
            for item in normalized_required
        }
        covered_identities = {
            (
                item["ea_id"],
                item["symbol"],
                item["timeframe"],
                item.get("variant_id") if "variant_id" in item else None,
                "variant_id" in item,
            )
            for item in covered_sleeves
        }
        if not required_identities.issubset(covered_identities):
            raise RequalError(
                "execution-cost manifest four-part sleeve coverage does not cover "
                "the selected book"
            )
    if window_contract is not None:
        required_window = _validate_evaluation_window(
            dict(window_contract), label="required execution-cost"
        )
        if evaluation_window != required_window:
            raise RequalError("execution-cost manifest evaluation window mismatch")

    contracts: dict[str, dict[str, Any]] = {}
    if scope == "GLOBAL":
        axes = _validate_execution_cost_axes(
            payload.get("axes"),
            manifest_dir=resolved.parent,
            context="global",
            source_manifest_sha256=source_manifest_sha256,
            as_of_utc=as_of_utc,
            covered_sleeves=covered_sleeves,
            evaluation_window=evaluation_window,
        )
        by_key = {_cost_sleeve_key(item): item for item in covered_sleeves}
        for key in covered_keys:
            contracts[key] = {
                "scope": scope,
                "timeframe": by_key[key]["timeframe"],
                "variant_id": by_key[key].get("variant_id"),
                "axes": axes,
            }
        if payload.get("sleeves") not in (None, []):
            raise RequalError("GLOBAL execution-cost manifest must not declare sleeves")
    else:
        rows = payload.get("sleeves")
        if not isinstance(rows, list) or not rows:
            raise RequalError("PER_SLEEVE execution-cost manifest requires sleeves")
        for row in rows:
            if not isinstance(row, dict):
                raise RequalError("execution-cost sleeve record must be an object")
            [identity] = _normalize_cost_sleeves(
                [row], label="execution-cost sleeve record"
            )
            ea_id = int(identity["ea_id"])
            symbol = str(identity["symbol"])
            timeframe = str(identity["timeframe"])
            key = _cost_sleeve_key(identity)
            if key in contracts:
                raise RequalError(f"duplicate execution-cost sleeve: {key}")
            if identity not in covered_sleeves:
                raise RequalError(f"execution-cost sleeve is outside covered_sleeves: {key}")
            contracts[key] = {
                "scope": scope,
                "timeframe": timeframe,
                "variant_id": identity.get("variant_id"),
                "axes": _validate_execution_cost_axes(
                    row.get("axes"),
                    manifest_dir=resolved.parent,
                    context=key,
                    source_manifest_sha256=source_manifest_sha256,
                    as_of_utc=as_of_utc,
                    covered_sleeves=[identity],
                    evaluation_window=evaluation_window,
                ),
            }
        if set(contracts) != set(covered_keys):
            raise RequalError(
                "PER_SLEEVE covered_keys must exactly match sleeve identities"
            )
        if payload.get("axes") not in (None, {}):
            raise RequalError("PER_SLEEVE execution-cost manifest must not declare global axes")

    artifact_bindings = sorted(
        {
            (
                axis_name,
                axis["evidence"]["path"],
                axis["evidence"]["sha256"],
                axis["evidence"]["sidecar_path"],
                axis["evidence"]["sidecar_sha256"],
            )
            for contract in contracts.values()
            for axis_name, axis in contract["axes"].items()
        }
    )
    axes_metadata = {
        axis_name: sorted(
            [
                {
                    **axis["evidence"],
                    "parameters_sha256": canonical_json_sha(axis["parameters"]),
                    "scenarios_sha256": canonical_json_sha(axis["scenarios"]),
                    "results_sha256": canonical_json_sha(axis["results"]),
                }
                for contract in contracts.values()
                for name, axis in contract["axes"].items()
                if name == axis_name
            ],
            key=lambda item: (item["path"], item["artifact_payload_sha256"]),
        )
        for axis_name in EXECUTION_COST_AXES
    }
    # GLOBAL contracts point to the same axis object for every sleeve.  Keep one
    # semantic binding per distinct artifact rather than duplicating it N times.
    for axis_name, rows in axes_metadata.items():
        unique = {
            (row["path"], row["artifact_payload_sha256"]): row for row in rows
        }
        axes_metadata[axis_name] = [unique[key] for key in sorted(unique)]
    metadata = {
        "path": str(resolved),
        "sha256": file_sha,
        "sidecar_path": str(sidecar.resolve()),
        "sidecar_sha256": sha256_file(sidecar),
        "manifest_payload_sha256": declared_payload_sha,
        "artifact_type": EXECUTION_COST_MANIFEST_TYPE,
        "scope": scope,
        "source_manifest_sha256": source_manifest_sha256,
        "valid_from_utc": valid_from.isoformat(),
        "valid_until_utc": valid_until.isoformat(),
        "covered_keys": sorted(covered_keys),
        "covered_sleeves": covered_sleeves,
        "evaluation_window": evaluation_window,
        "axes": axes_metadata,
        "bound_artifacts": [
            {
                "axis": axis_name,
                "path": artifact_path,
                "sha256": artifact_sha,
                "sidecar_path": artifact_sidecar_path,
                "sidecar_sha256": artifact_sidecar_sha,
            }
            for (
                axis_name,
                artifact_path,
                artifact_sha,
                artifact_sidecar_path,
                artifact_sidecar_sha,
            ) in artifact_bindings
        ],
    }
    metadata["semantic_contract_sha256"] = canonical_json_sha(
        {
            "source_manifest_sha256": source_manifest_sha256,
            "scope": scope,
            "covered_sleeves": covered_sleeves,
            "evaluation_window": evaluation_window,
            "contracts": contracts,
        }
    )
    return metadata, contracts


def verify_execution_cost_evidence_unchanged(
    metadata: Mapping[str, Any] | None,
) -> tuple[bool, list[str]]:
    if metadata is None:
        return True, []
    errors: list[str] = []
    for label, path_field, sha_field in (
        ("MANIFEST", "path", "sha256"),
        ("SIDECAR", "sidecar_path", "sidecar_sha256"),
    ):
        path = Path(str(metadata.get(path_field) or ""))
        if not path.is_file() or sha256_file(path) != metadata.get(sha_field):
            errors.append(f"EXECUTION_COST_{label}_CHANGED")
    axes = metadata.get("axes")
    if not isinstance(axes, Mapping) or set(axes) != set(EXECUTION_COST_AXES):
        errors.append("EXECUTION_COST_AXIS_BINDINGS_INVALID")
    elif any(not isinstance(axes.get(axis), list) or not axes.get(axis) for axis in EXECUTION_COST_AXES):
        errors.append("EXECUTION_COST_AXIS_BINDINGS_INCOMPLETE")
    for artifact in metadata.get("bound_artifacts") or []:
        if not isinstance(artifact, dict):
            errors.append("EXECUTION_COST_ARTIFACT_BINDING_INVALID")
            continue
        path = Path(str(artifact.get("path") or ""))
        if not path.is_file() or sha256_file(path) != artifact.get("sha256"):
            errors.append(f"EXECUTION_COST_ARTIFACT_CHANGED:{path}")
        sidecar = Path(str(artifact.get("sidecar_path") or ""))
        if not sidecar.is_file() or sha256_file(sidecar) != artifact.get("sidecar_sha256"):
            errors.append(f"EXECUTION_COST_ARTIFACT_SIDECAR_CHANGED:{sidecar}")
    return not errors, sorted(set(errors))


def execution_cost_axis_hash_snapshot(
    metadata: Mapping[str, Any] | None,
) -> dict[str, list[dict[str, Any]]] | None:
    """Return current file/sidecar hashes for every semantically bound axis."""

    if metadata is None:
        return None
    axes = metadata.get("axes")
    if not isinstance(axes, Mapping):
        return None
    snapshot: dict[str, list[dict[str, Any]]] = {}
    for axis in EXECUTION_COST_AXES:
        rows: list[dict[str, Any]] = []
        for binding in axes.get(axis) or []:
            if not isinstance(binding, Mapping):
                continue
            path = Path(str(binding.get("path") or ""))
            sidecar = Path(str(binding.get("sidecar_path") or ""))
            rows.append(
                {
                    "path": str(path),
                    "sha256": sha256_file(path) if path.is_file() else None,
                    "sidecar_path": str(sidecar),
                    "sidecar_sha256": sha256_file(sidecar) if sidecar.is_file() else None,
                    "artifact_payload_sha256": binding.get("artifact_payload_sha256"),
                    "evidence_type": binding.get("evidence_type"),
                }
            )
        snapshot[axis] = sorted(rows, key=lambda row: str(row["path"]))
    return snapshot


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def verify_network_isolation(path: Path) -> bool:
    programs = [path / "terminal64.exe", path / "metatester64.exe"]
    quoted = ",".join("'" + str(item).replace("'", "''") + "'" for item in programs)
    script = (
        f"$programs=@({quoted});"
        "$rules=Get-NetFirewallRule -Enabled True -Direction Outbound -Action Block -ErrorAction Stop;"
        "foreach($program in $programs){"
        "$matched=$false;foreach($rule in $rules){"
        "$app=$rule|Get-NetFirewallApplicationFilter;"
        "$address=$rule|Get-NetFirewallAddressFilter;"
        "if($app.Program -ieq $program -and $address.RemoteAddress -contains 'Internet'){$matched=$true;break}"
        "};if(-not $matched){exit 7}};Write-Output 'PASS'"
    )
    try:
        completed = subprocess.run(
            ["pwsh.exe", "-NoProfile", "-Command", script],
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return completed.returncode == 0 and completed.stdout.strip().endswith("PASS")


def validate_sandbox_root(
    path: Path,
    *,
    network_isolation_verifier: Callable[[Path], bool] = verify_network_isolation,
) -> Path:
    resolved = path.resolve()
    if not SAFE_SANDBOX_RE.match(resolved.name):
        raise RequalError(f"unsafe sandbox name (expected DXZ_Truth_*): {resolved}")
    lowered = {part.lower() for part in resolved.parts}
    if "t_live" in lowered or any(re.fullmatch(r"t(?:10|[1-9])", part) for part in lowered):
        raise RequalError(f"tier/live terminal cannot be a requal sandbox: {resolved}")
    terminal = resolved / "terminal64.exe"
    if not terminal.is_file():
        raise RequalError(f"sandbox terminal missing: {terminal}")
    accounts = resolved / "Config" / "accounts.dat"
    if accounts.exists() and not network_isolation_verifier(resolved):
        raise RequalError(
            "sandbox has an account cache but no verified outbound Internet block for "
            f"terminal64.exe + metatester64.exe: {resolved}"
        )
    return resolved


def validate_output_root(path: Path, live_root: Path) -> Path:
    resolved = path.resolve()
    if _tier_path_is_forbidden(resolved) or _is_relative_to(resolved, live_root):
        raise RequalError(
            f"output must be outside every T_Live/T1-T10 terminal tree: {resolved}"
        )
    return resolved


def validate_common_root(path: Path, *, execute: bool) -> Path:
    """Keep tester Q08 output out of the live terminal's user-wide Common tree."""
    resolved = path.resolve()
    expected = DEFAULT_COMMON.resolve()
    if execute and resolved == KNOWN_LIVE_COMMON.resolve():
        raise RequalError(
            "execution against the live Windows-profile Common tree is forbidden; "
            "launch the harness under an isolated Windows identity"
        )
    if execute and resolved != expected:
        raise RequalError(
            f"common root must match the executing identity's APPDATA tree: "
            f"expected={expected} actual={resolved}"
        )
    return resolved


def parse_set_header(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
        match = re.match(r"\s*;\s*([A-Za-z0-9_ -]+?)\s*:\s*(.*?)\s*$", raw)
        if match:
            key = re.sub(r"[^a-z0-9]+", "_", match.group(1).strip().lower()).strip("_")
            values[key] = match.group(2).strip()
    return values


def resolve_live_preset(
    preset_dir: Path,
    ea_id: int,
    symbol: str,
    *,
    timeframe: str | None = None,
    variant_id: str | None = None,
) -> tuple[Path, str]:
    base_symbol = symbol.removesuffix(".DWX").upper()
    expected_timeframe = str(timeframe).upper() if timeframe is not None else None
    if expected_timeframe is not None and not TF_RE.fullmatch(expected_timeframe):
        raise RequalError(f"live preset requested timeframe invalid: {expected_timeframe}")
    expected_variant = normalize_variant_id(variant_id, label="live preset request")
    matches: list[tuple[Path, str, str | None]] = []
    for path in sorted(preset_dir.glob("*.set")):
        header = parse_set_header(path)
        header_ea = header.get("ea_id")
        header_symbol = (header.get("symbol") or "").removesuffix(".DWX").upper()
        host_symbol = (header.get("host_symbol") or "").removesuffix(".DWX").upper()
        environment = (header.get("environment") or "").lower()
        name_match = re.search(rf"_QM5_{ea_id}_", path.name, re.IGNORECASE)
        symbol_match = re.search(rf"_{re.escape(base_symbol)}_", path.name, re.IGNORECASE)
        if header_ea and str(header_ea) != str(ea_id):
            continue
        if not header_ea and not name_match:
            continue
        if header_symbol and header_symbol != base_symbol and host_symbol != base_symbol:
            continue
        if not header_symbol and not symbol_match:
            continue
        is_dxz23 = "dxz23_live" in path.name.lower()
        if environment and environment != "live" and not is_dxz23:
            continue
        if not is_dxz23 and environment != "live":
            continue
        timeframe = (header.get("timeframe") or "").upper()
        if not timeframe:
            name_tf = re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)_QM5_", path.name)
            timeframe = name_tf.group(1) if name_tf else ""
        if not TF_RE.fullmatch(timeframe):
            raise RequalError(f"live preset has no valid timeframe: {path}")
        preset_variant = normalize_variant_id(
            header.get("variant_id"), label=f"live preset {path}"
        )
        if expected_timeframe is not None and timeframe != expected_timeframe:
            continue
        if expected_variant is not None and preset_variant != expected_variant:
            continue
        matches.append((path, timeframe, preset_variant))
    dxz23_matches = [item for item in matches if "dxz23_live" in item[0].name.lower()]
    if dxz23_matches:
        matches = dxz23_matches
    if len(matches) != 1:
        raise RequalError(
            f"expected exactly one DXZ live preset for {ea_id}:{symbol}; "
            f"found {[str(item[0]) for item in matches]}"
        )
    selected, selected_timeframe, _selected_variant = matches[0]
    return selected, selected_timeframe


def resolve_live_binary(live_root: Path, ea_label: str) -> Path:
    path = live_root / "MQL5" / "Experts" / "Live EAs" / f"{ea_label}.ex5"
    if not path.is_file():
        raise RequalError(f"deployed EX5 missing: {path}")
    return path


def resolve_reference_stream(root: Path | None, ea_id: int, symbol: str) -> Path | None:
    if root is None:
        return None
    token = symbol.replace(".", "_")
    direct = root / f"{ea_id}_{token}.jsonl"
    if direct.is_file():
        return direct
    base = symbol.removesuffix(".DWX")
    alternate = root / f"{ea_id}_{base}_DWX.jsonl"
    return alternate if alternate.is_file() else None


def normalize_reference_stream_root(path: Path) -> tuple[Path, Path]:
    """Return canonical ``(snapshot_root, streams_root)`` for either CLI layout."""

    resolved = path.resolve()
    snapshot_root = resolved.parent if resolved.name.casefold() == "streams" else resolved
    streams_root = snapshot_root / "streams"
    return snapshot_root, streams_root


def _resolve_bound_artifact(
    row: dict[str, Any],
    *,
    names: tuple[str, ...],
    nested_name: str,
    manifest_dir: Path,
) -> tuple[Path, str]:
    nested = row.get(nested_name) if isinstance(row.get(nested_name), dict) else {}
    path_text = next(
        (
            row.get(name)
            for name in names
            if isinstance(row.get(name), str) and str(row.get(name)).strip()
        ),
        None,
    ) or nested.get("path")
    sha_names = {
        f"{name}_sha256"
        for name in names
        if not name.endswith("_path")
    } | {
        f"{name.removesuffix('_path')}_sha256"
        for name in names
        if name.endswith("_path")
    }
    sha = next((row.get(name) for name in sha_names if row.get(name)), None) or nested.get("sha256")
    if not isinstance(path_text, str) or not path_text.strip():
        raise RequalError(f"override row missing {nested_name} path")
    if not isinstance(sha, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", sha):
        raise RequalError(f"override row missing valid {nested_name} SHA-256")
    path = Path(path_text)
    if not path.is_absolute():
        path = manifest_dir / path
    path = path.resolve()
    if not path.is_file():
        raise RequalError(f"override {nested_name} artifact missing: {path}")
    actual = sha256_file(path)
    if actual.lower() != sha.lower():
        raise RequalError(
            f"override {nested_name} hash mismatch: expected={sha.lower()} actual={actual}"
        )
    return path, actual


def load_artifact_override_manifest(
    path: Path,
    *,
    qualification_mode: str | None = None,
    source_manifest_sha256: str | None = None,
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    """Load and hash-verify explicit EX5/set bindings.

    Discovery keeps its legacy schema.  ``TARGET_BINARY_REQUAL`` additionally
    requires an immutable, canonically hashed manifest bound to the exact book
    manifest, with every EX5 and set outside all live/tier terminal roots.
    """

    resolved = path.resolve()
    try:
        payload = json.loads(resolved.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise RequalError(f"invalid artifact override manifest {resolved}: {exc}") from exc
    if not isinstance(payload, dict):
        raise RequalError("artifact override manifest must be a JSON object")
    if payload.get("schema_version") != 1:
        raise RequalError("artifact override manifest schema_version must be 1")
    declared_mode = payload.get("qualification_mode")
    effective_mode = qualification_mode or declared_mode
    if qualification_mode is not None and declared_mode != qualification_mode:
        raise RequalError(
            "artifact override qualification_mode mismatch: "
            f"expected={qualification_mode} actual={declared_mode}"
        )
    target_mode = effective_mode == TARGET_BINARY_REQUAL
    sidecar_binding: dict[str, str] = {}
    declared_payload_sha: str | None = None
    if target_mode:
        if payload.get("artifact_type") != TARGET_ARTIFACT_MANIFEST_TYPE:
            raise RequalError("target artifact override manifest artifact_type invalid")
        if (
            not isinstance(source_manifest_sha256, str)
            or not re.fullmatch(r"[0-9a-f]{64}", source_manifest_sha256.lower())
        ):
            raise RequalError("target artifact override requires source manifest SHA-256")
        if payload.get("source_manifest_sha256") != source_manifest_sha256.lower():
            raise RequalError("target artifact override source manifest mismatch")
        declared_payload_sha = str(payload.get("artifact_payload_sha256") or "").lower()
        unsigned = dict(payload)
        unsigned.pop("artifact_payload_sha256", None)
        if (
            not re.fullmatch(r"[0-9a-f]{64}", declared_payload_sha)
            or canonical_json_sha(unsigned) != declared_payload_sha
        ):
            raise RequalError("target artifact override canonical payload SHA-256 invalid")
        sidecar_binding = _read_immutable_sidecar(
            resolved,
            label="target artifact override manifest",
            file_sha=sha256_file(resolved),
        )
    raw_rows = payload.get("artifacts", payload.get("jobs"))
    if not isinstance(raw_rows, list) or not raw_rows:
        raise RequalError("artifact override manifest requires a non-empty artifacts array")
    indexed: dict[str, dict[str, Any]] = {}
    for raw_original in raw_rows:
        raw = dict(raw_original) if isinstance(raw_original, dict) else raw_original
        if not isinstance(raw, dict):
            raise RequalError("artifact override row must be an object")
        if "set" not in raw and isinstance(raw.get("preset"), dict):
            raw["set"] = raw["preset"]
        try:
            ea_id = int(raw["ea_id"])
        except (KeyError, TypeError, ValueError) as exc:
            raise RequalError("artifact override row has invalid ea_id") from exc
        symbol = str(raw.get("symbol") or "").upper()
        timeframe = str(raw.get("timeframe") or "").upper()
        if "variant_id" in raw and raw.get("variant_id") is None:
            raise RequalError("artifact override row variant_id cannot be null")
        variant_id = normalize_variant_id(
            raw.get("variant_id"), label="artifact override row"
        )
        if not symbol.endswith(".DWX"):
            raise RequalError(f"artifact override symbol must be literal .DWX: {ea_id}:{symbol}")
        if not TF_RE.fullmatch(timeframe):
            raise RequalError(f"artifact override timeframe invalid: {ea_id}:{timeframe}")
        key = promotion_identity_key(ea_id, symbol, timeframe, variant_id)
        if key in indexed:
            raise RequalError(f"duplicate artifact override row: {key}")
        ex5, ex5_sha = _resolve_bound_artifact(
            raw,
            names=("ex5", "live_ex5", "ex5_path", "live_ex5_path"),
            nested_name="ex5",
            manifest_dir=resolved.parent,
        )
        preset, preset_sha = _resolve_bound_artifact(
            raw,
            names=("set", "preset", "live_preset", "set_path", "preset_path", "live_preset_path"),
            nested_name="set",
            manifest_dir=resolved.parent,
        )
        if target_mode:
            if ex5.suffix.casefold() != ".ex5":
                raise RequalError(f"target override EX5 extension invalid: {ex5}")
            if preset.suffix.casefold() != ".set":
                raise RequalError(f"target override set extension invalid: {preset}")
            if _tier_path_is_forbidden(ex5) or _tier_path_is_forbidden(preset):
                raise RequalError(
                    "target override EX5/set must be outside T_Live/T1-T10: "
                    f"{ea_id}:{symbol}"
                )
        indexed[key] = {
            "ea_id": ea_id,
            "symbol": symbol,
            "timeframe": timeframe,
            "variant_id": variant_id,
            "ea_label": raw.get("ea_label"),
            "ex5_path": ex5,
            "ex5_sha256": ex5_sha,
            "set_path": preset,
            "set_sha256": preset_sha,
        }
    metadata = {
        "path": str(resolved),
        "sha256": sha256_file(resolved),
        **sidecar_binding,
        "schema_version": payload.get("schema_version"),
        "artifact_type": payload.get("artifact_type"),
        "artifact_payload_sha256": declared_payload_sha,
        "source_manifest_sha256": payload.get("source_manifest_sha256"),
        "qualification_mode": declared_mode,
        "rows": len(indexed),
        "bound_artifacts": sorted(
            [
                {
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "timeframe": row["timeframe"],
                    "variant_id": row["variant_id"],
                    "ex5_path": str(row["ex5_path"]),
                    "ex5_sha256": row["ex5_sha256"],
                    "set_path": str(row["set_path"]),
                    "set_sha256": row["set_sha256"],
                }
                for row in indexed.values()
            ],
            key=lambda row: (
                row["ea_id"],
                row["symbol"],
                row["timeframe"],
                row["variant_id"] or "",
            ),
        ),
    }
    return metadata, indexed


def verify_artifact_override_unchanged(
    metadata: Mapping[str, Any] | None,
) -> tuple[dict[str, Any] | None, list[str]]:
    if metadata is None:
        return None, []
    errors: list[str] = []
    manifest = Path(str(metadata.get("path") or ""))
    manifest_sha = sha256_file(manifest) if manifest.is_file() else None
    if manifest_sha != metadata.get("sha256"):
        errors.append("ARTIFACT_OVERRIDE_MANIFEST_CHANGED_DURING_SWEEP")
    sidecar_path = str(metadata.get("sidecar_path") or "")
    sidecar_sha: str | None = None
    if sidecar_path:
        sidecar = Path(sidecar_path)
        sidecar_sha = sha256_file(sidecar) if sidecar.is_file() else None
        if sidecar_sha != metadata.get("sidecar_sha256"):
            errors.append("ARTIFACT_OVERRIDE_SIDECAR_CHANGED_DURING_SWEEP")
    rows: list[dict[str, Any]] = []
    for binding in metadata.get("bound_artifacts") or []:
        if not isinstance(binding, Mapping):
            errors.append("ARTIFACT_OVERRIDE_BINDING_INVALID")
            continue
        row = {
            "ea_id": binding.get("ea_id"),
            "symbol": binding.get("symbol"),
            "timeframe": binding.get("timeframe"),
            "variant_id": binding.get("variant_id"),
        }
        for kind in ("ex5", "set"):
            artifact = Path(str(binding.get(f"{kind}_path") or ""))
            actual = sha256_file(artifact) if artifact.is_file() else None
            row[f"{kind}_path"] = str(artifact)
            row[f"{kind}_sha256"] = actual
            if actual != binding.get(f"{kind}_sha256"):
                errors.append(
                    f"ARTIFACT_OVERRIDE_{kind.upper()}_CHANGED_DURING_SWEEP:"
                    f"{binding.get('ea_id')}:{binding.get('symbol')}:"
                    f"{binding.get('timeframe')}:{binding.get('variant_id') or ''}"
                )
        rows.append(row)
    end = {
        "manifest_sha256": manifest_sha,
        "sidecar_sha256": sidecar_sha,
        "bound_artifacts": sorted(
            rows,
            key=lambda row: (
                int(row.get("ea_id") or 0),
                str(row.get("symbol") or ""),
                str(row.get("timeframe") or ""),
                str(row.get("variant_id") or ""),
            ),
        ),
    }
    return end, sorted(set(errors))


def resolve_card_contract_binding(
    raw: Any,
    *,
    manifest_dir: Path,
    required: bool,
    identity_label: str,
    expected_identity: tuple[int, str, str, str] | None = None,
) -> dict[str, str] | None:
    """Resolve one approved Card-v2 contract without path or identity guessing."""

    if raw is None:
        if required:
            raise RequalError(
                f"TARGET_BINARY_REQUAL requires card_contract {{path,sha256}}: "
                f"{identity_label}"
            )
        return None
    if not isinstance(raw, dict) or set(raw) != {"path", "sha256"}:
        raise RequalError(
            f"card_contract must contain exactly path and sha256: {identity_label}"
        )
    path_text = raw.get("path")
    expected_sha = raw.get("sha256")
    if not isinstance(path_text, str) or not path_text.strip():
        raise RequalError(f"card_contract path missing: {identity_label}")
    if not isinstance(expected_sha, str) or not re.fullmatch(
        r"[0-9a-fA-F]{64}", expected_sha
    ):
        raise RequalError(f"card_contract SHA-256 invalid: {identity_label}")
    card_path = Path(path_text)
    if not card_path.is_absolute():
        card_path = manifest_dir / card_path
    card_path = card_path.resolve()
    if _tier_path_is_forbidden(card_path):
        raise RequalError(
            f"card_contract must be outside T_Live/T1-T10: {identity_label}"
        )
    if not card_path.is_file():
        raise RequalError(f"card_contract artifact missing: {card_path}")
    actual_sha = sha256_file(card_path)
    if actual_sha.lower() != expected_sha.lower():
        raise RequalError(
            f"card_contract hash mismatch for {identity_label}: "
            f"expected={expected_sha.lower()} actual={actual_sha}"
        )
    text = card_path.read_text(encoding="utf-8-sig", errors="replace")
    frontmatter_match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    frontmatter: dict[str, str] = {}
    if frontmatter_match:
        for line in frontmatter_match.group(1).splitlines():
            field = re.match(
                r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*?)\s*$", line
            )
            if field:
                frontmatter[field.group(1)] = (
                    field.group(2).strip().strip('"').strip("'")
                )
    if frontmatter.get("card_schema_version") != "2":
        raise RequalError(
            f"card_contract must be a Strategy Card v2: {identity_label}"
        )
    if (
        frontmatter.get("status", "").upper() != "APPROVED"
        or frontmatter.get("g0_status", "").upper() != "APPROVED"
        or frontmatter.get("execution_contract_status", "").upper()
        != "APPROVED"
    ):
        raise RequalError(
            "card_contract must have status, g0_status and "
            f"execution_contract_status APPROVED: {identity_label}"
        )
    if expected_identity is not None:
        expected_ea, expected_symbol, expected_timeframe, expected_variant = (
            expected_identity
        )
        raw_ea = frontmatter.get("ea_id", "")
        normalized_ea = re.sub(r"^QM5_", "", raw_ea, flags=re.IGNORECASE)
        observed_identity = (
            int(normalized_ea) if normalized_ea.isdigit() else None,
            frontmatter.get("symbol", "").upper(),
            frontmatter.get("timeframe", "").upper(),
            frontmatter.get("variant_id", ""),
        )
        if observed_identity != (
            expected_ea,
            expected_symbol.upper(),
            expected_timeframe.upper(),
            expected_variant,
        ):
            raise RequalError(
                "card_contract four-part identity mismatch for "
                f"{identity_label}: observed={observed_identity}"
            )
    return {"path": str(card_path), "sha256": actual_sha}


def verify_card_contract_binding(
    binding: Mapping[str, Any] | None,
    *,
    identity_label: str,
) -> dict[str, Any] | None:
    """Re-hash one already resolved card binding for TOCTOU checks."""

    if binding is None:
        return None
    card_path = Path(str(binding.get("path") or ""))
    actual_sha = sha256_file(card_path) if card_path.is_file() else None
    expected_sha = str(binding.get("sha256") or "").lower()
    if actual_sha != expected_sha:
        raise RequalError(
            f"card_contract changed after preflight for {identity_label}: "
            f"expected={expected_sha} actual={actual_sha}"
        )
    return {"path": str(card_path.resolve()), "sha256": actual_sha}


def load_trade_rows(path: Path | None) -> list[dict[str, Any]]:
    if path is None or not path.is_file():
        return []
    rows: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("event") in (None, "TRADE_CLOSED", "DEAL_CLOSED"):
            payload = row.get("payload") if isinstance(row.get("payload"), dict) else row
            rows.append(dict(payload))
    return rows


def load_trade_rows_strict(path: Path | None) -> tuple[list[dict[str, Any]], list[str]]:
    """Parse a Q08/reference stream without silently discarding bad evidence."""
    if path is None or not path.is_file():
        return [], ["STREAM_MISSING"]
    rows: list[dict[str, Any]] = []
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError) as exc:
        return [], [f"STREAM_READ_ERROR:{exc!r}"]
    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            raw = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"line {line_number}: invalid JSON ({exc.msg})")
            continue
        if not isinstance(raw, dict):
            errors.append(f"line {line_number}: JSON value is not an object")
            continue
        if raw.get("event") not in ("TRADE_CLOSED", "DEAL_CLOSED"):
            errors.append(f"line {line_number}: unsupported event={raw.get('event')!r}")
            continue
        payload = raw.get("payload") if isinstance(raw.get("payload"), dict) else raw
        row = dict(payload)
        missing: list[str] = []
        if row_entry_time(row) is None:
            missing.append("entry_time")
        if not isinstance(row.get("symbol"), str) or not row["symbol"].strip():
            missing.append("symbol")
        if row_time(row) is None:
            missing.append("close_time")
        if missing:
            errors.append(f"line {line_number}: missing/invalid {','.join(missing)}")
            continue
        rows.append(row)
    if not rows:
        errors.append("STREAM_EMPTY")
    return rows, errors


def row_time(row: dict[str, Any]) -> int | None:
    value = row.get("time") or row.get("close_time") or row.get("ts_utc")
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value / 1000 if value > 10_000_000_000 else value)
    text = str(value).strip().replace("Z", "+00:00")
    if text.isdigit():
        return row_time({"time": int(text)})
    try:
        stamp = dt.datetime.fromisoformat(text)
        if stamp.tzinfo is None:
            stamp = stamp.replace(tzinfo=dt.UTC)
        return int(stamp.timestamp())
    except ValueError:
        return None


def row_entry_time(row: dict[str, Any]) -> int | None:
    value = row.get("entry_time")
    if value is None:
        return None
    return row_time({"time": value})


def signal_identity_stats(rows: Iterable[dict[str, Any]]) -> dict[str, Any]:
    materialized = list(rows)
    identities: list[list[Any]] = []
    outcome_signs: list[int] = []
    invalid_identity_rows = 0
    invalid_outcome_rows = 0
    for row in materialized:
        entry_time = row_entry_time(row)
        close_time = row_time(row)
        symbol = str(row.get("symbol") or "").strip().upper()
        if entry_time is None or close_time is None or not symbol:
            invalid_identity_rows += 1
            continue
        identities.append([entry_time, close_time, symbol])
        # Gross profit is the strategy outcome.  Net can flip a marginal trade
        # solely because historical commission/account economics differ.
        value = row.get("profit", row.get("net"))
        try:
            numeric = float(value)
        except (TypeError, ValueError):
            invalid_outcome_rows += 1
            continue
        outcome_signs.append(1 if numeric > 0 else (-1 if numeric < 0 else 0))
    row_count = len(materialized)
    identity_complete = row_count > 0 and invalid_identity_rows == 0
    outcome_complete = (
        identity_complete
        and invalid_outcome_rows == 0
        and len(outcome_signs) == row_count
    )
    return {
        "complete": identity_complete,
        "identity_complete": identity_complete,
        "row_count": row_count,
        "valid_identity_rows": len(identities),
        "invalid_identity_rows": invalid_identity_rows,
        "identity_count": len(identities),
        "identity_sha256": canonical_json_sha(identities),
        "valid_outcome_rows": len(outcome_signs),
        "invalid_outcome_rows": invalid_outcome_rows,
        "outcome_sign_count": len(outcome_signs),
        "outcome_sign_sha256": canonical_json_sha(outcome_signs),
        "outcome_sign_complete": outcome_complete,
        "outcome_sign_basis": "gross_profit_fallback_net",
    }


def compare_signal_identity(
    left: Mapping[str, Any], right: Mapping[str, Any]
) -> dict[str, bool]:
    """Compare identity and outcome independently; neither result implies the other."""

    identity_match = (
        left.get("identity_complete") is True
        and right.get("identity_complete") is True
        and left.get("identity_count") == right.get("identity_count")
        and left.get("identity_sha256") == right.get("identity_sha256")
    )
    outcome_sign_match = (
        left.get("outcome_sign_complete") is True
        and right.get("outcome_sign_complete") is True
        and left.get("outcome_sign_count") == right.get("outcome_sign_count")
        and left.get("outcome_sign_sha256") == right.get("outcome_sign_sha256")
    )
    return {
        "identity_match": identity_match,
        "outcome_sign_match": outcome_sign_match,
    }


def _canonical_decimal_text(value: Any) -> str | None:
    """Return a stable finite decimal representation, or ``None`` if invalid."""

    try:
        parsed = Decimal(str(value).strip())
    except (InvalidOperation, ValueError, TypeError):
        return None
    if not parsed.is_finite():
        return None
    if parsed == 0:
        return "0"
    return format(parsed.normalize(), "f")


def target_reproducibility_identity(
    rows: Iterable[dict[str, Any]],
    *,
    parse_errors: Iterable[str] = (),
    runtime_telemetry: Mapping[str, Any] | None = None,
    telemetry_binding: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Describe every immutable sequence required by the TARGET pair gate.

    The current Q08 stream fully carries the ordered trade rows, signal times,
    volume, outcome sign and exact net PnL.  It does not yet carry entry
    side/price, a semantic exit reason, daily/intraday MTM or margin streams.
    Those axes are emitted as explicit, incomplete descriptors so no
    downstream consumer can mistake a partial observation for proof.
    """

    materialized = [dict(row) for row in rows]
    detailed_rows = materialized
    if isinstance(telemetry_binding, Mapping) and isinstance(
        telemetry_binding.get("enriched_rows"), list
    ):
        detailed_rows = [dict(row) for row in telemetry_binding["enriched_rows"]]
    errors = [str(error) for error in parse_errors]
    row_count = len(materialized)
    stream_complete = row_count > 0 and not errors
    stream_reasons = [*errors, *(["STREAM_EMPTY"] if row_count == 0 else [])]
    signal_stats = signal_identity_stats(materialized)

    trade_sequence = materialized
    signal_sequence = [
        [row_entry_time(row), row_time(row), str(row.get("symbol") or "").strip().upper()]
        for row in materialized
        if row_entry_time(row) is not None
        and row_time(row) is not None
        and str(row.get("symbol") or "").strip()
    ]

    entry_sequence: list[list[Any]] = []
    entry_invalid: list[int] = []
    exit_sequence: list[list[Any]] = []
    exit_missing: list[int] = []
    lot_sequence: list[list[Any]] = []
    lot_invalid: list[int] = []
    pnl_sequence: list[list[Any]] = []
    pnl_invalid: list[int] = []
    outcome_sign_sequence: list[list[Any]] = []
    for index, row in enumerate(detailed_rows):
        raw_side = str(row.get("side", row.get("direction", ""))).strip().upper()
        side = {
            "LONG": "BUY",
            "BUY": "BUY",
            "SHORT": "SELL",
            "SELL": "SELL",
        }.get(raw_side)
        entry_price = _canonical_decimal_text(row.get("entry_price"))
        if side is not None and entry_price is not None and Decimal(entry_price) > 0:
            entry_sequence.append(
                [
                    index,
                    row_entry_time(row),
                    str(row.get("symbol") or "").strip().upper(),
                    side,
                    entry_price,
                ]
            )
        else:
            entry_invalid.append(index)

        exit_reason = row.get("exit_reason")
        if isinstance(exit_reason, str) and exit_reason.strip():
            exit_sequence.append([index, row_time(row), exit_reason.strip()])
        else:
            exit_missing.append(index)

        volume = _canonical_decimal_text(row.get("volume"))
        if volume is not None and Decimal(volume) > 0:
            lot_sequence.append([index, volume])
        else:
            lot_invalid.append(index)

        net = _canonical_decimal_text(row.get("net"))
        if net is not None:
            pnl_sequence.append([index, net])
            numeric_net = Decimal(net)
            outcome_sign_sequence.append(
                [index, 1 if numeric_net > 0 else (-1 if numeric_net < 0 else 0)]
            )
        else:
            pnl_invalid.append(index)

    def descriptor(
        sequence: list[Any],
        *,
        complete: bool,
        basis: str,
        reasons: Iterable[str] = (),
        count: int | None = None,
    ) -> dict[str, Any]:
        return {
            "complete": bool(complete),
            "count": row_count if count is None else int(count),
            "sha256": canonical_json_sha(sequence),
            "basis": basis,
            "reasons": sorted(set(str(reason) for reason in reasons)),
        }

    telemetry_required = telemetry_binding is not None
    telemetry_entry_complete = (
        isinstance(telemetry_binding, Mapping)
        and telemetry_binding.get("entries_complete") is True
    )
    telemetry_exit_complete = (
        isinstance(telemetry_binding, Mapping)
        and telemetry_binding.get("exits_complete") is True
    )
    telemetry_entry_reasons = (
        [str(item) for item in telemetry_binding.get("entry_axis_reasons", [])]
        if isinstance(telemetry_binding, Mapping)
        else []
    )
    telemetry_exit_reasons = (
        [str(item) for item in telemetry_binding.get("exit_axis_reasons", [])]
        if isinstance(telemetry_binding, Mapping)
        else []
    )
    daily_sequence = (
        runtime_telemetry.get("equity", {}).get("sequence", [])
        if isinstance(runtime_telemetry, Mapping)
        else []
    )
    if not isinstance(daily_sequence, list):
        daily_sequence = []

    return {
        "schema_version": 1,
        "trades": descriptor(
            trade_sequence,
            complete=stream_complete,
            basis="ordered_canonical_q08_trade_rows",
            reasons=stream_reasons,
        ),
        "signals": descriptor(
            signal_sequence,
            complete=(
                stream_complete
                and signal_stats.get("identity_complete") is True
                and len(signal_sequence) == row_count
            ),
            basis="ordered_entry_close_symbol_identity",
            reasons=[
                *stream_reasons,
                *(
                    []
                    if signal_stats.get("identity_complete") is True
                    else ["SIGNAL_IDENTITY_INCOMPLETE"]
                ),
            ],
        ),
        "entries": descriptor(
            entry_sequence,
            complete=(
                stream_complete
                and not entry_invalid
                and (not telemetry_required or telemetry_entry_complete)
            ),
            basis=(
                "ordered_q08_runtime_log_unique_time_symbol_volume_join"
                if telemetry_required
                else "ordered_entry_time_symbol_side_price_identity"
            ),
            reasons=[
                *stream_reasons,
                *(
                    telemetry_entry_reasons
                    if telemetry_required and not telemetry_entry_complete
                    else []
                ),
                *[
                    f"ENTRY_SIDE_OR_PRICE_INVALID_AT_ROW:{index}"
                    for index in entry_invalid
                ],
            ],
        ),
        "exits": descriptor(
            exit_sequence,
            complete=(
                stream_complete
                and not exit_missing
                and (not telemetry_required or telemetry_exit_complete)
            ),
            basis=(
                "ordered_q08_runtime_log_unique_time_symbol_volume_join"
                if telemetry_required
                else "ordered_close_time_exit_reason_identity"
            ),
            reasons=[
                *stream_reasons,
                *(
                    telemetry_exit_reasons
                    if telemetry_required and not telemetry_exit_complete
                    else []
                ),
                *[f"EXIT_REASON_MISSING_AT_ROW:{index}" for index in exit_missing],
            ],
        ),
        "lots": descriptor(
            lot_sequence,
            complete=stream_complete and not lot_invalid,
            basis="ordered_exact_volume_identity",
            reasons=[
                *stream_reasons,
                *[f"VOLUME_INVALID_AT_ROW:{index}" for index in lot_invalid],
            ],
        ),
        "outcome_signs": descriptor(
            outcome_sign_sequence,
            complete=stream_complete and not pnl_invalid,
            basis="ordered_exact_net_pnl_sign_identity",
            reasons=[
                *stream_reasons,
                *[f"NET_PNL_INVALID_AT_ROW:{index}" for index in pnl_invalid],
            ],
        ),
        "pnl": descriptor(
            pnl_sequence,
            complete=stream_complete and not pnl_invalid,
            basis="ordered_exact_net_pnl_identity",
            reasons=[
                *stream_reasons,
                *[f"NET_PNL_INVALID_AT_ROW:{index}" for index in pnl_invalid],
            ],
        ),
        "daily_mtm": descriptor(
            daily_sequence,
            complete=False,
            count=len(daily_sequence),
            basis="framework_EQUITY_SNAPSHOT_partial_daily_observation_sequence",
            reasons=[
                "DAILY_MTM_INITIAL_AND_FINAL_BOUNDARY_SNAPSHOTS_NOT_EMITTED"
            ],
        ),
        "mtm": descriptor(
            [],
            complete=False,
            count=0,
            basis="intraday_mark_to_market_observation_sequence",
            reasons=["INTRADAY_MTM_STREAM_NOT_EMITTED_BY_CURRENT_RUNNER_CONTRACT"],
        ),
        "margin": descriptor(
            [],
            complete=False,
            count=0,
            basis="used_free_stressed_margin_observation_sequence",
            reasons=["MARGIN_STREAM_NOT_EMITTED_BY_CURRENT_RUNNER_CONTRACT"],
        ),
    }


def qualification_status(
    qualification_mode: str,
    *,
    technical_pass: bool,
    cost_certified: bool,
) -> str:
    """Return the qualification state without promoting one TARGET run."""

    if qualification_mode in DISCOVERY_MODES:
        return "NONQUALIFYING_DISCOVERY"
    if not technical_pass:
        return "FAILED"
    if not cost_certified:
        return "COST_UNCERTIFIED"
    if qualification_mode == TARGET_BINARY_REQUAL:
        return TARGET_SINGLE_RUN_STATUS
    return "QUALIFIED"


def trade_stats(rows: Iterable[dict[str, Any]]) -> dict[str, Any]:
    materialized = list(rows)
    nets: list[float] = []
    times: list[int] = []
    for row in materialized:
        try:
            nets.append(float(row.get("net", row.get("profit", 0.0))) or 0.0)
        except (TypeError, ValueError):
            pass
        stamp = row_time(row)
        if stamp is not None:
            times.append(stamp)
    return {
        "trades": len(materialized),
        "net": round(sum(nets), 8),
        "close_time_count": len(times),
        "close_times_sha256": canonical_json_sha(times),
        "first_close_time": min(times) if times else None,
        "last_close_time": max(times) if times else None,
    }


@dataclasses.dataclass(frozen=True)
class Job:
    ordinal: int
    ea_id: int
    symbol: str
    ea_label: str
    timeframe: str
    live_ex5: Path
    live_preset: Path
    manifest_trades: int | None
    reference_stream: Path | None
    variant_id: str | None = None
    card_contract: dict[str, str] | None = None
    reference_binding_key: str | None = None
    reference_expected_sha256: str | None = None
    reference_frozen_relative_path: str | None = None
    artifact_source: str = "CANONICAL_T_LIVE"
    execution_cost_contract: dict[str, Any] | None = None
    set_file_expectation: dict[str, Any] | None = None
    manifest_risk_percent: Any = None
    expected_magic: int | None = None
    expected_magic_source: dict[str, Any] | None = None

    @property
    def key(self) -> str:
        return promotion_identity_key(
            self.ea_id, self.symbol, self.timeframe, self.variant_id
        )

    @property
    def timeframe_key(self) -> str:
        return promotion_identity_key(self.ea_id, self.symbol, self.timeframe)

    @property
    def legacy_key(self) -> str:
        return f"{self.ea_id}:{self.symbol.upper()}"

    @property
    def slug(self) -> str:
        variant = f"_{self.variant_id}" if self.variant_id else ""
        return (
            f"{self.ordinal:02d}_{self.ea_id}_{self.symbol.replace('.', '_')}_"
            f"{self.timeframe}{variant}"
        )


def verify_expected_magic_binding(
    job: Job,
    *,
    required: bool,
) -> dict[str, Any] | None:
    """Validate the manifest-sleeve authority carried by one expected magic."""

    if job.expected_magic is None:
        if required:
            raise RequalError(
                f"TARGET_BINARY_REQUAL job is missing expected_magic: {job.key}"
            )
        return None
    if type(job.expected_magic) is not int or job.expected_magic <= 0:
        raise RequalError(
            f"job expected_magic must be an exact positive integer: {job.key}"
        )
    source = job.expected_magic_source
    if not isinstance(source, dict):
        raise RequalError(f"job expected_magic source metadata is missing: {job.key}")
    if (
        source.get("authority") != "HASH_BOUND_SOURCE_MANIFEST_SLEEVE"
        or source.get("field") != "magic_number"
        or type(source.get("sleeve_ordinal")) is not int
        or source.get("sleeve_ordinal") != job.ordinal
        or source.get("promotion_identity") != job.key
        or type(source.get("expected_magic")) is not int
        or source.get("expected_magic") != job.expected_magic
        or not isinstance(source.get("manifest_path"), str)
        or not str(source.get("manifest_path")).strip()
        or not isinstance(source.get("manifest_sha256"), str)
        or not re.fullmatch(r"[0-9a-f]{64}", str(source.get("manifest_sha256")))
    ):
        raise RequalError(f"job expected_magic source metadata is invalid: {job.key}")
    source_manifest = Path(str(source["manifest_path"])).resolve()
    if (
        not source_manifest.is_file()
        or sha256_file(source_manifest) != source["manifest_sha256"]
    ):
        raise RequalError(f"job expected_magic source manifest changed: {job.key}")
    try:
        manifest = _strict_runtime_json(
            source_manifest.read_text(encoding="utf-8-sig", errors="strict")
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise RequalError(
            f"job expected_magic source manifest is invalid JSON: {job.key}: {exc}"
        ) from exc
    sleeves = manifest.get("sleeves") if isinstance(manifest, dict) else None
    if not isinstance(sleeves, list):
        raise RequalError(
            f"job expected_magic source manifest sleeves must be a list: {job.key}"
        )

    def sleeve_identity(raw: Any, *, ordinal: int) -> tuple[int, str, str, str | None]:
        if not isinstance(raw, dict):
            raise RequalError(
                f"job expected_magic source sleeve must be an object: ordinal={ordinal}"
            )
        raw_ea_id = raw.get("ea_id")
        raw_symbol = raw.get("symbol")
        if type(raw_ea_id) is not int or raw_ea_id <= 0:
            raise RequalError(
                f"job expected_magic source sleeve ea_id invalid: ordinal={ordinal}"
            )
        if (
            not isinstance(raw_symbol, str)
            or raw_symbol != raw_symbol.upper()
            or not raw_symbol.endswith(".DWX")
        ):
            raise RequalError(
                f"job expected_magic source sleeve symbol invalid: ordinal={ordinal}"
            )
        declared_timeframes = [
            raw.get(field)
            for field in ("timeframe", "host_timeframe")
            if raw.get(field) is not None
        ]
        if (
            not declared_timeframes
            or any(
                not isinstance(value, str)
                or value != value.upper()
                or not TF_RE.fullmatch(value)
                for value in declared_timeframes
            )
            or len(set(declared_timeframes)) != 1
        ):
            raise RequalError(
                "job expected_magic source sleeve timeframe invalid or conflicting: "
                f"ordinal={ordinal}"
            )
        variant_id = normalize_variant_id(
            raw.get("variant_id"),
            label=f"job expected_magic source sleeve ordinal={ordinal}",
        )
        return raw_ea_id, raw_symbol, declared_timeframes[0], variant_id

    selected_ordinal = int(source["sleeve_ordinal"])
    if selected_ordinal < 1 or selected_ordinal > len(sleeves):
        raise RequalError(
            f"job expected_magic source sleeve ordinal out of range: {job.key}"
        )
    identities = [
        sleeve_identity(raw, ordinal=ordinal)
        for ordinal, raw in enumerate(sleeves, start=1)
    ]
    expected_identity = (job.ea_id, job.symbol, job.timeframe, job.variant_id)
    selected = sleeves[selected_ordinal - 1]
    if identities[selected_ordinal - 1] != expected_identity:
        raise RequalError(
            f"job expected_magic source sleeve identity mismatch: {job.key}"
        )
    raw_magic = selected.get("magic_number")
    if type(raw_magic) is not int or raw_magic <= 0 or raw_magic != job.expected_magic:
        raise RequalError(
            f"job expected_magic source sleeve magic_number mismatch: {job.key}"
        )
    if "ea_label" in selected and selected.get("ea_label") != job.ea_label:
        raise RequalError(
            f"job expected_magic source sleeve ea_label mismatch: {job.key}"
        )
    if sum(identity == expected_identity for identity in identities) != 1:
        raise RequalError(
            f"job expected_magic source manifest identity is not unique: {job.key}"
        )
    return dict(source)


def _resolve_artifact_override_for_sleeve(
    artifact_overrides: Mapping[str, Mapping[str, Any]],
    *,
    ea_id: int,
    symbol: str,
    timeframe: str | None,
    variant_id: str | None,
) -> Mapping[str, Any]:
    """Resolve an override by exact identity, with unique-only legacy fallback."""

    candidates: list[Mapping[str, Any]] = []
    seen_keys: set[str] = set()
    for raw in artifact_overrides.values():
        if not isinstance(raw, Mapping):
            continue
        try:
            row_ea_id = int(raw.get("ea_id"))
        except (TypeError, ValueError):
            continue
        row_symbol = str(raw.get("symbol") or "").upper()
        row_timeframe = str(raw.get("timeframe") or "").upper()
        row_variant = normalize_variant_id(
            raw.get("variant_id"), label="artifact override row"
        )
        if row_ea_id != ea_id or row_symbol != symbol.upper():
            continue
        if timeframe is not None and row_timeframe != timeframe:
            continue
        if variant_id is not None and row_variant != variant_id:
            continue
        row_key = promotion_identity_key(
            row_ea_id, row_symbol, row_timeframe, row_variant
        )
        if row_key not in seen_keys:
            candidates.append(raw)
            seen_keys.add(row_key)
    requested = (
        promotion_identity_key(ea_id, symbol, timeframe, variant_id)
        if timeframe is not None
        else f"{ea_id}:{symbol}:LEGACY_TIMEFRAME"
    )
    if not candidates:
        raise RequalError(f"artifact override missing manifest sleeve: {requested}")
    if len(candidates) != 1:
        identities = sorted(
            promotion_identity_key(
                int(row["ea_id"]),
                str(row["symbol"]),
                str(row["timeframe"]),
                normalize_variant_id(
                    row.get("variant_id"), label="artifact override row"
                ),
            )
            for row in candidates
        )
        raise RequalError(
            f"artifact override identity is ambiguous for {requested}: {identities}"
        )
    return candidates[0]


def build_jobs(
    manifest_path: Path,
    live_root: Path,
    reference_stream_root: Path | None,
    artifact_overrides: dict[str, dict[str, Any]] | None = None,
    *,
    qualification_mode: str | None = None,
) -> tuple[dict[str, Any], list[Job]]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    resolved_manifest_path = manifest_path.resolve()
    manifest_sha256 = sha256_file(resolved_manifest_path)
    presets = live_root / "MQL5" / "Presets"
    jobs: list[Job] = []
    for ordinal, sleeve in enumerate(manifest.get("sleeves") or [], start=1):
        if not isinstance(sleeve, dict):
            raise RequalError(f"manifest sleeve must be an object: ordinal={ordinal}")
        ea_id = int(sleeve["ea_id"])
        symbol = str(sleeve["symbol"])
        if symbol != symbol.upper() or not symbol.endswith(".DWX"):
            raise RequalError(f"non-literal DWX symbol in book manifest: {ea_id}:{symbol}")
        label = str(sleeve["ea_label"])
        raw_expected_magic = sleeve.get("magic_number")
        if "magic_number" in sleeve and (
            type(raw_expected_magic) is not int or raw_expected_magic <= 0
        ):
            raise RequalError(
                "manifest sleeve magic_number must be an exact positive integer: "
                f"{ea_id}:{symbol}"
            )
        expected_magic = (
            raw_expected_magic
            if type(raw_expected_magic) is int and raw_expected_magic > 0
            else None
        )
        if qualification_mode == TARGET_BINARY_REQUAL and expected_magic is None:
            raise RequalError(
                "TARGET_BINARY_REQUAL requires explicit positive integer "
                f"manifest magic_number: {ea_id}:{symbol}"
            )
        declared_timeframes = {
            str(sleeve[field]).upper()
            for field in ("timeframe", "host_timeframe")
            if sleeve.get(field) is not None
        }
        if len(declared_timeframes) > 1:
            raise RequalError(
                f"manifest sleeve timeframe fields conflict: {ea_id}:{symbol}"
            )
        declared_timeframe = next(iter(declared_timeframes), None)
        if declared_timeframe is not None and not TF_RE.fullmatch(declared_timeframe):
            raise RequalError(
                f"manifest sleeve timeframe invalid: {ea_id}:{symbol}:{declared_timeframe}"
            )
        if qualification_mode == TARGET_BINARY_REQUAL and declared_timeframe is None:
            raise RequalError(
                "TARGET_BINARY_REQUAL requires explicit manifest timeframe: "
                f"{ea_id}:{symbol}"
            )
        if qualification_mode == TARGET_BINARY_REQUAL and "variant_id" not in sleeve:
            raise RequalError(
                "TARGET_BINARY_REQUAL requires explicit manifest variant_id: "
                f"{ea_id}:{symbol}:{declared_timeframe}"
            )
        if "variant_id" in sleeve and sleeve.get("variant_id") is None:
            raise RequalError("manifest sleeve variant_id cannot be null")
        declared_variant = normalize_variant_id(
            sleeve.get("variant_id"), label="manifest sleeve"
        )
        override = (
            _resolve_artifact_override_for_sleeve(
                artifact_overrides,
                ea_id=ea_id,
                symbol=symbol,
                timeframe=declared_timeframe,
                variant_id=declared_variant,
            )
            if artifact_overrides is not None
            else None
        )
        if override is not None:
            override_label = str(override.get("ea_label") or label)
            if override_label != label:
                raise RequalError(
                    f"artifact override EA label mismatch for {ea_id}:{symbol}: "
                    f"expected={label} actual={override_label}"
                )
            live_ex5 = Path(override["ex5_path"])
            live_preset = Path(override["set_path"])
            timeframe = str(override["timeframe"]).upper()
            variant_id = normalize_variant_id(
                override.get("variant_id"), label="artifact override row"
            )
            artifact_source = (
                TARGET_ARTIFACT_SOURCE
                if qualification_mode == TARGET_BINARY_REQUAL
                else "SHA_BOUND_DISCOVERY_OVERRIDE"
            )
        else:
            live_ex5 = resolve_live_binary(live_root, label)
            live_preset, timeframe = resolve_live_preset(
                presets,
                ea_id,
                symbol,
                timeframe=declared_timeframe,
                variant_id=declared_variant,
            )
            timeframe = timeframe.upper()
            if declared_timeframe is not None and declared_timeframe != timeframe:
                raise RequalError(
                    f"manifest/live preset timeframe mismatch for {ea_id}:{symbol}: "
                    f"manifest={declared_timeframe} preset={timeframe}"
                )
            variant_id = declared_variant
            artifact_source = "CANONICAL_T_LIVE"
        identity_label = promotion_identity_key(
            ea_id, symbol, timeframe, variant_id
        )
        expected_magic_source = (
            {
                "authority": "HASH_BOUND_SOURCE_MANIFEST_SLEEVE",
                "field": "magic_number",
                "manifest_path": str(resolved_manifest_path),
                "manifest_sha256": manifest_sha256,
                "sleeve_ordinal": ordinal,
                "promotion_identity": identity_label,
                "expected_magic": expected_magic,
            }
            if expected_magic is not None
            else None
        )
        card_contract = resolve_card_contract_binding(
            sleeve.get("card_contract"),
            manifest_dir=manifest_path.resolve().parent,
            required=qualification_mode == TARGET_BINARY_REQUAL,
            identity_label=identity_label,
            expected_identity=(ea_id, symbol, timeframe, variant_id)
            if qualification_mode == TARGET_BINARY_REQUAL
            and variant_id is not None
            else None,
        )
        raw_set_expectation = sleeve.get("set_file_expectation")
        if raw_set_expectation is not None and not isinstance(raw_set_expectation, dict):
            raise RequalError(f"set_file_expectation must be an object: {ea_id}:{symbol}")
        jobs.append(
            Job(
                ordinal=ordinal,
                ea_id=ea_id,
                symbol=symbol,
                ea_label=label,
                timeframe=timeframe,
                live_ex5=live_ex5,
                live_preset=live_preset,
                manifest_trades=(
                    int(sleeve["trades"]) if sleeve.get("trades") is not None else None
                ),
                # Main binds this only after the sealed snapshot manifest has
                # selected an exact frozen_relative_path.  Filename guessing
                # is never evidence.
                reference_stream=None,
                variant_id=variant_id,
                card_contract=card_contract,
                artifact_source=artifact_source,
                set_file_expectation=(
                    dict(raw_set_expectation)
                    if isinstance(raw_set_expectation, dict)
                    else None
                ),
                manifest_risk_percent=sleeve.get("risk_percent"),
                expected_magic=expected_magic,
                expected_magic_source=expected_magic_source,
            )
        )
    identities = [job.key.upper() for job in jobs]
    if len(identities) != len(set(identities)):
        raise RequalError("book manifest contains duplicate promotion identities")
    expected = int(manifest.get("n_sleeves") or len(jobs))
    if len(jobs) != expected:
        raise RequalError(f"manifest sleeve count mismatch: expected={expected} resolved={len(jobs)}")
    return manifest, jobs


def _resolve_job_mapping_binding(
    job: Job,
    *,
    rows: Mapping[str, dict[str, Any]],
    cohort: Iterable[Job],
    label: str,
) -> tuple[str | None, dict[str, Any] | None]:
    """Resolve exact identity first and allow legacy keys only when unique."""

    normalized = {str(key).upper(): value for key, value in rows.items()}
    candidate_keys = [job.key.upper()]
    if job.variant_id is not None:
        candidate_keys.append(job.timeframe_key.upper())
    candidate_keys.append(job.legacy_key.upper())
    present = list(dict.fromkeys(key for key in candidate_keys if key in normalized))
    if len(present) > 1:
        raise RequalError(
            f"{label} mixes exact and legacy identities for {job.key}: {present}"
        )
    if not present:
        return None, None
    selected_key = present[0]
    materialized = list(cohort)
    if selected_key == job.legacy_key.upper():
        compatible = [
            item for item in materialized if item.legacy_key.upper() == selected_key
        ]
        if len(compatible) != 1:
            raise RequalError(
                f"{label} legacy EA/symbol identity is ambiguous for {job.legacy_key}"
            )
    elif job.variant_id is not None and selected_key == job.timeframe_key.upper():
        compatible = [
            item
            for item in materialized
            if item.timeframe_key.upper() == selected_key
        ]
        if len(compatible) != 1:
            raise RequalError(
                f"{label} variantless timeframe identity is ambiguous for "
                f"{job.timeframe_key}"
            )
    return selected_key, normalized[selected_key]


def bind_jobs_to_reference_snapshot(
    jobs: Iterable[Job],
    *,
    snapshot: dict[str, Any],
    snapshot_rows: dict[str, dict[str, Any]],
) -> list[Job]:
    """Resolve streams only through ``selected.frozen_relative_path``."""

    snapshot_text = snapshot.get("snapshot_root")
    snapshot_root = Path(snapshot_text).resolve() if snapshot_text else None
    materialized = list(jobs)
    bound: list[Job] = []
    for job in materialized:
        binding_key, row = _resolve_job_mapping_binding(
            job,
            rows=snapshot_rows,
            cohort=materialized,
            label="reference snapshot",
        )
        selected = row.get("selected") if isinstance(row, dict) else None
        relative_text = selected.get("frozen_relative_path") if isinstance(selected, dict) else None
        expected_sha = selected.get("frozen_sha256") if isinstance(selected, dict) else None
        stream: Path | None = None
        if snapshot_root is not None and isinstance(relative_text, str) and relative_text.strip():
            candidate = (snapshot_root / Path(relative_text.replace("/", os.sep))).resolve()
            if _is_relative_to(candidate, snapshot_root):
                stream = candidate
        bound.append(
            dataclasses.replace(
                job,
                reference_stream=stream,
                reference_binding_key=binding_key,
                reference_expected_sha256=str(expected_sha) if expected_sha else None,
                reference_frozen_relative_path=str(relative_text) if relative_text else None,
            )
        )
    return bound


def bind_jobs_to_execution_cost_contracts(
    jobs: Iterable[Job],
    *,
    contracts: Mapping[str, dict[str, Any]] | None,
) -> list[Job]:
    materialized = list(jobs)
    bound: list[Job] = []
    for job in materialized:
        _binding_key, contract = (
            _resolve_job_mapping_binding(
                job,
                rows=contracts,
                cohort=materialized,
                label="execution-cost manifest",
            )
            if contracts is not None
            else (None, None)
        )
        if contract is not None:
            expected_tf = contract.get("timeframe")
            if expected_tf is not None and str(expected_tf).upper() != job.timeframe.upper():
                raise RequalError(
                    f"execution-cost timeframe mismatch for {job.key}: "
                    f"expected={job.timeframe} actual={expected_tf}"
                )
            if (
                job.artifact_source == TARGET_ARTIFACT_SOURCE
                and contract.get("variant_id") != job.variant_id
            ):
                raise RequalError(
                    f"execution-cost variant mismatch for {job.key}: "
                    f"expected={job.variant_id} actual={contract.get('variant_id')}"
                )
        bound.append(dataclasses.replace(job, execution_cost_contract=contract))
    return bound


def _set_value_equal(expected: Any, actual: Any) -> bool:
    if actual is None:
        return False
    try:
        return Decimal(str(expected).strip()) == Decimal(str(actual).strip())
    except (InvalidOperation, ValueError):
        return str(expected).strip().casefold() == str(actual).strip().casefold()


def _parse_live_set_values(path: Path) -> tuple[dict[str, str], list[str]]:
    if not path.is_file():
        return {}, ["LIVE_PRESET_MISSING"]
    try:
        text = path.read_text(encoding="utf-8-sig", errors="strict")
    except UnicodeDecodeError:
        try:
            text = path.read_text(encoding="cp1252", errors="strict")
        except (OSError, UnicodeError) as exc:
            return {}, [f"LIVE_PRESET_READ_ERROR:{exc!r}"]
    except OSError as exc:
        return {}, [f"LIVE_PRESET_READ_ERROR:{exc!r}"]
    values: dict[str, str] = {}
    errors: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith(";"):
            header = re.fullmatch(r";\s*environment\s*:\s*(.+?)\s*", stripped, re.IGNORECASE)
            if header:
                if "ENV" in values:
                    errors.append(f"LIVE_PRESET_DUPLICATE_KEY:ENV:{line_number}")
                else:
                    values["ENV"] = header.group(1).strip()
            continue
        if "=" not in stripped:
            continue
        key, value = (part.strip() for part in stripped.split("=", 1))
        if not key:
            errors.append(f"LIVE_PRESET_EMPTY_KEY:{line_number}")
            continue
        if key in values:
            errors.append(f"LIVE_PRESET_DUPLICATE_KEY:{key}:{line_number}")
            continue
        values[key] = value
    return values, errors


def live_preset_contract(job: Job, path: Path | None = None) -> dict[str, Any]:
    """Compare the source-manifest SET contract with exact preset values.

    DXZ manifests carry absolute sleeve ``RISK_PERCENT``.  Applying a second
    ``PORTFOLIO_WEIGHT`` below one would silently square/downscale the intended
    risk, so the v2 qualification contract fixes that multiplier at exactly 1.
    """

    preset_path = (path or job.live_preset).resolve()
    actual, parse_errors = _parse_live_set_values(preset_path)
    expected = job.set_file_expectation
    blockers = list(parse_errors)
    required = {"ENV", "RISK_FIXED", "RISK_PERCENT", "PORTFOLIO_WEIGHT"}
    checks: list[dict[str, Any]] = []
    if not isinstance(expected, dict) or not expected:
        blockers.append("MANIFEST_SET_FILE_EXPECTATION_MISSING_OR_INVALID")
        expected_values: dict[str, Any] = {}
    else:
        expected_values = dict(expected)
        missing = required - set(expected_values)
        blockers.extend(
            f"MANIFEST_SET_FILE_EXPECTATION_REQUIRED_KEY_MISSING:{name}"
            for name in sorted(missing)
        )
        for name, expected_value in sorted(expected_values.items()):
            actual_value = actual.get(str(name))
            match = _set_value_equal(expected_value, actual_value)
            checks.append(
                {
                    "name": str(name),
                    "expected": expected_value,
                    "actual": actual_value,
                    "status": "MATCH" if match else "MISMATCH",
                }
            )
            if not match:
                blockers.append(f"LIVE_PRESET_VALUE_MISMATCH:{name}")
    try:
        risk_fixed = Decimal(str(expected_values.get("RISK_FIXED")).strip())
        risk_percent = Decimal(str(expected_values.get("RISK_PERCENT")).strip())
        portfolio_weight = Decimal(str(expected_values.get("PORTFOLIO_WEIGHT")).strip())
        manifest_risk = Decimal(str(job.manifest_risk_percent).strip())
    except (InvalidOperation, ValueError):
        blockers.append("MANIFEST_SET_FILE_RISK_CONTRACT_INVALID")
    else:
        if risk_fixed != 0 or risk_percent <= 0:
            blockers.append("MANIFEST_SET_FILE_RISK_CONTRACT_INVALID")
        if risk_percent != manifest_risk:
            blockers.append("MANIFEST_RISK_PERCENT_SET_EXPECTATION_MISMATCH")
        if portfolio_weight != 1:
            blockers.append("MANIFEST_SET_FILE_DOUBLE_SCALING_RISK")
    return {
        "status": "PASS" if not blockers else "FAIL",
        "preset_path": str(preset_path),
        "preset_sha256": sha256_file(preset_path) if preset_path.is_file() else None,
        "expected": expected_values,
        "actual": actual,
        "checks": checks,
        "blockers": sorted(set(blockers)),
        "risk_contract": {
            "mode": "ABSOLUTE_SLEEVE_RISK_PERCENT",
            "required_portfolio_weight": 1,
        },
    }


def verify_reference_snapshot(
    stream_root: Path | None,
    *,
    source_manifest_sha256: str,
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    metadata: dict[str, Any] = {
        "status": "MISSING",
        "stream_root": str(stream_root) if stream_root else None,
        "errors": [],
    }
    rows_by_key: dict[str, dict[str, Any]] = {}
    if stream_root is None:
        metadata["errors"].append("REFERENCE_STREAM_ROOT_MISSING")
        return metadata, rows_by_key
    root, canonical_stream_root = normalize_reference_stream_root(stream_root)
    manifest_path = root / "reference_stream_manifest.json"
    seal_path = root / "seal.sha256"
    metadata.update(
        {
            "snapshot_root": str(root),
            "canonical_stream_root": str(canonical_stream_root),
            "manifest_path": str(manifest_path),
            "seal_path": str(seal_path),
        }
    )
    if not manifest_path.is_file() or not seal_path.is_file():
        metadata["errors"].append("REFERENCE_SNAPSHOT_MANIFEST_OR_SEAL_MISSING")
        return metadata, rows_by_key
    try:
        payload = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        metadata["errors"].append(f"REFERENCE_SNAPSHOT_MANIFEST_INVALID:{exc!r}")
        return metadata, rows_by_key
    metadata.update(
        {
            "status": str(payload.get("status") or "UNKNOWN"),
            "manifest_sha256": sha256_file(manifest_path),
            "seal_sha256": sha256_file(seal_path),
            "source_manifest_sha256": (payload.get("source_manifest") or {}).get("sha256"),
        }
    )
    if str(payload.get("status") or "").upper() != "PASS":
        metadata["errors"].append("REFERENCE_SNAPSHOT_STATUS_NOT_PASS")
    if metadata["source_manifest_sha256"] != source_manifest_sha256:
        metadata["errors"].append("REFERENCE_SNAPSHOT_SOURCE_MANIFEST_MISMATCH")
    try:
        seal_lines = seal_path.read_text(encoding="utf-8", errors="strict").splitlines()
    except (OSError, UnicodeError) as exc:
        metadata["errors"].append(f"REFERENCE_SEAL_READ_ERROR:{exc!r}")
        return metadata, rows_by_key
    sealed_paths: set[str] = set()
    seal_entries = 0
    for line_number, raw in enumerate(seal_lines, start=1):
        if not raw.strip():
            continue
        match = re.fullmatch(r"([0-9a-fA-F]{64})\s{2}(.+)", raw)
        if not match:
            metadata["errors"].append(f"REFERENCE_SEAL_LINE_INVALID:{line_number}")
            continue
        expected_sha, relative_text = match.groups()
        normalized_relative = relative_text.replace("\\", "/")
        sealed_paths.add(normalized_relative.casefold())
        seal_entries += 1
        candidate = (root / Path(relative_text.replace("/", os.sep))).resolve()
        if not _is_relative_to(candidate, root) or not candidate.is_file():
            metadata["errors"].append(f"REFERENCE_SEAL_TARGET_INVALID:{relative_text}")
            continue
        if sha256_file(candidate).lower() != expected_sha.lower():
            metadata["errors"].append(f"REFERENCE_SEAL_HASH_MISMATCH:{relative_text}")
    for sleeve in payload.get("sleeves") or []:
        key = str(sleeve.get("key") or "").upper()
        if key:
            if key in rows_by_key:
                metadata["errors"].append(
                    f"REFERENCE_SNAPSHOT_DUPLICATE_SLEEVE_IDENTITY:{key}"
                )
            else:
                rows_by_key[key] = sleeve
        selected = sleeve.get("selected") if isinstance(sleeve, dict) else None
        selected_relative = (
            selected.get("frozen_relative_path") if isinstance(selected, dict) else None
        )
        if selected_relative and str(selected_relative).replace("\\", "/").casefold() not in sealed_paths:
            metadata["errors"].append(
                f"REFERENCE_SELECTED_STREAM_NOT_SEALED:{selected_relative}"
            )
    if seal_entries == 0:
        metadata["errors"].append("REFERENCE_SEAL_EMPTY")
    if "reference_stream_manifest.json" not in sealed_paths:
        metadata["errors"].append("REFERENCE_MANIFEST_NOT_SEALED")
    metadata["seal_verified"] = not metadata["errors"]
    metadata["seal_entries"] = seal_entries
    metadata["sleeves_declared"] = len(rows_by_key)
    metadata["canonical_identity_sha256"] = canonical_json_sha(
        {
            "snapshot_root": str(root),
            "manifest_sha256": metadata.get("manifest_sha256"),
            "seal_sha256": metadata.get("seal_sha256"),
            "source_manifest_sha256": metadata.get("source_manifest_sha256"),
            "seal_verified": metadata.get("seal_verified"),
            "errors": metadata.get("errors"),
        }
    )
    return metadata, rows_by_key


def reference_preflight_blockers(
    job: Job,
    *,
    snapshot: dict[str, Any],
    snapshot_rows: dict[str, dict[str, Any]],
    window_contract: Mapping[str, Any] | None = None,
    require_reference: bool = True,
) -> list[str]:
    blockers: list[str] = list(live_preset_contract(job)["blockers"])
    if not require_reference:
        if job.reference_stream is not None or job.reference_expected_sha256 is not None:
            blockers.append("UNREFERENCED_DISCOVERY_HAS_REFERENCE_BINDING")
        return blockers
    if snapshot.get("errors"):
        blockers.append("REFERENCE_SNAPSHOT_SEAL_INVALID")
    rows, errors = load_trade_rows_strict(job.reference_stream)
    if errors:
        blockers.append("REFERENCE_STREAM_MISSING_OR_INVALID")
        return blockers
    if job.manifest_trades is not None and len(rows) != job.manifest_trades:
        blockers.append("REFERENCE_MANIFEST_TRADE_COUNT_MISMATCH")
    snapshot_key = job.reference_binding_key or job.key
    snapshot_row = snapshot_rows.get(snapshot_key.upper())
    selected = snapshot_row.get("selected") if isinstance(snapshot_row, dict) else None
    expected_sha = job.reference_expected_sha256 or (
        selected.get("frozen_sha256") if isinstance(selected, dict) else None
    )
    selected_relative = (
        selected.get("frozen_relative_path") if isinstance(selected, dict) else None
    )
    snapshot_root_text = snapshot.get("snapshot_root")
    if selected_relative and snapshot_root_text and job.reference_stream is not None:
        expected_path = (
            Path(str(snapshot_root_text))
            / Path(str(selected_relative).replace("/", os.sep))
        ).resolve()
        if job.reference_stream.resolve() != expected_path:
            blockers.append("REFERENCE_STREAM_SELECTED_PATH_MISMATCH")
    elif not selected_relative:
        blockers.append("REFERENCE_SELECTED_FROZEN_PATH_MISSING")
    if not expected_sha or job.reference_stream is None:
        blockers.append("REFERENCE_STREAM_NOT_BOUND_IN_SNAPSHOT")
    elif sha256_file(job.reference_stream).lower() != str(expected_sha).lower():
        blockers.append("REFERENCE_STREAM_SNAPSHOT_HASH_MISMATCH")
    if window_contract is not None:
        effective_from = _parse_date(
            str(window_contract.get("effective_from_date")), label="effective-from"
        )
        effective_to = _parse_date(
            str(window_contract.get("effective_to_date")), label="effective-to"
        )
        lower = int(dt.datetime.combine(effective_from, dt.time.min, tzinfo=dt.UTC).timestamp())
        upper = int(dt.datetime.combine(effective_to, dt.time.max, tzinfo=dt.UTC).timestamp())
        if any((row_entry_time(row) or -1) < lower for row in rows):
            blockers.append("REFERENCE_ENTRY_BEFORE_EFFECTIVE_WINDOW")
        if any((row_time(row) or upper + 1) > upper for row in rows):
            blockers.append("REFERENCE_CLOSE_AFTER_EFFECTIVE_WINDOW")
    return blockers


def preflight_blocked_receipt(
    job: Job,
    blockers: list[str],
    *,
    qualification_mode: str = "AS_LIVE_REQUAL",
    window_contract: Mapping[str, Any] | None = None,
    runner_sha256: str | None = None,
    artifact_override_manifest: Mapping[str, Any] | None = None,
    execution_cost_evidence_manifest: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    preset_contract = live_preset_contract(job)
    preset_failure = bool(preset_contract["blockers"])
    receipt_blockers = list(blockers)
    try:
        expected_magic_source = verify_expected_magic_binding(
            job, required=qualification_mode == TARGET_BINARY_REQUAL
        )
    except RequalError:
        expected_magic_source = None
        receipt_blockers.append("EXPECTED_MAGIC_BINDING_INVALID")
    if qualification_mode == TARGET_BINARY_REQUAL and job.card_contract is None:
        receipt_blockers.append("CARD_CONTRACT_MISSING")
    try:
        card_contract = verify_card_contract_binding(
            job.card_contract, identity_label=job.key
        )
    except (RequalError, OSError, ValueError):
        card_contract = None
        receipt_blockers.append("CARD_CONTRACT_CHANGED_AFTER_PREFLIGHT")
    receipt: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "status": "BLOCKED",
        "technical_status": "FAIL" if preset_failure else "BLOCKED",
        "qualification_mode": qualification_mode,
        "qualification_status": (
            "NONQUALIFYING_DISCOVERY"
            if qualification_mode in DISCOVERY_MODES
            else "FAILED"
        ),
        "deployment_eligible": False,
        "window_contract": dict(window_contract or {}),
        "requested_from_date": (window_contract or {}).get("requested_from_date"),
        "requested_to_date": (window_contract or {}).get("requested_to_date"),
        "effective_from_date": (window_contract or {}).get("effective_from_date"),
        "effective_to_date": (window_contract or {}).get("effective_to_date"),
        "runner_sha256": runner_sha256,
        "artifact_override_manifest": (
            dict(artifact_override_manifest) if artifact_override_manifest else None
        ),
        "artifact_source": job.artifact_source,
        "card_contract": card_contract,
        "execution_cost_evidence_manifest": (
            dict(execution_cost_evidence_manifest)
            if execution_cost_evidence_manifest
            else None
        ),
        "blockers": sorted(set(receipt_blockers)),
        "job": {
            "ordinal": job.ordinal,
            "ea_id": job.ea_id,
            "symbol": job.symbol,
            "ea_label": job.ea_label,
            "timeframe": job.timeframe,
            "variant_id": job.variant_id,
            "manifest_trades": job.manifest_trades,
            "expected_magic": job.expected_magic,
            "expected_magic_source": expected_magic_source,
        },
        "execution": {"skipped": True, "reason": "REFERENCE_PREFLIGHT_BLOCKED"},
        "live_preset_contract": preset_contract,
        "identity": {
            "live_ex5_path": str(job.live_ex5),
            "live_ex5_sha256": sha256_file(job.live_ex5),
            "live_preset_path": str(job.live_preset),
            "live_preset_sha256": sha256_file(job.live_preset),
            "reference_stream_path": str(job.reference_stream) if job.reference_stream else None,
            "reference_stream_sha256": (
                sha256_file(job.reference_stream) if job.reference_stream else None
            ),
            "reference_frozen_relative_path": job.reference_frozen_relative_path,
            "expected_magic": job.expected_magic,
            "expected_magic_source": expected_magic_source,
        },
        "cost_evidence": {
            "status": "NOT_EVALUATED",
            "cost_certified": False,
            "reasons": ["MT5_EXECUTION_SKIPPED"],
            "registry_path": None,
            "registry_sha256": None,
            "unknown_symbols": [],
            "degraded_symbols": [],
        },
        "cost_certified": False,
    }
    receipt["receipt_sha256"] = canonical_json_sha(receipt)
    return receipt


def write_tester_ini(
    path: Path,
    *,
    job: Job,
    report_name: str,
    preset_name: str,
    from_date: str,
    to_date: str,
    currency: str,
    deposit: int,
) -> None:
    lines = [
        "[Tester]",
        f"Expert=QM\\{job.ea_label}",
        f"Symbol={job.symbol}",
        f"Period={job.timeframe}",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=0",
        f"FromDate={from_date}",
        f"ToDate={to_date}",
        "ForwardMode=0",
        f"Deposit={deposit}",
        f"Currency={currency}",
        "ProfitInPips=0",
        "Leverage=100",
        "UseLocal=1",
        "Visual=0",
        "Replace=1",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        f"Report={report_name}",
        f"ExpertParameters={preset_name}",
        "",
    ]
    path.write_text("\r\n".join(lines), encoding="ascii", newline="")


def _common_stream_path(common_root: Path, job: Job) -> Path:
    token = job.symbol.replace(".", "_")
    return common_root / "QM" / "q08_trades" / f"{job.ea_id}_{token}.jsonl"


def _capture_common_stream(
    common_path: Path,
    evidence_path: Path,
    before_bytes: bytes | None,
    backup_path: Path | None = None,
) -> dict[str, Any]:
    if not common_path.is_file():
        if backup_path is not None and backup_path.is_file():
            os.replace(backup_path, common_path)
        elif before_bytes is not None:
            temp = common_path.with_name(f".{common_path.name}.dxz_restore_{uuid.uuid4().hex}")
            temp.write_bytes(before_bytes)
            os.replace(temp, common_path)
        return {
            "captured": False,
            "fresh_created": False,
            "restored": True,
            "reason": "missing_after_pre_run_removal",
        }
    current_bytes = common_path.read_bytes()
    current_sha = hashlib.sha256(current_bytes).hexdigest()
    evidence_path.write_bytes(current_bytes)

    # Compare-and-swap: never restore across a concurrent writer.
    if not common_path.is_file() or sha256_file(common_path) != current_sha:
        return {
            "captured": True,
            "stream_sha256": current_sha,
            "restored": False,
            "reason": "concurrent_common_stream_writer_detected",
        }
    if backup_path is not None and backup_path.is_file():
        os.replace(backup_path, common_path)
    elif before_bytes is None:
        common_path.unlink()
    else:
        temp = common_path.with_name(f".{common_path.name}.dxz_restore_{uuid.uuid4().hex}")
        temp.write_bytes(before_bytes)
        os.replace(temp, common_path)
    return {
        "captured": True,
        "fresh_created": True,
        "stream_sha256": current_sha,
        "stream_bytes": len(current_bytes),
        "restored": True,
        "previous_sha256": (
            hashlib.sha256(before_bytes).hexdigest() if before_bytes is not None else None
        ),
    }


def _recover_common_transaction(
    common_root: Path,
    job: Job,
    run_dir: Path,
) -> dict[str, Any]:
    """Restore the isolated pre-run Common state after any runner exception."""
    transaction_path = run_dir / "common_stream_transaction.json"
    if not transaction_path.is_file():
        return {"transaction_started": False, "recovery_required": False}
    recovery: dict[str, Any] = {
        "transaction_started": True,
        "recovery_required": True,
        "recovered": False,
    }
    try:
        transaction = json.loads(transaction_path.read_text(encoding="utf-8"))
        common_path = _common_stream_path(common_root, job)
        previous_sha = transaction.get("previous_sha256")
        had_previous = bool(transaction.get("had_previous"))
        backup_text = transaction.get("backup_path")
        backup = Path(backup_text) if backup_text else None
        if (
            had_previous
            and backup is not None
            and not backup.exists()
            and common_path.is_file()
            and sha256_file(common_path) == previous_sha
        ):
            recovery.update(
                {"recovered": True, "method": "already_restored", "restored_sha256": previous_sha}
            )
        else:
            if common_path.is_file():
                uncaptured = run_dir / "q08_stream_uncaptured_on_error.jsonl"
                shutil.copy2(common_path, uncaptured)
                recovery["uncaptured_stream_sha256"] = sha256_file(uncaptured)
                common_path.unlink()
            if had_previous:
                if backup is None or not backup.is_file():
                    raise RequalError("pre-run Q08 backup missing during exception recovery")
                os.replace(backup, common_path)
                restored_sha = sha256_file(common_path)
                if restored_sha != previous_sha:
                    raise RequalError("recovered pre-run Q08 hash mismatch")
                recovery.update(
                    {"recovered": True, "method": "backup_restore", "restored_sha256": restored_sha}
                )
            else:
                if backup is not None and backup.is_file():
                    backup.unlink()
                recovery.update({"recovered": not common_path.exists(), "method": "restore_absence"})
        transaction["status"] = "RECOVERED_AFTER_ERROR"
        transaction["recovery"] = recovery
        transaction_path.write_text(
            json.dumps(transaction, indent=2, sort_keys=True), encoding="utf-8"
        )
    except Exception as exc:  # recovery evidence must survive the original exception
        recovery["error"] = repr(exc)
    return recovery


RUNTIME_LOG_EVENTS = {
    "ENTRY_ACCEPTED",
    "TM_CLOSE",
    "TM_PARTIAL_CLOSE",
    "EQUITY_SNAPSHOT",
}
RUNTIME_LOG_NAME_RE_TEMPLATE = r"^QM5_{ea_id}_.+\.log$"
RUNTIME_LOG_QUIESCENCE_INTERVAL_SECONDS = 0.05
RUNTIME_LOG_STABILITY_OBSERVATIONS = 3
RUNTIME_LOG_LATE_RESCANS = 3
RUNTIME_LOG_POST_RESTORE_STABLE_OBSERVATIONS = 3
RUNTIME_LOG_POST_RESTORE_MAX_SCANS = 6


def _runtime_log_roots(sandbox: Path) -> list[Path]:
    """Return only the tester/file roots owned by one portable sandbox."""

    root = sandbox.resolve()
    candidates = [
        root / "MQL5" / "Files" / "QM",
        root / "Tester" / "MQL5" / "Files" / "QM",
    ]
    tester = root / "Tester"
    if tester.is_dir():
        candidates.extend(
            path / "MQL5" / "Files" / "QM"
            for path in sorted(tester.glob("Agent-*"))
            if path.is_dir()
        )
    unique: dict[str, Path] = {}
    for path in candidates:
        resolved = path.resolve()
        if not _is_relative_to(resolved, root):
            raise RequalError(f"runtime log root escapes sandbox: {resolved}")
        unique[_path_identity(resolved)] = resolved
    return list(unique.values())


def _runtime_log_candidates(sandbox: Path, ea_id: int) -> list[Path]:
    pattern = re.compile(
        RUNTIME_LOG_NAME_RE_TEMPLATE.format(ea_id=int(ea_id)), re.IGNORECASE
    )
    found: dict[str, Path] = {}
    sandbox_root = sandbox.resolve()
    for root in _runtime_log_roots(sandbox_root):
        if not root.is_dir():
            continue
        for path in root.iterdir():
            if not path.is_file() or not pattern.fullmatch(path.name):
                continue
            resolved = path.resolve()
            if not _is_relative_to(resolved, sandbox_root):
                raise RequalError(f"runtime log candidate escapes sandbox: {resolved}")
            found[_path_identity(resolved)] = resolved
    return [found[key] for key in sorted(found)]


def _write_runtime_log_transaction(path: Path, payload: Mapping[str, Any]) -> None:
    temporary = path.with_name(f".{path.name}.tmp_{uuid.uuid4().hex}")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True), encoding="utf-8"
    )
    os.replace(temporary, path)


def _prepare_runtime_log_transaction(
    sandbox: Path,
    job: Job,
    run_dir: Path,
) -> dict[str, Any]:
    """Atomically park every matching pre-run log and persist recovery intent."""

    sandbox_root = sandbox.resolve()
    marker_path = run_dir / "runtime_log_transaction.json"
    originals = _runtime_log_candidates(sandbox_root, job.ea_id)
    transaction: dict[str, Any] = {
        "schema_version": 1,
        "status": "PREPARE_INTENT",
        "sandbox": str(sandbox_root),
        "ea_id": job.ea_id,
        "job_identity": job.key,
        "pattern": RUNTIME_LOG_NAME_RE_TEMPLATE.format(ea_id=job.ea_id),
        "prepared_epoch_ns": None,
        "pre_run_logs": [],
    }
    for original in originals:
        backup = original.with_name(
            f".{original.name}.dxz_pre_{uuid.uuid4().hex}"
        )
        transaction["pre_run_logs"].append(
            {
                "path": str(original),
                "backup_path": str(backup),
                "sha256": sha256_file(original),
                "size": original.stat().st_size,
                "moved": False,
            }
        )
    _write_runtime_log_transaction(marker_path, transaction)
    try:
        for row in transaction["pre_run_logs"]:
            original = Path(row["path"])
            backup = Path(row["backup_path"])
            os.replace(original, backup)
            row["moved"] = True
            _write_runtime_log_transaction(marker_path, transaction)
        leftovers = _runtime_log_candidates(sandbox_root, job.ea_id)
        if leftovers:
            raise RequalError(
                "runtime logs appeared while preparing isolated capture: "
                f"{[str(path) for path in leftovers]}"
            )
        transaction["prepared_epoch_ns"] = time.time_ns()
        transaction["status"] = "PREPARED"
        _write_runtime_log_transaction(marker_path, transaction)
        return transaction
    except BaseException:
        recovery = _restore_runtime_log_prestate(
            sandbox_root, job, run_dir, transaction=transaction, capture_new=True
        )
        transaction["status"] = (
            "PREPARE_FAILED_RESTORED"
            if recovery.get("restored")
            else "PREPARE_FAILED_RESTORE_FAILED"
        )
        transaction["recovery"] = recovery
        _write_runtime_log_transaction(marker_path, transaction)
        raise


def _restore_runtime_log_prestate(
    sandbox: Path,
    job: Job,
    run_dir: Path,
    *,
    transaction: Mapping[str, Any],
    capture_new: bool,
) -> dict[str, Any]:
    """Restore every parked file; preserve any post-run file inside ``run_dir``."""

    sandbox_root = sandbox.resolve()
    restore_errors: list[str] = []
    displaced: list[dict[str, Any]] = []
    evidence_dir = run_dir / "runtime_log_uncaptured_on_error"
    intact_prestate: set[str] = set()
    for raw in transaction.get("pre_run_logs", []):
        if not isinstance(raw, Mapping):
            continue
        original = Path(str(raw.get("path") or "")).resolve()
        backup = Path(str(raw.get("backup_path") or "")).resolve()
        expected_sha = str(raw.get("sha256") or "")
        if (
            _is_relative_to(original, sandbox_root)
            and _is_relative_to(backup, sandbox_root)
            and not backup.exists()
            and original.is_file()
            and sha256_file(original) == expected_sha
        ):
            intact_prestate.add(_path_identity(original))
    try:
        current = [
            path
            for path in _runtime_log_candidates(sandbox_root, job.ea_id)
            if _path_identity(path) not in intact_prestate
        ]
    except Exception as exc:
        current = []
        restore_errors.append(f"CANDIDATE_DISCOVERY_ERROR:{exc!r}")
    if current and capture_new:
        evidence_dir.mkdir(parents=True, exist_ok=True)
    for index, path in enumerate(current, start=1):
        try:
            target = evidence_dir / f"{index:03d}_{path.name}"
            os.replace(path, target)
            displaced.append(
                {
                    "source_path": str(path),
                    "evidence_path": str(target),
                    "sha256": sha256_file(target),
                    "size": target.stat().st_size,
                }
            )
        except Exception as exc:
            restore_errors.append(f"POST_RUN_LOG_PRESERVE_ERROR:{path}:{exc!r}")

    restore_bindings: list[dict[str, Any]] = []
    for raw in transaction.get("pre_run_logs", []):
        if not isinstance(raw, Mapping):
            restore_errors.append("INVALID_PRE_RUN_TRANSACTION_ROW")
            continue
        original = Path(str(raw.get("path") or "")).resolve()
        backup = Path(str(raw.get("backup_path") or "")).resolve()
        expected_sha = str(raw.get("sha256") or "")
        if not _is_relative_to(original, sandbox_root) or not _is_relative_to(
            backup, sandbox_root
        ):
            restore_errors.append(f"RESTORE_PATH_ESCAPES_SANDBOX:{original}")
            continue
        try:
            # A process can die after os.replace() and before the next marker
            # update.  Backup existence is therefore authoritative evidence
            # that the move happened even when the persisted flag is false.
            moved = raw.get("moved") is True or backup.is_file()
            if moved and backup.is_file():
                if original.exists():
                    raise RequalError(
                        f"runtime log restore target still occupied: {original}"
                    )
                temporary = original.with_name(
                    f".{original.name}.dxz_restore_{uuid.uuid4().hex}"
                )
                shutil.copy2(backup, temporary)
                os.replace(temporary, original)
            elif moved and not backup.is_file() and (
                not original.is_file() or sha256_file(original) != expected_sha
            ):
                raise RequalError(f"runtime log restore backup missing: {backup}")
            if not original.is_file() or sha256_file(original) != expected_sha:
                raise RequalError(f"runtime log restore hash mismatch: {original}")
            restore_bindings.append(
                {
                    "path": original,
                    "backup_path": backup,
                    "sha256": expected_sha,
                }
            )
        except Exception as exc:
            restore_errors.append(f"PRE_RUN_LOG_RESTORE_ERROR:{original}:{exc!r}")

    quiescence_incidents: list[str] = []
    stable_observations = 0
    quiescence_scans = 0
    expected_by_path = {
        _path_identity(row["path"]): row for row in restore_bindings
    }

    def preserve_post_restore(path: Path, *, reason: str) -> None:
        nonlocal displaced
        if not capture_new:
            restore_errors.append(f"{reason}:CAPTURE_DISABLED:{path}")
            return
        evidence_dir.mkdir(parents=True, exist_ok=True)
        target = evidence_dir / (
            f"{len(displaced) + 1:03d}_post_restore_{uuid.uuid4().hex}_{path.name}"
        )
        os.replace(path, target)
        displaced.append(
            {
                "source_path": str(path),
                "evidence_path": str(target),
                "sha256": sha256_file(target),
                "size": target.stat().st_size,
                "post_restore": True,
                "reason": reason,
            }
        )

    def restore_binding(binding: Mapping[str, Any]) -> None:
        original = Path(binding["path"])
        backup = Path(binding["backup_path"])
        if not backup.is_file():
            raise RequalError(f"post-restore backup missing: {backup}")
        temporary = original.with_name(
            f".{original.name}.dxz_restore_{uuid.uuid4().hex}"
        )
        shutil.copy2(backup, temporary)
        os.replace(temporary, original)

    for scan in range(1, RUNTIME_LOG_POST_RESTORE_MAX_SCANS + 1):
        quiescence_scans = scan
        time.sleep(RUNTIME_LOG_QUIESCENCE_INTERVAL_SECONDS)
        clean = True
        try:
            current = _runtime_log_candidates(sandbox_root, job.ea_id)
        except Exception as exc:
            restore_errors.append(f"POST_RESTORE_DISCOVERY_ERROR:{exc!r}")
            break
        current_by_path = {_path_identity(path): path for path in current}
        for path_key, path in list(current_by_path.items()):
            if path_key in expected_by_path:
                continue
            clean = False
            quiescence_incidents.append(f"UNEXPECTED_LOG:{path}")
            try:
                preserve_post_restore(
                    path, reason="POST_RESTORE_UNEXPECTED_RUNTIME_LOG"
                )
            except Exception as exc:
                restore_errors.append(
                    f"POST_RESTORE_LOG_PRESERVE_ERROR:{path}:{exc!r}"
                )
        for path_key, binding in expected_by_path.items():
            original = Path(binding["path"])
            expected_sha = str(binding["sha256"])
            actual = current_by_path.get(path_key)
            try:
                actual_sha = (
                    sha256_file(actual)
                    if actual is not None and actual.is_file()
                    else None
                )
            except OSError:
                actual_sha = None
            if actual_sha == expected_sha:
                continue
            clean = False
            quiescence_incidents.append(
                f"PRESTATE_CHANGED:{original}:actual={actual_sha}"
            )
            try:
                if actual is not None and actual.exists():
                    preserve_post_restore(
                        actual, reason="POST_RESTORE_PRESTATE_CHANGED"
                    )
                restore_binding(binding)
            except Exception as exc:
                restore_errors.append(
                    f"POST_RESTORE_PRESTATE_RECOVERY_ERROR:{original}:{exc!r}"
                )
        stable_observations = stable_observations + 1 if clean else 0
        if stable_observations >= RUNTIME_LOG_POST_RESTORE_STABLE_OBSERVATIONS:
            break

    quiescence_confirmed = (
        stable_observations >= RUNTIME_LOG_POST_RESTORE_STABLE_OBSERVATIONS
        and not restore_errors
    )
    if not quiescence_confirmed:
        restore_errors.append("POST_RESTORE_QUIESCENCE_NOT_CONFIRMED")

    restored_rows: list[dict[str, Any]] = []
    if quiescence_confirmed:
        for binding in restore_bindings:
            original = Path(binding["path"])
            expected_sha = str(binding["sha256"])
            try:
                final_matches = (
                    original.is_file() and sha256_file(original) == expected_sha
                )
            except OSError:
                final_matches = False
            if not final_matches:
                restore_errors.append(
                    f"POST_RESTORE_FINAL_HASH_MISMATCH:{original}"
                )
                continue
            restored_rows.append(
                {"path": str(original), "sha256": expected_sha, "verified": True}
            )
        if not restore_errors:
            for binding in restore_bindings:
                backup = Path(binding["backup_path"])
                if not backup.is_file():
                    continue
                try:
                    backup.unlink()
                except OSError as exc:
                    restore_errors.append(
                        f"PRE_RUN_BACKUP_CLEANUP_ERROR:{backup}:{exc!r}"
                    )
    return {
        "restored": quiescence_confirmed and not restore_errors,
        "restore_errors": restore_errors,
        "restored_pre_run_logs": restored_rows,
        "preserved_post_run_logs": displaced,
        "quiescence_confirmed": quiescence_confirmed and not restore_errors,
        "quiescence_incidents": quiescence_incidents,
        "stable_observations": stable_observations,
        "quiescence_scans": quiescence_scans,
        "residual_concurrency_risk": (
            "FINITE_QUIESCENCE_WINDOW_CANNOT_PREVENT_A_NON_RUN_UNIQUE_LOG_WRITER_"
            "FROM_REOPENING_AFTER_RETURN"
        ),
    }


def _capture_runtime_log_transaction(
    sandbox: Path,
    job: Job,
    run_dir: Path,
    transaction: dict[str, Any],
) -> dict[str, Any]:
    """Capture exactly one fresh log, then restore the complete pre-run state."""

    boundary = transaction.get("prepared_epoch_ns")
    capture: dict[str, Any] = {
        "status": "FAIL",
        "captured": False,
        "fresh": False,
        "ambiguous": False,
        "restored": False,
        "blockers": [],
        "candidates": [],
        "preserved_post_run_logs": [],
    }
    candidates: list[Path] = []
    staging = run_dir / "runtime_log_candidates"
    try:
        if not isinstance(boundary, int) or boundary <= 0:
            raise RequalError("runtime log transaction has no valid freshness boundary")
        candidates = _runtime_log_candidates(sandbox, job.ea_id)
        if candidates:
            staging.mkdir(parents=True, exist_ok=True)
        for index, source in enumerate(candidates, start=1):
            stat = source.stat()
            evidence = staging / f"{index:03d}_{source.name}"
            os.replace(source, evidence)
            first_sha = sha256_file(evidence)
            first_size = evidence.stat().st_size
            stable = True
            stability_observations = 0
            for _observation in range(RUNTIME_LOG_STABILITY_OBSERVATIONS):
                time.sleep(RUNTIME_LOG_QUIESCENCE_INTERVAL_SECONDS)
                unchanged = (
                    evidence.is_file()
                    and evidence.stat().st_size == first_size
                    and sha256_file(evidence) == first_sha
                )
                stability_observations += int(unchanged)
                if not unchanged:
                    stable = False
            row = {
                "source_path": str(source),
                "evidence_path": str(evidence),
                "sha256": first_sha,
                "size": evidence.stat().st_size,
                "mtime_ns": stat.st_mtime_ns,
                "fresh": stat.st_mtime_ns >= boundary and stat.st_size > 0,
                "stable": stable,
                "stability_observations": stability_observations,
                "required_stability_observations": RUNTIME_LOG_STABILITY_OBSERVATIONS,
            }
            capture["candidates"].append(row)
            capture["preserved_post_run_logs"].append(dict(row))
            if not stable:
                capture["blockers"].append("RUNTIME_LOG_NOT_STABLE")
        late_detected = False
        next_index = len(candidates) + 1
        for rescan in range(1, RUNTIME_LOG_LATE_RESCANS + 1):
            time.sleep(RUNTIME_LOG_QUIESCENCE_INTERVAL_SECONDS)
            late = _runtime_log_candidates(sandbox, job.ea_id)
            if late:
                staging.mkdir(parents=True, exist_ok=True)
                late_detected = True
            for source in late:
                evidence = staging / f"{next_index:03d}_late_{source.name}"
                next_index += 1
                os.replace(source, evidence)
                late_row = {
                    "source_path": str(source),
                    "evidence_path": str(evidence),
                    "sha256": sha256_file(evidence),
                    "size": evidence.stat().st_size,
                    "mtime_ns": evidence.stat().st_mtime_ns,
                    "fresh": True,
                    "stable": False,
                    "late_writer": True,
                    "late_rescan": rescan,
                }
                capture["candidates"].append(late_row)
                capture["preserved_post_run_logs"].append(dict(late_row))
        capture["late_rescans"] = RUNTIME_LOG_LATE_RESCANS
        if late_detected:
            capture["ambiguous"] = True
            capture["blockers"].append("RUNTIME_LOG_LATE_WRITER_DETECTED")
        fresh = [row for row in capture["candidates"] if row["fresh"]]
        if not capture["candidates"]:
            capture["blockers"].append("RUNTIME_LOG_MISSING")
        elif len(capture["candidates"]) != 1:
            capture["ambiguous"] = True
            capture["blockers"].append("RUNTIME_LOG_MULTIPLE_CANDIDATES")
        elif not fresh:
            capture["blockers"].append("RUNTIME_LOG_STALE")
        else:
            selected = fresh[0]
            selected_evidence = Path(selected["evidence_path"])
            canonical = run_dir / "runtime_log.jsonl"
            shutil.copy2(selected_evidence, canonical)
            copied_sha = sha256_file(canonical)
            if copied_sha != selected["sha256"] or selected.get("stable") is not True:
                capture["blockers"].append("RUNTIME_LOG_COPY_HASH_MISMATCH")
            else:
                capture.update(
                    {
                        "captured": True,
                        "fresh": True,
                        "evidence_path": str(canonical),
                        "source_path": selected["source_path"],
                        "sha256": copied_sha,
                        "size": canonical.stat().st_size,
                    }
                )
    except Exception as exc:
        capture["blockers"].append(f"RUNTIME_LOG_CAPTURE_ERROR:{exc!r}")
    finally:
        recovery = _restore_runtime_log_prestate(
            sandbox, job, run_dir, transaction=transaction, capture_new=True
        )
        capture["restored"] = recovery["restored"]
        capture["restore_errors"] = recovery["restore_errors"]
        capture["restored_pre_run_logs"] = recovery["restored_pre_run_logs"]
        if recovery.get("preserved_post_run_logs"):
            capture["preserved_post_run_logs"].extend(
                recovery["preserved_post_run_logs"]
            )
            capture["ambiguous"] = True
            capture["blockers"].append("RUNTIME_LOG_LATE_WRITER_DETECTED")
        if not recovery["restored"]:
            capture["blockers"].append("RUNTIME_LOG_PRESTATE_RESTORE_FAILED")
        if recovery.get("quiescence_incidents"):
            capture["ambiguous"] = True
            capture["blockers"].append("RUNTIME_LOG_POST_RESTORE_WRITER_DETECTED")
        capture["post_restore_quiescence"] = {
            "confirmed": recovery.get("quiescence_confirmed") is True,
            "stable_observations": recovery.get("stable_observations", 0),
            "required_stable_observations": (
                RUNTIME_LOG_POST_RESTORE_STABLE_OBSERVATIONS
            ),
            "scans": recovery.get("quiescence_scans", 0),
            "incidents": recovery.get("quiescence_incidents", []),
        }
    capture["blockers"] = sorted(set(capture["blockers"]))
    if capture["captured"] and capture["fresh"] and capture["restored"] and not capture[
        "blockers"
    ]:
        capture["status"] = "PASS"
    transaction["status"] = (
        "CAPTURED_AND_RESTORED"
        if capture["status"] == "PASS"
        else "CAPTURE_FAILED_RESTORED"
        if capture["restored"]
        else "CAPTURE_AND_RESTORE_FAILED"
    )
    transaction["completed_utc"] = dt.datetime.now(dt.UTC).isoformat()
    transaction["capture"] = capture
    capture["residual_concurrency_risk"] = (
        "FINITE_QUIESCENCE_WINDOW_CANNOT_PREVENT_A_NON_RUN_UNIQUE_LOG_WRITER_"
        "FROM_REOPENING_AFTER_TRANSACTION_COMPLETION"
    )
    _write_runtime_log_transaction(run_dir / "runtime_log_transaction.json", transaction)
    return capture


def _recover_runtime_log_transaction(
    sandbox: Path,
    job: Job,
    run_dir: Path,
) -> dict[str, Any]:
    marker = run_dir / "runtime_log_transaction.json"
    if not marker.is_file():
        return {"transaction_started": False, "recovery_required": False}
    try:
        transaction = json.loads(marker.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        return {
            "transaction_started": True,
            "recovery_required": True,
            "recovered": False,
            "error": f"TRANSACTION_READ_ERROR:{exc!r}",
        }
    if transaction.get("status") in {
        "CAPTURED_AND_RESTORED",
        "CAPTURE_FAILED_RESTORED",
        "PREPARE_FAILED_RESTORED",
    }:
        return {
            "transaction_started": True,
            "recovery_required": False,
            "recovered": True,
            "method": "already_restored",
        }
    recovery = _restore_runtime_log_prestate(
        sandbox, job, run_dir, transaction=transaction, capture_new=True
    )
    transaction["status"] = (
        "RECOVERED_AFTER_ERROR"
        if recovery["restored"]
        else "RECOVERY_FAILED_AFTER_ERROR"
    )
    transaction["recovery"] = recovery
    _write_runtime_log_transaction(marker, transaction)
    return {
        "transaction_started": True,
        "recovery_required": True,
        "recovered": recovery["restored"],
        **recovery,
    }


def _runtime_log_timestamp(value: Any) -> int | None:
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip().replace("Z", "+00:00")
    try:
        stamp = dt.datetime.fromisoformat(text)
    except ValueError:
        return None
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=dt.UTC)
    return int(stamp.timestamp())


def _runtime_sequence_descriptor(
    sequence: list[list[Any]],
    *,
    complete: bool,
    basis: str,
    reasons: Iterable[str] = (),
) -> dict[str, Any]:
    return {
        "complete": bool(complete),
        "count": len(sequence),
        "sha256": canonical_json_sha(sequence),
        "basis": basis,
        "reasons": sorted(set(str(reason) for reason in reasons)),
        "sequence": sequence,
    }


def _strict_runtime_json(line: str) -> Any:
    def reject_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON constant: {value}")

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(
        line,
        object_pairs_hook=unique_object,
        parse_constant=reject_constant,
    )


def _strict_runtime_decimal(value: Any) -> str | None:
    if isinstance(value, bool) or not isinstance(value, (int, float, Decimal)):
        return None
    return _canonical_decimal_text(value)


def parse_runtime_log_strict(path: Path | None, job: Job) -> dict[str, Any]:
    """Parse the framework JSONL log and bind every row to one exact job."""

    errors: list[str] = []
    expected_magic = job.expected_magic
    expected_magic_valid = type(expected_magic) is int and expected_magic > 0
    if expected_magic is not None and not expected_magic_valid:
        errors.append("AUTHORITATIVE_EXPECTED_MAGIC_INVALID")
    entries: list[list[Any]] = []
    exits: list[list[Any]] = []
    equity: list[list[Any]] = []
    observed_magics: set[int] = set()
    relevant_timestamps: list[int] = []
    init_count = 0
    init_ok_count = 0
    line_count = 0
    if path is None or not path.is_file():
        errors.append("RUNTIME_LOG_MISSING")
        lines: list[str] = []
    else:
        try:
            lines = path.read_text(encoding="utf-8", errors="strict").splitlines()
        except (OSError, UnicodeError) as exc:
            lines = []
            errors.append(f"RUNTIME_LOG_READ_ERROR:{exc!r}")

    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        line_count += 1
        try:
            raw = _strict_runtime_json(line)
        except (json.JSONDecodeError, ValueError) as exc:
            errors.append(f"line {line_number}: invalid JSON ({exc})")
            continue
        if not isinstance(raw, dict):
            errors.append(f"line {line_number}: JSON value is not an object")
            continue
        event = raw.get("event")
        raw_ea = raw.get("ea_id")
        row_ea = raw_ea if type(raw_ea) is int else None
        row_symbol = str(raw.get("symbol") or "").strip().upper()
        row_timeframe = str(raw.get("tf") or "").strip().upper()
        raw_magic = raw.get("magic")
        row_magic = raw_magic if type(raw_magic) is int else None
        if row_ea != job.ea_id:
            errors.append(f"line {line_number}: EA_IDENTITY_MISMATCH")
        if row_symbol != job.symbol.upper():
            errors.append(f"line {line_number}: SYMBOL_IDENTITY_MISMATCH")
        if row_timeframe != job.timeframe.upper():
            errors.append(f"line {line_number}: TIMEFRAME_IDENTITY_MISMATCH")
        if row_magic is None or row_magic <= 0:
            errors.append(f"line {line_number}: MAGIC_INVALID")
        else:
            observed_magics.add(row_magic)
        if expected_magic_valid and row_magic != expected_magic:
            errors.append(f"line {line_number}: EXPECTED_MAGIC_HEADER_MISMATCH")
        raw_payload = raw.get("payload")
        if (
            expected_magic_valid
            and isinstance(raw_payload, dict)
            and "magic" in raw_payload
            and (
                type(raw_payload.get("magic")) is not int
                or raw_payload.get("magic") != expected_magic
            )
        ):
            errors.append(f"line {line_number}: EXPECTED_MAGIC_PAYLOAD_MISMATCH")
        if event == "INIT":
            init_count += 1
            payload = raw.get("payload")
            if not isinstance(payload, dict):
                errors.append(f"line {line_number}: INIT_PAYLOAD_INVALID")
            else:
                if "magic" in payload and (
                    type(payload.get("magic")) is not int
                    or payload.get("magic") != row_magic
                ):
                    errors.append(f"line {line_number}: INIT_MAGIC_MISMATCH")
                if "symbol" in payload and (
                    str(payload.get("symbol") or "").strip().upper()
                    != job.symbol.upper()
                ):
                    errors.append(f"line {line_number}: INIT_SYMBOL_MISMATCH")
        elif event == "INIT_OK":
            init_ok_count += 1
        if event not in RUNTIME_LOG_EVENTS:
            continue
        payload = raw.get("payload")
        if not isinstance(payload, dict):
            errors.append(f"line {line_number}: EVENT_PAYLOAD_INVALID:{event}")
            continue
        stamp = _runtime_log_timestamp(raw.get("ts_broker"))
        if stamp is None:
            errors.append(f"line {line_number}: BROKER_TIMESTAMP_INVALID:{event}")
            continue
        relevant_timestamps.append(stamp)
        payload_symbol = str(payload.get("symbol") or "").strip().upper()
        if payload_symbol != job.symbol.upper():
            errors.append(f"line {line_number}: PAYLOAD_SYMBOL_MISMATCH:{event}")
        if event == "ENTRY_ACCEPTED":
            raw_payload_magic = payload.get("magic")
            raw_ticket = payload.get("ticket")
            payload_magic = (
                raw_payload_magic if type(raw_payload_magic) is int else None
            )
            ticket = raw_ticket if type(raw_ticket) is int else 0
            side = {
                "QM_BUY": "BUY",
                "BUY": "BUY",
                "QM_SELL": "SELL",
                "SELL": "SELL",
            }.get(str(payload.get("type") or "").strip().upper())
            lots = _strict_runtime_decimal(payload.get("lots"))
            price = _strict_runtime_decimal(payload.get("price"))
            reason = str(payload.get("reason") or "").strip()
            invalid = []
            if payload_magic != row_magic:
                invalid.append("PAYLOAD_MAGIC_MISMATCH")
            if ticket <= 0:
                invalid.append("TICKET_INVALID")
            if side is None:
                invalid.append("SIDE_INVALID")
            if lots is None or Decimal(lots) <= 0:
                invalid.append("VOLUME_INVALID")
            if price is None or Decimal(price) <= 0:
                invalid.append("PRICE_INVALID")
            if not reason:
                invalid.append("ENTRY_REASON_MISSING")
            if invalid:
                errors.extend(
                    f"line {line_number}: {item}:ENTRY_ACCEPTED" for item in invalid
                )
            else:
                entries.append(
                    [
                        stamp,
                        job.symbol.upper(),
                        lots,
                        side,
                        price,
                        ticket,
                        reason,
                        row_magic,
                    ]
                )
        elif event in {"TM_CLOSE", "TM_PARTIAL_CLOSE"}:
            raw_ticket = payload.get("ticket")
            ticket = raw_ticket if type(raw_ticket) is int else 0
            lots = _strict_runtime_decimal(payload.get("lots"))
            reason = str(payload.get("reason") or "").strip()
            expected_partial = event == "TM_PARTIAL_CLOSE"
            invalid = []
            if ticket <= 0:
                invalid.append("TICKET_INVALID")
            if lots is None or Decimal(lots) <= 0:
                invalid.append("VOLUME_INVALID")
            if not reason:
                invalid.append("EXIT_REASON_MISSING")
            if payload.get("ok") is not True:
                invalid.append("EXIT_NOT_ACCEPTED")
            if payload.get("partial") is not expected_partial:
                invalid.append("PARTIAL_FLAG_MISMATCH")
            if invalid:
                errors.extend(f"line {line_number}: {item}:{event}" for item in invalid)
            else:
                exits.append(
                    [
                        stamp,
                        job.symbol.upper(),
                        lots,
                        reason,
                        ticket,
                        event,
                        row_magic,
                    ]
                )
        else:
            raw_day_key = payload.get("day_key")
            raw_month_key = payload.get("month_key")
            day_key = raw_day_key if type(raw_day_key) is int else 0
            month_key = raw_month_key if type(raw_month_key) is int else 0
            equity_value = _strict_runtime_decimal(payload.get("equity"))
            day_pnl = _strict_runtime_decimal(payload.get("day_pnl"))
            month_pnl = _strict_runtime_decimal(payload.get("month_pnl"))
            atr_regime = str(payload.get("atr_regime") or "").strip()
            invalid = []
            try:
                day_date = dt.datetime.strptime(str(day_key), "%Y%m%d").date()
            except ValueError:
                day_date = None
            if not re.fullmatch(r"\d{8}", str(day_key)):
                invalid.append("DAY_KEY_INVALID")
            if not re.fullmatch(r"\d{6}", str(month_key)):
                invalid.append("MONTH_KEY_INVALID")
            if day_date is None:
                invalid.append("DAY_KEY_NOT_CALENDAR_DATE")
            if day_date is not None and month_key != day_date.year * 100 + day_date.month:
                invalid.append("MONTH_DAY_KEY_MISMATCH")
            if equity_value is None or Decimal(equity_value) <= 0:
                invalid.append("EQUITY_INVALID")
            if day_pnl is None:
                invalid.append("DAY_PNL_INVALID")
            if month_pnl is None:
                invalid.append("MONTH_PNL_INVALID")
            if not atr_regime:
                invalid.append("ATR_REGIME_MISSING")
            if invalid:
                errors.extend(
                    f"line {line_number}: {item}:EQUITY_SNAPSHOT" for item in invalid
                )
            else:
                equity.append(
                    [
                        stamp,
                        day_key,
                        job.symbol.upper(),
                        equity_value,
                        day_pnl,
                        month_pnl,
                        atr_regime,
                        row_magic,
                    ]
                )

    if line_count == 0 and "RUNTIME_LOG_MISSING" not in errors:
        errors.append("RUNTIME_LOG_EMPTY")
    if init_count != 1:
        errors.append(f"RUNTIME_LOG_INIT_COUNT_INVALID:{init_count}")
    if init_ok_count != 1:
        errors.append(f"RUNTIME_LOG_INIT_OK_COUNT_INVALID:{init_ok_count}")
    if len(observed_magics) != 1:
        errors.append("RUNTIME_LOG_MAGIC_IDENTITY_NOT_UNIQUE")
    if any(
        later < earlier
        for earlier, later in zip(relevant_timestamps, relevant_timestamps[1:])
    ):
        errors.append("RUNTIME_LOG_EVENT_TIME_NOT_MONOTONIC_APPEND_CONTAMINATION")
    equity_day_keys = [row[1] for row in equity]
    if len(equity_day_keys) != len(set(equity_day_keys)):
        errors.append("EQUITY_SNAPSHOT_DAY_KEY_DUPLICATE")
    if any(
        later <= earlier
        for earlier, later in zip(equity_day_keys, equity_day_keys[1:])
    ):
        errors.append("EQUITY_SNAPSHOT_DAY_KEY_NOT_STRICTLY_INCREASING")
    if not equity:
        errors.append("EQUITY_SNAPSHOT_SEQUENCE_EMPTY")
    common_complete = not errors
    observed_magic = next(iter(observed_magics)) if len(observed_magics) == 1 else None
    return {
        "schema_version": 1,
        "status": "PASS" if common_complete else "FAIL",
        "errors": sorted(set(errors)),
        "line_count": line_count,
        "relevant_event_count": len(entries) + len(exits) + len(equity),
        "identity": {
            "ea_id": job.ea_id,
            "symbol": job.symbol.upper(),
            "timeframe": job.timeframe.upper(),
            "magic": observed_magic,
            "magic_unique": len(observed_magics) == 1,
            "expected_magic": expected_magic,
            "expected_magic_valid": expected_magic_valid,
            "expected_magic_source": (
                dict(job.expected_magic_source) if job.expected_magic_source else None
            ),
            "observed_magic_matches_expected": (
                observed_magic == expected_magic if expected_magic_valid else None
            ),
        },
        "entries": _runtime_sequence_descriptor(
            entries,
            complete=common_complete,
            basis=(
                "framework_ENTRY_ACCEPTED_broker_time_symbol_volume_side_"
                "requested_price_not_fill_price"
            ),
            reasons=errors,
        ),
        "exits": _runtime_sequence_descriptor(
            exits,
            complete=common_complete,
            basis="framework_TM_CLOSE_broker_time_symbol_volume_reason",
            reasons=errors,
        ),
        "equity": _runtime_sequence_descriptor(
            equity,
            complete=False,
            basis="framework_EQUITY_SNAPSHOT_partial_observation_sequence",
            reasons=[
                *errors,
                "INITIAL_AND_FINAL_EQUITY_BOUNDARY_SNAPSHOTS_NOT_EMITTED",
            ],
        ),
    }


def bind_runtime_telemetry_to_q08(
    rows: Iterable[dict[str, Any]],
    telemetry: Mapping[str, Any] | None,
    *,
    expected_magic: int | None = None,
) -> dict[str, Any]:
    """Require bijective time+symbol+volume joins for entry and exit evidence."""

    materialized = [dict(row) for row in rows]
    blockers: list[str] = []
    expected_magic_valid = type(expected_magic) is int and expected_magic > 0
    if not isinstance(telemetry, Mapping) or telemetry.get("status") != "PASS":
        blockers.append("RUNTIME_TELEMETRY_INVALID")
        return {
            "status": "FAIL",
            "integrity_status": "FAIL",
            "blockers": blockers,
            "entries_complete": False,
            "exits_complete": False,
            "enriched_rows": materialized,
            "magic_bound": False,
            "authoritative_expected_magic_bound": False,
            "expected_magic": expected_magic,
            "expected_magic_valid": expected_magic_valid,
        }
    entry_sequence = telemetry.get("entries", {}).get("sequence", [])
    exit_sequence = telemetry.get("exits", {}).get("sequence", [])
    observed_magic = telemetry.get("identity", {}).get("magic")
    q08_magics: list[int] = []
    row_entry_keys: list[tuple[int | None, str, str | None]] = []
    row_exit_keys: list[tuple[int | None, str, str | None]] = []
    for index, row in enumerate(materialized):
        symbol = str(row.get("symbol") or "").strip().upper()
        volume = _canonical_decimal_text(row.get("volume"))
        if volume is None or Decimal(volume) <= 0:
            blockers.append(f"Q08_VOLUME_INVALID_AT_ROW:{index}")
            volume = None
        raw_magic = row.get("magic")
        magic = raw_magic if type(raw_magic) is int else 0
        if magic <= 0:
            blockers.append(f"Q08_MAGIC_INVALID_AT_ROW:{index}")
        else:
            q08_magics.append(magic)
        row_entry_keys.append((row_entry_time(row), symbol, volume))
        row_exit_keys.append((row_time(row), symbol, volume))

    magic_cross_stream_consistent = (
        bool(materialized)
        and len(q08_magics) == len(materialized)
        and len(set(q08_magics)) == 1
        and q08_magics[0] == observed_magic
    )
    if not magic_cross_stream_consistent:
        blockers.append("Q08_RUNTIME_MAGIC_IDENTITY_MISMATCH")
    runtime_matches_expected = (
        observed_magic == expected_magic if expected_magic_valid else False
    )
    q08_matches_expected = (
        bool(materialized)
        and len(q08_magics) == len(materialized)
        and all(magic == expected_magic for magic in q08_magics)
        if expected_magic_valid
        else False
    )
    authoritative_expected_magic_bound = (
        expected_magic_valid
        and runtime_matches_expected
        and q08_matches_expected
        and magic_cross_stream_consistent
    )
    if expected_magic is None:
        blockers.append("AUTHORITATIVE_EXPECTED_MAGIC_NOT_HASH_BOUND")
    elif not expected_magic_valid:
        blockers.append("AUTHORITATIVE_EXPECTED_MAGIC_INVALID")
    else:
        if not runtime_matches_expected:
            blockers.append("RUNTIME_EXPECTED_MAGIC_IDENTITY_MISMATCH")
        if not q08_matches_expected:
            blockers.append("Q08_EXPECTED_MAGIC_IDENTITY_MISMATCH")

    log_entry_keys = [(row[0], row[1], row[2]) for row in entry_sequence]
    log_exit_keys = [(row[0], row[1], row[2]) for row in exit_sequence]

    def unique_bijection(
        q08_keys: list[tuple[int | None, str, str | None]],
        log_keys: list[tuple[int | None, str, str | None]],
        label: str,
    ) -> bool:
        q08_counts = collections.Counter(q08_keys)
        log_counts = collections.Counter(log_keys)
        complete = (
            bool(q08_keys)
            and len(q08_keys) == len(log_keys)
            and all(key[0] is not None and key[1] and key[2] is not None for key in q08_keys)
            and all(count == 1 for count in q08_counts.values())
            and all(count == 1 for count in log_counts.values())
            and q08_counts == log_counts
        )
        if not complete:
            blockers.append(f"Q08_RUNTIME_{label}_JOIN_NOT_UNIQUE_BIJECTION")
        return complete

    entry_join_complete = unique_bijection(row_entry_keys, log_entry_keys, "ENTRY")
    exit_join_complete = unique_bijection(row_exit_keys, log_exit_keys, "EXIT")
    joins_complete = entry_join_complete and exit_join_complete
    # ENTRY_ACCEPTED logs the request price (trade_req.price), not the broker's
    # actual fill (trade_res.price).  A perfect event join can bind side and the
    # requested price, but must never close the exact-entry-price pair axis.
    blockers.append("ENTRY_FILL_PRICE_NOT_EMITTED")
    entry_axis_reasons = ["ENTRY_FILL_PRICE_NOT_EMITTED"]
    if not entry_join_complete:
        entry_axis_reasons.append("Q08_RUNTIME_ENTRY_JOIN_NOT_UNIQUE_BIJECTION")
    exit_axis_reasons: list[str] = []
    if not authoritative_expected_magic_bound:
        exit_axis_reasons.append(
            "AUTHORITATIVE_EXPECTED_MAGIC_NOT_HASH_BOUND"
            if expected_magic is None
            else "AUTHORITATIVE_EXPECTED_MAGIC_IDENTITY_MISMATCH"
        )
    if not exit_join_complete:
        exit_axis_reasons.append("Q08_RUNTIME_EXIT_JOIN_NOT_UNIQUE_BIJECTION")
    entry_by_key = {
        (row[0], row[1], row[2]): row for row in entry_sequence
    } if entry_join_complete else {}
    exit_by_key = {
        (row[0], row[1], row[2]): row for row in exit_sequence
    } if exit_join_complete else {}
    enriched: list[dict[str, Any]] = []
    for row, entry_key, exit_key in zip(
        materialized, row_entry_keys, row_exit_keys
    ):
        current = dict(row)
        if entry_join_complete:
            event = entry_by_key[entry_key]
            current["side"] = event[3]
            current["requested_entry_price"] = event[4]
        if exit_join_complete:
            current["exit_reason"] = exit_by_key[exit_key][3]
        enriched.append(current)
    return {
        "status": (
            "INCOMPLETE"
            if magic_cross_stream_consistent
            and joins_complete
            and (expected_magic is None or authoritative_expected_magic_bound)
            else "FAIL"
        ),
        "integrity_status": (
            "PASS"
            if magic_cross_stream_consistent
            and (expected_magic is None or authoritative_expected_magic_bound)
            else "FAIL"
        ),
        "blockers": sorted(set(blockers)),
        "entries_complete": False,
        "entry_join_complete": entry_join_complete,
        "exits_complete": (
            exit_join_complete and authoritative_expected_magic_bound
        ),
        "exit_join_complete": exit_join_complete,
        "entry_axis_reasons": entry_axis_reasons,
        "exit_axis_reasons": exit_axis_reasons,
        "enriched_rows": enriched,
        "magic_bound": authoritative_expected_magic_bound,
        "authoritative_expected_magic_bound": authoritative_expected_magic_bound,
        "expected_magic": expected_magic,
        "expected_magic_valid": expected_magic_valid,
        "runtime_magic_matches_expected": runtime_matches_expected,
        "q08_magic_matches_expected": q08_matches_expected,
        "magic_cross_stream_consistent": magic_cross_stream_consistent,
        "observed_magic": observed_magic,
        "entry_join_basis": (
            "exact_broker_time_symbol_canonical_volume_bijection; "
            "price_is_request_not_fill"
        ),
        "exit_join_basis": "exact_broker_time_symbol_canonical_volume_bijection",
    }


TARGET_RUNTIME_Q08_BINDING_FIELDS = {
    "status",
    "integrity_status",
    "blockers",
    "entries_complete",
    "entry_join_complete",
    "exits_complete",
    "exit_join_complete",
    "entry_axis_reasons",
    "exit_axis_reasons",
    "enriched_rows",
    "magic_bound",
    "authoritative_expected_magic_bound",
    "expected_magic",
    "expected_magic_valid",
    "runtime_magic_matches_expected",
    "q08_magic_matches_expected",
    "magic_cross_stream_consistent",
    "observed_magic",
    "entry_join_basis",
    "exit_join_basis",
}


def target_runtime_q08_binding_contract_issues(
    binding: Mapping[str, Any] | None,
    *,
    expected_magic: Any,
) -> list[str]:
    """Validate the only current TARGET run-time/Q08 success contract.

    ``INCOMPLETE`` is intentional solely because ENTRY_ACCEPTED contains a
    request price rather than an authoritative fill price.  Every join and
    expected-Magic integrity axis must otherwise be complete.
    """

    if not isinstance(binding, Mapping):
        return ["BINDING_NOT_OBJECT"]
    issues: list[str] = []
    if set(binding) != TARGET_RUNTIME_Q08_BINDING_FIELDS:
        issues.append("SCHEMA_FIELDS_MISMATCH")
    expected_values = {
        "status": "INCOMPLETE",
        "integrity_status": "PASS",
        "blockers": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
        "entries_complete": False,
        "entry_join_complete": True,
        "exits_complete": True,
        "exit_join_complete": True,
        "entry_axis_reasons": ["ENTRY_FILL_PRICE_NOT_EMITTED"],
        "exit_axis_reasons": [],
        "magic_bound": True,
        "authoritative_expected_magic_bound": True,
        "expected_magic": expected_magic,
        "expected_magic_valid": True,
        "runtime_magic_matches_expected": True,
        "q08_magic_matches_expected": True,
        "magic_cross_stream_consistent": True,
        "observed_magic": expected_magic,
        "entry_join_basis": (
            "exact_broker_time_symbol_canonical_volume_bijection; "
            "price_is_request_not_fill"
        ),
        "exit_join_basis": "exact_broker_time_symbol_canonical_volume_bijection",
    }
    if type(expected_magic) is not int or expected_magic <= 0:
        issues.append("EXPECTED_MAGIC_INVALID")
    for field, expected in expected_values.items():
        if binding.get(field) != expected:
            issues.append(f"FIELD_MISMATCH:{field}")
    enriched_rows = binding.get("enriched_rows")
    if not isinstance(enriched_rows, list) or not enriched_rows or not all(
        isinstance(row, Mapping) for row in enriched_rows
    ):
        issues.append("ENRICHED_ROWS_MISSING_OR_INVALID")
    return sorted(set(issues))


def target_runtime_q08_binding_blockers(
    binding: Mapping[str, Any] | None,
    *,
    expected_magic: Any,
) -> list[str]:
    """Return receipt blockers for a non-conforming TARGET Q08 binding."""

    issues = target_runtime_q08_binding_contract_issues(
        binding, expected_magic=expected_magic
    )
    if not issues:
        return []
    result = ["RUNTIME_LOG_Q08_BINDING_INVALID"]
    raw_blockers = binding.get("blockers") if isinstance(binding, Mapping) else None
    if isinstance(raw_blockers, list) and all(
        isinstance(item, str) and item for item in raw_blockers
    ):
        result.extend(raw_blockers)
    else:
        result.append("RUNTIME_LOG_Q08_BINDING_BLOCKERS_INVALID")
    result.extend(
        f"RUNTIME_LOG_Q08_BINDING_CONTRACT:{issue}" for issue in issues
    )
    return result


class _ReportCellParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.cells: list[str] = []
        self._depth = 0
        self._parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.casefold() in {"td", "th"}:
            if self._depth == 0:
                self._parts = []
            self._depth += 1

    def handle_data(self, data: str) -> None:
        if self._depth:
            self._parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag.casefold() in {"td", "th"} and self._depth:
            self._depth -= 1
            if self._depth == 0:
                self.cells.append(" ".join("".join(self._parts).split()))


def parse_native_report_execution_evidence(report_path: Path) -> dict[str, Any]:
    """Bind MT5's model-quality header independently of performance parsers."""

    raw = report_path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        text = raw.decode("utf-16")
    elif raw[:512][1::2].count(0) > max(2, len(raw[:512]) // 8):
        text = raw.decode("utf-16-le", errors="strict")
    else:
        text = raw.decode("utf-8-sig", errors="strict")
    parser = _ReportCellParser()
    parser.feed(text)
    values: dict[str, str] = {}
    labels = {
        "history quality": "history_quality",
        "bars": "bars",
        "ticks": "ticks",
        "symbols": "symbol_count",
    }
    for index, cell in enumerate(parser.cells[:-1]):
        normalized = html.unescape(cell).strip().rstrip(":").casefold()
        field = labels.get(normalized)
        if field and field not in values:
            values[field] = parser.cells[index + 1].strip()

    def positive_int(field: str) -> int | None:
        text_value = values.get(field)
        if text_value is None:
            return None
        digits = re.sub(r"[^0-9]", "", text_value)
        if not digits:
            return None
        value = int(digits)
        return value if value > 0 else None

    quality = values.get("history_quality")
    normalized_quality = " ".join(str(quality or "").split()).casefold()
    bars = positive_int("bars")
    ticks = positive_int("ticks")
    symbol_count = positive_int("symbol_count")
    errors: list[str] = []
    if quality is None:
        errors.append("HISTORY_QUALITY_MISSING")
    elif normalized_quality != "100% real ticks":
        errors.append("HISTORY_QUALITY_NOT_100_PERCENT_REAL_TICKS")
    if bars is None:
        errors.append("BARS_MISSING_OR_INVALID")
    if ticks is None:
        errors.append("TICKS_MISSING_OR_INVALID")
    if symbol_count is None:
        errors.append("SYMBOL_COUNT_MISSING_OR_INVALID")
    return {
        "history_quality": quality,
        "history_quality_normalized": normalized_quality or None,
        "bars": bars,
        "ticks": ticks,
        "symbol_count": symbol_count,
        "real_ticks_certified": not errors,
        "errors": errors,
    }


def build_cost_evidence(
    native_metrics: Mapping[str, Any] | None,
    *,
    native_execution_evidence: Mapping[str, Any] | None = None,
    execution_cost_contract: Mapping[str, Any] | None = None,
    execution_cost_manifest: Mapping[str, Any] | None = None,
    native_report_sha256: str | None = None,
    default_registry_path: Path = DEFAULT_COST_REGISTRY,
) -> dict[str, Any]:
    metrics = native_metrics if isinstance(native_metrics, Mapping) else {}
    model = metrics.get("commission_model")
    model_mapping = model if isinstance(model, Mapping) else {}
    registry_text = str(model_mapping.get("registry_path") or default_registry_path)
    registry_path = Path(registry_text).resolve()
    unknown = sorted({str(item) for item in (model_mapping.get("unknown_symbols") or [])})
    degraded_symbols = sorted(
        {str(item) for item in (model_mapping.get("degraded_symbols") or [])}
    )
    registry_sha = sha256_file(registry_path) if registry_path.is_file() else None
    legacy_reasons: list[str] = []
    if not isinstance(model, Mapping):
        legacy_reasons.append("COMMISSION_MODEL_NOT_EVALUATED")
    if model_mapping.get("degraded") is not False:
        legacy_reasons.append("COMMISSION_MODEL_DEGRADED")
    if degraded_symbols:
        legacy_reasons.append("DEGRADED_SYMBOL_COSTS")
    if unknown:
        legacy_reasons.append("UNKNOWN_SYMBOL_COSTS")
    if registry_sha is None:
        legacy_reasons.append("COMMISSION_REGISTRY_MISSING")

    axes: dict[str, dict[str, Any]] = {}
    reasons: list[str] = []
    contract_axes = (
        execution_cost_contract.get("axes")
        if isinstance(execution_cost_contract, Mapping)
        else None
    )
    for axis in EXECUTION_COST_AXES:
        raw = contract_axes.get(axis) if isinstance(contract_axes, Mapping) else None
        if not isinstance(raw, Mapping) or raw.get("status") != "PASS":
            axes[axis] = {
                "status": "NOT_EVALUATED",
                "source": "EXTERNAL_EXECUTION_COST_EVIDENCE_REQUIRED",
                "reasons": ["EXECUTION_COST_MANIFEST_AXIS_MISSING"],
            }
            reasons.append(f"{axis.upper()}_NOT_CERTIFIED")
            continue
        axis_row = {
            "status": "PASS",
            "source": "IMMUTABLE_EXTERNAL_EXECUTION_COST_EVIDENCE",
            "assertion": raw.get("assertion"),
            "methodology": raw.get("methodology"),
            "parameters": dict(raw.get("parameters") or {}),
            "scenarios": list(raw.get("scenarios") or []),
            "results": dict(raw.get("results") or {}),
            "evidence": dict(raw.get("evidence") or {}),
            "reasons": [],
        }
        if axis == "historical_tester_spread":
            native = (
                native_execution_evidence
                if isinstance(native_execution_evidence, Mapping)
                else {}
            )
            axis_row["native_report_evidence"] = {
                "native_report_sha256": native_report_sha256,
                "history_quality": native.get("history_quality"),
                "bars": native.get("bars"),
                "ticks": native.get("ticks"),
                "symbol_count": native.get("symbol_count"),
                "real_ticks_certified": native.get("real_ticks_certified"),
            }
            if (
                native.get("real_ticks_certified") is not True
                or " ".join(str(native.get("history_quality") or "").split()).casefold()
                != "100% real ticks"
                or not re.fullmatch(r"[0-9a-f]{64}", str(native_report_sha256 or ""))
            ):
                axis_row["status"] = "FAIL"
                axis_row["reasons"] = [
                    "NATIVE_REPORT_100_PERCENT_REAL_TICKS_NOT_BOUND"
                ]
                reasons.append("HISTORICAL_TESTER_SPREAD_NOT_CERTIFIED")
        axes[axis] = axis_row

    # The current-broker axes are deliberately external-only.  In particular,
    # a 100% real-ticks tester report never contributes to spread parity.
    certified = (
        isinstance(execution_cost_manifest, Mapping)
        and all(axes[axis].get("status") == "PASS" for axis in EXECUTION_COST_AXES)
    )
    if execution_cost_manifest is None:
        reasons.append("EXECUTION_COST_EVIDENCE_MANIFEST_MISSING")
    elif not certified and not reasons:
        reasons.append("EXECUTION_COST_AXIS_NOT_CERTIFIED")
    return {
        "status": (
            "CERTIFIED"
            if certified
            else "NOT_EVALUATED"
            if execution_cost_manifest is None
            else "DEGRADED"
        ),
        "cost_certified": certified,
        "reasons": sorted(set(reasons)),
        "required_axes": list(EXECUTION_COST_AXES),
        "axes": axes,
        "execution_cost_evidence_manifest": (
            dict(execution_cost_manifest) if execution_cost_manifest else None
        ),
        "scope": (
            execution_cost_contract.get("scope")
            if isinstance(execution_cost_contract, Mapping)
            else None
        ),
        "registry_path": str(registry_path),
        "registry_sha256": registry_sha,
        "unknown_symbols": unknown,
        "degraded_symbols": degraded_symbols,
        "legacy_commission_model": {
            "status": "DIAGNOSTIC_ONLY_NOT_A_QUALIFICATION_AXIS",
            "reasons": sorted(set(legacy_reasons)),
            "model": dict(model_mapping),
        },
    }


def _parse_native_report(report_path: Path, symbol: str) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    # Imports are delayed so planning/safety tests do not require numpy.
    from framework.scripts.q08_davey.common import load_trades_from_mt5_report
    from tools.strategy_farm.portfolio.prop_challenge_optimizer import (
        parse_mt5_report_daily_pnl,
    )

    rows = load_trades_from_mt5_report(report_path)
    # Parse all symbols.  Basket EAs (notably 12778) trade symbols beyond the
    # tester host chart; filtering to the host would understate their economics.
    metrics = parse_mt5_report_daily_pnl(report_path)
    metrics["host_symbol"] = symbol
    metrics["execution_evidence"] = parse_native_report_execution_evidence(report_path)
    metrics.pop("daily_pnl", None)
    return metrics, rows


def _terminate_process_tree(process: subprocess.Popen[Any]) -> dict[str, Any]:
    result: dict[str, Any] = {"requested": True, "pid": process.pid}
    if os.name == "nt":
        completed = subprocess.run(
            ["taskkill.exe", "/PID", str(process.pid), "/T", "/F"],
            capture_output=True,
            text=True,
            timeout=30,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        result.update(
            {
                "method": "taskkill_tree",
                "returncode": completed.returncode,
                "stdout": completed.stdout[-1000:],
                "stderr": completed.stderr[-1000:],
            }
        )
    else:
        process.kill()
        result["method"] = "process_kill"
    with contextlib.suppress(subprocess.TimeoutExpired):
        process.wait(timeout=30)
    result["root_exit_code"] = process.poll()
    return result


def _wait_for_stable_report(
    path: Path,
    *,
    started_epoch: float,
    timeout_seconds: int = 30,
) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_seconds
    previous: tuple[int, int] | None = None
    stable_observations = 0
    latest: dict[str, Any] = {"stable": False, "exists": False}
    while time.monotonic() < deadline:
        if path.is_file():
            stat = path.stat()
            latest = {
                "stable": False,
                "exists": True,
                "bytes": stat.st_size,
                "mtime_ns": stat.st_mtime_ns,
                "fresh_mtime": stat.st_mtime >= started_epoch - 2,
            }
            fingerprint = (stat.st_size, stat.st_mtime_ns)
            if stat.st_size > 1024 and latest["fresh_mtime"] and fingerprint == previous:
                stable_observations += 1
            else:
                stable_observations = 0
            previous = fingerprint
            if stable_observations >= 2:
                latest["stable"] = True
                latest["sha256"] = sha256_file(path)
                return latest
        time.sleep(0.5)
    return latest


def run_job(
    job: Job,
    sandbox: Path,
    output_root: Path,
    common_root: Path,
    *,
    from_date: str,
    to_date: str,
    currency: str,
    deposit: int,
    timeout_seconds: int,
    qualification_mode: str = "AS_LIVE_REQUAL",
    window_contract: Mapping[str, Any] | None = None,
    runner_sha256: str | None = None,
    artifact_override_manifest: Mapping[str, Any] | None = None,
    execution_cost_evidence_manifest: Mapping[str, Any] | None = None,
    sandbox_derivations: Mapping[str, Mapping[str, Any]] | None = None,
) -> dict[str, Any]:
    started = dt.datetime.now(dt.UTC)
    window = dict(
        window_contract
        or build_window_contract(from_date, to_date)
    )
    runner_bound_sha = runner_sha256 or sha256_file(Path(__file__).resolve())
    require_reference = qualification_mode != "DISCOVERY_COMPLETE_UNREFERENCED"
    expected_magic_source = verify_expected_magic_binding(
        job, required=qualification_mode == TARGET_BINARY_REQUAL
    )
    if qualification_mode == TARGET_BINARY_REQUAL and job.card_contract is None:
        raise RequalError(
            f"TARGET_BINARY_REQUAL job is missing card_contract: {job.key}"
        )
    card_contract_before = verify_card_contract_binding(
        job.card_contract, identity_label=job.key
    )
    sandbox_derivation_before: dict[str, Any] | None = None
    if qualification_mode == TARGET_BINARY_REQUAL:
        sandbox_derivation_before = load_target_sandbox_derivation(sandbox)
        expected_derivation = (
            sandbox_derivations.get(_path_identity(sandbox))
            if sandbox_derivations is not None
            else None
        )
        if expected_derivation is None or sandbox_derivation_before != dict(
            expected_derivation
        ):
            raise RequalError(
                f"target sandbox derivation changed after preflight: {sandbox}"
            )
    run_dir = output_root / "runs" / job.slug
    run_dir.mkdir(parents=True, exist_ok=False)
    source_ex5_sha_before = sha256_file(job.live_ex5)
    source_preset_sha_before = sha256_file(job.live_preset)
    source_preset_contract_before = live_preset_contract(job)
    if source_preset_contract_before["status"] != "PASS":
        raise RequalError(
            f"live preset violates manifest SET contract before MT5 for {job.key}: "
            f"{source_preset_contract_before['blockers']}"
        )
    reference_sha_before = (
        sha256_file(job.reference_stream)
        if job.reference_stream is not None and job.reference_stream.is_file()
        else None
    )
    if require_reference and (
        not job.reference_expected_sha256
        or reference_sha_before != job.reference_expected_sha256
    ):
        raise RequalError(
            f"reference hash changed after preflight for {job.key}: "
            f"expected={job.reference_expected_sha256} actual={reference_sha_before}"
        )

    expert_dir = sandbox / "MQL5" / "Experts" / "QM"
    preset_dir = sandbox / "MQL5" / "Profiles" / "Tester"
    expert_dir.mkdir(parents=True, exist_ok=True)
    preset_dir.mkdir(parents=True, exist_ok=True)
    staged_ex5 = expert_dir / job.live_ex5.name
    staged_preset = preset_dir / job.live_preset.name
    shutil.copy2(job.live_ex5, staged_ex5)
    shutil.copy2(job.live_preset, staged_preset)
    if sha256_file(staged_ex5) != source_ex5_sha_before:
        raise RequalError(f"EX5 staging hash mismatch for {job.key}")
    if sha256_file(staged_preset) != source_preset_sha_before:
        raise RequalError(f"preset staging hash mismatch for {job.key}")
    staged_preset_contract = live_preset_contract(job, staged_preset)
    if staged_preset_contract["status"] != "PASS":
        raise RequalError(
            f"staged preset violates manifest SET contract before MT5 for {job.key}: "
            f"{staged_preset_contract['blockers']}"
        )

    report_name = f"DXZ_TRUTH_{job.slug}.htm"
    report_source = sandbox / report_name
    ini_path = run_dir / "tester.ini"
    write_tester_ini(
        ini_path,
        job=job,
        report_name=report_name,
        preset_name=staged_preset.name,
        from_date=from_date,
        to_date=to_date,
        currency=currency,
        deposit=deposit,
    )

    common_path = _common_stream_path(common_root, job)
    common_path.parent.mkdir(parents=True, exist_ok=True)
    had_previous = common_path.is_file()
    before_bytes = common_path.read_bytes() if had_previous else None
    before_sha = hashlib.sha256(before_bytes).hexdigest() if before_bytes is not None else None
    common_backup = (
        common_path.with_name(f".{common_path.name}.dxz_pre_{uuid.uuid4().hex}")
        if had_previous
        else None
    )
    common_transaction_path = run_dir / "common_stream_transaction.json"
    common_transaction: dict[str, Any] = {
        "status": "PREPARE_INTENT",
        "common_path": str(common_path),
        "backup_path": str(common_backup) if common_backup else None,
        "had_previous": had_previous,
        "previous_sha256": before_sha,
        "prepared_utc": dt.datetime.now(dt.UTC).isoformat(),
    }
    # Persist recovery intent before the first mutating operation.  If the
    # atomic move itself raises, the worker can prove that the original target
    # is already intact; if it succeeds, the recorded backup can be restored.
    common_transaction_path.write_text(
        json.dumps(common_transaction, indent=2, sort_keys=True), encoding="utf-8"
    )
    if common_backup is not None:
        os.replace(common_path, common_backup)
    # The Common tree is identity-isolated from T_Live.  Removing the target
    # before execution makes freshness provable: a post-run file can only have
    # been created by this job, while the previous isolated artifact is restored
    # after capture.
    if common_path.exists():
        raise RequalError(f"could not clear isolated pre-run Q08 stream: {common_path}")
    common_transaction["status"] = "PREPARED"
    common_transaction_path.write_text(
        json.dumps(common_transaction, indent=2, sort_keys=True), encoding="utf-8"
    )
    if report_source.exists():
        report_source.unlink()

    command = [
        str(sandbox / "terminal64.exe"),
        "/portable",
        f"/config:{str(ini_path.resolve()).replace('/', chr(92))}",
    ]
    runtime_log_transaction = _prepare_runtime_log_transaction(
        sandbox, job, run_dir
    )
    process: subprocess.Popen[Any] | None = None
    timed_out = False
    termination: dict[str, Any] | None = None
    runtime_log_capture: dict[str, Any]
    try:
        process = subprocess.Popen(
            command,
            cwd=str(sandbox),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        deadline = time.monotonic() + timeout_seconds
        while process.poll() is None and time.monotonic() < deadline:
            time.sleep(2)
        if process.poll() is None:
            timed_out = True
            termination = _terminate_process_tree(process)
    finally:
        if process is not None and process.poll() is None:
            termination = _terminate_process_tree(process)
        runtime_log_capture = _capture_runtime_log_transaction(
            sandbox, job, run_dir, runtime_log_transaction
        )
        if runtime_log_capture.get("restored") is not True:
            recovery = _recover_runtime_log_transaction(sandbox, job, run_dir)
            runtime_log_capture["exception_recovery"] = recovery
    exit_code = process.returncode if process is not None else None

    report_stability = _wait_for_stable_report(
        report_source, started_epoch=started.timestamp()
    )

    report_target = run_dir / "report.htm"
    report_exists = report_source.is_file()
    if report_exists:
        shutil.copy2(report_source, report_target)
    report_copy_hash_match = (
        report_target.is_file()
        and bool(report_stability.get("sha256"))
        and sha256_file(report_target) == report_stability.get("sha256")
    )
    common_capture = _capture_common_stream(
        common_path,
        run_dir / "q08_stream.jsonl",
        before_bytes,
        common_backup,
    )
    common_capture["pre_run_removed"] = before_bytes is not None
    common_capture["previous_sha256"] = before_sha
    common_restore_verified = (
        (before_sha is None and not common_path.exists())
        or (
            before_sha is not None
            and common_path.is_file()
            and sha256_file(common_path) == before_sha
        )
    )
    common_capture["restore_hash_verified"] = common_restore_verified
    common_transaction.update(
        {
            "status": "CAPTURED_AND_RESTORED" if common_restore_verified else "RESTORE_FAILED",
            "completed_utc": dt.datetime.now(dt.UTC).isoformat(),
            "capture": common_capture,
        }
    )
    common_transaction_path.write_text(
        json.dumps(common_transaction, indent=2, sort_keys=True), encoding="utf-8"
    )

    native_metrics: dict[str, Any] = {}
    native_rows: list[dict[str, Any]] = []
    parse_error = None
    if report_target.is_file():
        try:
            native_metrics, native_rows = _parse_native_report(report_target, job.symbol)
        except Exception as exc:  # evidence records parser faults without hiding the report
            parse_error = repr(exc)
    derived_stream = run_dir / "report_trade_stream.jsonl"
    if native_rows:
        derived_stream.write_text(
            "".join(json.dumps(row, sort_keys=True) + "\n" for row in native_rows),
            encoding="utf-8",
        )

    reference_sha_after = (
        sha256_file(job.reference_stream)
        if job.reference_stream is not None and job.reference_stream.is_file()
        else None
    )
    reference_rows, reference_errors = load_trade_rows_strict(job.reference_stream)
    if not require_reference:
        reference_rows, reference_errors = [], []
    q08_evidence = run_dir / "q08_stream.jsonl"
    q08_rows, q08_errors = load_trade_rows_strict(
        q08_evidence if common_capture.get("fresh_created") else None
    )
    runtime_log_evidence = (
        run_dir / "runtime_log.jsonl"
        if runtime_log_capture.get("status") == "PASS"
        else None
    )
    runtime_telemetry = parse_runtime_log_strict(runtime_log_evidence, job)
    runtime_telemetry_binding = bind_runtime_telemetry_to_q08(
        q08_rows, runtime_telemetry, expected_magic=job.expected_magic
    )
    runtime_telemetry_artifact = run_dir / "runtime_telemetry.json"
    runtime_telemetry_artifact.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "capture_sha256": runtime_log_capture.get("sha256"),
                "job_identity": job.key,
                "expected_magic": job.expected_magic,
                "expected_magic_source": expected_magic_source,
                "telemetry": runtime_telemetry,
                "q08_binding": runtime_telemetry_binding,
            },
            indent=2,
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    observed_stats = trade_stats(native_rows)
    reference_stats = trade_stats(reference_rows)
    q08_stats = trade_stats(q08_rows)
    reference_identity = signal_identity_stats(reference_rows)
    q08_identity = signal_identity_stats(q08_rows)
    manifest_count_match = (
        job.manifest_trades is None or observed_stats["trades"] == job.manifest_trades
    )
    close_sequence_match = (
        bool(reference_rows)
        and observed_stats["close_time_count"] == reference_stats["close_time_count"]
        and observed_stats["close_times_sha256"] == reference_stats["close_times_sha256"]
    )
    q08_native_close_sequence_match = (
        bool(q08_rows)
        and q08_stats["close_time_count"] == observed_stats["close_time_count"]
        and q08_stats["close_times_sha256"] == observed_stats["close_times_sha256"]
    )
    signal_comparison = compare_signal_identity(q08_identity, reference_identity)
    q08_reference_identity_match = (
        bool(q08_rows) and bool(reference_rows) and signal_comparison["identity_match"]
    )
    q08_reference_outcome_sign_match = (
        bool(q08_rows)
        and bool(reference_rows)
        and signal_comparison["outcome_sign_match"]
    )
    expected_start_date = from_date.replace(".", "-")
    expected_end_date = to_date.replace(".", "-")
    native_report_window_match = (
        native_metrics.get("start_date") == expected_start_date
        and native_metrics.get("end_date") == expected_end_date
    )
    native_report_trade_count_match = (
        native_metrics.get("closed_trades") == observed_stats["trades"]
    )
    native_execution_evidence = (
        native_metrics.get("execution_evidence")
        if isinstance(native_metrics.get("execution_evidence"), dict)
        else {
            "history_quality": None,
            "history_quality_normalized": None,
            "bars": None,
            "ticks": None,
            "symbol_count": None,
            "real_ticks_certified": False,
            "errors": ["EXECUTION_EVIDENCE_NOT_PARSED"],
        }
    )
    native_report_sha = sha256_file(report_target) if report_target.is_file() else None
    cost_evidence = build_cost_evidence(
        native_metrics,
        native_execution_evidence=native_execution_evidence,
        execution_cost_contract=job.execution_cost_contract,
        execution_cost_manifest=execution_cost_evidence_manifest,
        native_report_sha256=native_report_sha,
    )
    source_ex5_sha_after = sha256_file(job.live_ex5)
    source_preset_sha_after = sha256_file(job.live_preset)
    source_preset_contract_after = live_preset_contract(job)
    card_contract_after: dict[str, Any] | None = None
    card_contract_unchanged = True
    try:
        card_contract_after = verify_card_contract_binding(
            job.card_contract, identity_label=job.key
        )
    except (RequalError, OSError, ValueError):
        card_contract_unchanged = False
    sandbox_derivation_after: dict[str, Any] | None = None
    sandbox_derivation_unchanged = True
    if qualification_mode == TARGET_BINARY_REQUAL:
        try:
            sandbox_derivation_after = load_target_sandbox_derivation(sandbox)
        except (RequalError, OSError, ValueError):
            sandbox_derivation_unchanged = False
        else:
            sandbox_derivation_unchanged = (
                sandbox_derivation_after == sandbox_derivation_before
            )
    status = "PASS"
    blockers: list[str] = []
    if timed_out:
        blockers.append("TIMEOUT")
    if source_ex5_sha_after != source_ex5_sha_before:
        blockers.append("SOURCE_EX5_CHANGED_DURING_JOB")
    if source_preset_sha_after != source_preset_sha_before:
        blockers.append("SOURCE_PRESET_CHANGED_DURING_JOB")
    if source_preset_contract_after["status"] != "PASS":
        blockers.extend(source_preset_contract_after["blockers"])
    if not card_contract_unchanged:
        blockers.append("CARD_CONTRACT_CHANGED_DURING_JOB")
    if not sandbox_derivation_unchanged:
        blockers.append("TARGET_SANDBOX_DERIVATION_CHANGED_DURING_JOB")
    if exit_code != 0:
        blockers.append("NONZERO_TERMINAL_EXIT")
    if not report_exists:
        blockers.append("NO_NATIVE_REPORT")
    if not report_stability.get("stable"):
        blockers.append("NATIVE_REPORT_NOT_STABLE_OR_FRESH")
    if not report_copy_hash_match:
        blockers.append("NATIVE_REPORT_COPY_HASH_MISMATCH")
    if not native_report_window_match:
        blockers.append("NATIVE_REPORT_WINDOW_MISMATCH")
    if not native_report_trade_count_match:
        blockers.append("NATIVE_REPORT_TRADE_COUNT_MISMATCH")
    if native_execution_evidence.get("real_ticks_certified") is not True:
        blockers.append("NATIVE_REPORT_EXECUTION_EVIDENCE_INVALID")
        blockers.extend(
            f"NATIVE_REPORT_{item}"
            for item in native_execution_evidence.get("errors", [])
        )
    if parse_error:
        blockers.append("REPORT_PARSE_ERROR")
    if not native_rows:
        blockers.append("NO_REPORT_TRADES")
    if not common_capture.get("restored"):
        blockers.append("COMMON_STREAM_RACE")
    if not common_restore_verified:
        blockers.append("COMMON_STREAM_RESTORE_HASH_MISMATCH")
    if not common_capture.get("fresh_created"):
        blockers.append("Q08_STREAM_NOT_FRESH")
    if q08_errors:
        blockers.append("Q08_STREAM_INVALID")
    if require_reference and reference_errors:
        blockers.append("REFERENCE_STREAM_MISSING_OR_INVALID")
    if require_reference and reference_sha_after != reference_sha_before:
        blockers.append("REFERENCE_STREAM_CHANGED_DURING_JOB")
    if not q08_native_close_sequence_match:
        blockers.append("Q08_NATIVE_CLOSE_SEQUENCE_MISMATCH")
    if require_reference and not q08_reference_identity_match:
        blockers.append("Q08_REFERENCE_SIGNAL_IDENTITY_MISMATCH")
    if require_reference and not q08_reference_outcome_sign_match:
        blockers.append("Q08_REFERENCE_OUTCOME_SIGN_MISMATCH")
    if not manifest_count_match:
        blockers.append("MANIFEST_TRADE_COUNT_MISMATCH")
    if require_reference and reference_rows and not close_sequence_match:
        blockers.append("REFERENCE_CLOSE_SEQUENCE_MISMATCH")
    if runtime_log_capture.get("restored") is not True:
        blockers.append("RUNTIME_LOG_PRESTATE_RESTORE_FAILED")
    if (
        runtime_log_capture.get("status") == "PASS"
        and runtime_telemetry.get("status") != "PASS"
    ):
        blockers.append("RUNTIME_LOG_TELEMETRY_INVALID")
        blockers.extend(runtime_telemetry.get("errors", []))
    if qualification_mode == TARGET_BINARY_REQUAL:
        if runtime_log_capture.get("status") != "PASS":
            blockers.append("RUNTIME_LOG_CAPTURE_INVALID")
            blockers.extend(runtime_log_capture.get("blockers", []))
        if runtime_telemetry.get("status") != "PASS":
            blockers.append("RUNTIME_LOG_TELEMETRY_INVALID")
            blockers.extend(runtime_telemetry.get("errors", []))
        blockers.extend(
            target_runtime_q08_binding_blockers(
                runtime_telemetry_binding,
                expected_magic=job.expected_magic,
            )
        )
    if blockers:
        status = "FAIL"

    technical_status = status
    receipt_qualification_status = qualification_status(
        qualification_mode,
        technical_pass=status == "PASS",
        cost_certified=cost_evidence["cost_certified"] is True,
    )
    if qualification_mode in DISCOVERY_MODES:
        if status == "PASS":
            status = "NONQUALIFYING"

    receipt = {
        "schema_version": SCHEMA_VERSION,
        "status": status,
        "technical_status": technical_status,
        "qualification_mode": qualification_mode,
        "qualification_status": receipt_qualification_status,
        "deployment_eligible": False,
        "window_contract": window,
        "requested_from_date": window["requested_from_date"],
        "requested_to_date": window["requested_to_date"],
        "effective_from_date": window["effective_from_date"],
        "effective_to_date": window["effective_to_date"],
        "runner_sha256": runner_bound_sha,
        "artifact_override_manifest": (
            dict(artifact_override_manifest) if artifact_override_manifest else None
        ),
        "artifact_source": job.artifact_source,
        "card_contract": dict(job.card_contract) if job.card_contract else None,
        "execution_cost_evidence_manifest": (
            dict(execution_cost_evidence_manifest)
            if execution_cost_evidence_manifest
            else None
        ),
        "blockers": blockers,
        "job": {
            "ordinal": job.ordinal,
            "ea_id": job.ea_id,
            "symbol": job.symbol,
            "ea_label": job.ea_label,
            "timeframe": job.timeframe,
            "variant_id": job.variant_id,
            "manifest_trades": job.manifest_trades,
            "expected_magic": job.expected_magic,
            "expected_magic_source": expected_magic_source,
        },
        "execution": {
            "sandbox": str(sandbox),
            "sandbox_derivation": sandbox_derivation_before,
            "sandbox_derivation_end": sandbox_derivation_after,
            "sandbox_derivation_unchanged": sandbox_derivation_unchanged,
            "command_contract": ["terminal64.exe", "/portable", "/config:<absolute-ini>"],
            "started_utc": started.isoformat(),
            "finished_utc": dt.datetime.now(dt.UTC).isoformat(),
            "exit_code": exit_code,
            "timed_out": timed_out,
            "timeout_termination": termination,
            "from_date": from_date,
            "to_date": to_date,
            "requested_from_date": window["requested_from_date"],
            "requested_to_date": window["requested_to_date"],
            "effective_from_date": window["effective_from_date"],
            "effective_to_date": window["effective_to_date"],
            "currency": currency,
            "deposit": deposit,
        },
        "identity": {
            "live_ex5_path": str(job.live_ex5),
            "live_ex5_sha256": source_ex5_sha_after,
            "live_ex5_sha256_before": source_ex5_sha_before,
            "source_ex5_path": str(job.live_ex5),
            "source_ex5_sha256": source_ex5_sha_after,
            "source_ex5_sha256_before": source_ex5_sha_before,
            "staged_ex5_sha256": sha256_file(staged_ex5),
            "live_preset_path": str(job.live_preset),
            "live_preset_sha256": source_preset_sha_after,
            "live_preset_sha256_before": source_preset_sha_before,
            "source_set_path": str(job.live_preset),
            "source_set_sha256": source_preset_sha_after,
            "source_set_sha256_before": source_preset_sha_before,
            "staged_preset_sha256": sha256_file(staged_preset),
            "tester_ini_sha256": sha256_file(ini_path),
            "native_report_sha256": native_report_sha,
            "report_trade_stream_sha256": (
                sha256_file(derived_stream) if derived_stream.is_file() else None
            ),
            "q08_stream_sha256": common_capture.get("stream_sha256"),
            "runtime_log_path": runtime_log_capture.get("evidence_path"),
            "runtime_log_sha256": runtime_log_capture.get("sha256"),
            "runtime_log_transaction_path": str(
                run_dir / "runtime_log_transaction.json"
            ),
            "runtime_log_transaction_sha256": sha256_file(
                run_dir / "runtime_log_transaction.json"
            ),
            "runtime_telemetry_path": str(runtime_telemetry_artifact),
            "runtime_telemetry_sha256": sha256_file(runtime_telemetry_artifact),
            "reference_stream_path": str(job.reference_stream) if job.reference_stream else None,
            "reference_stream_sha256": (
                reference_sha_after
            ),
            "reference_expected_sha256": job.reference_expected_sha256,
            "reference_stream_sha256_before": reference_sha_before,
            "reference_frozen_relative_path": job.reference_frozen_relative_path,
            "artifact_source": job.artifact_source,
            "artifact_override_manifest": dict(artifact_override_manifest or {}),
            "card_contract": card_contract_before,
            "card_contract_end": card_contract_after,
            "card_contract_unchanged": card_contract_unchanged,
            "expected_magic": job.expected_magic,
            "expected_magic_source": expected_magic_source,
        },
        "common_stream_capture": common_capture,
        "runtime_log_capture": runtime_log_capture,
        "runtime_telemetry": {
            **{
                key: value
                for key, value in runtime_telemetry.items()
                if key not in {"entries", "exits", "equity"}
            },
            "entries": {
                key: value
                for key, value in runtime_telemetry["entries"].items()
                if key != "sequence"
            },
            "exits": {
                key: value
                for key, value in runtime_telemetry["exits"].items()
                if key != "sequence"
            },
            "equity": {
                key: value
                for key, value in runtime_telemetry["equity"].items()
                if key != "sequence"
            },
        },
        "runtime_telemetry_binding": {
            key: value
            for key, value in runtime_telemetry_binding.items()
            if key != "enriched_rows"
        },
        "native_report_stability": report_stability,
        "native_report_copy_hash_match": report_copy_hash_match,
        "native_report_window_match": native_report_window_match,
        "native_report_trade_count_match": native_report_trade_count_match,
        "native_metrics": native_metrics,
        "native_report_execution_evidence": native_execution_evidence,
        "live_preset_contract": {
            "before": source_preset_contract_before,
            "staged": staged_preset_contract,
            "after": source_preset_contract_after,
            "unchanged": (
                source_preset_contract_before == source_preset_contract_after
                and source_preset_sha_before == source_preset_sha_after
            ),
        },
        "cost_evidence": cost_evidence,
        "cost_certified": cost_evidence["cost_certified"],
        "observed_trade_stats": observed_stats,
        "q08_trade_stats": q08_stats,
        "reference_trade_stats": reference_stats if reference_rows else None,
        "q08_signal_identity": q08_identity,
        "reference_signal_identity": reference_identity if reference_rows else None,
        "q08_parse_errors": q08_errors,
        "reference_parse_errors": reference_errors,
        "manifest_count_match": manifest_count_match,
        "reference_close_sequence_match": close_sequence_match if reference_rows else None,
        "q08_native_close_sequence_match": q08_native_close_sequence_match,
        "q08_reference_signal_identity_match": q08_reference_identity_match,
        "q08_reference_outcome_sign_match": q08_reference_outcome_sign_match,
        "parse_error": parse_error,
    }
    if qualification_mode == TARGET_BINARY_REQUAL:
        receipt["reproducibility_identity"] = target_reproducibility_identity(
            q08_rows,
            parse_errors=q08_errors,
            runtime_telemetry=runtime_telemetry,
            telemetry_binding=runtime_telemetry_binding,
        )
    receipt["receipt_sha256"] = canonical_json_sha(receipt)
    (run_dir / "receipt.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True), encoding="utf-8"
    )
    return receipt


def execute_book(
    jobs: list[Job],
    sandboxes: list[Path],
    output_root: Path,
    common_root: Path,
    **run_kwargs: Any,
) -> list[dict[str, Any]]:
    common_keys = [str(_common_stream_path(common_root, job)).casefold() for job in jobs]
    if len(common_keys) != len(set(common_keys)):
        raise RequalError("duplicate case-insensitive Q08 Common paths in execution cohort")
    # One serial worker per portable root; roots execute in parallel.
    buckets: list[list[Job]] = [[] for _ in sandboxes]
    for index, job in enumerate(jobs):
        buckets[index % len(sandboxes)].append(job)

    def worker(root: Path, assigned: list[Job]) -> list[dict[str, Any]]:
        receipts: list[dict[str, Any]] = []
        for job in assigned:
            try:
                receipts.append(
                    run_job(job, root, output_root, common_root, **run_kwargs)
                )
            except BaseException as exc:
                run_dir = output_root / "runs" / job.slug
                recovery = _recover_common_transaction(common_root, job, run_dir)
                runtime_log_recovery = _recover_runtime_log_transaction(
                    root, job, run_dir
                )
                if not isinstance(exc, Exception):
                    raise
                receipt = {
                    "schema_version": SCHEMA_VERSION,
                    "status": "ERROR",
                    "technical_status": "ERROR",
                    "qualification_mode": run_kwargs.get(
                        "qualification_mode", "AS_LIVE_REQUAL"
                    ),
                    "qualification_status": "FAILED",
                    "deployment_eligible": False,
                    "window_contract": dict(run_kwargs.get("window_contract") or {}),
                    "requested_from_date": (run_kwargs.get("window_contract") or {}).get(
                        "requested_from_date"
                    ),
                    "requested_to_date": (run_kwargs.get("window_contract") or {}).get(
                        "requested_to_date"
                    ),
                    "effective_from_date": (run_kwargs.get("window_contract") or {}).get(
                        "effective_from_date"
                    ),
                    "effective_to_date": (run_kwargs.get("window_contract") or {}).get(
                        "effective_to_date"
                    ),
                    "runner_sha256": run_kwargs.get("runner_sha256"),
                    "artifact_override_manifest": run_kwargs.get(
                        "artifact_override_manifest"
                    ),
                    "artifact_source": job.artifact_source,
                    "card_contract": (
                        dict(job.card_contract) if job.card_contract else None
                    ),
                    "execution_cost_evidence_manifest": run_kwargs.get(
                        "execution_cost_evidence_manifest"
                    ),
                    "blockers": ["RUNNER_EXCEPTION"],
                    "job": {
                        "ea_id": job.ea_id,
                        "symbol": job.symbol,
                        "timeframe": job.timeframe,
                        "variant_id": job.variant_id,
                        "ordinal": job.ordinal,
                        "expected_magic": job.expected_magic,
                        "expected_magic_source": (
                            dict(job.expected_magic_source)
                            if job.expected_magic_source
                            else None
                        ),
                    },
                    "identity": {
                        "expected_magic": job.expected_magic,
                        "expected_magic_source": (
                            dict(job.expected_magic_source)
                            if job.expected_magic_source
                            else None
                        ),
                    },
                    "execution": {"sandbox": str(root)},
                    "common_stream_exception_recovery": recovery,
                    "runtime_log_exception_recovery": runtime_log_recovery,
                    "cost_evidence": {
                        "status": "NOT_EVALUATED",
                        "cost_certified": False,
                        "reasons": ["RUNNER_EXCEPTION"],
                        "registry_path": None,
                        "registry_sha256": None,
                        "unknown_symbols": [],
                        "degraded_symbols": [],
                    },
                    "cost_certified": False,
                    "error": repr(exc),
                }
                receipt["receipt_sha256"] = canonical_json_sha(receipt)
                run_dir.mkdir(parents=True, exist_ok=True)
                (run_dir / "receipt.json").write_text(
                    json.dumps(receipt, indent=2, sort_keys=True), encoding="utf-8"
                )
                receipts.append(receipt)
        return receipts

    receipts: list[dict[str, Any]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(sandboxes)) as pool:
        futures = [pool.submit(worker, root, bucket) for root, bucket in zip(sandboxes, buckets)]
        for future in concurrent.futures.as_completed(futures):
            receipts.extend(future.result())
    return sorted(receipts, key=lambda item: int((item.get("job") or {}).get("ordinal") or 0))


@contextlib.contextmanager
def execution_locks(paths: Iterable[Path], *, token: str) -> Iterable[None]:
    acquired: list[Path] = []
    payload = json.dumps(
        {
            "token": token,
            "pid": os.getpid(),
            "created_utc": dt.datetime.now(dt.UTC).isoformat(),
        },
        sort_keys=True,
    ).encode("utf-8")
    try:
        for path in sorted({item.resolve() for item in paths}, key=lambda item: str(item).casefold()):
            path.parent.mkdir(parents=True, exist_ok=True)
            try:
                descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError as exc:
                raise RequalError(f"execution lock already exists: {path}") from exc
            try:
                os.write(descriptor, payload)
            finally:
                os.close(descriptor)
            acquired.append(path)
        yield
    finally:
        for path in reversed(acquired):
            with contextlib.suppress(OSError):
                if path.read_bytes() == payload:
                    path.unlink()


def build_plan(jobs: list[Job], sandboxes: list[Path]) -> dict[str, Any]:
    rows = []
    for index, job in enumerate(jobs):
        card_contract = verify_card_contract_binding(
            job.card_contract, identity_label=job.key
        )
        expected_magic_source = verify_expected_magic_binding(job, required=False)
        rows.append(
            {
                "ordinal": job.ordinal,
                "ea_id": job.ea_id,
                "symbol": job.symbol,
                "ea_label": job.ea_label,
                "timeframe": job.timeframe,
                "variant_id": job.variant_id,
                "expected_magic": job.expected_magic,
                "expected_magic_source": expected_magic_source,
                "sandbox": str(sandboxes[index % len(sandboxes)]),
                "live_ex5": str(job.live_ex5),
                "live_ex5_sha256": sha256_file(job.live_ex5),
                "live_preset": str(job.live_preset),
                "live_preset_sha256": sha256_file(job.live_preset),
                "live_preset_contract": live_preset_contract(job),
                "reference_stream": str(job.reference_stream) if job.reference_stream else None,
                "reference_expected_sha256": job.reference_expected_sha256,
                "reference_frozen_relative_path": job.reference_frozen_relative_path,
                "artifact_source": job.artifact_source,
                "card_contract": card_contract,
                "execution_cost_contract": (
                    {
                        "scope": job.execution_cost_contract.get("scope"),
                        "axis_status": {
                            axis: (job.execution_cost_contract.get("axes") or {})
                            .get(axis, {})
                            .get("status")
                            for axis in EXECUTION_COST_AXES
                        },
                    }
                    if job.execution_cost_contract
                    else None
                ),
            }
        )
    return {"schema_version": SCHEMA_VERSION, "mode": "PLAN", "jobs": rows}


def parser() -> argparse.ArgumentParser:
    argp = argparse.ArgumentParser(description=__doc__)
    argp.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    argp.add_argument("--live-root", type=Path, default=DEFAULT_LIVE_ROOT)
    argp.add_argument("--sandbox-root", action="append", type=Path, required=True)
    argp.add_argument("--reference-stream-root", type=Path)
    argp.add_argument(
        "--execution-cost-evidence-manifest",
        type=Path,
        help=(
            "Optional immutable five-axis execution-cost manifest. Without it, "
            "AS_LIVE runs remain COST_UNCERTIFIED."
        ),
    )
    argp.add_argument(
        "--qualification-mode",
        choices=sorted(QUALIFICATION_MODES),
        default="AS_LIVE_REQUAL",
    )
    argp.add_argument(
        "--artifact-override-manifest",
        type=Path,
        help="Required SHA-bound EX5/set manifest for explicit discovery modes.",
    )
    argp.add_argument("--common-root", type=Path, default=DEFAULT_COMMON)
    argp.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    argp.add_argument("--from-date", default="2017.01.01")
    argp.add_argument("--to-date", default="2025.12.31")
    argp.add_argument("--effective-from")
    argp.add_argument("--effective-to")
    argp.add_argument("--currency", default="EUR")
    argp.add_argument("--deposit", type=int, default=100_000)
    argp.add_argument("--timeout-seconds", type=int, default=5_400)
    argp.add_argument(
        "--only",
        action="append",
        default=[],
        help="Optional EA id or EA:symbol selector. Repeatable; intended for smoke/retry runs.",
    )
    argp.add_argument("--execute", action="store_true", help="Run MT5; default is a safe plan only")
    return argp


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    invocation_utc = dt.datetime.now(dt.UTC)
    live_root = args.live_root.resolve()
    manifest_path = args.manifest.resolve()
    manifest_sha = sha256_file(manifest_path)
    runner_sha_start = sha256_file(Path(__file__).resolve())
    cost_registry_sha_start = (
        sha256_file(DEFAULT_COST_REGISTRY) if DEFAULT_COST_REGISTRY.is_file() else None
    )
    reference_root = args.reference_stream_root.resolve() if args.reference_stream_root else None
    override_manifest_path = (
        args.artifact_override_manifest.resolve()
        if args.artifact_override_manifest
        else None
    )
    execution_cost_manifest_path = (
        args.execution_cost_evidence_manifest.resolve()
        if args.execution_cost_evidence_manifest
        else None
    )
    window_contract = build_window_contract(
        args.from_date,
        args.to_date,
        effective_from=args.effective_from,
        effective_to=args.effective_to,
    )
    validate_qualification_contract(
        qualification_mode=args.qualification_mode,
        live_root=live_root,
        reference_stream_root=reference_root,
        artifact_override_manifest=override_manifest_path,
    )
    override_metadata: dict[str, Any] | None = None
    artifact_overrides: dict[str, dict[str, Any]] | None = None
    if override_manifest_path is not None:
        override_metadata, artifact_overrides = load_artifact_override_manifest(
            override_manifest_path,
            qualification_mode=args.qualification_mode,
            source_manifest_sha256=manifest_sha,
        )
        declared_override_mode = override_metadata.get("qualification_mode")
        if declared_override_mode != args.qualification_mode:
            raise RequalError(
                "artifact override qualification_mode mismatch: "
                f"expected={args.qualification_mode} actual={declared_override_mode}"
            )
    execution_cost_metadata: dict[str, Any] | None = None
    execution_cost_contracts: dict[str, dict[str, Any]] | None = None
    sandboxes = [validate_sandbox_root(path) for path in args.sandbox_root]
    if len(set(sandboxes)) != len(sandboxes):
        raise RequalError("duplicate sandbox roots")
    sandbox_derivation_rows = (
        [load_target_sandbox_derivation(path) for path in sandboxes]
        if args.qualification_mode == TARGET_BINARY_REQUAL
        else []
    )
    sandbox_derivations = {
        _path_identity(Path(row["sandbox_root"])): row
        for row in sandbox_derivation_rows
    }
    live_source_snapshot = (
        snapshot_live_source_artifacts(live_root)
        if args.qualification_mode == TARGET_BINARY_REQUAL
        else None
    )
    output_root = validate_output_root(args.output_dir, live_root)
    common_root = validate_common_root(args.common_root, execute=args.execute)
    manifest, jobs = build_jobs(
        manifest_path,
        live_root,
        reference_root,
        artifact_overrides,
        qualification_mode=args.qualification_mode,
    )
    manifest_job_count = len(jobs)
    if args.only:
        selectors = {str(value).strip().upper() for value in args.only}
        selected_ordinals: set[int] = set()
        unmatched: list[str] = []
        for selector in sorted(selectors):
            if selector.isdigit():
                matches = [job for job in jobs if str(job.ea_id) == selector]
            else:
                matches = [
                    job
                    for job in jobs
                    if selector
                    in {
                        job.key.upper(),
                        job.timeframe_key.upper(),
                        job.legacy_key.upper(),
                    }
                ]
                if len(matches) > 1:
                    raise RequalError(
                        f"--only selector is ambiguous; use timeframe/variant identity: "
                        f"{selector}"
                    )
            if not matches:
                unmatched.append(selector)
            selected_ordinals.update(job.ordinal for job in matches)
        if unmatched:
            raise RequalError(
                f"--only selectors matched no manifest sleeves: {sorted(unmatched)}"
            )
        jobs = [job for job in jobs if job.ordinal in selected_ordinals]
    scope = "PARTIAL" if args.only or len(jobs) != manifest_job_count else "FULL"
    if execution_cost_manifest_path is not None:
        execution_cost_metadata, execution_cost_contracts = (
            load_execution_cost_evidence_manifest(
                execution_cost_manifest_path,
                source_manifest_sha256=manifest_sha,
                as_of_utc=invocation_utc,
                required_sleeves=[
                    {
                        "ea_id": job.ea_id,
                        "symbol": job.symbol,
                        "timeframe": job.timeframe,
                        **(
                            {"variant_id": job.variant_id}
                            if args.qualification_mode == TARGET_BINARY_REQUAL
                            or job.variant_id is not None
                            else {}
                        ),
                    }
                    for job in jobs
                ],
                window_contract=window_contract,
            )
        )
        execution_cost_metadata["axis_hashes_start"] = (
            execution_cost_axis_hash_snapshot(execution_cost_metadata)
        )
    jobs = bind_jobs_to_execution_cost_contracts(
        jobs, contracts=execution_cost_contracts
    )
    if execution_cost_contracts is not None:
        missing_cost_keys = sorted(
            job.key for job in jobs if job.execution_cost_contract is None
        )
        if missing_cost_keys:
            raise RequalError(
                "execution-cost manifest does not cover selected sleeves: "
                f"{missing_cost_keys}"
            )
    output_root.mkdir(parents=True, exist_ok=True)

    require_reference = args.qualification_mode != "DISCOVERY_COMPLETE_UNREFERENCED"
    if require_reference:
        reference_snapshot, snapshot_rows = verify_reference_snapshot(
            reference_root, source_manifest_sha256=manifest_sha
        )
        jobs = bind_jobs_to_reference_snapshot(
            jobs,
            snapshot=reference_snapshot,
            snapshot_rows=snapshot_rows,
        )
    else:
        reference_snapshot = {
            "status": "NOT_REQUIRED_UNREFERENCED_DISCOVERY",
            "stream_root": None,
            "snapshot_root": None,
            "errors": [],
            "seal_verified": False,
        }
        snapshot_rows = {}
    preflight_by_key = {
        job.key: reference_preflight_blockers(
            job,
            snapshot=reference_snapshot,
            snapshot_rows=snapshot_rows,
            window_contract=window_contract,
            require_reference=require_reference,
        )
        for job in jobs
    }

    plan = build_plan(jobs, sandboxes)
    runnable_plan_index = 0
    for row, job in zip(plan["jobs"], jobs):
        row["reference_preflight_blockers"] = preflight_by_key[job.key]
        row["reference_preflight_ready"] = not preflight_by_key[job.key]
        if preflight_by_key[job.key]:
            row["sandbox"] = None
            row["execution_disposition"] = "BLOCKED_BEFORE_MT5"
        else:
            row["sandbox"] = str(sandboxes[runnable_plan_index % len(sandboxes)])
            row["execution_disposition"] = "RUN_MT5"
            runnable_plan_index += 1
    plan.update(
        {
            "schema_version": SCHEMA_VERSION,
            "scope": scope,
            "selected_jobs": len(jobs),
            "manifest_jobs": manifest_job_count,
            "manifest_path": str(manifest_path),
            "manifest_sha256": manifest_sha,
            "manifest_declared_status": manifest.get("status"),
            "runner_path": str(Path(__file__).resolve()),
            "runner_sha256": runner_sha_start,
            "runner_sha256_start": runner_sha_start,
            "qualification_mode": args.qualification_mode,
            "qualification_status": (
                "NONQUALIFYING_DISCOVERY"
                if args.qualification_mode in DISCOVERY_MODES
                else "PENDING_EXECUTION"
            ),
            "deployment_eligible": False,
            "window_contract": window_contract,
            "requested_from_date": window_contract["requested_from_date"],
            "requested_to_date": window_contract["requested_to_date"],
            "effective_from_date": window_contract["effective_from_date"],
            "effective_to_date": window_contract["effective_to_date"],
            "live_root": str(live_root),
            "canonical_live_root": str(DEFAULT_LIVE_ROOT.resolve()),
            "canonical_live_root_pinned": args.qualification_mode in QUALIFYING_MODES,
            "canonical_live_artifacts_used": args.qualification_mode == AS_LIVE_REQUAL,
            "live_source_snapshot": live_source_snapshot,
            "artifact_override_manifest": override_metadata,
            "execution_cost_evidence_manifest": execution_cost_metadata,
            "sandboxes": [str(path) for path in sandboxes],
            "sandbox_derivations": sandbox_derivation_rows,
            "common_root": str(common_root),
            "common_root_isolated_from_live": common_root != KNOWN_LIVE_COMMON.resolve(),
            "windows_identity": {
                "getpass_user": getpass.getuser(),
                "username": os.environ.get("USERNAME"),
                "userprofile": os.environ.get("USERPROFILE"),
                "appdata": os.environ.get("APPDATA"),
            },
            "reference_snapshot": reference_snapshot,
            "literal_dwx_only": True,
            "cost_registry": {
                "path": str(DEFAULT_COST_REGISTRY.resolve()),
                "sha256": cost_registry_sha_start,
            },
        }
    )
    if not args.execute:
        plan_path = output_root / "plan.json"
        plan_path.write_text(json.dumps(plan, indent=2, sort_keys=True), encoding="utf-8")
        print(json.dumps({"status": "PLAN_ONLY", "jobs": len(jobs), "output": str(output_root)}))
        return 0

    run_id = dt.datetime.now(dt.UTC).strftime("%Y%m%dT%H%M%SZ")
    execution_root = output_root / run_id
    execution_root.mkdir(parents=True, exist_ok=False)
    plan["run_id"] = run_id
    plan_path = execution_root / "plan.json"
    plan_path.write_text(json.dumps(plan, indent=2, sort_keys=True), encoding="utf-8")
    plan_sha = sha256_file(plan_path)

    blocked_receipts = [
        preflight_blocked_receipt(
            job,
            preflight_by_key[job.key],
            qualification_mode=args.qualification_mode,
            window_contract=window_contract,
            runner_sha256=runner_sha_start,
            artifact_override_manifest=override_metadata,
            execution_cost_evidence_manifest=execution_cost_metadata,
        )
        for job in jobs
        if preflight_by_key[job.key]
    ]
    for receipt in blocked_receipts:
        ordinal = int(receipt["job"]["ordinal"])
        job = next(item for item in jobs if item.ordinal == ordinal)
        run_dir = execution_root / "runs" / job.slug
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "receipt.json").write_text(
            json.dumps(receipt, indent=2, sort_keys=True), encoding="utf-8"
        )
    runnable_jobs = [job for job in jobs if not preflight_by_key[job.key]]
    executed_receipts: list[dict[str, Any]] = []
    if runnable_jobs:
        lock_paths = [common_root / "QM" / ".dxz_requal_sweep.lock"] + [
            root / ".qm_dxz_requal.lock" for root in sandboxes
        ]
        with execution_locks(lock_paths, token=run_id):
            executed_receipts = execute_book(
                runnable_jobs,
                sandboxes,
                execution_root,
                common_root,
                from_date=args.from_date,
                to_date=args.to_date,
                currency=args.currency.upper(),
                deposit=args.deposit,
                timeout_seconds=args.timeout_seconds,
                qualification_mode=args.qualification_mode,
                window_contract=window_contract,
                runner_sha256=runner_sha_start,
                artifact_override_manifest=override_metadata,
                execution_cost_evidence_manifest=execution_cost_metadata,
                sandbox_derivations=sandbox_derivations,
            )
    receipts = sorted(
        blocked_receipts + executed_receipts,
        key=lambda item: int((item.get("job") or {}).get("ordinal") or 0),
    )
    counts: dict[str, int] = {}
    technical_counts: dict[str, int] = {}
    for receipt in receipts:
        status = str(receipt.get("status") or "UNKNOWN")
        counts[status] = counts.get(status, 0) + 1
        technical = str(receipt.get("technical_status") or status or "UNKNOWN")
        technical_counts[technical] = technical_counts.get(technical, 0) + 1
    runner_sha_end = sha256_file(Path(__file__).resolve())
    manifest_sha_end = sha256_file(manifest_path)
    override_end_snapshot, override_end_errors = verify_artifact_override_unchanged(
        override_metadata
    )
    override_manifest_sha_end = (
        override_end_snapshot.get("manifest_sha256")
        if isinstance(override_end_snapshot, dict)
        else None
    )
    sandbox_derivations_end, sandbox_derivation_errors = (
        verify_target_sandbox_derivations_unchanged(sandbox_derivation_rows)
        if args.qualification_mode == TARGET_BINARY_REQUAL
        else ([], [])
    )
    live_source_snapshot_end = (
        snapshot_live_source_artifacts(live_root)
        if args.qualification_mode == TARGET_BINARY_REQUAL
        else None
    )
    cost_registry_sha_end = (
        sha256_file(DEFAULT_COST_REGISTRY) if DEFAULT_COST_REGISTRY.is_file() else None
    )
    execution_cost_unchanged, execution_cost_end_errors = (
        verify_execution_cost_evidence_unchanged(execution_cost_metadata)
    )
    execution_cost_axis_hashes_end = execution_cost_axis_hash_snapshot(
        execution_cost_metadata
    )
    execution_cost_manifest_end_sha = (
        sha256_file(execution_cost_manifest_path)
        if execution_cost_manifest_path is not None
        and execution_cost_manifest_path.is_file()
        else None
    )
    if require_reference:
        reference_snapshot_end, _ = verify_reference_snapshot(
            reference_root, source_manifest_sha256=manifest_sha
        )
    else:
        reference_snapshot_end = dict(reference_snapshot)
    global_blockers: list[str] = []
    if runner_sha_end != runner_sha_start:
        global_blockers.append("RUNNER_CHANGED_DURING_SWEEP")
    if manifest_sha_end != manifest_sha:
        global_blockers.append("SOURCE_MANIFEST_CHANGED_DURING_SWEEP")
    global_blockers.extend(override_end_errors)
    global_blockers.extend(sandbox_derivation_errors)
    if (
        args.qualification_mode == TARGET_BINARY_REQUAL
        and live_source_snapshot_end != live_source_snapshot
    ):
        global_blockers.append("T_LIVE_SOURCE_ARTIFACTS_CHANGED_DURING_SWEEP")
    if (
        cost_registry_sha_start is None
        or cost_registry_sha_end != cost_registry_sha_start
    ):
        global_blockers.append("COST_REGISTRY_CHANGED_OR_MISSING_DURING_SWEEP")
    if not execution_cost_unchanged:
        global_blockers.extend(execution_cost_end_errors)
    if canonical_json_sha(reference_snapshot_end) != canonical_json_sha(reference_snapshot):
        global_blockers.append("REFERENCE_SNAPSHOT_CHANGED_DURING_SWEEP")
    receipts_all_pass = technical_counts == {"PASS": len(jobs)}
    all_pass = receipts_all_pass and not global_blockers
    if args.qualification_mode in DISCOVERY_MODES and all_pass:
        summary_status = "NONQUALIFYING_DISCOVERY"
    elif all_pass:
        summary_status = "PASS" if scope == "FULL" else "PASS_PARTIAL"
    elif set(counts).issubset({"PASS", "BLOCKED"}) and counts.get("BLOCKED"):
        summary_status = "INCOMPLETE"
    else:
        summary_status = "FAIL"
    cost_rows = [
        receipt.get("cost_evidence")
        for receipt in receipts
        if isinstance(receipt.get("cost_evidence"), dict)
    ]
    cost_certified = bool(cost_rows) and len(cost_rows) == len(receipts) and all(
        row.get("status") == "CERTIFIED" and row.get("cost_certified") is True
        and set((row.get("axes") or {})) == set(EXECUTION_COST_AXES)
        and all(
            (row.get("axes") or {}).get(axis, {}).get("status") == "PASS"
            for axis in EXECUTION_COST_AXES
        )
        for row in cost_rows
    ) and execution_cost_metadata is not None and execution_cost_unchanged
    cost_status = (
        "CERTIFIED"
        if cost_certified
        else "NOT_EVALUATED"
        if cost_rows and all(row.get("status") == "NOT_EVALUATED" for row in cost_rows)
        else "DEGRADED"
    )
    summary_qualification_status = qualification_status(
        args.qualification_mode,
        technical_pass=all_pass,
        cost_certified=cost_certified,
    )
    summary = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_id,
        "status": summary_status,
        "technical_status": (
            "PASS" if all_pass else "FAIL"
        ),
        "qualification_mode": args.qualification_mode,
        "qualification_status": summary_qualification_status,
        "deployment_eligible": False,
        "window_contract": window_contract,
        "requested_from_date": window_contract["requested_from_date"],
        "requested_to_date": window_contract["requested_to_date"],
        "effective_from_date": window_contract["effective_from_date"],
        "effective_to_date": window_contract["effective_to_date"],
        "scope": scope,
        "counts": counts,
        "technical_counts": technical_counts,
        "global_blockers": global_blockers,
        "n_jobs": len(jobs),
        "manifest_jobs": manifest_job_count,
        "manifest_sha256": manifest_sha,
        "manifest_sha256_end": manifest_sha_end,
        "manifest_unchanged": manifest_sha == manifest_sha_end,
        "plan_path": str(plan_path),
        "plan_sha256": plan_sha,
        "runner_sha256": runner_sha_start,
        "runner_sha256_start": runner_sha_start,
        "runner_sha256_end": runner_sha_end,
        "runner_unchanged": runner_sha_start == runner_sha_end,
        "reference_snapshot": reference_snapshot,
        "reference_snapshot_end": reference_snapshot_end,
        "reference_snapshot_unchanged": not any(
            blocker == "REFERENCE_SNAPSHOT_CHANGED_DURING_SWEEP"
            for blocker in global_blockers
        ),
        "common_root": str(common_root),
        "common_root_isolated_from_live": True,
        "artifact_override_manifest": override_metadata,
        "artifact_override_manifest_sha256_end": override_manifest_sha_end,
        "artifact_override_end_snapshot": override_end_snapshot,
        "artifact_override_manifest_unchanged": not override_end_errors,
        "live_root": str(live_root),
        "canonical_live_root": str(DEFAULT_LIVE_ROOT.resolve()),
        "canonical_live_root_pinned": args.qualification_mode in QUALIFYING_MODES,
        "canonical_live_artifacts_used": args.qualification_mode == AS_LIVE_REQUAL,
        "live_source_snapshot": live_source_snapshot,
        "live_source_snapshot_end": live_source_snapshot_end,
        "live_source_unchanged": live_source_snapshot_end == live_source_snapshot,
        "sandbox_derivations": sandbox_derivation_rows,
        "sandbox_derivations_end": sandbox_derivations_end,
        "sandbox_derivations_unchanged": not sandbox_derivation_errors,
        "cost_evidence": {
            "status": cost_status,
            "cost_certified": cost_certified,
            "reasons": sorted(
                {
                    str(reason)
                    for row in cost_rows
                    for reason in (row.get("reasons") or [])
                }
            ),
            "required_axes": list(EXECUTION_COST_AXES),
            "axes": {
                axis: {
                    "status": (
                        "PASS"
                        if cost_rows
                        and len(cost_rows) == len(receipts)
                        and all(
                            (row.get("axes") or {}).get(axis, {}).get("status")
                            == "PASS"
                            for row in cost_rows
                        )
                        else "NOT_CERTIFIED"
                    ),
                    "pass_receipts": sum(
                        (row.get("axes") or {}).get(axis, {}).get("status") == "PASS"
                        for row in cost_rows
                    ),
                    "required_receipts": len(receipts),
                }
                for axis in EXECUTION_COST_AXES
            },
            "execution_cost_evidence_manifest": execution_cost_metadata,
            "registry_paths": sorted(
                {
                    str(row.get("registry_path"))
                    for row in cost_rows
                    if row.get("registry_path")
                }
            ),
            "registry_sha256s": sorted(
                {
                    str(row.get("registry_sha256"))
                    for row in cost_rows
                    if row.get("registry_sha256")
                }
            ),
            "unknown_symbols": sorted(
                {
                    str(symbol)
                    for row in cost_rows
                    for symbol in (row.get("unknown_symbols") or [])
                }
            ),
            "degraded_symbols": sorted(
                {
                    str(symbol)
                    for row in cost_rows
                    for symbol in (row.get("degraded_symbols") or [])
                }
            ),
        },
        "cost_registry": {
            "path": str(DEFAULT_COST_REGISTRY.resolve()),
            "sha256_start": cost_registry_sha_start,
            "sha256_end": cost_registry_sha_end,
            "unchanged": cost_registry_sha_start == cost_registry_sha_end,
        },
        "execution_cost_evidence_manifest": (
            {
                **execution_cost_metadata,
                "sha256_end": execution_cost_manifest_end_sha,
                "axis_hashes_end": execution_cost_axis_hashes_end,
                "unchanged": execution_cost_unchanged,
                "end_errors": execution_cost_end_errors,
            }
            if execution_cost_metadata is not None
            else None
        ),
        "cost_certified": cost_certified,
        "receipts": receipts,
    }
    summary["summary_sha256"] = canonical_json_sha(summary)
    summary_path = execution_root / "summary.json"
    summary_path.write_text(
        json.dumps(summary, indent=2, sort_keys=True), encoding="utf-8"
    )
    summary_file_sha = sha256_file(summary_path)
    summary_sidecar = summary_path.with_name(summary_path.name + ".sha256")
    with summary_sidecar.open("x", encoding="ascii", newline="\n") as handle:
        handle.write(f"{summary_file_sha}  {summary_path.name}\n")
    print(json.dumps({"status": summary["status"], "counts": counts, "output": str(execution_root)}))
    return 0 if all_pass else 2


if __name__ == "__main__":
    raise SystemExit(main())
