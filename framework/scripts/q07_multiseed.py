"""Q07 — Multi-Seed runner.

Per Vault Q07 spec:
  Seeds:    42, 17, 99, 7, 2026  (canonical list, framework/registry/multiseed_seeds.json)
  Window:   full available history
  Stress:   Q06 HARSH settings applied (highest realistic stress)
  Verdict:  PF variance across seeds < 20% AND no seed PF < 1.0

Runs the same setfile 5 times — once per seed — with qm_rng_seed input
overridden to each canonical seed. Per-seed PF/DD/Trades captured.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from framework.scripts._phase_utils import ensure_dir, utc_now_iso, write_json
from framework.scripts.q05_stress_medium import _parse_pf_dd_trades, STARTING_EQUITY
from framework.scripts.q06_stress_harsh import gen_harsh_setfile_for

GATE_NAME = "Q07"
PF_VARIANCE_PCT_MAX = 20.0
PER_SEED_PF_MIN = 1.0


def _load_canonical_seeds() -> list[int]:
    """Load from framework/registry/multiseed_seeds.json — fail loud if absent."""
    repo_root = Path(__file__).resolve().parents[2]
    path = repo_root / "framework" / "registry" / "multiseed_seeds.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    seeds = data.get("seeds")
    if not isinstance(seeds, list) or len(seeds) != 5:
        raise ValueError(f"bad seed registry shape at {path}")
    return [int(s) for s in seeds]


def _write_seeded_setfile(baseline: Path, seed: int) -> Path:
    """Write a copy of `baseline` with qm_rng_seed=<seed> overridden."""
    text = baseline.read_text(encoding="utf-8", errors="replace")
    if "qm_rng_seed=" in text:
        new = re.sub(r"qm_rng_seed=\d+", f"qm_rng_seed={seed}", text)
    else:
        # Inject after qm_magic_slot_offset= line if present, else after PORTFOLIO_WEIGHT
        anchor = "qm_magic_slot_offset="
        if anchor in text:
            new = text.replace(anchor + "0", f"qm_magic_slot_offset=0\nqm_rng_seed={seed}", 1)
        else:
            new = text.rstrip() + f"\nqm_rng_seed={seed}\n"
    out_path = baseline.with_name(f"{baseline.stem}_seed{seed}.set")
    out_path.write_text(new, encoding="utf-8")
    return out_path


def _run_seed(*, ea_id: int, ea_expert: str, symbol: str, setfile: Path,
              seed: int, terminal: str, report_root: Path,
              timeout_sec: int) -> dict:
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
        "-DispatchSubGateHash", f"q07_seed{seed}_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q07",
        "-DispatchVersion", f"q07_seed_{seed}",
        "-Runs", "1",
        "-MinTrades", "20",
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    proc = subprocess.run(args, capture_output=True, text=True,
                          timeout=timeout_sec, creationflags=creationflags)
    sym_clean = symbol.replace(".", "_")
    summary = report_root / f"QM5_{ea_id}" / "Q07" / sym_clean / f"seed_{seed}" / "summary.json"
    pf, dd_money, trades = _parse_pf_dd_trades(summary)
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None
    return {"seed": seed, "pf": pf, "dd_money": dd_money, "dd_pct": dd_pct,
            "trades": trades, "exit_code": proc.returncode,
            "summary_path": str(summary) if summary.exists() else None}


def evaluate_seeds(seed_results: list[dict]) -> tuple[str, str, dict]:
    """Combined Q07 verdict from per-seed results."""
    pfs = [r["pf"] for r in seed_results if r.get("pf") is not None and r["pf"] > 0]
    if len(pfs) < len(seed_results):
        missing = [r["seed"] for r in seed_results if r.get("pf") is None or r["pf"] <= 0]
        return ("INVALID",
                f"seeds_with_invalid_pf:{missing}",
                {"per_seed_pf": [(r["seed"], r["pf"]) for r in seed_results]})

    mean_pf = sum(pfs) / len(pfs)
    if mean_pf <= 0:
        return "FAIL", "mean_pf_non_positive", {}
    spread = max(pfs) - min(pfs)
    variance_pct = (spread / mean_pf) * 100.0
    floor_breach = [r["seed"] for r in seed_results if r["pf"] < PER_SEED_PF_MIN]

    metrics = {
        "per_seed_pf": [(r["seed"], round(r["pf"], 4)) for r in seed_results],
        "mean_pf": round(mean_pf, 4),
        "spread": round(spread, 4),
        "variance_pct": round(variance_pct, 2),
        "min_pf": round(min(pfs), 4),
        "max_pf": round(max(pfs), 4),
    }

    if floor_breach:
        return ("FAIL",
                f"per_seed_pf_below_floor:seeds={floor_breach}:floor={PER_SEED_PF_MIN}",
                metrics)
    if variance_pct >= PF_VARIANCE_PCT_MAX:
        return ("FAIL",
                f"pf_variance_pct={variance_pct:.2f}>={PF_VARIANCE_PCT_MAX}",
                metrics)
    return ("PASS",
            f"variance_pct={variance_pct:.2f}<{PF_VARIANCE_PCT_MAX}:min_pf={min(pfs):.3f}",
            metrics)


def main() -> int:
    ap = argparse.ArgumentParser(description="Q07 Multi-Seed runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile (Q06 HARSH stress will be applied per Q07 spec)")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=2400)
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    # Q07 runs against Q06 HARSH stress per spec — apply HARSH first, then per-seed.
    harsh_set = gen_harsh_setfile_for(args.baseline_setfile)
    seeds = _load_canonical_seeds()
    print(f"Q07 {args.ea} {args.symbol}  seeds={seeds}  on top of HARSH stress")

    seed_results: list[dict] = []
    for seed in seeds:
        seeded_set = _write_seeded_setfile(harsh_set, seed)
        print(f"  seed {seed}: running...")
        res = _run_seed(ea_id=ea_id, ea_expert=args.ea, symbol=args.symbol,
                        setfile=seeded_set, seed=seed,
                        terminal=args.terminal, report_root=args.report_root,
                        timeout_sec=args.timeout_sec)
        print(f"    -> PF={res['pf']}  trades={res['trades']}  exit={res['exit_code']}")
        seed_results.append(res)

    verdict, reason, metrics = evaluate_seeds(seed_results)
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q07" / args.symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": args.symbol,
        "seeds": seeds,
        "verdict": verdict,
        "reason": reason,
        "metrics": metrics,
        "per_seed_detail": seed_results,
        "generated_at_utc": utc_now_iso(),
    })
    print(f"Q07 {args.ea} {args.symbol}: {verdict}")
    print(f"  reason: {reason}")
    return 0 if verdict == "PASS" else (1 if verdict == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
