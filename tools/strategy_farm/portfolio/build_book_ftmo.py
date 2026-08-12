#!/usr/bin/env python3
"""Build a fail-closed dry-run Q11_FTMO manifest under DL-084.

This tool consumes frozen FUND_SCORE rows and an optional, roster-bound Phase-1
bootstrap result. It never harvests terminal data itself. The ae5331f67 M1
bootstrap lineage must be declared by the supplied result, and the reviewed FTMO
cost/swap snapshot must match SHA-256 7eab3bf8... exactly.
"""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.portfolio.book_builder_common import (
    BookBuildError,
    canonical_json,
    file_binding,
    load_json,
    resolve_roster,
    roster_sha256,
    sha256_bytes,
    sleeve_bindings,
    validate_dual_book_manifest,
    write_json,
    write_text,
)


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ROSTER = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")
DEFAULT_FUND_SCORES = Path(r"D:\QM\strategy_farm\artifacts\portfolio\fund_scores.json")
DEFAULT_COST_SNAPSHOT = REPO_ROOT / "docs" / "ops" / "evidence" / "2026-07-30_ftmo_book3_symbol_cost_snapshot.json"
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\portfolio")
SCHEMA_PATH = REPO_ROOT / "tools" / "strategy_farm" / "config" / "dual_book_manifest.v1.schema.json"
EXPECTED_COST_SNAPSHOT_SHA256 = "7eab3bf8c97373fcb44e36aca39dd679fbd3e093783cd6eacd9cb171190b3280"
M1_BOOTSTRAP_LINEAGE_COMMIT = "ae5331f67"
FUND_SCORE_FLOOR = 1.0
P1_LOWER_BOUND_FLOOR = 0.80


def _score_key(value: Any) -> tuple[int, str] | None:
    text = str(value or "").strip().upper()
    if ":" not in text:
        return None
    ea, symbol = text.split(":", 1)
    try:
        ea_id = int(ea.replace("QM5_", ""))
    except ValueError:
        return None
    if "." not in symbol:
        symbol += ".DWX"
    return ea_id, symbol


def load_fund_scores(path: Path) -> tuple[dict[tuple[int, str], dict[str, Any]], dict[str, Any]]:
    payload = load_json(path)
    if not isinstance(payload, Mapping) or payload.get("metric") != "FUND_SCORE":
        raise BookBuildError("fund-score input must declare metric FUND_SCORE")
    if not isinstance(payload.get("rows"), list):
        raise BookBuildError("fund-score input rows must be a list")
    result: dict[tuple[int, str], dict[str, Any]] = {}
    for index, source in enumerate(payload["rows"]):
        if not isinstance(source, Mapping):
            raise BookBuildError(f"fund-score row {index} is not an object")
        key = _score_key(source.get("sleeve"))
        if key is None:
            continue
        row = dict(source)
        if row.get("status") == "SCORED":
            try:
                med60 = float(row["med60_1x"])
                worst = abs(float(row["worst_day_1x"]))
                wdd90 = float(row["wdd_p90_1x"])
                declared = float(row["fund_score"])
            except (KeyError, TypeError, ValueError) as exc:
                raise BookBuildError(f"fund-score row {index} lacks formula inputs") from exc
            expected = med60 / max(2.0, 2.0 * worst, wdd90)
            if not all(math.isfinite(v) for v in (med60, worst, wdd90, declared)):
                raise BookBuildError(f"fund-score row {index} contains non-finite values")
            if abs(expected - declared) > 1e-9:
                raise BookBuildError(f"fund-score formula mismatch for {key}: {declared} != {expected}")
        if key in result:
            raise BookBuildError(f"duplicate fund-score row for {key}")
        result[key] = row
    return result, {"input": file_binding(path), "formula": "med60/max(2,2*abs(wDay),wDD_p90)"}


def select_one_per_symbol(
    roster: list[tuple[int, str]], scores: Mapping[tuple[int, str], Mapping[str, Any]]
) -> tuple[list[tuple[int, str]], list[dict[str, Any]]]:
    assessments: list[dict[str, Any]] = []
    eligible: list[tuple[tuple[int, str], float]] = []
    for key in sorted(roster):
        row = scores.get(key)
        score = None
        reason = "FUND_SCORE_MISSING"
        if row is not None and row.get("status") == "SCORED":
            score = float(row["fund_score"])
            reason = "FUND_SCORE_PASS" if score >= FUND_SCORE_FLOOR else "FUND_SCORE_BELOW_1"
            if score >= FUND_SCORE_FLOOR:
                eligible.append((key, score))
        elif row is not None:
            reason = f"FUND_SCORE_{str(row.get('status', 'UNSCORABLE')).upper()}"
        assessments.append({
            "ea_id": key[0], "symbol": key[1], "fund_score": score,
            "eligible": score is not None and score >= FUND_SCORE_FLOOR,
            "reason": reason,
        })
    best: dict[str, tuple[tuple[int, str], float]] = {}
    for key, score in eligible:
        previous = best.get(key[1])
        if previous is None or (-score, key[0]) < (-previous[1], previous[0][0]):
            best[key[1]] = (key, score)
    selected = sorted(item[0] for item in best.values())
    selected_set = set(selected)
    for row in assessments:
        key = (int(row["ea_id"]), str(row["symbol"]))
        if row["eligible"] and key not in selected_set:
            row["eligible"] = False
            row["reason"] = "ONE_EA_PER_SYMBOL_LOWER_SCORE"
    return selected, assessments


def _cost_coverage(
    snapshot_path: Path,
    selected: list[tuple[int, str]],
    *,
    required_sha256: str,
) -> tuple[dict[str, Any], bool, list[str]]:
    binding = file_binding(snapshot_path)
    if binding["sha256"] != required_sha256:
        raise BookBuildError(
            f"FTMO cost/swap snapshot hash mismatch: {binding['sha256']} != {required_sha256}"
        )
    payload = load_json(snapshot_path)
    rows = payload.get("book3_normalization") if isinstance(payload, Mapping) else None
    if not isinstance(rows, list):
        raise BookBuildError("FTMO cost/swap snapshot lacks book3_normalization rows")
    supported = {str(row.get("dwx_symbol", "")).upper() for row in rows if isinstance(row, Mapping)}
    missing = sorted({symbol for _, symbol in selected if symbol not in supported})
    return {
        "input": binding,
        "required_sha256": required_sha256,
        "supported_symbols": sorted(supported),
        "coverage_complete": not missing,
        "missing_symbols": missing,
    }, not missing, missing


def _density(
    selected: list[tuple[int, str]],
    scores: Mapping[tuple[int, str], Mapping[str, Any]],
    *,
    min_sleeves: int,
    min_active_days_per_60d: float,
) -> dict[str, Any]:
    values: list[float] = []
    missing: list[str] = []
    for key in selected:
        raw = scores[key].get("active_days_per_60d")
        if raw is None:
            missing.append(f"{key[0]}:{key[1]}")
            continue
        try:
            value = float(raw)
        except (TypeError, ValueError):
            missing.append(f"{key[0]}:{key[1]}")
            continue
        if not math.isfinite(value):
            missing.append(f"{key[0]}:{key[1]}")
            continue
        values.append(value)
    checks = {
        "minimum_sleeves": len(selected) >= min_sleeves,
        "density_evidence_complete": not missing and len(values) == len(selected),
        "each_sleeve_active_days_per_60d": bool(values) and min(values) >= min_active_days_per_60d,
    }
    return {
        "contract": {
            "minimum_sleeves": min_sleeves,
            "minimum_active_days_per_sleeve_per_60d": min_active_days_per_60d,
            "minimum_trading_days_phase1": 4,
        },
        "observed": {"selected_sleeves": len(selected), "active_days_per_60d": values},
        "missing_density_rows": missing,
        "checks": checks,
        "passed": all(checks.values()),
    }


def _bootstrap(
    path: Path | None,
    *,
    selected_roster_sha256: str,
    cost_snapshot_sha256: str,
) -> dict[str, Any]:
    if path is None:
        return {
            "status": "MISSING",
            "ci_lower_p_phase1": 0.0,
            "required_lower_bound": P1_LOWER_BOUND_FLOOR,
            "measured_gap": P1_LOWER_BOUND_FLOOR,
            "passed": False,
            "reason": "ROSTER_BOUND_BOOTSTRAP_RESULT_REQUIRED",
            "required_engine_lineage": M1_BOOTSTRAP_LINEAGE_COMMIT,
        }
    payload = load_json(path)
    if not isinstance(payload, Mapping):
        raise BookBuildError("bootstrap result must be an object")
    if payload.get("schema") != "qm.ftmo-p1-bootstrap-result/v1":
        raise BookBuildError("unsupported FTMO Phase-1 bootstrap result schema")
    if payload.get("roster_sha256") != selected_roster_sha256:
        raise BookBuildError("bootstrap result is not bound to the selected FTMO roster")
    if payload.get("cost_snapshot_sha256") != cost_snapshot_sha256:
        raise BookBuildError("bootstrap result is not bound to the required cost/swap snapshot")
    lineage = payload.get("engine_lineage")
    if not isinstance(lineage, Mapping) or lineage.get("ftmo_m1_bootstrap_commit") != M1_BOOTSTRAP_LINEAGE_COMMIT:
        raise BookBuildError("bootstrap result lacks ae5331f67 M1 bootstrap lineage")
    try:
        lower = float(payload["ci_lower_p_phase1"])
        estimate = float(payload["estimated_p_phase1"])
        replicates = int(payload["replicates"])
    except (KeyError, TypeError, ValueError) as exc:
        raise BookBuildError("bootstrap result lacks probability/lower-bound fields") from exc
    if not (0 <= lower <= estimate <= 1) or replicates < 100:
        raise BookBuildError("bootstrap result probabilities or replicate count are invalid")
    passed = lower >= P1_LOWER_BOUND_FLOOR
    return {
        "status": "VERIFIED",
        "input": file_binding(path),
        "estimated_p_phase1": estimate,
        "ci_lower_p_phase1": lower,
        "replicates": replicates,
        "required_lower_bound": P1_LOWER_BOUND_FLOOR,
        "measured_gap": round(max(0.0, P1_LOWER_BOUND_FLOOR - lower), 8),
        "passed": passed,
        "engine_lineage": dict(lineage),
    }


def build_ftmo_manifest(
    *,
    roster_path: Path,
    fund_scores_path: Path,
    cost_snapshot_path: Path,
    bootstrap_result_path: Path | None,
    as_of: str,
    min_sleeves: int = 3,
    min_active_days_per_60d: float = 4.0,
    required_cost_sha256: str = EXPECTED_COST_SNAPSHOT_SHA256,
) -> dict[str, Any]:
    roster, roster_provenance = resolve_roster(roster_path)
    scores, score_provenance = load_fund_scores(fund_scores_path)
    selected, assessments = select_one_per_symbol(roster, scores)
    cost, cost_pass, _ = _cost_coverage(
        cost_snapshot_path, selected, required_sha256=required_cost_sha256
    )
    density = _density(
        selected, scores,
        min_sleeves=min_sleeves,
        min_active_days_per_60d=min_active_days_per_60d,
    )
    bindings = sleeve_bindings(REPO_ROOT, selected)
    for row in bindings:
        if float(row["backtest_risk_fixed"]) != 1000.0 or float(row["backtest_risk_percent"]) != 0.0:
            raise BookBuildError(
                f"FTMO source sleeve {row['ea_id']}:{row['symbol']} is not RISK_FIXED=1000/RISK_PERCENT=0"
            )
        row["weight"] = 1.0
        row["risk_fixed"] = 1000.0
        row["risk_percent"] = 0.0
        row["fund_score"] = float(scores[(row["ea_id"], row["symbol"])]["fund_score"])
    selected_hash = roster_sha256(bindings)
    bootstrap = _bootstrap(
        bootstrap_result_path,
        selected_roster_sha256=selected_hash,
        cost_snapshot_sha256=cost["input"]["sha256"],
    )
    fund_pass = bool(selected) and all(row["fund_score"] >= FUND_SCORE_FLOOR for row in bindings)
    checks = {
        "fund_score_each_at_least_1": fund_pass,
        "one_ea_per_symbol": len({row["symbol"] for row in bindings}) == len(bindings),
        "density": density["passed"],
        "cost_and_swap_snapshot_coverage": cost_pass,
        "bootstrap_lower_bound_at_least_0p80": bootstrap["passed"],
    }
    bar_met = all(checks.values())
    status = "BAR_MET_OWNER_REVIEW" if bar_met else "BAR_NOT_MET"
    sleeve_hash = sha256_bytes(canonical_json(bindings).encode("ascii"))
    return {
        "schema": "qm.dual-book-manifest/v1",
        "lane": "Q11_FTMO",
        "as_of": as_of,
        "execution_mode": "DRY_RUN",
        "status": status,
        "challenge_recommendation": "NONE",
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "roster": roster_provenance,
        "candidate_roster_sha256": roster_sha256([{"ea_id": x[0], "symbol": x[1]} for x in roster]),
        "roster_sha256": selected_hash,
        "sleeve_list_sha256": sleeve_hash,
        "sleeves": bindings,
        "fund_score": {
            "floor": FUND_SCORE_FLOOR,
            "provenance": score_provenance,
            "assessments": assessments,
        },
        "symbol_policy": "ONE_EA_PER_SYMBOL_HIGHEST_FUND_SCORE_DETERMINISTIC_TIE_EA_ID",
        "density": density,
        "ftmo_cost_swap": cost,
        "phase1_bootstrap": bootstrap,
        "bar": {"checks": checks, "passed": bar_met, "measured_gap": bootstrap["measured_gap"]},
        "schema_binding": file_binding(SCHEMA_PATH),
    }


def evidence_markdown(manifest: Mapping[str, Any], manifest_path: Path) -> str:
    checks = "\n".join(
        f"- {name}: {'PASS' if passed else 'FAIL'}"
        for name, passed in manifest["bar"]["checks"].items()
    )
    return f"""# Q11_FTMO dry-run book evidence

- Status: `{manifest['status']}`
- Challenge recommendation: `NONE`
- Manifest: `{manifest_path}`
- Candidate roster hash: `{manifest['candidate_roster_sha256']}`
- Selected roster hash: `{manifest['roster_sha256']}`
- Hash-bound sleeve list: `{manifest['sleeve_list_sha256']}`
- Phase-1 bootstrap lower-bound gap: `{manifest['bar']['measured_gap']}`
- Execution: `DRY_RUN`; deployment and AutoTrading actions are `NONE`.

## Fail-closed bar

{checks}

The manifest remains parked. A paid challenge or any live action is outside this tool and requires the OWNER ceremony after every bar is evidenced.
"""


def parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--roster", type=Path, default=DEFAULT_ROSTER)
    ap.add_argument("--fund-scores", type=Path, default=DEFAULT_FUND_SCORES)
    ap.add_argument("--cost-snapshot", type=Path, default=DEFAULT_COST_SNAPSHOT)
    ap.add_argument("--bootstrap-result", type=Path)
    ap.add_argument("--min-sleeves", type=int, default=3)
    ap.add_argument("--min-active-days-per-60d", type=float, default=4.0)
    ap.add_argument("--as-of", default="2026-08-12")
    ap.add_argument("--out-dir", type=Path)
    return ap


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    out_dir = args.out_dir or DEFAULT_REPORT_ROOT / f"book_ftmo_{args.as_of}"
    manifest_path = out_dir / "manifest.json"
    try:
        manifest = build_ftmo_manifest(
            roster_path=args.roster,
            fund_scores_path=args.fund_scores,
            cost_snapshot_path=args.cost_snapshot,
            bootstrap_result_path=args.bootstrap_result,
            as_of=args.as_of,
            min_sleeves=args.min_sleeves,
            min_active_days_per_60d=args.min_active_days_per_60d,
        )
        validate_dual_book_manifest(manifest)
        write_json(manifest_path, manifest)
        write_text(out_dir / "evidence.md", evidence_markdown(manifest, manifest_path))
    except BookBuildError as exc:
        print(json.dumps({"status": "INPUT_INVALID", "error": str(exc)}, indent=2), file=sys.stderr)
        return 2
    print(json.dumps({
        "status": manifest["status"],
        "manifest": str(manifest_path),
        "evidence": str(out_dir / "evidence.md"),
        "sleeves": len(manifest["sleeves"]),
        "bootstrap_gap": manifest["bar"]["measured_gap"],
        "dry_run": True,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
