from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any, Mapping, Sequence

try:
    from .commission import describe_model, load_model
    from .portfolio_assemble import assemble_portfolio
    from .portfolio_common import (
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
    )
    from .portfolio_correlation import COMMISSION_BASIS
    from .portfolio_kpi import Key, equal_weights, metrics_from_daily_pnl, portfolio_metrics
except ImportError:  # pragma: no cover - direct script execution
    from commission import describe_model, load_model  # type: ignore
    from portfolio_assemble import assemble_portfolio  # type: ignore
    from portfolio_common import (  # type: ignore
        DEFAULT_ARTIFACT_DIR,
        DEFAULT_CANDIDATES_DB,
        DEFAULT_COMMON_DIR,
        key_label,
        load_streams,
        read_candidates,
    )
    from portfolio_correlation import COMMISSION_BASIS  # type: ignore
    from portfolio_kpi import Key, equal_weights, metrics_from_daily_pnl, portfolio_metrics  # type: ignore


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = DEFAULT_ARTIFACT_DIR / "portfolio_manifest_tlive_DRAFT.json"
STATUS = "DRAFT_FOR_OWNER_APPROVAL"
MANUAL_NOTE = (
    "Deploy-prep only: OWNER+Claude must verify this draft and manually perform any "
    "T_Live copy, terminal action, and AutoTrading flip."
)


def build_manifest(
    book_keys: Sequence[Key],
    *,
    weights: Mapping[Key, float] | Mapping[str, float] | Sequence[float] | None = None,
    account_risk_pct: float = 2.0,
    starting_capital: float = 10_000.0,
    common_dir: Path = DEFAULT_COMMON_DIR,
) -> dict[str, Any]:
    if account_risk_pct < 0.0:
        raise ValueError("account_risk_pct must be non-negative")

    keys = _normalize_keys(book_keys)
    normalized_weights = _normalize_weights(keys, weights)
    model = load_model()
    if keys:
        kpis = portfolio_metrics(
            keys,
            normalized_weights,
            common_dir,
            starting_capital=starting_capital,
            commission_model=model,
        )
    else:
        kpis = metrics_from_daily_pnl(
            [],
            n_sleeves=0,
            starting_capital=starting_capital,
            n_days=0,
        )

    sleeves = []
    for slot, key in enumerate(keys):
        ea_id, symbol = key
        weight = normalized_weights[key]
        risk_percent = float(account_risk_pct) * weight
        ex5_path = _expected_ex5_path(ea_id)
        sleeves.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "slot": slot,
                "weight": _round_float(weight),
                "risk_percent": _round_float(risk_percent),
                "magic_number": int(ea_id) * 10000 + slot,
                "ex5_path": str(ex5_path),
                "ex5_exists": ex5_path.exists(),
                "set_file_expectation": {
                    "ENV": "live",
                    "RISK_PERCENT": _round_float(risk_percent),
                    "RISK_FIXED": 0.0,
                    "qm_magic_slot_offset": slot,
                    "PORTFOLIO_WEIGHT": _round_float(weight),
                },
            }
        )

    return {
        "status": STATUS,
        "generated_at_utc": dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat(),
        "note": MANUAL_NOTE,
        "manual_approval_required": True,
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "commission_basis": COMMISSION_BASIS,
        "commission_model": describe_model(model),
        "degraded": model.degraded,
        "degraded_symbols": sorted(model.degraded_symbols),
        "account_risk_pct": float(account_risk_pct),
        "starting_capital": float(starting_capital),
        "n_sleeves": len(sleeves),
        "book": [key_label(key) for key in keys],
        "weights": {key_label(key): _round_float(normalized_weights[key]) for key in keys},
        "kpis": kpis,
        "sleeves": sleeves,
    }


def write_manifest(manifest: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, sort_keys=True)
        fh.write("\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build T_Live draft portfolio manifest.")
    parser.add_argument("--common-dir", type=Path, default=DEFAULT_COMMON_DIR)
    parser.add_argument("--candidates-db", type=Path, default=DEFAULT_CANDIDATES_DB)
    parser.add_argument("--all-streams", action="store_true")
    parser.add_argument("--max-dd-pct", type=float, default=6.0)
    parser.add_argument("--account-risk-pct", type=float, default=2.0)
    parser.add_argument("--starting-capital", type=float, default=10_000.0)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help="Draft manifest JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    selected_keys, weights, discovery_basis = _selected_book(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        max_dd_pct=args.max_dd_pct,
        starting_capital=args.starting_capital,
    )
    manifest = build_manifest(
        selected_keys,
        weights=weights,
        account_risk_pct=args.account_risk_pct,
        starting_capital=args.starting_capital,
        common_dir=args.common_dir,
    )
    manifest["basis"] = discovery_basis
    manifest["generated_basis"] = discovery_basis
    manifest["max_dd_pct_constraint"] = float(args.max_dd_pct)
    write_manifest(manifest, args.out)
    print(f"wrote {args.out} ({manifest['n_sleeves']} sleeves)")
    print(MANUAL_NOTE)
    return 0


def _selected_book(
    *,
    common_dir: Path,
    candidates_db: Path,
    all_streams: bool,
    max_dd_pct: float,
    starting_capital: float,
) -> tuple[list[Key], dict[Key, float], str]:
    if all_streams:
        model = load_model()
        streams = load_streams(common_dir, commission_model=model)
        if not streams:
            return [], {}, "all_q08_streams_uncertified"
    elif not read_candidates(candidates_db):
        return [], {}, "candidates"

    assembled = assemble_portfolio(
        common_dir=common_dir,
        candidates_db=candidates_db,
        all_streams=all_streams,
        max_dd_pct=max_dd_pct,
        weighting="equal",
        starting_capital=starting_capital,
    )
    keys = [_parse_key_label(label) for label in assembled["selected_keys"]]
    weight_map = {
        _parse_key_label(label): float(weight)
        for label, weight in assembled["weights"].items()
    }
    return keys, weight_map, str(assembled["basis"])


def _normalize_keys(keys: Sequence[Key]) -> list[Key]:
    return sorted(set((int(ea_id), str(symbol)) for ea_id, symbol in keys))


def _normalize_weights(
    keys: Sequence[Key],
    weights: Mapping[Key, float] | Mapping[str, float] | Sequence[float] | None,
) -> dict[Key, float]:
    if not keys:
        return {}
    if weights is None:
        return {key: float(value) for key, value in equal_weights(keys).items()}

    if isinstance(weights, Mapping):
        raw: dict[Key, float] = {}
        for key in keys:
            if key in weights:
                raw[key] = float(weights[key])  # type: ignore[index]
                continue
            label = key_label(key)
            if label in weights:
                raw[key] = float(weights[label])  # type: ignore[index]
                continue
            raise ValueError(f"missing weight for {label}")
    else:
        if len(weights) != len(keys):
            raise ValueError("weights length must match book_keys length")
        raw = {key: float(weight) for key, weight in zip(keys, weights)}

    for key, value in raw.items():
        if not math.isfinite(value) or value < 0.0:
            raise ValueError(f"invalid weight for {key_label(key)}")
    total = sum(raw.values())
    if total <= 0.0:
        raise ValueError("weights must sum to a positive value")
    return {key: value / total for key, value in raw.items()}


def _parse_key_label(label: str) -> Key:
    ea_token, separator, symbol = str(label).partition(":")
    if not separator:
        raise ValueError(f"invalid key label {label!r}")
    return int(ea_token), symbol


def _expected_ex5_path(ea_id: int) -> Path:
    ea_root = REPO_ROOT / "framework" / "EAs"
    matches = sorted(ea_root.glob(f"QM5_{int(ea_id)}_*"))
    if matches:
        exact = matches[0] / f"{matches[0].name}.ex5"
        if exact.exists():
            return exact
        ex5_files = sorted(matches[0].glob("*.ex5"))
        if ex5_files:
            return ex5_files[0]
        return exact
    fallback_name = f"QM5_{int(ea_id)}_UNKNOWN"
    return ea_root / fallback_name / f"{fallback_name}.ex5"


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
