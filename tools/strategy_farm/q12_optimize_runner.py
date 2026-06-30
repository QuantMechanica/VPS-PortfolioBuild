#!/usr/bin/env python3
"""Run bounded Q12 research optimizations on a dedicated MT5 terminal.

This script is intentionally outside the canonical pipeline state machine. It
writes research setfiles and reports, runs MT5 via framework/scripts/run_smoke.ps1,
and records the parsed outcomes. It does not insert work_items, mutate registry
state, or mark any gate PASS.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
RUN_SMOKE = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
DEFAULT_WORK_ROOT = Path(r"D:\QM\strategy_farm\scratch\q12_opt")
DEFAULT_REPORT_ROOT = Path(r"D:\QM\reports\q12_opt")


@dataclass(frozen=True)
class Candidate:
    ea_id: int
    ea_dir: str
    symbol: str
    period: str
    baseline_setfile: Path
    min_trades: int
    variants: list[tuple[str, dict[str, Any]]]

    @property
    def label(self) -> str:
        return f"QM5_{self.ea_id}"

    @property
    def expert(self) -> str:
        return f"QM\\{self.ea_dir}"


def p(path: str) -> Path:
    return Path(path)


def candidates() -> list[Candidate]:
    eas = REPO_ROOT / "framework" / "EAs"
    return [
        Candidate(
            10440,
            "QM5_10440_mql5-ohlc-mtf",
            "NDX.DWX",
            "H1",
            eas / "QM5_10440_mql5-ohlc-mtf" / "sets" / "QM5_10440_mql5-ohlc-mtf_NDX.DWX_H1_backtest_grid_035.set",
            20,
            [
                ("center_stop050", {"strategy_entry_atr_offset_mult": 0.07, "strategy_stop_min_atr_mult": 0.50, "strategy_stop_max_atr_mult": 2.50, "strategy_take_profit_r": 2.00}),
                ("center_stop065", {"strategy_entry_atr_offset_mult": 0.07, "strategy_stop_min_atr_mult": 0.65, "strategy_stop_max_atr_mult": 2.50, "strategy_take_profit_r": 2.00}),
                ("early_entry", {"strategy_entry_atr_offset_mult": 0.06, "strategy_stop_min_atr_mult": 0.50, "strategy_stop_max_atr_mult": 2.50, "strategy_take_profit_r": 2.00}),
                ("clean_entry", {"strategy_entry_atr_offset_mult": 0.08, "strategy_stop_min_atr_mult": 0.50, "strategy_stop_max_atr_mult": 2.50, "strategy_take_profit_r": 2.00}),
                ("compressed_stop_pf", {"strategy_entry_atr_offset_mult": 0.07, "strategy_stop_min_atr_mult": 0.55, "strategy_stop_max_atr_mult": 2.25, "strategy_take_profit_r": 2.10}),
                ("survival_room", {"strategy_entry_atr_offset_mult": 0.07, "strategy_stop_min_atr_mult": 0.60, "strategy_stop_max_atr_mult": 2.75, "strategy_take_profit_r": 1.90}),
                ("clean_pf", {"strategy_entry_atr_offset_mult": 0.08, "strategy_stop_min_atr_mult": 0.65, "strategy_stop_max_atr_mult": 2.50, "strategy_take_profit_r": 2.10}),
                ("shorter_expiry", {"strategy_entry_atr_offset_mult": 0.07, "strategy_stop_min_atr_mult": 0.50, "strategy_stop_max_atr_mult": 2.50, "strategy_pending_expiry_minutes": 180}),
            ],
        ),
        Candidate(
            10692,
            "QM5_10692_tv-ls-ms",
            "NDX.DWX",
            "H1",
            eas / "QM5_10692_tv-ls-ms" / "sets" / "QM5_10692_tv-ls-ms_NDX.DWX_H1_backtest.set",
            100,
            [
                ("q06_anchor", {"strategy_pivot_lookback": 5, "strategy_structure_lookback": 6, "strategy_max_bars_after_sweep": 24, "strategy_atr_period": 13, "strategy_atr_median_bars": 85, "strategy_min_atr_median_ratio": 0.511717, "strategy_atr_stop_mult": 1.151181, "strategy_atr_stop_cap_mult": 3.311932, "strategy_reward_r": 1.799675, "strategy_max_hold_bars": 25, "strategy_session_start_hour": 6, "strategy_session_end_hour": 17}),
                ("reward_190", {"strategy_reward_r": 1.90}),
                ("reward_200", {"strategy_reward_r": 2.00}),
                ("tight_stop", {"strategy_atr_stop_mult": 1.05}),
                ("wide_stop", {"strategy_atr_stop_mult": 1.25}),
                ("structure_5", {"strategy_structure_lookback": 5}),
                ("fresh_sweep", {"strategy_max_bars_after_sweep": 20}),
                ("smoother_atr", {"strategy_atr_period": 14, "strategy_atr_median_bars": 90}),
                ("session_plus1h", {"strategy_session_end_hour": 18}),
                ("grid_plateau", {"strategy_pivot_lookback": 5, "strategy_structure_lookback": 5, "strategy_max_bars_after_sweep": 20, "strategy_atr_period": 18, "strategy_reward_r": 2.00}),
            ],
        ),
        Candidate(
            10715,
            "QM5_10715_tv-asian-box",
            "USDJPY.DWX",
            "M15",
            eas / "QM5_10715_tv-asian-box" / "sets" / "QM5_10715_tv-asian-box_USDJPY.DWX_M15_backtest.set",
            200,
            [
                ("baseline_defaults", {"strategy_timeframe": "PERIOD_M15", "strategy_source_utc_offset_hours": 7, "strategy_asian_start_hhmm": 0, "strategy_asian_end_hhmm": 600, "strategy_eod_close_hhmm": 2355, "strategy_atr_period": 14, "strategy_fx_metal_sl_atr_mult": 0.50, "strategy_index_sl_atr_mult": 0.35, "strategy_min_range_atr_mult": 0.20, "strategy_max_range_atr_mult": 1.50, "strategy_max_spread_stop_frac": 0.12, "strategy_entry_buffer_points": 2.0, "strategy_use_atr_tp": "false"}),
                ("fx_sl_045", {"strategy_fx_metal_sl_atr_mult": 0.45}),
                ("fx_sl_055", {"strategy_fx_metal_sl_atr_mult": 0.55}),
                ("range_025_140", {"strategy_min_range_atr_mult": 0.25, "strategy_max_range_atr_mult": 1.40}),
                ("range_015_130", {"strategy_min_range_atr_mult": 0.15, "strategy_max_range_atr_mult": 1.30}),
                ("buffer_1", {"strategy_entry_buffer_points": 1.0}),
                ("buffer_3", {"strategy_entry_buffer_points": 3.0}),
                ("spread_frac_010", {"strategy_max_spread_stop_frac": 0.10}),
                ("atr20", {"strategy_atr_period": 20, "strategy_fx_metal_sl_atr_mult": 0.50}),
            ],
        ),
        Candidate(
            10939,
            "QM5_10939_grimes-context-pb",
            "GBPUSD.DWX",
            "H4",
            eas / "QM5_10939_grimes-context-pb" / "sets" / "QM5_10939_grimes-context-pb_GBPUSD.DWX_H4_backtest.set",
            20,
            [
                ("baseline_defaults", {"strategy_atr_period": 20, "strategy_d1_fast_ema": 20, "strategy_d1_slow_ema": 50, "strategy_d1_adx_period": 14, "strategy_d1_adx_min": 16.0, "strategy_surprise_lookback": 12, "strategy_breakout_lookback": 30, "strategy_surprise_atr_mult": 2.50, "strategy_climax_bar_atr_mult": 3.00, "strategy_pullback_min_bars": 3, "strategy_pullback_max_bars": 10, "strategy_pullback_min_pct": 0.25, "strategy_pullback_max_pct": 0.55, "strategy_trigger_lookback": 3, "strategy_pullback_bar_atr_mult": 1.50, "strategy_stop_atr_buffer": 0.25, "strategy_max_stop_atr_mult": 2.25, "strategy_target_r_mult": 2.0, "strategy_breakeven_r_mult": 1.0, "strategy_time_exit_h4_bars": 18, "strategy_spread_stop_max_pct": 0.08}),
                ("adx_18", {"strategy_d1_adx_min": 18.0}),
                ("adx_14", {"strategy_d1_adx_min": 14.0}),
                ("surprise_225_climax_325", {"strategy_surprise_atr_mult": 2.25, "strategy_climax_bar_atr_mult": 3.25}),
                ("surprise_275_climax_325", {"strategy_surprise_atr_mult": 2.75, "strategy_climax_bar_atr_mult": 3.25}),
                ("pullback_20_50", {"strategy_pullback_min_pct": 0.20, "strategy_pullback_max_pct": 0.50}),
                ("pullback_30_60", {"strategy_pullback_min_pct": 0.30, "strategy_pullback_max_pct": 0.60}),
                ("target_175_be_09", {"strategy_target_r_mult": 1.75, "strategy_breakeven_r_mult": 0.90}),
                ("wider_stop", {"strategy_stop_atr_buffer": 0.35, "strategy_max_stop_atr_mult": 2.50}),
            ],
        ),
        Candidate(
            10940,
            "QM5_10940_grimes-nested-pb",
            "XAUUSD.DWX",
            "H4",
            eas / "QM5_10940_grimes-nested-pb" / "sets" / "QM5_10940_grimes-nested-pb_XAUUSD.DWX_H4_backtest.set",
            20,
            [
                ("baseline_defaults", {"strategy_d1_fast_ema": 20, "strategy_d1_slow_ema": 50, "strategy_d1_pullback_bars": 12, "strategy_d1_impulse_bars": 24, "strategy_pullback_min_fraction": 0.25, "strategy_pullback_max_fraction": 0.55, "strategy_h4_atr_period": 20, "strategy_h4_pause_min_bars": 3, "strategy_h4_pause_max_bars": 8, "strategy_pause_range_atr_mult": 1.25, "strategy_stop_atr_mult": 0.35, "strategy_max_stop_atr_mult": 2.50, "strategy_target_r": 2.0, "strategy_breakeven_trigger_r": 1.0, "strategy_time_exit_bars": 20, "strategy_d1_atr_percentile_lookback": 120, "strategy_d1_atr_min_percentile": 20.0, "strategy_spread_stop_max_fraction": 0.08}),
                ("atr_pct_30", {"strategy_d1_atr_min_percentile": 30.0}),
                ("atr_pct_10", {"strategy_d1_atr_min_percentile": 10.0}),
                ("pause_range_100", {"strategy_pause_range_atr_mult": 1.00}),
                ("pause_range_150", {"strategy_pause_range_atr_mult": 1.50}),
                ("pullback_20_50", {"strategy_pullback_min_fraction": 0.20, "strategy_pullback_max_fraction": 0.50}),
                ("pullback_30_60", {"strategy_pullback_min_fraction": 0.30, "strategy_pullback_max_fraction": 0.60}),
                ("wider_stop", {"strategy_stop_atr_mult": 0.50, "strategy_max_stop_atr_mult": 3.00}),
                ("target_175_be_09", {"strategy_target_r": 1.75, "strategy_breakeven_trigger_r": 0.90}),
                ("target_225_exit_24", {"strategy_target_r": 2.25, "strategy_time_exit_bars": 24}),
            ],
        ),
        Candidate(
            12567,
            "QM5_12567_cum-rsi2-commodity",
            "XNGUSD.DWX",
            "D1",
            eas / "QM5_12567_cum-rsi2-commodity" / "sets" / "QM5_12567_cum-rsi2-commodity_XNGUSD.DWX_D1_backtest.set",
            10,
            [
                ("baseline_defaults", {"strategy_rsi_period": 2, "strategy_cum_window": 2, "strategy_cum_rsi_entry": 35.0, "strategy_rsi_exit": 65.0, "strategy_sma_period": 200, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.5, "strategy_max_hold_bars": 5, "strategy_max_spread_points": 300}),
                ("entry_30", {"strategy_cum_rsi_entry": 30.0}),
                ("entry_40", {"strategy_cum_rsi_entry": 40.0}),
                ("entry45_sma150", {"strategy_rsi_period": 2, "strategy_cum_window": 2, "strategy_cum_rsi_entry": 45.0, "strategy_rsi_exit": 65.0, "strategy_sma_period": 150, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.5, "strategy_max_hold_bars": 5, "strategy_max_spread_points": 300}),
                ("exit_60", {"strategy_rsi_exit": 60.0}),
                ("exit_70", {"strategy_rsi_exit": 70.0}),
                ("sl_20", {"strategy_atr_sl_mult": 2.0}),
                ("sl_30", {"strategy_atr_sl_mult": 3.0}),
                ("hold_4", {"strategy_max_hold_bars": 4}),
                ("hold_7", {"strategy_max_hold_bars": 7}),
                ("atr10_sl225", {"strategy_atr_period": 10, "strategy_atr_sl_mult": 2.25}),
                ("atr20_sl275", {"strategy_atr_period": 20, "strategy_atr_sl_mult": 2.75}),
            ],
        ),
        Candidate(
            11132,
            "QM5_11132_tm-cum-rsi2",
            "SP500.DWX",
            "D1",
            eas / "QM5_11132_tm-cum-rsi2" / "sets" / "QM5_11132_tm-cum-rsi2_SP500.DWX_D1_backtest.set",
            10,
            [
                ("baseline_defaults", {"strategy_rsi_period": 2, "strategy_cum_window": 2, "strategy_cum_rsi_entry": 35.0, "strategy_rsi_exit": 65.0, "strategy_sma_period": 200, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.5, "strategy_max_hold_bars": 5, "strategy_max_spread_points": 300}),
                ("anchor_a", {"strategy_cum_rsi_entry": 39.230433, "strategy_rsi_exit": 66.126371, "strategy_sma_period": 165, "strategy_atr_period": 12, "strategy_atr_sl_mult": 1.924779, "strategy_max_hold_bars": 5, "strategy_max_spread_points": 227}),
                ("anchor_b", {"strategy_cum_rsi_entry": 39.253136, "strategy_rsi_exit": 65.574493, "strategy_sma_period": 155, "strategy_atr_period": 16, "strategy_atr_sl_mult": 2.724197, "strategy_max_hold_bars": 5, "strategy_max_spread_points": 289}),
                ("mid_blend", {"strategy_cum_rsi_entry": 39.0, "strategy_rsi_exit": 66.0, "strategy_sma_period": 160, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.25}),
                ("strict_entry", {"strategy_cum_rsi_entry": 38.0, "strategy_rsi_exit": 66.0, "strategy_sma_period": 165, "strategy_atr_period": 12, "strategy_atr_sl_mult": 2.00}),
                ("more_trades", {"strategy_cum_rsi_entry": 40.0, "strategy_rsi_exit": 66.0, "strategy_sma_period": 155, "strategy_atr_period": 16, "strategy_atr_sl_mult": 2.50}),
                ("let_winners_run", {"strategy_cum_rsi_entry": 39.0, "strategy_rsi_exit": 70.0, "strategy_sma_period": 160, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.25}),
                ("fast_exit", {"strategy_cum_rsi_entry": 39.0, "strategy_rsi_exit": 62.0, "strategy_sma_period": 160, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.25}),
                ("conservative_trend", {"strategy_cum_rsi_entry": 39.0, "strategy_rsi_exit": 66.0, "strategy_sma_period": 180, "strategy_atr_period": 14, "strategy_atr_sl_mult": 2.25}),
            ],
        ),
        Candidate(
            10513,
            "QM5_10513_mql5-ichimoku",
            "XAUUSD.DWX",
            "D1",
            eas / "QM5_10513_mql5-ichimoku" / "sets" / "QM5_10513_mql5-ichimoku_XAUUSD.DWX_D1_backtest_grid_006.set",
            10,
            [
                ("q06_6_18_68_18", {"strategy_tenkan_period": 6, "strategy_kijun_period": 18, "strategy_senkou_b_period": 68, "strategy_atr_period": 18}),
                ("q06_9_18_52_18", {"strategy_tenkan_period": 9, "strategy_kijun_period": 18, "strategy_senkou_b_period": 52, "strategy_atr_period": 18}),
                ("q06_9_18_68_18", {"strategy_tenkan_period": 9, "strategy_kijun_period": 18, "strategy_senkou_b_period": 68, "strategy_atr_period": 18}),
                ("q06_9_26_52_18", {"strategy_tenkan_period": 9, "strategy_kijun_period": 26, "strategy_senkou_b_period": 52, "strategy_atr_period": 18}),
                ("interp_7_18_60_18", {"strategy_tenkan_period": 7, "strategy_kijun_period": 18, "strategy_senkou_b_period": 60, "strategy_atr_period": 18}),
                ("interp_8_20_60_18", {"strategy_tenkan_period": 8, "strategy_kijun_period": 20, "strategy_senkou_b_period": 60, "strategy_atr_period": 18}),
                ("tight_exit", {"strategy_tenkan_period": 9, "strategy_kijun_period": 18, "strategy_senkou_b_period": 52, "strategy_atr_period": 18, "strategy_atr_sl_mult": 1.25, "strategy_tp_rr": 1.30}),
                ("wide_stop", {"strategy_tenkan_period": 9, "strategy_kijun_period": 18, "strategy_senkou_b_period": 52, "strategy_atr_period": 18, "strategy_atr_sl_mult": 1.75, "strategy_tp_rr": 1.50}),
                ("b68_tp18", {"strategy_tenkan_period": 9, "strategy_kijun_period": 18, "strategy_senkou_b_period": 68, "strategy_atr_period": 18, "strategy_tp_rr": 1.80}),
                ("q06_6_18_68_14", {"strategy_tenkan_period": 6, "strategy_kijun_period": 18, "strategy_senkou_b_period": 68, "strategy_atr_period": 14}),
            ],
        ),
    ]


def now_tag() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def variant_overrides(candidate: Candidate, max_variants: int) -> list[tuple[str, dict[str, Any]]]:
    if candidate.variants and candidate.variants[0][0].startswith("baseline"):
        return candidate.variants[:max_variants]
    return [("baseline", {})] + candidate.variants[: max(0, max_variants - 1)]


def _is_defaultish(setfile: Path, key: str, value: Any) -> bool:
    defaults = parse_setfile(setfile)
    if key not in defaults:
        return False
    current = str(defaults[key]).strip()
    desired = str(value).strip()
    try:
        return abs(float(current) - float(desired)) < 1e-9
    except ValueError:
        return current == desired


def parse_setfile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = raw.strip()
        if not line or line.startswith(";") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def write_variant_setfile(candidate: Candidate, name: str, overrides: dict[str, Any], out_dir: Path) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    text = candidate.baseline_setfile.read_text(encoding="utf-8", errors="ignore").rstrip()
    suffix = re.sub(r"[^A-Za-z0-9_.-]+", "_", name)
    path = out_dir / f"{candidate.ea_dir}_{candidate.symbol}_{candidate.period}_q12opt_{suffix}.set"
    lines = [text, f"; --- q12_opt variant {name} generated {now_tag()} ---"]
    for key, value in overrides.items():
        lines.append(f"{key}={value}")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    return path


def run_smoke(candidate: Candidate, setfile: Path, variant: str, args: argparse.Namespace, report_root: Path) -> dict[str, Any]:
    cmd = [
        "pwsh.exe",
        "-NoProfile",
        "-File",
        str(RUN_SMOKE),
        "-EAId",
        str(candidate.ea_id),
        "-EALabel",
        candidate.ea_dir,
        "-Expert",
        candidate.expert,
        "-Symbol",
        candidate.symbol,
        "-Period",
        candidate.period,
        "-Year",
        str(args.year),
        "-Terminal",
        args.terminal,
        "-Runs",
        "1",
        "-MinTrades",
        str(candidate.min_trades),
        "-Model",
        "4",
        "-TimeoutSeconds",
        str(args.timeout_seconds),
        "-SetFile",
        str(setfile),
        "-ReportRoot",
        str(report_root),
        "-DispatchPhase",
        "Q12_OPT",
        "-DispatchVersion",
        variant,
    ]
    if args.from_date:
        cmd += ["-FromDate", args.from_date]
    if args.to_date:
        cmd += ["-ToDate", args.to_date]
    started = dt.datetime.now(dt.timezone.utc)
    proc = subprocess.run(cmd, cwd=REPO_ROOT, text=True, capture_output=True, timeout=args.timeout_seconds + 120)
    ended = dt.datetime.now(dt.timezone.utc)
    summary_path = None
    for line in (proc.stdout or "").splitlines():
        if line.startswith("run_smoke.summary="):
            summary_path = line.split("=", 1)[1].strip()
    result = {
        "ea": candidate.label,
        "ea_dir": candidate.ea_dir,
        "symbol": candidate.symbol,
        "period": candidate.period,
        "variant": variant,
        "setfile": str(setfile),
        "returncode": proc.returncode,
        "started_utc": started.isoformat(),
        "ended_utc": ended.isoformat(),
        "summary_path": summary_path,
        "stdout_tail": "\n".join((proc.stdout or "").splitlines()[-20:]),
        "stderr_tail": "\n".join((proc.stderr or "").splitlines()[-20:]),
    }
    if summary_path and Path(summary_path).exists():
        summary = json.loads(Path(summary_path).read_text(encoding="utf-8-sig", errors="ignore"))
        copy_graph_assets(summary)
        result.update(extract_metrics(summary))
    return result


def copy_graph_assets(summary: dict[str, Any]) -> None:
    for run in summary.get("runs") or []:
        src_report = run.get("report_source_path")
        dst_report = run.get("report_canonical_path")
        if not src_report or not dst_report:
            continue
        src = Path(src_report)
        dst = Path(dst_report)
        if not src.exists() or not dst.parent.exists():
            continue
        stem = src.with_suffix("").name
        for png in src.parent.glob(f"{stem}*.png"):
            target = dst.parent / png.name
            if not target.exists():
                shutil.copy2(png, target)


def extract_metrics(summary: dict[str, Any]) -> dict[str, Any]:
    runs = summary.get("runs") or []
    best = None
    for run in runs:
        if best is None or float(run.get("net_profit") or -1e18) > float(best.get("net_profit") or -1e18):
            best = run
    out = {
        "result": summary.get("result"),
        "reason_classes": ";".join(summary.get("reason_classes") or []),
        "run_tag": summary.get("run_tag"),
        "report_dir": summary.get("report_dir"),
        "year": summary.get("year"),
        "terminal": summary.get("terminal"),
    }
    if best:
        out.update(
            {
                "net_profit": best.get("net_profit"),
                "profit_factor": best.get("profit_factor"),
                "total_trades": best.get("total_trades"),
                "drawdown": best.get("drawdown"),
                "drawdown_raw": best.get("drawdown_raw"),
                "report": best.get("report_canonical_path") or best.get("report_source_path"),
            }
        )
    return out


def write_outputs(rows: list[dict[str, Any]], out_dir: Path) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "results.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
    keys = [
        "ea",
        "symbol",
        "period",
        "variant",
        "result",
        "net_profit",
        "profit_factor",
        "total_trades",
        "drawdown",
        "drawdown_raw",
        "summary_path",
        "report",
        "setfile",
        "returncode",
        "reason_classes",
    ]
    with (out_dir / "results.csv").open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=keys, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--terminal", default="T10")
    parser.add_argument("--year", type=int, default=2024)
    parser.add_argument("--from-date", default="")
    parser.add_argument("--to-date", default="")
    parser.add_argument("--max-variants-per-ea", type=int, default=3)
    parser.add_argument("--ea", action="append", help="Run only selected EA label, e.g. QM5_10440")
    parser.add_argument("--timeout-seconds", type=int, default=3600)
    parser.add_argument("--work-root", type=Path, default=DEFAULT_WORK_ROOT)
    parser.add_argument("--report-root", type=Path, default=DEFAULT_REPORT_ROOT)
    args = parser.parse_args()

    run_id = now_tag()
    work_dir = args.work_root / run_id
    report_root = args.report_root / run_id
    selected = set(args.ea or [])
    rows: list[dict[str, Any]] = []
    for candidate in candidates():
        if selected and candidate.label not in selected and candidate.ea_dir not in selected:
            continue
        if not candidate.baseline_setfile.exists():
            rows.append({"ea": candidate.label, "symbol": candidate.symbol, "variant": "missing_baseline", "setfile": str(candidate.baseline_setfile), "returncode": -1})
            continue
        set_dir = work_dir / "sets" / candidate.ea_dir
        for variant, overrides in variant_overrides(candidate, args.max_variants_per_ea):
            setfile = write_variant_setfile(candidate, variant, overrides, set_dir)
            print(f"[q12-opt] run {candidate.label} {candidate.symbol} {variant} {overrides}", flush=True)
            row = run_smoke(candidate, setfile, variant, args, report_root)
            row["overrides_json"] = json.dumps(overrides, sort_keys=True)
            rows.append(row)
            write_outputs(rows, work_dir)
    write_outputs(rows, work_dir)
    print(f"[q12-opt] results_json={work_dir / 'results.json'}")
    print(f"[q12-opt] results_csv={work_dir / 'results.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
