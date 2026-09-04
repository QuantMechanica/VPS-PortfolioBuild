"""Read-only comparison against exact census ledger cells; never enqueues work.

Returns 2 when any mandatory acceptance criterion is unmet. Performance is read
ONLY here, after the counter has produced performance-blind predictions.
"""
from __future__ import annotations

import argparse
import csv
import json
import sqlite3
from collections import Counter
from decimal import Decimal
from pathlib import Path

try:
    from . import pattern_fire_count as counter
except ImportError:
    import pattern_fire_count as counter

PROGRAMS = ("DL089_QM5_11421_EURUSD_DWX_2019_2025", "DL089_QM5_10706_GBPUSD_DWX_2019_2025")


def load_cell(conn, cell: dict) -> tuple[dict | None, str | None]:
    row = conn.execute("SELECT status,evidence_path,payload_json FROM work_items WHERE id=?",
                       (cell["work_item_id"],)).fetchone()
    if row is None: return None, "missing_work_item"
    if row["status"] != "done": return None, f"not_done:{row['status']}"
    path = Path(row["evidence_path"] or "")
    if not path.is_file(): return None, "missing_summary"
    summary = json.loads(path.read_text(encoding="utf-8-sig"))
    if summary.get("disposition") == "skipped_as_excluded":
        return None, "pruned_receipt_not_a_measured_cell"
    runs = [r for r in summary.get("runs", []) if r.get("status") == "OK"]
    if len(runs) != 1 or runs[0].get("net_profit") is None or runs[0].get("total_trades") is None:
        return None, "missing_or_ambiguous_metrics"
    run = runs[0]
    payload = json.loads(row["payload_json"] or "{}")
    if payload.get("arm") != cell["arm"] or int(payload.get("year", 0)) != int(cell["year"]):
        return None, "ledger_payload_mismatch"
    if payload.get("program_id") != cell["cell_key"].split(":", 1)[0]:
        return None, "ledger_program_mismatch"
    binary = summary.get("execution_identity", {}).get("expert_binary", {})
    observed_hash = binary.get("observed_after", {}).get("sha256")
    required_hash = binary.get("required_sha256")
    if not required_hash or observed_hash != required_hash or not binary.get("stable_during_run"):
        return None, "missing_or_unstable_binary_identity"
    return {"summary": summary, "path": str(path), "sha256": counter.sha256(path), "run": run,
            "net_profit": str(run["net_profit"]), "trades": int(run["total_trades"]),
            "ex5_sha256": required_hash}, None


def classify(predicted: int, baseline: dict, actual: dict) -> str:
    differs = (Decimal(actual["net_profit"]) != Decimal(baseline["net_profit"])
               or actual["trades"] != baseline["trades"])
    if predicted == 0: return "false_never_fires" if differs else "true_never_fires"
    return "true_fires" if differs else "false_fires"


def verify_program(conn, ledger_path: Path, bars: Path, output_dir: Path) -> dict:
    ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    program = ledger["program_id"]
    cells = ledger["cells"]
    if len({(int(c["year"]), c["arm"]) for c in cells}) != len(cells):
        raise ValueError("duplicate ledger year/arm")
    baselines, reports, excluded = {}, {}, []
    for cell in cells:
        if cell["arm"] != "baseline": continue
        result, reason = load_cell(conn, cell)
        if reason:
            excluded.append({"year": cell["year"], "arm": "baseline", "reason": reason,
                             "work_item_id": cell["work_item_id"]})
            continue
        report = Path(result["run"].get("report_canonical_path", ""))
        if not report.is_file() or counter.sha256(report) != result["run"].get("report_sha256"):
            raise ValueError(f"missing/mutated baseline report {cell['work_item_id']}")
        if len(counter.parse_report(report)[0]) != result["trades"]:
            raise ValueError(f"baseline report/summary trade-count mismatch {cell['work_item_id']}")
        baselines[int(cell["year"])], reports[int(cell["year"])] = result, report
    symbols = {base["summary"]["symbol"] for base in baselines.values()}
    if len(symbols) != 1: raise ValueError("missing or mixed baseline symbols")
    result = counter.count_program(program, symbols.pop(), reports, bars)
    counter.write_result(result, output_dir / f"{program}_counts.json")
    comparisons, matrix = [], Counter()
    for cell in cells:
        if cell["arm"] == "baseline": continue
        year, arm = int(cell["year"]), cell["arm"]
        if arm not in counter.ARMS: raise ValueError(f"unknown census arm {arm}")
        actual, reason = load_cell(conn, cell)
        if not reason and year not in baselines: reason = "baseline_unavailable"
        if reason:
            excluded.append({"year": year, "arm": arm, "reason": reason, "work_item_id": cell["work_item_id"]})
            continue
        base = baselines[year]
        if any(base["summary"].get(k) != actual["summary"].get(k)
               for k in ("symbol", "period", "from_date", "to_date", "model", "ea_id")):
            excluded.append({"year": year, "arm": arm, "reason": "different_execution_context",
                             "work_item_id": cell["work_item_id"]})
            continue
        predicted = result["counts_by_year"][str(year)][arm]
        all_orders = result["all_order_counts_by_year_diagnostic"][str(year)][arm]
        outcome = classify(predicted, base, actual)
        matrix[outcome] += 1
        row = {"year": year, "arm": arm, "predicted_fire_count": predicted,
               "all_order_fire_count_diagnostic": all_orders, "outcome": outcome,
               "baseline_profit": base["net_profit"], "cell_profit": actual["net_profit"],
               "baseline_trades": base["trades"], "cell_trades": actual["trades"],
               "work_item_id": cell["work_item_id"], "summary_path": actual["path"],
               "summary_sha256": actual["sha256"], "baseline_summary_sha256": base["sha256"],
               "same_ex5": bool(base["ex5_sha256"]) and base["ex5_sha256"] == actual["ex5_sha256"]}
        if outcome.startswith("false"):
            side, pid_text = arm.split("_")
            pid = int(pid_text)
            row["affected_baseline_entries"] = [e for e in result["entry_alignment"][str(year)]
                if e["direction"].lower() == side and pid in e["fired_predicates"]]
            if not row["same_ex5"]:
                row["explanation"] = "Binary identity differs; this is not a controlled same-binary comparison."
            elif outcome == "false_never_fires" and all_orders:
                row["explanation"] = ("No filled baseline entry fires, but candidate orders do. Blocking an unfilled "
                    "order can change later state/opportunities. This is a diagnostic hypothesis, not proven causality; "
                    "native gate trace and tick-derived bars are required. The zero-count skip is unsafe.")
            elif outcome == "false_never_fires":
                row["explanation"] = ("No baseline order fires in these bars yet cell metrics differ. Unresolved "
                    "bar-source, reference-time or execution mismatch; do not skip this arm.")
            else:
                row["explanation"] = ("A predicate matches a filled baseline order but aggregate profit/trades are equal. "
                    "Baseline-entry coincidence does not prove changed aggregate results: later requests may replace "
                    "a blocked request. Bar provenance and the native gate trace remain unverified; no causal claim.")
        comparisons.append(row)
    total = len(comparisons)
    agreement = (matrix["true_never_fires"] + matrix["true_fires"]) / total if total else 0.0
    metric_pass = total > 0 and not matrix["false_never_fires"] and agreement >= .95
    # A self-declared cache flag is deliberately insufficient for acceptance.
    # This first delivery has no raw-TKC decoder or tester-bar attestation verifier.
    blockers = ["Raw DWX TKC tick derivation and 20 tester-bar spot checks have not been verified."]
    if not metric_pass: blockers.append("The zero-false-never-fires / >=95% metric criterion failed.")
    if any(not r["same_ex5"] for r in comparisons): blockers.append("Some compared cells use different binaries.")
    if any(not r["reason"].startswith("not_done:") for r in excluded):
        blockers.append("Some completed/missing cells lack usable comparison evidence.")
    years = {str(y): sum(r["year"] == y for r in comparisons) for y in sorted(reports)}
    result_summary = {"program_id": program, "ledger_path": str(ledger_path),
                      "ledger_sha256": counter.sha256(ledger_path), "baseline_years": sorted(reports),
                      "compared_arms_by_year": years, "compared_cells": total,
                      "confusion_matrix": {k: matrix[k] for k in
                        ("true_never_fires", "false_never_fires", "true_fires", "false_fires")},
                      "agreement": agreement, "metric_criterion_pass": metric_pass,
                      "accepted": False, "acceptance_blockers": blockers,
                      "never_firing_arms_observed_years": result["never_fires_observed_years"],
                      "never_firing_share_observed_years": len(result["never_fires_observed_years"]) / 154,
                      "disagreements": [r for r in comparisons if r["outcome"].startswith("false")],
                      "excluded": excluded, "comparisons": comparisons,
                      "bars_provenance": result["bars_provenance"]}
    out = output_dir / f"{program}_verification.json"
    out.write_text(json.dumps(result_summary, indent=2) + "\n", encoding="utf-8")
    with out.with_suffix(".csv").open("w", encoding="utf-8", newline="") as f:
        fields = ["year", "arm", "predicted_fire_count", "all_order_fire_count_diagnostic", "outcome",
                  "baseline_profit", "cell_profit", "baseline_trades", "cell_trades", "work_item_id", "same_ex5"]
        w = csv.DictWriter(f, fieldnames=fields, extrasaction="ignore"); w.writeheader(); w.writerows(comparisons)
    return result_summary


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=Path("D:/QM/strategy_farm/state/farm_state.sqlite"))
    ap.add_argument("--census-root", type=Path, default=Path("D:/QM/strategy_farm/artifacts/opt_census"))
    ap.add_argument("--bars-root", type=Path, default=Path("D:/QM/data/research/d1_bars"))
    ap.add_argument("--output-dir", type=Path, required=True)
    args = ap.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(args.db.resolve().as_uri() + "?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row
    conn.execute("BEGIN")  # both programs see one read snapshot
    try:
        results = [verify_program(conn, args.census_root / program / "ledger.json",
                    args.bars_root / f"{symbol}.csv", args.output_dir)
                   for program, symbol in zip(PROGRAMS, ("EURUSD.DWX", "GBPUSD.DWX"))]
    finally:
        conn.close()
    print(json.dumps([{k: r[k] for k in ("program_id", "compared_cells", "confusion_matrix", "agreement",
                     "accepted", "acceptance_blockers", "never_firing_share_observed_years")} for r in results], indent=2))
    return 0 if all(r["accepted"] for r in results) else 2


if __name__ == "__main__":
    raise SystemExit(main())
