"""Q10 — Full-History Confirmation runner.

Per Vault Q10 spec (the closing per-(EA, symbol) verdict):
  Window:   full available history per symbol (typically 2017 → present)
  Params:   Q03 plateau-median (locked)
  News:     Q09 chosen mode (default Mode 3)
  Stress:   none (baseline commission $7/lot only)
  Verdict:  PF > 1.0 AND DD < 25%

After PASS: triggers `gen_q10_baseline.py` to capture the per-trade
distribution for the Q13 KS-test kill-switch. Capture writes to the STAGING
baseline dir (D:/QM/reports/state/q10_baselines_staging), never the live MT5
Common dir. The live EA reads its baseline only from Common at OnInit, so a
Q10 PASS does not move any live kill-switch distribution; promoting a staged
baseline into Common is OWNER-gated (gen_q10_baseline.py --deploy-live).
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
                                            full_history_window, run_with_launch_fault_retry)
from framework.scripts.q05_stress_medium import (
    _parse_pf_dd_trades,
    _select_run_summary,
    _text_from_completed_process,
    STARTING_EQUITY,
    summary_invalid_reason,
)
from framework.scripts.gen_q10_baseline import STAGING_DIR
from framework.scripts.q10_recency import (
    RECENCY_AXIS_ENFORCED,
    RECENCY_SCHEMA_VERSION,
    compute_recency_shadow,
)

# Wrapper must outlive the tester budget (2026-07-06 audit G16).
RUNNER_HEADROOM_SEC = 120

GATE_NAME = "Q10"
PF_FLOOR = 1.0
# 15->25 to match Q02/Q05/Q06. The OWNER decision of 2026-07-15 raised the per-EA DD
# ceiling to 25% at norm risk but listed only p2_baseline.py and q05_stress_medium.py as
# affected — Q10 had never been executed at that point (first run 2026-07-20), so it
# produced no dd_above_ceiling FAIL for the audit to catch. Leaving it at 15 made the
# gates contradict each other on the same measurement: QM5_13213/USDJPY scored dd 21.50
# at Q05 (gross full-history, PASS at 25) and dd 22.80 at Q10 (full-history confirmation,
# FAIL at 15). See decisions/2026-07-15_dd_ceiling_25pct_portfolio_rationale.md.
DD_PCT_MAX = 25.0
DEFAULT_NEWS_TEMPORAL = "QM_NEWS_TEMPORAL_PRE30_POST30"   # Mode 3
DEFAULT_NEWS_COMPLIANCE = "QM_NEWS_COMPLIANCE_DXZ"


def _decide_verdict(*, timed_out: bool, invalid_reason, pf, dd_money,
                    dd_pct, timeout_sec: int) -> tuple[str, str]:
    """Q10 verdict decision — extracted VERBATIM from run_confirmation so the
    ULTRACODE WS-C recency shadow cannot influence it and so a fixture battery
    can prove the verdict logic is byte-identical. PF_FLOOR/DD_PCT_MAX unchanged
    (still the module constants 1.0 / 25.0 — the ratified 2026-07-15 ceiling).

    RECENCY_AXIS_ENFORCED is intentionally NOT an input here: the recency axis is
    shadow-only. Changing that is an OWNER-ratified DL decision, not a code edit.
    """
    if timed_out:
        return "INVALID", f"timeout_expired:timeout_sec={timeout_sec}"
    if invalid_reason:
        return "INVALID", invalid_reason
    if pf is None or dd_money is None:
        return "INVALID", "missing_pf_or_dd_in_summary"
    if pf <= PF_FLOOR:
        return "FAIL", f"pf_below_floor:pf={pf:.3f}:floor={PF_FLOOR}"
    if dd_pct > DD_PCT_MAX:
        return "FAIL", f"dd_above_ceiling:dd_pct={dd_pct:.2f}:max={DD_PCT_MAX}"
    return "PASS", f"pf={pf:.3f}:dd_pct={dd_pct:.2f}"


def _resolve_ex5_source(repo_root: Path, ea_expert: str | None) -> Path | None:
    """Best-effort resolve the source .ex5 for the confirmed EA so the recency
    shadow can bind its SHA-256. `ea_expert` is the canonical MT5 path
    'QM\\<dir>' (from resolve_ea_expert_path); the source binary lives at
    framework/EAs/<dir>/<dir>.ex5. Returns None (-> identity ex5_sha256 UNKNOWN)
    when it cannot be located rather than guessing."""
    if not ea_expert:
        return None
    name = str(ea_expert).replace("QM\\", "").replace("QM/", "").strip("\\/")
    if not name:
        return None
    cand = Path(repo_root) / "framework" / "EAs" / name / f"{name}.ex5"
    return cand if cand.exists() else None


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
                      report_root: Path, timeout_sec: int = 3600,
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
    timed_out = False
    exit_code: int | None = None
    output_text = ""
    started_at = time.time()
    try:
        proc = run_with_launch_fault_retry(
            args,
            capture_output=True,
            text=True,
            timeout=timeout_sec + RUNNER_HEADROOM_SEC,
            creationflags=creationflags,
        )
        exit_code = proc.returncode
        output_text = _text_from_completed_process(proc)
    except subprocess.TimeoutExpired as exc:
        timed_out = True
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
    pf, dd_money, trades = _parse_pf_dd_trades(summary) if summary else (None, None, 0)
    dd_pct = (dd_money / STARTING_EQUITY * 100.0) if dd_money is not None else None

    # 2026-07-06 audit G2 (mirror of the q05/q06 pattern): an infra-invalid
    # summary (NO_HISTORY cold cache, BARS_ZERO, ONINIT_FAILED, empty report)
    # still carries defaulted pf=0.0/dd=0.0 run rows — grading those as
    # strategy metrics turned first-attempt cold-cache transients into
    # terminal FAILs at the final confirmation gate.
    invalid_reason = summary_invalid_reason(summary) if summary else None

    verdict, reason = _decide_verdict(
        timed_out=timed_out, invalid_reason=invalid_reason, pf=pf,
        dd_money=dd_money, dd_pct=dd_pct, timeout_sec=timeout_sec,
    )

    report_htm = _find_report_htm(summary, started_at=started_at) if summary else None

    # ULTRACODE WS-C — recency-axis SHADOW metrics + evidence-identity binding.
    # Computed from the native report trade list and persisted under a versioned
    # key ALWAYS. Fully guarded (compute_recency_shadow never raises);
    # RECENCY_AXIS_ENFORCED is False, so this has no effect on `verdict`/`reason`
    # above. The identity block binds report / set / EX5 SHA-256 + window endpoint
    # into the aggregate so the evidence tuple is cryptographically self-describing
    # (unresolvable hash => explicit UNKNOWN; the live runner has no signed
    # manifest, so manifest_ref is UNKNOWN here and is filled in by the audit).
    ex5_source = _resolve_ex5_source(repo_root, ea_expert)
    recency_shadow = compute_recency_shadow(
        report_htm,
        setfile_path=setfile,
        ex5_path=ex5_source,
        window_endpoint=history_to,
        manifest_ref=None,
    )

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
        "exit_code": exit_code,
        "summary_path": str(summary) if summary else None,
        "report_htm": report_htm,
        "history_year": history_year,
        "history_from": history_from,
        "history_to": history_to,
        "latest_full_year": latest_full_year,
        "full_history_from_override": full_history_from,
        "generated_at_utc": utc_now_iso(),
        "recency_axis_enforced": RECENCY_AXIS_ENFORCED,
        "evidence_identity": recency_shadow.get("identity"),
        RECENCY_SCHEMA_VERSION: recency_shadow,
    }


def _find_report_htm(summary_path: Path, *, started_at: float) -> str | None:
    """Locate a report produced by the same fresh confirmation invocation."""
    if not summary_path.exists():
        return None
    candidates: list[Path] = []
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        summary = {}
    for run in reversed(summary.get("runs") or []):
        for key in ("report_canonical_path", "report_source_path"):
            raw_path = run.get(key)
            if raw_path:
                candidates.append(Path(str(raw_path)))
    candidates.extend(summary_path.parent.glob("raw/run_*/report.htm"))
    seen: set[Path] = set()
    for candidate in candidates:
        if candidate in seen:
            continue
        seen.add(candidate)
        try:
            if candidate.stat().st_mtime >= started_at:
                return str(candidate)
        except OSError:
            continue
    return None


def trigger_baseline_capture(ea_id: int, symbol: str, report_htm: str) -> bool:
    """After Q10 PASS, generate the per-trade baseline for the KS kill-switch.

    Writes into the STAGING baseline dir, never the live MT5 Common dir. The
    live loader (QM_KillSwitchKS.mqh) reads its baseline only from Common at
    OnInit, so an automated Q10 PASS leaves live/running EAs untouched: the
    corrected baseline stays staged until an OWNER-gated promotion into Common
    (gen_q10_baseline.py --deploy-live). WP-11 OWNER gate, Codex review
    2026-07-25 — automated capture must not publish into the live kill-switch
    path ahead of the manual Q11-Q13/OWNER decision."""
    repo_root = Path(__file__).resolve().parents[2]
    gen_script = repo_root / "framework" / "scripts" / "gen_q10_baseline.py"
    args = [sys.executable, str(gen_script),
            "--ea-id", str(ea_id),
            "--symbol", symbol,
            "--report", report_htm,
            "--out-dir", str(STAGING_DIR)]
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
    ap.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    ap.add_argument("--timeout-sec", type=int, default=3600,
                    help="Full-history runs take longer than a single-year run")
    ap.add_argument("--latest-full-year", type=int,
                    help="Cap full-history window when validated custom-symbol history ends before default")
    ap.add_argument("--full-history-from",
                    help="Override full-history start date as YYYY.MM.DD for custom-symbol cohorts")
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
        latest_full_year=args.latest_full_year,
        full_history_from=args.full_history_from,
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
