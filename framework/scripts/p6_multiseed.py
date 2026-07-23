import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Sequence

DEFAULT_SEEDS = (42, 17, 99, 7, 2026)


def _parse_seed_csv(seed_csv: str) -> List[int]:
    if not seed_csv.strip():
        raise ValueError("Seed list cannot be empty.")
    seeds: List[int] = []
    for raw in seed_csv.split(","):
        token = raw.strip()
        if not token:
            raise ValueError("Seed list contains an empty value.")
        seeds.append(int(token))
    return seeds


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _load_seed_evidence(seed_dir: Path, seed: int) -> Dict[str, Any]:
    evidence_path = seed_dir / f"seed_{seed}.json"
    if not evidence_path.exists():
        return {
            "seed": seed,
            "status": "MISSING",
            "evidence_path": str(evidence_path),
            "criterion": "Seed evidence file missing.",
        }

    payload = json.loads(evidence_path.read_text(encoding="utf-8"))
    pf = payload.get("profit_factor")
    seed_pass = payload.get("seed_pass")
    trade_count = payload.get("trade_count")
    if not _is_number(pf):
        raise ValueError(f"Seed {seed} evidence must include numeric 'profit_factor'.")
    if not isinstance(seed_pass, bool):
        raise ValueError(f"Seed {seed} evidence must include boolean 'seed_pass'.")
    if not isinstance(trade_count, int):
        raise ValueError(f"Seed {seed} evidence must include integer 'trade_count'.")

    return {
        "seed": seed,
        "status": "OK",
        "evidence_path": str(evidence_path),
        "profit_factor": float(pf),
        "trade_count": trade_count,
        "seed_pass": seed_pass,
    }


def _compute_verdict(seed_metrics: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    missing_count = sum(1 for m in seed_metrics if m["status"] != "OK")
    if missing_count > 0:
        return {
            "verdict": "MULTI_SEED_WAIVER",
            "criterion": "Evidence missing for one or more seeds.",
            "pass_count": 0,
            "has_pf_below_one": False,
            "missing_evidence_count": missing_count,
        }

    pass_count = sum(1 for m in seed_metrics if m["seed_pass"])
    has_pf_below_one = any(m["profit_factor"] < 1.0 for m in seed_metrics)

    if pass_count >= 3 and not has_pf_below_one:
        verdict = "MULTI_SEED_PASS"
        criterion = ">= 3 seeds passed and no seed has PF < 1.0."
    elif pass_count >= 3 and has_pf_below_one:
        verdict = "MULTI_SEED_MIXED"
        criterion = ">= 3 seeds passed but at least one seed has PF < 1.0."
    else:
        verdict = "MULTI_SEED_FAIL"
        criterion = "< 3 seeds passed."

    return {
        "verdict": verdict,
        "criterion": criterion,
        "pass_count": pass_count,
        "has_pf_below_one": has_pf_below_one,
        "missing_evidence_count": 0,
    }


def _write_markdown_report(
    output_root: Path,
    ea_id: str,
    symbol: str,
    payload: Dict[str, Any],
) -> Path:
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_symbol = symbol.replace("/", "_")
    target_dir = output_root / ea_id / "P6"
    target_dir.mkdir(parents=True, exist_ok=True)
    report_path = target_dir / f"P6_{ea_id}_{safe_symbol}_{ts}.md"

    lines = [
        f"# P6 Multi-Seed Report - {ea_id} ({symbol})",
        "",
        f"- phase: {payload['phase']}",
        f"- ea_id: {payload['ea_id']}",
        f"- symbol: {payload['symbol']}",
        f"- verdict: {payload['verdict']}",
        f"- criterion: {payload['criterion']}",
        f"- pass_count: {payload['details']['pass_count']}",
        f"- has_pf_below_one: {str(payload['details']['has_pf_below_one']).lower()}",
        f"- missing_evidence_count: {payload['details']['missing_evidence_count']}",
        "",
        "| seed | status | seed_pass | profit_factor | trade_count | evidence_path |",
        "|---:|---|---:|---:|---:|---|",
    ]

    for metric in payload["details"]["per_seed_metrics"]:
        seed_pass = "" if "seed_pass" not in metric else str(metric["seed_pass"]).lower()
        pf = "" if "profit_factor" not in metric else f"{metric['profit_factor']:.6f}"
        trade_count = "" if "trade_count" not in metric else str(metric["trade_count"])
        lines.append(
            f"| {metric['seed']} | {metric['status']} | {seed_pass} | {pf} | {trade_count} | {metric['evidence_path']} |"
        )

    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return report_path


def run_p6_multiseed(
    ea_id: str,
    seeds: Sequence[int],
    symbol: str,
    seed_metrics_dir: Path,
    output_root: Path,
) -> Dict[str, Any]:
    per_seed_metrics = [_load_seed_evidence(seed_metrics_dir, seed) for seed in seeds]
    verdict_data = _compute_verdict(per_seed_metrics)

    payload = {
        "phase": "P6",
        "ea_id": ea_id,
        "symbol": symbol,
        "verdict": verdict_data["verdict"],
        "criterion": verdict_data["criterion"],
        "details": {
            "seeds": list(seeds),
            "pass_count": verdict_data["pass_count"],
            "has_pf_below_one": verdict_data["has_pf_below_one"],
            "missing_evidence_count": verdict_data["missing_evidence_count"],
            "per_seed_metrics": per_seed_metrics,
        },
    }

    evidence_path = _write_markdown_report(output_root, ea_id, symbol, payload)
    payload["evidence_path"] = str(evidence_path)

    print(
        json.dumps(
            {
                "phase": payload["phase"],
                "ea_id": payload["ea_id"],
                "verdict": payload["verdict"],
                "criterion": payload["criterion"],
                "evidence_path": payload["evidence_path"],
            }
        )
    )
    return payload


def main() -> int:
    parser = argparse.ArgumentParser(description="Run P6 multi-seed stability gate checks.")
    parser.add_argument("--ea", required=True, dest="ea_id")
    parser.add_argument("--seeds", default="42,17,99,7,2026")
    parser.add_argument("--symbol", default="EURUSD.DWX")
    parser.add_argument("--seed-metrics-dir", default="framework/reports/seed_metrics")
    parser.add_argument("--output-root", default="D:/QM/reports/pipeline")
    args = parser.parse_args()

    result = run_p6_multiseed(
        ea_id=args.ea_id,
        seeds=_parse_seed_csv(args.seeds),
        symbol=args.symbol,
        seed_metrics_dir=Path(args.seed_metrics_dir),
        output_root=Path(args.output_root),
    )

    if result["verdict"] in ("MULTI_SEED_PASS", "MULTI_SEED_MIXED"):
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
