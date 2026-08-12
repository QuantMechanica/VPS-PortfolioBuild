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
    from .portfolio_montecarlo import build_artifact as mc_build_artifact
    from .portfolio_resize import AllocationError, capped_proportional_allocation
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
    from portfolio_montecarlo import build_artifact as mc_build_artifact  # type: ignore
    from portfolio_resize import AllocationError, capped_proportional_allocation  # type: ignore


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_OUT = DEFAULT_ARTIFACT_DIR / "portfolio_manifest_tlive_DRAFT.json"
DEFAULT_MAGIC_REGISTRY = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"


def _canonical_starting_capital() -> float:
    """The q08_trades streams are generated on the canonical tester account
    (framework/registry/tester_defaults.json initial_deposit = $100k, RISK_FIXED=$1000=1%/trade).
    The manifest MaxDD must use that same base — the old $10k default overstated DD ~10x and made a
    1.5% book look like 13.8%, breaking the DD-cap check. Single source of truth: tester_defaults."""
    try:
        defaults = json.loads(
            (REPO_ROOT / "framework" / "registry" / "tester_defaults.json").read_text(encoding="utf-8")
        )
        value = float(defaults.get("initial_deposit", 100_000.0))
        return value if value > 0.0 else 100_000.0
    except Exception:
        return 100_000.0


DEFAULT_STARTING_CAPITAL = _canonical_starting_capital()
STATUS = "DRAFT_FOR_OWNER_APPROVAL"
STATUS_DD_CAP_FAILED = "DRAFT_REJECTED_DD_CAP"
# Hard Rule (OWNER 2026-06-26): never risk more than 1% of the account per trade.
MAX_RISK_PCT_PER_TRADE = 1.0
MANUAL_NOTE = (
    "Deploy-prep only: OWNER+Claude must verify this draft and manually perform any "
    "T_Live copy, terminal action, and AutoTrading flip."
)


def _mc_p95_max_drawdown_pct(artifact: Mapping[str, Any]) -> float | None:
    """Robust drawdown for the cap decision (deploy-cap memo D1): the conservative
    (max) p95 max-drawdown across the Monte-Carlo block-bootstrap and trade-order-shuffle
    resamples. This is a distribution estimate, NOT the single observed path the manifest
    KPIs report — a low-frequency book's observed DD is one lucky equity curve."""
    candidates: list[float] = []
    for method in ("block_bootstrap", "trade_order_shuffle"):
        try:
            candidates.append(float(artifact[method]["max_drawdown_pct"]["p95"]))
        except (KeyError, TypeError, ValueError):
            continue
    return max(candidates) if candidates else None


def apply_leverage_scale(manifest: dict[str, Any], scale: float) -> None:
    """De-lever (or lever) the WHOLE book by `scale`, keeping every sleeve and its relative
    weight (deploy-cap memo D3). Drawdown% scales ~linearly with position size, so scaling
    each sleeve's risk by `scale` scales the book's drawdown by `scale`. This fits a DD cap
    WITHOUT dropping diversifying sleeves (the old greedy path met the cap by shrinking the
    book to 2 sleeves, throwing away the diversification we built)."""
    if scale <= 0.0:
        raise ValueError("leverage scale must be > 0")
    # Fail before mutating any field if a legacy manifest would multiply the
    # already-allocated RISK_PERCENT by a relative weight a second time.
    for sleeve in manifest.get("sleeves", []):
        sfe = sleeve.get("set_file_expectation")
        if not isinstance(sfe, dict):
            raise ValueError("sleeve lacks set_file_expectation risk contract")
        try:
            set_risk = float(sfe["RISK_PERCENT"])
            portfolio_weight = float(sfe["PORTFOLIO_WEIGHT"])
            allocated_risk = float(sleeve["risk_percent"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError("sleeve risk contract is incomplete or non-numeric") from exc
        if not math.isclose(portfolio_weight, 1.0, rel_tol=0.0, abs_tol=1e-12):
            raise ValueError(
                "legacy double-scaled risk contract: PORTFOLIO_WEIGHT must be 1.0 "
                "when RISK_PERCENT is the allocated sleeve risk"
            )
        if not math.isclose(set_risk, allocated_risk, rel_tol=0.0, abs_tol=1e-9):
            raise ValueError("sleeve RISK_PERCENT does not equal allocated sleeve risk")
    manifest["account_risk_pct"] = _round_float(float(manifest["account_risk_pct"]) * scale)
    if "requested_account_risk_pct" in manifest:
        manifest["requested_account_risk_pct"] = _round_float(
            float(manifest["requested_account_risk_pct"]) * scale
        )
    if "allocated_total_risk_pct" in manifest:
        manifest["allocated_total_risk_pct"] = manifest["account_risk_pct"]
    if "risk_target_preserved" in manifest:
        manifest["risk_target_preserved"] = True
    for sleeve in manifest.get("sleeves", []):
        sleeve["risk_percent"] = _round_float(float(sleeve["risk_percent"]) * scale)
        sfe = sleeve.get("set_file_expectation")
        if isinstance(sfe, dict) and "RISK_PERCENT" in sfe:
            sfe["RISK_PERCENT"] = _round_float(float(sfe["RISK_PERCENT"]) * scale)


def finalize_cap_decision(
    manifest: dict[str, Any],
    *,
    mc_p95_dd: float | None,
    observed_dd: float | None,
    cap_pct: float,
) -> dict[str, Any]:
    """Apply the DD cap to a built manifest (deploy-cap memo D1+D3).

    D1: decide on the robust MC-p95 drawdown when available, never the single observed path.
    D3: if over cap, de-lever the full book to fit (keep all sleeves) instead of rejecting.
    """
    manifest["max_dd_pct_constraint"] = float(cap_pct)
    manifest["kpis"]["observed_max_drawdown_pct"] = observed_dd
    manifest["kpis"]["mc_p95_max_drawdown_pct"] = mc_p95_dd
    dd_for_cap = mc_p95_dd if mc_p95_dd is not None else observed_dd
    manifest["dd_basis_for_cap"] = "mc_p95" if mc_p95_dd is not None else "observed"

    if dd_for_cap is None:
        manifest["cap_met"] = False
        manifest["status"] = STATUS_DD_CAP_FAILED
        manifest["deployment_action"] = "NONE"
        return manifest
    if float(dd_for_cap) <= float(cap_pct):
        manifest["cap_met"] = True
        return manifest

    # D3: de-lever the full diversified book rather than drop sleeves.
    scale = float(cap_pct) / float(dd_for_cap)
    apply_leverage_scale(manifest, scale)
    manifest["cap_met"] = True
    manifest["de_levered_to_cap"] = {
        "leverage_scale": _round_float(scale),
        "dd_basis": manifest["dd_basis_for_cap"],
        "pre_delever_dd_pct": _round_float(float(dd_for_cap)),
        "target_cap_pct": float(cap_pct),
        "note": "Full book de-levered to meet the DD cap; all sleeves retained (memo D3).",
    }
    return manifest


def build_manifest(
    book_keys: Sequence[Key],
    *,
    weights: Mapping[Key, float] | Mapping[str, float] | Sequence[float] | None = None,
    account_risk_pct: float = 2.0,
    starting_capital: float = DEFAULT_STARTING_CAPITAL,
    common_dir: Path = DEFAULT_COMMON_DIR,
    magic_registry: Path = DEFAULT_MAGIC_REGISTRY,
) -> dict[str, Any]:
    if account_risk_pct < 0.0:
        raise ValueError("account_risk_pct must be non-negative")

    keys = _normalize_keys(book_keys)
    normalized_weights = _normalize_weights(keys, weights)
    requested_account_risk_pct = float(account_risk_pct)
    if keys and requested_account_risk_pct > 0.0:
        positive_scores = {
            key_label(key): weight
            for key, weight in normalized_weights.items()
            if weight > 0.0
        }
        try:
            risk_by_label = capped_proportional_allocation(
                positive_scores,
                requested_account_risk_pct,
                MAX_RISK_PCT_PER_TRADE,
            )
        except AllocationError as exc:
            raise ValueError(
                "account risk cannot be allocated without violating the 1% sleeve cap: "
                f"{exc}"
            ) from exc
        risk_by_key = {key: risk_by_label.get(key_label(key), 0.0) for key in keys}
        # Portfolio KPI weights must describe the same relative allocation that the
        # set-file risk percentages implement.  The former min(...) clip changed one
        # without changing the other and silently lost total risk.
        effective_weights = {
            key: risk_by_key[key] / requested_account_risk_pct for key in keys
        }
    else:
        risk_by_key = {key: 0.0 for key in keys}
        effective_weights = normalized_weights
    allocated_account_risk_pct = sum(risk_by_key.values())
    model = load_model()
    if keys:
        kpis = portfolio_metrics(
            keys,
            effective_weights,
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
        weight = effective_weights[key]
        # Hard Rule (OWNER 2026-06-26): never risk more than 1% per trade.  Excess from a
        # capped sleeve has already been redistributed across uncapped positive-weight
        # sleeves above; an infeasible target raised instead of being silently discarded.
        risk_percent = risk_by_key[key]
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
                    # ``risk_percent`` is already the sleeve's absolute account-risk
                    # allocation. Applying the relative analytics weight again in the
                    # EA would double-scale risk (risk_percent * weight).
                    "PORTFOLIO_WEIGHT": 1.0,
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
        "requested_account_risk_pct": requested_account_risk_pct,
        "account_risk_pct": allocated_account_risk_pct,
        "allocated_total_risk_pct": allocated_account_risk_pct,
        "risk_application_contract": {
            "unit": "account_percent_points",
            "RISK_PERCENT": "absolute_allocated_sleeve_risk",
            "PORTFOLIO_WEIGHT": 1.0,
            "effective_risk_formula": "RISK_PERCENT * PORTFOLIO_WEIGHT",
            "relative_weights_are_analytics_only": True,
        },
        "risk_target_preserved": math.isclose(
            requested_account_risk_pct,
            allocated_account_risk_pct,
            rel_tol=0.0,
            abs_tol=1e-9,
        ) if keys else requested_account_risk_pct == 0.0,
        "starting_capital": float(starting_capital),
        "n_sleeves": len(sleeves),
        "book": [key_label(key) for key in keys],
        "base_weights": {key_label(key): _round_float(normalized_weights[key]) for key in keys},
        "weights": {key_label(key): _round_float(effective_weights[key]) for key in keys},
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
    parser.add_argument(
        "--mc-runs",
        type=int,
        default=1000,
        help="Monte-Carlo resamples for the robust p95 drawdown used in the DD-cap decision.",
    )
    parser.add_argument("--account-risk-pct", type=float, default=2.0)
    parser.add_argument("--starting-capital", type=float, default=DEFAULT_STARTING_CAPITAL)
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

    # D1: robust MC-p95 drawdown (at the canonical starting capital) drives the cap decision,
    # not the single observed equity path. Falls back to observed DD if the MC run is
    # unavailable (e.g. a selected stream is missing on this host).
    observed_dd = manifest["kpis"].get("max_drawdown_pct")
    mc_p95 = None
    if selected_keys:
        try:
            mc_artifact = mc_build_artifact(
                common_dir=args.common_dir,
                selected_keys=[(int(ea_id), str(symbol)) for ea_id, symbol in selected_keys],
                weights=[float(weights[key]) for key in selected_keys],
                runs=args.mc_runs,
                seed=0,
                starting_capital=args.starting_capital,
            )
            mc_p95 = _mc_p95_max_drawdown_pct(mc_artifact)
        except Exception as exc:  # robust draft generation; never crash deploy-prep on MC
            manifest["mc_dd_error"] = str(exc)
    finalize_cap_decision(
        manifest, mc_p95_dd=mc_p95, observed_dd=observed_dd, cap_pct=float(args.max_dd_pct)
    )
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
