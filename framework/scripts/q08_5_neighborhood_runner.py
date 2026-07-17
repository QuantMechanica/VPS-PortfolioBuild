"""Q08.5 — Neighborhood Stability runner.

Produces the `perturbations.json` consumed by `q08_davey/sub_8_5_neighborhood.py`.

For each numeric parameter chosen at Q03 plateau-median, fires three
backtests at the param's nominal value AND at ±10% perturbations,
keeping all other parameters at their plateau-median. Captures PF and
DD per perturbation; the sub-gate then checks:

  - every perturbation must have PF > 1.0
  - every perturbation's DD must be < 1.5 × baseline DD

Output:
    D:/QM/reports/pipeline/QM5_<id>/Q08/neighborhood/<symbol>/perturbations.json
    {
      "baseline":     {"pf": 1.42, "dd": 8500, "trades": 220, "params": {...}},
      "perturbations":[
        {"param": "fast_ema",  "delta": "-10pct", "value": 18, "pf": 1.35, "dd": 9100, "trades": 215},
        {"param": "fast_ema",  "delta": "+10pct", "value": 22, "pf": 1.38, "dd": 8800, "trades": 218},
        ...
      ],
      "generated_at_utc": "...",
      "ea_id": 1056, "symbol": "NDX.DWX"
    }

Reads the Q03 plateau pick from:
    D:/QM/reports/pipeline/QM5_<id>/Q03/<symbol>/plateau_pick.json
(written by the future Q03 sweep runner update; for now this is the
contract that runner must produce.)
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import period_from_setfile
from framework.scripts.q05_stress_medium import summary_invalid_reason

# Wrapper must outlive the tester budget, or a run finishing at the buzzer
# loses its summary write (2026-07-06 audit G16; mirrors q05/q06).
RUNNER_HEADROOM_SEC = 120

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json
from framework.scripts.q05_stress_medium import _parse_pf_dd_trades

GATE_NAME = "Q08.5_neighborhood"
PERTURBATION_PCT = 10.0
EVIDENCE_SCHEMA_VERSION = 2
ENGINE_VERSION = "q08_neighborhood_param_type_aware_v2"
MIN_VALID_PERTURBATIONS = 2
NON_STRATEGY_PREFIXES = ("qm_", "RISK_")
NON_PERTURBABLE_NAME_TOKENS = (
    "enabled",
    "mode",
    "use_",
    "no_",
    "direction",
)
STRUCTURAL_PARAM_PATTERNS = (
    r"(?:^|_)beta(?:_|$)",
    r"(?:^|_)hedge_ratio(?:_|$)",
    r"(?:^|_)regression_(?:slope|coef|coefficient)(?:_|$)",
    r"(?:^|_)cointegration_(?:slope|coef|coefficient)(?:_|$)",
    r"(?:^|_)pca_(?:loading|weight)(?:_|$)",
    r"(?:^|_)eigen(?:vector|weight)(?:_|$)",
    r"(?:^|_)fitted_(?:slope|coef|coefficient)(?:_|$)",
    r"(?:^|_)(?:pair|symbol|instrument|leg)_(?:a|b|1|2|left|right|long|short)(?:_|$)",
    r"(?:^|_)(?:pair|pair_id|pair_name|pair_selection)(?:_|$)",
)
DISCRETE_CALENDAR_PATTERNS = (
    r"(?:^|_)(?:day_of_week|weekday)(?:_|$)",
    r"(?:^|_)(?:month_of_year|entry_month|exit_month|trade_month|calendar_month)(?:_|$)",
    r"(?:^|_)session_(?:start|end|open|close)(?:_(?:hour|minute|hhmm))?(?:_|$)",
    r"(?:^|_)(?:lookback|window|holding|entry|exit)_sessions?(?:_|$)",
    r"(?:^|_)(?:hour|minute|hhmm)(?:_|$)",
    r"(?:^|_)trading_days?(?:_|$)",
    r"(?:^|_)days?_(?:before|after)(?:_|$)",
    r"(?:^|_)window_days?(?:_|$)",
    r"(?:^|_)(?:entry|exit)_day(?:_|$)",
)


def _is_framework_param(key: str) -> bool:
    lowered = key.casefold()
    return (
        lowered.startswith("qm_")
        or key.upper().startswith("RISK_")
        or key.upper() == "PORTFOLIO_WEIGHT"
    )


def _parse_scalar(raw: str) -> bool | int | float | None:
    token = raw.strip()
    if token.casefold() == "true":
        return True
    if token.casefold() == "false":
        return False
    if re.fullmatch(r"[-+]?\d+", token):
        try:
            return int(token)
        except ValueError:
            return None
    try:
        value = float(token)
    except ValueError:
        return None
    return value if math.isfinite(value) else None


def parse_setfile_assignments(setfile_path: Path) -> dict[str, dict[str, Any]]:
    """Parse the strategy block, including MT5 optimiser step metadata.

    MT5 setfiles may encode ``value||start||step||stop||Y/N``.  Q08 uses the
    first cell as the active value and the third cell as the lattice/stepsize.
    Duplicate or empty strategy assignments are rejected fail-closed.
    """
    if not setfile_path.exists():
        raise FileNotFoundError(f"baseline setfile missing: {setfile_path}")
    text = setfile_path.read_text(encoding="utf-8-sig", errors="replace")
    in_strategy_block = False
    assignments: dict[str, dict[str, Any]] = {}
    for line_number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if line.casefold().startswith("; strategy-specific params"):
            in_strategy_block = True
            continue
        if not in_strategy_block or not line or line.startswith(";") or "=" not in line:
            continue
        key, rhs = line.split("=", 1)
        key = key.strip()
        rhs = rhs.strip()
        if not key or _is_framework_param(key):
            continue
        if key in assignments:
            raise ValueError(f"duplicate strategy parameter {key}: {setfile_path}")
        if not rhs:
            raise ValueError(f"empty strategy parameter {key}: {setfile_path}")
        cells = [cell.strip() for cell in rhs.split("||")]
        active = _parse_scalar(cells[0])
        step = _parse_scalar(cells[2]) if len(cells) >= 4 else None
        minimum = _parse_scalar(cells[1]) if len(cells) >= 4 else None
        maximum = _parse_scalar(cells[3]) if len(cells) >= 4 else None
        assignments[key] = {
            "value": active,
            "raw_rhs": rhs,
            "cells": cells,
            "step": step if isinstance(step, (int, float)) and not isinstance(step, bool) else None,
            "minimum": minimum if isinstance(minimum, (int, float)) and not isinstance(minimum, bool) else None,
            "maximum": maximum if isinstance(maximum, (int, float)) and not isinstance(maximum, bool) else None,
            "line_number": line_number,
        }
    return assignments


def inspect_baseline_setfile(setfile_path: Path, expected_symbol: str | None = None) -> dict:
    """Return fail-closed identity metadata for a neighborhood baseline."""
    if not setfile_path.exists():
        raise FileNotFoundError(f"baseline setfile missing: {setfile_path}")

    raw_bytes = setfile_path.read_bytes()
    text = raw_bytes.decode("utf-8-sig", errors="replace")
    declared_symbol: str | None = None
    host_symbol: str | None = None
    for raw in text.splitlines():
        line = raw.strip()
        symbol_match = re.match(r";\s*symbol\s*:\s*(\S+)", line, flags=re.IGNORECASE)
        if symbol_match:
            declared_symbol = symbol_match.group(1).strip()
        host_match = re.match(r";\s*host_symbol\s*:\s*(\S+)", line, flags=re.IGNORECASE)
        if host_match:
            host_symbol = host_match.group(1).strip()
    assignments = parse_setfile_assignments(setfile_path)
    if expected_symbol:
        if not declared_symbol:
            raise ValueError(
                f"baseline setfile missing '; symbol:' metadata: {setfile_path}"
            )
        if declared_symbol.casefold() != expected_symbol.casefold():
            raise ValueError(
                "baseline setfile symbol mismatch: "
                f"expected={expected_symbol} declared={declared_symbol} path={setfile_path}"
            )
    if not assignments:
        raise ValueError(f"baseline setfile has no strategy parameters: {setfile_path}")
    return {
        "path": str(setfile_path.resolve()),
        "sha256": hashlib.sha256(raw_bytes).hexdigest(),
        "declared_symbol": declared_symbol,
        "host_symbol": host_symbol,
        "strategy_param_count": len(assignments),
        "strategy_param_names": list(assignments),
    }


def classify_param(
        key: str, value: Any, metadata: dict[str, Any] | None = None,
        declared_type: str | None = None) -> dict[str, Any]:
    """Classify one strategy input under the OWNER parameter-type rule."""
    lowered = key.casefold()
    override = str(declared_type or "").strip().casefold()
    if override in {"continuous", "discrete", "structural", "fixed"}:
        return {"class": override, "reason": "declared_metadata"}
    if _is_framework_param(key):
        return {"class": "fixed", "reason": "framework_or_risk"}
    if any(token in lowered for token in NON_PERTURBABLE_NAME_TOKENS):
        return {"class": "fixed", "reason": "categorical_or_enable_flag"}
    if any(re.search(pattern, lowered) for pattern in STRUCTURAL_PARAM_PATTERNS):
        return {"class": "structural", "reason": "fitted_or_structural_coefficient"}
    if any(re.search(pattern, lowered) for pattern in DISCRETE_CALENDAR_PATTERNS):
        return {"class": "discrete", "reason": "calendar_or_ordinal_lattice"}
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return {"class": "fixed", "reason": "categorical_or_nonnumeric"}
    if float(value) == 0.0:
        return {"class": "fixed", "reason": "zero_sentinel"}
    step = (metadata or {}).get("step")
    return {
        "class": "continuous",
        "reason": "numeric_tuning_knob",
        "step": step,
    }


def is_perturbable_param(key: str, value: int | float) -> bool:
    return classify_param(key, value)["class"] in {"continuous", "discrete"}


def load_plateau_pick(plateau_path: Path) -> dict:
    """Load Q03's plateau-median parameter pick.

    Expected schema (contract with the Q03 runner):
      {"params": {"fast_ema": 20, "slow_ema": 50, "atr_mult": 2.0},
       "baseline_pf": 1.42, "baseline_dd": 8500, ...}
    """
    if not plateau_path.exists():
        raise FileNotFoundError(f"Q03 plateau pick missing: {plateau_path}")
    data = json.loads(plateau_path.read_text(encoding="utf-8"))
    if "params" not in data:
        raise ValueError(f"plateau_pick.json missing 'params' key: {plateau_path}")
    return data


def load_params_from_setfile(setfile_path: Path) -> dict:
    """Fallback when Q03 did not publish plateau_pick.json yet."""
    identity = inspect_baseline_setfile(setfile_path)
    assignments = parse_setfile_assignments(setfile_path)
    params: dict[str, int | float] = {}
    for key, meta in assignments.items():
        parsed = meta["value"]
        if not isinstance(parsed, (int, float)) or isinstance(parsed, bool):
            continue
        if classify_param(key, parsed, meta)["class"] == "fixed":
            continue
        params[key] = parsed
    source_type = "baseline_setfile" if params else "baseline_setfile_no_perturbable_numeric_params"
    return {
        "params": params,
        "param_metadata": assignments,
        "source": str(setfile_path),
        "source_type": source_type,
        "strategy_param_count": identity["strategy_param_count"],
    }


def _within_bounds(value: int | float, metadata: dict[str, Any]) -> bool:
    minimum = metadata.get("minimum")
    maximum = metadata.get("maximum")
    numeric_minimum = (
        float(minimum)
        if isinstance(minimum, (int, float)) and not isinstance(minimum, bool)
        else None
    )
    numeric_maximum = (
        float(maximum)
        if isinstance(maximum, (int, float)) and not isinstance(maximum, bool)
        else None
    )
    if numeric_minimum is not None and float(value) < numeric_minimum:
        return False
    if numeric_maximum is not None and float(value) > numeric_maximum:
        return False
    return True


def parameter_perturbations(
        key: str, value: int | float, metadata: dict[str, Any] | None,
        pct: float, declared_type: str | None = None) -> list[dict[str, Any]]:
    """Return distinct, in-range perturbations for one classified parameter."""
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return []
    meta = metadata or {}
    classification = classify_param(key, value, meta, declared_type)
    param_class = classification["class"]
    if param_class not in {"continuous", "discrete"}:
        return []

    lowered = key.casefold()
    candidates: list[tuple[str, int | float]] = []
    if param_class == "discrete" and "hhmm" in lowered:
        hour, minute = divmod(int(value), 100)
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            return []
        total_minutes = hour * 60 + minute
        for sign, label in ((-1, "-1step"), (1, "+1step")):
            shifted = total_minutes + sign * 60
            if 0 <= shifted < 24 * 60:
                candidates.append((label, (shifted // 60) * 100 + shifted % 60))
    else:
        metadata_step = meta.get("step")
        usable_step = (
            abs(float(metadata_step))
            if isinstance(metadata_step, (int, float))
            and not isinstance(metadata_step, bool)
            and float(metadata_step) != 0.0
            else None
        )
        if param_class == "discrete":
            delta = usable_step or 1.0
            labels = ("-1step", "+1step")
        else:
            raw_delta = abs(float(value)) * pct / 100.0
            if isinstance(value, int):
                raw_delta = max(1.0, raw_delta)
            if raw_delta == 0.0:
                return []
            if usable_step:
                delta = max(usable_step, math.ceil(raw_delta / usable_step) * usable_step)
            else:
                delta = raw_delta
            labels = (f"-{pct:g}pct", f"+{pct:g}pct")
        for sign, label in ((-1, labels[0]), (1, labels[1])):
            candidate: int | float = float(value) + sign * delta
            if isinstance(value, int):
                candidate = int(round(candidate))
            else:
                candidate = round(float(candidate), 12)
            candidates.append((label, candidate))

    out: list[dict[str, Any]] = []
    seen: set[tuple[type, int | float]] = set()
    for label, candidate in candidates:
        if candidate == value or not _within_bounds(candidate, meta):
            continue
        marker = (type(candidate), candidate)
        if marker in seen:
            continue
        seen.add(marker)
        out.append({
            "delta": label,
            "value": candidate,
            "param_class": param_class,
            "classification_reason": classification["reason"],
        })
    return out


def numeric_perturbation(value, pct: float):
    """Backward-compatible pair helper for continuous numeric parameters."""
    rows = parameter_perturbations("strategy_numeric", value, {}, pct, "continuous")
    return tuple(row["value"] for row in rows) if len(rows) == 2 else None


def _format_setfile_scalar(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float) and math.isfinite(value):
        # ``repr`` is the shortest decimal that round-trips to the same binary
        # float.  A 15-digit format silently changed fitted constants such as
        # QM5_13117's beta and then tripped our own exact materialization check.
        return repr(value)
    if isinstance(value, str):
        token = value.strip()
        if token and "\n" not in token and "\r" not in token and "||" not in token:
            return token
    raise ValueError(f"unsupported setfile scalar: {value!r}")


def materialize_setfile(source_set: Path, overrides: dict[str, Any], out_path: Path) -> dict:
    """Apply only known assignments and prove the generated set remains complete."""
    source_assignments = parse_setfile_assignments(source_set)
    missing = sorted(set(overrides) - set(source_assignments))
    if missing:
        raise ValueError(f"setfile override parameters missing from baseline: {','.join(missing)}")
    text = source_set.read_text(encoding="utf-8-sig", errors="replace")
    for key, value in overrides.items():
        original = source_assignments[key]
        cells = list(original["cells"])
        cells[0] = _format_setfile_scalar(value)
        if len(cells) >= 5:
            cells[4] = "N"
        replacement = f"{key}={'||'.join(cells)}"
        pattern = re.compile(rf"^{re.escape(key)}\s*=.*$", flags=re.MULTILINE)
        text, count = pattern.subn(lambda _match: replacement, text)
        if count != 1:
            raise ValueError(f"setfile override count for {key}: got={count}:need=1")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text, encoding="utf-8")

    generated = parse_setfile_assignments(out_path)
    if set(generated) != set(source_assignments):
        raise ValueError("generated setfile changed strategy parameter inventory")
    for key, original in source_assignments.items():
        if key in overrides:
            expected = overrides[key]
            if isinstance(expected, str):
                matches = generated[key]["cells"][0] == expected.strip()
            else:
                matches = generated[key]["value"] == expected
            if not matches:
                raise ValueError(
                    f"generated setfile value mismatch for {key}: "
                    f"got={generated[key]['cells'][0]!r}:expected={expected!r}"
                )
        elif generated[key]["cells"] != original["cells"]:
            raise ValueError(f"generated setfile changed untouched parameter {key}")
        if len(original["cells"]) > 1 and generated[key]["cells"][1:4] != original["cells"][1:4]:
            raise ValueError(f"generated setfile changed optimiser lattice for {key}")
    raw = out_path.read_bytes()
    return {
        "path": str(out_path.resolve()),
        "sha256": hashlib.sha256(raw).hexdigest(),
        "strategy_param_count": len(generated),
    }


def write_perturbation_setfile(baseline_set: Path, param: str, value, out_dir: Path) -> Path:
    """Write and validate a setfile with exactly one strategy override."""
    safe_value = re.sub(r"[^A-Za-z0-9_.-]+", "_", _format_setfile_scalar(value))
    out_path = out_dir / f"{baseline_set.stem}_perturb_{param}_{safe_value}.set"
    materialize_setfile(baseline_set, {param: value}, out_path)
    return out_path


def _normalize_expert(expert: str | None) -> str:
    value = str(expert or "").strip().replace("/", "\\")
    return re.sub(r"\.ex5$", "", value.rsplit("\\", 1)[-1], flags=re.IGNORECASE).casefold()


def _summary_matches_invocation(
        summary_path: Path, *, started_at: float, ea_id: int, ea_expert: str,
        symbol: str, period: str, terminal: str) -> bool:
    try:
        if summary_path.stat().st_mtime < started_at:
            return False
        data = json.loads(summary_path.read_text(encoding="utf-8-sig"))
        summary_ea_id = int(data.get("ea_id"))
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return False
    return (
        summary_ea_id == ea_id
        and _normalize_expert(data.get("expert")) == _normalize_expert(ea_expert)
        and str(data.get("symbol") or "").strip().casefold() == symbol.strip().casefold()
        and str(data.get("period") or "").strip().casefold() == period.strip().casefold()
        and str(data.get("terminal") or "").strip().casefold() == terminal.strip().casefold()
    )


def latest_run_smoke_summary(
        report_root: Path, ea_id: int, started_at: float, *, ea_expert: str | None = None,
        symbol: str | None = None, period: str | None = None,
        terminal: str | None = None) -> Path | None:
    """Return a fresh exact-identity summary; never fall back to stale evidence."""
    base = Path(report_root) / f"QM5_{ea_id}"
    if not base.exists():
        return None
    candidates: list[tuple[float, Path]] = []
    for summary in base.rglob("summary.json"):
        try:
            mtime = summary.stat().st_mtime
        except OSError:
            continue
        if mtime >= started_at:
            candidates.append((mtime, summary))
    for _mtime, summary in sorted(candidates, reverse=True):
        if all(value is not None for value in (ea_expert, symbol, period, terminal)):
            if not _summary_matches_invocation(
                    summary, started_at=started_at, ea_id=ea_id,
                    ea_expert=str(ea_expert), symbol=str(symbol), period=str(period),
                    terminal=str(terminal)):
                continue
        return summary
    return None


def _summary_from_run_smoke_output(
        output_text: str, *, started_at: float, ea_id: int, ea_expert: str,
        symbol: str, period: str, terminal: str) -> Path | None:
    matches = list(re.finditer(
        r"(?m)^run_smoke\.summary=(?P<path>.+?)\s*$",
        output_text or "",
    ))
    for match in reversed(matches):
        path = Path(match.group("path").strip().strip('"'))
        if _summary_matches_invocation(
                path, started_at=started_at, ea_id=ea_id, ea_expert=ea_expert,
                symbol=symbol, period=period, terminal=terminal):
            return path
    return None


def resolve_ea_expert(ea_label: str, ea_id: int) -> str:
    repo_root = Path(__file__).resolve().parents[2]
    if ea_label.startswith("QM\\"):
        return ea_label
    if "_" in ea_label.replace(f"QM5_{ea_id}", "", 1).strip("_"):
        return f"QM\\{ea_label}"
    ea_dirs = sorted(
        d for d in (repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*")
        if d.is_dir()
    )
    return f"QM\\{ea_dirs[0].name}" if ea_dirs else f"QM\\{ea_label}"


def fire_backtest_details(*, ea_id: int, ea_expert: str, symbol: str,
                          setfile: Path, terminal: str, run_tag: str,
                          report_root: Path, timeout_sec: int = 900,
                          period: str = "H1", from_date: str = "2017.01.01",
                          to_date: str = "2025.12.31") -> dict[str, Any]:
    """Run one child backtest and bind metrics to its exact fresh summary."""
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        # Full-history window — matches the canonical Q08 baseline (q08_davey/aggregate.py).
        # Was "-Year 0" with no date range, which made run_smoke build fromDate="0.01.01"
        # (an invalid year-0 window) -> 0 trades on EVERY perturbation INCLUDING the baseline
        # -> 8.5 FAILed every EA falsely (167/167 runs had a 0-trade baseline). 2026-06-26 fix.
        "-Year", str(to_date).split(".", 1)[0],
        "-FromDate", from_date,
        "-ToDate", to_date,
        "-Terminal", terminal,
        # 2026-07-06 audit G6: was hardcoded "H1" — non-H1 EAs got their entire
        # plateau evidence generated on the wrong chart timeframe (the exact
        # class period_from_setfile was created for).
        "-Period", period,
        "-DispatchSubGateHash", run_tag,
        "-DispatchPhase", "Q08.5",
        "-DispatchVersion", "q08_neighborhood",
        "-Runs", "1",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    started_at = time.time()
    output_parts: list[str] = []
    return_code: int | None = None
    timed_out = False
    try:
        proc = subprocess.run(
            args, capture_output=True, text=True,
            timeout=timeout_sec + RUNNER_HEADROOM_SEC,
            creationflags=creationflags,
        )
        return_code = proc.returncode
        output_parts.extend([str(proc.stdout or ""), str(proc.stderr or "")])
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        for raw in (exc.stdout, exc.stderr):
            if isinstance(raw, bytes):
                output_parts.append(raw.decode("utf-8", errors="replace"))
            elif raw:
                output_parts.append(str(raw))
    output_text = "\n".join(output_parts)
    # The stdout marker is the only authoritative binding to this child run.
    # An EA/symbol/period scan cannot distinguish two sequential perturbations
    # and can silently reuse the immediately preceding config's summary.
    summary = _summary_from_run_smoke_output(
        output_text, started_at=started_at, ea_id=ea_id, ea_expert=ea_expert,
        symbol=symbol, period=period, terminal=terminal,
    )
    result: dict[str, Any] = {
        "pf": None,
        "dd": None,
        "trades": 0,
        "status": "INVALID",
        "invalid_reason": "timeout" if timed_out else "summary_missing_or_identity_mismatch",
        "summary_path": str(summary.resolve()) if summary is not None else None,
        "report_path": None,
        "run_smoke_return_code": return_code,
        "run_started_at": started_at,
        "effective_symbol": symbol,
        "period": period,
        "from_date": from_date,
        "to_date": to_date,
        "terminal": terminal,
    }
    if summary is None:
        return result
    invalid_reason = summary_invalid_reason(summary)
    if invalid_reason:
        result["invalid_reason"] = str(invalid_reason)
        return result
    pf, dd, trades = _parse_pf_dd_trades(summary)
    result.update({"pf": pf, "dd": dd, "trades": trades})
    try:
        summary_data = json.loads(summary.read_text(encoding="utf-8-sig"))
        for run in summary_data.get("runs") or []:
            report_path = run.get("report_canonical_path") or run.get("report_source_path")
            if report_path:
                result["report_path"] = str(Path(report_path).resolve())
                break
    except (OSError, json.JSONDecodeError):
        pass
    if pf is None or dd is None:
        result["invalid_reason"] = "report_metrics_missing"
    elif int(trades or 0) <= 0:
        result["invalid_reason"] = "zero_trades"
    else:
        result["status"] = "VALID"
        result["invalid_reason"] = None
    return result


def fire_backtest(*, ea_id: int, ea_expert: str, symbol: str,
                   setfile: Path, terminal: str, run_tag: str,
                   report_root: Path, timeout_sec: int = 900,
                   period: str = "H1", from_date: str = "2017.01.01",
                   to_date: str = "2025.12.31") -> tuple[float | None, float | None, int]:
    """Backward-compatible metric tuple wrapper."""
    result = fire_backtest_details(
        ea_id=ea_id, ea_expert=ea_expert, symbol=symbol, setfile=setfile,
        terminal=terminal, run_tag=run_tag, report_root=report_root,
        timeout_sec=timeout_sec, period=period, from_date=from_date,
        to_date=to_date,
    )
    return result["pf"], result["dd"], int(result["trades"] or 0)


def resolve_backtest_context(
        baseline_setfile: Path, logical_symbol: str, period: str,
        timeout_sec: int, from_date: str | None = None,
        to_date: str | None = None) -> dict[str, Any]:
    """Resolve basket host symbol and the intersection of validated history."""
    identity = inspect_baseline_setfile(baseline_setfile, logical_symbol)
    tester_symbol = str(identity.get("host_symbol") or logical_symbol)
    manifest_path = baseline_setfile.parent.parent / "basket_manifest.json"
    manifest: dict[str, Any] = {}
    if manifest_path.exists():
        try:
            candidate = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
            if str(candidate.get("logical_symbol") or "").casefold() == logical_symbol.casefold():
                manifest = candidate
                tester_symbol = str(candidate.get("host_symbol") or tester_symbol)
                period = str(candidate.get("host_timeframe") or period)
        except (OSError, json.JSONDecodeError):
            manifest = {}

    is_basket = tester_symbol.casefold() != logical_symbol.casefold()
    effective_from = from_date or ("2018.07.02" if is_basket else "2017.01.01")
    effective_to = to_date or "2025.12.31"
    latest_full_year = manifest.get("latest_full_year")
    if is_basket and not latest_full_year:
        symbols = {
            str(symbol).casefold() for symbol in (manifest.get("basket_symbols") or [tester_symbol])
        }
        registry = Path(__file__).resolve().parents[1] / "registry" / "dwx_symbol_history_ranges.csv"
        years: list[int] = []
        try:
            with registry.open("r", encoding="utf-8-sig", newline="") as handle:
                for row in csv.DictReader(handle):
                    if (
                        str(row.get("symbol") or "").casefold() in symbols
                        and str(row.get("period") or "").casefold() == period.casefold()
                    ):
                        years.append(int(row["last_year"]))
        except (OSError, TypeError, ValueError):
            years = []
        if years:
            latest_full_year = min(years)
    if is_basket and latest_full_year and not to_date:
        effective_to = f"{int(latest_full_year)}.12.31"
    effective_timeout = max(timeout_sec, 3600) if is_basket else timeout_sec
    return {
        "logical_symbol": logical_symbol,
        "tester_symbol": tester_symbol,
        "period": period,
        "from_date": effective_from,
        "to_date": effective_to,
        "timeout_sec": effective_timeout,
        "is_basket": is_basket,
        "manifest_path": str(manifest_path.resolve()) if manifest_path.exists() else None,
        "latest_full_year": int(latest_full_year) if latest_full_year else None,
    }


def write_artifact_atomic(path: Path, payload: dict[str, Any]) -> None:
    temp_path = path.with_name(f".{path.name}.{time.time_ns()}.tmp")
    write_json(temp_path, payload)
    temp_path.replace(path)


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08.5 Neighborhood Stability runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile (used as the nominal centre)")
    ap.add_argument("--plateau-pick", type=Path,
                    help="Q03 plateau_pick.json (autodetected from --ea/--symbol if absent)")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=900)
    ap.add_argument("--from-date",
                    help="Explicit validated history start (YYYY.MM.DD)")
    ap.add_argument("--to-date",
                    help="Explicit validated history end (YYYY.MM.DD)")
    ap.add_argument("--max-params", type=int, default=8,
                    help="Cap on params perturbed (skip after N to bound compute)")
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))
    ea_expert = resolve_ea_expert(args.ea, ea_id)
    sym_clean = args.symbol.replace(".", "_")

    try:
        baseline_identity = inspect_baseline_setfile(args.baseline_setfile, args.symbol)
    except (FileNotFoundError, ValueError) as exc:
        print(f"Q08.5 invalid baseline setfile: {exc}", file=sys.stderr)
        return 2

    plateau_path = args.plateau_pick or (
        args.report_root / f"QM5_{ea_id}" / "Q03" / sym_clean / "plateau_pick.json"
    )
    try:
        pick = load_plateau_pick(plateau_path)
        pick_source = str(plateau_path.resolve())
        pick_source_type = "plateau_pick"
    except FileNotFoundError:
        pick = load_params_from_setfile(args.baseline_setfile)
        pick_source = baseline_identity["path"]
        pick_source_type = "baseline_setfile_fallback"
    try:
        pick_source_sha256 = hashlib.sha256(Path(pick_source).read_bytes()).hexdigest()
    except OSError as exc:
        print(f"Q08.5 parameter source unreadable: {pick_source}: {exc}", file=sys.stderr)
        return 2
    params = pick["params"]
    if not isinstance(params, dict):
        print(f"Q08.5 params is not a dict: {pick_source}", file=sys.stderr)
        return 2

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q08" / "neighborhood" / sym_clean)
    setfile_dir = ensure_dir(out_dir / "setfiles")

    period = period_from_setfile(args.baseline_setfile)
    context = resolve_backtest_context(
        args.baseline_setfile, args.symbol, period, args.timeout_sec,
        args.from_date, args.to_date,
    )
    period = str(context["period"])
    baseline_assignments = parse_setfile_assignments(args.baseline_setfile)
    param_type_overrides = dict(pick.get("param_types") or {})
    metadata_block = pick.get("param_metadata") or pick.get("metadata") or {}
    if isinstance(metadata_block, dict):
        for key, value in metadata_block.items():
            if isinstance(value, dict) and value.get("type"):
                param_type_overrides.setdefault(key, value["type"])

    nominal_overrides: dict[str, Any] = {}
    for key, value in params.items():
        if not isinstance(value, (bool, int, float, str)):
            print(f"Q08.5 unsupported plateau value: {key}={value!r}", file=sys.stderr)
            return 2
        nominal_overrides[key] = value
    nominal_path = setfile_dir / f"{args.baseline_setfile.stem}_neighborhood_nominal.set"
    try:
        nominal_identity = materialize_setfile(
            args.baseline_setfile,
            nominal_overrides,
            nominal_path,
        )
    except (OSError, ValueError) as exc:
        print(f"Q08.5 nominal setfile materialization failed: {exc}", file=sys.stderr)
        return 2
    nominal_assignments = parse_setfile_assignments(nominal_path)

    classified_params = list(sorted(params.items()))
    classifications: list[dict[str, Any]] = []
    eligible: list[tuple[str, int | float, list[dict[str, Any]]]] = []
    for key, value in classified_params:
        metadata = baseline_assignments.get(key) or {}
        classification = classify_param(
            key, value, metadata, param_type_overrides.get(key),
        )
        candidates = parameter_perturbations(
            key, value, metadata, PERTURBATION_PCT, param_type_overrides.get(key),
        )
        row = {
            "param": key,
            "nominal": value,
            **classification,
            "candidate_values": [candidate["value"] for candidate in candidates],
        }
        classifications.append(row)
        if candidates:
            eligible.append((key, value, candidates))

    chosen = eligible[:max(0, args.max_params)]
    print(
        f"Q08.5 {args.ea} {args.symbol}: {len(chosen)}/{len(eligible)} eligible "
        f"params; tester={context['tester_symbol']} {period} "
        f"{context['from_date']}..{context['to_date']}"
    )

    baseline_result = fire_backtest_details(
        ea_id=ea_id, ea_expert=ea_expert, symbol=str(context["tester_symbol"]),
        setfile=nominal_path, terminal=args.terminal, run_tag="baseline",
        report_root=args.report_root, timeout_sec=int(context["timeout_sec"]),
        period=period, from_date=str(context["from_date"]),
        to_date=str(context["to_date"]),
    )
    baseline_result.update({
        "params": {key: meta["value"] for key, meta in nominal_assignments.items()},
        "setfile_path": nominal_identity["path"],
        "setfile_sha256": nominal_identity["sha256"],
        "config_id": f"neighborhood_{nominal_identity['sha256'][:16]}",
    })
    print(
        f"  baseline -> status={baseline_result['status']} PF={baseline_result['pf']} "
        f"DD={baseline_result['dd']} trades={baseline_result['trades']}"
    )

    perturbations: list[dict[str, Any]] = []
    seen_hashes = {nominal_identity["sha256"]}
    for param_name, _nominal, candidates in chosen:
        for candidate in candidates:
            label = str(candidate["delta"])
            value = candidate["value"]
            run_tag = f"{param_name}_{label.replace('-', 'neg').replace('+', 'pos')}"
            try:
                setfile = write_perturbation_setfile(
                    nominal_path, param_name, value, setfile_dir,
                )
                set_identity = {
                    "path": str(setfile.resolve()),
                    "sha256": hashlib.sha256(setfile.read_bytes()).hexdigest(),
                }
            except (OSError, ValueError) as exc:
                perturbations.append({
                    "param": param_name,
                    "delta": label,
                    "value": value,
                    "param_class": candidate["param_class"],
                    "status": "INVALID",
                    "invalid_reason": f"setfile_materialization:{type(exc).__name__}:{exc}",
                    "pf": None,
                    "dd": None,
                    "trades": 0,
                })
                continue
            if set_identity["sha256"] in seen_hashes:
                perturbations.append({
                    "param": param_name,
                    "delta": label,
                    "value": value,
                    "param_class": candidate["param_class"],
                    "status": "INVALID",
                    "invalid_reason": "duplicate_effective_config",
                    "pf": None,
                    "dd": None,
                    "trades": 0,
                    "setfile_path": set_identity["path"],
                    "setfile_sha256": set_identity["sha256"],
                })
                continue
            seen_hashes.add(set_identity["sha256"])
            print(f"  perturb {param_name}={value} ({label})...")
            result = fire_backtest_details(
                ea_id=ea_id, ea_expert=ea_expert,
                symbol=str(context["tester_symbol"]), setfile=setfile,
                terminal=args.terminal, run_tag=run_tag,
                report_root=args.report_root, timeout_sec=int(context["timeout_sec"]),
                period=period, from_date=str(context["from_date"]),
                to_date=str(context["to_date"]),
            )
            result.update({
                "param": param_name,
                "delta": label,
                "value": value,
                "param_class": candidate["param_class"],
                "classification_reason": candidate["classification_reason"],
                "setfile_path": set_identity["path"],
                "setfile_sha256": set_identity["sha256"],
                "config_id": f"neighborhood_{set_identity['sha256'][:16]}",
            })
            perturbations.append(result)
            print(
                f"    -> status={result['status']} PF={result['pf']} "
                f"DD={result['dd']} trades={result['trades']}"
            )

    valid_perturbations = [row for row in perturbations if row.get("status") == "VALID"]
    invalid_perturbations = [row for row in perturbations if row.get("status") != "VALID"]
    if baseline_result["status"] != "VALID":
        evidence_status = "INVALID_BASELINE"
    elif len(valid_perturbations) >= MIN_VALID_PERTURBATIONS:
        evidence_status = "VALID"
    elif not eligible:
        evidence_status = "INVALID_NO_PERTURBABLE_PARAMS"
    else:
        evidence_status = "INVALID_INSUFFICIENT_VALID_PERTURBATIONS"
    excluded_classes = {row["class"] for row in classifications if not row["candidate_values"]}
    structurally_inapplicable = bool(classifications) and not eligible and excluded_classes <= {
        "fixed", "structural"
    }

    payload = {
        "schema_version": EVIDENCE_SCHEMA_VERSION,
        "engine_version": ENGINE_VERSION,
        "ea_id": ea_id,
        "symbol": args.symbol,
        "ea_expert": ea_expert,
        "perturbation_pct": PERTURBATION_PCT,
        "minimum_valid_perturbations": MIN_VALID_PERTURBATIONS,
        "backtest_context": context,
        "baseline": baseline_result,
        "perturbations": perturbations,
        "param_classifications": classifications,
        "n_params_in_pick": len(classified_params),
        "n_params_eligible": len(eligible),
        "n_params_tested": len(chosen),
        "n_valid_perturbations": len(valid_perturbations),
        "n_invalid_perturbations": len(invalid_perturbations),
        "n_distinct_valid_configs": (
            (1 if baseline_result["status"] == "VALID" else 0) + len(valid_perturbations)
        ),
        "param_source": pick_source,
        "param_source_type": pick_source_type,
        "param_source_sha256": pick_source_sha256,
        "baseline_setfile_path": baseline_identity["path"],
        "baseline_setfile_sha256": baseline_identity["sha256"],
        "baseline_setfile_symbol": baseline_identity["declared_symbol"],
        "baseline_setfile_strategy_param_count": baseline_identity["strategy_param_count"],
        "nominal_setfile_path": nominal_identity["path"],
        "nominal_setfile_sha256": nominal_identity["sha256"],
        "generated_at_utc": utc_now_iso(),
        "evidence_status": evidence_status,
        "structurally_inapplicable": structurally_inapplicable,
    }
    artifact = out_dir / "perturbations.json"
    write_artifact_atomic(artifact, payload)
    print(f"Q08.5 wrote {artifact} ({evidence_status})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
