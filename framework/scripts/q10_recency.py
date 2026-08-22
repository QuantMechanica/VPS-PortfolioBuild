"""Q10 recency-axis metrics (ULTRACODE WS-C) — cohort-bound enforcement.

Purpose
-------
Q10 certifies an ~8-year *average* edge (PF > 1.0, DD < 25% over full history).
It has no recency axis: a sleeve whose edge died in the last two years can still
PASS on the lifetime average (e.g. 12567/XNGUSD — Q10 PASS full-history while its
sealed Q08 edge-decay is 41.52%, PF 1.7642 -> 1.0318, FAIL_HARD twice).

This module computes recency metrics from the Q10 native-report trade list and
classifies CURRENT / WATCH / DECAYED / UNKNOWN. These pure functions never
change a Q10 verdict themselves. `q10_confirmation.py` persists the output under
a versioned key and applies the OWNER-ratified enforcement contract only to work
items created on or after the dated cohort cutoff; the one-shot
``q10_recency_audit.py`` reuses these same pure functions.

Evidence identity (WS-C round 2)
--------------------------------
``evidence_identity`` binds the Q10 evidence tuple — native report SHA-256,
set-file SHA-256, EA-binary (.ex5) SHA-256, window endpoint and manifest
reference — into ONE identity block. Every hash that cannot be resolved from disk
is the explicit string ``"UNKNOWN"`` (never silently dropped), so a consumer can
tell "not bound" apart from "absent". The live Q10 aggregate carries this block
inside its ``recency_shadow_v1`` record; the audit binds the same block per sleeve
(adding the manifest reference it alone has). This is the cryptographic
report/set/binary/window contract the WS-C challenge asked for; documented gaps
(no signed-manifest field in the live runner; ex5 unresolvable when the source
tree is absent) surface as ``"UNKNOWN"`` rather than being asserted.

Design anchors (documented; OWNER-decision points in decisions/2026-07-26_q10_recency_axis_enforcement.md)
--------------------------------------------------------------------------------
* Per-trade ``net = profit + swap + commission`` — validated to reconcile to the
  native report "Total Net Profit" exactly (11422 18382.37==18382.37;
  12567/XNG 1791.18==1791.18). Profit-only does NOT reconcile.
* Half-vs-half edge decline replicates Q08.8 (``framework/scripts/q08_davey/
  sub_8_8_edge_decay.py``) byte-for-byte in method and its 40 % threshold, so the
  recency axis is consistent with the ratified backtest gate:
    - >= 200 trades AND >= 24 active months: rolling-12mo first vs last window
    - else (swing, DL-070): first-half vs second-half of active months, mid split
    - ``decline_pct = (pf_first - pf_last) / pf_first * 100``; FAIL/DECAYED if
      ``decline_pct >= 40`` (``>=`` boundary, matching Q08).
* Trailing windows end at the report's own evidence endpoint (its last-trade
  month). Trailing-24m is the primary recency window; trailing-12m is reported as
  colour (usually too sparse to classify low-frequency sleeves).
* The trailing-window recency band is deliberately *stricter* than Q08's 40 %
  because these are LIVE sleeves at elevated total risk, not backtest candidates:
    - recency_decline_pct = (pf_full - pf_trailing24m) / pf_full * 100
    - >= 25 -> DECAYED ; >= 20 -> WATCH ; else CURRENT (``>=`` boundaries)
  Any of {Q08 half-split >= 40, trailing-24m PF < 1.0} also forces DECAYED.
* Honest about coverage: below the assessability floors the verdict is UNKNOWN,
  never imputed.

Native-report parsing (UTF-16 / German-locale tolerant, FIFO in/out pairing) is
adapted verbatim from the Codex-endorsed parser in
``tools/strategy_farm/portfolio/prop_challenge_optimizer.py`` /
``ftmo_report_cost_reconcile.py`` and kept stdlib-only here so this module is safe
to import in the live Q10 runner path. The audit cross-checks this parser against
the canonical one (parity assertion) so there is no silent drift.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import re
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Sequence

# ---------------------------------------------------------------------------
# Versioning + documented thresholds (single source of truth for shadow+audit)
# ---------------------------------------------------------------------------
RECENCY_SCHEMA_VERSION = "recency_shadow_v1"
RECENCY_IDENTITY_VERSION = "recency_identity_v1"

# Policy switch ratified by OWNER on 2026-08-22.  The caller still applies the
# dated cohort boundary; setting this True does not retroactively re-grade old
# rows.  See decisions/2026-08-22_q10_recency_cohort_activation.md.
RECENCY_AXIS_ENFORCED = True

# Q08-aligned edge-decay (framework/scripts/q08_davey/sub_8_8_edge_decay.py)
Q08_MAX_DECLINE_PCT = 40.0
Q08_SWING_FLOOR = 30          # below this, full history is not assessable
Q08_HIGHFREQ_TRADES = 200     # >= this uses rolling-12mo, else swing half-split
Q08_HIGHFREQ_MIN_MONTHS = 24
Q08_SWING_MIN_MONTHS = 12

# Trailing-window recency bands (WS-C, stricter than Q08 for live money).
RECENCY_WATCH_PCT = 20.0      # decline >= 20 % -> at least WATCH
RECENCY_DECAY_PCT = 25.0      # decline >= 25 % -> DECAYED
MIN_TRAILING_TRADES = 10      # 24-month assessability floor (>=5/yr x 2y)

# Trailing windows (months back from the evidence endpoint, inclusive).
TRAILING_24M_MONTHS = 24
TRAILING_12M_MONTHS = 12

SEVERITY = {"CURRENT": 0, "WATCH": 1, "DECAYED": 2, "UNKNOWN": -1}

# Sentinel used for any evidence hash / field that cannot be resolved from disk.
UNKNOWN = "UNKNOWN"


# ===========================================================================
# Evidence identity binding (WS-C round 2 — cryptographic report/set/binary/window)
# ===========================================================================
def sha256_file(path: str | Path | None) -> str | None:
    """SHA-256 of a file on disk, or None if it cannot be read. Pure/read-only."""
    if not path:
        return None
    try:
        p = Path(path)
        h = hashlib.sha256()
        with p.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                h.update(chunk)
        return h.hexdigest()
    except (OSError, ValueError):
        return None


def evidence_identity(*, report_htm: str | Path | None = None,
                      setfile_path: str | Path | None = None,
                      ex5_path: str | Path | None = None,
                      window_endpoint: Any = None,
                      manifest_ref: str | Path | None = None) -> dict[str, Any]:
    """Bind the Q10 evidence tuple into ONE identity block.

    report SHA-256 + set-file SHA-256 + EX5 SHA-256 + window endpoint + manifest
    reference. Any hash that cannot be resolved from disk is the explicit string
    ``"UNKNOWN"`` (never silently omitted); an absent path stays ``None`` for the
    *_path field but its hash is still ``"UNKNOWN"`` so a consumer never mistakes
    "no input" for "verified". Pure, read-only, never raises.
    """
    def _hash(p: str | Path | None) -> str:
        digest = sha256_file(p)
        return digest if digest else UNKNOWN

    return {
        "schema": RECENCY_IDENTITY_VERSION,
        "report_htm": str(report_htm) if report_htm else None,
        "report_sha256": _hash(report_htm),
        "setfile_path": str(setfile_path) if setfile_path else None,
        "setfile_sha256": _hash(setfile_path),
        "ex5_path": str(ex5_path) if ex5_path else None,
        "ex5_sha256": _hash(ex5_path),
        "window_endpoint": window_endpoint if window_endpoint not in (None, "") else UNKNOWN,
        "manifest_ref": str(manifest_ref) if manifest_ref else UNKNOWN,
    }


# ===========================================================================
# Native MT5 report parsing (stdlib-only; adapted from prop_challenge_optimizer)
# ===========================================================================
@dataclass(frozen=True)
class ClosedTrade:
    exit_time: dt.datetime
    entry_time: dt.datetime
    symbol: str
    side: str
    net: float          # profit + swap + commission (reconciles to native net)
    profit: float
    swap: float
    commission: float


class _HtmlTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._in_cell = False
        self._cell_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.lower()
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._in_cell = True
            self._cell_parts = []

    def handle_data(self, data: str) -> None:
        if self._in_cell:
            self._cell_parts.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self._row is not None and self._in_cell:
            cell = " ".join("".join(self._cell_parts).split())
            self._row.append(cell)
            self._in_cell = False
            self._cell_parts = []
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def _looks_utf16le(raw: bytes) -> bool:
    if len(raw) < 4:
        return False
    sample = raw[: min(len(raw), 512)]
    odd_nuls = sample[1::2].count(0)
    even_nuls = sample[0::2].count(0)
    return odd_nuls > len(sample) // 8 and odd_nuls > even_nuls * 2


def _read_report_text(report_path: Path) -> str:
    raw = report_path.read_bytes()
    encodings: list[str] = []
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        encodings.append("utf-16")
    if raw.startswith(b"\xef\xbb\xbf"):
        encodings.append("utf-8-sig")
    if _looks_utf16le(raw):
        encodings.append("utf-16-le")
    encodings.extend(["utf-8-sig", "utf-8", "utf-16", "utf-16-le"])
    for encoding in dict.fromkeys(encodings):
        try:
            text = raw.decode(encoding)
        except UnicodeError:
            continue
        if "<" in text or "Period" in text or "Deals" in text:
            return text
    return raw.decode("utf-8", errors="replace")


def _report_rows(report_path: Path) -> list[list[str]]:
    parser = _HtmlTableParser()
    parser.feed(_read_report_text(report_path))
    return parser.rows


def _normalize_cell(raw: str) -> str:
    return re.sub(r"\s+", " ", raw.strip().rstrip(":").lower())


def _parse_report_number(raw: str) -> float | None:
    match = re.search(r"-?[\d\s\xa0,.]+", raw)
    if not match:
        return None
    value = match.group(0).replace("\xa0", " ").strip().replace(" ", "")
    if "," in value and "." in value:
        value = value.replace(",", "")
    elif "," in value:
        value = value.replace(",", ".")
    try:
        return float(value)
    except ValueError:
        return None


def _parse_report_int(raw: str) -> int | None:
    value = _parse_report_number(raw)
    return None if value is None else int(value)


def _parse_report_datetime(raw: str) -> dt.datetime:
    return dt.datetime.strptime(raw.strip(), "%Y.%m.%d %H:%M:%S").replace(tzinfo=dt.UTC)


def _cell_after(rows: Sequence[Sequence[str]], label: str) -> str | None:
    target = _normalize_cell(label)
    for row in rows:
        for idx, cell in enumerate(row[:-1]):
            if _normalize_cell(cell) == target:
                return row[idx + 1]
    return None


def report_stats(rows: Sequence[Sequence[str]]) -> dict[str, Any]:
    return {
        "expert": _cell_after(rows, "Expert"),
        "symbol": _cell_after(rows, "Symbol"),
        "period": _cell_after(rows, "Period"),
        "net": _parse_report_number(_cell_after(rows, "Total Net Profit") or ""),
        "pf": _parse_report_number(_cell_after(rows, "Profit Factor") or ""),
        "total_trades": _parse_report_int(_cell_after(rows, "Total Trades") or ""),
    }


def _consume_exit(entry_queue: list[dict[str, Any]], exit_deal: dict[str, Any]) -> list[ClosedTrade]:
    exit_volume = float(exit_deal["volume"])
    if exit_volume <= 0.0:
        raise ValueError("exit volume must be positive")
    remaining = exit_volume
    out: list[ClosedTrade] = []
    tol = 1e-8
    while remaining > tol:
        if not entry_queue:
            raise ValueError(f"exit volume {exit_volume} exceeds open entry volume")
        entry = entry_queue[0]
        entry_remaining = float(entry.get("remaining_volume", entry["volume"]))
        matched = min(entry_remaining, remaining)
        exit_share = matched / exit_volume
        entry_share = matched / float(entry["volume"])
        entry["remaining_volume"] = entry_remaining - matched
        remaining -= matched
        profit = float(entry["profit"]) * entry_share + float(exit_deal["profit"]) * exit_share
        swap = float(entry["swap"]) * entry_share + float(exit_deal["swap"]) * exit_share
        commission = float(entry["commission"]) * entry_share + float(exit_deal["commission"]) * exit_share
        out.append(ClosedTrade(
            exit_time=exit_deal["time"], entry_time=entry["time"], symbol=str(entry["symbol"]),
            side=str(entry["side"]), net=profit + swap + commission,
            profit=profit, swap=swap, commission=commission,
        ))
        if float(entry["remaining_volume"]) <= tol:
            entry_queue.pop(0)
    return out


def extract_closed_trades(report_path: Path) -> tuple[list[ClosedTrade], dict[str, Any]]:
    """Parse native MT5 report.htm deals into FIFO-paired closed trades.

    Direction (in/out) + Type (buy/sell) drive pairing — NEVER P/L sign. Raises
    ValueError on any reconciliation failure (open entries, count mismatch).
    """
    rows = _report_rows(report_path)
    stats = report_stats(rows)
    in_deals = False
    headers: list[str] = []
    open_entries: dict[tuple[str, str], list[dict[str, Any]]] = {}
    trades: list[ClosedTrade] = []
    for row in rows:
        if len(row) == 1 and _normalize_cell(row[0]) == "deals":
            in_deals = True
            headers = []
            continue
        if not in_deals:
            continue
        if row and _normalize_cell(row[0]) == "time":
            headers = row
            continue
        if not headers or len(row) < len(headers):
            continue
        deal = dict(zip(headers, row))
        symbol = str(deal.get("Symbol") or "").strip()
        if not symbol:
            continue
        direction = _normalize_cell(str(deal.get("Direction") or ""))
        vol = _parse_report_number(str(deal.get("Volume") or ""))
        price = _parse_report_number(str(deal.get("Price") or ""))
        if vol is None or price is None:
            continue
        parsed = {
            "time": _parse_report_datetime(str(deal.get("Time") or "")),
            "symbol": symbol, "volume": float(vol), "price": float(price),
            "commission": _parse_report_number(str(deal.get("Commission") or "0")) or 0.0,
            "swap": _parse_report_number(str(deal.get("Swap") or "0")) or 0.0,
            "profit": _parse_report_number(str(deal.get("Profit") or "0")) or 0.0,
        }
        if direction == "in":
            side = _normalize_cell(str(deal.get("Type") or ""))
            if side not in {"buy", "sell"}:
                raise ValueError(f"unsupported entry type {side!r}")
            parsed["side"] = side
            parsed["remaining_volume"] = float(parsed["volume"])
            open_entries.setdefault((symbol, side), []).append(parsed)
            continue
        if direction != "out":
            continue
        exit_type = _normalize_cell(str(deal.get("Type") or ""))
        entry_side = "buy" if exit_type == "sell" else "sell" if exit_type == "buy" else ""
        key = (symbol, entry_side)
        if not entry_side or not open_entries.get(key):
            raise ValueError(f"{exit_type} exit has no matching entry")
        trades.extend(_consume_exit(open_entries[key], parsed))
    remaining = sum(len(q) for q in open_entries.values())
    if remaining:
        raise ValueError(f"{remaining} entry deals remain open")
    if not trades:
        raise ValueError("no closed round trips parsed")
    if stats.get("total_trades") is not None and stats["total_trades"] != len(trades):
        raise ValueError(f"parsed {len(trades)} trades, native report says {stats['total_trades']}")
    return trades, stats


# ===========================================================================
# Recency metrics (pure functions over closed trades)
# ===========================================================================
def profit_factor(nets: list[float]) -> float | None:
    """Q08-identical: sum(wins)/|sum(losses)|; None if no losses and no wins;
    inf if wins>0 and no losses."""
    wins = sum(p for p in nets if p > 0)
    losses = abs(sum(p for p in nets if p < 0))
    if losses == 0:
        return None if wins == 0 else float("inf")
    return wins / losses


def _yyyymm(ts: dt.datetime) -> int:
    return ts.year * 100 + ts.month


def _months_back(endpoint_yyyymm: int, months: int) -> int:
    """Inclusive lower bound yyyymm for a trailing window of `months` ending at
    endpoint (e.g. endpoint 202512, 24 months -> 202401)."""
    y, m = divmod(endpoint_yyyymm, 100)
    total = y * 12 + (m - 1) - (months - 1)
    return (total // 12) * 100 + (total % 12) + 1


def window_metrics(trades: list[ClosedTrade], lo_yyyymm: int | None,
                   hi_yyyymm: int | None) -> dict[str, Any]:
    """PF / trade count / net over [lo, hi] inclusive month range (None = open)."""
    nets: list[float] = []
    for t in trades:
        ym = _yyyymm(t.exit_time)
        if lo_yyyymm is not None and ym < lo_yyyymm:
            continue
        if hi_yyyymm is not None and ym > hi_yyyymm:
            continue
        nets.append(t.net)
    pf = profit_factor(nets)
    return {
        "pf": None if pf is None else (None if pf == float("inf") else round(pf, 4)),
        "pf_is_inf": pf == float("inf"),
        "trades": len(nets),
        "net": round(sum(nets), 2),
        "lo_yyyymm": lo_yyyymm,
        "hi_yyyymm": hi_yyyymm,
    }


def q08_half_vs_half(trades: list[ClosedTrade]) -> dict[str, Any]:
    """Replicates framework/scripts/q08_davey/sub_8_8_edge_decay.py exactly:
    monthly net buckets; high-freq (>=200 trades) rolling-12mo first vs last,
    else swing first-half vs second-half of active months. Threshold 40 %."""
    n = len(trades)
    if n < Q08_SWING_FLOOR:
        return {"status": "INVALID", "reason": f"insufficient_trade_count:got={n}:need>={Q08_SWING_FLOOR}"}
    monthly: dict[int, list[float]] = {}
    for t in trades:
        monthly.setdefault(_yyyymm(t.exit_time), []).append(t.net)
    months = sorted(monthly.keys())

    def trailing12(end_ym: int) -> float | None:
        cy, cm = divmod(end_ym, 100)
        win: list[float] = []
        for back in range(12):
            y, m = cy, cm - back
            while m <= 0:
                m += 12
                y -= 1
            win.extend(monthly.get(y * 100 + m, []))
        return profit_factor(win)

    if n >= Q08_HIGHFREQ_TRADES:
        if len(months) < Q08_HIGHFREQ_MIN_MONTHS:
            return {"status": "INVALID", "reason": f"insufficient_month_coverage:got={len(months)}:need>=24"}
        pf_first = trailing12(months[11])
        pf_last = trailing12(months[-1])
        mode = "rolling_12mo"
        meta = {"first_window_end_yyyymm": months[11], "last_window_end_yyyymm": months[-1]}
    else:
        if len(months) < Q08_SWING_MIN_MONTHS:
            return {"status": "INVALID", "reason": f"insufficient_month_coverage_swing:got={len(months)}:need>=12"}
        mid = len(months) // 2
        first_pl = [pl for m in months[:mid] for pl in monthly[m]]
        last_pl = [pl for m in months[mid:] for pl in monthly[m]]
        pf_first = profit_factor(first_pl)
        pf_last = profit_factor(last_pl)
        mode = "swing_half_vs_half"
        meta = {"first_half_yyyymm": [months[0], months[mid - 1]],
                "second_half_yyyymm": [months[mid], months[-1]]}

    if pf_first is None or pf_first <= 0 or pf_first == float("inf"):
        return {"status": "INVALID", "reason": f"first_window_pf_invalid:{pf_first}:mode={mode}", "decay_mode": mode}
    if pf_last is None:
        return {"status": "FAIL", "reason": f"last_window_no_losses_no_wins:mode={mode}",
                "pf_first": round(pf_first, 4), "pf_last": None, "decay_mode": mode, **meta}
    pf_last_val = float("inf") if pf_last == float("inf") else pf_last
    if pf_last_val == float("inf"):
        # last window all wins -> edge improved, decline negative (clamp for report)
        decline = -100.0
    else:
        decline = (pf_first - pf_last_val) / pf_first * 100.0
    status = "PASS" if decline < Q08_MAX_DECLINE_PCT else "FAIL"
    return {
        "status": status, "decline_pct": round(decline, 2), "threshold_pct": Q08_MAX_DECLINE_PCT,
        "pf_first": round(pf_first, 4),
        "pf_last": None if pf_last == float("inf") else round(pf_last_val, 4),
        "pf_last_is_inf": pf_last == float("inf"),
        "decay_mode": mode, "n_trades": n, "months_covered": len(months), **meta,
    }


def classify(*, recency_decline_pct: float | None, trailing24m_pf: float | None,
             trailing24m_trades: int, full_trades: int,
             q08_status: str | None, q08_decline_pct: float | None,
             parse_ok: bool = True, has_db_row: bool = True) -> dict[str, Any]:
    """Documented CURRENT / WATCH / DECAYED / UNKNOWN classifier.

    Order (first match wins for UNKNOWN gates; otherwise worst-of severity):
      1. no DB-authoritative Q10 row               -> UNKNOWN:no_db_q10_row
      2. parse/reconcile failure                   -> UNKNOWN:parse_or_reconcile_failure
      3. full trades < Q08_SWING_FLOOR (30)        -> UNKNOWN:insufficient_full_history_trades
      4. trailing-24m trades < MIN_TRAILING_TRADES -> UNKNOWN:insufficient_trailing24m_trades
      5. trailing-24m PF < 1.0                      -> DECAYED:trailing24m_pf_below_1
      6. Q08 half-split decline >= 40              -> DECAYED:q08_edge_decay_breach
      7. recency_decline_pct >= 25                 -> DECAYED:recency_pf_decline
         recency_decline_pct >= 20                 -> WATCH:recency_pf_decline
         else                                      -> CURRENT
    """
    if not has_db_row:
        return {"verdict": "UNKNOWN", "reason": "no_db_q10_row"}
    if not parse_ok:
        return {"verdict": "UNKNOWN", "reason": "parse_or_reconcile_failure"}
    if full_trades < Q08_SWING_FLOOR:
        return {"verdict": "UNKNOWN",
                "reason": f"insufficient_full_history_trades:got={full_trades}:need>={Q08_SWING_FLOOR}"}
    if trailing24m_trades < MIN_TRAILING_TRADES:
        return {"verdict": "UNKNOWN",
                "reason": f"insufficient_trailing24m_trades:got={trailing24m_trades}:need>={MIN_TRAILING_TRADES}"}

    reasons: list[str] = []
    verdict = "CURRENT"

    def bump(to: str) -> None:
        nonlocal verdict
        if SEVERITY[to] > SEVERITY[verdict]:
            verdict = to

    if trailing24m_pf is not None and trailing24m_pf < 1.0:
        bump("DECAYED")
        reasons.append(f"trailing24m_pf_below_1.0:pf={round(trailing24m_pf, 4)}")
    if q08_status == "FAIL" and q08_decline_pct is not None and q08_decline_pct >= Q08_MAX_DECLINE_PCT:
        bump("DECAYED")
        reasons.append(f"q08_edge_decay_breach:decline={q08_decline_pct}:>=40")
    if recency_decline_pct is not None:
        if recency_decline_pct >= RECENCY_DECAY_PCT:
            bump("DECAYED")
            reasons.append(f"recency_pf_decline:pct={round(recency_decline_pct, 2)}:>=25")
        elif recency_decline_pct >= RECENCY_WATCH_PCT:
            bump("WATCH")
            reasons.append(f"recency_pf_decline:pct={round(recency_decline_pct, 2)}:>=20")
        else:
            reasons.append(f"recency_pf_decline:pct={round(recency_decline_pct, 2)}:<20")
    else:
        # trailing-24m PF is inf (all wins) or undefined but trade floor met -> treat as CURRENT
        reasons.append("recency_decline_undefined_or_improving")
    return {"verdict": verdict, "reason": ";".join(reasons)}


def compute_recency(trades: list[ClosedTrade], stats: dict[str, Any] | None = None,
                    endpoint_yyyymm: int | None = None,
                    has_db_row: bool = True) -> dict[str, Any]:
    """Full recency computation from a parsed closed-trade list. Pure."""
    if endpoint_yyyymm is None:
        endpoint_yyyymm = max(_yyyymm(t.exit_time) for t in trades) if trades else None
    full = window_metrics(trades, None, None)
    result: dict[str, Any] = {
        "schema": RECENCY_SCHEMA_VERSION,
        "recency_axis_enforced": RECENCY_AXIS_ENFORCED,
        "endpoint_yyyymm": endpoint_yyyymm,
        "full": full,
        "native_pf": (stats or {}).get("pf"),
        "native_net": (stats or {}).get("net"),
        "native_total_trades": (stats or {}).get("total_trades"),
    }
    if endpoint_yyyymm is None:
        result["classification"] = classify(
            recency_decline_pct=None, trailing24m_pf=None, trailing24m_trades=0,
            full_trades=full["trades"], q08_status=None, q08_decline_pct=None,
            parse_ok=False, has_db_row=has_db_row)
        return result
    t24 = window_metrics(trades, _months_back(endpoint_yyyymm, TRAILING_24M_MONTHS), endpoint_yyyymm)
    t12 = window_metrics(trades, _months_back(endpoint_yyyymm, TRAILING_12M_MONTHS), endpoint_yyyymm)
    half = q08_half_vs_half(trades)
    pf_full = full["pf"]
    pf_t24 = t24["pf"]
    recency_decline = None
    if pf_full not in (None, 0) and pf_t24 is not None:
        recency_decline = (pf_full - pf_t24) / pf_full * 100.0
    result.update({
        "trailing_24m": t24,
        "trailing_12m": t12,
        "q08_half_vs_half": half,
        "recency_decline_pct": None if recency_decline is None else round(recency_decline, 2),
    })
    result["classification"] = classify(
        recency_decline_pct=recency_decline,
        trailing24m_pf=pf_t24,
        trailing24m_trades=t24["trades"],
        full_trades=full["trades"],
        q08_status=half.get("status"),
        q08_decline_pct=half.get("decline_pct"),
        parse_ok=True, has_db_row=has_db_row,
    )
    return result


def compute_recency_shadow(report_htm: str | Path | None,
                           endpoint_yyyymm: int | None = None, *,
                           setfile_path: str | Path | None = None,
                           ex5_path: str | Path | None = None,
                           window_endpoint: Any = None,
                           manifest_ref: str | Path | None = None) -> dict[str, Any]:
    """Live-path entry point for q10_confirmation.py. Fully guarded: any failure
    degrades to an UNKNOWN shadow record and NEVER raises into the Q10 verdict.

    The returned record ALWAYS carries an ``identity`` block binding the report /
    set / EX5 SHA-256 tuple, the window endpoint and the manifest reference (each
    unresolvable field is the explicit string ``"UNKNOWN"``), so the persisted Q10
    aggregate is cryptographically self-describing even when the trade-list parse
    itself degrades to UNKNOWN.
    """
    identity = evidence_identity(
        report_htm=report_htm, setfile_path=setfile_path, ex5_path=ex5_path,
        window_endpoint=window_endpoint, manifest_ref=manifest_ref,
    )
    base = {"schema": RECENCY_SCHEMA_VERSION,
            "recency_axis_enforced": RECENCY_AXIS_ENFORCED,
            "identity": identity}
    if not report_htm:
        return {**base, "status": "UNKNOWN", "reason": "no_report_htm"}
    try:
        path = Path(report_htm)
        if not path.exists():
            return {**base, "status": "UNKNOWN", "reason": "report_htm_missing"}
        trades, stats = extract_closed_trades(path)
        out = compute_recency(trades, stats, endpoint_yyyymm=endpoint_yyyymm, has_db_row=True)
        out["status"] = "OK"
        out["report_htm"] = str(path)
        out["identity"] = identity
        return out
    except Exception as exc:  # shadow must never break the verdict
        return {**base, "status": "UNKNOWN",
                "reason": f"shadow_compute_error:{type(exc).__name__}:{exc}"}
