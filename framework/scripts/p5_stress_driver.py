#!/usr/bin/env python3
"""Build P5 clean/stress metrics by driving run_smoke.ps1 deterministically."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

from _phase_utils import ensure_dir, load_json, normalize_symbol, parse_float, parse_int, write_json


def _read_smoke_summary(path: Path) -> dict:
    data = load_json(path)
    runs = [r for r in data.get("runs", []) if str(r.get("status", "")).upper() == "OK"]
    first = runs[0] if runs else {}
    return {
        "pf": parse_float(first.get("profit_factor", 0.0)),
        "trade_count": parse_int(first.get("total_trades", 0)),
        "summary_path": str(path),
    }


def _run_smoke(
    smoke_script: Path,
    *,
    ea_id: int,
    symbol: str,
    year: int,
    period: str,
    terminal: str,
    runs: int,
    min_trades: int,
    setfile: Path | None,
    allow_running_terminal: bool,
    smoke_timeout_seconds: int,
) -> Path:
    cmd = [
        "pwsh",
        "-NoProfile",
        "-File",
        str(smoke_script),
        "-EAId",
        str(ea_id),
        "-Symbol",
        symbol,
        "-Year",
        str(year),
        "-Period",
        period,
        "-Terminal",
        terminal,
        "-Runs",
        str(runs),
        "-MinTrades",
        str(min_trades),
    ]
    if setfile:
        cmd.extend(["-SetFile", str(setfile)])
    if allow_running_terminal:
        cmd.append("-AllowRunningTerminal")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=smoke_timeout_seconds)
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"run_smoke timed out after {smoke_timeout_seconds}s\ncmd={' '.join(cmd)}") from exc
    if proc.returncode != 0:
        raise RuntimeError(f"run_smoke failed\ncmd={' '.join(cmd)}\nstdout={proc.stdout}\nstderr={proc.stderr}")
    summary_line = ""
    for line in proc.stdout.splitlines():
        if line.startswith("run_smoke.summary="):
            summary_line = line
    if not summary_line:
        raise RuntimeError(f"run_smoke summary path missing\nstdout={proc.stdout}\nstderr={proc.stderr}")
    return Path(summary_line.split("=", 1)[1].strip())


def _write_stress_setfile(base_setfile: Path | None, out_path: Path, *, commission_cents_per_lot: float, spread_points: float) -> None:
    lines: list[str] = []
    if base_setfile and base_setfile.exists():
        lines.extend(base_setfile.read_text(encoding="utf-8", errors="replace").splitlines())
    lines.append(f"Inp_CommissionCentsPerLot={commission_cents_per_lot}")
    lines.append(f"Inp_SpreadPoints={spread_points}")
    out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--ea", required=True, help="QM5_<id>")
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--year", type=int, required=True)
    ap.add_argument("--period", default="H1")
    ap.add_argument("--terminal", default="T1")
    ap.add_argument("--runs", type=int, default=2)
    ap.add_argument("--min-trades", type=int, default=20)
    ap.add_argument("--calibration-json", required=True)
    ap.add_argument("--base-setfile", default="")
    ap.add_argument("--out-prefix", default="D:/QM/reports/pipeline")
    ap.add_argument("--smoke-script", default="framework/scripts/run_smoke.ps1")
    ap.add_argument("--allow-running-terminal", action="store_true")
    ap.add_argument("--smoke-timeout-seconds", type=int, default=1200)
    ap.add_argument("--mock-clean-summary", default="")
    ap.add_argument("--mock-stress-summary", default="")
    args = ap.parse_args()

    out_dir = ensure_dir(Path(args.out_prefix) / args.ea / "P5")
    calibration = load_json(Path(args.calibration_json))
    symbol_key = args.symbol if args.symbol in calibration.get("symbols", {}) else f"{normalize_symbol(args.symbol)}.DWX"
    block = calibration.get("symbols", {}).get(symbol_key, {})
    commission = parse_float(block.get("commission_cents_per_lot", 0.0))
    spread = parse_float(block.get("spread_points", {}).get("p95", 0.0))

    base_setfile = Path(args.base_setfile) if args.base_setfile else None
    stress_setfile = out_dir / f"{args.ea}_{normalize_symbol(args.symbol)}_P5_STRESS.set"
    _write_stress_setfile(base_setfile, stress_setfile, commission_cents_per_lot=commission, spread_points=spread)

    if args.mock_clean_summary and args.mock_stress_summary:
        clean_summary_path = Path(args.mock_clean_summary)
        stress_summary_path = Path(args.mock_stress_summary)
    else:
        ea_num = int(args.ea.split("_")[1])
        clean_summary_path = _run_smoke(
            Path(args.smoke_script),
            ea_id=ea_num,
            symbol=args.symbol,
            year=args.year,
            period=args.period,
            terminal=args.terminal,
            runs=args.runs,
            min_trades=args.min_trades,
            setfile=base_setfile,
            allow_running_terminal=args.allow_running_terminal,
            smoke_timeout_seconds=args.smoke_timeout_seconds,
        )
        stress_summary_path = _run_smoke(
            Path(args.smoke_script),
            ea_id=ea_num,
            symbol=args.symbol,
            year=args.year,
            period=args.period,
            terminal=args.terminal,
            runs=args.runs,
            min_trades=args.min_trades,
            setfile=stress_setfile,
            allow_running_terminal=args.allow_running_terminal,
            smoke_timeout_seconds=args.smoke_timeout_seconds,
        )

    clean_metrics = _read_smoke_summary(clean_summary_path)
    stress_metrics = _read_smoke_summary(stress_summary_path)

    clean_path = out_dir / "p5_clean_metrics.json"
    stress_path = out_dir / "p5_stress_metrics.json"
    write_json(clean_path, {"symbol": args.symbol, "pf": clean_metrics["pf"], "trade_count": clean_metrics["trade_count"]})
    write_json(stress_path, {"symbol": args.symbol, "pf": stress_metrics["pf"], "trade_count": stress_metrics["trade_count"]})
    print(json.dumps({"clean_metrics_json": str(clean_path), "stress_metrics_json": str(stress_path), "stress_setfile": str(stress_setfile)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
