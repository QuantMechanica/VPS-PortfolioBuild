#!/usr/bin/env python3
"""Deterministic FTMO sleeve dependence matrix.

The matrix is deliberately broader than Pearson correlation.  It measures
daily losses and tails, trading-day overlap, position-time and direction
overlap, entry clustering, shared economic labels, and simultaneous MAE-based
open-risk.  Input trades are real chronological closed-trade records prepared
by :mod:`tools.strategy_farm.ftmo.book_sim`.

This module is read-only toward terminals, farm state and trading accounts.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import math
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence
from zoneinfo import ZoneInfo

import numpy as np


SCHEMA = "qm.ftmo-book-dependence-matrix/v1"
DEFAULT_TZ = "Europe/Prague"


def _as_epoch(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.timezone.utc)
    return parsed.timestamp()


def _business_days(start: dt.date, end: dt.date) -> list[dt.date]:
    out: list[dt.date] = []
    cur = start
    while cur <= end:
        if cur.weekday() < 5:
            out.append(cur)
        cur += dt.timedelta(days=1)
    return out


def _corr(a: np.ndarray, b: np.ndarray) -> float | None:
    if a.size < 3 or b.size < 3 or np.std(a) <= 1e-12 or np.std(b) <= 1e-12:
        return None
    value = float(np.corrcoef(a, b)[0, 1])
    return round(value, 6) if math.isfinite(value) else None


def _ratio(observed: float, expected: float) -> float | None:
    if expected <= 0.0:
        return None
    return round(observed / expected, 6)


def _merge_intervals(intervals: Iterable[tuple[float, float]]) -> list[tuple[float, float]]:
    ordered = sorted((a, b) for a, b in intervals if b > a)
    if not ordered:
        return []
    merged = [ordered[0]]
    for start, end in ordered[1:]:
        old_start, old_end = merged[-1]
        if start <= old_end:
            merged[-1] = (old_start, max(old_end, end))
        else:
            merged.append((start, end))
    return merged


def _intersection_seconds(
    left: Sequence[tuple[float, float]], right: Sequence[tuple[float, float]]
) -> float:
    i = j = 0
    total = 0.0
    while i < len(left) and j < len(right):
        start = max(left[i][0], right[j][0])
        end = min(left[i][1], right[j][1])
        if end > start:
            total += end - start
        if left[i][1] <= right[j][1]:
            i += 1
        else:
            j += 1
    return total


def _direction_overlap(
    left: Sequence[Mapping[str, Any]], right: Sequence[Mapping[str, Any]]
) -> tuple[float, float | None]:
    total = same = 0.0
    for a in left:
        a0, a1 = _as_epoch(a["entry_time"]), _as_epoch(a["close_time"])
        for b in right:
            b0, b1 = _as_epoch(b["entry_time"]), _as_epoch(b["close_time"])
            if b0 >= a1:
                break
            if b1 <= a0:
                continue
            overlap = max(0.0, min(a1, b1) - max(a0, b0))
            total += overlap
            if str(a.get("side", "")).upper() == str(b.get("side", "")).upper():
                same += overlap
    return total, (round(same / total, 6) if total > 0.0 else None)


def _entry_overlap_share(
    left: Sequence[Mapping[str, Any]], right: Sequence[Mapping[str, Any]], window_seconds: int = 1800
) -> float | None:
    a = sorted(_as_epoch(t["entry_time"]) for t in left)
    b = sorted(_as_epoch(t["entry_time"]) for t in right)
    if not a or not b:
        return None
    matched = 0
    j = 0
    for stamp in a:
        while j < len(b) and b[j] < stamp - window_seconds:
            j += 1
        if j < len(b) and abs(b[j] - stamp) <= window_seconds:
            matched += 1
        elif j > 0 and abs(b[j - 1] - stamp) <= window_seconds:
            matched += 1
    return round(matched / min(len(a), len(b)), 6)


def _simultaneous_open_risk(
    left: Sequence[Mapping[str, Any]], right: Sequence[Mapping[str, Any]]
) -> float:
    events: list[tuple[float, int, str, float]] = []
    for label, trades in (("a", left), ("b", right)):
        for trade in trades:
            risk = abs(float(trade.get("mae_scaled") or 0.0))
            start = _as_epoch(trade["entry_time"])
            end = _as_epoch(trade["close_time"])
            if end <= start:
                continue
            events.append((start, 1, label, risk))
            events.append((end, 0, label, -risk))
    active = {"a": 0.0, "b": 0.0}
    peak = 0.0
    for _, order, label, delta in sorted(events, key=lambda row: (row[0], row[1])):
        active[label] = max(0.0, active[label] + delta)
        if active["a"] > 0.0 and active["b"] > 0.0:
            peak = max(peak, active["a"] + active["b"])
    return round(peak, 2)


def _daily_series(
    sleeve: Mapping[str, Any], tz: ZoneInfo
) -> tuple[dict[dt.date, float], set[dt.date]]:
    pnl: dict[dt.date, float] = {}
    traded: set[dt.date] = set()
    for trade in sleeve.get("trades") or []:
        close = dt.datetime.fromtimestamp(_as_epoch(trade["close_time"]), dt.timezone.utc)
        entry = dt.datetime.fromtimestamp(_as_epoch(trade["entry_time"]), dt.timezone.utc)
        close_day = close.astimezone(tz).date()
        entry_day = entry.astimezone(tz).date()
        pnl[close_day] = pnl.get(close_day, 0.0) + float(trade.get("net_scaled") or 0.0)
        traded.add(entry_day)
    return pnl, traded


def _tail_days(values: Mapping[dt.date, float], fraction: float = 0.10) -> set[dt.date]:
    losses = sorted(((value, day) for day, value in values.items() if value < 0.0))
    if not losses:
        return set()
    count = max(1, int(math.ceil(len(losses) * fraction)))
    return {day for _, day in losses[:count]}


def _worst_days(values: Mapping[dt.date, float], count: int = 20) -> set[dt.date]:
    return {day for _, day in sorted((value, day) for day, value in values.items())[:count]}


def _pair_row(
    left: Mapping[str, Any], right: Mapping[str, Any], tz: ZoneInfo
) -> dict[str, Any]:
    left_pnl, left_trade_days = _daily_series(left, tz)
    right_pnl, right_trade_days = _daily_series(right, tz)
    all_days = sorted(set(left_pnl) | set(right_pnl) | left_trade_days | right_trade_days)
    if all_days:
        grid = _business_days(min(all_days), max(all_days))
    else:
        grid = []
    a = np.asarray([left_pnl.get(day, 0.0) for day in grid], dtype=float)
    b = np.asarray([right_pnl.get(day, 0.0) for day in grid], dtype=float)
    n = max(1, len(grid))

    loss_a = {day for day, value in left_pnl.items() if value < 0.0}
    loss_b = {day for day, value in right_pnl.items() if value < 0.0}
    loss_observed = len(loss_a & loss_b) / n
    loss_expected = (len(loss_a) / n) * (len(loss_b) / n)
    trade_observed = len(left_trade_days & right_trade_days) / n
    trade_expected = (len(left_trade_days) / n) * (len(right_trade_days) / n)

    tail_a, tail_b = _tail_days(left_pnl), _tail_days(right_pnl)
    tail_observed = len(tail_a & tail_b) / n
    tail_expected = (len(tail_a) / n) * (len(tail_b) / n)
    downside_mask = (a < 0.0) | (b < 0.0)

    left_trades = sorted(left.get("trades") or [], key=lambda t: _as_epoch(t["entry_time"]))
    right_trades = sorted(right.get("trades") or [], key=lambda t: _as_epoch(t["entry_time"]))
    left_intervals = _merge_intervals(
        (_as_epoch(t["entry_time"]), _as_epoch(t["close_time"])) for t in left_trades
    )
    right_intervals = _merge_intervals(
        (_as_epoch(t["entry_time"]), _as_epoch(t["close_time"])) for t in right_trades
    )
    overlap_seconds = _intersection_seconds(left_intervals, right_intervals)
    left_seconds = sum(end - start for start, end in left_intervals)
    right_seconds = sum(end - start for start, end in right_intervals)
    overlap_share = (
        round(overlap_seconds / min(left_seconds, right_seconds), 6)
        if min(left_seconds, right_seconds) > 0.0 else None
    )

    same_symbol = str(left.get("symbol")) == str(right.get("symbol"))
    raw_overlap, direction_share = _direction_overlap(left_trades, right_trades)
    worst_a, worst_b = _worst_days(left_pnl), _worst_days(right_pnl)
    worst_overlap = len(worst_a & worst_b)

    def common(field: str) -> bool:
        a_value = str(left.get(field) or "").strip().upper()
        b_value = str(right.get(field) or "").strip().upper()
        return bool(a_value and b_value and a_value not in {"UNKNOWN", "UNSPECIFIED"}
                    and a_value == b_value)

    return {
        "pair": f"{left['id']}/{right['id']}",
        "left_id": left["id"],
        "right_id": right["id"],
        "symbols": f"{left.get('symbol')}/{right.get('symbol')}",
        "business_days": len(grid),
        "daily_pnl_correlation": _corr(a, b),
        "downside_correlation": _corr(a[downside_mask], b[downside_mask]),
        "loss_day_overlap_days": len(loss_a & loss_b),
        "loss_day_overlap_ratio_vs_independence": _ratio(loss_observed, loss_expected),
        "trade_day_overlap_days": len(left_trade_days & right_trade_days),
        "trade_day_overlap_ratio_vs_independence": _ratio(trade_observed, trade_expected),
        "position_overlap_hours": round(overlap_seconds / 3600.0, 3),
        "position_overlap_share_of_smaller_exposure": overlap_share,
        "same_direction_share_when_overlapping": direction_share if same_symbol else None,
        "same_symbol_entry_within_30m_share": (
            _entry_overlap_share(left_trades, right_trades) if same_symbol else None
        ),
        "lower_tail_coexceed_days": len(tail_a & tail_b),
        "lower_tail_coexceed_ratio_vs_independence": _ratio(tail_observed, tail_expected),
        "worst_20_day_overlap": worst_overlap,
        "worst_20_day_overlap_ratio_vs_independence": _ratio(
            worst_overlap / n, (len(worst_a) / n) * (len(worst_b) / n)
        ),
        "common_session": common("session"),
        "common_news_window": common("news_profile"),
        "common_symbol": same_symbol,
        "common_family": common("family"),
        "simultaneous_open_risk_max_usd_mae_proxy": _simultaneous_open_risk(
            left_trades, right_trades
        ),
        "proxy_notes": {
            "position_overlap": "exact entry/close interval overlap from closed trades",
            "direction_overlap": "same-side seconds divided by all raw pairwise overlap seconds",
            "open_risk": "sum of scaled per-trade MAE magnitudes while both sleeves are open",
            "tail": "bottom decile of each sleeve's strictly losing Prague close-days",
        },
    }


def _cluster_edges(rows: Sequence[Mapping[str, Any]]) -> list[tuple[str, str]]:
    edges: list[tuple[str, str]] = []
    for row in rows:
        corr = row.get("daily_pnl_correlation")
        loss = row.get("loss_day_overlap_ratio_vs_independence")
        tail = row.get("lower_tail_coexceed_ratio_vs_independence")
        pos = row.get("position_overlap_share_of_smaller_exposure")
        # A sparse tail coincidence alone is not enough to connect two sleeves:
        # require corroboration in correlation/loss overlap, or exact same-symbol
        # co-exposure. This prevents a chain of unrelated one-day coincidences
        # from turning the whole book into one misleading giant component.
        flagged = (
            (corr is not None and corr >= 0.50
             and ((loss is not None and loss >= 1.5) or (tail is not None and tail >= 1.5)))
            or (loss is not None and loss >= 2.0 and tail is not None and tail >= 2.0)
            or (row.get("common_symbol") and pos is not None and pos >= 0.25)
        )
        if flagged:
            edges.append((str(row["left_id"]), str(row["right_id"])))
    return edges


def _components(ids: Sequence[str], edges: Sequence[tuple[str, str]]) -> list[list[str]]:
    adjacent = {item: set() for item in ids}
    for left, right in edges:
        adjacent.setdefault(left, set()).add(right)
        adjacent.setdefault(right, set()).add(left)
    seen: set[str] = set()
    out: list[list[str]] = []
    for node in ids:
        if node in seen or not adjacent.get(node):
            continue
        stack = [node]
        component: list[str] = []
        while stack:
            cur = stack.pop()
            if cur in seen:
                continue
            seen.add(cur)
            component.append(cur)
            stack.extend(sorted(adjacent.get(cur, set()) - seen, reverse=True))
        if len(component) > 1:
            out.append(sorted(component))
    return sorted(out)


def _top_pair(
    rows: Sequence[Mapping[str, Any]], edges: Sequence[tuple[str, str]]
) -> Mapping[str, Any] | None:
    if not rows:
        return None

    edge_set = {frozenset(edge) for edge in edges}
    clustered = [
        row for row in rows
        if frozenset((str(row["left_id"]), str(row["right_id"]))) in edge_set
    ]
    candidates = clustered or list(rows)

    def severity(row: Mapping[str, Any]) -> tuple[float, float, float, float]:
        return (
            float(row.get("loss_day_overlap_ratio_vs_independence") or 0.0),
            float(row.get("lower_tail_coexceed_ratio_vs_independence") or 0.0),
            float(row.get("position_overlap_share_of_smaller_exposure") or 0.0),
            float(row.get("daily_pnl_correlation") or 0.0),
        )

    return max(candidates, key=severity)


def compute_dependence_matrix(
    sleeves: Sequence[Mapping[str, Any]], *, timezone: str = DEFAULT_TZ,
    generated_at_utc: str | None = None,
) -> dict[str, Any]:
    tz = ZoneInfo(timezone)
    ordered = sorted(sleeves, key=lambda s: str(s["id"]))
    rows = [
        _pair_row(ordered[i], ordered[j], tz)
        for i in range(len(ordered))
        for j in range(i + 1, len(ordered))
    ]
    edges = _cluster_edges(rows)
    clusters = _components([str(s["id"]) for s in ordered], edges)
    top = _top_pair(rows, edges)
    return {
        "schema": SCHEMA,
        "generated_at_utc": generated_at_utc,
        "timezone": timezone,
        "sleeves": [
            {
                "id": s["id"], "ea_id": s.get("ea_id"), "symbol": s.get("symbol"),
                "timeframe": s.get("timeframe"), "family": s.get("family"),
                "session": s.get("session"), "trades": len(s.get("trades") or []),
            }
            for s in ordered
        ],
        "pairs": rows,
        "summary": {
            "top_fail_together_pair": dict(top) if top else None,
            "fail_together_clusters": clusters,
            "cluster_rule": (
                "edge when correlation >=0.50 is corroborated by loss/tail overlap, "
                "loss and tail are both >=2x independence, or same-symbol position "
                "overlap is >=25% of smaller exposure"
            ),
            "max_abs_daily_correlation": max(
                (abs(float(r["daily_pnl_correlation"])) for r in rows
                 if r.get("daily_pnl_correlation") is not None), default=None
            ),
            "max_loss_overlap_ratio": max(
                (float(r["loss_day_overlap_ratio_vs_independence"]) for r in rows
                 if r.get("loss_day_overlap_ratio_vs_independence") is not None), default=None
            ),
            "max_lower_tail_ratio": max(
                (float(r["lower_tail_coexceed_ratio_vs_independence"]) for r in rows
                 if r.get("lower_tail_coexceed_ratio_vs_independence") is not None), default=None
            ),
            "max_simultaneous_open_risk_usd_mae_proxy": max(
                (float(r["simultaneous_open_risk_max_usd_mae_proxy"]) for r in rows),
                default=0.0,
            ),
        },
    }


def render_markdown(matrix: Mapping[str, Any]) -> str:
    summary = matrix.get("summary") or {}
    top = summary.get("top_fail_together_pair") or {}
    lines = [
        "# FTMO_BOOK_DEPENDENCE_MATRIX",
        "",
        f"Schema: `{matrix.get('schema')}`. Prague-day basis: `{matrix.get('timezone')}`.",
        "",
        "The table preserves separate dependence dimensions; no composite score is used.",
        "",
        f"Top fail-together pair: **{top.get('pair', 'NOT_YET_MEASURABLE')}**.",
        f"Clusters: `{json.dumps(summary.get('fail_together_clusters') or [])}`.",
        "",
        "| pair | daily r | downside r | loss overlap / indep | trade-day / indep | position overlap | same-dir | tail / indep | worst20 | max open-risk proxy USD | flags |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in matrix.get("pairs") or []:
        flags = ", ".join(
            name for name, field in (
                ("symbol", "common_symbol"), ("family", "common_family"),
                ("session", "common_session"), ("news", "common_news_window"),
            ) if row.get(field)
        ) or "-"
        fmt = lambda value: "-" if value is None else f"{float(value):.3f}"
        lines.append(
            "| {pair} | {corr} | {down} | {loss} | {trade} | {pos} | {direction} | "
            "{tail} | {worst} | {risk:.2f} | {flags} |".format(
                pair=row["pair"], corr=fmt(row.get("daily_pnl_correlation")),
                down=fmt(row.get("downside_correlation")),
                loss=fmt(row.get("loss_day_overlap_ratio_vs_independence")),
                trade=fmt(row.get("trade_day_overlap_ratio_vs_independence")),
                pos=fmt(row.get("position_overlap_share_of_smaller_exposure")),
                direction=fmt(row.get("same_direction_share_when_overlapping")),
                tail=fmt(row.get("lower_tail_coexceed_ratio_vs_independence")),
                worst=row.get("worst_20_day_overlap", 0),
                risk=float(row.get("simultaneous_open_risk_max_usd_mae_proxy") or 0.0),
                flags=flags,
            )
        )
    lines.extend([
        "",
        "Position overlap uses exact closed-trade entry/exit intervals. Open risk is a "
        "conservative per-trade MAE proxy, not tick-exact floating P/L.",
        "",
    ])
    return "\n".join(lines)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path,
                        help="Prepared sleeve JSON with a top-level sleeves list")
    parser.add_argument("--out-json", required=True, type=Path)
    parser.add_argument("--out-md", required=True, type=Path)
    args = parser.parse_args(argv)
    payload = json.loads(args.input.read_text(encoding="utf-8"))
    matrix = compute_dependence_matrix(payload.get("sleeves") or [],
                                       generated_at_utc=payload.get("generated_at_utc"))
    args.out_json.parent.mkdir(parents=True, exist_ok=True)
    args.out_json.write_text(json.dumps(matrix, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.out_md.parent.mkdir(parents=True, exist_ok=True)
    args.out_md.write_text(render_markdown(matrix), encoding="utf-8")
    print(json.dumps({"status": "OK", "pairs": len(matrix["pairs"]),
                      "json": str(args.out_json), "markdown": str(args.out_md)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
