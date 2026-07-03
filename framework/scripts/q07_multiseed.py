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
import time
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import (ensure_dir, utc_now_iso, write_json,
                                            resolve_ea_expert_path, period_from_setfile,
                                            full_history_window,
                                            run_with_launch_fault_retry)
from framework.scripts.q05_stress_medium import (
    _latest_report_metrics,
    _parse_pf_dd_trades,
    summary_invalid_reason,
    MIN_TRADES,
    STARTING_EQUITY,
    RUNNER_HEADROOM_SEC,
    _basket_tester_overrides,
)
from framework.scripts.q06_stress_harsh import gen_harsh_setfile_for, _basket_logical_symbol

GATE_NAME = "Q07"
PF_VARIANCE_PCT_MAX = 20.0
PER_SEED_PF_MIN = 1.0


def _text_from_completed_process(proc: subprocess.CompletedProcess | subprocess.TimeoutExpired) -> str:
    parts: list[str] = []
    for raw in (getattr(proc, "stdout", None), getattr(proc, "stderr", None)):
        if raw is None:
            continue
        if isinstance(raw, bytes):
            parts.append(raw.decode("utf-8", errors="replace"))
        else:
            parts.append(str(raw))
    return "\n".join(part for part in parts if part)


def _summary_from_run_smoke_output(output_text: str) -> Path | None:
    match = re.search(r"(?m)^run_smoke\.summary=(?P<path>.+?)\s*$", output_text or "")
    if not match:
        return None
    path = Path(match.group("path").strip().strip('"'))
    return path if path.exists() else None


def _find_latest_summary_after(report_root: Path, started_at: float) -> Path | None:
    root = Path(report_root)
    if not root.is_dir():
        return None
    cands = []
    for summary in root.rglob("summary.json"):
        try:
            mtime = summary.stat().st_mtime
        except OSError:
            continue
        if mtime >= started_at:
            cands.append((mtime, summary))
    if not cands:
        return None
    return max(cands, key=lambda item: item[0])[1]


def _latest_report_metrics_after(report_root: Path, started_at: float) -> dict | None:
    root = Path(report_root)
    if not root.is_dir():
        return None
    reports = []
    for report in root.rglob("report.htm"):
        try:
            mtime = report.stat().st_mtime
        except OSError:
            continue
        if mtime >= started_at:
            reports.append((mtime, report))
    for _mtime, report in sorted(reports, reverse=True):
        metrics = _latest_report_metrics(report.parent)
        if metrics:
            return metrics
    return None


def _seed_from_tester_ini(path: Path) -> int | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    match = re.search(r"_seed(?P<seed>\d+)\.set\b", text, flags=re.IGNORECASE)
    if not match:
        return None
    return int(match.group("seed"))


def _seed_from_summary_path(summary_path: Path) -> int | None:
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        data = {}
    run_paths: list[Path] = []
    for run in data.get("runs") or []:
        for key in ("report_canonical_path", "tester_ini_path"):
            raw = run.get(key)
            if raw:
                run_paths.append(Path(str(raw)))
    for run_path in run_paths:
        ini_path = run_path if run_path.name.lower() == "tester.ini" else run_path.parent / "tester.ini"
        seed = _seed_from_tester_ini(ini_path)
        if seed is not None:
            return seed
    for ini_path in summary_path.parent.rglob("tester.ini"):
        seed = _seed_from_tester_ini(ini_path)
        if seed is not None:
            return seed
    return None


def _result_from_existing_seed_summary(*, summary_path: Path, seed: int,
                                       latest_full_year: int | None,
                                       full_history_from: str | None) -> dict | None:
    invalid_reason = summary_invalid_reason(summary_path)
    if invalid_reason:
        return None
    pf, dd_money, trades = _parse_pf_dd_trades(summary_path)
    if pf is None or int(trades or 0) < MIN_TRADES:
        return None
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None
    return {
        "seed": seed,
        "pf": pf,
        "dd_money": dd_money,
        "dd_pct": dd_pct,
        "trades": trades,
        "exit_code": 0,
        "timed_out": False,
        "timeout_detail": None,
        "timeout_sec": None,
        "runner_timeout_sec": None,
        "summary_path": str(summary_path),
        "report_path": None,
        "metric_source": "summary_json_reused",
        "history_year": None,
        "history_from": None,
        "history_to": None,
        "latest_full_year": latest_full_year,
        "full_history_from_override": full_history_from,
        "invalid_reason": None,
        "reused_existing_summary": True,
    }


def _recover_existing_seed_results(report_root: Path, seeds: list[int],
                                   latest_full_year: int | None,
                                   full_history_from: str | None) -> dict[int, dict]:
    root = Path(report_root)
    search_roots: list[Path] = []
    if root.is_dir():
        search_roots.append(root)
    try:
        search_roots.extend(
            p for p in sorted(root.parent.glob(f"{root.name}.requeued_*"))
            if p.is_dir()
        )
    except OSError:
        pass
    if not search_roots:
        return {}
    wanted = set(seeds)
    recovered: dict[int, dict] = {}
    summaries: list[Path] = []
    for search_root in search_roots:
        summaries.extend(search_root.rglob("summary.json"))
    summaries = sorted(summaries, key=lambda p: p.stat().st_mtime, reverse=True)
    for summary_path in summaries:
        seed = _seed_from_summary_path(summary_path)
        if seed not in wanted or seed in recovered:
            continue
        result = _result_from_existing_seed_summary(
            summary_path=summary_path,
            seed=seed,
            latest_full_year=latest_full_year,
            full_history_from=full_history_from,
        )
        if result is not None:
            recovered[seed] = result
    return recovered


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
              timeout_sec: int, period: str = "H1",
              latest_full_year: int | None = None,
              full_history_from: str | None = None) -> dict:
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    history_year, history_from, history_to = full_history_window(latest_full_year, full_history_from)
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", history_year, "-FromDate", history_from, "-ToDate", history_to,
        "-Terminal", terminal,
        "-Period", period,
        "-DispatchSubGateHash", f"q07_seed{seed}_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q07",
        "-DispatchVersion", f"q07_seed_{seed}",
        "-Runs", "1",
        "-MinTrades", str(MIN_TRADES),
        "-Model", "4",
        "-SetFile", str(setfile),
        "-ReportRoot", str(report_root),
        "-TimeoutSeconds", str(timeout_sec),
    ]
    tester_currency, tester_deposit = _basket_tester_overrides(setfile)
    if tester_currency:
        args.extend(["-TesterCurrencyOverride", tester_currency])
    if tester_deposit:
        args.extend(["-TesterDepositOverride", str(tester_deposit)])
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    runner_timeout_sec = timeout_sec + RUNNER_HEADROOM_SEC
    timed_out = False
    timeout_detail = None
    output_text = ""
    started_at = time.time()
    try:
        proc = run_with_launch_fault_retry(
            args,
            runner=subprocess.run,
            capture_output=True,
            text=True,
            timeout=runner_timeout_sec,
            creationflags=creationflags,
        )
        exit_code = proc.returncode
        output_text = _text_from_completed_process(proc)
    except subprocess.TimeoutExpired as exc:
        timed_out = True
        timeout_detail = f"subprocess_timeout_after={exc.timeout}s"
        exit_code = 124
        output_text = _text_from_completed_process(exc)
    summary = _summary_from_run_smoke_output(output_text) or _find_latest_summary_after(report_root, started_at)
    invalid_reason = summary_invalid_reason(summary) if summary else None
    report_metrics = None if summary else _latest_report_metrics_after(report_root, started_at)
    if summary:
        pf, dd_money, trades = _parse_pf_dd_trades(summary)
    elif report_metrics:
        pf = report_metrics["pf"]
        dd_money = report_metrics["dd_money"]
        trades = report_metrics["trades"]
    else:
        pf, dd_money, trades = None, None, 0
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None
    if timed_out and summary is None and report_metrics is None:
        invalid_reason = f"timeout_expired:timeout_sec={timeout_sec}:runner_timeout_sec={runner_timeout_sec}"
    return {"seed": seed, "pf": pf, "dd_money": dd_money, "dd_pct": dd_pct,
            "trades": trades, "exit_code": exit_code,
            "timed_out": timed_out, "timeout_detail": timeout_detail,
            "timeout_sec": timeout_sec, "runner_timeout_sec": runner_timeout_sec,
            "summary_path": str(summary) if summary else None,
            "report_path": report_metrics.get("report_path") if report_metrics else None,
            "metric_source": "summary_json" if summary else ("report_htm" if report_metrics else None),
            "history_year": history_year,
            "history_from": history_from,
            "history_to": history_to,
            "latest_full_year": latest_full_year,
            "full_history_from_override": full_history_from,
            "invalid_reason": invalid_reason}


def evaluate_seeds(seed_results: list[dict]) -> tuple[str, str, dict]:
    """Combined Q07 verdict from per-seed results."""
    invalid_seeds = [
        (r["seed"], r.get("invalid_reason") or f"exit_code={r.get('exit_code')}")
        for r in seed_results
        if r.get("invalid_reason") or (
            int(r.get("trades") or 0) < MIN_TRADES
            and r.get("exit_code") not in (0, "0", None)
        )
    ]
    if invalid_seeds:
        return ("INVALID",
                f"seeds_invalid_evidence:{invalid_seeds}",
                {"per_seed_trades": [(r["seed"], r.get("trades", 0)) for r in seed_results]})

    missing_summary = [
        r["seed"] for r in seed_results
        if not r.get("summary_path") and not r.get("report_path")
    ]
    if missing_summary:
        return ("INVALID",
                f"seeds_missing_summary:{missing_summary}",
                {"per_seed_pf": [(r["seed"], r["pf"]) for r in seed_results]})

    low_trades = [r["seed"] for r in seed_results if int(r.get("trades") or 0) < MIN_TRADES]
    if low_trades:
        return ("FAIL",
                f"seed_trades_below_floor:seeds={low_trades}:floor={MIN_TRADES}",
                {"per_seed_trades": [(r["seed"], r.get("trades", 0)) for r in seed_results]})

    missing_pf = [r["seed"] for r in seed_results if r.get("pf") is None]
    if missing_pf:
        return ("FAIL",
                f"seeds_missing_pf:{missing_pf}",
                {"per_seed_pf": [(r["seed"], r["pf"]) for r in seed_results]})

    pfs = [float(r["pf"]) for r in seed_results]

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
    ap.add_argument("--latest-full-year", type=int,
                    help="Cap full-history window when validated custom-symbol history ends before default")
    ap.add_argument("--full-history-from",
                    help="Override full-history start date as YYYY.MM.DD for custom-symbol cohorts")
    ap.add_argument("--logical-symbol",
                    help="Basket evidence symbol to record when --symbol is the MT5 host")
    args = ap.parse_args()

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    repo_root = Path(__file__).resolve().parents[2]
    ea_expert = resolve_ea_expert_path(repo_root, args.ea)
    if ea_expert is None:
        print(f"cannot resolve EA dir for {args.ea}", file=sys.stderr)
        return 2
    period = period_from_setfile(args.baseline_setfile)

    # Q07 runs against Q06 HARSH stress per spec — apply HARSH first, then per-seed.
    harsh_set = gen_harsh_setfile_for(args.baseline_setfile)
    evidence_symbol = args.logical_symbol or _basket_logical_symbol(harsh_set, args.symbol) or args.symbol
    seeds = _load_canonical_seeds()
    print(f"Q07 {args.ea} {evidence_symbol}  runner_symbol={args.symbol}  seeds={seeds}  on top of HARSH stress")

    recovered = _recover_existing_seed_results(
        args.report_root,
        seeds,
        args.latest_full_year,
        args.full_history_from,
    )
    seed_results: list[dict] = []
    for seed in seeds:
        if seed in recovered:
            res = recovered[seed]
            print(f"  seed {seed}: reusing {res['summary_path']}")
            print(f"    -> PF={res['pf']}  trades={res['trades']}  exit={res['exit_code']}")
            seed_results.append(res)
            continue
        seeded_set = _write_seeded_setfile(harsh_set, seed)
        print(f"  seed {seed}: running...")
        res = _run_seed(ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
                        setfile=seeded_set, seed=seed,
                        terminal=args.terminal, report_root=args.report_root,
                        timeout_sec=args.timeout_sec, period=period,
                        latest_full_year=args.latest_full_year,
                        full_history_from=args.full_history_from)
        print(f"    -> PF={res['pf']}  trades={res['trades']}  exit={res['exit_code']}")
        seed_results.append(res)

    verdict, reason, metrics = evaluate_seeds(seed_results)
    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q07" / evidence_symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": evidence_symbol,
        "runner_symbol": args.symbol,
        "seeds": seeds,
        "verdict": verdict,
        "reason": reason,
        "metrics": metrics,
        "per_seed_detail": seed_results,
        "latest_full_year": args.latest_full_year,
        "full_history_from_override": args.full_history_from,
        "generated_at_utc": utc_now_iso(),
    })
    print(f"Q07 {args.ea} {args.symbol}: {verdict}")
    print(f"  reason: {reason}")
    return 0 if verdict == "PASS" else (1 if verdict == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
