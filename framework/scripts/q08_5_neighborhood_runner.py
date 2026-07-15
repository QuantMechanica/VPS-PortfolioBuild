"""Q08.5 — Neighborhood Stability runner.

Produces the `perturbations.json` consumed by `q08_davey/sub_8_5_neighborhood.py`.

For each numeric parameter chosen at Q03 plateau-median, fires three
backtests at the param's nominal value AND at ±10% perturbations,
keeping all other parameters at their plateau-median. Captures PF and
DD per perturbation; the sub-gate then checks:

  - every perturbation must have PF > 1.0
  - every perturbation's DD must be < 1.5 × baseline DD

Output:
    D:/QM/reports/pipeline/QM5_<id>/Q08/neighborhood/<symbol>/perturbations.json
    {
      "baseline":     {"pf": 1.42, "dd": 8500, "trades": 220, "params": {...}},
      "perturbations":[
        {"param": "fast_ema",  "delta": "-10pct", "value": 18, "pf": 1.35, "dd": 9100, "trades": 215},
        {"param": "fast_ema",  "delta": "+10pct", "value": 22, "pf": 1.38, "dd": 8800, "trades": 218},
        ...
      ],
      "generated_at_utc": "...",
      "ea_id": 1056, "symbol": "NDX.DWX"
    }

Reads the Q03 plateau pick from:
    D:/QM/reports/pipeline/QM5_<id>/Q03/<symbol>/plateau_pick.json
(written by the future Q03 sweep runner update; for now this is the
contract that runner must produce.)
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import period_from_setfile
from framework.scripts.q05_stress_medium import (
    _parse_pf_dd_trades,
    _select_run_summary,
    _text_from_completed_process,
    summary_invalid_reason,
)

# Wrapper must outlive the tester budget, or a run finishing at the buzzer
# loses its summary write (2026-07-06 audit G16; mirrors q05/q06).
RUNNER_HEADROOM_SEC = 120

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json

GATE_NAME = "Q08.5_neighborhood"
PERTURBATION_PCT = 10.0
NON_STRATEGY_PREFIXES = ("qm_", "RISK_")
NON_PERTURBABLE_NAME_TOKENS = (
    "enabled",
    "mode",
    "use_",
    "no_",
    "direction",
    "time",
    "hour",
    "minute",
    "hhmm",
    # Calendar-denominated windows are STRUCTURAL anchors, not tuning knobs
    # (5 sessions = one week of highs/lows; a 4-session week has no market
    # meaning; the EA can never run N=4 live since it always collects N complete
    # sessions). Bar-/period-denominated windows stay perturbable. OWNER-ratified:
    # decisions/2026-07-15_q08_neighborhood_calendar_params.md ("day" deliberately
    # omitted — collides with tunable daily_loss-style money caps).
    "session",
    "week",
    "month",
)


def is_perturbable_param(key: str, value: int | float) -> bool:
    lowered = key.lower()
    if key == "PORTFOLIO_WEIGHT" or key.startswith(NON_STRATEGY_PREFIXES):
        return False
    if any(token in lowered for token in NON_PERTURBABLE_NAME_TOKENS):
        return False
    if float(value) == 0.0:
        return False
    return True


def load_plateau_pick(plateau_path: Path) -> dict:
    """Load Q03's plateau-median parameter pick.

    Expected schema (contract with the Q03 runner):
      {"params": {"fast_ema": 20, "slow_ema": 50, "atr_mult": 2.0},
       "baseline_pf": 1.42, "baseline_dd": 8500, ...}
    """
    if not plateau_path.exists():
        raise FileNotFoundError(f"Q03 plateau pick missing: {plateau_path}")
    data = json.loads(plateau_path.read_text(encoding="utf-8"))
    if "params" not in data:
        raise ValueError(f"plateau_pick.json missing 'params' key: {plateau_path}")
    return data


def load_params_from_setfile(setfile_path: Path) -> dict:
    """Fallback when Q03 did not publish plateau_pick.json yet."""
    if not setfile_path.exists():
        raise FileNotFoundError(f"baseline setfile missing: {setfile_path}")
    params: dict[str, int | float] = {}
    in_strategy_block = False
    for raw in setfile_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if line.lower().startswith("; strategy-specific params"):
            in_strategy_block = True
            continue
        if not line or line.startswith(";") or "=" not in line or not in_strategy_block:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key or value.lower() in {"true", "false"}:
            continue
        try:
            if re.fullmatch(r"[-+]?\d+", value):
                parsed = int(value)
            else:
                parsed = float(value)
        except ValueError:
            continue
        if not is_perturbable_param(key, parsed):
            continue
        params[key] = parsed
    if not params:
        return {"params": params, "source": str(setfile_path), "source_type": "baseline_setfile_no_strategy_params"}
    return {"params": params, "source": str(setfile_path), "source_type": "baseline_setfile"}


def numeric_perturbation(value, pct: float):
    """Return (down, up) tuples for ±pct of a numeric value.

    Integer params perturb by max(1, round(value * pct/100)) to avoid
    sub-integer perturbations that round-trip back to the original.
    Float params perturb by value * pct/100.
    """
    if isinstance(value, bool):
        return None  # booleans aren't perturbable
    if isinstance(value, int):
        step = max(1, round(abs(value) * pct / 100.0))
        return value - step, value + step
    if isinstance(value, float):
        step = abs(value) * pct / 100.0
        if step == 0:
            return None
        return round(value - step, 6), round(value + step, 6)
    return None


def write_perturbation_setfile(baseline_set: Path, param: str, value, out_dir: Path) -> Path:
    """Write a setfile with one parameter overridden."""
    text = baseline_set.read_text(encoding="utf-8", errors="replace")
    # The skeleton's strategy params live under "input group "Strategy"".
    # We patch `<param>=<value>` if present, otherwise append.
    pattern = re.compile(rf"^({re.escape(param)})\s*=.*$", re.MULTILINE)
    if pattern.search(text):
        new_text = pattern.sub(f"{param}={value}", text)
    else:
        new_text = text.rstrip() + f"\n{param}={value}\n"
    out_path = out_dir / f"{baseline_set.stem}_perturb_{param}_{value}.set"
    out_path.write_text(new_text, encoding="utf-8")
    return out_path


def resolve_ea_expert(ea_label: str, ea_id: int) -> str:
    repo_root = Path(__file__).resolve().parents[2]
    if ea_label.startswith("QM\\"):
        return ea_label
    if "_" in ea_label.replace(f"QM5_{ea_id}", "", 1).strip("_"):
        return f"QM\\{ea_label}"
    ea_dirs = sorted(
        d for d in (repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*")
        if d.is_dir()
    )
    return f"QM\\{ea_dirs[0].name}" if ea_dirs else f"QM\\{ea_label}"


def fire_backtest(*, ea_id: int, ea_expert: str, symbol: str,
                   setfile: Path, terminal: str, run_tag: str,
                   report_root: Path, timeout_sec: int = 900,
                   period: str = "H1",
                   from_date: str = "2017.01.01") -> tuple[float | None, float | None, int]:
    """One full-history backtest for a perturbation; returns (pf, dd_money, trades)."""
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        # Full-history window — matches the canonical Q08 baseline (q08_davey/aggregate.py).
        # Was "-Year 0" with no date range, which made run_smoke build fromDate="0.01.01"
        # (an invalid year-0 window) -> 0 trades on EVERY perturbation INCLUDING the baseline
        # -> 8.5 FAILed every EA falsely (167/167 runs had a 0-trade baseline). 2026-06-26 fix.
        "-Year", "2025",
        "-FromDate", from_date,
        "-ToDate", "2025.12.31",
        "-Terminal", terminal,
        # 2026-07-06 audit G6: was hardcoded "H1" — non-H1 EAs got their entire
        # plateau evidence generated on the wrong chart timeframe (the exact
        # class period_from_setfile was created for).
        "-Period", period,
        "-DispatchSubGateHash", run_tag,
        "-DispatchPhase", "Q08.5",
        "-DispatchVersion", "q08_neighborhood",
        "-Runs", "1",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    started_at = time.time()
    output_text = ""
    try:
        proc = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout_sec + RUNNER_HEADROOM_SEC,
            creationflags=creationflags,
        )
        output_text = _text_from_completed_process(proc)
    except subprocess.TimeoutExpired as exc:
        output_text = _text_from_completed_process(exc)
    summary = _select_run_summary(
        output_text,
        report_root,
        started_at=started_at,
        ea_id=ea_id,
        ea_expert=ea_expert,
        symbol=symbol,
        period=period,
        terminal=terminal,
    )
    if summary is None:
        return None, None, 0
    # Review 83be4dd3 M-1: infra-invalid summaries (NO_HISTORY cold cache,
    # BARS_ZERO, REPORT_FORMAT_DRIFT) carry DEFAULTED pf=0.0 in their run rows
    # — parsing them graded infra failures as plateau breaches (the exact G5
    # class, closed for timeouts but not for invalid summaries). Return the
    # infra sentinel so sub_8_5 records an invalid perturbation instead.
    if summary_invalid_reason(summary):
        return None, None, 0
    return _parse_pf_dd_trades(summary)


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08.5 Neighborhood Stability runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile (used as the nominal centre)")
    ap.add_argument("--plateau-pick", type=Path,
                    help="Q03 plateau_pick.json (autodetected from --ea/--symbol if absent)")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=900)
    ap.add_argument("--max-params", type=int, default=8,
                    help="Cap on params perturbed (skip after N to bound compute)")
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))
    ea_expert = resolve_ea_expert(args.ea, ea_id)
    sym_clean = args.symbol.replace(".", "_")

    plateau_path = args.plateau_pick or (
        args.report_root / f"QM5_{ea_id}" / "Q03" / sym_clean / "plateau_pick.json"
    )
    try:
        pick = load_plateau_pick(plateau_path)
        pick_source = str(plateau_path)
        pick_source_type = "plateau_pick"
    except FileNotFoundError:
        pick = load_params_from_setfile(args.baseline_setfile)
        pick_source = str(args.baseline_setfile)
        pick_source_type = "baseline_setfile_fallback"
    params = pick["params"]
    if not isinstance(params, dict):
        print(f"Q08.5 params is not a dict: {pick_source}", file=sys.stderr)
        return 2

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q08" / "neighborhood" / sym_clean)
    setfile_dir = ensure_dir(out_dir / "setfiles")

    period = period_from_setfile(args.baseline_setfile)

    # Basket EAs: the tester must run on the HOST symbol (the logical symbol has
    # no tradable stream — running on it produced 0 trades on baseline AND every
    # perturbation, i.e. the 13117 degenerate_baseline INVALID, 2026-07-15).
    # Evidence stays keyed by the logical symbol (out_dir above) so the Q08
    # aggregate finds it. Mirrors farmctl._load_basket_manifest host resolution.
    tester_symbol = args.symbol
    from_date = "2017.01.01"
    manifest_path = Path(args.baseline_setfile).parent.parent / "basket_manifest.json"
    if manifest_path.exists():
        try:
            _m = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
            if str(_m.get("logical_symbol")) == args.symbol and _m.get("host_symbol"):
                tester_symbol = str(_m["host_symbol"])
                period = str(_m.get("host_timeframe") or period)
                # Basket customs begin ~2018 — a 2017.01.01 start yields a
                # 0-bar HOST chart (report Bars:0, zero trades on baseline AND
                # every perturbation; 13117 diagnosis 2026-07-15). Match the
                # official phase runners' basket window.
                from_date = "2018.07.02"  # farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM
                print(f"Q08.5 basket: logical {args.symbol} -> host {tester_symbol} "
                      f"({period}), from {from_date}")
        except (OSError, json.JSONDecodeError):
            pass

    # Baseline (nominal) backtest
    print(f"Q08.5 {args.ea} {args.symbol}: baseline (no perturbation, period={period})...")
    bl_pf, bl_dd, bl_trades = fire_backtest(
        ea_id=ea_id, ea_expert=ea_expert, symbol=tester_symbol,
        setfile=args.baseline_setfile, terminal=args.terminal,
        run_tag="baseline", report_root=args.report_root,
        timeout_sec=args.timeout_sec, period=period, from_date=from_date,
    )
    print(f"  baseline -> PF={bl_pf}  DD={bl_dd}  trades={bl_trades}")

    # Pick the first N numeric params (deterministic by sorted name)
    numeric_params = [(k, v) for k, v in sorted(params.items())
                      if isinstance(v, (int, float)) and not isinstance(v, bool)]
    if not numeric_params:
        payload = {
            "ea_id": ea_id,
            "symbol": args.symbol,
            "ea_expert": ea_expert,
            "perturbation_pct": PERTURBATION_PCT,
            "baseline": {
                "pf": bl_pf, "dd": bl_dd, "trades": bl_trades,
                "params": params,
            },
            "perturbations": [],
            "n_params_in_pick": 0,
            "n_params_tested": 0,
            "param_source": pick_source,
            "param_source_type": pick_source_type,
            "generated_at_utc": utc_now_iso(),
            "note": "no_numeric_strategy_params_to_perturb",
        }
        write_json(out_dir / "perturbations.json", payload)
        print(f"Q08.5 wrote {out_dir / 'perturbations.json'} (no numeric strategy params)")
        return 0
    chosen = numeric_params[: args.max_params]
    print(f"Q08.5: perturbing {len(chosen)} of {len(numeric_params)} numeric params at ±{PERTURBATION_PCT}%")

    perturbations: list[dict] = []
    for param_name, nominal in chosen:
        bounds = numeric_perturbation(nominal, PERTURBATION_PCT)
        if bounds is None:
            continue
        for label, value in (("-10pct", bounds[0]), ("+10pct", bounds[1])):
            run_tag = f"{param_name}_{label.replace('-', 'neg').replace('+', 'pos')}"
            setfile = write_perturbation_setfile(args.baseline_setfile, param_name, value, setfile_dir)
            print(f"  perturb {param_name}={value} ({label})...")
            pf, dd_money, trades = fire_backtest(
                ea_id=ea_id, ea_expert=ea_expert, symbol=tester_symbol,
                setfile=setfile, terminal=args.terminal, run_tag=run_tag,
                report_root=args.report_root, timeout_sec=args.timeout_sec,
                period=period, from_date=from_date,
            )
            perturbations.append({
                "param": param_name,
                "delta": label,
                "value": value,
                "pf": pf,
                "dd": dd_money,
                "trades": trades,
            })
            print(f"    -> PF={pf}  DD={dd_money}  trades={trades}")

    payload = {
        "ea_id": ea_id,
        "symbol": args.symbol,
        "ea_expert": ea_expert,
        "perturbation_pct": PERTURBATION_PCT,
        "baseline": {
            "pf": bl_pf, "dd": bl_dd, "trades": bl_trades,
            "params": params,
        },
        "perturbations": perturbations,
        "n_params_in_pick": len(numeric_params),
        "n_params_tested": len(chosen),
        "param_source": pick_source,
        "param_source_type": pick_source_type,
        "generated_at_utc": utc_now_iso(),
    }
    write_json(out_dir / "perturbations.json", payload)
    print(f"Q08.5 wrote {out_dir / 'perturbations.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
