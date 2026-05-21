#!/usr/bin/env python3
"""P5b calibrated-noise MT5 runner.

P5b no longer treats synthetic Monte Carlo rows as a hard gate. It runs real
MT5 backtests with calibrated noise/stress setfiles and writes phase artifacts.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

from _phase_utils import add_common_args, build_result, ensure_dir, load_json, normalize_symbol, parse_float, parse_int, update_result_with_evidence_path, write_phase_artifacts


SCENARIOS = [
    ("p95", 1.0),
    ("p99", 1.35),
]


def _infer_parent_worker_terminal() -> str:
    if sys.platform != "win32":
        return ""
    command = (
        "$p=(Get-CimInstance Win32_Process -Filter \"ProcessId=%d\").CommandLine; "
        "if($p){[Console]::Out.Write($p)}"
    ) % os.getppid()
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", command],
        capture_output=True,
        text=True,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    match = re.search(r"--terminal\s+(T(?:10|[1-9]))\b", proc.stdout or "", re.IGNORECASE)
    return match.group(1).upper() if match else ""


def _infer_active_work_item(ea: str) -> dict[str, str]:
    db_path = Path("D:/QM/strategy_farm/state/farm_state.sqlite")
    if not db_path.exists():
        return {}
    try:
        with sqlite3.connect(db_path) as con:
            con.row_factory = sqlite3.Row
            row = con.execute(
                """
                SELECT symbol, setfile_path, claimed_by
                FROM work_items
                WHERE ea_id=? AND phase='P5b' AND status='active'
                ORDER BY updated_at DESC
                LIMIT 1
                """,
                (ea,),
            ).fetchone()
    except sqlite3.Error:
        return {}
    if not row:
        return {}
    return {
        "symbol": str(row["symbol"] or ""),
        "base_setfile": str(row["setfile_path"] or ""),
        "terminal": str(row["claimed_by"] or ""),
    }


def _ea_label_from_setfile(base_setfile: Path | None, ea: str) -> str:
    if base_setfile:
        for parent in [base_setfile.parent, *base_setfile.parents]:
            if parent.name.startswith(f"{ea}_"):
                return parent.name
    return ea


def _symbol_calibration(calibration: dict, symbol: str) -> dict:
    symbols = calibration.get("symbols") or {}
    symbol_key = symbol if symbol in symbols else f"{normalize_symbol(symbol)}.DWX"
    block = symbols.get(symbol_key) or {}
    if not block and symbols:
        first_key = next(iter(symbols.keys()))
        block = dict(symbols[first_key])
        block["source_symbol_fallback"] = first_key
    return block


def _write_noise_setfile(base_setfile: Path, target: Path, calibration: dict, multiplier: float) -> None:
    lines = base_setfile.read_text(encoding="utf-8", errors="replace").splitlines()
    spread = parse_float((calibration.get("spread_points") or {}).get("p95", 0.0)) * multiplier
    slippage = parse_float((calibration.get("slippage_points") or {}).get("p95", 0.0)) * multiplier
    commission = parse_float(calibration.get("commission_cents_per_lot", 0.0)) * multiplier
    lines.extend([
        f"Inp_SpreadPoints={round(spread, 4)}",
        f"Inp_SlippagePoints={round(slippage, 4)}",
        f"Inp_CommissionCentsPerLot={round(commission, 4)}",
    ])
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _summary_metrics(path: Path) -> dict[str, object]:
    summary = json.loads(path.read_text(encoding="utf-8-sig"))
    ok_runs = [r for r in summary.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
    first = ok_runs[0] if ok_runs else {}
    return {
        "summary_path": str(path),
        "result": str(summary.get("result") or ""),
        "profit_factor": parse_float(first.get("profit_factor", 0.0)),
        "trade_count": parse_int(first.get("total_trades", 0)),
        "net_profit": parse_float(first.get("net_profit", 0.0)),
    }


def _run_scenario(
    *,
    smoke_script: Path,
    ea: str,
    ea_label: str,
    symbol: str,
    year: int,
    period: str,
    terminal: str,
    setfile: Path,
    scenario: str,
    report_root: Path,
    min_trades: int,
    timeout_seconds: int,
) -> dict[str, object]:
    ea_num = int(ea.split("_", 1)[1])
    cmd = [
        "pwsh", "-NoProfile", "-File", str(smoke_script),
        "-EAId", str(ea_num),
        "-EALabel", ea_label,
        "-Symbol", symbol,
        "-Year", str(year),
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", "1",
        "-MinTrades", str(min_trades),
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-DispatchPhase", "P5b",
        "-DispatchVersion", scenario,
        "-TimeoutSeconds", str(timeout_seconds),
        "-AllowMissingRealTicksLogMarker",
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    proc = subprocess.run(
        cmd,
        cwd=str(Path(__file__).resolve().parents[2]),
        capture_output=True,
        text=True,
        timeout=timeout_seconds + 120,
        creationflags=creationflags,
    )
    summary_path = ""
    for line in (proc.stdout + "\n" + proc.stderr).splitlines():
        if line.startswith("run_smoke.summary="):
            summary_path = line.split("=", 1)[1].strip()
    if not summary_path or not Path(summary_path).exists():
        return {"scenario": scenario, "result": "FAIL", "reason": f"NO_SUMMARY_JSON rc={proc.returncode}", "stdout_tail": proc.stdout[-1200:], "stderr_tail": proc.stderr[-1200:]}
    metrics = _summary_metrics(Path(summary_path))
    metrics["scenario"] = scenario
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    add_common_args(parser)
    parser.add_argument("--calibration-json", required=True)
    parser.add_argument("--base-setfile", default="")
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--year", type=int, default=2024)
    parser.add_argument("--period", default="H1")
    parser.add_argument("--terminal", default="any")
    parser.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    parser.add_argument("--smoke-timeout-seconds", type=int, default=1200)
    parser.add_argument("--min-trades", type=int, default=5)
    parser.add_argument("--min-profit-factor", type=float, default=1.0)
    parser.add_argument("--trials-csv", default="", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if str(args.terminal).lower() in ("", "any"):
        args.terminal = _infer_parent_worker_terminal() or "T1"

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5b")
    inferred = _infer_active_work_item(args.ea) if (not args.base_setfile or not args.symbol) else {}
    if inferred:
        args.base_setfile = args.base_setfile or inferred.get("base_setfile", "")
        args.symbol = args.symbol or inferred.get("symbol", "")
        if str(args.terminal).lower() in ("", "any", "t1"):
            args.terminal = inferred.get("terminal") or args.terminal
    base_setfile = Path(args.base_setfile)
    if not args.base_setfile:
        result = build_result(
            phase="P5b",
            ea_id=args.ea,
            verdict="WAITING_INPUT",
            criterion="P5b requires --base-setfile for real calibrated-noise MT5 runs.",
            evidence_path=str(Path(args.calibration_json)),
            details={
                "calibration_json": str(Path(args.calibration_json)),
                "trials_csv_deprecated": str(Path(args.trials_csv)) if args.trials_csv else "",
                "real_mt5_run_count": 0,
                "failed_run_count": 0,
            },
        )
        result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5b", ea_id=args.ea, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0
    if not base_setfile.exists():
        raise ValueError(f"base setfile missing: {base_setfile}")
    calibration = _symbol_calibration(load_json(Path(args.calibration_json)), args.symbol)
    ea_label = _ea_label_from_setfile(base_setfile, args.ea)

    rows: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix=f"qm_p5b_{args.ea}_") as tmp:
        for scenario, multiplier in SCENARIOS:
            setfile = Path(tmp) / f"{args.ea}_{normalize_symbol(args.symbol)}_{scenario}.set"
            _write_noise_setfile(base_setfile, setfile, calibration, multiplier)
            rows.append(_run_scenario(
                smoke_script=Path(args.smoke_script),
                ea=args.ea,
                ea_label=ea_label,
                symbol=args.symbol,
                year=args.year,
                period=args.period,
                terminal=args.terminal,
                setfile=setfile,
                scenario=scenario,
                report_root=out_dir / "noise_runs",
                min_trades=args.min_trades,
                timeout_seconds=args.smoke_timeout_seconds,
            ))

    trials_path = out_dir / "p5b_trials.csv"
    with trials_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = ["scenario", "result", "profit_factor", "trade_count", "net_profit", "summary_path", "reason"]
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({key: row.get(key, "") for key in fieldnames})

    failures = []
    for row in rows:
        if str(row.get("result") or "").upper() != "PASS":
            failures.append({"scenario": row.get("scenario"), "reason": row.get("reason") or row.get("result")})
            continue
        if int(row.get("trade_count") or 0) < args.min_trades:
            failures.append({"scenario": row.get("scenario"), "reason": "MIN_TRADES_NOT_MET"})
        if float(row.get("profit_factor") or 0.0) < args.min_profit_factor:
            failures.append({"scenario": row.get("scenario"), "reason": "PF_BELOW_GATE"})

    verdict = "PASS" if rows and not failures else "FAIL"
    result = build_result(
        phase="P5b",
        ea_id=args.ea,
        verdict=verdict,
        criterion="P5b real calibrated-noise MT5 gate passed." if verdict == "PASS" else "P5b real calibrated-noise MT5 gate failed.",
        evidence_path=str(trials_path),
        details={
            "trial_count": len(rows),
            "real_mt5_run_count": sum(1 for row in rows if row.get("summary_path")),
            "failed_run_count": len(failures),
            "failures": failures,
            "rows": rows,
            "csv": str(trials_path),
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5b", ea_id=args.ea, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
