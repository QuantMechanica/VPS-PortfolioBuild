from __future__ import annotations

import argparse
import csv
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
    from .portfolio_kpi import (
        Key,
        equal_weights,
        inverse_vol_weights,
        metrics_from_daily_pnl,
        portfolio_metrics,
    )
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
    from portfolio_kpi import (  # type: ignore
        Key,
        equal_weights,
        inverse_vol_weights,
        metrics_from_daily_pnl,
        portfolio_metrics,
    )


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = DEFAULT_ARTIFACT_DIR / "portfolio_manifest_tlive_DRAFT.json"
DEFAULT_MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
STATUS = "DRAFT_FOR_OWNER_APPROVAL"
STATUS_DD_CAP_FAILED = "DRAFT_REJECTED_DD_CAP"
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
    magic_registry: Path = DEFAULT_MAGIC_REGISTRY,
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
    magic_rows = _load_magic_registry(magic_registry, keys)
    for slot, key in enumerate(keys):
        ea_id, symbol = key
        weight = normalized_weights[key]
        risk_percent = float(account_risk_pct) * weight
        ex5_path = _expected_ex5_path(ea_id)
        magic = _resolve_magic(magic_rows, ea_id, symbol)
        sleeves.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "slot": slot,
                "weight": _round_float(weight),
                "risk_percent": _round_float(risk_percent),
                "magic_number": magic["magic"],
                "magic_source": str(magic_registry),
                "ex5_path": str(ex5_path),
                "ex5_exists": ex5_path.exists(),
                "set_file_expectation": {
                    "ENV": "live",
                    "RISK_PERCENT": _round_float(risk_percent),
                    "RISK_FIXED": 0.0,
                    "qm_magic_slot_offset": magic["symbol_slot"],
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
    parser.add_argument(
        "--book-source",
        choices=("selected", "q12-ready-all"),
        default="selected",
        help=(
            "selected: greedy portfolio assembler; q12-ready-all: include every "
            "distinct Q12_REVIEW_READY sleeve with inverse-vol weights."
        ),
    )
    parser.add_argument("--max-dd-pct", type=float, default=6.0)
    parser.add_argument("--account-risk-pct", type=float, default=2.0)
    parser.add_argument("--starting-capital", type=float, default=10_000.0)
    parser.add_argument("--magic-registry", type=Path, default=DEFAULT_MAGIC_REGISTRY)
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help="Draft manifest JSON path.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.all_streams and args.book_source == "q12-ready-all":
        raise ValueError("--all-streams cannot be combined with --book-source q12-ready-all")
    selected_keys, weights, discovery_basis = _selected_book(
        common_dir=args.common_dir,
        candidates_db=args.candidates_db,
        all_streams=args.all_streams,
        book_source=args.book_source,
        max_dd_pct=args.max_dd_pct,
        starting_capital=args.starting_capital,
    )
    manifest = build_manifest(
        selected_keys,
        weights=weights,
        account_risk_pct=args.account_risk_pct,
        starting_capital=args.starting_capital,
        common_dir=args.common_dir,
        magic_registry=args.magic_registry,
    )
    manifest["basis"] = discovery_basis
    manifest["generated_basis"] = discovery_basis
    manifest["book_source"] = args.book_source
    manifest["max_dd_pct_constraint"] = float(args.max_dd_pct)
    max_dd = manifest["kpis"].get("max_drawdown_pct")
    cap_met = isinstance(max_dd, (float, int)) and float(max_dd) <= float(args.max_dd_pct)
    manifest["cap_met"] = bool(cap_met)
    if not cap_met:
        manifest["status"] = STATUS_DD_CAP_FAILED
        manifest["deployment_action"] = "NONE"
    write_manifest(manifest, args.out)
    print(f"wrote {args.out} ({manifest['n_sleeves']} sleeves)")
    print(MANUAL_NOTE)
    return 0


def _selected_book(
    *,
    common_dir: Path,
    candidates_db: Path,
    all_streams: bool,
    book_source: str = "selected",
    max_dd_pct: float,
    starting_capital: float,
) -> tuple[list[Key], dict[Key, float], str]:
    if book_source == "q12-ready-all":
        keys = read_candidates(candidates_db)
        if not keys:
            return [], {}, "portfolio_candidates.Q12_REVIEW_READY_all"
        weights = inverse_vol_weights(keys, common_dir)
        return keys, weights, "portfolio_candidates.Q12_REVIEW_READY_all"
    if book_source != "selected":
        raise ValueError(f"unsupported book_source {book_source!r}")

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
        weighting="inverse_vol",
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


def _load_magic_registry(path: Path, keys: Sequence[Key]) -> dict[Key, dict[str, int]]:
    wanted = set(keys)
    if not wanted:
        return {}
    if not path.exists():
        raise FileNotFoundError(f"magic registry not found: {path}")

    rows: dict[Key, dict[str, int]] = {}
    with path.open("r", encoding="utf-8-sig", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if str(row.get("status") or "").strip().lower() != "active":
                continue
            ea_text = str(row.get("ea_id") or "").strip()
            symbol = str(row.get("symbol") or "").strip()
            slot_text = str(row.get("symbol_slot") or "").strip()
            magic_text = str(row.get("magic") or "").strip()
            if not ea_text or not symbol or not slot_text or not magic_text:
                continue
            ea_id = int(ea_text)
            symbol_slot = int(slot_text)
            magic = int(magic_text)
            expected_magic = ea_id * 10000 + symbol_slot
            if magic != expected_magic:
                raise ValueError(
                    f"magic registry mismatch for {ea_id}:{symbol}: "
                    f"magic={magic} expected={expected_magic}"
                )
            key = (ea_id, symbol)
            if key not in wanted:
                continue
            if key in rows:
                raise ValueError(f"duplicate active magic registry row for {key_label(key)}")
            rows[key] = {"symbol_slot": symbol_slot, "magic": magic}
    return rows


def _resolve_magic(
    rows: Mapping[Key, dict[str, int]],
    ea_id: int,
    symbol: str,
) -> dict[str, int]:
    key = (int(ea_id), str(symbol))
    if key not in rows:
        raise ValueError(f"no active magic registry row for {key_label(key)}")
    return rows[key]


def _round_float(value: float) -> float:
    rounded = round(float(value), 10)
    return 0.0 if rounded == -0.0 else rounded


if __name__ == "__main__":
    raise SystemExit(main())
