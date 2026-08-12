"""Q04 — Walk-Forward + Commission runner.

Per Vault `03 Pipeline/Q04 Walk-Forward + Commission.md` (2026-05-23 rewrite):

  3 anchored expanding-window folds, 12-month OOS each:
      F1: DEV 2017-01-01 → 2022-12-31 / OOS 2023-01-01 → 2023-12-31
      F2: DEV 2017-01-01 → 2023-12-31 / OOS 2024-01-01 → 2024-12-31
      F3: DEV 2017-01-01 → 2024-12-31 / OOS 2025-01-01 → 2025-12-31

  Each fold runs with $7/lot ECN commission applied via the tester groups
  file. Per-fold PF-gross AND PF-net captured (FW1 OWNER call). Verdict:
  ALL 3 folds must have PF-net > 1.0.

Per-symbol verdict (runs per Q03 PASS entry). Skipped for symbols whose
first_data_year > 2022 (would have no valid DEV window).

Usage:
    python q04_walkforward.py --ea QM5_1056 --symbol NDX.DWX \
        --params <plateau_pick.json> --terminal T2

    # Batch — discover Q03-PASS pairs in farm DB and run all
    python q04_walkforward.py --discover --max 10
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import sys
from pathlib import Path

# Allow running both as a module and as a script
if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from framework.scripts._phase_utils import ensure_dir, run_with_launch_fault_retry, utc_now_iso

GATE_NAME = "Q04"
# DL-082 §2 (OWNER-ratified 2026-07-19): the Q04 cost input is now the per-symbol,
# per-venue truth in framework/registry/venue_cost_model.json, selectable via
# --cost-variant / QM_Q04_COST_VARIANT (dxz worst-case default | ftmo | flat7). The
# flat $7/lot below is retained ONLY as the `flat7` reproduction variant and as the
# ultimate never-null hard fallback. This is an INPUT correction: fold thresholds and
# all grading logic below are UNCHANGED.
COMMISSION_PER_LOT_ROUND_TRIP = 7.00     # USD; legacy flat7 reproduction / hard fallback
DEFAULT_COST_VARIANT = "dxz"
COST_VARIANT_ENV = "QM_Q04_COST_VARIANT"
PF_NET_FLOOR_PER_FOLD = 1.0
# DL-071 (OWNER-ratified 2026-06-09): PASS_SOFT tier for net-positive-with-variance
# edges (ORB / structural setups lose in some periods by design). Clean PASS still
# requires every fold > floor; PASS_SOFT requires a profitable MAJORITY of folds, a
# clear mean edge, and NO catastrophic fold — guardrails so it recalibrates without
# passing single-year wonders. Tunable.
Q04_SOFT_MEAN_FLOOR = 1.10        # mean PF-net across folds must exceed this
Q04_SOFT_MIN_FOLD_FLOOR = 0.80    # no fold may be below this (no catastrophic year)
Q04_SOFT_MIN_POS_FRACTION = 2.0 / 3.0  # >= this fraction of folds must have PF-net > floor

# Low-freq-aware Q04 (DL-076, OWNER-ratified 2026-06-23). A strategy firing only a few
# times per year is sliced too thin by the 3×1yr OOS folds: a per-year PF from 5-10
# trades is noise, not a robustness signal, and one thin year tanks the strict gate. For
# LOW-FREQUENCY EAs only, additionally evaluate a single POOLED OOS window (all OOS years
# concatenated) under the SAME PF-net > 1.0 bar — the statistically correct unit at that
# sample size, NOT a softened threshold. The pooled stream is the concatenation of the 3
# strict folds' realistic-net per-trade streams (no extra backtest; identical cost model).
# Guards keep quality identical:
#   (1) eligibility — avg < Q04_LOWFREQ_MAX_TRADES_PER_YEAR OOS trades/yr across the folds
#   (2) >= Q04_OOS_MIN_TRADES_PER_YEAR trades/yr sustained on the pooled OOS window, else
#       INVALID (never a free pass). OWNER 2026-06-26: "5 Trades/Jahr genügen, WENN er auf
#       den OOS-Daten min. 5/Jahr macht" — this is the OOS counterpart to the relaxed Q02
#       trade floor (Q02 now accepts 5/yr in-sample; Q04 confirms 5/yr holds out-of-sample).
#   (3) trades in >= Q04_LOWFREQ_MIN_ACTIVE_YEARS of the OOS years (no single-year wonder)
# High-frequency EAs are untouched: the strict 3-fold is their only path. Only attempted
# when the strict verdict is FAIL with every fold completed — never rescues INFRA/INVALID.
Q04_LOWFREQ_MAX_TRADES_PER_YEAR = 15
# OOS floor: pooled trades must be >= this rate * number of OOS years (e.g. 5 * 3 = 15).
Q04_OOS_MIN_TRADES_PER_YEAR = 5
Q04_LOWFREQ_MIN_ACTIVE_YEARS = 2
INVALID_SUMMARY_REASON_CLASSES = {
    "NO_HISTORY",
    "NO_HISTORY_LOG",
    "NO_REAL_TICKS",
    "REPORT_MISSING",
    "REPORT_PARSE_ERROR",
    "REPORT_FORMAT_DRIFT",
    "INVALID_REPORT",
    "INCOMPLETE_RUNS",
    "ONINIT_FAILED",
    "BARS_ZERO",
    "HISTORY_CONTEXT_INVALID",
    "TIMEOUT",
    "ACCOUNT_NOT_SPECIFIED",
}
INVALID_REPORT_MARKERS = {
    "EMPTY_EXPERT",
    "EMPTY_SYMBOL",
    "M0_1970_PERIOD",
    "BARS_ZERO",
    "HISTORY_CONTEXT_INVALID",
    "REPORT_METRIC_MISSING:EXPERT",
    "REPORT_METRIC_MISSING:PERIOD",
    "REPORT_METRIC_MISSING:BARS",
    "ONINIT_FAILED",
}

# Anchored expanding-window fold geometry. 2025 is the latest closed year
# (per OWNER 2026-05-23). New full folds auto-add when a new year closes —
# this list is the source of truth for *available* folds today.
FOLDS = [
    {"id": "F1", "dev_start": "2017-01-01", "dev_end": "2022-12-31",
     "oos_start": "2023-01-01", "oos_end": "2023-12-31"},
    {"id": "F2", "dev_start": "2017-01-01", "dev_end": "2023-12-31",
     "oos_start": "2024-01-01", "oos_end": "2024-12-31"},
    {"id": "F3", "dev_start": "2017-01-01", "dev_end": "2024-12-31",
     "oos_start": "2025-01-01", "oos_end": "2025-12-31"},
]


def sha256_file(path: Path) -> str | None:
    try:
        digest = hashlib.sha256()
        with Path(path).open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError:
        return None


def _safe_path_component(value: str, fallback: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(value or "").strip()).strip("._")
    return cleaned or fallback


def q04_evidence_leaf(symbol: str, evidence_key: str) -> str:
    """Unique one-level Q04 leaf compatible with the existing aggregate ingester."""
    return (
        f"{_safe_path_component(symbol, 'UNKNOWN_SYMBOL')}"
        f"__{_safe_path_component(evidence_key, 'UNKNOWN_EVIDENCE')}"
    )


def _write_json_atomic(path: Path, data: dict) -> None:
    """Publish JSON atomically so a reader never observes a partial verdict."""
    ensure_dir(path.parent)
    temp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    try:
        with temp.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(data, handle, indent=2, sort_keys=True)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp, path)
    finally:
        try:
            if temp.exists():
                temp.unlink()
        except OSError:
            pass


def _resolved_ex5(repo_root: Path, ea_expert: str) -> Path | None:
    expert_leaf = re.split(r"[\\/]+", str(ea_expert or "").strip())[-1]
    if not expert_leaf or expert_leaf in {".", ".."}:
        return None
    candidate = Path(repo_root) / "framework" / "EAs" / expert_leaf / f"{expert_leaf}.ex5"
    try:
        return candidate.resolve() if candidate.is_file() and candidate.stat().st_size > 0 else None
    except OSError:
        return None


def _basket_history_symbols(setfile: Path, runner_symbol: str) -> list[str]:
    symbols = [str(runner_symbol).strip()]
    manifest = None
    for candidate in (
        Path(setfile).parent / "basket_manifest.json",
        Path(setfile).parent.parent / "basket_manifest.json",
    ):
        try:
            if candidate.is_file():
                loaded = json.loads(candidate.read_text(encoding="utf-8-sig"))
                if isinstance(loaded, dict):
                    manifest = loaded
                    break
        except (OSError, json.JSONDecodeError):
            continue
    if manifest:
        host = str(manifest.get("host_symbol") or "").strip()
        if host and not host.startswith("_"):
            symbols.append(host)
        basket = manifest.get("basket_symbols")
        if isinstance(basket, list):
            symbols.extend(str(value).strip() for value in basket)
    unique: list[str] = []
    seen: set[str] = set()
    for symbol in symbols:
        key = symbol.casefold()
        if not symbol or key in seen:
            continue
        seen.add(key)
        unique.append(symbol)
    return unique


def _fold_preflight(
    *,
    repo_root: Path,
    mt5_root: Path,
    terminal: str,
    ea_expert: str,
    setfile: Path,
    symbol: str,
    fold: dict,
) -> tuple[str | None, dict]:
    """Read-only preflight for the exact binary and OOS source-history years."""
    source_set = Path(setfile)
    try:
        if not source_set.is_file() or source_set.stat().st_size <= 0:
            return "SETFILE_NOT_RESOLVED", {"setfile_path": str(source_set)}
    except OSError:
        return "SETFILE_NOT_RESOLVED", {"setfile_path": str(source_set)}

    ex5 = _resolved_ex5(repo_root, ea_expert)
    if ex5 is None:
        expert_leaf = re.split(r"[\\/]+", str(ea_expert or "").strip())[-1]
        return "EX5_NOT_RESOLVED", {
            "ea_expert": ea_expert,
            "expected_ex5_path": str(
                Path(repo_root)
                / "framework"
                / "EAs"
                / expert_leaf
                / f"{expert_leaf}.ex5"
            ),
        }

    first_year = int(str(fold["oos_start"])[:4])
    last_year = int(str(fold["oos_end"])[:4])
    history_paths: list[str] = []
    missing: list[str] = []
    for history_symbol in _basket_history_symbols(source_set, symbol):
        for year in range(first_year, last_year + 1):
            hcc = (
                Path(mt5_root)
                / str(terminal)
                / "Bases"
                / "Custom"
                / "history"
                / history_symbol
                / f"{year}.hcc"
            )
            try:
                if not hcc.is_file() or hcc.stat().st_size <= 0:
                    missing.append(str(hcc))
                else:
                    history_paths.append(str(hcc))
            except OSError:
                missing.append(str(hcc))
    evidence = {
        "ex5_path": str(ex5),
        "ex5_sha256": sha256_file(ex5),
        "setfile_path": str(source_set.resolve()),
        "setfile_sha256": sha256_file(source_set),
        "history_paths": history_paths,
        "history_years": [first_year, last_year],
        "history_symbols": _basket_history_symbols(source_set, symbol),
    }
    if missing:
        evidence["missing_history_paths"] = missing
        return "OOS_HISTORY_NOT_WARM", evidence
    return None, evidence


def folds_for_year(latest_full_year: int = 2025) -> list[dict]:
    """Return the list of available anchored folds given the latest closed
    calendar year. Folds with OOS years > latest are excluded."""
    out: list[dict] = []
    for fold in FOLDS:
        oos_year = int(fold["oos_end"][:4])
        if oos_year <= latest_full_year:
            out.append(fold)
    return out


def parse_pf_from_report_summary(summary_path: Path) -> tuple[float | None, int]:
    """Return (PF-net, trades) from a Q04 fold MT5 summary.json."""
    if not summary_path.exists():
        return None, 0
    try:
        sj = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None, 0
    runs = sj.get("runs") or []
    if not runs:
        return None, 0
    r0 = runs[-1]
    try:
        pf_net = float(r0.get("profit_factor") or 0) or None
        trades = int(r0.get("total_trades") or 0)
    except (TypeError, ValueError):
        return None, 0
    return pf_net, trades


def guard_pf_net_against_report_summary(
    *,
    pf_net: float | None,
    trades: int,
    commission_basis: str,
    report_pf: float | None,
    report_trades: int,
) -> tuple[float | None, int, str, str | None]:
    """Keep Q04's stream/self-report PF from contradicting native MT5 evidence.

    The preferred Q04 grading source is the per-trade stream because it lets the
    runner apply the shared worst-case commission model. A malformed or partial
    stream is still worse than the native report: it can miss closing deals and
    falsely inflate PF. When that happens, fall back to the MT5 summary metrics
    and carry an explicit guard reason in the aggregate.
    """
    if pf_net is None or report_pf is None or report_trades <= 0:
        return pf_net, trades, commission_basis, None

    reasons: list[str] = []
    if trades and trades != report_trades:
        reasons.append(f"trade_count_mismatch:stream={trades},report={report_trades}")

    # Net-of-cost PF should not materially exceed the native report PF. A small
    # tolerance covers rounding and the case where the shared commission model is
    # marginally cheaper than tester-side commission on a symbol.
    allowed_pf = max(report_pf + 0.05, report_pf * 1.25)
    if pf_net > allowed_pf:
        reasons.append(f"pf_contradicts_report:stream={pf_net:.3f},report={report_pf:.3f}")

    if not reasons:
        return pf_net, trades, commission_basis, None

    return report_pf, report_trades, "native_report_guard_fallback", ";".join(reasons)


def _load_summary(summary_path: Path) -> dict | None:
    if not summary_path.exists():
        return None
    try:
        return json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None


def summary_invalid_reason(summary_path: Path) -> str | None:
    """Return infra/data invalidation markers from a run_smoke fold summary.

    A Q04 fold can produce a run_smoke failure summary even when the real MT5
    report was never exported. That is retryable infrastructure evidence, not a
    completed zero-trade strategy fold. Conversely, run_smoke retains failed
    cold-cache attempts after a later valid report. Once an ``OK`` run exists,
    only that completed run and the authoritative top-level reason classes may
    invalidate the fold; stale retry markers must not override it.
    """
    sj = _load_summary(summary_path)
    if sj is None:
        return "summary_parse_error"
    runs = [run for run in (sj.get("runs") or []) if isinstance(run, dict)]
    if str(sj.get("result") or "").upper() == "PASS" and any(
        str(run.get("status") or "").upper() == "OK" for run in runs
    ):
        return None
    reasons = {str(r).upper() for r in (sj.get("reason_classes") or [])}
    completed = any(str(run.get("status") or "").upper() == "OK" for run in runs)
    markers: set[str] = set()
    for run in runs:
        status = str(run.get("status") or "").upper()
        if completed and status != "OK":
            continue
        if status == "INVALID":
            markers.add("RUN_STATUS_INVALID")
        for reason in run.get("invalid_report_reasons") or []:
            markers.add(str(reason).upper())
        if run.get("failure"):
            markers.add(str(run.get("failure")).upper())
    invalid = sorted((reasons & INVALID_SUMMARY_REASON_CLASSES) | (markers & INVALID_REPORT_MARKERS))
    if markers and "RUN_STATUS_INVALID" in markers:
        invalid.append("RUN_STATUS_INVALID")
    if invalid:
        return "invalid_summary:" + ",".join(dict.fromkeys(invalid))
    return None


def estimate_pf_gross(pf_net: float | None, trades: int, lots: float, commission_total: float | None) -> float | None:
    """Estimate PF-gross from PF-net by adding back per-trade commission.

    PF_net = wins_net / |losses_net|
           = (wins_gross - n_winning * c) / |losses_gross + n_losing * c|

    Without per-trade detail, the cleanest estimate is:
        gross_factor = (commission_total / |losses_gross_approx|) + 1
        PF_gross ≈ PF_net * gross_factor

    Since we don't have wins_gross / losses_gross separately, we report
    PF-net as primary and PF-gross as a coarse approximation. The Q04
    runner's job is to capture both for diagnostic clarity; the per-fold
    verdict is on PF-net.
    """
    if pf_net is None or trades <= 0 or commission_total is None or commission_total <= 0:
        return pf_net
    # Coarse: PF-gross is always >= PF-net since commission only depresses net.
    # Without losses-gross detail we cap the bump at a small adjustment.
    return round(pf_net * 1.05, 4) if pf_net > 0 else pf_net


def _common_files_dir() -> Path:
    return Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files")


def _q04_sim_result_path(ea_id: int, symbol: str) -> Path:
    return _common_files_dir() / "QM" / "q04_sim" / f"{ea_id}_{symbol.replace('.', '_')}.json"


def read_pf_net_from_ea(ea_id: int, symbol: str) -> tuple[float | None, int, float | None]:
    """PF-net the EA self-reported (net of InpQMSimCommissionPerLot), from the
    deterministic Common\\Files result file. The MT5 tester applies NO commission to
    custom .DWX symbols, so the report PF is gross; the EA emits the true PF-net here."""
    p = _q04_sim_result_path(ea_id, symbol)
    if not p.exists():
        return None, 0, None
    try:
        d = json.loads(p.read_text(encoding="utf-8-sig"))
        pf = d.get("pf_net")
        comm = d.get("sim_commission_total")
        pf = float(pf) if pf is not None else None
        trades = int(d.get("closed_deals") or 0)
        comm = float(comm) if comm is not None else None
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return None, 0, None
    return pf, trades, comm


def _basket_tester_overrides(setfile: Path) -> tuple[str | None, int | None]:
    """Return tester currency/deposit from the EA basket manifest, if present.

    Q04 copies the setfile into the report directory before launching run_smoke,
    so run_smoke's setfile-relative manifest fallback cannot see the original EA
    directory. Read it here from the source setfile path and pass explicit
    overrides to preserve basket-specific tester accounting.
    """
    manifest_path = Path(setfile).parent.parent / "basket_manifest.json"
    if not manifest_path.exists():
        return None, None
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return None, None

    currency_raw = str(manifest.get("tester_currency") or "").strip().upper()
    currency = currency_raw if re.fullmatch(r"[A-Z]{3}", currency_raw) else None

    deposit = None
    for key in ("tester_deposit", "tester_initial_deposit"):
        try:
            value = int(str(manifest.get(key) or "").strip())
        except ValueError:
            continue
        if value > 0:
            deposit = value
            break
    return currency, deposit


# ---------------------------------------------------------------------------
# DL-073 (OWNER-ratified 2026-06-09): realistic %-of-notional commission.
# Q04 historically charged a flat $7/lot round-trip EA-side — per-instrument WRONG
# (too harsh for FX majors ~$5, materially too lenient for high-notional index/gold).
# We now grade Q04 with the SAME instrument-correct model Q08 uses
# (tools/strategy_farm/portfolio/commission.py + framework/registry/live_commission.json:
#  cost_rt = max(pct_rate_rt × notional_acct, flat_per_lot_rt × volume)), applied POST-HOC
# to the per-trade stream the fold backtest already emits. No EA change, no MT5 re-run:
# every backtest writes TRADE_CLOSED rows (with notional + volume) to the q08_trades
# stream, so the realistic net P&L is recomputed in python. The flat-$7 EA self-report
# is kept only as a fallback when the stream is unavailable. Mirrors
# q08_davey.aggregate._apply_worst_case_commission so both gates share one cost model.
# ---------------------------------------------------------------------------
_COMMISSION_MODEL = None


def _commission_model():
    """Lazy-load the shared CommissionModel (live_commission.json class model).

    Retained for reference / any downstream import; the DL-082 §2 grading path uses the
    per-symbol VenueCostModel below."""
    global _COMMISSION_MODEL
    if _COMMISSION_MODEL is None:
        from tools.strategy_farm.portfolio import commission
        _COMMISSION_MODEL = commission.load_model()
    return _COMMISSION_MODEL


def _venue_model():
    """Lazy-load the per-symbol VenueCostModel (venue_cost_model.json, DL-082 §2)."""
    from framework.scripts.venue_costs import load_venue_model
    return load_venue_model()


def resolve_cost_variant(cli_value: str | None = None) -> str:
    """Pick the Q04 cost variant: CLI flag > QM_Q04_COST_VARIANT env > dxz default.

    dxz  = max(DXZ,FTMO) per-symbol worst-case (venue_cost_model.json) — gate default.
    ftmo = FTMO side incl. $0 indices / $0 energy.
    flat7 = legacy flat $7/lot round-trip (reproduction only)."""
    import os
    from framework.scripts.venue_costs import VALID_VARIANTS
    value = (cli_value or os.environ.get(COST_VARIANT_ENV) or DEFAULT_COST_VARIANT)
    value = str(value).strip().lower()
    if value not in VALID_VARIANTS:
        print(f"WARN q04: unknown --cost-variant {value!r}; using {DEFAULT_COST_VARIANT}",
              file=sys.stderr)
        return DEFAULT_COST_VARIANT
    return value


def _ea_side_sim_commission_per_lot(symbol: str, variant: str = DEFAULT_COST_VARIANT) -> float:
    """Per-SYMBOL flat commission for the EA-side InpQMSimCommissionPerLot injection.

    The fold backtest self-accounts this flat per-lot rate; it is the value the
    EA-side fallback verdict grades on when no per-trade stream exists (~45% of recent
    FX folds). DL-082 §2 (2026-07-19) replaces the per-CLASS flat (which mis-priced
    indices — WS30 charged $5.5 vs a real $0.70) with the per-SYMBOL venue figure for
    the active variant: dxz worst-case, ftmo side, or flat7. The primary grading path
    (pf_net_from_stream) applies the full %-notional model on the stream; this keeps
    the FALLBACK consistent with it. A symbol missing/null in the model falls back to
    the class-conservative value with a WARN (never a silent $0)."""
    try:
        return float(_venue_model().per_lot_rt(symbol, variant))
    except Exception:
        # venue model unavailable -> never-null hard fallback (legacy flat $7/lot).
        return float(COMMISSION_PER_LOT_ROUND_TRIP)


def _q08_trade_stream_path(ea_id: int, symbol: str) -> Path:
    return _common_files_dir() / "QM" / "q08_trades" / f"{ea_id}_{symbol.replace('.', '_')}.jsonl"


def _gross_before_commission(trade: dict) -> float:
    """gross P&L of a trade before any commission (mirrors
    q08_davey.aggregate._gross_before_commission). The MT5 tester applies $0 commission to
    .DWX custom symbols, so `profit` is already gross of cost; add swap."""
    try:
        profit = trade.get("profit")
        swap = float(trade.get("swap") or 0.0)
        if profit is not None:
            return float(profit) + swap
        net = float(trade.get("net") or 0.0)
        bc = trade.get("commission")
        return net - float(bc) if bc is not None else net
    except (TypeError, ValueError):
        return 0.0


def pf_net_from_stream(ea_id: int, symbol: str, fold: dict,
                       variant: str = DEFAULT_COST_VARIANT,
                       model=None) -> tuple[float | None, int, float | None, float | None, list[float]]:
    """DL-073/DL-082 grading source: PF-net under the per-symbol venue commission model,
    computed post-hoc from the per-trade stream the fold backtest just emitted.

    `variant` selects the cost input (dxz worst-case default | ftmo | flat7); the
    thresholds and windowing are unchanged. Returns (pf_net, n_trades, commission_total,
    gross_total, nets) where `nets` is the list of realistic-net per-trade P&L inside the
    fold's OOS window (used by the DL-076 low-freq pooled verdict). Returns
    (None, 0, None, None, []) when no usable stream exists (caller falls back to the EA's
    per-symbol-flat self-report).
    """
    from framework.scripts.q08_davey import common as q08common
    model = model or _venue_model()
    trades = q08common.load_trades_from_log(_q08_trade_stream_path(ea_id, symbol))
    if not trades:
        return None, 0, None, None, []
    # Defensive OOS windowing: a fold backtest only runs its OOS year, but a stale stream
    # could carry other dates. Keep trades whose close ts is inside [oos_start, oos_end].
    oos_start = dt.datetime.fromisoformat(fold["oos_start"]).replace(tzinfo=dt.timezone.utc)
    oos_end = (dt.datetime.fromisoformat(fold["oos_end"]).replace(tzinfo=dt.timezone.utc)
               + dt.timedelta(days=1))
    nets: list[float] = []
    cost_total = 0.0
    gross_total = 0.0
    for t in trades:
        ts = q08common.trade_timestamp(t)
        if ts is not None and not (oos_start <= ts < oos_end):
            continue
        vol = float(t.get("volume") or 0.0)
        notional = t.get("notional")
        notional = float(notional) if notional not in (None, "") else None
        cost = model.cost_round_trip(str(t.get("symbol") or symbol), vol, notional, variant)
        gross = _gross_before_commission(t)
        nets.append(gross - cost)
        cost_total += cost
        gross_total += gross
    if not nets:
        return None, 0, None, None, []
    pf = q08common.profit_factor(nets)
    if pf == float("inf"):      # no losing trades after cost → cap for a finite verdict
        pf = 999.0
    return pf, len(nets), round(cost_total, 4), round(gross_total, 4), nets


def resolve_ea_expert_path(repo_root: Path, ea_label: str) -> str | None:
    """Canonical MT5 expert path 'QM\\<ea_dir>' for run_smoke / the tester (run_smoke
    deploys framework/EAs/<dir>/<dir>.ex5 to Experts/QM/<dir>.ex5). Bare labels do NOT
    resolve — that was the Q04 expert-path bug."""
    eas = repo_root / "framework" / "EAs"
    matches = sorted(p for p in eas.glob(f"{ea_label}_*") if p.is_dir())
    if not matches and (eas / ea_label).is_dir():
        matches = [eas / ea_label]
    return f"QM\\{matches[0].name}" if matches else None


def period_from_setfile(setfile: Path, default: str = "H1") -> str:
    """Resolve the tester period from any canonical set-file suffix.

    Q04 also accepts diagnostic/locked sets such as ``*_M15_native_parity.set``;
    limiting inference to ``*_M15_backtest.set`` silently launched those EAs on
    the H1 fallback.
    """
    m = re.search(
        r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)(?:_|\.|$)",
        Path(setfile).name,
    )
    return m.group(1) if m else default


def aggregate_verdict(fold_results: list[dict]) -> tuple[str, str]:
    """Verdict over the OOS folds (DL-071, OWNER-ratified 2026-06-09):
      - PASS       : EVERY fold has PF-net > floor (clean, the gold standard).
      - PASS_SOFT  : a profitable MAJORITY of folds (>= Q04_SOFT_MIN_POS_FRACTION),
                     mean PF-net > Q04_SOFT_MEAN_FLOOR, and NO catastrophic fold
                     (every fold's PF-net >= Q04_SOFT_MIN_FOLD_FLOOR; a no-trade
                     fold counts as 0.0 → fails this guard). Net-positive-with-
                     controlled-variance — advances like a Q08 soft-pass.
      - FAIL       : otherwise.
    A no-trade / missing fold is treated as PF-net 0.0 for the soft test, so it can
    never soft-pass on a fold that did not trade.
    """
    if not fold_results:
        return "INVALID", "no_folds_ran"
    incomplete = [
        f for f in fold_results
        if not f.get("summary_path") or f.get("invalid_reason")
    ]
    if incomplete:
        return "INVALID", ";".join(
            f"{f['id']}:{f.get('invalid_reason') or 'incomplete_fold'}"
            for f in incomplete
        )
    failures = [f for f in fold_results if f.get("pf_net") is None or
                                            float(f["pf_net"]) <= PF_NET_FLOOR_PER_FOLD]
    detail = ";".join(
        f"{f['id']}:pf_net={f['pf_net']:.3f}" if f.get("pf_net") is not None
        else f"{f['id']}:trades={f.get('trades', 0)}"
        for f in fold_results
    )
    if not failures:
        return "PASS", detail
    # PASS_SOFT check: net-positive with controlled variance.
    n = len(fold_results)
    pfs = [float(f["pf_net"]) if f.get("pf_net") is not None else 0.0 for f in fold_results]
    n_pos = sum(1 for p in pfs if p > PF_NET_FLOOR_PER_FOLD)
    mean_pf = sum(pfs) / n
    min_pf = min(pfs)
    import math
    need_pos = math.ceil(Q04_SOFT_MIN_POS_FRACTION * n)
    if (n_pos >= need_pos and mean_pf > Q04_SOFT_MEAN_FLOOR
            and min_pf >= Q04_SOFT_MIN_FOLD_FLOOR):
        return "PASS_SOFT", (f"soft:{n_pos}/{n}>floor,mean={mean_pf:.3f},"
                             f"min={min_pf:.3f};{detail}")
    return "FAIL", detail


def is_lowfreq_eligible(strict_folds: list[dict]) -> bool:
    """DL-076: True iff every strict fold completed AND the average OOS trades/yr is below
    the low-freq threshold. Completed folds are required so the trade counts (and thus the
    frequency classification) are trustworthy — an incomplete/INFRA fold must be re-run,
    not reclassified as low-freq."""
    if not strict_folds:
        return False
    if any(not f.get("summary_path") or f.get("invalid_reason") for f in strict_folds):
        return False
    total = sum(int(f.get("trades") or 0) for f in strict_folds)
    return total < Q04_LOWFREQ_MAX_TRADES_PER_YEAR * len(strict_folds)


def aggregate_verdict_lowfreq(strict_folds: list[dict]) -> tuple[str, str]:
    """DL-076 pooled low-freq verdict. The pooled stream is the concatenation of the strict
    folds' realistic-net per-trade P&L (oos_nets) — mathematically identical to one pooled
    OOS backtest under the same DL-073 cost model, with no extra MT5 run. Same PF-net > 1.0
    bar as the strict gate; only the windowing differs.

      PASS_LOWFREQ : pooled PF-net > floor, >= MIN_POOLED_TRADES pooled trades, and trades
                     in >= MIN_ACTIVE_YEARS of the OOS years (no single-year wonder).
      INVALID      : too few pooled trades to compute a meaningful PF, or no per-trade
                     stream available (a flat-$7 fallback fold cannot be pooled).
      FAIL         : single-year wonder, or pooled PF-net <= floor.
    """
    from framework.scripts.q08_davey import common as q08common
    if any(f.get("oos_nets") is None for f in strict_folds) or \
            any(not f.get("summary_path") or f.get("invalid_reason") for f in strict_folds):
        return "INVALID", "lowfreq_no_pooled_stream"
    pooled_nets: list[float] = []
    for f in strict_folds:
        pooled_nets.extend(float(x) for x in (f.get("oos_nets") or []))
    n_trades = len(pooled_nets)
    active_years = sum(1 for f in strict_folds if int(f.get("trades") or 0) > 0)
    # OWNER 2026-06-26: require >= 5 trades/yr sustained on the pooled OOS window.
    min_pooled = Q04_OOS_MIN_TRADES_PER_YEAR * len(strict_folds)
    if n_trades < min_pooled:
        return "INVALID", (f"lowfreq_insufficient_pooled_trades:"
                           f"{n_trades}<{min_pooled}(>={Q04_OOS_MIN_TRADES_PER_YEAR}/yr)")
    pf = q08common.profit_factor(pooled_nets)
    if pf == float("inf"):       # no losing trades after cost → cap for a finite verdict
        pf = 999.0
    detail = (f"pool:pf_net={pf:.3f},pooled_trades={n_trades},"
              f"active_years={active_years}/{len(strict_folds)}")
    if active_years < Q04_LOWFREQ_MIN_ACTIVE_YEARS:
        return "FAIL", f"lowfreq_single_year_wonder;{detail}"
    if pf > PF_NET_FLOOR_PER_FOLD:
        return "PASS_LOWFREQ", f"lowfreq_pooled_pass;{detail}"
    return "FAIL", f"lowfreq_pooled_pf_below_floor;{detail}"


def exit_code_for_verdict(verdict: str) -> int:
    if verdict in ("PASS", "PASS_SOFT", "PASS_LOWFREQ"):
        return 0
    if verdict == "FAIL":
        return 1
    return 3


def _mt5_date(iso_date: str) -> str:
    return iso_date.replace("-", ".")


def _summary_from_log(log_path: Path) -> Path | None:
    try:
        lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()
        for line in reversed(lines):
            if line.startswith("run_smoke.summary="):
                candidate = Path(line.partition("=")[2].strip())
                if candidate.exists():
                    return candidate
    except OSError:
        return None
    return None


def _run_smoke_report_identity(summary_path: Path | None) -> dict:
    if summary_path is None or not summary_path.is_file():
        return {}
    summary = _load_summary(summary_path)
    if not isinstance(summary, dict):
        return {}
    runs = [row for row in (summary.get("runs") or []) if isinstance(row, dict)]
    selected = next(
        (row for row in reversed(runs) if str(row.get("status") or "").upper() == "OK"),
        runs[-1] if runs else None,
    )
    evidence = {
        "source_summary_path": str(summary_path),
        "source_summary_sha256": sha256_file(summary_path),
    }
    if selected:
        report_raw = selected.get("report_canonical_path") or selected.get("report_source_path")
        if report_raw:
            report_path = Path(str(report_raw))
            evidence["source_report_path"] = str(report_path)
            evidence["source_report_sha256"] = (
                str(selected.get("report_sha256"))
                if selected.get("report_sha256")
                else sha256_file(report_path)
            )
    return evidence


def _write_fold_summary(evidence_dir: Path, result: dict) -> dict:
    """Write the deterministic, classifiable record for every fold outcome."""
    summary_path = Path(evidence_dir) / "folds" / str(result["id"]) / "summary.json"
    result["summary_path"] = str(summary_path)
    durable = {
        "evidence_schema": "q04_fold/v2",
        "phase": GATE_NAME,
        **{key: value for key, value in result.items() if key != "oos_nets"},
    }
    _write_json_atomic(summary_path, durable)
    return result


def _fold_failure(
    *,
    evidence_dir: Path,
    fold: dict,
    reason: str,
    log_path: Path,
    preflight: dict | None = None,
    exit_code: int | None = None,
) -> dict:
    return _write_fold_summary(
        evidence_dir,
        {
            **fold,
            "pf_net": None,
            "trades": 0,
            "sim_commission_total": None,
            "gross_total": None,
            "commission_basis": None,
            "report_pf": None,
            "report_trades": 0,
            "report_guard_reason": None,
            "oos_nets": [],
            "status": "INVALID",
            "verdict_reason": reason,
            "invalid_reason": reason,
            "exit_code": exit_code,
            "log_path": str(log_path),
            "preflight": preflight or {},
        },
    )


def run_fold_via_smoke(*, ea_id: int, ea_expert: str, symbol: str,
                        setfile: Path, fold: dict, report_root: Path,
                        terminal: str, period: str, timeout_sec: int = 1800,
                        cost_variant: str = DEFAULT_COST_VARIANT,
                        scratch_root: Path | None = None,
                        evidence_dir: Path | None = None,
                        repo_root: Path | None = None,
                        mt5_root: Path = Path("D:/QM/mt5")) -> dict:
    """Invoke run_smoke for one OOS fold and always publish its durable summary.

    ``report_root`` is the durable evidence root. Tester reports, logs, and the
    injected setfile stay below ``scratch_root`` (the work-item directory in
    factory dispatch). The read-only binary/history preflight runs before every
    fold and never imports or mutates custom-symbol history.
    """
    import subprocess

    oos_year = int(fold["oos_end"][:4])
    run_id = f"q04_{fold['id']}_{oos_year}"
    actual_repo_root = Path(repo_root) if repo_root is not None else Path(__file__).resolve().parents[2]
    durable_dir = (
        Path(evidence_dir)
        if evidence_dir is not None
        else Path(report_root) / f"QM5_{ea_id}" / "Q04" / _safe_path_component(symbol, "UNKNOWN_SYMBOL")
    )
    scratch = Path(scratch_root) if scratch_root is not None else Path(report_root)
    fold_dir = (
        scratch
        / f"QM5_{ea_id}"
        / "Q04"
        / _safe_path_component(durable_dir.name, "evidence")
        / str(fold["id"])
    )
    fold_dir.mkdir(parents=True, exist_ok=True)
    log_path = fold_dir / "run_smoke.log"

    preflight_reason, preflight = _fold_preflight(
        repo_root=actual_repo_root,
        mt5_root=Path(mt5_root),
        terminal=terminal,
        ea_expert=ea_expert,
        setfile=Path(setfile),
        symbol=symbol,
        fold=fold,
    )
    if preflight_reason:
        return _fold_failure(
            evidence_dir=durable_dir,
            fold=fold,
            reason=preflight_reason,
            log_path=log_path,
            preflight=preflight,
        )

    try:
        run_smoke_ps1 = actual_repo_root / "framework" / "scripts" / "run_smoke.ps1"
        # Inject the EA-side simulated commission into a scratch-local copy.
        fold_set = fold_dir / f"{Path(setfile).stem}_q04comm.set"
        base_text = Path(setfile).read_text(encoding="utf-8", errors="ignore")
        sim_comm_per_lot = _ea_side_sim_commission_per_lot(symbol, cost_variant)
        if "InpQMSimCommissionPerLot" not in base_text:
            base_text = (
                base_text.rstrip("\r\n")
                + f"\r\nInpQMSimCommissionPerLot={sim_comm_per_lot}\r\n"
            )
        fold_set.write_text(base_text, encoding="utf-8")
        tester_currency, tester_deposit = _basket_tester_overrides(Path(setfile))

        # Clear only the fold's volatile Common outputs. No .DWX history import
        # or history mutation is performed by this runner.
        for stale in (
            _q04_sim_result_path(ea_id, symbol),
            _q08_trade_stream_path(ea_id, symbol),
        ):
            try:
                if stale.exists():
                    stale.unlink()
            except OSError:
                pass

        args = [
            "pwsh.exe", "-NoProfile", "-File", str(run_smoke_ps1),
            "-EAId", str(ea_id),
            "-Expert", ea_expert,
            "-Symbol", symbol,
            "-Year", str(oos_year),
            "-Terminal", terminal,
            "-Period", period,
            "-DispatchSubGateHash", run_id,
            "-DispatchPhase", "Q04",
            "-DispatchVersion", "q04_walkforward",
            "-Runs", "1",
            "-MinTrades", "5",
            "-Model", "4",
            "-SetFile", str(fold_set),
            "-ReportRoot", str(scratch),
            "-TimeoutSeconds", str(timeout_sec),
            "-FromDate", _mt5_date(fold["oos_start"]),
            "-ToDate", _mt5_date(fold["oos_end"]),
            "-AllowRunningTerminal",
            "-AllowMissingRealTicksLogMarker",
        ]
        if tester_currency:
            args.extend(["-TesterCurrencyOverride", tester_currency])
        if tester_deposit:
            args.extend(["-TesterDepositOverride", str(tester_deposit)])
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        try:
            with log_path.open("w", encoding="utf-8") as log:
                proc = run_with_launch_fault_retry(
                    args,
                    runner=subprocess.run,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    text=True,
                    timeout=timeout_sec,
                    creationflags=creationflags,
                )
        except subprocess.TimeoutExpired:
            return _fold_failure(
                evidence_dir=durable_dir,
                fold=fold,
                reason="FOLD_TIMEOUT",
                log_path=log_path,
                preflight=preflight,
            )
        except OSError:
            return _fold_failure(
                evidence_dir=durable_dir,
                fold=fold,
                reason="RUN_SMOKE_LAUNCH_ERROR",
                log_path=log_path,
                preflight=preflight,
            )

        source_summary = _summary_from_log(log_path)
        if source_summary is None:
            legacy = scratch / f"QM5_{ea_id}" / "Q04" / str(fold["id"]) / "summary.json"
            source_summary = legacy if legacy.is_file() else None
        if source_summary is None:
            return _fold_failure(
                evidence_dir=durable_dir,
                fold=fold,
                reason="SOURCE_SUMMARY_MISSING",
                log_path=log_path,
                preflight=preflight,
                exit_code=proc.returncode,
            )

        invalid_reason = summary_invalid_reason(source_summary)
        report_pf, report_trades = parse_pf_from_report_summary(source_summary)

        # Grade from the per-symbol venue model applied to the emitted stream,
        # falling back to the EA self-report only when no usable stream exists.
        pf_net, trades, comm_total, gross_total, oos_nets = pf_net_from_stream(
            ea_id, symbol, fold, cost_variant
        )
        commission_basis = f"venue_{cost_variant}_stream"
        if pf_net is None:
            pf_net, trades, comm_total = read_pf_net_from_ea(ea_id, symbol)
            gross_total = None
            oos_nets = []
            commission_basis = f"venue_{cost_variant}_ea_side_flat"

        pf_net, trades, commission_basis, report_guard_reason = (
            guard_pf_net_against_report_summary(
                pf_net=pf_net,
                trades=trades,
                commission_basis=commission_basis,
                report_pf=report_pf,
                report_trades=report_trades,
            )
        )
        if report_guard_reason:
            comm_total = None
            gross_total = None
            oos_nets = []
        if not invalid_reason and pf_net is None and (report_trades or 0) > 0:
            invalid_reason = "stream_and_selfreport_missing"

        status = (
            "INVALID"
            if invalid_reason
            else ("OK" if (pf_net is not None and proc.returncode == 0) else "FAIL")
        )
        if invalid_reason:
            verdict_reason = invalid_reason
        elif pf_net is None or trades <= 0:
            verdict_reason = "STRATEGY_ZERO_TRADES"
        elif proc.returncode != 0:
            verdict_reason = "STRATEGY_MIN_TRADES_NOT_MET"
        elif pf_net <= PF_NET_FLOOR_PER_FOLD:
            verdict_reason = "STRATEGY_PF_AT_OR_BELOW_FLOOR"
        else:
            verdict_reason = "FOLD_COMPLETE"
        result = {
            **fold,
            "pf_net": pf_net,
            "trades": trades,
            "sim_commission_total": comm_total,
            "gross_total": gross_total,
            "cost_variant": cost_variant,
            "commission_per_lot_used": sim_comm_per_lot,
            "commission_basis": commission_basis,
            "report_pf": report_pf,
            "report_trades": report_trades,
            "report_guard_reason": report_guard_reason,
            "oos_nets": oos_nets,
            "status": status,
            "verdict_reason": verdict_reason,
            "invalid_reason": invalid_reason,
            "exit_code": proc.returncode,
            "log_path": str(log_path),
            "preflight": preflight,
            **_run_smoke_report_identity(source_summary),
        }
        return _write_fold_summary(durable_dir, result)
    except Exception as exc:
        return _fold_failure(
            evidence_dir=durable_dir,
            fold=fold,
            reason=f"FOLD_ERROR_{type(exc).__name__.upper()}",
            log_path=log_path,
            preflight=preflight,
        )


def main() -> int:
    ap = argparse.ArgumentParser(description="Q04 walk-forward + commission runner")
    ap.add_argument("--ea", required=True, help="EA label, e.g. QM5_1056")
    ap.add_argument("--symbol", required=True, help="e.g. NDX.DWX")
    ap.add_argument("--logical-symbol",
                    help="Basket evidence symbol to record when --symbol is the MT5 host")
    ap.add_argument("--setfile", type=Path, required=True,
                    help="Q03 plateau-median setfile to use across all folds")
    ap.add_argument("--period", choices=("M1", "M5", "M15", "M30", "H1", "H4", "H6", "H8", "D1", "W1", "MN1"),
                    help="Explicit tester period; otherwise inferred from the set-file name")
    ap.add_argument("--expert",
                    help="Optional pre-deployed MT5 expert path override, e.g. QM\\QM5_10377_locked")
    ap.add_argument("--terminal", default="T2", help="MT5 terminal (T1-T10)")
    ap.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/pipeline"),
                    help="Durable aggregate/fold-summary root")
    ap.add_argument("--out-prefix", type=Path, help=argparse.SUPPRESS)
    ap.add_argument("--scratch-root", type=Path,
                    help="Volatile tester/report workspace (defaults to --report-root)")
    ap.add_argument("--evidence-key",
                    help="Immutable work-item identity used to isolate the durable Q04 leaf")
    ap.add_argument("--latest-full-year", type=int, default=2025,
                    help="Last closed calendar year (excludes folds past this)")
    ap.add_argument("--timeout-sec", type=int, default=1800)
    ap.add_argument("--cost-variant", choices=("dxz", "ftmo", "flat7"), default=None,
                    help=("Cost input (DL-082 §2): dxz worst-case [default] | ftmo | "
                          f"flat7 legacy. If omitted, uses ${COST_VARIANT_ENV} env or dxz."))
    args = ap.parse_args()
    cost_variant = resolve_cost_variant(args.cost_variant)

    ea_match = re.match(r"QM5_(\d+)_?", args.ea)
    if not ea_match:
        print(f"bad EA label: {args.ea}", file=sys.stderr)
        return 2
    ea_id = int(ea_match.group(1))

    repo_root = Path(__file__).resolve().parents[2]
    ea_expert = args.expert or resolve_ea_expert_path(repo_root, args.ea)
    if ea_expert is None:
        ea_expert = ""
        print(
            f"cannot resolve EA dir for {args.ea} under framework/EAs; "
            "publishing classifiable fold failures",
            file=sys.stderr,
        )
    period = args.period or period_from_setfile(args.setfile)
    runner_symbol = args.symbol
    evidence_symbol = args.logical_symbol or args.symbol
    setfile_sha256 = sha256_file(args.setfile)
    evidence_key = args.evidence_key or f"set_{(setfile_sha256 or 'missing')[:16]}"
    evidence_leaf = q04_evidence_leaf(evidence_symbol, evidence_key)
    out_dir = ensure_dir(
        args.report_root / f"QM5_{ea_id}" / "Q04" / evidence_leaf
    )
    scratch_root = args.scratch_root or args.report_root

    folds = folds_for_year(args.latest_full_year)
    label = evidence_symbol if evidence_symbol == runner_symbol else f"{evidence_symbol} via {runner_symbol}"
    try:
        venue = _venue_model()
        per_lot_used = venue.per_lot_rt(runner_symbol, cost_variant)
        cost_source = venue.source_tag()
    except Exception:
        per_lot_used = COMMISSION_PER_LOT_ROUND_TRIP
        cost_source = "venue_cost_model_unavailable:flat7_hard_fallback"
    print(f"Q04 {args.ea} {label} {period}  expert={ea_expert}  folds={[f['id'] for f in folds]}  "
          f"cost-variant={cost_variant} ({cost_source}; {runner_symbol} "
          f"${per_lot_used:.2f}/lot headline; DL-082 §2)")

    fold_results: list[dict] = []
    for fold in folds:
        print(f"  fold {fold['id']}: OOS {fold['oos_start']} -> {fold['oos_end']} ...")
        res = run_fold_via_smoke(
            ea_id=ea_id, ea_expert=ea_expert, symbol=runner_symbol,
            setfile=args.setfile, fold=fold,
            report_root=args.report_root, terminal=args.terminal,
            period=period, timeout_sec=args.timeout_sec,
            cost_variant=cost_variant,
            scratch_root=scratch_root,
            evidence_dir=out_dir,
            repo_root=repo_root,
        )
        pf_str = f"{res['pf_net']:.3f}" if res.get("pf_net") is not None else "n/a"
        print(f"    -> PF-net={pf_str}  trades={res['trades']}  status={res['status']}")
        fold_results.append(res)

    verdict, reason = aggregate_verdict(fold_results)

    # DL-076: low-freq pooled rescue. Only when the strict gate FAILed with every fold
    # completed and the EA is genuinely low-frequency. Pools the strict folds' realistic-net
    # per-trade streams (no extra backtest) and re-judges on the SAME PF-net > 1.0 bar.
    lowfreq_verdict = lowfreq_reason = None
    if verdict == "FAIL" and is_lowfreq_eligible(fold_results):
        total_oos = sum(int(f.get("trades") or 0) for f in fold_results)
        lowfreq_verdict, lowfreq_reason = aggregate_verdict_lowfreq(fold_results)
        print(f"  low-freq EA ({total_oos} OOS trades / {len(folds)}yr) "
              f"→ pooled verdict={lowfreq_verdict} ({lowfreq_reason})")
        if lowfreq_verdict == "PASS_LOWFREQ":
            verdict, reason = lowfreq_verdict, lowfreq_reason
        else:
            reason = f"{reason} || lowfreq:{lowfreq_verdict}:{lowfreq_reason}"

    # DL-082 §2: report the basis actually used across folds (venue stream model unless a
    # fold had to fall back to the per-symbol EA-side flat self-report).
    bases = sorted({f.get("commission_basis") for f in fold_results if f.get("commission_basis")})
    first_preflight = next(
        (
            f.get("preflight")
            for f in fold_results
            if isinstance(f.get("preflight"), dict) and f.get("preflight")
        ),
        {},
    )
    aggregate_path = out_dir / "aggregate.json"
    identity_payload = {
        "ea_id": ea_id,
        "evidence_key": evidence_key,
        "runner_symbol": runner_symbol,
        "setfile_sha256": setfile_sha256,
        "symbol": evidence_symbol,
    }
    aggregate_identity = hashlib.sha256(
        json.dumps(identity_payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()
    _write_json_atomic(aggregate_path, {
        "evidence_schema": "q04_aggregate/v2",
        "phase": GATE_NAME,
        "ea_id": ea_id,
        "ea": args.ea,
        "symbol": evidence_symbol,
        "runner_symbol": runner_symbol,
        "evidence_key": evidence_key,
        "evidence_leaf": evidence_leaf,
        "aggregate_identity_sha256": aggregate_identity,
        "setfile_path": str(args.setfile),
        "setfile_sha256": setfile_sha256,
        "ex5_path": first_preflight.get("ex5_path"),
        "ex5_sha256": first_preflight.get("ex5_sha256"),
        # DL-082 §2 evidence provenance (per run):
        "cost_variant": cost_variant,
        "commission_per_lot_used": per_lot_used,
        "source": cost_source,   # "venue_cost_model.json <generated ts>"
        "commission_model": f"venue_cost_model.json[{cost_variant}] (DL-082 §2)",
        "commission_basis": bases,
        "commission_per_lot_round_trip_fallback": COMMISSION_PER_LOT_ROUND_TRIP,
        "verdict": verdict,
        "reason": reason,
        "verdict_reason": reason,
        "lowfreq_verdict": lowfreq_verdict,       # DL-076: pooled tier outcome if attempted
        "lowfreq_reason": lowfreq_reason,
        "generated_at_utc": utc_now_iso(),
        "fold_count": len(fold_results),
        # Drop the in-memory per-trade `oos_nets` (only used for the pooled computation;
        # persisting it would balloon aggregate.json for high-frequency EAs).
        "folds": [{k: v for k, v in f.items() if k != "oos_nets"} for f in fold_results],
    })
    print(f"Q04 verdict for {args.ea} {label}: {verdict}")
    print(f"  reason: {reason}")
    print(f"  aggregate: {aggregate_path}")
    return exit_code_for_verdict(verdict)


if __name__ == "__main__":
    sys.exit(main())
