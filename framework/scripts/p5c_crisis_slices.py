#!/usr/bin/env python3
"""P5c crisis-slice MT5 runner.

P5c is a hard gate only when every named slice is backed by a real MT5
summary.json. It does not accept proxy multipliers.
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
from pathlib import Path

from _phase_utils import add_common_args, build_result, ensure_dir, load_csv_rows, parse_float, parse_int, update_result_with_evidence_path, write_phase_artifacts


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
                WHERE ea_id=? AND phase='P5c' AND status='active'
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


def _summary_metrics(path: Path) -> dict[str, object]:
    summary = json.loads(path.read_text(encoding="utf-8-sig"))
    ok_runs = [r for r in summary.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
    first = ok_runs[0] if ok_runs else {}
    reason_classes = [str(r) for r in (summary.get("reason_classes") or [])]
    result = str(summary.get("result") or "")
    if "NO_HISTORY" in {r.upper() for r in reason_classes}:
        result = "NO_HISTORY"
    return {
        "summary_path": str(path),
        "result": result,
        "reason_classes": ",".join(reason_classes),
        "profit_factor": parse_float(first.get("profit_factor", 0.0)),
        "trade_count": parse_int(first.get("total_trades", 0)),
        "net_profit": parse_float(first.get("net_profit", 0.0)),
    }


def _run_slice(
    *,
    smoke_script: Path,
    ea: str,
    ea_label: str,
    symbol: str,
    period: str,
    terminal: str,
    setfile: Path,
    slice_name: str,
    start: str,
    end: str,
    report_root: Path,
    min_trades: int,
    timeout_seconds: int,
) -> dict[str, object]:
    ea_num = int(ea.split("_", 1)[1])
    cmd = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(smoke_script),
        "-EAId", str(ea_num),
        "-EALabel", ea_label,
        "-Symbol", symbol,
        "-Year", start[:4],
        "-FromDate", start,
        "-ToDate", end,
        "-Terminal", terminal,
        "-Period", period,
        "-Runs", "1",
        "-MinTrades", str(min_trades),
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-DispatchPhase", "P5c",
        "-DispatchVersion", slice_name,
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
        return {
            "slice": slice_name,
            "start": start,
            "end": end,
            "result": "FAIL",
            "reason": f"NO_SUMMARY_JSON rc={proc.returncode}",
            "stdout_tail": proc.stdout[-1200:],
            "stderr_tail": proc.stderr[-1200:],
        }
    metrics = _summary_metrics(Path(summary_path))
    metrics.update({"slice": slice_name, "start": start, "end": end})
    return metrics


def main() -> int:
    parser = argparse.ArgumentParser(description="Run real P5c crisis slices in MT5")
    add_common_args(parser)
    parser.add_argument("--slices-csv", required=True)
    parser.add_argument("--base-setfile", default="")
    parser.add_argument("--symbol", default="")
    parser.add_argument("--period", default="H1")
    parser.add_argument("--terminal", default="any")
    parser.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    parser.add_argument("--smoke-timeout-seconds", type=int, default=1200)
    parser.add_argument("--min-trades", type=int, default=1)
    parser.add_argument("--min-profit-factor", type=float, default=1.0)
    parser.add_argument("--clean-metrics-json", default="", help=argparse.SUPPRESS)
    parser.add_argument("--stress-metrics-json", default="", help=argparse.SUPPRESS)
    args = parser.parse_args()

    if str(args.terminal).lower() in ("", "any"):
        args.terminal = _infer_parent_worker_terminal() or "T1"

    ea_id = args.ea
    inferred = _infer_active_work_item(ea_id) if (not args.base_setfile or not args.symbol) else {}
    if inferred:
        args.base_setfile = args.base_setfile or inferred.get("base_setfile", "")
        args.symbol = args.symbol or inferred.get("symbol", "")
        if str(args.terminal).lower() in ("", "any", "t1"):
            args.terminal = inferred.get("terminal") or args.terminal
    out_dir = ensure_dir(Path(args.out_prefix) / ea_id / "P5c")
    rows = load_csv_rows(Path(args.slices_csv))
    setfile = Path(args.base_setfile)
    if not args.base_setfile or not args.symbol:
        result = build_result(
            phase="P5c",
            ea_id=ea_id,
            verdict="WAITING_INPUT",
            criterion="P5c requires --base-setfile and --symbol for real MT5 crisis-slice runs.",
            evidence_path=str(Path(args.slices_csv)),
            details={"slices_csv": str(Path(args.slices_csv)), "slice_count": len(rows)},
        )
        result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5c", ea_id=ea_id, result=result)
        update_result_with_evidence_path(result_path, result)
        print(result_path)
        return 0
    if not setfile.exists():
        raise ValueError(f"base setfile missing: {setfile}")
    ea_label = _ea_label_from_setfile(setfile, ea_id)

    results = [
        _run_slice(
            smoke_script=Path(args.smoke_script),
            ea=ea_id,
            ea_label=ea_label,
            symbol=args.symbol,
            period=args.period,
            terminal=args.terminal,
            setfile=setfile,
            slice_name=str(row.get("slice") or "UNKNOWN"),
            start=str(row.get("start") or ""),
            end=str(row.get("end") or ""),
            report_root=out_dir / "slice_runs",
            min_trades=args.min_trades,
            timeout_seconds=args.smoke_timeout_seconds,
        )
        for row in rows
    ]

    csv_path = out_dir / "p5c_crisis_slices.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        fieldnames = ["slice", "start", "end", "result", "profit_factor", "trade_count", "net_profit", "summary_path", "reason_classes", "reason"]
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for row in results:
            writer.writerow({key: row.get(key, "") for key in fieldnames})

    failures = []
    unavailable = []
    for row in results:
        if str(row.get("result") or "").upper() == "NO_HISTORY":
            unavailable.append({"slice": row.get("slice"), "reason": "NO_HISTORY"})
            continue
        if str(row.get("result") or "").upper() != "PASS":
            failures.append({"slice": row.get("slice"), "reason": row.get("reason") or row.get("reason_classes") or row.get("result")})
            continue
        if int(row.get("trade_count") or 0) < args.min_trades:
            failures.append({"slice": row.get("slice"), "reason": "MIN_TRADES_NOT_MET"})
        if float(row.get("profit_factor") or 0.0) < args.min_profit_factor:
            failures.append({"slice": row.get("slice"), "reason": "PF_BELOW_GATE"})

    available_results = [row for row in results if str(row.get("result") or "").upper() != "NO_HISTORY"]
    verdict = "PASS" if not failures and available_results else "FAIL"
    criterion = "P5c real MT5 crisis-slice gate passed." if verdict == "PASS" else "P5c real MT5 crisis-slice gate failed."
    result = build_result(
        phase="P5c",
        ea_id=ea_id,
        verdict=verdict,
        criterion=criterion,
        evidence_path=str(csv_path),
        details={
            "slice_count": len(results),
            "available_slice_count": len(available_results),
            "unavailable_slices": unavailable,
            "failures": failures,
            "rows": results,
            "csv": str(csv_path),
        },
    )
    result_path, _ = write_phase_artifacts(out_dir=out_dir, phase="P5c", ea_id=ea_id, result=result)
    update_result_with_evidence_path(result_path, result)
    print(result_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
