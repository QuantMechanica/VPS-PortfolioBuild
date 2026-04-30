#!/usr/bin/env python3
"""P8 news impact mode-selection runner."""

from __future__ import annotations

import argparse
from pathlib import Path

from _phase_utils import (
    add_common_args,
    build_result,
    ensure_dir,
    load_csv_rows,
    parse_bool_like,
    parse_float,
    parse_int,
    row_symbol,
    update_result_with_evidence_path,
    write_phase_artifacts,
)

MODE_ALIASES = {
    "OFF": "OFF",
    "PAUSE": "PAUSE",
    "SKIP_DAY": "SKIP_DAY",
    "FTMO_PAUSE": "FTMO_PAUSE",
    "5ERS_PAUSE": "5ers_PAUSE",
    "NO_NEWS": "no_news",
    "NO_NEWS_ONLY": "no_news",
    "NEWS_ONLY": "news_only",
}
DEFAULT_MODES = ["OFF", "PAUSE", "SKIP_DAY", "FTMO_PAUSE", "5ers_PAUSE", "no_news", "news_only"]
FALLBACK_SYMBOL = "ALL_SYMBOLS"


def normalize_mode(mode: str) -> str:
    text = (mode or "").strip().upper()
    return MODE_ALIASES.get(text, "")


def is_row_eligible(row: dict[str, str]) -> bool:
    pf = parse_float(row.get("pf"), 0.0)
    trades = parse_int(row.get("trades"), 0)
    return pf >= 1.0 and trades > 0


def parse_modes_text(modes_text: str) -> list[str]:
    text = (modes_text or "").strip()
    if text.lower() in {"", "all", "*"}:
        return list(DEFAULT_MODES)

    modes: list[str] = []
    seen: set[str] = set()
    for chunk in text.split(","):
        normalized = normalize_mode(chunk)
        if not normalized:
            continue
        if normalized in seen:
            continue
        seen.add(normalized)
        modes.append(normalized)
    if not modes:
        raise ValueError("At least one valid mode is required")
    return modes


def summarize_symbol_modes(rows: list[dict[str, str]]) -> dict[str, object]:
    eligible = [r for r in rows if is_row_eligible(r)]
    if eligible:
        eligible.sort(
            key=lambda r: (
                parse_float(r.get("pf"), 0.0),
                parse_float(r.get("sharpe"), 0.0),
                -parse_float(r.get("drawdown_pct"), 999.0),
            ),
            reverse=True,
        )
        recommended = eligible[0].get("mode", "OFF")
        verdict = "MODE_SELECTED"
    else:
        recommended = "OFF" if any(r.get("mode", "") == "OFF" for r in rows) else "REVIEW_REQUIRED"
        verdict = "NO_ELIGIBLE_MODE"

    matrix_summary = []
    for row in rows:
        matrix_summary.append(
            {
                "compliance_5ers": parse_bool_like(row.get("compliance_5ers", "")),
                "compliance_ftmo": parse_bool_like(row.get("compliance_ftmo", "")),
                "compliance_news_only": parse_bool_like(row.get("compliance_news_only", "")),
                "compliance_no_news": parse_bool_like(row.get("compliance_no_news", "")),
                "drawdown_pct": parse_float(row.get("drawdown_pct"), 0.0),
                "mode": row.get("mode", ""),
                "pf": parse_float(row.get("pf"), 0.0),
                "sharpe": parse_float(row.get("sharpe", 0.0)),
                "trades": parse_int(row.get("trades"), 0),
            }
        )

    compliance_summary = {
        "fiveers_pass": any(parse_bool_like(row.get("compliance_5ers", "")) for row in rows),
        "ftmo_pass": any(parse_bool_like(row.get("compliance_ftmo", "")) for row in rows),
        "news_only_pass": any(parse_bool_like(row.get("compliance_news_only", "")) for row in rows),
        "no_news_pass": any(parse_bool_like(row.get("compliance_no_news", "")) for row in rows),
    }

    return {
        "compliance": compliance_summary,
        "eligible_mode_count": len(eligible),
        "matrix": matrix_summary,
        "recommended_mode": recommended,
        "verdict": verdict,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate P8 news-mode matrix and recommend deploy mode")
    add_common_args(parser)
    parser.add_argument("--news-matrix")
    parser.add_argument("--matrix-csv", dest="matrix_csv_legacy", help=argparse.SUPPRESS)
    parser.add_argument("--modes", default="all")
    args = parser.parse_args()

    ea_id = args.ea
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P8")

    matrix_path_text = args.news_matrix or args.matrix_csv_legacy
    if not matrix_path_text:
        parser.error("--news-matrix is required")
    matrix_path = Path(matrix_path_text)
    selected_modes = parse_modes_text(args.modes)
    selected_mode_set = set(selected_modes)

    rows = load_csv_rows(matrix_path)
    filtered_rows: list[dict[str, str]] = []
    for raw in rows:
        normalized_mode = normalize_mode(raw.get("mode", ""))
        if not normalized_mode or normalized_mode not in selected_mode_set:
            continue
        row = dict(raw)
        row["mode"] = normalized_mode
        filtered_rows.append(row)

    by_symbol: dict[str, list[dict[str, str]]] = {}
    for row in filtered_rows:
        symbol = row_symbol(row).strip() or FALLBACK_SYMBOL
        by_symbol.setdefault(symbol, []).append(row)
    symbol_keys = sorted(by_symbol.keys())

    symbol_results: list[dict[str, object]] = []
    recommended_mode_by_symbol: dict[str, str] = {}
    has_no_eligible = False
    for symbol in symbol_keys:
        summary = summarize_symbol_modes(by_symbol[symbol])
        if summary["verdict"] == "NO_ELIGIBLE_MODE":
            has_no_eligible = True
        recommended_mode_by_symbol[symbol] = str(summary["recommended_mode"])
        symbol_results.append(
            {
                "symbol": symbol,
                "compliance": summary["compliance"],
                "eligible_mode_count": summary["eligible_mode_count"],
                "matrix": summary["matrix"],
                "recommended_mode": summary["recommended_mode"],
                "verdict": summary["verdict"],
            }
        )

    if symbol_results and not has_no_eligible:
        verdict = "MODE_SELECTED"
        criterion = "Recommended mode selected per symbol by PF/Sharpe eligibility ranking"
    elif symbol_results:
        verdict = "NO_ELIGIBLE_MODE"
        criterion = "At least one symbol had no eligible mode (PF >= 1.0, trades > 0)"
    else:
        verdict = "NO_ELIGIBLE_MODE"
        criterion = "No recognized rows matched selected modes"

    aggregate_compliance = {
        "fiveers_pass": any(bool(item["compliance"]["fiveers_pass"]) for item in symbol_results),
        "ftmo_pass": any(bool(item["compliance"]["ftmo_pass"]) for item in symbol_results),
        "news_only_pass": any(bool(item["compliance"]["news_only_pass"]) for item in symbol_results),
        "no_news_pass": any(bool(item["compliance"]["no_news_pass"]) for item in symbol_results),
    }
    details = {
        "compliance": aggregate_compliance,
        "matrix": [
            row
            for item in symbol_results
            for row in [
                dict(entry, symbol=item["symbol"])  # keep flat matrix compatibility with symbol column
                for entry in item["matrix"]
            ]
        ],
        "recommended_mode": symbol_results[0]["recommended_mode"] if len(symbol_results) == 1 else None,
        "recommended_mode_by_symbol": recommended_mode_by_symbol,
        "selected_modes": selected_modes,
        "symbol_results": symbol_results,
    }

    result = build_result(
        phase="P8",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path="",
        details=details,
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P8", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
