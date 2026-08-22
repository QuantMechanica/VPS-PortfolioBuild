#!/usr/bin/env python3
"""Economic OOS clustering with mechanics-based strategy-family fingerprints.

This is an evidence tool.  It reads completed Q08 PASS rows and their exported
trade streams, writes a point-in-time report, and never mutates factory state or
authorizes a portfolio/deployment decision.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import sqlite3
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from tools.strategy_farm.portfolio.portfolio_common import Trade, load_streams, to_daily_pnl


SCHEMA = "qm.economic-strategy-clusters/v1"
DEFAULT_DB = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")
DEFAULT_STREAM_ROOT = Path(r"D:/QM/reports/portfolio/sleeve_streams")
DEFAULT_CARD_ROOT = Path(r"D:/QM/strategy_farm/artifacts/cards_approved")
DEFAULT_CAPITAL = 100_000.0
Key = tuple[int, str]


class ClusteringError(ValueError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _section(text: str, heading: str) -> str:
    match = re.search(
        rf"(?ims)^###\s+{re.escape(heading)}\s*$\s*(.*?)(?=^###\s+|^##\s+|\Z)", text
    )
    return match.group(1) if match else ""


def _frontmatter_links(text: str, field: str) -> list[str]:
    front = text.split("---", 2)[1] if text.startswith("---") and text.count("---") >= 2 else ""
    match = re.search(
        rf"(?m)^{re.escape(field)}:[ \t]*\r?$\n"
        rf"((?:[ \t]*-[^\r\n]*(?:\r?\n|$))*)",
        front,
    )
    if not match:
        return []
    result: list[str] = []
    for raw in re.findall(r"\[\[[^/\]]+/([^\]]+)\]\]", match.group(1)):
        result.append(raw.strip().lower())
    return sorted(set(result))


def _taxonomy(values: Iterable[str], rules: Mapping[str, Sequence[str]]) -> list[str]:
    joined = " ".join(values).lower().replace("_", "-")
    return sorted(name for name, needles in rules.items() if any(token in joined for token in needles))


CONCEPT_RULES = {
    "breakout": ("breakout", "break-down", "range-break"),
    "carry_value": ("carry", "value", "risk-premium"),
    "mean_reversion": ("mean-reversion", "reversion", "contrarian", "z-score"),
    "momentum_trend": ("momentum", "trend", "time-series"),
    "pattern": ("chart-pattern", "candlestick", "triangle", "wedge", "head-and-shoulders"),
    "relative_value": ("cointegration", "pairs", "relative-value", "spread"),
    "seasonality": ("season", "calendar", "turn-of"),
    "volatility": ("volatility", "variance", "vix"),
}
INDICATOR_RULES = {
    "channel_band": ("bollinger", "keltner", "donchian", "channel", "band"),
    "moving_average": ("moving-average", "sma", "ema", "wma", "hma"),
    "oscillator": ("rsi", "stochastic", "cci", "williams", "macd"),
    "pivots": ("pivot", "fractal", "swing"),
    "volatility": ("atr", "volatility", "standard-deviation", "variance"),
    "volume_flow": ("volume", "obv", "money-flow"),
    "zscore_spread": ("zscore", "z-score", "cointegration", "spread"),
}
ENTRY_RULES = {
    "breakout": ("breakout", "breaks above", "breaks below", "buy-stop", "sell-stop"),
    "cross": ("crosses above", "crosses below", "crossover", "cross-under"),
    "mean_reversion": ("mean reversion", "z-score", "oversold", "overbought"),
    "momentum": ("momentum", "trend-follow", "trend follow"),
    "pattern": ("pattern", "pivot", "fractal", "triangle", "engulf"),
    "scheduled": ("monthly", "weekly", "day of", "session open", "scheduled"),
}
EXIT_RULES = {
    "fixed_target_stop": ("take profit", "stop loss", "fixed tp", "fixed sl"),
    "signal_reversal": ("opposite signal", "signal reversal", "crosses back"),
    "time_stop": ("time-stop", "time stop", "bars after", "end of session"),
    "trailing": ("trailing", "trail stop"),
}


def family_descriptor(card_text: str) -> dict[str, Any]:
    concepts = _frontmatter_links(card_text, "concepts")
    indicators = _frontmatter_links(card_text, "indicators")
    entry = _section(card_text, "Entry")
    exit_text = _section(card_text, "Exit")
    period_tokens = sorted(set(re.findall(r"(?i)\b(?:M[1-9][0-9]*|H[1-9][0-9]*|D1|W1|MN1)\b", card_text)))
    normalized_periods = [token.upper() for token in period_tokens]
    if any(token.startswith("M") or token == "H1" for token in normalized_periods):
        horizon = "intraday"
    elif any(token in {"H4", "D1"} for token in normalized_periods):
        horizon = "swing"
    elif any(token in {"W1", "MN1"} for token in normalized_periods):
        horizon = "long_horizon"
    else:
        horizon = "unspecified"
    descriptor = {
        "concept_archetypes": _taxonomy(concepts, CONCEPT_RULES),
        "indicator_archetypes": _taxonomy(indicators, INDICATOR_RULES),
        "entry_archetypes": _taxonomy([entry], ENTRY_RULES),
        "exit_archetypes": _taxonomy([exit_text], EXIT_RULES),
        "horizon": horizon,
    }
    # Empty semantics must not collapse unrelated incomplete cards together.
    if not any(descriptor[name] for name in descriptor if name != "horizon"):
        raise ClusteringError("card has no classifiable mechanics or indicator semantics")
    return descriptor


def fingerprint(descriptor: Mapping[str, Any]) -> str:
    canonical = json.dumps(descriptor, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _card_for_ea(card_root: Path, ea_id: int) -> Path:
    matches: list[Path] = []
    for path in card_root.glob(f"QM5_{ea_id}_*.md"):
        text = path.read_text(encoding="utf-8-sig")
        if re.search(rf"(?m)^ea_id:\s*QM5_{ea_id}\s*$", text):
            matches.append(path)
    if len(matches) != 1:
        raise ClusteringError(f"QM5_{ea_id} requires exactly one content-bound approved card; found {len(matches)}")
    return matches[0]


def q08_pass_keys(db_path: Path) -> list[Key]:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    with sqlite3.connect(uri, uri=True) as conn:
        rows = conn.execute(
            "SELECT ea_id, symbol FROM work_items "
            "WHERE phase='Q08' AND status='done' AND verdict='PASS'"
        ).fetchall()
    keys: set[Key] = set()
    for ea_label, symbol in rows:
        match = re.fullmatch(r"QM5_(\d+)", str(ea_label).strip())
        if not match or not str(symbol).strip():
            raise ClusteringError(f"invalid Q08 PASS identity: {ea_label!r}/{symbol!r}")
        keys.add((int(match.group(1)), str(symbol).strip()))
    return sorted(keys)


def _quantile(values: Sequence[float], probability: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(float(value) for value in values)
    position = probability * (len(ordered) - 1)
    low, high = math.floor(position), math.ceil(position)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (position - low)


def _correlation(left: Sequence[float], right: Sequence[float]) -> float:
    if len(left) != len(right) or not left:
        return 0.0
    ml, mr = sum(left) / len(left), sum(right) / len(right)
    dl = [value - ml for value in left]
    dr = [value - mr for value in right]
    denom = math.sqrt(sum(value * value for value in dl) * sum(value * value for value in dr))
    return sum(a * b for a, b in zip(dl, dr)) / denom if denom > 0 else 0.0


def _jaccard(left: set[dt.date], right: set[dt.date]) -> float:
    union = left | right
    return len(left & right) / len(union) if union else 0.0


def _exposure_days(trades: Sequence[Trade]) -> set[dt.date]:
    days: set[dt.date] = set()
    for trade in trades:
        close_day = dt.datetime.fromtimestamp(trade.time, tz=dt.UTC).date()
        open_day = (
            dt.datetime.fromtimestamp(trade.entry_time, tz=dt.UTC).date()
            if trade.entry_time is not None else close_day
        )
        if open_day > close_day:
            open_day = close_day
        cursor = open_day
        while cursor <= close_day:
            days.add(cursor)
            cursor += dt.timedelta(days=1)
    return days


def analyze(
    *, db_path: Path, stream_root: Path, card_root: Path,
    starting_capital: float = DEFAULT_CAPITAL, similarity_threshold: float = 0.25,
) -> dict[str, Any]:
    db_before = sha256_file(db_path)
    requested = q08_pass_keys(db_path)
    streams = load_streams(stream_root, candidates=requested)
    db_after = sha256_file(db_path)
    if db_before != db_after:
        raise ClusteringError("factory database changed during snapshot; retry on a stable read")
    usable = sorted(key for key in requested if streams.get(key))
    if not usable:
        raise ClusteringError("no non-empty Q08 PASS streams are available")
    all_daily = {key: to_daily_pnl(streams[key]) for key in usable}
    dates = sorted({day for series in all_daily.values() for day in series})
    if not dates:
        raise ClusteringError("Q08 PASS streams contain no closed-trade P/L")

    members: list[dict[str, Any]] = []
    vectors: dict[Key, list[float]] = {}
    downside: dict[Key, list[float]] = {}
    tails: dict[Key, set[dt.date]] = {}
    exposures: dict[Key, set[dt.date]] = {}
    family_by_key: dict[Key, str] = {}
    family_errors: list[dict[str, Any]] = []
    for key in usable:
        vector = [float(all_daily[key].get(day, 0.0)) / starting_capital for day in dates]
        loss_values = [value for value in vector if value < 0]
        tail_count = max(1, math.ceil(len(loss_values) * 0.05)) if loss_values else 0
        loss_days = sorted((value, day) for value, day in zip(vector, dates) if value < 0)
        tail_days = {day for _, day in loss_days[:tail_count]}
        exposure_days = _exposure_days(streams[key])
        vectors[key] = vector
        downside[key] = [min(0.0, value) for value in vector]
        tails[key] = tail_days
        exposures[key] = exposure_days
        try:
            card = _card_for_ea(card_root, key[0])
            descriptor = family_descriptor(card.read_text(encoding="utf-8-sig"))
            family_id = fingerprint(descriptor)
            family_by_key[key] = family_id
            family_status = "CLASSIFIED"
        except (OSError, UnicodeError, ClusteringError) as exc:
            # Fail closed: an unclassified sleeve receives a unique sentinel and
            # can never make another sleeve look independent through a guess.
            descriptor = None
            family_id = hashlib.sha256(f"UNKNOWN:{key[0]}".encode()).hexdigest()
            family_by_key[key] = family_id
            family_status = "UNKNOWN"
            family_errors.append({"ea_id": key[0], "reason": str(exc)})
        es = sum(value for value, _ in loss_days[:tail_count]) / tail_count if tail_count else 0.0
        stream_path = stream_root / "QM" / "q08_trades" / f"{key[0]}_{key[1].replace('.', '_')}.jsonl"
        members.append({
            "ea_id": key[0], "symbol": key[1], "trade_count": len(streams[key]),
            "oos_total_pnl_pct": round(sum(vector) * 100.0, 8),
            "downside_deviation_pct": round(math.sqrt(sum(v * v for v in downside[key]) / len(dates)) * 100.0, 8),
            "worst_day_pct": round(min(vector) * 100.0, 8),
            "tail_p05_pct": round(_quantile(vector, 0.05) * 100.0, 8),
            "tail_expected_shortfall_pct": round(es * 100.0, 8),
            "exposure_day_ratio": round(len(exposure_days) / len(dates), 8),
            "family_fingerprint": family_id, "family_status": family_status,
            "family_descriptor": descriptor,
            "stream_binding": {"path": str(stream_path), "sha256": sha256_file(stream_path)} if stream_path.is_file() else None,
        })

    parent = {key: key for key in usable}
    def find(key: Key) -> Key:
        while parent[key] != key:
            parent[key] = parent[parent[key]]
            key = parent[key]
        return key
    def union(left: Key, right: Key) -> None:
        a, b = find(left), find(right)
        if a != b:
            parent[max(a, b)] = min(a, b)

    pair_links: list[dict[str, Any]] = []
    for index, left in enumerate(usable):
        for right in usable[index + 1:]:
            pnl_corr = _correlation(vectors[left], vectors[right])
            down_corr = _correlation(downside[left], downside[right])
            tail_overlap = _jaccard(tails[left], tails[right])
            exposure_overlap = _jaccard(exposures[left], exposures[right])
            similarity = (
                0.35 * max(0.0, pnl_corr) + 0.30 * max(0.0, down_corr)
                + 0.20 * tail_overlap + 0.15 * exposure_overlap
            )
            same_family = family_by_key[left] == family_by_key[right]
            if same_family or similarity >= similarity_threshold:
                union(left, right)
                pair_links.append({
                    "left": f"{left[0]}:{left[1]}", "right": f"{right[0]}:{right[1]}",
                    "same_family": same_family, "economic_similarity": round(similarity, 8),
                    "pnl_correlation": round(pnl_corr, 8), "downside_correlation": round(down_corr, 8),
                    "tail_overlap": round(tail_overlap, 8), "exposure_overlap": round(exposure_overlap, 8),
                })
    groups: dict[Key, list[Key]] = defaultdict(list)
    for key in usable:
        groups[find(key)].append(key)
    clusters = [
        {"cluster_id": index, "member_count": len(group),
         "members": [f"{key[0]}:{key[1]}" for key in sorted(group)],
         "family_fingerprints": sorted({family_by_key[key] for key in group})}
        for index, group in enumerate(sorted(groups.values(), key=lambda group: min(group)), start=1)
    ]
    family_groups: dict[str, list[str]] = defaultdict(list)
    for key in usable:
        family_groups[family_by_key[key]].append(f"{key[0]}:{key[1]}")
    return {
        "schema": SCHEMA, "generated_at_utc": dt.datetime.now(dt.UTC).isoformat(),
        "decision_authority": "EVIDENCE_ONLY", "deployment_action": "NONE", "autotrading_action": "NONE",
        "inputs": {"db_path": str(db_path), "db_sha256": db_before, "stream_root": str(stream_root),
                   "card_root": str(card_root), "starting_capital": starting_capital,
                   "similarity_threshold": similarity_threshold},
        "coverage": {"q08_pass_keys": len(requested), "usable_nonempty_streams": len(usable),
                     "missing_or_empty_streams": [f"{key[0]}:{key[1]}" for key in sorted(set(requested)-set(usable))],
                     "family_unknown_count": len(family_errors), "family_errors": family_errors,
                     "oos_date_first": str(dates[0]), "oos_date_last": str(dates[-1]), "oos_observed_dates": len(dates)},
        "members": members,
        "family_groups": [{"family_fingerprint": fid, "member_count": len(rows), "members": sorted(rows)}
                          for fid, rows in sorted(family_groups.items())],
        "economic_clusters": clusters, "cluster_links": pair_links,
        "independence_summary": {"raw_sleeve_count": len(usable), "family_count": len(family_groups),
                                 "economic_independence_cluster_count": len(clusters),
                                 "same_family_variants_never_count_as_independent": True},
    }


def markdown(report: Mapping[str, Any]) -> str:
    coverage, summary = report["coverage"], report["independence_summary"]
    lines = ["# Economic strategy clustering", "", "## Result", "",
             f"- Q08 PASS identities: {coverage['q08_pass_keys']}",
             f"- Usable OOS streams: {coverage['usable_nonempty_streams']}",
             f"- Raw sleeves / mechanics families / economic clusters: {summary['raw_sleeve_count']} / {summary['family_count']} / {summary['economic_independence_cluster_count']}",
             f"- OOS observation range: {coverage['oos_date_first']} through {coverage['oos_date_last']}",
             f"- Unclassified family identities: {coverage['family_unknown_count']}", "",
             "Same-family variants are collapsed before independence is counted, regardless of filenames or apparent return decorrelation.", "",
             "The mechanics fingerprint hashes normalized card concepts, indicator archetypes, entry/exit mechanics, and horizon; EA IDs, slugs, and filenames are excluded. Cross-family linkage uses 35% positive daily-P/L correlation, 30% positive downside correlation, 20% worst-loss-day overlap, and 15% exposure-day overlap. The 0.25 linkage threshold is diagnostic evidence, not a portfolio gate.", "",
             "## Sleeve economics", "", "| Sleeve | P/L % | Downside % | Worst day % | ES(5%) % | Exposure | Family |", "|---|---:|---:|---:|---:|---:|---|"]
    for row in report["members"]:
        lines.append(f"| {row['ea_id']}:{row['symbol']} | {row['oos_total_pnl_pct']:.4f} | {row['downside_deviation_pct']:.4f} | {row['worst_day_pct']:.4f} | {row['tail_expected_shortfall_pct']:.4f} | {row['exposure_day_ratio']:.4f} | {row['family_fingerprint'][:12]} |")
    lines.extend(["", "## Clusters", ""])
    for cluster in report["economic_clusters"]:
        lines.append(f"- C{cluster['cluster_id']:03d} ({cluster['member_count']}): " + ", ".join(cluster["members"]))
    economic_links = sorted(
        (row for row in report["cluster_links"] if not row["same_family"]),
        key=lambda row: row["economic_similarity"],
        reverse=True,
    )
    lines.extend(["", "## Strongest cross-family economic links", "",
                  "| Pair | Similarity | P/L corr | Downside corr | Tail overlap | Exposure overlap |",
                  "|---|---:|---:|---:|---:|---:|"])
    for row in economic_links[:20]:
        lines.append(
            f"| {row['left']} / {row['right']} | {row['economic_similarity']:.4f} | "
            f"{row['pnl_correlation']:.4f} | {row['downside_correlation']:.4f} | "
            f"{row['tail_overlap']:.4f} | {row['exposure_overlap']:.4f} |"
        )
    lines.extend(["", "Evidence only; no book, deployment, live-trading, or AutoTrading action is authorized.", ""])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--stream-root", type=Path, default=DEFAULT_STREAM_ROOT)
    parser.add_argument("--card-root", type=Path, default=DEFAULT_CARD_ROOT)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--markdown-output", type=Path)
    parser.add_argument("--similarity-threshold", type=float, default=0.25)
    args = parser.parse_args()
    report = analyze(db_path=args.db, stream_root=args.stream_root, card_root=args.card_root,
                     similarity_threshold=args.similarity_threshold)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.markdown_output:
        args.markdown_output.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_output.write_text(markdown(report), encoding="utf-8")
    print(json.dumps(report["independence_summary"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
