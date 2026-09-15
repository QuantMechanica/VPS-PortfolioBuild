#!/usr/bin/env python3
"""Deterministic, read-only live per-sleeve PnL attribution from DXZ execution data.

OWNER directive 3 §33 / §43H / §44: the portfolio recomposition engine still lacks a
robust *realized live money* signal per sleeve.  This module builds that signal from the
real DXZ deal stream and writes ``D:/QM/reports/state/live_sleeve_attribution.json``
(schema ``qm.live-sleeve-attribution/v1``).

Source of truth (READ-ONLY, never written by this tool):

* deal stream: the AccountMonitor normalized deal export
  ``C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv``
  (written by ``framework/monitor/QM_AccountMonitor.mq5`` ~60 s after each new deal;
  ``net_actual = profit + swap + commission + fee`` per deal; a closed position's
  realized net is the sum of ``net_actual`` over ALL its deals grouped by ``position_id``).
* account snapshot: ``.../journal/account_snapshot.json`` (book-level equity / balance /
  floating_pnl / daily_pnl — used for book totals; per-sleeve floating is not exported).
* roster: ``D:/QM/reports/state/live_deployment_pointer.json`` →
  ``binary_setfile_fingerprint.per_sleeve`` (``magic_number`` + ``deployed_preset``).
  Magic scheme (Hard Rule): ``magic = ea_id*10000 + slot`` → ``ea_id = magic//10000``,
  ``slot = magic%10000``; symbol / timeframe / preset-slot decoded from the preset name.

The tool is deterministic and idempotent for a fixed input CSV + snapshot + pointer +
``--generated-at-utc``.  It performs NO T_Live writes, NO terminal control, NO order
actions and NO AutoTrading toggle (recorded in the ``authorization`` block).

Honest gaps (recorded, never invented):

* per-sleeve floating PnL is EVIDENCE_MISSING (only book-level floating is exported);
* the live correlation / overlap matrix is EVIDENCE_MISSING when the observed window has
  ``n_days < 20`` calendar days (statistically meaningless below that);
* dark sleeves (roster magics with zero closes) are reported as no-data, never zero-return.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA = "qm.live-sleeve-attribution/v1"

DEFAULT_DEALS_CSV = Path(
    r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv"
)
DEFAULT_ACCOUNT_SNAPSHOT = Path(
    r"C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\account_snapshot.json"
)
DEFAULT_POINTER = Path(r"D:\QM\reports\state\live_deployment_pointer.json")
DEFAULT_OUT = Path(r"D:\QM\reports\state\live_sleeve_attribution.json")

# Book base equity used as the denominator for contribution_to_book_return.  The DXZ
# account opened with a 100_000 USD deposit (first BALANCE row); this is a stable base
# so contribution is comparable across runs.  Overridden by the observed first deposit
# when present.
FALLBACK_BOOK_BASE_EQUITY = 100_000.0

CORRELATION_MIN_DAYS = 20  # below this the live matrix is statistically meaningless

EXIT_MARKERS = {"OUT", "OUT_BY", "INOUT"}
ENTRY_MARKERS = {"IN", "INOUT"}
TRADE_TYPES = {"BUY", "SELL"}


# --------------------------------------------------------------------------- utils
def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _file_pointer(path: Path) -> dict[str, Any]:
    p = Path(path)
    if not p.exists():
        return {"path": str(p), "status": "EVIDENCE_MISSING"}
    stat = p.stat()
    return {
        "path": str(p.resolve()),
        "status": "PRESENT",
        "sha256": _sha256(p),
        "size_bytes": stat.st_size,
        "mtime_utc": dt.datetime.fromtimestamp(stat.st_mtime, dt.timezone.utc).isoformat(),
    }


def _to_float(raw: Any) -> float:
    try:
        return float(str(raw).strip())
    except (TypeError, ValueError):
        return 0.0


def _to_int(raw: Any) -> int:
    try:
        return int(str(raw).strip())
    except (TypeError, ValueError):
        return 0


def _freshness(mtime_utc: str | None, generated_at_utc: str) -> dict[str, Any]:
    if not mtime_utc:
        return {"status": "EVIDENCE_MISSING", "age_seconds": None}
    try:
        m = dt.datetime.fromisoformat(mtime_utc.replace("Z", "+00:00"))
        g = dt.datetime.fromisoformat(generated_at_utc.replace("Z", "+00:00"))
        age = (g - m).total_seconds()
    except ValueError:
        return {"status": "UNKNOWN", "age_seconds": None}
    label = "FRESH" if age <= 3600 else ("STALE" if age <= 86400 else "VERY_STALE")
    return {"status": label, "age_seconds": round(age, 1), "mtime_utc": mtime_utc}


# --------------------------------------------------------------------------- roster
def _decode_preset(preset_path: str) -> dict[str, str]:
    """Decode ``<slot>_<SYMBOL>_<TF>_QM5_<eaid>_<slug>.set`` into its parts."""
    stem = Path(str(preset_path)).stem
    parts = stem.split("_")
    return {
        "preset_slot": parts[0] if len(parts) >= 1 else "",
        "symbol": parts[1] if len(parts) >= 2 else "",
        "timeframe": parts[2] if len(parts) >= 3 else "",
        "preset_ea_id": parts[4] if len(parts) >= 5 else "",
    }


def load_roster(pointer_path: Path) -> dict[int, dict[str, Any]]:
    """magic -> {ea_id, symbol, slot, timeframe, preset, preset_slot} from the deploy pointer."""
    payload = json.loads(Path(pointer_path).read_text(encoding="utf-8-sig"))
    rows = payload.get("binary_setfile_fingerprint", {}).get("per_sleeve", [])
    roster: dict[int, dict[str, Any]] = {}
    for row in rows:
        magic = _to_int(row.get("magic_number"))
        if magic <= 0:
            continue
        decoded = _decode_preset(str(row.get("deployed_preset", "")))
        roster[magic] = {
            "magic": magic,
            "ea_id": magic // 10000,
            "slot": magic % 10000,
            "symbol": decoded["symbol"],
            "timeframe": decoded["timeframe"],
            "preset_slot": decoded["preset_slot"],
            "deployed_preset": str(row.get("deployed_preset", "")),
        }
    return roster


# --------------------------------------------------------------------------- deals
def read_deals(source: Path) -> list[dict[str, str]]:
    with Path(source).open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    if rows and ("position_id" not in rows[0] or "net_actual" not in rows[0]):
        raise ValueError("deal export schema missing position_id/net_actual")
    return rows


def _resolve_magic(rows: Sequence[Mapping[str, str]]) -> int:
    for row in rows:
        for field in ("logical_magic", "deal_magic", "magic"):
            value = str(row.get(field, "") or "").strip()
            if value and _to_int(value):
                return _to_int(value)
    return 0


def closed_positions(rows: Sequence[Mapping[str, str]], start_utc: str) -> list[dict[str, Any]]:
    """Group trade deals by position_id; keep positions whose final exit >= start_utc.

    Each result carries the full realized cost breakdown for the position lifecycle.
    """
    by_position: dict[int, list[Mapping[str, str]]] = defaultdict(list)
    for row in rows:
        if str(row.get("type", "")).upper() not in TRADE_TYPES:
            continue
        pid = _to_int(row.get("position_id"))
        if pid > 0:
            by_position[pid].append(row)

    out: list[dict[str, Any]] = []
    for pid, lifecycle in by_position.items():
        life = sorted(lifecycle, key=lambda r: (str(r.get("time_utc", "")), _to_int(r.get("deal_id"))))
        exits = [r for r in life if str(r.get("entry", "")).upper() in EXIT_MARKERS]
        entries = [r for r in life if str(r.get("entry", "")).upper() in ENTRY_MARKERS]
        if not exits or not entries:
            continue
        closed_at = max(str(r.get("time_utc", "")) for r in exits)
        if closed_at < start_utc:
            continue
        opened = min(entries, key=lambda r: (str(r.get("time_utc", "")), _to_int(r.get("deal_id"))))
        gross = sum(_to_float(r.get("profit")) for r in life)
        swap = sum(_to_float(r.get("swap")) for r in life)
        commission = sum(_to_float(r.get("commission")) + _to_float(r.get("fee")) for r in life)
        net = sum(_to_float(r.get("net_actual")) for r in life)
        out.append({
            "position_id": pid,
            "magic": _resolve_magic(life),
            "symbol": next((str(r.get("symbol")) for r in life if r.get("symbol")), ""),
            "opened_at_utc": str(opened.get("time_utc", "")),
            "closed_at_utc": closed_at,
            "close_date_utc": closed_at[:10],
            "lots": sum(_to_float(r.get("volume")) for r in entries),
            "gross": gross,
            "swap": swap,
            "commission": commission,
            "net": net,
        })
    return sorted(out, key=lambda r: (r["closed_at_utc"], r["position_id"]))


def _max_drawdown(sequence: Sequence[float]) -> float:
    """Max peak-to-trough drop of the cumulative sum of ``sequence`` (money, >= 0)."""
    peak = 0.0
    cum = 0.0
    dd = 0.0
    for value in sequence:
        cum += value
        peak = max(peak, cum)
        dd = max(dd, peak - cum)
    return dd


def _book_base_equity(rows: Sequence[Mapping[str, str]]) -> float:
    """First deposit (initial BALANCE row) as the contribution denominator, else fallback."""
    for row in rows:
        if str(row.get("type", "")).upper() == "BALANCE" and _to_float(row.get("net_actual")) > 0:
            return _to_float(row.get("net_actual"))
    return FALLBACK_BOOK_BASE_EQUITY


# --------------------------------------------------------------------------- aggregation
def _aggregate_sleeve(
    magic: int,
    positions: Sequence[Mapping[str, Any]],
    roster_row: Mapping[str, Any] | None,
    book_base_equity: float,
    book_realized_dd: float,
    data_source: Mapping[str, Any],
    freshness: Mapping[str, Any],
) -> dict[str, Any]:
    realized = round(sum(p["net"] for p in positions), 2)
    gross = round(sum(p["gross"] for p in positions), 2)
    swap = round(sum(p["swap"] for p in positions), 2)
    commission = round(sum(p["commission"] for p in positions), 2)
    ordered = sorted(positions, key=lambda p: (p["closed_at_utc"], p["position_id"]))
    realized_dd = round(_max_drawdown([p["net"] for p in ordered]), 2)
    symbols = sorted({p["symbol"] for p in positions if p["symbol"]})
    if not symbols and roster_row and roster_row.get("symbol"):
        symbols = [roster_row["symbol"]]
    contribution_return = (
        round(realized / book_base_equity, 8) if book_base_equity else None
    )
    contribution_dd = (
        round(realized_dd / book_realized_dd, 8) if book_realized_dd > 0 else None
    )
    return {
        "magic": magic,
        "ea_id": (roster_row or {}).get("ea_id", magic // 10000 if magic else None),
        "symbol": symbols[0] if symbols else ((roster_row or {}).get("symbol") or "UNKNOWN"),
        "symbols_observed": symbols,
        "slot": (roster_row or {}).get("slot", magic % 10000 if magic else None),
        "timeframe": (roster_row or {}).get("timeframe", "UNKNOWN"),
        "in_current_roster": roster_row is not None,
        "trade_count": len(positions),
        "flat": len(positions) == 0,
        "realized_pnl": realized,
        "floating_pnl": "EVIDENCE_MISSING",  # per-sleeve floating is not exported (book-level only)
        "gross": gross,
        "net": realized,
        "swap": swap,
        "commission": commission,
        "realized_dd": realized_dd,
        "contribution_to_book_return": contribution_return,
        "contribution_to_book_dd": contribution_dd,
        "since_utc": ordered[0]["closed_at_utc"] if ordered else None,
        "last_deal_utc": ordered[-1]["closed_at_utc"] if ordered else None,
        "data_source": data_source.get("path"),
        "freshness": freshness.get("status", "UNKNOWN"),
    }


def _daily_series(positions: Sequence[Mapping[str, Any]], calendar: Sequence[str]) -> list[float]:
    by_day: dict[str, float] = defaultdict(float)
    for p in positions:
        by_day[p["close_date_utc"]] += p["net"]
    return [round(by_day.get(day, 0.0), 6) for day in calendar]


def _pearson(a: Sequence[float], b: Sequence[float]) -> float | None:
    n = len(a)
    if n < 2:
        return None
    ma = sum(a) / n
    mb = sum(b) / n
    cov = sum((a[i] - ma) * (b[i] - mb) for i in range(n))
    va = sum((a[i] - ma) ** 2 for i in range(n))
    vb = sum((b[i] - mb) ** 2 for i in range(n))
    if va <= 0.0 or vb <= 0.0:
        return None  # a flat series has no defined correlation
    return round(cov / math.sqrt(va * vb), 6)


def _correlation_matrix(
    positions: Sequence[Mapping[str, Any]],
    roster: Mapping[int, Mapping[str, Any]],
) -> dict[str, Any]:
    dates = sorted({p["close_date_utc"] for p in positions if p["close_date_utc"]})
    if not dates:
        return {"status": "EVIDENCE_MISSING", "reason": "no_closed_positions", "n_days": 0}
    start = dt.date.fromisoformat(dates[0])
    end = dt.date.fromisoformat(dates[-1])
    n_days = (end - start).days + 1
    if n_days < CORRELATION_MIN_DAYS:
        return {
            "status": "EVIDENCE_MISSING",
            "reason": f"n_days<{CORRELATION_MIN_DAYS}",
            "n_days": n_days,
        }
    calendar = [(start + dt.timedelta(days=i)).isoformat() for i in range(n_days)]
    by_magic: dict[int, list[Mapping[str, Any]]] = defaultdict(list)
    for p in positions:
        if p["magic"]:
            by_magic[p["magic"]].append(p)
    series = {m: _daily_series(rows, calendar) for m, rows in by_magic.items()}
    magics = sorted(m for m, s in series.items() if any(v != 0.0 for v in s))
    pairs: list[dict[str, Any]] = []
    for i in range(len(magics)):
        for j in range(i + 1, len(magics)):
            mi, mj = magics[i], magics[j]
            corr = _pearson(series[mi], series[mj])
            overlap = sum(
                1 for k in range(n_days) if series[mi][k] != 0.0 and series[mj][k] != 0.0
            )
            pairs.append({
                "a_magic": mi,
                "a_ea_id": (roster.get(mi) or {}).get("ea_id", mi // 10000),
                "b_magic": mj,
                "b_ea_id": (roster.get(mj) or {}).get("ea_id", mj // 10000),
                "correlation": corr if corr is not None else "UNDEFINED_FLAT_SERIES",
                "overlap_days": overlap,
            })
    return {
        "status": "PRESENT",
        "n_days": n_days,
        "window": {"start": calendar[0], "end": calendar[-1]},
        "basis": "Pearson correlation of daily realized-net sleeve PnL (0 on no-close days)",
        "sleeves_scored": len(magics),
        "pairs": pairs,
    }


# --------------------------------------------------------------------------- build
def build(
    *,
    deals_csv: Path = DEFAULT_DEALS_CSV,
    account_snapshot: Path = DEFAULT_ACCOUNT_SNAPSHOT,
    pointer: Path = DEFAULT_POINTER,
    start_utc: str = "2026-07-24T00:00:00Z",
    generated_at_utc: str,
) -> dict[str, Any]:
    deals_ptr = _file_pointer(deals_csv)
    pointer_ptr = _file_pointer(pointer)
    snapshot_ptr = _file_pointer(account_snapshot)
    freshness = _freshness(deals_ptr.get("mtime_utc"), generated_at_utc)

    authorization = {
        "t_live_write": False,
        "terminal_control": False,
        "autotrading_toggle": False,
        "order_action": False,
    }

    if deals_ptr["status"] != "PRESENT":
        return {
            "schema": SCHEMA,
            "generated_at_utc": generated_at_utc,
            "mode": "READ_ONLY_T_LIVE_INPUT",
            "status": "EVIDENCE_MISSING",
            "reason": "live_deals_normalized.csv absent — enable QM_AccountMonitor export",
            "source": deals_ptr,
            "pointer": pointer_ptr,
            "account_snapshot": snapshot_ptr,
            "sleeves": [],
            "book_totals": {"status": "EVIDENCE_MISSING"},
            "correlation_matrix": {"status": "EVIDENCE_MISSING", "reason": "no_source"},
            "health": {
                "source_present": False,
                "deals_parsed": 0,
                "roster_size": 0,
                "mapped_sleeves": 0,
                "unmapped_magics": [],
                "dark_sleeves": [],
            },
            "authorization": authorization,
        }

    rows = read_deals(deals_csv)
    roster = load_roster(pointer) if pointer_ptr["status"] == "PRESENT" else {}
    positions = closed_positions(rows, start_utc)
    book_base_equity = _book_base_equity(rows)

    # Book-level realized DD from the chronological book realized-net curve.
    ordered_book = sorted(positions, key=lambda p: (p["closed_at_utc"], p["position_id"]))
    book_realized_dd = round(_max_drawdown([p["net"] for p in ordered_book]), 2)

    observed_nonzero = {p["magic"] for p in positions if p["magic"] != 0}
    all_magics = sorted(set(roster) | observed_nonzero)

    sleeves = []
    for magic in all_magics:
        sleeve_positions = [p for p in positions if p["magic"] == magic]
        sleeves.append(_aggregate_sleeve(
            magic, sleeve_positions, roster.get(magic),
            book_base_equity, book_realized_dd, deals_ptr, freshness,
        ))
    manual = _aggregate_sleeve(
        0, [p for p in positions if p["magic"] == 0], None,
        book_base_equity, book_realized_dd, deals_ptr, freshness,
    )

    # Book totals.
    book_realized = round(sum(p["net"] for p in positions), 2)
    snapshot_payload: dict[str, Any] = {}
    if snapshot_ptr["status"] == "PRESENT":
        try:
            snapshot_payload = json.loads(Path(account_snapshot).read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            snapshot_payload = {}

    book_totals = {
        "book_base_equity": round(book_base_equity, 2),
        "realized_pnl": book_realized,
        "gross": round(sum(p["gross"] for p in positions), 2),
        "swap": round(sum(p["swap"] for p in positions), 2),
        "commission": round(sum(p["commission"] for p in positions), 2),
        "net": book_realized,
        "trade_count": len(positions),
        "realized_dd": book_realized_dd,
        "realized_return_pct": (
            round(100.0 * book_realized / book_base_equity, 4) if book_base_equity else None
        ),
        "window": {
            "start_utc": start_utc,
            "last_deal_utc": max((str(r.get("time_utc", "")) for r in rows), default=None),
        },
        # Book-level live account state (per-sleeve floating is not exported).
        "account_equity": snapshot_payload.get("equity", "EVIDENCE_MISSING"),
        "account_balance": snapshot_payload.get("balance", "EVIDENCE_MISSING"),
        "account_floating_pnl": snapshot_payload.get("floating_pnl", "EVIDENCE_MISSING"),
        "account_open_positions": snapshot_payload.get("open_positions", "EVIDENCE_MISSING"),
        "account_snapshot_utc": snapshot_payload.get("time_utc", "EVIDENCE_MISSING"),
    }

    correlation = _correlation_matrix(positions, roster)

    unmapped = sorted(m for m in observed_nonzero if m not in roster)
    dark = sorted(
        m for m in roster if not any(p["magic"] == m for p in positions)
    )
    health = {
        "source_present": True,
        "source_freshness": freshness,
        "deals_parsed": len(rows),
        "closed_positions": len(positions),
        "roster_size": len(roster),
        "mapped_sleeves": sum(1 for s in sleeves if s["in_current_roster"]),
        "unmapped_magics": unmapped,
        "unmapped_note": "magics observed in the live deal stream that are not in the current deploy pointer roster (historical or T1-T10 mirror lines)",
        "dark_sleeves": dark,
        "dark_note": "roster sleeves with zero closed positions in the window — treat as no-data, never zero-return",
        "per_sleeve_floating_status": "EVIDENCE_MISSING",
        "per_sleeve_floating_note": "AccountMonitor exports only book-level floating_pnl; per-sleeve floating needs an open-positions export (not attached by any AI seat).",
    }

    return {
        "schema": SCHEMA,
        "generated_at_utc": generated_at_utc,
        "mode": "READ_ONLY_T_LIVE_INPUT",
        "status": "PRESENT",
        "definitions": {
            "realized_pnl": "sum(net_actual) over all deals of positions closed within the window (== net)",
            "gross": "sum(profit) over lifecycle deals (before swap/commission/fee)",
            "net": "gross + swap + commission (== realized_pnl); net_actual is authoritative",
            "swap": "sum(swap) over lifecycle deals",
            "commission": "sum(commission + fee) over lifecycle deals (negative = cost)",
            "realized_dd": "max peak-to-trough drop (money) of the sleeve's cumulative realized-net curve",
            "floating_pnl": "EVIDENCE_MISSING per sleeve — only book-level floating is exported",
            "contribution_to_book_return": "sleeve realized_pnl / book_base_equity (fraction)",
            "contribution_to_book_dd": "sleeve realized_dd / book realized_dd (approximate DD share; None when book DD is 0)",
            "correlation_matrix": f"Pearson correlation of daily realized-net sleeve PnL; EVIDENCE_MISSING when n_days < {CORRELATION_MIN_DAYS}",
        },
        "source": deals_ptr,
        "pointer": pointer_ptr,
        "account_snapshot": snapshot_ptr,
        "window": {"start_utc": start_utc},
        "sleeves": sleeves,
        "manual_magic_0": manual,
        "book_totals": book_totals,
        "correlation_matrix": correlation,
        "health": health,
        "authorization": authorization,
    }


def write_output(model: Mapping[str, Any], out_path: Path) -> Path:
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    return out_path


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--deals-csv", type=Path, default=DEFAULT_DEALS_CSV)
    parser.add_argument("--account-snapshot", type=Path, default=DEFAULT_ACCOUNT_SNAPSHOT)
    parser.add_argument("--pointer", type=Path, default=DEFAULT_POINTER)
    parser.add_argument("--start-utc", default="2026-07-24T00:00:00Z")
    parser.add_argument("--generated-at-utc", default=None,
                        help="Fixed UTC stamp for deterministic output; defaults to now.")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)

    generated_at = args.generated_at_utc or (
        dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    )
    model = build(
        deals_csv=args.deals_csv,
        account_snapshot=args.account_snapshot,
        pointer=args.pointer,
        start_utc=args.start_utc,
        generated_at_utc=generated_at,
    )
    out = write_output(model, args.out)
    print(json.dumps({
        "out": str(out),
        "status": model["status"],
        "sleeves": len(model["sleeves"]),
        "closed_positions": model.get("book_totals", {}).get("trade_count"),
        "book_realized_pnl": model.get("book_totals", {}).get("realized_pnl"),
        "correlation_status": model.get("correlation_matrix", {}).get("status"),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
