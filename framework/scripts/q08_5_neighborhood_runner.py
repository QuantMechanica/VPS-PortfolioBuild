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
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json
from framework.scripts.q05_stress_medium import _parse_pf_dd_trades

GATE_NAME = "Q08.5_neighborhood"
PERTURBATION_PCT = 10.0


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
                params[key] = int(value)
            else:
                params[key] = float(value)
        except ValueError:
            continue
    if not params:
        raise ValueError(f"no numeric params found in baseline setfile: {setfile_path}")
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
    if "_" in ea_label.replace(f"QM5_{ea_id}", "", 1).strip("_"):
        return ea_label
    ea_dirs = sorted(
        d for d in (repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*")
        if d.is_dir()
    )
    return ea_dirs[0].name if ea_dirs else ea_label


def fire_backtest(*, ea_id: int, ea_expert: str, symbol: str,
                   setfile: Path, terminal: str, run_tag: str,
                   report_root: Path, timeout_sec: int = 900) -> tuple[float | None, float | None, int]:
    """One full-history backtest for a perturbation; returns (pf, dd_money, trades)."""
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", "0",
        "-Terminal", terminal,
        "-Period", "H1",
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
    try:
        subprocess.run(args, capture_output=True, text=True,
                       timeout=timeout_sec, creationflags=creationflags)
    except subprocess.TimeoutExpired:
        return None, None, 0
    sym_clean = symbol.replace(".", "_")
    summary = (report_root / f"QM5_{ea_id}" / "Q08" / "neighborhood"
               / sym_clean / run_tag / "summary.json")
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

    # Baseline (nominal) backtest
    print(f"Q08.5 {args.ea} {args.symbol}: baseline (no perturbation)...")
    bl_pf, bl_dd, bl_trades = fire_backtest(
        ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
        setfile=args.baseline_setfile, terminal=args.terminal,
        run_tag="baseline", report_root=args.report_root,
        timeout_sec=args.timeout_sec,
    )
    print(f"  baseline -> PF={bl_pf}  DD={bl_dd}  trades={bl_trades}")

    # Pick the first N numeric params (deterministic by sorted name)
    numeric_params = [(k, v) for k, v in sorted(params.items())
                      if isinstance(v, (int, float)) and not isinstance(v, bool)]
    if not numeric_params:
        print("no numeric params in plateau_pick.params", file=sys.stderr)
        return 2
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
                ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
                setfile=setfile, terminal=args.terminal, run_tag=run_tag,
                report_root=args.report_root, timeout_sec=args.timeout_sec,
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
