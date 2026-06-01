from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_COMMON_DIR,
        align,
        key_label,
        load_streams,
        to_daily_pnl,
    )
    from .portfolio_kpi import (
        Key,
        equity_to_daily_pnl,
        metrics_from_daily_pnl,
        portfolio_daily_pnl,
    )
except ImportError:  # pragma: no cover - direct script execution
    from portfolio_common import (  # type: ignore
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_COMMON_DIR,
        align,
        key_label,
        load_streams,
        to_daily_pnl,
    )
    from portfolio_kpi import (  # type: ignore
        Key,
        equity_to_daily_pnl,
        metrics_from_daily_pnl,
        portfolio_daily_pnl,
    )


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_CONFIG = REPO_ROOT / "framework" / "registry" / "portfolio_burnin.json"
DEFAULT_OUT = DEFAULT_ARTIFACT_DIR / "portfolio_burnin_report.json"
STATUS = "EVIDENCE_FOR_OWNER"
REPORT_NAME = "portfolio_burnin_report.json"


class ConfigError(ValueError):
    """Raised when OWNER-gated burn-in config is incomplete."""


def collect_forward_equity(
    live_results_root: Path | str,
    manifest: Mapping[str, Any],
    *,
    burnin_window_days: int | None = None,
) -> dict[str, Any]:
    """Collect DXZ/T_Live forward trade streams and build combined portfolio equity.

    The framework emits one ``TRADE_CLOSED`` JSONL stream per sleeve through
    ``FILE_COMMON`` at ``Common/Files/QM/q08_trades/<ea_id>_<symbol>.jsonl``.
    The collector also accepts a terminal-local ``MQL5/Files`` root for copied
    evidence bundles. Only manifest sleeves are loaded.
    """

    root = Path(live_results_root)
    keys, weights = _manifest_keys_and_weights(manifest)
    if not keys:
        return {
            "dates": [],
            "daily_pnl": [],
            "equity_curve": [],
            "keys": [],
            "weights": [],
            "sleeves": {},
            "metrics": metrics_from_daily_pnl(
                [],
                n_sleeves=0,
                starting_capital=_starting_capital(manifest),
                n_days=0,
            ),
        }

    streams, stream_root, searched_roots = _load_live_streams(root, keys)
    missing = sorted(set(keys) - set(streams))
    if missing:
        labels = ", ".join(key_label(key) for key in missing)
        searched = ", ".join(str(item) for item in searched_roots)
        raise ValueError(
            f"missing live forward stream(s) for manifest sleeve(s): {labels}; searched: {searched}"
        )

    series_by_key = {key: to_daily_pnl(streams[key]) for key in keys}
    aligned_keys, dates, matrix = align(series_by_key)
    if burnin_window_days is not None:
        dates, matrix = _limit_to_first_window(dates, matrix, burnin_window_days)
    weight_vector = [weights[key] for key in aligned_keys]
    daily_pnl = portfolio_daily_pnl(matrix, weight_vector)
    equity_curve = _cumulative_sum(daily_pnl)
    starting_capital = _starting_capital(manifest)

    sleeve_payload: dict[str, Any] = {}
    for col, key in enumerate(aligned_keys):
        sleeve_daily = [float(row[col]) for row in matrix]
        sleeve_payload[key_label(key)] = {
            "daily_pnl": [_round_float(value) for value in sleeve_daily],
            "metrics": metrics_from_daily_pnl(
                sleeve_daily,
                n_sleeves=1,
                starting_capital=starting_capital,
                n_days=len(dates),
            ),
        }

    return {
        "dates": [day.isoformat() for day in dates],
        "daily_pnl": [_round_float(value) for value in daily_pnl],
        "equity_curve": [_round_float(value) for value in equity_curve],
        "keys": [key_label(key) for key in aligned_keys],
        "weights": [_round_float(value) for value in weight_vector],
        "stream_root": str(stream_root),
        "sleeves": sleeve_payload,
        "metrics": metrics_from_daily_pnl(
            daily_pnl,
            n_sleeves=len(aligned_keys),
            starting_capital=starting_capital,
            n_days=len(dates),
        ),
    }


def burnin_verdict(
    manifest: Mapping[str, Any],
    forward_equity: Mapping[str, Any] | Sequence[float],
    mc_artifact: Mapping[str, Any],
    *,
    dd_tolerance: float,
    sharpe_band: float,
) -> dict[str, Any]:
    if dd_tolerance < 0.0:
        raise ValueError("dd_tolerance must be non-negative")
    if sharpe_band < 0.0:
        raise ValueError("sharpe_band must be non-negative")

    starting_capital = _starting_capital(manifest)
    daily_pnl, sleeve_payload = _forward_daily_pnl(forward_equity)
    realised = metrics_from_daily_pnl(
        daily_pnl,
        n_sleeves=_manifest_sleeve_count(manifest),
        starting_capital=starting_capital,
        n_days=len(daily_pnl),
    )
    mc_p95 = _mc_drawdown_p95(mc_artifact)
    dd_limit = mc_p95 + float(dd_tolerance)
    backtest_sharpe = _as_optional_float(_nested_get(manifest, ("kpis", "sharpe")))
    realised_sharpe = _as_optional_float(realised.get("sharpe"))

    reasons: list[str] = []
    verdict = "PASS"
    if float(realised["max_drawdown_pct"]) > dd_limit:
        verdict = "FAIL"
        reasons.append(
            "realised portfolio max-DD "
            f"{_round_float(float(realised['max_drawdown_pct']))}% exceeds "
            f"Monte-Carlo p95 {_round_float(mc_p95)}% + tolerance {_round_float(dd_tolerance)}%"
        )

    if backtest_sharpe is None:
        verdict = "HOLD" if verdict == "PASS" else verdict
        reasons.append("manifest backtest Sharpe is missing")
    elif realised_sharpe is None:
        verdict = "HOLD" if verdict == "PASS" else verdict
        reasons.append("realised forward Sharpe is unavailable")
    elif abs(realised_sharpe - backtest_sharpe) > float(sharpe_band):
        verdict = "HOLD" if verdict == "PASS" else verdict
        reasons.append(
            "realised Sharpe "
            f"{_round_float(realised_sharpe)} is outside +/-{_round_float(sharpe_band)} "
            f"of backtest Sharpe {_round_float(backtest_sharpe)}"
        )

    return {
        "status": STATUS,
        "verdict": verdict,
        "advisory_only": True,
        "tier0_safety": {
            "tlive_action": "NONE",
            "autotrading_action": "NONE",
            "note": "Evidence only; T_Live trading-state control remains OWNER+Claude manual.",
        },
        "reasons": reasons,
        "criteria": {
            "mc_p95_max_drawdown_pct": _round_float(mc_p95),
            "dd_tolerance_pct_points": _round_float(dd_tolerance),
            "dd_limit_pct": _round_float(dd_limit),
            "backtest_sharpe": None if backtest_sharpe is None else _round_float(backtest_sharpe),
            "sharpe_band": _round_float(sharpe_band),
        },
        "realised": realised,
        "per_sleeve_drift": _per_sleeve_drift(manifest, sleeve_payload),
    }


def note_go_live_is_manual() -> str:
    return (
        "R-064-6 is read-only evidence. The DXZ/T_Live go-live flip is OWNER+Claude "
        "manual; this module does not operate the terminal or change trading state."
    )


def load_burnin_config(path: Path | str = DEFAULT_CONFIG) -> dict[str, Any]:
    config_path = Path(path)
    with config_path.open("r", encoding="utf-8") as fh:
        config = json.load(fh)
    missing = _missing_owner_values(config)
    if missing:
        joined = ", ".join(missing)
        raise ConfigError(f"OWNER must set portfolio burn-in config value(s): {joined}")
    return config


def build_report(
    *,
    manifest: Mapping[str, Any],
    forward_equity: Mapping[str, Any],
    mc_artifact: Mapping[str, Any],
    dd_tolerance: float,
    sharpe_band: float,
    config: Mapping[str, Any],
) -> dict[str, Any]:
    verdict = burnin_verdict(
        manifest,
        forward_equity,
        mc_artifact,
        dd_tolerance=dd_tolerance,
        sharpe_band=sharpe_band,
    )
    return {
        "status": STATUS,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "config_basis": {
            "burnin_window_days": config.get("burnin_window_days"),
            "mandatory_scope": config.get("mandatory_scope"),
            "live_environment": _nested_get(config, ("live_account", "environment")),
            "account_label": _nested_get(config, ("live_account", "account_label")),
        },
        "forward_equity": forward_equity,
        "verdict": verdict,
    }


def write_report(report: Mapping[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(report, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build R-064-6 DXZ/T_Live read-only burn-in evidence report."
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--live-results-root",
        type=Path,
        default=None,
        help="MT5 Common/Files root, terminal data path, or copied evidence bundle root.",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--mc-artifact", type=Path, default=None)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = load_burnin_config(args.config)
        manifest = _read_json(args.manifest)
        mc_path = args.mc_artifact or _manifest_mc_artifact_path(manifest)
        if mc_path is None:
            raise ValueError(
                "Monte-Carlo artifact is required; pass --mc-artifact or set "
                "manifest['montecarlo_artifact']"
            )
        mc_artifact = _read_json(mc_path)
        live_root = args.live_results_root or Path(str(config["live_account"]["terminal_data_path"]))
        forward_equity = collect_forward_equity(
            live_root,
            manifest,
            burnin_window_days=int(config["burnin_window_days"]),
        )
        tolerances = config["pass_tolerances"]
        report = build_report(
            manifest=manifest,
            forward_equity=forward_equity,
            mc_artifact=mc_artifact,
            dd_tolerance=float(tolerances["dd_tolerance"]),
            sharpe_band=float(tolerances["sharpe_band"]),
            config=config,
        )
        out_path = _resolve_out_path(args.out)
        write_report(report, out_path)
        print(f"wrote {out_path}")
        print(note_go_live_is_manual())
        return 0
    except (ConfigError, FileNotFoundError, ValueError, KeyError) as exc:
        print(f"portfolio burn-in refused: {exc}")
        return 2


def _manifest_keys_and_weights(manifest: Mapping[str, Any]) -> tuple[list[Key], dict[Key, float]]:
    sleeves = list(manifest.get("sleeves") or [])
    if sleeves:
        keys: list[Key] = []
        weights: dict[Key, float] = {}
        for sleeve in sleeves:
            key = (int(sleeve["ea_id"]), str(sleeve["symbol"]))
            keys.append(key)
            weights[key] = float(sleeve.get("weight", 0.0))
        return keys, _normalize_weights(weights)

    raw_weights = manifest.get("weights") or {}
    if not isinstance(raw_weights, Mapping):
        raise ValueError("manifest weights must be a mapping when sleeves are absent")
    weights = {}
    for label, weight in raw_weights.items():
        key = _parse_key_label(str(label))
        weights[key] = float(weight)
    return sorted(weights), _normalize_weights(weights)


def _normalize_weights(weights: Mapping[Key, float]) -> dict[Key, float]:
    if not weights:
        return {}
    total = sum(float(value) for value in weights.values())
    if not math.isfinite(total) or total <= 0.0:
        raise ValueError("manifest sleeve weights must sum to a positive value")
    normalized = {}
    for key, weight in weights.items():
        value = float(weight)
        if not math.isfinite(value) or value < 0.0:
            raise ValueError(f"invalid manifest sleeve weight for {key_label(key)}")
        normalized[key] = value / total
    return normalized


def _forward_daily_pnl(
    forward_equity: Mapping[str, Any] | Sequence[float],
) -> tuple[list[float], Mapping[str, Any]]:
    if isinstance(forward_equity, Mapping):
        if "daily_pnl" in forward_equity:
            return [float(value) for value in forward_equity["daily_pnl"]], dict(
                forward_equity.get("sleeves") or {}
            )
        if "equity_curve" in forward_equity:
            curve = [float(value) for value in forward_equity["equity_curve"]]
            return equity_to_daily_pnl(curve), dict(forward_equity.get("sleeves") or {})
        raise ValueError("forward_equity must contain daily_pnl or equity_curve")
    curve = [float(value) for value in forward_equity]
    return equity_to_daily_pnl(curve), {}


def _load_live_streams(
    live_results_root: Path,
    keys: Sequence[Key],
) -> tuple[dict[Key, Any], Path, list[Path]]:
    roots = _live_stream_roots(live_results_root)
    requested = set(keys)
    best_streams: dict[Key, Any] = {}
    best_root = roots[0]

    for root in roots:
        streams = load_streams(root, candidates=list(keys))
        if requested.issubset(streams):
            return streams, root, roots
        if len(streams) > len(best_streams):
            best_streams = streams
            best_root = root

    return best_streams, best_root, roots


def _live_stream_roots(live_results_root: Path) -> list[Path]:
    """Return candidate roots that contain ``QM/q08_trades`` below them."""

    candidates = [
        live_results_root,
        live_results_root / "MQL5" / "Files",
    ]
    if live_results_root.exists() and live_results_root.is_dir():
        candidates.extend(
            child / "MQL5" / "Files"
            for child in sorted(live_results_root.iterdir(), key=lambda item: item.name)
            if child.is_dir()
        )
    candidates.append(DEFAULT_COMMON_DIR)
    roots: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        marker = str(candidate)
        if marker in seen:
            continue
        roots.append(candidate)
        seen.add(marker)
    return roots


def _limit_to_first_window(
    dates: Sequence[dt.date],
    matrix: Any,
    burnin_window_days: int,
) -> tuple[list[dt.date], Any]:
    if burnin_window_days <= 0 or not dates:
        return list(dates), matrix

    first_day = dates[0]
    keep = [
        idx
        for idx, day in enumerate(dates)
        if (day - first_day).days < int(burnin_window_days)
    ]
    if len(keep) == len(dates):
        return list(dates), matrix

    kept_dates = [dates[idx] for idx in keep]
    if hasattr(matrix, "shape"):
        return kept_dates, matrix[keep, :]
    return kept_dates, [matrix[idx] for idx in keep]


def _per_sleeve_drift(
    manifest: Mapping[str, Any],
    sleeve_payload: Mapping[str, Any],
) -> dict[str, Any]:
    manifest_sleeves = {
        key_label((int(sleeve["ea_id"]), str(sleeve["symbol"]))): sleeve
        for sleeve in manifest.get("sleeves") or []
    }
    drift: dict[str, Any] = {}
    for label, payload in sorted(sleeve_payload.items()):
        live_metrics = payload.get("metrics", {}) if isinstance(payload, Mapping) else {}
        backtest_metrics = {}
        sleeve = manifest_sleeves.get(label, {})
        if isinstance(sleeve, Mapping):
            raw = sleeve.get("kpis") or sleeve.get("backtest_kpis") or {}
            if isinstance(raw, Mapping):
                backtest_metrics = dict(raw)
        drift[label] = {
            "live": live_metrics,
            "backtest": backtest_metrics,
            "sharpe_delta": _metric_delta(live_metrics, backtest_metrics, "sharpe"),
            "max_drawdown_pct_delta": _metric_delta(
                live_metrics,
                backtest_metrics,
                "max_drawdown_pct",
            ),
        }
    return drift


def _missing_owner_values(config: Mapping[str, Any]) -> list[str]:
    required = config.get("_owner_must_set") or []
    missing: list[str] = []
    for path in required:
        value = _nested_get(config, str(path).split("."))
        if _is_placeholder(value):
            missing.append(str(path))
    return missing


def _is_placeholder(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, str):
        stripped = value.strip()
        return not stripped or stripped.startswith("OWNER_SET")
    return False


def _mc_drawdown_p95(mc_artifact: Mapping[str, Any]) -> float:
    candidates = (
        ("block_bootstrap", "max_drawdown_pct", "p95"),
        ("trade_order_shuffle", "max_drawdown_pct", "p95"),
        ("max_drawdown_pct", "p95"),
    )
    for path in candidates:
        value = _nested_get(mc_artifact, path)
        if value is not None:
            return float(value)
    raise ValueError("Monte-Carlo artifact does not contain max_drawdown_pct p95")


def _manifest_mc_artifact_path(manifest: Mapping[str, Any]) -> Path | None:
    for key in ("montecarlo_artifact", "mc_artifact"):
        value = manifest.get(key)
        if value:
            return Path(str(value))
    value = _nested_get(manifest, ("basis", "montecarlo_artifact"))
    if value:
        return Path(str(value))
    return None


def _nested_get(mapping: Mapping[str, Any], path: Sequence[str]) -> Any:
    current: Any = mapping
    for part in path:
        if not isinstance(current, Mapping) or part not in current:
            return None
        current = current[part]
    return current


def _metric_delta(
    live_metrics: Mapping[str, Any],
    backtest_metrics: Mapping[str, Any],
    key: str,
) -> float | None:
    live = _as_optional_float(live_metrics.get(key))
    backtest = _as_optional_float(backtest_metrics.get(key))
    if live is None or backtest is None:
        return None
    return _round_float(live - backtest)


def _as_optional_float(value: Any) -> float | None:
    if value is None:
        return None
    try:
        parsed = float(value)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(parsed):
        return None
    return parsed


def _manifest_sleeve_count(manifest: Mapping[str, Any]) -> int:
    if "n_sleeves" in manifest:
        return int(manifest["n_sleeves"])
    if manifest.get("sleeves"):
        return len(manifest["sleeves"])
    return len(manifest.get("weights") or [])


def _starting_capital(manifest: Mapping[str, Any]) -> float:
    return float(manifest.get("starting_capital", 10_000.0))


def _parse_key_label(label: str) -> Key:
    ea_token, separator, symbol = label.partition(":")
    if not separator:
        raise ValueError(f"invalid key label {label!r}")
    return int(ea_token), symbol


def _read_json(path: Path) -> dict[str, Any]:
    with Path(path).open("r", encoding="utf-8") as fh:
        return json.load(fh)


def _resolve_out_path(path: Path) -> Path:
    return path / REPORT_NAME if path.suffix == "" else path


def _cumulative_sum(values: Sequence[float]) -> list[float]:
    total = 0.0
    output: list[float] = []
    for value in values:
        total += float(value)
        output.append(total)
    return output


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
