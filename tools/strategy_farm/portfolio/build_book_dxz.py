#!/usr/bin/env python3
"""Build a dry-run Q11_DXZ manifest under the DL-084 contract.

The builder is deliberately analytic-only. It reads an explicit roster, a sealed
stream bundle, the current-book manifest, and repository registries; it cannot
deploy presets, launch MT5, mutate the farm DB, or recommend application unless
all three incumbent comparisons are not worse on the same history.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Mapping

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.portfolio.book_builder_common import (
    BookBuildError,
    aligned_matrix,
    book_metrics,
    capped_inverse_vol,
    canonical_json,
    common_window,
    file_binding,
    key_from_row,
    load_cluster_overlay,
    load_daily,
    load_json,
    portfolio_daily,
    resolve_roster,
    roster_sha256,
    sha256_bytes,
    sleeve_bindings,
    validate_dual_book_manifest,
    write_json,
    write_text,
)
from tools.strategy_farm.portfolio import concentration_tail
from tools.strategy_farm.portfolio.portfolio_common import load_streams
from tools.strategy_farm import risk_freeze


REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_ROSTER = Path(r"D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json")
DEFAULT_INCUMBENT = DEFAULT_ROSTER
DEFAULT_STREAM_ROOT = Path(r"D:\QM\reports\portfolio\dxz_final_20260719")
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\portfolio")
SCHEMA_PATH = REPO_ROOT / "tools" / "strategy_farm" / "config" / "dual_book_manifest.v1.schema.json"
DEFAULT_CONCENTRATION_POLICY = concentration_tail.DEFAULT_POLICY_PATH
DEFAULT_SYMBOL_MATRIX = concentration_tail.DEFAULT_SYMBOL_MATRIX


def _incumbent(path: Path) -> tuple[list[tuple[int, str]], dict[tuple[int, str], float], dict[str, Any]]:
    payload = load_json(path)
    if not isinstance(payload, Mapping) or not isinstance(payload.get("sleeves"), list):
        raise BookBuildError("incumbent manifest must contain a sleeves list")
    keys: list[tuple[int, str]] = []
    weights: dict[tuple[int, str], float] = {}
    for index, row in enumerate(payload["sleeves"]):
        if not isinstance(row, Mapping):
            raise BookBuildError(f"incumbent sleeve {index} is not an object")
        key = key_from_row(row, f"incumbent sleeve {index}")
        if key in weights:
            raise BookBuildError(f"duplicate incumbent sleeve {key}")
        try:
            weight = float(row.get("risk_percent", row.get("weight")))
        except (TypeError, ValueError) as exc:
            raise BookBuildError(f"incumbent sleeve {key} lacks a numeric risk weight") from exc
        if weight < 0:
            raise BookBuildError(f"incumbent sleeve {key} has a negative risk weight")
        keys.append(key)
        weights[key] = weight
    if not keys or sum(weights.values()) <= 0:
        raise BookBuildError("incumbent manifest has no positive book risk")
    return sorted(keys), weights, {"input": file_binding(path), "book": payload.get("book")}


def _gate(proposal: Mapping[str, Any], incumbent: Mapping[str, Any]) -> dict[str, Any]:
    checks = {
        "return_to_maxdd_not_worse": (
            proposal.get("return_to_maxdd") is not None
            and incumbent.get("return_to_maxdd") is not None
            and float(proposal["return_to_maxdd"]) >= float(incumbent["return_to_maxdd"])
        ),
        "worst_day_not_worse": float(proposal["worst_day_pct"]) >= float(incumbent["worst_day_pct"]),
        "maxdd_not_worse": float(proposal["max_drawdown_pct"]) <= float(incumbent["max_drawdown_pct"]),
    }
    return {
        "rule": "ALL: return/maxDD >= incumbent; worst-day >= incumbent; maxDD <= incumbent",
        "checks": checks,
        "passed": all(checks.values()),
    }


def _final_status(gate: Mapping[str, Any], concentration: Mapping[str, Any]) -> str:
    if concentration.get("concentration_reject"):
        return "CONCENTRATION_CAP_BREACH"
    if concentration.get("builder_eligible") is not True:
        return "CONCENTRATION_POLICY_UNRATIFIED"
    return "APPLY_RECOMMENDED" if gate.get("passed") is True else "NOT_WORSE_BAR_NOT_MET"


def build_dxz_manifest(
    *,
    roster_path: Path,
    incumbent_path: Path,
    stream_root: Path,
    cluster_overlay_path: Path | None = None,
    total_risk_pct: float = 9.75,
    sleeve_cap_pct: float = 1.0,
    starting_capital: float = 100_000.0,
    concentration_policy_path: Path = DEFAULT_CONCENTRATION_POLICY,
    symbol_matrix_path: Path = DEFAULT_SYMBOL_MATRIX,
    as_of: str,
) -> dict[str, Any]:
    if total_risk_pct <= 0 or sleeve_cap_pct <= 0 or starting_capital <= 0:
        raise BookBuildError("risk, cap, and capital inputs must be positive")
    roster, roster_provenance = resolve_roster(roster_path)
    incumbent_keys, incumbent_weights, incumbent_provenance = _incumbent(incumbent_path)
    all_keys = sorted(set(roster) | set(incumbent_keys))
    daily, stream_provenance = load_daily(stream_root, all_keys)
    start, end = common_window(daily, all_keys)
    overlay, overlay_provenance = load_cluster_overlay(cluster_overlay_path)
    proposal_keys, proposal_dates, proposal_matrix = aligned_matrix(daily, roster, start, end)
    proposal_weights = capped_inverse_vol(
        proposal_keys,
        proposal_matrix,
        total=total_risk_pct,
        cap=sleeve_cap_pct,
        overlay={key: overlay[key] for key in overlay if key in roster},
    )
    incumbent_aligned, incumbent_dates, incumbent_matrix = aligned_matrix(
        daily, incumbent_keys, start, end
    )
    if proposal_dates != incumbent_dates:
        raise BookBuildError("proposal and incumbent did not resolve to the identical common-day grid")
    proposal_metrics = book_metrics(
        portfolio_daily(proposal_keys, proposal_matrix, proposal_weights),
        len(proposal_keys),
        starting_capital,
    )
    incumbent_metrics = book_metrics(
        portfolio_daily(incumbent_aligned, incumbent_matrix, incumbent_weights),
        len(incumbent_aligned),
        starting_capital,
    )
    gate = _gate(proposal_metrics, incumbent_metrics)
    proposal_streams = load_streams(stream_root, candidates=proposal_keys)
    try:
        concentration = concentration_tail.evaluate(
            keys=proposal_keys,
            weights=proposal_weights,
            dates=proposal_dates,
            matrix=proposal_matrix,
            streams=proposal_streams,
            starting_capital=starting_capital,
            policy_path=concentration_policy_path,
            symbol_matrix_path=symbol_matrix_path,
            repo_root=REPO_ROOT,
        )
    except concentration_tail.ConcentrationTailError as exc:
        raise BookBuildError(f"SP-C3 concentration evidence invalid: {exc}") from exc

    bindings = sleeve_bindings(REPO_ROOT, roster)
    by_key = {(row["ea_id"], row["symbol"]): row for row in bindings}
    sleeves: list[dict[str, Any]] = []
    for key in sorted(roster):
        binding = dict(by_key[key])
        sleeves.append({
            **binding,
            "weight": round(proposal_weights[key], 8),
            "risk_fixed_source": binding["backtest_risk_fixed"],
            "risk_percent_source": binding["backtest_risk_percent"],
        })
    sleeve_hash = sha256_bytes(canonical_json(sleeves).encode("ascii"))
    status = _final_status(gate, concentration)
    return {
        "schema": "qm.dual-book-manifest/v1",
        "lane": "Q11_DXZ",
        "as_of": as_of,
        "execution_mode": "DRY_RUN",
        "status": status,
        "application_authority": "OWNER_ONLY",
        "deployment_action": "NONE",
        "autotrading_action": "NONE",
        "roster": roster_provenance,
        "roster_sha256": roster_sha256(sleeves),
        "sleeve_list_sha256": sleeve_hash,
        "sleeves": sleeves,
        "weighting": {
            "method": "CAPPED_INVERSE_VOL_DAILY_PNL",
            "total_risk_pct": total_risk_pct,
            "sleeve_cap_pct": sleeve_cap_pct,
            "cluster_overlay": overlay_provenance,
        },
        "comparison": {
            "basis": "IDENTICAL_SEALED_COMMON_HISTORY",
            "window": {"start": start.isoformat(), "end": end.isoformat(), "days": len(proposal_dates)},
            "starting_capital": starting_capital,
            "proposal": proposal_metrics,
            "incumbent": incumbent_metrics,
            "incumbent_provenance": incumbent_provenance,
            "not_worse_gate": gate,
        },
        "stream_basis": stream_provenance,
        "concentration_tail": concentration,
        "schema_binding": file_binding(SCHEMA_PATH),
    }


def evidence_markdown(manifest: Mapping[str, Any], manifest_path: Path) -> str:
    gate = manifest["comparison"]["not_worse_gate"]
    checks = "\n".join(
        f"- {name}: {'PASS' if passed else 'FAIL'}"
        for name, passed in gate["checks"].items()
    )
    return f"""# Q11_DXZ dry-run book evidence

- Status: `{manifest['status']}`
- Execution: `DRY_RUN`; deployment and AutoTrading actions are `NONE`.
- Manifest: `{manifest_path}`
- Roster hash: `{manifest['roster_sha256']}`
- Hash-bound sleeve list: `{manifest['sleeve_list_sha256']}`
- Common history: `{manifest['comparison']['window']['start']}` through `{manifest['comparison']['window']['end']}` ({manifest['comparison']['window']['days']} days)
- Weighting: capped inverse-vol, cap `{manifest['weighting']['sleeve_cap_pct']}`, total `{manifest['weighting']['total_risk_pct']}`.

## Incumbent gate

{checks}

{concentration_tail.markdown_panel(manifest['concentration_tail'])}

`APPLY_RECOMMENDED` is emitted only when every incumbent and SP-C3 check passes
under an OWNER-ratified cap policy. Application remains an OWNER ceremony outside
this tool.
"""


def parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
    ap.add_argument("--roster", type=Path, default=DEFAULT_ROSTER)
    ap.add_argument("--incumbent", type=Path, default=DEFAULT_INCUMBENT)
    ap.add_argument("--stream-root", type=Path, default=DEFAULT_STREAM_ROOT)
    ap.add_argument("--cluster-overlay", type=Path)
    ap.add_argument("--total-risk-pct", type=float, default=9.75)
    ap.add_argument("--sleeve-cap-pct", type=float, default=1.0)
    ap.add_argument("--starting-capital", type=float, default=100_000.0)
    ap.add_argument("--concentration-policy", type=Path, default=DEFAULT_CONCENTRATION_POLICY)
    ap.add_argument("--symbol-matrix", type=Path, default=DEFAULT_SYMBOL_MATRIX)
    ap.add_argument("--as-of", default="2026-08-12")
    ap.add_argument("--out-dir", type=Path)
    return ap


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    out_dir = args.out_dir or DEFAULT_REPORT_ROOT / f"book_dxz_{args.as_of}"
    manifest_path = out_dir / "manifest.json"
    try:
        manifest = build_dxz_manifest(
            roster_path=args.roster,
            incumbent_path=args.incumbent,
            stream_root=args.stream_root,
            cluster_overlay_path=args.cluster_overlay,
            total_risk_pct=args.total_risk_pct,
            sleeve_cap_pct=args.sleeve_cap_pct,
            starting_capital=args.starting_capital,
            concentration_policy_path=args.concentration_policy,
            symbol_matrix_path=args.symbol_matrix,
            as_of=args.as_of,
        )
        validate_dual_book_manifest(manifest)
        risk_freeze.assert_live_book_mutation_allowed(
            "mint a proposed DXZ book manifest",
        )
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
        "dry_run": True,
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
