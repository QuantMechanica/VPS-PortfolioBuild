#!/usr/bin/env python
"""Read-only live-sleeve DRIFT monitor for the QM Darwinex Zero terminal T_Live.

Motivation (OWNER 2026-09-13): three live sleeves (12778 / 12969 / 13117) sat
"dark" for seven weeks with zero trades and nothing compared their live activity
against backtest expectation, so no alarm ever fired.  This monitor closes that
gap.  For every deployed sleeve it compares what the sleeve has ACTUALLY done on
T_Live (EA JSONL logs + terminal deal journals) against its own sealed backtest
stream and raises deterministic alarms.

READ-ONLY by contract:
  * C:/QM/mt5/T_Live/** is only ever opened for reading (no MetaTrader5 API, no
    terminal control, no writes anywhere under the live tree).
  * The only file written is --out (JSON, default D:/QM/reports/state) plus an
    optional --markdown sibling.  --out is refused if it resolves under T_Live.

It is a MONITOR, not a gate: it exits 0 regardless of verdict.

Output schema: qm.live-sleeve-drift/v1

Metrics (all deterministic; the only knobs are the constants declared below):
  1. Activity  - expected trades since deploy = lambda_bt * trading_days_live.
                 observed = live entries (TM_OPEN ok=true, else ENTRY_ACCEPTED).
                 Poisson lower tail P(X<=obs) -> ALARM_DARK / WARN_LOW_ACTIVITY;
                 upper tail P(X>=obs) -> WARN_HIGH_ACTIVITY (over-trading).
  2. Performance - live price R-multiples (exit-entry)/(entry-SL) reconstructed
                 from EA-log ENTRY_ACCEPTED + the paired terminal-journal exit
                 deal vs the backtest R distribution (net/RISK_FIXED); rank-based
                 drift = mean live-R percentile within the backtest sample, plus a
                 one-sided Mann-Whitney p; WARN_PERF if n>=10 and p<0.05.
  3. Heartbeat - age of the last EA-log line; ALARM_SILENT if no line within the
                 last HEARTBEAT_SILENT_TRADING_DAYS trading days while RUNNING.
  4. Symbol sanity - EA-log symbol must be the bare broker name in the manifest
                 slot (ALARM_SYMBOL_MISMATCH), .DWX literal in a trade payload is
                 flagged, and BASKET_WARMUP loaded=0 -> ALARM_WARMUP_EMPTY.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any

# Reuse live_book_pulse helpers where importable (normalize_symbol, decode_bytes,
# path_is_under).  The monitor still runs standalone if the import fails.
try:  # pragma: no cover - import shim
    import live_book_pulse as _lbp
except ModuleNotFoundError:  # pragma: no cover - import shim
    try:
        from tools.strategy_farm import live_book_pulse as _lbp
    except ModuleNotFoundError:
        _lbp = None


# --------------------------------------------------------------------------- #
# Constants (the complete set of tuning knobs; nothing else is calibrated)
# --------------------------------------------------------------------------- #
SCHEMA = "qm.live-sleeve-drift/v1"

DEFAULT_PULSE = Path(r"D:\QM\reports\state\live_book_pulse.json")
DEFAULT_EA_LOG_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM")
DEFAULT_JOURNAL_DIR = Path(r"C:\QM\mt5\T_Live\MT5_Base\logs")
DEFAULT_STREAM_ROOTS = [
    Path(r"D:\QM\reports\portfolio\dxz_v2_20260913\streams_v2b\QM\q08_trades"),
    Path(r"D:\QM\reports\portfolio\dxz_final_20260719\QM\q08_trades"),
]
DEFAULT_OUT = Path(r"D:\QM\reports\state\live_sleeve_drift.json")
LIVE_ROOT = Path(r"C:\QM\mt5\T_Live")

# Backtest streams are RISK_FIXED $1000 per trade on 100k; net / RISK_FIXED = R.
RISK_FIXED_USD = 1000.0
# Trading-day basis for both lambda and days_live (Mon-Fri; holidays not modelled
# -- a documented simplification that keeps the window deterministic without a
# broker calendar; it slightly raises expected, which is conservative for a DARK
# test since the risk is a false OK, not a false alarm).
POISSON_ALARM_DARK_P = 0.01     # observed==0 and P(X<=0) < this -> ALARM_DARK
POISSON_WARN_LOW_P = 0.05       # P(X<=obs) < this -> WARN_LOW_ACTIVITY
POISSON_WARN_HIGH_P = 0.01      # P(X>=obs) < this -> WARN_HIGH_ACTIVITY
PERF_MIN_N = 10                 # min paired live round-trips for a perf verdict
PERF_ALPHA = 0.05               # one-sided Mann-Whitney threshold for WARN_PERF
HEARTBEAT_SILENT_TRADING_DAYS = 2
# A journal exit deal is paired to a TM_CLOSE within this many minutes (broker
# time) on the same symbol + opposite side.
DEAL_EXIT_MATCH_TOLERANCE_MIN = 240

SEVERITY_RANK = {"OK": 0, "WARN": 1, "ALARM": 2}
ALARM_CODES = {  # code -> severity class
    "ALARM_DARK": "ALARM",
    "ALARM_SILENT": "ALARM",
    "ALARM_SYMBOL_MISMATCH": "ALARM",
    "ALARM_WARMUP_EMPTY": "ALARM",
    "WARN_LOW_ACTIVITY": "WARN",
    "WARN_HIGH_ACTIVITY": "WARN",
    "WARN_PERF": "WARN",
    "WARN_NO_BACKTEST_STREAM": "WARN",
    "WARN_NO_EA_LOG": "WARN",
    "WARN_UNRESOLVED_FILLS": "WARN",
    "WARN_EVAL_ERROR": "WARN",
}

DEAL_RE = re.compile(
    r"deal #(?P<deal>\d+)\s+(?P<side>buy|sell)\s+(?P<vol>[\d.]+)\s+(?P<symbol>\S+)"
    r"\s+at\s+(?P<price>[\d.]+)\s+done\s+\(based on order #(?P<order>\d+)\)",
    re.IGNORECASE,
)
DATE_FILE_RE = re.compile(r"(?P<date>\d{8})\.log$", re.IGNORECASE)


# --------------------------------------------------------------------------- #
# Small helpers (fall back to local copies if live_book_pulse is unavailable)
# --------------------------------------------------------------------------- #
def normalize_symbol(symbol: Any) -> str:
    if _lbp is not None:
        return _lbp.normalize_symbol(symbol)
    text = str(symbol or "").strip().upper()
    return text[:-4] if text.endswith(".DWX") else text


def decode_bytes(data: bytes) -> str:
    if _lbp is not None:
        return _lbp.decode_bytes(data)
    if data[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return data.decode("utf-16", errors="replace")
    if data.count(b"\x00") > max(10, len(data) // 20):
        return data.decode("utf-16-le", errors="replace")
    for enc in ("utf-8-sig", "cp1252"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_iso(text: Any) -> datetime | None:
    if not text:
        return None
    s = str(text).strip().replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(s)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def parse_broker_naive(text: Any) -> datetime | None:
    """ts_broker fields are naive local-broker time; keep them naive for matching
    against journal broker timestamps."""
    if not text:
        return None
    s = str(text).strip().replace("Z", "")
    try:
        return datetime.fromisoformat(s).replace(tzinfo=None)
    except ValueError:
        return None


def trading_days_between(d0: date, d1: date) -> int:
    """Inclusive count of Mon-Fri days between two dates (>=0)."""
    if d1 < d0:
        return 0
    n = 0
    d = d0
    while d <= d1:
        if d.weekday() < 5:
            n += 1
        d += timedelta(days=1)
    return n


# --------------------------------------------------------------------------- #
# Statistics (no scipy; deterministic, unit-tested)
# --------------------------------------------------------------------------- #
def poisson_cdf(k: int, lam: float) -> float:
    """Lower-tail P(X <= k) for a Poisson(lam).  Iterative term to stay stable."""
    if lam <= 0:
        return 1.0 if k >= 0 else 0.0
    if k < 0:
        return 0.0
    term = math.exp(-lam)  # P(X=0)
    total = term
    for i in range(1, int(k) + 1):
        term *= lam / i
        total += term
    return min(total, 1.0)


def poisson_sf_inclusive(k: int, lam: float) -> float:
    """Upper-tail P(X >= k) for a Poisson(lam)."""
    if k <= 0:
        return 1.0
    return max(0.0, 1.0 - poisson_cdf(k - 1, lam))


def normal_cdf(z: float) -> float:
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


def mean_percentile(live: list[float], backtest: list[float]) -> float | None:
    """Mean percentile of each live R within the backtest R sample.

    Percentile of x = (# backtest < x + 0.5 * # backtest == x) / n_backtest
    (mid-rank convention).  0.5 == no drift; <0.5 == live worse; >0.5 == better.
    """
    if not live or not backtest:
        return None
    m = len(backtest)
    acc = 0.0
    for x in live:
        below = sum(1 for b in backtest if b < x)
        equal = sum(1 for b in backtest if b == x)
        acc += (below + 0.5 * equal) / m
    return acc / len(live)


def mann_whitney(live: list[float], backtest: list[float], alternative: str = "less") -> dict[str, Any] | None:
    """Mann-Whitney U with tie-corrected normal approximation.

    ``live`` is sample 1.  alternative="less" tests H1: live is stochastically
    smaller than backtest (i.e. the sleeve underperforms its backtest).
    """
    n1, n2 = len(live), len(backtest)
    if n1 == 0 or n2 == 0:
        return None
    combined = [(float(v), 0) for v in live] + [(float(v), 1) for v in backtest]
    combined.sort(key=lambda t: t[0])
    n = len(combined)
    ranks = [0.0] * n
    tie_term = 0.0
    i = 0
    while i < n:
        j = i
        while j + 1 < n and combined[j + 1][0] == combined[i][0]:
            j += 1
        avg_rank = (i + 1 + j + 1) / 2.0  # 1-based ranks averaged over the tie block
        for k in range(i, j + 1):
            ranks[k] = avg_rank
        t = j - i + 1
        tie_term += t ** 3 - t
        i = j + 1
    r1 = sum(rank for rank, (_, grp) in zip(ranks, combined) if grp == 0)
    u1 = r1 - n1 * (n1 + 1) / 2.0
    u2 = n1 * n2 - u1
    mu = n1 * n2 / 2.0
    if n > 1:
        sigma2 = (n1 * n2 / 12.0) * ((n + 1) - tie_term / (n * (n - 1)))
    else:
        sigma2 = 0.0
    if sigma2 <= 0:
        return {"u1": u1, "u2": u2, "z": 0.0, "p": 1.0}
    sigma = math.sqrt(sigma2)
    if alternative == "less":
        z = (u1 + 0.5 - mu) / sigma  # continuity-corrected lower tail on U1
        p = normal_cdf(z)
    elif alternative == "greater":
        z = (u1 - 0.5 - mu) / sigma
        p = 1.0 - normal_cdf(z)
    else:  # two-sided
        z = (u1 - mu) / sigma
        p = min(1.0, 2.0 * min(normal_cdf(z), 1.0 - normal_cdf(z)))
    return {"u1": u1, "u2": u2, "z": z, "p": p}


def _worst(*verdicts: str) -> str:
    best = "OK"
    for v in verdicts:
        if SEVERITY_RANK.get(v, 0) > SEVERITY_RANK.get(best, 0):
            best = v
    return best


def _severity_of(codes: list[str]) -> str:
    verdict = "OK"
    for code in codes:
        verdict = _worst(verdict, ALARM_CODES.get(code, "WARN"))
    return verdict


# --------------------------------------------------------------------------- #
# Inputs
# --------------------------------------------------------------------------- #
def load_sleeves(pulse_path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Enumerate deployed sleeves from live_book_pulse.json's book_manifest."""
    meta: dict[str, Any] = {"pulse_path": str(pulse_path), "effective_state": None, "manifest_path": None}
    try:
        pulse = json.loads(pulse_path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        meta["error"] = f"pulse_unreadable:{exc}"
        return [], meta
    meta["effective_state"] = pulse.get("effective_state")
    meta["pulse_generated_at_utc"] = pulse.get("generated_at_utc")
    bm = pulse.get("book_manifest") or {}
    meta["manifest_path"] = bm.get("path")
    sleeves = [s for s in (bm.get("sleeves") or []) if isinstance(s, dict) and s.get("ea_id")]
    return sleeves, meta


def load_deploy_dates(manifest_path: str | None) -> dict[str, str]:
    """(ea_id|symbol_norm) -> ex5_deployed_mtime ISO from the raw manifest."""
    out: dict[str, str] = {}
    if not manifest_path:
        return out
    try:
        payload = json.loads(Path(manifest_path).read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return out
    for s in payload.get("sleeves") or []:
        if not isinstance(s, dict) or not s.get("ea_id"):
            continue
        key = f"{int(s['ea_id'])}|{normalize_symbol(s.get('symbol'))}"
        mtime = s.get("ex5_deployed_mtime") or s.get("deployed_at") or s.get("reserved_at")
        if mtime:
            out[key] = str(mtime)
    return out


def load_backtest_stream(ea_id: int, symbol_norm: str, stream_roots: list[Path]) -> dict[str, Any]:
    """Load a sealed q08 TRADE_CLOSED stream for (ea_id, symbol)."""
    result: dict[str, Any] = {
        "found": False, "stream_path": None, "stream_set": None,
        "n_trades": 0, "lambda_per_trading_day": None,
        "span_start": None, "span_end": None,
        "r_multiples": [], "entry_times": [],
    }
    fname = f"{ea_id}_{symbol_norm}_DWX.jsonl"
    path = None
    for root in stream_roots:
        cand = root / fname
        if cand.is_file():
            path = cand
            break
    if path is None:
        return result
    result["found"] = True
    result["stream_path"] = str(path)
    # label the dataset by its portfolio dir (parents: q08_trades/QM/<setdir>/...)
    parts = path.parts
    result["stream_set"] = parts[-4] if len(parts) >= 4 else None
    entry_times: list[int] = []
    r_mult: list[float] = []
    try:
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if rec.get("event") != "TRADE_CLOSED":
                    continue
                et = rec.get("entry_time")
                net = rec.get("net")
                if et is not None:
                    entry_times.append(int(et))
                if net is not None:
                    r_mult.append(float(net) / RISK_FIXED_USD)
    except OSError:
        return result
    entry_times.sort()
    result["entry_times"] = entry_times
    result["r_multiples"] = r_mult
    result["n_trades"] = len(entry_times)
    if entry_times:
        d0 = datetime.fromtimestamp(entry_times[0], timezone.utc).date()
        d1 = datetime.fromtimestamp(entry_times[-1], timezone.utc).date()
        result["span_start"] = d0.isoformat()
        result["span_end"] = d1.isoformat()
        tdays = max(trading_days_between(d0, d1), 1)
        result["lambda_per_trading_day"] = len(entry_times) / tdays
    return result


def parse_ea_log(path: Path) -> dict[str, Any]:
    """Stream a single EA JSONL log and extract the fields the monitor needs."""
    info: dict[str, Any] = {
        "exists": path.is_file(),
        "first_init_ok": None, "last_init_ok": None,
        "last_equity_snapshot": None, "last_line_ts": None,
        "tm_open_ok": 0, "entry_accepted": 0,
        # per-slot counts keyed by normalized symbol (multi-symbol EAs share one
        # magic + one log; TM_OPEN/ENTRY_ACCEPTED payloads carry the real symbol)
        "tm_open_ok_by_symbol": defaultdict(int),        # PLACEMENTS (orders acked)
        "entry_accepted_by_symbol": defaultdict(int),
        # entry order tickets from TM_OPEN ok=true, per symbol; joined to journal
        # `deal ... based on order #N` lines to count FILLED positions.
        "tm_open_tickets_by_symbol": defaultdict(set),
        "warmup_empty_events": 0, "basket_symbols": [],
        "log_symbols": set(), "dwx_literal_seen": False,
        "entries": [],   # ENTRY_ACCEPTED: dict(ticket, price, sl, side, symbol, ts_broker)
        "closes": [],    # TM_CLOSE ok: dict(ticket, symbol, ts_broker)
    }
    if not path.is_file():
        return info
    try:
        handle = path.open("r", encoding="utf-8-sig", errors="replace")
    except OSError:
        info["exists"] = False
        return info
    with handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                e = json.loads(line)
            except json.JSONDecodeError:
                continue
            ev = e.get("event") or ""
            ts = e.get("ts_utc")
            if ts:
                info["last_line_ts"] = ts
            sym = e.get("symbol")
            if sym:
                info["log_symbols"].add(str(sym))
            payload = e.get("payload") if isinstance(e.get("payload"), dict) else {}
            if ev == "INIT_OK":
                if info["first_init_ok"] is None:
                    info["first_init_ok"] = ts
                info["last_init_ok"] = ts
            elif ev == "EQUITY_SNAPSHOT":
                info["last_equity_snapshot"] = ts
            elif ev == "TM_OPEN":
                psym = payload.get("symbol")
                if payload.get("ok") is True:
                    info["tm_open_ok"] += 1
                    nsym = normalize_symbol(psym or sym)
                    info["tm_open_ok_by_symbol"][nsym] += 1
                    tk = payload.get("ticket")
                    if tk is not None:
                        info["tm_open_tickets_by_symbol"][nsym].add(tk)
                if psym and ".DWX" in str(psym).upper():
                    info["dwx_literal_seen"] = True
            elif ev == "ENTRY_ACCEPTED":
                info["entry_accepted"] += 1
                psym = payload.get("symbol")
                info["entry_accepted_by_symbol"][normalize_symbol(psym or sym)] += 1
                if psym and ".DWX" in str(psym).upper():
                    info["dwx_literal_seen"] = True
                ptype = str(payload.get("type") or "").upper()
                side = "buy" if "BUY" in ptype else ("sell" if "SELL" in ptype else None)
                info["entries"].append({
                    "ticket": payload.get("ticket"),
                    "price": payload.get("price"),
                    "sl": payload.get("sl"),
                    "side": side,
                    "symbol": normalize_symbol(psym or sym),
                    "ts_broker": e.get("ts_broker"),
                })
            elif ev == "TM_CLOSE":
                if payload.get("ok") is not False:
                    info["closes"].append({
                        "ticket": payload.get("ticket"),
                        "symbol": normalize_symbol(payload.get("symbol") or sym),
                        "ts_broker": e.get("ts_broker"),
                    })
            elif ev == "BASKET_WARMUP":
                if payload.get("loaded") == 0:
                    info["warmup_empty_events"] += 1
            elif ev == "SYMBOL_GUARD_INIT":
                syms = payload.get("symbols")
                if isinstance(syms, list) and len(syms) > len(info["basket_symbols"]):
                    info["basket_symbols"] = [str(x) for x in syms]
    info["log_symbols"] = sorted(info["log_symbols"])
    info["tm_open_ok_by_symbol"] = dict(info["tm_open_ok_by_symbol"])
    info["entry_accepted_by_symbol"] = dict(info["entry_accepted_by_symbol"])
    info["tm_open_tickets_by_symbol"] = {k: set(v) for k, v in info["tm_open_tickets_by_symbol"].items()}
    return info


def parse_journals(journal_dir: Path, since: date | None, until: date | None) -> list[dict[str, Any]]:
    """Parse terminal deal journals into a time-ordered list of executed deals.

    Deal lines carry broker time (from the line) + the file's date.  These are
    account-level fills (T_Live shares the DXZ account with T1-T10 by OWNER
    design), so each deal is attributed to a sleeve only via its order ticket,
    never counted blind.
    """
    deals: list[dict[str, Any]] = []
    if not journal_dir.is_dir():
        return deals
    for path in sorted(journal_dir.glob("*.log")):
        m = DATE_FILE_RE.search(path.name)
        if not m:
            continue
        try:
            fdate = datetime.strptime(m.group("date"), "%Y%m%d").date()
        except ValueError:
            continue
        if since and fdate < since - timedelta(days=3):
            continue
        if until and fdate > until:
            continue
        try:
            text = decode_bytes(path.read_bytes())
        except OSError:
            continue
        for line in text.splitlines():
            dm = DEAL_RE.search(line)
            if not dm:
                continue
            parts = line.split("\t")
            dt = None
            for token in parts:
                token = token.strip()
                try:
                    tt = datetime.strptime(token, "%H:%M:%S.%f").time()
                    dt = datetime.combine(fdate, tt)
                    break
                except ValueError:
                    continue
            deals.append({
                "dt_broker": dt,
                "deal": int(dm.group("deal")),
                "order": int(dm.group("order")),
                "side": dm.group("side").lower(),
                "volume": float(dm.group("vol")),
                "symbol": normalize_symbol(dm.group("symbol")),
                "price": float(dm.group("price")),
            })
    deals.sort(key=lambda d: (d["dt_broker"] or datetime.min))
    return deals


def count_positions_opened(symbol_deals: list[dict[str, Any]]) -> int:
    """Count distinct positions OPENED from a symbol's time-ordered deals via a
    running net-position tracker (each flat -> non-flat transition = one new
    position).  Used only for the per-symbol fallback when a lone sleeve owns the
    symbol and TM_OPEN tickets are unavailable -- so entry deals cannot be
    isolated by the ticket join."""
    pos = 0.0
    opened = 0
    for d in symbol_deals:
        prev = pos
        pos += d["volume"] if d["side"] == "buy" else -d["volume"]
        if abs(prev) < 1e-9 and abs(pos) > 1e-9:
            opened += 1
    return opened


# --------------------------------------------------------------------------- #
# Per-metric evaluation
# --------------------------------------------------------------------------- #
def eval_activity(observed: int | None, placements: int, observed_source: str,
                  expected: float | None) -> dict[str, Any]:
    row: dict[str, Any] = {
        # observed_entries = FILLED positions (deals), NOT order placements.
        "observed_entries": observed, "placements": placements,
        "observed_source": observed_source,
        "expected": None if expected is None else round(expected, 4),
        "p_low": None, "p_high": None, "verdict": "OK", "codes": [],
    }
    if observed is None:
        # fills could not be resolved (no TM_OPEN ticket + symbol shared by >1
        # sleeve); never guess -> WARN, and do not run the Poisson test.
        row["verdict"] = "WARN"
        row["codes"] = ["WARN_UNRESOLVED_FILLS"]
        return row
    if expected is None:
        row["verdict"] = "WARN"
        row["codes"] = ["WARN_NO_BACKTEST_STREAM"]
        return row
    p_low = poisson_cdf(observed, expected)
    p_high = poisson_sf_inclusive(observed, expected)
    row["p_low"] = round(p_low, 6)
    row["p_high"] = round(p_high, 6)
    codes: list[str] = []
    if observed == 0 and p_low < POISSON_ALARM_DARK_P:
        codes.append("ALARM_DARK")
    elif p_low < POISSON_WARN_LOW_P:
        codes.append("WARN_LOW_ACTIVITY")
    if p_high < POISSON_WARN_HIGH_P and observed > expected:
        codes.append("WARN_HIGH_ACTIVITY")
    row["codes"] = codes
    row["verdict"] = _severity_of(codes)
    return row


def reconstruct_live_r(entries: list[dict[str, Any]], closes: list[dict[str, Any]],
                       deals: list[dict[str, Any]]) -> tuple[list[float], int, int]:
    """Reconstruct realized price R-multiples for one sleeve.

    R = dir * (exit_price - entry_price) / |entry_price - SL|, a cost-free
    price-based R-multiple (excludes commission/swap by construction -- never
    invented).  entry_price/SL/side come from ENTRY_ACCEPTED; exit_price is the
    journal deal on the same symbol, opposite side, nearest the TM_CLOSE broker
    time.  A round-trip whose exit deal cannot be located is dropped, not guessed.
    """
    close_by_ticket: dict[Any, datetime] = {}
    for c in closes:
        dt = parse_broker_naive(c.get("ts_broker"))
        if c.get("ticket") is not None and dt is not None:
            close_by_ticket[c["ticket"]] = dt
    r_values: list[float] = []
    paired = 0
    for en in entries:
        ticket = en.get("ticket")
        price = en.get("price")
        sl = en.get("sl")
        side = en.get("side")
        symbol = en.get("symbol")
        if None in (price, sl, side) or not symbol:
            continue
        try:
            price = float(price)
            sl = float(sl)
        except (TypeError, ValueError):
            continue
        risk = abs(price - sl)
        if risk <= 0:
            continue
        close_dt = close_by_ticket.get(ticket)
        if close_dt is None:
            continue
        opposite = "sell" if side == "buy" else "buy"
        best = None
        best_gap = None
        for d in deals:
            if d["symbol"] != symbol or d["side"] != opposite or d["dt_broker"] is None:
                continue
            gap = abs((d["dt_broker"] - close_dt).total_seconds())
            if gap <= DEAL_EXIT_MATCH_TOLERANCE_MIN * 60 and (best_gap is None or gap < best_gap):
                best_gap = gap
                best = d
        if best is None:
            continue
        direction = 1.0 if side == "buy" else -1.0
        r_values.append(direction * (best["price"] - price) / risk)
        paired += 1
    return r_values, paired, len(entries)


def eval_performance(live_r: list[float], backtest_r: list[float]) -> dict[str, Any]:
    row: dict[str, Any] = {
        "n_live": len(live_r), "n_backtest": len(backtest_r),
        "live_r_mean": round(sum(live_r) / len(live_r), 4) if live_r else None,
        "mean_percentile": None, "mw_u": None, "mw_p": None,
        "verdict": "OK", "codes": [],
        "source": "journal_paired_price_R_multiples",
    }
    pct = mean_percentile(live_r, backtest_r)
    if pct is not None:
        row["mean_percentile"] = round(pct, 4)
    if len(live_r) < PERF_MIN_N or not backtest_r:
        row["note"] = f"insufficient_live_round_trips (n={len(live_r)} < {PERF_MIN_N})"
        return row
    mw = mann_whitney(live_r, backtest_r, alternative="less")
    if mw is None:
        return row
    row["mw_u"] = mw["u1"]
    row["mw_p"] = round(mw["p"], 6)
    if mw["p"] < PERF_ALPHA:
        row["codes"] = ["WARN_PERF"]
        row["verdict"] = "WARN"
    return row


def ks_state_file_mtime(ea_log_dir: Path, ea_id: int, magic: Any) -> datetime | None:
    """mtime of QM\\halt\\ks_state_<ea_id>_<magic>.state, an independent liveness
    signal that survives a stale per-EA JSONL logger.  QM_KillSwitchCheck runs on
    every OnTick (QM_KillSwitch.mqh:622-635) and rewrites this file once per
    broker-day boundary via QM_KillSwitchRefreshBrokerDay (:258-276), so its mtime
    proves the EA is still ticking even when the JSONL logger stopped appending
    after a terminal restart (OWNER 2026-09-17: 1567/EURUSD false ALARM_SILENT --
    log last written 2026-09-11 VPS reboot, ks_state updated 2026-09-17).
    Returns None if the sleeve has no magic or the file cannot be stat'ed."""
    if magic is None:
        return None
    try:
        magic_int = int(magic)
    except (TypeError, ValueError):
        return None
    path = ea_log_dir / "halt" / f"ks_state_{ea_id}_{magic_int}.state"
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return None
    return datetime.fromtimestamp(mtime, timezone.utc)


def eval_heartbeat(ea: dict[str, Any], now: datetime, terminal_state: str | None,
                   ks_state_mtime: datetime | None = None) -> dict[str, Any]:
    row: dict[str, Any] = {
        "first_init_ok": ea.get("first_init_ok"),
        "last_init_ok": ea.get("last_init_ok"),
        "last_equity_snapshot": ea.get("last_equity_snapshot"),
        "last_log_line": ea.get("last_line_ts"),
        "ks_state_mtime_utc": iso_utc(ks_state_mtime) if ks_state_mtime else None,
        "liveness_source": None,
        "terminal_state": terminal_state,
        "age_trading_days": None, "verdict": "OK", "codes": [],
    }
    codes: list[str] = []
    if not ea.get("exists"):
        codes.append("WARN_NO_EA_LOG")

    log_last = parse_iso(ea.get("last_line_ts")) or parse_iso(ea.get("last_init_ok"))
    if ks_state_mtime is not None and (log_last is None or ks_state_mtime > log_last):
        last, row["liveness_source"] = ks_state_mtime, "ks_state_mtime"
    elif log_last is not None:
        last, row["liveness_source"] = log_last, "ea_log"
    else:
        last = None

    if last is None:
        codes.append("ALARM_SILENT")
    else:
        age_td = trading_days_between(last.date(), now.date())
        age_td = max(age_td - 1, 0)  # same-day = 0 trading days old
        row["age_trading_days"] = age_td
        running = str(terminal_state or "").upper() == "RUNNING"
        if running and age_td > HEARTBEAT_SILENT_TRADING_DAYS:
            codes.append("ALARM_SILENT")

    row["codes"] = list(dict.fromkeys(codes))
    row["verdict"] = _severity_of(row["codes"])
    return row


def eval_symbol(ea: dict[str, Any], manifest_symbol_norm: str) -> dict[str, Any]:
    row: dict[str, Any] = {
        "manifest_symbol": manifest_symbol_norm,
        "log_symbols": ea.get("log_symbols"),
        "basket_symbols": ea.get("basket_symbols"),
        "dwx_literal_seen": bool(ea.get("dwx_literal_seen")),
        "warmup_empty_events": ea.get("warmup_empty_events", 0),
        "verdict": "OK", "codes": [],
    }
    codes: list[str] = []
    log_syms = [normalize_symbol(s) for s in (ea.get("log_symbols") or [])]
    # The chart/top-level symbol must be the bare broker name in the slot. Basket
    # constituent symbols (SYMBOL_GUARD_INIT / warmup) are not the slot symbol.
    if ea.get("exists") and log_syms and manifest_symbol_norm and manifest_symbol_norm not in log_syms:
        codes.append("ALARM_SYMBOL_MISMATCH")
    if ea.get("dwx_literal_seen"):
        codes.append("ALARM_SYMBOL_MISMATCH")
    if ea.get("warmup_empty_events", 0) > 0:
        codes.append("ALARM_WARMUP_EMPTY")
    # de-dup while preserving order
    row["codes"] = list(dict.fromkeys(codes))
    row["verdict"] = _severity_of(row["codes"])
    return row


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
def evaluate_sleeve(sleeve: dict[str, Any], ea_log_dir: Path, deals: list[dict[str, Any]],
                    stream_roots: list[Path], deploy_dates: dict[str, str],
                    now: datetime, terminal_state: str | None,
                    deal_order_numbers: set[int], deals_by_symbol: dict[str, list[dict[str, Any]]],
                    symbol_sleeve_count: dict[str, int]) -> dict[str, Any]:
    ea_id = int(sleeve["ea_id"])
    symbol_norm = normalize_symbol(sleeve.get("symbol") or sleeve.get("symbol_norm"))
    key = sleeve.get("key") or f"{ea_id}|{symbol_norm}"

    ea_path = ea_log_dir / f"QM5_{ea_id}_ea-{ea_id}.log"
    ea = parse_ea_log(ea_path)

    # Deploy date: manifest ex5_deployed_mtime, else first INIT_OK, else None.
    deploy_source = "manifest_ex5_deployed_mtime"
    deploy_iso = deploy_dates.get(key)
    if not deploy_iso:
        deploy_iso = ea.get("first_init_ok")
        deploy_source = "first_init_ok" if deploy_iso else "unknown"
    deploy_dt = parse_iso(deploy_iso) or parse_broker_naive(deploy_iso)
    deploy_date = deploy_dt.date() if deploy_dt else None
    days_live = trading_days_between(deploy_date, now.date()) if deploy_date else None

    bt = load_backtest_stream(ea_id, symbol_norm, stream_roots)
    lam = bt.get("lambda_per_trading_day")
    expected = (lam * days_live) if (lam is not None and days_live) else None

    # Observed = FILLED positions on THIS slot's symbol, NOT order placements.
    # Several sleeves place pending stop orders daily and cancel the unfilled leg,
    # so TM_OPEN/ENTRY_ACCEPTED counts inflate activity. The true fill count is the
    # number of distinct entry order tickets (TM_OPEN ok=true) that appear as a
    # journal `deal ... based on order #N` line. Multi-symbol EAs are per-slot.
    placements = int((ea.get("tm_open_ok_by_symbol") or {}).get(symbol_norm, 0))
    if placements == 0:
        placements = int((ea.get("entry_accepted_by_symbol") or {}).get(symbol_norm, 0))
    slot_tickets = (ea.get("tm_open_tickets_by_symbol") or {}).get(symbol_norm, set())
    if slot_tickets:
        observed = len(slot_tickets & deal_order_numbers)
        observed_source = "journal_fill_join"
    elif placements == 0:
        observed, observed_source = 0, "no_entries"
    elif symbol_sleeve_count.get(symbol_norm, 0) == 1 and symbol_norm in deals_by_symbol:
        observed = count_positions_opened(deals_by_symbol[symbol_norm])
        observed_source = "journal_deals_per_symbol"
    else:
        # placements>0 but tickets missing AND symbol shared by >1 sleeve: fills
        # cannot be attributed -> unknown, never guessed.
        observed, observed_source = None, "unresolved_no_ticket_shared_symbol"

    activity = eval_activity(observed, placements, observed_source, expected)

    slot_entries = [e for e in ea.get("entries", []) if normalize_symbol(e.get("symbol")) == symbol_norm]
    live_r, paired, n_entries = reconstruct_live_r(slot_entries, ea.get("closes", []), deals)
    performance = eval_performance(live_r, bt.get("r_multiples", []))
    performance["round_trips_paired"] = paired
    performance["entries_seen"] = n_entries

    ks_ts = ks_state_file_mtime(ea_log_dir, ea_id, sleeve.get("magic"))
    heartbeat = eval_heartbeat(ea, now, terminal_state, ks_ts)
    symbol_check = eval_symbol(ea, symbol_norm)

    codes: list[str] = []
    for section in (activity, performance, heartbeat, symbol_check):
        codes.extend(section.get("codes", []))
    codes = list(dict.fromkeys(codes))
    overall = _severity_of(codes)

    return {
        "key": key, "ea_id": ea_id, "symbol": symbol_norm,
        "magic": sleeve.get("magic"), "ea_label": sleeve.get("ea_label"),
        "deploy_date": deploy_date.isoformat() if deploy_date else None,
        "deploy_source": deploy_source,
        "days_live_trading": days_live,
        "backtest": {
            "found": bt["found"], "stream_set": bt["stream_set"], "stream_path": bt["stream_path"],
            "n_trades": bt["n_trades"], "lambda_per_trading_day":
                round(lam, 6) if lam is not None else None,
            "span_start": bt["span_start"], "span_end": bt["span_end"],
            "r_n": len(bt.get("r_multiples", [])),
        },
        "activity": {k: v for k, v in activity.items() if k != "codes"},
        "performance": {k: v for k, v in performance.items() if k != "codes"},
        "heartbeat": {k: v for k, v in heartbeat.items() if k != "codes"},
        "symbol_check": {k: v for k, v in symbol_check.items() if k != "codes"},
        "alarm_codes": codes,
        "verdict": overall,
    }


def build_output(sleeves_eval: list[dict[str, Any]], meta: dict[str, Any], now: datetime,
                 inputs: dict[str, Any]) -> dict[str, Any]:
    alarms: list[dict[str, Any]] = []
    for row in sleeves_eval:
        for code in row["alarm_codes"]:
            alarms.append({
                "class": "live_sleeve_drift",
                "severity": ALARM_CODES.get(code, "WARN"),
                "metric": code,
                "value": row["key"],
                "detail": _alarm_detail(code, row),
            })
    n_alarm = sum(1 for r in sleeves_eval if r["verdict"] == "ALARM")
    n_warn = sum(1 for r in sleeves_eval if r["verdict"] == "WARN")
    verdict = "ALARM" if n_alarm else ("WARN" if n_warn else "OK")
    return {
        "schema": SCHEMA,
        "generated_at_utc": iso_utc(now),
        "verdict": verdict,
        "constants": {
            "risk_fixed_usd": RISK_FIXED_USD,
            "poisson_alarm_dark_p": POISSON_ALARM_DARK_P,
            "poisson_warn_low_p": POISSON_WARN_LOW_P,
            "poisson_warn_high_p": POISSON_WARN_HIGH_P,
            "perf_min_n": PERF_MIN_N,
            "perf_alpha": PERF_ALPHA,
            "heartbeat_silent_trading_days": HEARTBEAT_SILENT_TRADING_DAYS,
            "deal_exit_match_tolerance_min": DEAL_EXIT_MATCH_TOLERANCE_MIN,
            "trading_day_basis": "mon_fri_holidays_not_modelled",
        },
        "inputs": inputs,
        "terminal_state": meta.get("effective_state"),
        "pulse_generated_at_utc": meta.get("pulse_generated_at_utc"),
        "sleeve_count": len(sleeves_eval),
        "summary": {
            "n_ok": sum(1 for r in sleeves_eval if r["verdict"] == "OK"),
            "n_warn": n_warn, "n_alarm": n_alarm,
            "dark": [r["key"] for r in sleeves_eval if "ALARM_DARK" in r["alarm_codes"]],
            "warmup_empty": [r["key"] for r in sleeves_eval if "ALARM_WARMUP_EMPTY" in r["alarm_codes"]],
            "silent": [r["key"] for r in sleeves_eval if "ALARM_SILENT" in r["alarm_codes"]],
            "over_trading": [r["key"] for r in sleeves_eval if "WARN_HIGH_ACTIVITY" in r["alarm_codes"]],
        },
        "sleeves": sleeves_eval,
        "alarms": alarms,
    }


def _alarm_detail(code: str, row: dict[str, Any]) -> str:
    a = row.get("activity", {})
    if code in ("ALARM_DARK", "WARN_LOW_ACTIVITY"):
        return (f"fills={a.get('observed_entries')} (placements={a.get('placements')}, "
                f"{a.get('observed_source')}) expected={a.get('expected')} "
                f"P(X<=obs)={a.get('p_low')} days_live={row.get('days_live_trading')}")
    if code == "WARN_HIGH_ACTIVITY":
        return (f"fills={a.get('observed_entries')} (placements={a.get('placements')}, "
                f"{a.get('observed_source')}) expected={a.get('expected')} P(X>=obs)={a.get('p_high')}")
    if code == "ALARM_WARMUP_EMPTY":
        return f"BASKET_WARMUP loaded=0 x{row.get('symbol_check', {}).get('warmup_empty_events')}"
    if code == "ALARM_SILENT":
        hb = row.get("heartbeat", {})
        return (f"last_log_line={hb.get('last_log_line')} ks_state_mtime={hb.get('ks_state_mtime_utc')} "
                f"liveness_source={hb.get('liveness_source')} age_trading_days={hb.get('age_trading_days')}")
    if code == "ALARM_SYMBOL_MISMATCH":
        return f"manifest={row.get('symbol')} log_symbols={row.get('symbol_check', {}).get('log_symbols')} dwx_literal={row.get('symbol_check', {}).get('dwx_literal_seen')}"
    if code == "WARN_PERF":
        p = row.get("performance", {})
        return f"n_live={p.get('n_live')} mean_pct={p.get('mean_percentile')} mw_p={p.get('mw_p')}"
    return code


def _heartbeat_display(hb: dict[str, Any]) -> str:
    if hb.get("liveness_source") == "ks_state_mtime":
        return f"{(hb.get('ks_state_mtime_utc') or '-')[:10]}*"
    return (hb.get("last_log_line") or "-")[:10]


def render_markdown(out: dict[str, Any]) -> str:
    lines = [
        f"# Live Sleeve Drift Monitor ({out['schema']})",
        "",
        f"Generated: {out['generated_at_utc']} | terminal_state={out.get('terminal_state')} | overall verdict: **{out['verdict']}**",
        "",
        f"Sleeves: {out['sleeve_count']} | OK {out['summary']['n_ok']} / WARN {out['summary']['n_warn']} / ALARM {out['summary']['n_alarm']}",
        "",
        "| Sleeve | Days live | lambda_bt | Expected | Fills | Placements | P(X<=obs) | Activity | Perf n/p | Last heartbeat | Verdict | Alarms |",
        "|---|--:|--:|--:|--:|--:|--:|---|---|---|---|---|",
    ]
    for r in sorted(out["sleeves"], key=lambda x: (-SEVERITY_RANK.get(x["verdict"], 0), x["key"])):
        a = r["activity"]
        p = r["performance"]
        hb = r["heartbeat"]
        act_v = _severity_of([c for c in r["alarm_codes"] if c in ("ALARM_DARK", "WARN_LOW_ACTIVITY", "WARN_HIGH_ACTIVITY")])
        perf = f"{p.get('n_live')}/{p.get('mw_p') if p.get('mw_p') is not None else '-'}"
        lam = r["backtest"]["lambda_per_trading_day"]
        lines.append(
            f"| {r['key']} | {r.get('days_live_trading')} | "
            f"{lam if lam is not None else '-'} | {a.get('expected')} | {a.get('observed_entries')} | "
            f"{a.get('placements')} | {a.get('p_low')} | {act_v} | {perf} | "
            f"{_heartbeat_display(hb)} ({hb.get('age_trading_days')}td) | "
            f"**{r['verdict']}** | {', '.join(r['alarm_codes']) or '-'} |"
        )
    lines += ["", "_* heartbeat timestamp is the ks_state file's mtime (newer than the JSONL logger's last line)._", ""]
    lines += ["## Alarms", ""]
    if out["alarms"]:
        for al in out["alarms"]:
            lines.append(f"- **{al['severity']} {al['metric']}** `{al['value']}` - {al['detail']}")
    else:
        lines.append("- none")
    return "\n".join(lines) + "\n"


def run(pulse: Path, ea_log_dir: Path, journal_dir: Path, stream_roots: list[Path],
        now: datetime | None = None) -> dict[str, Any]:
    now = now or utc_now()
    sleeves, meta = load_sleeves(pulse)
    deploy_dates = load_deploy_dates(meta.get("manifest_path"))
    # earliest deploy to bound journal parsing
    earliest = None
    for iso in deploy_dates.values():
        dt = parse_iso(iso) or parse_broker_naive(iso)
        if dt and (earliest is None or dt.date() < earliest):
            earliest = dt.date()
    deals = parse_journals(journal_dir, earliest, now.date())
    deal_order_numbers = {d["order"] for d in deals}
    deals_by_symbol: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for d in deals:
        deals_by_symbol[d["symbol"]].append(d)
    symbol_sleeve_count: dict[str, int] = defaultdict(int)
    for s in sleeves:
        symbol_sleeve_count[normalize_symbol(s.get("symbol") or s.get("symbol_norm"))] += 1

    evaluated: list[dict[str, Any]] = []
    for sleeve in sleeves:
        try:
            evaluated.append(evaluate_sleeve(
                sleeve, ea_log_dir, deals, stream_roots, deploy_dates, now,
                meta.get("effective_state"), deal_order_numbers,
                dict(deals_by_symbol), dict(symbol_sleeve_count)))
        except Exception as exc:  # a bad sleeve must not sink the monitor
            evaluated.append({
                "key": sleeve.get("key") or str(sleeve.get("ea_id")),
                "ea_id": sleeve.get("ea_id"), "symbol": normalize_symbol(sleeve.get("symbol")),
                "verdict": "WARN", "alarm_codes": ["WARN_EVAL_ERROR"],
                "error": f"{type(exc).__name__}:{exc}",
                "activity": {}, "performance": {}, "heartbeat": {}, "symbol_check": {}, "backtest": {},
            })
    inputs = {
        "pulse": str(pulse), "ea_log_dir": str(ea_log_dir), "journal_dir": str(journal_dir),
        "stream_roots": [str(s) for s in stream_roots], "manifest_path": meta.get("manifest_path"),
        "journal_deals_parsed": len(deals),
    }
    return build_output(evaluated, meta, now, inputs)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Read-only live sleeve drift monitor (qm.live-sleeve-drift/v1)")
    parser.add_argument("--pulse", default=str(DEFAULT_PULSE))
    parser.add_argument("--ea-log-dir", default=str(DEFAULT_EA_LOG_DIR))
    parser.add_argument("--journal-dir", default=str(DEFAULT_JOURNAL_DIR))
    parser.add_argument("--stream-root", action="append", default=None,
                        help="Backtest stream root (repeatable; order = priority). "
                             "Defaults to dxz_v2_20260913 then dxz_final_20260719.")
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="Output JSON path (refused under T_Live).")
    parser.add_argument("--markdown", default=None, help="Optional markdown report path.")
    parser.add_argument("--now", default=None, help="Override 'now' (ISO UTC); for reproducible history runs.")
    args = parser.parse_args(argv)

    stream_roots = [Path(s) for s in args.stream_root] if args.stream_root else list(DEFAULT_STREAM_ROOTS)
    now = parse_iso(args.now) if args.now else utc_now()

    out_path = Path(args.out)
    try:
        out_path.resolve().relative_to(LIVE_ROOT.resolve())
        print(f"refusing to write inside live terminal tree: {out_path}", file=sys.stderr)
        return 0
    except ValueError:
        pass  # not under live root -> OK

    snapshot = run(Path(args.pulse), Path(args.ea_log_dir), Path(args.journal_dir), stream_roots, now)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = out_path.with_suffix(out_path.suffix + ".tmp")
    tmp.write_text(json.dumps(snapshot, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(out_path)

    if args.markdown:
        md_path = Path(args.markdown)
        md_path.parent.mkdir(parents=True, exist_ok=True)
        md_path.write_text(render_markdown(snapshot), encoding="utf-8")

    s = snapshot["summary"]
    print(f"[{snapshot['verdict']}] sleeves={snapshot['sleeve_count']} "
          f"ok={s['n_ok']} warn={s['n_warn']} alarm={s['n_alarm']} "
          f"dark={s['dark']} warmup_empty={s['warmup_empty']} "
          f"silent={s['silent']} over_trading={s['over_trading']} -> {out_path}")
    return 0  # monitor, never a gate


if __name__ == "__main__":
    sys.exit(main())
