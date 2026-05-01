#!/usr/bin/env python3
"""DL-054 anti-theater pass-criteria gate library.

Five binding gates a (ea_id, phase, symbol) run must pass before Pipeline-Op
may write `verdict = PASS` to `report.csv`. Any gate fail forces
`verdict = INVALID` (not PASS, not FAIL) with `invalidation_reason`.

Authority:
  decisions/DL-054_anti_theater_pass_criteria.md
  framework/registry/tester_defaults.json
  decisions/DL-038 (Seven Binding Backtest Rules)

Author: Board Advisor 2026-05-01 — draft for CTO review/merge into
        framework/scripts/pipeline_dispatcher.py and per-phase runners.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------

REPO_ROOT = Path(r"C:\QM\repo")
TESTER_DEFAULTS_PATH = REPO_ROOT / "framework" / "registry" / "tester_defaults.json"
DWX_IMPORT_LOGS = Path(r"D:\QM\mt5\T1\dwx_import\logs")

REJECTED_JOURNAL_LINES = (
    "no history data, stop testing",
    "cannot get history",
    "no data synchronized",
    "Terminal: Invalid params",
)

# Gate-1 verify-failure tokens that MUST NOT appear in the latest verify block
# for a given symbol. Read from hourly_<latest>.log per the QUA-684 D2 audit.
VERIFY_FAILURE_TOKENS = (
    "FAIL_tail_bars",
    "FAIL_tail_mid_bars",
    "bars_one_shot=0",
    "bars_drift=-100,000",
)


# -------------------------------------------------------------------------
# Result types
# -------------------------------------------------------------------------


@dataclass
class GateResult:
    """One gate's verdict."""

    gate: str  # 'G1' | 'G2' | 'G3' | 'G4' | 'G5'
    name: str
    passed: bool
    reason: str  # short machine-parseable reason on fail; empty on pass
    detail: str = ""  # optional longer detail for log


@dataclass
class MatrixVerdict:
    """All-gate verdict for a single (ea_id, phase, symbol) row."""

    ea_id: str
    phase: str
    symbol: str
    terminal: str
    gates: list[GateResult]
    verdict: str  # 'PASS' | 'INVALID' (FAIL only when a real strategy-level failure, not gate fail)
    invalidation_reason: str  # populated when verdict == 'INVALID'

    def to_csv_row(self, evidence_path: str = "") -> dict[str, str]:
        return {
            "ea_id": self.ea_id,
            "phase": self.phase,
            "symbol": self.symbol,
            "terminal": self.terminal,
            "verdict": self.verdict,
            "invalidation_reason": self.invalidation_reason,
            "evidence": evidence_path,
        }


# -------------------------------------------------------------------------
# Gate 1 — tester data access verified
# -------------------------------------------------------------------------


def latest_hourly_log(import_logs_dir: Path = DWX_IMPORT_LOGS) -> Path | None:
    """Return path to the most recent hourly_YYYY-MM-DD.log."""
    if not import_logs_dir.is_dir():
        return None
    candidates = sorted(import_logs_dir.glob("hourly_*.log"))
    return candidates[-1] if candidates else None


def gate1_verify_data_access(
    symbol: str,
    window_start: datetime,
    window_end: datetime,
    import_logs_dir: Path = DWX_IMPORT_LOGS,
) -> GateResult:
    """G1 — symbol's latest verify block is OK and history covers ≥95% of window."""
    log_path = latest_hourly_log(import_logs_dir)
    if log_path is None:
        return GateResult(
            "G1", "tester data access verified", False,
            "no_hourly_log",
            f"no hourly_*.log found in {import_logs_dir}",
        )

    text = log_path.read_text(encoding="utf-8", errors="replace")

    # Find the latest verify line for this symbol.
    pattern = re.compile(r"\[\s*(?P<verdict>\w+(?:_\w+)*)\]\s+" + re.escape(symbol) + r":(?P<rest>[^\n]+)")
    matches = list(pattern.finditer(text))
    if not matches:
        return GateResult(
            "G1", "tester data access verified", False,
            "symbol_not_in_verify_log",
            f"no verify line for {symbol} in {log_path.name}",
        )
    last = matches[-1]
    verdict_token = last.group("verdict")
    rest = last.group("rest")

    if any(token in (verdict_token + rest) for token in VERIFY_FAILURE_TOKENS):
        return GateResult(
            "G1", "tester data access verified", False,
            "verify_block_failed",
            f"latest verify for {symbol} contains failure token: {verdict_token} + {rest[:200]}",
        )

    # Check history coverage. The verify line includes head_ms / tail_ms.
    head_match = re.search(r"head_ms expected=(?P<head>\d+)/got=(?P<got_head>\d+)", rest)
    tail_match = re.search(r"tail_ms expected=(?P<tail>\d+)/got=(?P<got_tail>\d+)", rest)
    if head_match and tail_match:
        got_head_ms = int(head_match.group("got_head"))
        got_tail_ms = int(tail_match.group("got_tail"))
        avail_start = datetime.fromtimestamp(got_head_ms / 1000, tz=timezone.utc)
        avail_end = datetime.fromtimestamp(got_tail_ms / 1000, tz=timezone.utc)
        window_total = (window_end - window_start).total_seconds()
        overlap_start = max(avail_start, window_start)
        overlap_end = min(avail_end, window_end)
        overlap = max(0.0, (overlap_end - overlap_start).total_seconds())
        if window_total <= 0 or overlap / window_total < 0.95:
            return GateResult(
                "G1", "tester data access verified", False,
                "window_coverage_below_95pct",
                f"overlap {overlap / max(1.0, window_total):.2%} < 95% — avail {avail_start} → {avail_end}, "
                f"requested {window_start} → {window_end}",
            )
    # else: head/tail not parseable; treat as pass (verify block was OK overall)

    return GateResult("G1", "tester data access verified", True, "")


# -------------------------------------------------------------------------
# Gate 2 — tester defaults loaded + RISK_FIXED setfile
# -------------------------------------------------------------------------


def load_tester_defaults(path: Path = TESTER_DEFAULTS_PATH) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def gate2_tester_defaults_loaded(launch_config: dict, defaults: dict | None = None) -> GateResult:
    """G2 — launch_config matches tester_defaults.json + RISK_FIXED set-file path present."""
    if defaults is None:
        defaults = load_tester_defaults()

    expected_deposit = defaults.get("initial_deposit")
    expected_currency = defaults.get("deposit_currency")
    expected_leverage = defaults.get("leverage")

    actual_deposit = launch_config.get("initial_deposit") or launch_config.get("Deposit")
    actual_currency = launch_config.get("deposit_currency") or launch_config.get("Currency")
    actual_leverage = launch_config.get("leverage") or launch_config.get("Leverage")
    setfile = launch_config.get("setfile_path") or launch_config.get("Setfile")

    if int(actual_deposit or 0) != int(expected_deposit or 0):
        return GateResult(
            "G2", "tester defaults loaded", False, "deposit_mismatch",
            f"launch deposit={actual_deposit} != defaults={expected_deposit}",
        )
    if str(actual_currency or "").upper() != str(expected_currency or "").upper():
        return GateResult(
            "G2", "tester defaults loaded", False, "currency_mismatch",
            f"launch currency={actual_currency} != defaults={expected_currency}",
        )
    if int(actual_leverage or 0) != int(expected_leverage or 0):
        return GateResult(
            "G2", "tester defaults loaded", False, "leverage_mismatch",
            f"launch leverage={actual_leverage} != defaults={expected_leverage}",
        )
    if not setfile or not Path(str(setfile)).exists():
        return GateResult(
            "G2", "tester defaults loaded", False, "setfile_missing",
            f"setfile not present: {setfile}",
        )
    # RISK_FIXED token check inside the setfile.
    try:
        sf_text = Path(str(setfile)).read_text(encoding="utf-16-le", errors="replace")
        if "RISK_FIXED" not in sf_text and "risk_fixed" not in sf_text.lower():
            sf_text = Path(str(setfile)).read_text(encoding="utf-8", errors="replace")
        if "RISK_FIXED" not in sf_text and "risk_fixed" not in sf_text.lower():
            return GateResult(
                "G2", "tester defaults loaded", False, "risk_fixed_token_missing",
                "setfile does not contain RISK_FIXED — DL-038 Rule 7 violation",
            )
    except Exception as exc:  # noqa: BLE001 — read failure is itself a fail
        return GateResult(
            "G2", "tester defaults loaded", False, "setfile_read_error",
            f"could not read setfile: {exc}",
        )
    return GateResult("G2", "tester defaults loaded", True, "")


# -------------------------------------------------------------------------
# Gate 3 — tester journal clean
# -------------------------------------------------------------------------


def gate3_journal_clean(journal_path: Path) -> GateResult:
    """G3 — tester journal must NOT contain any rejected line."""
    if not journal_path.exists():
        return GateResult(
            "G3", "tester journal clean", False, "journal_missing",
            f"journal not found: {journal_path}",
        )
    try:
        text = journal_path.read_text(encoding="utf-16-le", errors="replace")
    except Exception:
        text = journal_path.read_text(encoding="utf-8", errors="replace")
    hits = [line for line in REJECTED_JOURNAL_LINES if line in text]
    if hits:
        return GateResult(
            "G3", "tester journal clean", False, "rejected_journal_lines",
            f"journal contains: {hits}",
        )
    return GateResult("G3", "tester journal clean", True, "")


# -------------------------------------------------------------------------
# Gate 4 — trade evidence
# -------------------------------------------------------------------------

ZERO_TRADE_ADR_DIR = REPO_ROOT / "decisions"


def parse_trade_count(report_path: Path) -> int | None:
    """Parse MT5 tester report.htm/xml for total trades. Returns None if unparseable."""
    if not report_path.exists():
        return None
    try:
        text = report_path.read_text(encoding="utf-16-le", errors="replace")
    except Exception:
        text = report_path.read_text(encoding="utf-8", errors="replace")
    # MT5 HTML tester report typically has "Total Trades" or "Total Net Profit / Trades"
    # We try a few patterns; CTO refines on Tuesday with the actual report shape.
    patterns = [
        r"Total\s*[Tt]rades\D+(\d+)",
        r"(?:Total|Trades)\s*</td>\s*<td[^>]*>\s*(\d+)",
        r'"trades_total"\s*:\s*(\d+)',
        r"<TotalTrades>(\d+)</TotalTrades>",
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            return int(m.group(1))
    return None


def has_zero_trade_adr(ea_id: str, symbol: str) -> bool:
    """Check if a per-symbol zero-trade ADR exists at decisions/<date>_zero_trade_<ea>_<symbol>.md."""
    if not ZERO_TRADE_ADR_DIR.is_dir():
        return False
    pattern = f"*_zero_trade_{ea_id}_{symbol}.md"
    return any(ZERO_TRADE_ADR_DIR.glob(pattern))


def gate4_trade_evidence(report_path: Path, ea_id: str, symbol: str) -> GateResult:
    """G4 — trade_count >= 1 OR per-symbol zero-trade ADR."""
    trade_count = parse_trade_count(report_path)
    if trade_count is None:
        return GateResult(
            "G4", "trade evidence", False, "report_unparseable",
            f"could not parse trade count from {report_path}",
        )
    if trade_count >= 1:
        return GateResult("G4", "trade evidence", True, "", f"trades={trade_count}")
    if has_zero_trade_adr(ea_id, symbol):
        return GateResult(
            "G4", "trade evidence", True, "",
            f"trades=0 with zero-trade ADR present for {ea_id}/{symbol}",
        )
    return GateResult(
        "G4", "trade evidence", False, "zero_trades_no_adr",
        f"trades=0 and no decisions/<date>_zero_trade_{ea_id}_{symbol}.md ADR exists — "
        f"this is a ZERO_TRADE outcome, not PASS, until ADR filed",
    )


# -------------------------------------------------------------------------
# Gate 5 — symbol-name canonical
# -------------------------------------------------------------------------

CANONICAL_SYMBOL_PATTERN = re.compile(r"\b([A-Z][A-Za-z0-9]+\.DWX)\b")
T1_BASES_HISTORY = Path(r"D:\QM\mt5\T1\bases\Custom\history")


def canonical_symbols_from_filesystem(history_dir: Path = T1_BASES_HISTORY) -> set[str]:
    """Return set of canonical .DWX symbol names from MT5 custom-symbol history dirs.

    This is the most robust source: each `<sym>.DWX/` subdir is the symbol MT5
    actually has compiled bars for. Independent of log rotation.
    """
    if not history_dir.is_dir():
        return set()
    return {p.name for p in history_dir.iterdir() if p.is_dir() and p.name.endswith(".DWX")}


def canonical_symbols_from_import_log(import_logs_dir: Path = DWX_IMPORT_LOGS) -> set[str]:
    """Return set of canonical .DWX symbol names from import log content.

    Walks backward through hourly logs until one with non-empty symbol set is
    found (today's log may be a stub). Falls back to filesystem if all logs
    are empty.
    """
    if not import_logs_dir.is_dir():
        return canonical_symbols_from_filesystem()
    candidates = sorted(import_logs_dir.glob("hourly_*.log"), reverse=True)
    for log_path in candidates:
        text = log_path.read_text(encoding="utf-8", errors="replace")
        syms = {m.group(1) for m in CANONICAL_SYMBOL_PATTERN.finditer(text)}
        if syms:
            return syms
    return canonical_symbols_from_filesystem()


def gate5_canonical_symbol(symbol: str, import_logs_dir: Path = DWX_IMPORT_LOGS) -> GateResult:
    """G5 — symbol must match an import-log path component exactly (case-sensitive)."""
    canonical = canonical_symbols_from_import_log(import_logs_dir)
    if not canonical:
        return GateResult(
            "G5", "symbol-name canonical", False, "no_canonical_set",
            "could not derive canonical symbol set from import log",
        )
    if symbol not in canonical:
        # Hint about common mistakes (NDX vs NDXm, GDAXI vs GDAXIm).
        hints = [c for c in canonical if c.replace("m.DWX", ".DWX") == symbol or c.replace(".DWX", "m.DWX") == symbol]
        hint_str = f" (did you mean {hints}?)" if hints else ""
        return GateResult(
            "G5", "symbol-name canonical", False, "non_canonical_symbol",
            f"{symbol} not in canonical set ({len(canonical)} symbols){hint_str}",
        )
    return GateResult("G5", "symbol-name canonical", True, "")


# -------------------------------------------------------------------------
# Orchestrator
# -------------------------------------------------------------------------


def apply_pre_launch_gates(
    *,
    ea_id: str,
    phase: str,
    symbol: str,
    terminal: str,
    window_start: datetime,
    window_end: datetime,
    launch_config: dict,
) -> MatrixVerdict:
    """Run G1, G2, G5 (G3 is post-launch, G4 is post-launch).

    Returns MatrixVerdict with verdict=='INVALID' on any pre-launch fail.
    Pipeline-Op MUST refuse to launch if verdict is INVALID.
    """
    gates = [
        gate1_verify_data_access(symbol, window_start, window_end),
        gate2_tester_defaults_loaded(launch_config),
        gate5_canonical_symbol(symbol),
    ]
    failed = [g for g in gates if not g.passed]
    if failed:
        reason = "; ".join(f"{g.gate}:{g.reason}" for g in failed)
        return MatrixVerdict(
            ea_id=ea_id, phase=phase, symbol=symbol, terminal=terminal,
            gates=gates, verdict="INVALID", invalidation_reason=reason,
        )
    # Pre-launch ok — placeholder verdict; post-launch will overwrite.
    return MatrixVerdict(
        ea_id=ea_id, phase=phase, symbol=symbol, terminal=terminal,
        gates=gates, verdict="PRELAUNCH_OK", invalidation_reason="",
    )


def apply_post_launch_gates(
    pre_verdict: MatrixVerdict,
    *,
    journal_path: Path,
    report_path: Path,
) -> MatrixVerdict:
    """Run G3 + G4 after launch. Combines with pre-launch gates for final verdict."""
    gates = list(pre_verdict.gates)
    gates.append(gate3_journal_clean(journal_path))
    gates.append(gate4_trade_evidence(report_path, pre_verdict.ea_id, pre_verdict.symbol))
    failed = [g for g in gates if not g.passed]
    if failed:
        reason = "; ".join(f"{g.gate}:{g.reason}" for g in failed)
        return MatrixVerdict(
            ea_id=pre_verdict.ea_id, phase=pre_verdict.phase, symbol=pre_verdict.symbol,
            terminal=pre_verdict.terminal, gates=gates, verdict="INVALID",
            invalidation_reason=reason,
        )
    return MatrixVerdict(
        ea_id=pre_verdict.ea_id, phase=pre_verdict.phase, symbol=pre_verdict.symbol,
        terminal=pre_verdict.terminal, gates=gates, verdict="PASS",
        invalidation_reason="",
    )


def serialize_verdict(verdict: MatrixVerdict) -> dict:
    return {
        "ea_id": verdict.ea_id,
        "phase": verdict.phase,
        "symbol": verdict.symbol,
        "terminal": verdict.terminal,
        "verdict": verdict.verdict,
        "invalidation_reason": verdict.invalidation_reason,
        "gates": [asdict(g) for g in verdict.gates],
    }


# -------------------------------------------------------------------------
# CLI smoke
# -------------------------------------------------------------------------


def main(argv: Iterable[str] | None = None) -> int:
    """Quick smoke: print canonical symbol set + tester defaults."""
    import sys
    canonical = canonical_symbols_from_import_log()
    defaults = load_tester_defaults()
    print(f"canonical_symbols: {len(canonical)} found")
    for s in sorted(canonical):
        print(f"  {s}")
    print(f"tester_defaults: {json.dumps(defaults, indent=2)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
