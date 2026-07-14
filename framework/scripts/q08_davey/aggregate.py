"""Q08 Davey aggregator — run all 11 sub-gates, AND-combine verdicts, write report.

Output:
    D:/QM/reports/pipeline/QM5_<id>/Q08/<symbol>/aggregate.json
    D:/QM/reports/pipeline/QM5_<id>/Q08/<symbol>/8_<N>_<name>.json (per sub-gate)

The combined verdict is AND across all 11 sub-gates, then calibrated into
PASS/FAIL_SOFT/FAIL_HARD/INVALID so soft-only and low-sample signals do not
become hard blockers.

Usage:
    python -m framework.scripts.q08_davey.aggregate \
        --ea-id 1056 --symbol NDX.DWX \
        --log D:/QM/strategy_farm/.../QM5_1056_NDX_DWX.log

    # Or batch — discover all Q07-PASS pairs and run Q08 on each
    python -m framework.scripts.q08_davey.aggregate --discover
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import shutil
import sys
import time
from pathlib import Path

# Allow running both as a module and as a script
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
    from tools.strategy_farm.portfolio import commission
    from framework.scripts.q08_davey import (
        common, sub_8_1_correlation, sub_8_2_dsr_mc_fdr, sub_8_3_tail_dependence,
        sub_8_4_seasonal, sub_8_5_neighborhood, sub_8_6_chopping_block,
        sub_8_7_pbo, sub_8_8_edge_decay, sub_8_9_runs_test, sub_8_10_regime_crisis,
        sub_8_11_mc_shuffle_dd,
    )
else:
    from tools.strategy_farm.portfolio import commission
    from . import (
        common, sub_8_1_correlation, sub_8_2_dsr_mc_fdr, sub_8_3_tail_dependence,
        sub_8_4_seasonal, sub_8_5_neighborhood, sub_8_6_chopping_block,
        sub_8_7_pbo, sub_8_8_edge_decay, sub_8_9_runs_test, sub_8_10_regime_crisis,
        sub_8_11_mc_shuffle_dd,
    )

from framework.scripts.q05_stress_medium import (
    _summary_from_run_smoke_output,
    _summary_identity_matches,
    _text_from_completed_process,
)

# Execution order matches the Vault Q08 spec numbering.
SUB_GATES = [
    ("8.1",  sub_8_1_correlation),
    ("8.2",  sub_8_2_dsr_mc_fdr),
    ("8.3",  sub_8_3_tail_dependence),
    ("8.4",  sub_8_4_seasonal),
    ("8.5",  sub_8_5_neighborhood),
    ("8.6",  sub_8_6_chopping_block),
    ("8.7",  sub_8_7_pbo),
    ("8.8",  sub_8_8_edge_decay),
    ("8.9",  sub_8_9_runs_test),
    ("8.10", sub_8_10_regime_crisis),
    ("8.11", sub_8_11_mc_shuffle_dd),
]

N_SEASON = 3  # max CONSECUTIVE losing calendar months still 'soft' (OWNER: "am Stück")
CHOP_SOFT = 0.90
PBO_HARD = 55.0
LOW_SAMPLE_DETAIL_TOKENS = (
    "insufficient_trade_count",
    "insufficient_daily_returns",
    "insufficient_month_coverage",
    "insufficient_history",
    "insufficient_candidate_history",
    "months_with_no_trades",
    "no_trades",
    "regime_input_missing",
    "regime_join_incomplete",
    "regimes_with_zero_trades",
)

# DL-077: minimum number of NON-TRIVIAL quality sub-gates that must actually PASS for a
# low-freq edge to advance (to the SOFT/portfolio track or a clean PASS). Below this, nothing
# real validated the edge and the result is INVALID. PBO (8.7) is the canonical such gate.
DL077_MIN_QUALITY_PASSES = 1
DEFAULT_NEIGHBORHOOD_MAX_PARAMS = 2
NEIGHBORHOOD_RUN_TIMEOUT_SEC = 900
NEIGHBORHOOD_RUN_HEADROOM_SEC = 120


def _ensure_sub_gate_inputs(ea_id: int, symbol: str, terminal: str | None = None,
                            baseline_setfile: Path | None = None,
                            neighborhood_max_params: int | None = None) -> dict:
    """PT4 2026-05-23 — pre-invoke Q08.5 + Q08.7 supporting runners if their
    output artifacts don't yet exist. Sub-gates 8.5 (neighborhood) and 8.7
    (PBO) read perturbations.json / scores.csv produced by separate runners.
    Without those files the sub-gates return INVALID; this pre-pass tries
    to populate them so the gate can give a real verdict.

    Both runners are best-effort: failure here is logged but doesn't abort
    the aggregator. The sub-gates handle missing files gracefully.
    """
    import subprocess as _sp
    sym_clean = symbol.replace(".", "_")
    repo_root = Path(__file__).resolve().parents[3]
    py = sys.executable

    ran: dict[str, dict] = {}

    perturbations = (Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/"
                          f"neighborhood/{sym_clean}/perturbations.json"))
    if not perturbations.exists():
        # Best-effort dispatch — requires a baseline setfile to be discoverable.
        # We let the runner self-resolve from --ea + --symbol via Q03 plateau
        # pick lookup; it'll log SKIP and exit non-zero if pre-reqs missing.
        baseline = baseline_setfile or _guess_baseline_setfile(repo_root, ea_id, symbol)
        if baseline is not None:
            try:
                cmd = [
                    py, str(repo_root / "framework" / "scripts" /
                            "q08_5_neighborhood_runner.py"),
                    "--ea", f"QM5_{ea_id}",
                    "--symbol", symbol,
                    "--baseline-setfile", str(baseline),
                    "--terminal", terminal or "T2",
                ]
                max_params = (
                    neighborhood_max_params
                    if neighborhood_max_params is not None
                    else DEFAULT_NEIGHBORHOOD_MAX_PARAMS
                )
                cmd.extend(["--max-params", str(max_params)])
                expected_runs = 1 + 2 * max_params
                outer_timeout = (
                    expected_runs
                    * (NEIGHBORHOOD_RUN_TIMEOUT_SEC + NEIGHBORHOOD_RUN_HEADROOM_SEC)
                    + 60
                )
                proc = _sp.run(cmd, capture_output=True, text=True, timeout=outer_timeout)
                ran["8_5_neighborhood"] = {
                    "exit_code": proc.returncode,
                    "artifact_now_exists": perturbations.exists(),
                    "stdout_tail": proc.stdout[-1000:],
                    "stderr_tail": proc.stderr[-1000:],
                }
            except _sp.TimeoutExpired:
                ran["8_5_neighborhood"] = {"exit_code": -1, "error": "timeout"}
            except Exception as exc:
                ran["8_5_neighborhood"] = {"exit_code": -1, "error": repr(exc)}
        else:
            ran["8_5_neighborhood"] = {"skipped": "no_baseline_setfile_resolvable"}

    pbo_scores = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/pbo/"
                      f"{sym_clean}/scores.csv")
    if not pbo_scores.exists():
        try:
            proc = _sp.run([
                py, str(repo_root / "framework" / "scripts" /
                        "q08_7_pbo_runner.py"),
                "--ea", f"QM5_{ea_id}",
                "--symbol", symbol,
            ], capture_output=True, text=True, timeout=600)
            ran["8_7_pbo"] = {
                "exit_code": proc.returncode,
                "artifact_now_exists": pbo_scores.exists(),
                "stdout_tail": proc.stdout[-1000:],
                "stderr_tail": proc.stderr[-1000:],
            }
        except _sp.TimeoutExpired:
            ran["8_7_pbo"] = {"exit_code": -1, "error": "timeout"}
        except Exception as exc:
            ran["8_7_pbo"] = {"exit_code": -1, "error": repr(exc)}

    return ran


def _guess_baseline_setfile(repo_root: Path, ea_id: int, symbol: str) -> Path | None:
    """Find a baseline backtest setfile for an EA — used to feed the
    neighborhood runner when we can't otherwise resolve the Q03 pick."""
    ea_dirs = [d for d in (repo_root / "framework" / "EAs").iterdir()
               if d.is_dir() and d.name.startswith(f"QM5_{ea_id}_")]
    if not ea_dirs:
        return None
    sets_dir = ea_dirs[0] / "sets"
    if not sets_dir.exists():
        return None
    # Match the symbol; prefer baseline setfiles (not stress / not seed / not perturb)
    sym_token = symbol
    for f in sets_dir.glob("*_backtest.set"):
        if sym_token in f.name and not any(s in f.name for s in
                                            ("stress", "_seed", "_perturb")):
            return f
    return None


def _common_q08_trade_log(ea_id: int, symbol: str) -> Path:
    """Deterministic Common\\Files path the recompiled EA writes its per-trade stream to
    (the tester writes the EA's own log to the agent sandbox, which Q08 can't find)."""
    return (Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files")
            / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl")


# Durable per-sleeve portfolio stream store. The Common\Files q08_trades dir is a
# VOLATILE working area: the aggregator unlink-clears it on every re-run and the EA
# only rewrites it on the fresh-baseline code path, so with heavy re-validation churn
# a valid FAIL_SOFT sleeve frequently has NO stream there by the time the portfolio
# builder looks. We therefore persist a durable copy here at verdict time, keyed by
# the VERDICT symbol, that no Q08 re-run ever clears. Structured as <root>/QM/q08_trades/
# so portfolio_common.load_streams(<root>) reads it with zero new parsing code.
DURABLE_STREAM_ROOT = Path(r"D:\QM\reports\portfolio\sleeve_streams")


def _persist_durable_sleeve_stream(ea_id: int, symbol: str,
                                   raw_trades: list[dict],
                                   common_log_override: "Path | None" = None) -> dict:
    """Persist a builder-compatible per-trade stream to the durable store.

    Fidelity rule: the portfolio commission model needs per-trade volume/notional.
    The live Common\\Files stream carries those, so copy it verbatim when present.
    Otherwise serialise the in-memory trades ONLY when every trade carries volume
    (i.e. it came from a TRADE_CLOSED source, not the volume-less HTML report
    fallback) — feeding the builder volume-less rows would silently zero commission.

    common_log_override: when the EA is a basket EA running on a host_symbol, the
    Common\\Files path is keyed on host_symbol, not the logical composite symbol.
    Pass the already-resolved common_log Path from run_all so the copy uses the
    correct source.
    """
    sym_clean = symbol.replace(".", "_")
    dst = DURABLE_STREAM_ROOT / "QM" / "q08_trades" / f"{ea_id}_{sym_clean}.jsonl"

    # 2026-07-06 audit G7: basket EAs are admitted under the LOGICAL symbol but
    # their live stream is keyed by HOST symbol. Persist under BOTH names so
    # every downstream keying convention (Q09 resolver host-key path, durable
    # logical-name path) finds the stream without manual copies.
    host_dst: Path | None = None
    if common_log_override is not None and common_log_override.name != dst.name:
        host_dst = dst.parent / common_log_override.name

    def _mirror_host_copy() -> None:
        if host_dst is not None:
            shutil.copyfile(dst, host_dst)

    if not raw_trades:
        return {"persisted": False, "reason": "no_trades", "n": 0}
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        common_log = common_log_override or _common_q08_trade_log(ea_id, symbol)
        if common_log.exists() and common_log.stat().st_size > 0:
            shutil.copyfile(common_log, dst)
            _mirror_host_copy()
            return {"persisted": True, "source": "common_copy",
                    "path": str(dst), "n": len(raw_trades),
                    "host_copy": str(host_dst) if host_dst else None}
        if all("volume" in t for t in raw_trades):
            lines = []
            for t in raw_trades:
                lines.append(json.dumps({
                    "event": "TRADE_CLOSED",
                    "time": int(t.get("time") or 0),
                    "net": float(t.get("net") or 0.0),
                    "profit": float(t.get("profit") or 0.0),
                    "swap": float(t.get("swap") or 0.0),
                    "commission": float(t.get("commission") or 0.0),
                    "volume": float(t.get("volume") or 0.0),
                    "notional": t.get("notional"),
                    "symbol": t.get("symbol") or symbol,
                }))
            dst.write_text("\n".join(lines) + "\n", encoding="utf-8")
            _mirror_host_copy()
            return {"persisted": True, "source": "serialized",
                    "path": str(dst), "n": len(lines),
                    "host_copy": str(host_dst) if host_dst else None}
        return {"persisted": False, "reason": "report_fallback_no_volume",
                "n": len(raw_trades)}
    except OSError as exc:
        return {"persisted": False, "reason": f"oserror:{exc}", "n": len(raw_trades)}


def _latest_structured_qm_log(ea_id: int, symbol: str, terminal: str | None = None) -> Path | None:
    """Find the fullest tester-agent QM log carrying structured framework events.

    `farmctl` passes the terminal MQL5 Logs path, but Strategy Tester agents write
    QM_Logger output under Tester/Agent-*/MQL5/Files/QM. The Common\\Files stream
    only carries TRADE_CLOSED rows, so Q08.1/8.3/8.10 need this recovery path for
    EQUITY_SNAPSHOT input.
    """
    terminals = [terminal] if terminal else []
    terminals.extend(f"T{i}" for i in range(1, 11) if f"T{i}" not in terminals)
    symbol_token = f'"symbol":"{symbol}"'

    candidates: list[Path] = []
    for term in terminals:
        if not term:
            continue
        base = Path("D:/QM/mt5") / term / "Tester"
        if not base.exists():
            continue
        candidates.extend(base.glob(f"Agent-*/MQL5/Files/QM/QM5_{ea_id}_*.log"))

    best: tuple[int, float, Path] | None = None
    for path in candidates:
        count = 0
        try:
            with path.open(encoding="utf-8", errors="ignore") as fh:
                for line in fh:
                    if "EQUITY_SNAPSHOT" in line and symbol_token in line:
                        count += 1
        except OSError:
            continue
        if count <= 0:
            continue
        score = (count, path.stat().st_mtime, path)
        if best is None or score[:2] > best[:2]:
            best = score
    return best[2] if best is not None else None


def _host_symbol_from_setfile(setfile: Path, fallback: str) -> str:
    """Read '; host_symbol:' from the setfile header. Basket EAs carry a logical
    composite symbol that does not exist in MT5's market watch; the host_symbol
    is the physical MT5 symbol the baseline backtest must run on.

    Tolerant parser: strips leading/trailing whitespace, case-insensitive on the
    key, accepts both ';host_symbol:' and '; host_symbol :' spacings.
    Single-symbol EAs have no such header line — the fallback is returned unchanged,
    so this helper is a zero-regression no-op for non-basket EAs.
    """
    try:
        for line in setfile.read_text(encoding="utf-8-sig").splitlines():
            m = re.match(r";\s*host_symbol\s*:\s*(\S+)", line.strip(), flags=re.IGNORECASE)
            if m:
                return m.group(1)
    except (OSError, UnicodeDecodeError):
        pass
    return fallback


def _run_baseline_for_trades(ea_id: int, symbol: str, terminal: str | None,
                             baseline_setfile: Path | None = None) -> dict:
    """Run ONE clean full-history backtest so the EA emits its TRADE_CLOSED stream to
    Common\\Files. Q08 itself doesn't otherwise run a backtest, so without this the trade
    log never exists for the aggregator to read."""
    import subprocess as _sp
    import re as _re
    repo_root = Path(__file__).resolve().parents[3]
    baseline = baseline_setfile or _guess_baseline_setfile(repo_root, ea_id, symbol)
    if baseline is None:
        return {"skipped": "no_baseline_setfile"}
    baseline = Path(baseline)
    ea_dirs = [d for d in (repo_root / "framework" / "EAs").iterdir()
               if d.is_dir() and d.name.startswith(f"QM5_{ea_id}_")]
    if not ea_dirs:
        return {"skipped": "no_ea_dir"}
    expert = f"QM\\{ea_dirs[0].name}"
    m = _re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)_backtest", baseline.name)
    period = m.group(1) if m else "H1"
    report_root = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/_baseline")
    test_symbol = _host_symbol_from_setfile(baseline, symbol)
    # Basket EAs run on the host physical symbol rather than the logical composite.
    # Real-tick (Model 4) multi-symbol baskets can exceed 2400s; allow 5400s.
    # The Q08 phase-runner timeout in farmctl must be >= 90 min for basket EAs.
    is_basket = test_symbol != symbol
    timeout_run = 5400 if is_basket else 2400
    timeout_proc = timeout_run + 120
    test_terminal = terminal or "T1"
    args = [
        "pwsh.exe", "-NoProfile", "-File",
        str(repo_root / "framework" / "scripts" / "run_smoke.ps1"),
        "-EAId", str(ea_id), "-Expert", expert, "-Symbol", test_symbol,
        "-Year", "2025", "-FromDate", "2017.01.01", "-ToDate", "2025.12.31",
        "-Terminal", test_terminal, "-Period", period,
        "-Runs", "1", "-MinTrades", "1", "-Model", "4",
        "-SetFile", str(baseline), "-ReportRoot", str(report_root),
        "-DispatchPhase", "Q08", "-DispatchVersion", "q08_baseline",
        "-DispatchSubGateHash", f"q08base_{ea_id}_{symbol.replace('.', '_')}",
        "-TimeoutSeconds", str(timeout_run),
    ]
    flags = 0x08000000 if sys.platform == "win32" else 0
    started_at = time.time()
    output_text = ""
    exit_code = None
    run_error = None
    try:
        p = _sp.run(args, capture_output=True, text=True, timeout=timeout_proc, creationflags=flags)
        exit_code = p.returncode
        output_text = _text_from_completed_process(p)
    except Exception as exc:
        run_error = repr(exc)
        output_text = _text_from_completed_process(exc)
    summary = _summary_from_run_smoke_output(
        output_text,
        started_at=started_at,
        ea_id=ea_id,
        ea_expert=expert,
        symbol=test_symbol,
        period=period,
        terminal=test_terminal,
    ) or _latest_baseline_summary(
        report_root,
        ea_id,
        wait_seconds=10 if run_error is None else 0,
        started_at=started_at,
        expected_expert=expert,
        expected_symbol=test_symbol,
        expected_period=period,
        expected_terminal=test_terminal,
    )
    out = {
        "exit_code": exit_code,
        "expert": expert,
        "period": period,
        "test_symbol": test_symbol,
        "test_terminal": test_terminal,
        "run_started_at": started_at,
    }
    if run_error is not None:
        out["error"] = run_error
    if summary is not None:
        out.update(_baseline_report_metadata(summary, started_at=started_at))
    structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
    if structured_log is not None:
        out["structured_log_path"] = str(structured_log)
    return out


def _latest_baseline_summary(
        report_root: Path, ea_id: int, wait_seconds: int = 0, *,
        started_at: float, expected_expert: str, expected_symbol: str,
        expected_period: str, expected_terminal: str) -> Path | None:
    """Return only a fresh baseline summary for the exact expected MT5 run."""
    base = report_root / f"QM5_{ea_id}"
    deadline = time.time() + max(0, wait_seconds)
    while True:
        if base.exists():
            summaries: list[tuple[float, Path]] = []
            for candidate in base.glob("*/summary.json"):
                try:
                    mtime = candidate.stat().st_mtime
                except OSError:
                    continue
                if mtime >= started_at:
                    summaries.append((mtime, candidate))
            for _mtime, candidate in sorted(summaries, reverse=True):
                try:
                    data = json.loads(candidate.read_text(encoding="utf-8-sig"))
                except (OSError, json.JSONDecodeError):
                    continue
                if _summary_identity_matches(
                        data, ea_id=ea_id, ea_expert=expected_expert,
                        symbol=expected_symbol, period=expected_period,
                        terminal=expected_terminal):
                    return candidate
        if time.time() >= deadline:
            return None
        time.sleep(1)


def _baseline_report_metadata(
        summary_path: Path, *, started_at: float | None = None) -> dict:
    try:
        data = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {"baseline_summary_path": str(summary_path)}
    runs = data.get("runs") or []
    run = runs[0] if runs else {}
    report_path = run.get("report_canonical_path") or run.get("report_source_path")
    if report_path and started_at is not None:
        try:
            if Path(str(report_path)).stat().st_mtime < started_at:
                report_path = None
        except OSError:
            report_path = None
    return {
        "baseline_summary_path": str(summary_path),
        "baseline_result": data.get("result"),
        "baseline_reason_classes": data.get("reason_classes"),
        "baseline_report_path": report_path,
        "baseline_total_trades": run.get("total_trades"),
        "baseline_profit_factor": run.get("profit_factor"),
    }


def _float_or_none(value) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _gross_before_commission(trade: dict) -> float:
    profit = _float_or_none(trade.get("profit"))
    swap = _float_or_none(trade.get("swap")) or 0.0
    if profit is not None:
        return profit + swap

    net = _float_or_none(trade.get("net")) or 0.0
    broker_commission = _float_or_none(trade.get("commission"))
    if broker_commission is not None:
        return net - broker_commission
    return net


# DL-072 (OWNER-ratified 2026-06-09): cost-cushion gate. cushion = gross / realistic
# cost = the multiple of realistic per-instrument cost the gross edge can absorb before
# net P&L hits zero. The principled, instrument-correct robustness filter for cost-
# fragile small edges — replaces the arbitrary flat-$7 cost number with a margin metric.
Q08_COST_CUSHION_PASS = 2.0   # cushion >= 2 => net profit >= realistic cost (robust)
Q08_COST_CUSHION_SOFT = 1.0   # 1 <= cushion < 2 => net-positive but thin -> EDGE_SOFT


def _cost_cushion(gross_total: float, cost_total: float) -> tuple[float | None, str]:
    """(cushion, tier). cushion = gross/cost; tier PASS / EDGE_SOFT / EDGE_HARD.
    gross<=0 => no edge to cushion (EDGE_HARD; profitability gates handle it anyway).
    cost~0  => no modeled cost drag (PASS, cushion N/A)."""
    if gross_total <= 0:
        return ((round(gross_total / cost_total, 4) if cost_total > 1e-9 else 0.0), "EDGE_HARD")
    if cost_total <= 1e-9:
        return None, "PASS"
    cushion = gross_total / cost_total
    if cushion >= Q08_COST_CUSHION_PASS:
        tier = "PASS"
    elif cushion >= Q08_COST_CUSHION_SOFT:
        tier = "EDGE_SOFT"
    else:
        tier = "EDGE_HARD"
    return round(cushion, 4), tier


def _apply_worst_case_commission(trades: list[dict], fallback_symbol: str) -> tuple[list[dict], dict]:
    model = commission.load_model()
    adjusted: list[dict] = []
    total_cost = 0.0
    gross_total = 0.0

    volumeless = 0
    for trade in trades:
        row = dict(trade)
        trade_symbol = str(row.get("symbol") or fallback_symbol)
        volume = _float_or_none(row.get("volume")) or 0.0
        if volume <= 0.0:
            volumeless += 1
        notional = _float_or_none(row.get("notional"))
        cost = model.cost_round_trip(trade_symbol, volume, notional)
        total_cost += cost
        gross_total += _gross_before_commission(row)

        original_net = _float_or_none(row.get("net", row.get("profit", 0))) or 0.0
        row["net_original"] = original_net
        row["commission_model_cost"] = cost
        row["commission_basis"] = "worst_case_dxz_ftmo"
        row["net"] = _gross_before_commission(row) - cost
        adjusted.append(row)

    cushion, tier = _cost_cushion(gross_total, total_cost)
    # 2026-07-06 audit G4: volume-less rows (HTML-report fallback) price every
    # trade at $0 commission — cushion "PASS" and net==gross are then data
    # artifacts, not cost statements. The durable-stream persister already
    # refuses such rows (report_fallback_no_volume); grading must refuse them
    # too, on any trade set that actually traded.
    if trades and volumeless == len(trades):
        cushion, tier = None, "INVALID"
    model_info = commission.describe_model(model)
    return adjusted, {
        "commission_basis": "worst_case_dxz_ftmo",
        "commission_model": model_info,
        "commission_total": round(total_cost, 6),
        "gross_total": round(gross_total, 6),
        # DL-072 cost-cushion: how many multiples of realistic per-instrument cost
        # the gross edge can absorb before net P&L hits zero (cushion = gross/cost).
        # The principled, instrument-correct successor to the flat-$7 cost gate.
        "cost_cushion": cushion,
        "cost_cushion_tier": tier,
        "degraded_symbols": model_info["degraded_symbols"],
    }


def _detail_text(sub_gate_result: dict) -> str:
    return str(sub_gate_result.get("detail") or "").strip()


def _result_name(sub_gate_result: dict) -> str:
    return str(sub_gate_result.get("name") or "").strip().lower()


def _float_from_detail(detail: str, pattern: str) -> float | None:
    match = re.search(pattern, detail)
    if not match:
        return None
    try:
        return float(match.group(1))
    except (TypeError, ValueError):
        return None


def _max_consecutive_losing_months(sub_gate_result: dict) -> int | None:
    """Longest run of CONSECUTIVE losing calendar months (OWNER: 'am Stück').
    4 scattered losing months are not a sustained drawdown; 4 in a row are."""
    evidence = sub_gate_result.get("evidence") or {}
    losing_months = evidence.get("losing_months")
    if not isinstance(losing_months, list):
        detail = _detail_text(sub_gate_result)
        if "losing_months:" not in detail:
            return None
        tail = detail.split("losing_months:", 1)[1]
        losing_months = [int(x) for x in re.findall(r"\b\d{1,2}\b", tail)]
    months = sorted({int(m) for m in losing_months if 1 <= int(m) <= 12})
    if not months:
        return 0
    best = run = 1
    for i in range(1, len(months)):
        run = run + 1 if months[i] == months[i - 1] + 1 else 1
        best = max(best, run)
    return best


def _classify_fail(sub_gate_result: dict) -> str:
    """Classify a non-PASS Q08 sub-gate result for the portfolio-rescue track."""
    detail = _detail_text(sub_gate_result)
    detail_lower = detail.lower()
    name = _result_name(sub_gate_result)

    if any(token in detail_lower for token in LOW_SAMPLE_DETAIL_TOKENS):
        return "LOW_SAMPLE"

    if name.startswith("8.4"):
        streak = _max_consecutive_losing_months(sub_gate_result)
        if streak is not None and streak <= N_SEASON:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    if name.startswith("8.6"):
        pf_after = _float_from_detail(detail, r"pf_after_top\d+pct_removal=([-+]?\d+(?:\.\d+)?)")
        if pf_after is not None and CHOP_SOFT <= pf_after < 1.0:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    if name.startswith("8.7"):
        pbo = _float_from_detail(detail, r"PBO=([-+]?\d+(?:\.\d+)?)%")
        if pbo is not None and 40.0 < pbo <= PBO_HARD:
            return "EDGE_SOFT"
        return "EDGE_HARD"

    return "EDGE_HARD"


def _net_profit_factor(trades: list[dict]) -> float | None:
    profits = [_float_or_none(t.get("net")) or 0.0 for t in trades]
    return common.profit_factor(profits)


def _aggregate_verdict(sub_results: list[dict], trades: list[dict] | None = None,
                       cost_cushion_tier: str | None = None) -> tuple[str, dict[str, str]]:
    """Combine sub-gate statuses into PASS/FAIL_SOFT/FAIL_HARD/INVALID."""
    classification: dict[str, str] = {}
    hard = False
    soft = False
    invalid = False

    for result in sub_results:
        name = str(result.get("name") or "unknown")
        status = str(result.get("status") or "").upper()
        if status == "PASS":
            classification[name] = "PASS"
            continue
        # Portfolio reframe (DL-075, 2026-06-21, OWNER): seasonal (8.4), chopping-block
        # (8.6), regime/crisis (8.10), and MC shuffle DD (8.11) measure SINGLE-EA
        # robustness across conditions or trade sequencing —
        # exactly the risk the Q09 anti-correlation portfolio absorbs by diversification.
        # Requiring each EA to individually survive every season/regime double-counts the
        # robustness bar and walls off low-freq/regime-dependent edges. So these gates
        # gates can only contribute a SOFT signal here: never HARD-fail, never block as
        # INVALID. The EA flows to the Q09 portfolio track where combined robustness is
        # the real gate. Profitability (portfolio_net_pf, cost_cushion) stays HARD below.
        if name.startswith(("8.4", "8.6", "8.10", "8.11")):
            classification[name] = "EDGE_SOFT"
            soft = True
            continue
        if status == "INVALID" and not any(
            token in _detail_text(result).lower() for token in LOW_SAMPLE_DETAIL_TOKENS
        ):
            classification[name] = "INVALID"
            invalid = True
            continue
        tier = _classify_fail(result)
        classification[name] = tier
        if tier == "EDGE_HARD":
            hard = True
        else:
            soft = True

    pf = _net_profit_factor(trades or [])
    if pf is not None and pf < 1.0:
        classification["portfolio_net_pf"] = "EDGE_HARD"
        hard = True

    # DL-072 cost-cushion gate: the new signal here is the EDGE_SOFT band — an edge
    # that IS net-positive but has a thin margin over realistic per-instrument cost
    # (< 2x). EDGE_HARD (cost > gross) is consistent with portfolio_net_pf above.
    if cost_cushion_tier == "EDGE_HARD":
        # DL-077: cost_cushion goes EDGE_HARD when gross <= 0 — but that is ALSO the state of a
        # 0-trade baseline (an infra failure: the Q08 baseline produced no trades), not a real
        # cost failure. Never HARD-fail an EA on a baseline that did not run; mark INVALID so it
        # re-runs. A genuine cost fail (traded, but gross <= cost) keeps EDGE_HARD.
        if trades:
            classification["cost_cushion"] = "EDGE_HARD"
            hard = True
        else:
            classification["cost_cushion"] = "INVALID"
            invalid = True
    elif cost_cushion_tier == "EDGE_SOFT":
        classification["cost_cushion"] = "EDGE_SOFT"
        soft = True
    elif cost_cushion_tier == "PASS":
        classification["cost_cushion"] = "PASS"
    elif cost_cushion_tier == "INVALID":
        # 2026-07-06 audit G4: all-volume-less trade set (report fallback) —
        # commission was un-computable, so BOTH hard profitability gates
        # (cushion + net PF) graded gross. Re-run with a real stream.
        classification["cost_cushion"] = "INVALID"
        invalid = True

    # HARD dominates: a definitive edge failure (e.g. PBO 88%, net PF < 1.0) means the EA is
    # not robust regardless of a non-evaluable gate.
    if hard:
        return "FAIL_HARD", classification

    # DL-077 (2026-06-26, OWNER): the Davey statistical battery mostly CANNOT COMPUTE for the
    # low-frequency structural edges this funnel selects (8.2 DSR, 8.6, 8.8, 8.9, 8.10 go
    # INVALID at low trade/daily-return counts). An INVALID sub-gate means "could not test",
    # NOT "failed" -- it must never block a PROFITABLE edge with real evidence (e.g. PBO) from
    # the Q09 portfolio track. Pre-DL-077 a single non-low-sample INVALID returned the blocking
    # INVALID verdict -> every low-freq sleeve INFRA_FAILed at Q08 and the book could not grow.
    if pf is None:
        # Profitability itself could not be computed (no baseline trades) -> genuinely invalid.
        return "INVALID", classification
    # Require at least one NON-TRIVIAL quality gate to actually pass (8.1/8.3 are trivial
    # first-portfolio passes); otherwise nothing real validated the edge -> too thin to advance.
    real_quality_passes = sum(
        1 for gate_name, verdict in classification.items()
        if verdict == "PASS" and not str(gate_name).startswith(("8.1", "8.3"))
    )
    if real_quality_passes < DL077_MIN_QUALITY_PASSES:
        return "INVALID", classification
    # Profitable, has real evidence, no hard failure: INVALID Davey gates and soft signals
    # both route to the portfolio track (FAIL_SOFT), never block. Clean gold PASS only when
    # there are no soft/invalid signals at all.
    if soft or invalid:
        return "FAIL_SOFT", classification
    return "PASS", classification


def run_all(ea_id: int, symbol: str, log_path: Path,
            portfolio: list[dict] | None = None,
            out_dir: Path | None = None,
            terminal: str | None = None,
            baseline_setfile: Path | None = None,
            neighborhood_max_params: int | None = None) -> dict:
    log_path = Path(log_path)
    trades = common.load_trades_from_log(log_path)
    equity_stream = common.load_equity_stream(log_path)
    if not equity_stream:
        structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
        if structured_log is not None:
            equity_stream = common.load_equity_stream(structured_log)
    # Tester writes the EA log to the agent sandbox, so the farmctl --log path is empty.
    # The recompiled EA also dumps a TRADE_CLOSED stream to Common\Files; read that, and
    # run a clean baseline backtest first if it's not there yet.
    host_log: "Path | None" = None  # resolved to host-symbol path for basket EAs; used below
    baseline_run = None
    if not trades:
        common_log = _common_q08_trade_log(ea_id, symbol)
        # Basket EAs: resolve host-symbol log path. The EA's _Symbol is the physical chart
        # symbol (e.g. GBPJPY.DWX), NOT the logical composite symbol used as the work-item
        # key, so TRADE_CLOSED lands in a per-host path, not the logical-symbol path.
        _repo_root_q8 = Path(__file__).resolve().parents[3]
        _baseline_sf_q8 = baseline_setfile or _guess_baseline_setfile(_repo_root_q8, ea_id, symbol)
        if _baseline_sf_q8 is not None:
            _h_sym = _host_symbol_from_setfile(Path(_baseline_sf_q8), symbol)
            if _h_sym and _h_sym != symbol:
                host_log = _common_q08_trade_log(ea_id, _h_sym)
        # Always run a FRESH full-history baseline so Q08 evaluates a clean run, not a
        # stale per-fold log left by an earlier phase (which would undercount trades and
        # wrongly fail a higher-frequency strategy). Clear the stale log first.
        try:
            if common_log.exists():
                common_log.unlink()
        except OSError:
            pass
        # NOTE: we intentionally do NOT delete host_log here. For basket EAs the host-symbol
        # file is written only by a full-history OnDeinit, so pre-existing data is always a
        # valid full-history run. If the fresh baseline succeeds, the EA overwrites it with
        # updated data. If the baseline times out (long cold-cache multi-symbol runs), the
        # pre-existing file provides the correct fallback. Deleting it before a potentially
        # timed-out baseline discards the only valid trade stream — the 0-trade INVALID loop.
        baseline_run = _run_baseline_for_trades(ea_id, symbol, terminal, baseline_setfile)
        if baseline_run and not baseline_run.get("baseline_report_path"):
            retry_started_at = _float_or_none(baseline_run.get("run_started_at"))
            if retry_started_at is not None:
                retry_summary = _latest_baseline_summary(
                    Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/_baseline"),
                    ea_id,
                    wait_seconds=5,
                    started_at=retry_started_at,
                    expected_expert=str(baseline_run.get("expert") or ""),
                    expected_symbol=str(baseline_run.get("test_symbol") or ""),
                    expected_period=str(baseline_run.get("period") or ""),
                    expected_terminal=str(baseline_run.get("test_terminal") or ""),
                )
                if retry_summary is not None:
                    baseline_run.update(_baseline_report_metadata(
                        retry_summary,
                        started_at=retry_started_at,
                    ))
        trades = common.load_trades_from_log(common_log)
        equity_stream = common.load_equity_stream(common_log) or equity_stream
        # Basket EA host-symbol fallback: if the logical-symbol path is still empty after
        # the baseline, the EA used _Symbol (physical chart symbol) as its TRADE_CLOSED key.
        if not trades and host_log is not None:
            trades = common.load_trades_from_log(host_log)
            equity_stream = common.load_equity_stream(host_log) or equity_stream
            if trades and baseline_run is not None:
                baseline_run["host_sym_log_fallback"] = str(host_log)
        structured_log = _latest_structured_qm_log(ea_id, symbol, terminal)
        if structured_log is not None:
            equity_stream = common.load_equity_stream(structured_log) or equity_stream
            if baseline_run is not None:
                baseline_run["structured_log_path"] = str(structured_log)
        if not trades and baseline_run and baseline_run.get("baseline_report_path"):
            trades = common.load_trades_from_mt5_report(Path(str(baseline_run["baseline_report_path"])))

    # Snapshot the per-trade list BEFORE worst-case commission mutates it; the durable
    # portfolio stream carries gross-of-worst-case net (the builder reapplies its own
    # commission model), matching the raw Common\Files stream format.
    raw_trades = [dict(t) for t in trades]
    portfolio_stream = _persist_durable_sleeve_stream(ea_id, symbol, raw_trades, host_log)

    trades, commission_info = _apply_worst_case_commission(trades, symbol)

    # PT4 — best-effort pre-run of Q08.5 + Q08.7 supporting runners
    sub_gate_input_runs = _ensure_sub_gate_inputs(
        ea_id,
        symbol,
        terminal,
        baseline_setfile,
        neighborhood_max_params,
    )

    sub_results: list[dict] = []
    for label, mod in SUB_GATES:
        try:
            res = mod.run(
                trades=trades,
                equity_stream=equity_stream,
                portfolio=portfolio,
                ea_id=ea_id,
                symbol=symbol,
            )
        except Exception as exc:
            res = common.make_result(
                f"{label}_{mod.GATE_NAME if hasattr(mod, 'GATE_NAME') else 'unknown'}",
                "INVALID",
                value=None, threshold=None,
                detail=f"sub_gate_exception:{type(exc).__name__}:{exc}",
            )
        sub_results.append(res)

    mc_shuffle_dd = next(
        (
            dict(r.get("evidence") or {})
            for r in sub_results
            if str(r.get("name") or "").startswith("8.11")
        ),
        None,
    )

    # PASS only if all 11 PASS; otherwise split failures into hard/soft/infra.
    overall, verdict_classification = _aggregate_verdict(
        sub_results, trades, commission_info.get("cost_cushion_tier"))

    aggregate = {
        "ea_id": ea_id,
        "symbol": symbol,
        "phase": "Q08",
        "verdict": overall,
        "verdict_classification": verdict_classification,
        "verdict_calibration": {
            "N_SEASON": N_SEASON,
            "CHOP_SOFT": CHOP_SOFT,
            "PBO_HARD": PBO_HARD,
        },
        "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "n_trades": len(trades),
        "n_equity_snapshots": len(equity_stream),
        "commission_basis": commission_info["commission_basis"],
        "commission_model": commission_info["commission_model"],
        "commission_total": commission_info["commission_total"],
        "gross_total": commission_info.get("gross_total"),
        "cost_cushion": commission_info.get("cost_cushion"),
        "cost_cushion_tier": commission_info.get("cost_cushion_tier"),
        "sub_gates": sub_results,
        "sub_gate_input_runs": sub_gate_input_runs,
        "baseline_run": baseline_run,
        "summary": {
            "n_pass":    sum(1 for r in sub_results if r["status"] == "PASS"),
            "n_fail":    sum(1 for r in sub_results if r["status"] == "FAIL"),
            "n_invalid": sum(1 for r in sub_results if r["status"] == "INVALID"),
        },
    }
    if mc_shuffle_dd:
        aggregate["mc_shuffle_dd"] = mc_shuffle_dd
        aggregate["mc_maxdd_p95"] = mc_shuffle_dd.get("mc_maxdd_p95")
        aggregate["mc_maxdd_p95_pct"] = mc_shuffle_dd.get("mc_maxdd_p95_pct")
        aggregate["mc_maxdd_p95_over_as_realized_maxdd"] = (
            mc_shuffle_dd.get("mc_maxdd_p95_over_as_realized_maxdd")
        )
    if commission_info["degraded_symbols"]:
        aggregate["degraded_symbols"] = commission_info["degraded_symbols"]

    if out_dir is None:
        sym_clean = symbol.replace(".", "_")
        out_dir = Path(f"D:/QM/reports/pipeline/QM5_{ea_id}/Q08/{sym_clean}")
    out_dir.mkdir(parents=True, exist_ok=True)

    # Persisted before Q08.5/Q08.7 support runners can overwrite the volatile
    # Common\Files trade stream with perturbation/fold artifacts.
    aggregate["portfolio_stream"] = portfolio_stream

    (out_dir / "aggregate.json").write_text(
        json.dumps(aggregate, indent=2, default=str), encoding="utf-8"
    )
    for r in sub_results:
        slug = r["name"].replace(".", "_")
        (out_dir / f"{slug}.json").write_text(
            json.dumps(r, indent=2, default=str), encoding="utf-8"
        )

    return aggregate


def _print_summary(agg: dict) -> None:
    print(f"\nQ08 · QM5_{agg['ea_id']} {agg['symbol']}  ->  {agg['verdict']}")
    print(f"    trades={agg['n_trades']}  equity_snaps={agg['n_equity_snapshots']}")
    for r in agg["sub_gates"]:
        flag = {"PASS": "OK", "FAIL": "X ", "INVALID": "? "}.get(r["status"], "  ")
        val = r.get("value")
        thr = r.get("threshold")
        print(f"    {flag} {r['name']:30s}  value={val}  threshold={thr}")
        print(f"        {r['detail']}")


def main() -> int:
    ap = argparse.ArgumentParser(description="Q08 Davey aggregator (11 sub-gates)")
    ap.add_argument("--ea-id", type=int, help="EA id (with --symbol + --log)")
    ap.add_argument("--symbol", help="symbol e.g. NDX.DWX")
    ap.add_argument("--log", type=Path, help="path to EA JSON-lines log")
    ap.add_argument("--out-dir", type=Path, help="override output dir")
    ap.add_argument("--terminal", help="MT5 terminal (T1-T10) for the baseline trade-log backtest")
    ap.add_argument("--baseline-setfile", type=Path,
                    help="explicit baseline setfile for Q08 baseline and neighborhood support runs")
    ap.add_argument("--neighborhood-max-params", type=int,
                    help="override Q08.5 perturbation parameter cap for bounded reruns")
    ap.add_argument("--discover", action="store_true",
                    help="walk Q07-PASS pairs in farm DB and run Q08 on each (TODO)")
    args = ap.parse_args()

    if args.discover:
        print("--discover not yet wired (needs farm DB query of Q07 PASS pairs)", file=sys.stderr)
        return 2

    if not (args.ea_id and args.symbol and args.log):
        ap.print_usage(sys.stderr)
        return 2

    agg = run_all(
        args.ea_id,
        args.symbol,
        args.log,
        out_dir=args.out_dir,
        terminal=args.terminal,
        baseline_setfile=args.baseline_setfile,
        neighborhood_max_params=args.neighborhood_max_params,
    )
    _print_summary(agg)
    return 0 if agg["verdict"] == "PASS" else (1 if agg["verdict"] == "FAIL" else 3)


if __name__ == "__main__":
    sys.exit(main())
