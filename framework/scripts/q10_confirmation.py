"""Q10 — Full-History Confirmation runner.

Per Vault Q10 spec (the closing per-(EA, symbol) verdict):
  Window:   full available history per symbol (typically 2017 → present)
  Params:   Q03 plateau-median (locked)
  News:     Q09 chosen mode (default Mode 3)
  Stress:   none (baseline commission $7/lot only)
  Verdict:  PF > 1.0 AND DD < 15%

After PASS: triggers `gen_q10_baseline.py` to capture the per-trade
distribution for the Q13 KS-test kill-switch.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import (ensure_dir, utc_now_iso, write_json,
                                            resolve_ea_expert_path, period_from_setfile,
                                            find_latest_summary, FULL_HISTORY_FROM,
                                            FULL_HISTORY_TO, FULL_HISTORY_YEAR)
from framework.scripts.q05_stress_medium import _parse_pf_dd_trades, STARTING_EQUITY

GATE_NAME = "Q10"
PF_FLOOR = 1.0
DD_PCT_MAX = 15.0
DEFAULT_NEWS_TEMPORAL = "QM_NEWS_TEMPORAL_PRE30_POST30"   # Mode 3
DEFAULT_NEWS_COMPLIANCE = "QM_NEWS_COMPLIANCE_DXZ"


def write_canonical_setfile(baseline: Path, news_temporal: str,
                             news_compliance: str) -> Path:
    """Write a Q10 canonical setfile from baseline: no stress, chosen news mode."""
    text = baseline.read_text(encoding="utf-8", errors="replace")

    def patch_input(key: str, value: str) -> None:
        nonlocal text
        if re.search(rf"^{key}=", text, re.MULTILINE):
            text = re.sub(rf"^{key}=.*$", f"{key}={value}", text, flags=re.MULTILINE)
        else:
            text = text.rstrip() + f"\n{key}={value}\n"

    patch_input("qm_news_temporal", news_temporal)
    patch_input("qm_news_compliance", news_compliance)
    patch_input("qm_stress_reject_probability", "0.0000")

    # Update environment header
    text = re.sub(r"^(;\s*environment:\s*)\w+", r"\1q10_full_history_confirmation",
                  text, flags=re.MULTILINE | re.IGNORECASE)

    stem = baseline.stem
    if stem.endswith("_backtest"):
        stem = stem[: -len("_backtest")]
    out = baseline.with_name(f"{stem}_q10_confirmation.set")
    out.write_text(text, encoding="utf-8")
    return out


def run_confirmation(*, ea_id: int, ea_expert: str, symbol: str,
                      setfile: Path, terminal: str, period: str = "H1",
                      report_root: Path, timeout_sec: int = 3600) -> dict:
    repo_root = Path(__file__).resolve().parents[2]
    run_smoke_ps1 = repo_root / "framework" / "scripts" / "run_smoke.ps1"
    args = [
        "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
        "-EAId", str(ea_id),
        "-Expert", ea_expert,
        "-Symbol", symbol,
        "-Year", FULL_HISTORY_YEAR, "-FromDate", FULL_HISTORY_FROM, "-ToDate", FULL_HISTORY_TO,
        "-Terminal", terminal,
        "-Period", period,
        "-DispatchSubGateHash", f"q10_{ea_id}_{symbol.replace('.', '_')}",
        "-DispatchPhase", "Q10",
        "-DispatchVersion", "q10_full_history_confirmation",
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
    summary = find_latest_summary(report_root)
    pf, dd_money, trades = _parse_pf_dd_trades(summary) if summary else (None, None, 0)
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None

    if pf is None or dd_money is None:
        verdict, reason = "INVALID", "missing_pf_or_dd_in_summary"
    elif pf <= PF_FLOOR:
        verdict, reason = "FAIL", f"pf_below_floor:pf={pf:.3f}:floor={PF_FLOOR}"
    elif dd_pct > DD_PCT_MAX:
        verdict, reason = "FAIL", f"dd_above_ceiling:dd_pct={dd_pct:.2f}:max={DD_PCT_MAX}"
    else:
        verdict, reason = "PASS", f"pf={pf:.3f}:dd_pct={dd_pct:.2f}"

    return {
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "symbol": symbol,
        "verdict": verdict,
        "reason": reason,
        "pf": pf,
        "dd_money": dd_money,
        "dd_pct": dd_pct,
        "trades": trades,
        "exit_code": proc.returncode,
        "summary_path": str(summary) if summary else None,
        "report_htm": _find_report_htm(summary) if summary else None,
        "generated_at_utc": utc_now_iso(),
    }


def _find_report_htm(summary_path: Path) -> str | None:
    """Locate the per-run .htm report next to the summary.json."""
    if not summary_path.exists():
        return None
    raw_dir = summary_path.parent / "raw" / "run_01"
    candidate = raw_dir / "report.htm"
    if candidate.exists():
        return str(candidate)
    return None


def trigger_baseline_capture(ea_id: int, symbol: str, report_htm: str) -> bool:
    """After Q10 PASS, generate the per-trade baseline for the KS kill-switch."""
    repo_root = Path(__file__).resolve().parents[2]
    gen_script = repo_root / "framework" / "scripts" / "gen_q10_baseline.py"
    args = [sys.executable, str(gen_script),
            "--ea-id", str(ea_id),
            "--symbol", symbol,
            "--report", report_htm]
    creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
    proc = subprocess.run(args, capture_output=True, text=True,
                          timeout=60, creationflags=creationflags)
    if proc.returncode == 0:
        print(f"  baseline captured: {proc.stdout.strip()}")
        return True
    print(f"  baseline capture FAIL: {proc.stderr.strip() or proc.stdout.strip()}",
          file=sys.stderr)
    return False


def main() -> int:
    ap = argparse.ArgumentParser(description="Q10 Full-History Confirmation runner")
    ap.add_argument("--ea", required=True)
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--baseline-setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile; Q09 news mode applied to canonical Q10 variant")
    ap.add_argument("--news-temporal", default=DEFAULT_NEWS_TEMPORAL,
                    help="Q09 chosen temporal mode (default = Mode 3 pre30_post30)")
    ap.add_argument("--news-compliance", default=DEFAULT_NEWS_COMPLIANCE,
                    help="Q09 chosen compliance profile (default = DXZ)")
    ap.add_argument("--terminal", default="T2")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"))
    ap.add_argument("--timeout-sec", type=int, default=3600,
                    help="Full-history runs take longer than a single-year run")
    ap.add_argument("--no-baseline-capture", action="store_true",
                    help="Skip the gen_q10_baseline.py trigger after PASS")
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

    canonical = write_canonical_setfile(args.baseline_setfile,
                                         args.news_temporal,
                                         args.news_compliance)
    print(f"Q10 {args.ea} {args.symbol}: canonical setfile {canonical.name}")
    print(f"  news: temporal={args.news_temporal}  compliance={args.news_compliance}")

    res = run_confirmation(
        ea_id=ea_id, ea_expert=ea_expert, symbol=args.symbol,
        setfile=canonical, terminal=args.terminal, period=period,
        report_root=args.report_root, timeout_sec=args.timeout_sec,
    )
    res["news_temporal"] = args.news_temporal
    res["news_compliance"] = args.news_compliance

    out_dir = ensure_dir(args.report_root / f"QM5_{ea_id}" / "Q10" / args.symbol.replace(".", "_"))
    write_json(out_dir / "aggregate.json", res)

    print(f"Q10 {args.ea} {args.symbol}: {res['verdict']}  pf={res['pf']}  dd_pct={res['dd_pct']}  trades={res['trades']}")

    # After PASS: capture the trade-distribution baseline for Q13 KS kill-switch.
    if res["verdict"] == "PASS" and not args.no_baseline_capture and res.get("report_htm"):
        print("  Q10 PASS → triggering baseline capture for Q13 KS kill-switch...")
        trigger_baseline_capture(ea_id, args.symbol, res["report_htm"])

    return 0 if res["verdict"] == "PASS" else (1 if res["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
