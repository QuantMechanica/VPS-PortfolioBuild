#!/usr/bin/env python3
"""Read-only Strategy Card mechanism census for orthogonal sourcing.

The historical card corpus is heterogeneous: most cards have ``concepts`` but
do not have a first-class ``family`` or ``mechanism`` field.  This module keeps
the raw field census and adds a deliberately small, deterministic taxonomy for
the mechanism classes considered by the Wave-2 research programme.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


FRONTIER_ORDER = {
    "": -1,
    "Q02": 2,
    "Q03": 3,
    "Q04": 4,
    "Q05": 5,
    "Q06": 6,
    "Q07": 7,
    "Q08": 8,
    "Q09": 9,
    "Q10": 10,
    "Q14": 14,
    "Q15": 15,
    "Q16": 16,
}

INDEX_SYMBOLS = {"GDAXI.DWX", "NDX.DWX", "SP500.DWX", "UK100.DWX", "WS30.DWX"}
COMMODITY_SYMBOLS = {"XAGUSD.DWX", "XAUUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX"}

# These are mechanism classes, not profitability labels.  Rules intentionally
# err toward inclusion; the report discloses them as a keyword census.
MECHANISM_LABELS = (
    "scheduled_announcement_risk_premium",
    "fx_benchmark_fix_rebalancing",
    "fx_local_session_inventory_drift",
    "carry_unwind_crisis_momentum",
    "index_volatility_liquidity_reversal",
    "commodity_monthly_momentum",
    "cross_instrument_relative_value",
    "index_gap_response",
)


@dataclass(frozen=True)
class CardRecord:
    path: Path
    ea_id: str
    raw_family: str
    raw_mechanism: str
    symbols: tuple[str, ...]
    searchable: str
    family: str
    mechanisms: tuple[str, ...]


def _front_matter(text: str) -> str:
    if not text.startswith("---"):
        return ""
    match = re.match(r"\A---\s*\r?\n(.*?)\r?\n---(?:\r?\n|\Z)", text, re.S)
    return match.group(1) if match else ""


def _scalar(front: str, key: str) -> str:
    match = re.search(rf"(?mi)^{re.escape(key)}\s*:\s*(.*?)\s*$", front)
    if not match:
        return ""
    value = match.group(1).strip().strip('"\'')
    return value if not value.startswith("[") else ""


def _list(front: str, key: str) -> list[str]:
    inline = re.search(rf"(?mi)^{re.escape(key)}\s*:\s*\[(.*?)\]\s*$", front)
    if inline:
        return [part.strip().strip('"\'') for part in inline.group(1).split(",") if part.strip()]
    block = re.search(
        rf"(?ms)^{re.escape(key)}\s*:\s*\r?\n((?:\s+-\s+.*(?:\r?\n|\Z))*)",
        front,
    )
    if not block:
        return []
    return [
        match.group(1).strip().strip('"\'')
        for match in re.finditer(r"(?m)^\s+-\s+(.*?)\s*$", block.group(1))
    ]


def canonical_family(searchable: str) -> str:
    """Assign one broad family for an all-card distribution."""
    text = searchable.lower()
    if any(token in text for token in ("pairs-trading", "relative-value", "relative value", "cointegration", "market-neutral", "dispersion", "two-leg")):
        return "relative_value_stat_arb"
    if any(token in text for token in ("calendar", "seasonality", "month-end", "month end", "day-of-week", "weekday", "fixing")):
        return "calendar_seasonality"
    if any(token in text for token in ("announcement", "news-event", "eia", "fomc", "nonfarm", "cpi release")):
        return "event_driven"
    if any(token in text for token in ("carry", "funding premium", "roll-yield")):
        return "carry_funding"
    if any(token in text for token in ("mean-reversion", "mean reversion", "reversal", "fade")):
        return "mean_reversion"
    if any(token in text for token in ("breakout", "range break", "donchian")):
        return "breakout"
    if any(token in text for token in ("trend-following", "trend following", "momentum", "trend-continuation")):
        return "trend_momentum"
    if any(token in text for token in ("volatility", "variance", "vol-regime", "vol regime")):
        return "volatility_regime"
    return "other_or_unclassified"


def classify_mechanisms(searchable: str, symbols: Iterable[str]) -> tuple[str, ...]:
    text = searchable.lower()
    symbol_set = set(symbols)
    is_index = bool(symbol_set & INDEX_SYMBOLS)
    is_commodity = bool(symbol_set & COMMODITY_SYMBOLS)
    labels: list[str] = []

    if any(token in text for token in ("macro-announcement", "announcement-day", "pre-fomc", "pre-announcement", "scheduled macro", "cpi release", "nonfarm payroll")):
        labels.append("scheduled_announcement_risk_premium")
    if any(token in text for token in ("wm/r", "wmr", "london fix", "benchmark fix", "fix rebalanc", "month-end fx", "month end fx")):
        labels.append("fx_benchmark_fix_rebalancing")
    if any(token in text for token in ("local-session", "local session", "session inventory drift", "local-currency intraday", "local currency intraday", "intraday depreciation")):
        labels.append("fx_local_session_inventory_drift")
    if any(token in text for token in ("carry-unwind", "carry unwind", "currency crash momentum", "funding-currency unwind", "funding currency unwind")):
        labels.append("carry_unwind_crisis_momentum")
    if is_index and any(token in text for token in ("evaporating liquidity", "liquidity reversal", "volatility-regime mean", "volatility regime mean", "high-volatility reversal", "high volatility reversal")):
        labels.append("index_volatility_liquidity_reversal")
    if is_commodity and "month" in text and any(token in text for token in ("momentum", "trend-following", "trend following", "continuation")):
        labels.append("commodity_monthly_momentum")
    if any(token in text for token in ("cross-asset", "cross asset", "relative-value", "relative value", "two-leg", "gold-silver ratio", "xau/xag", "dispersion spread")):
        labels.append("cross_instrument_relative_value")
    if is_index and "gap" in text and any(token in text for token in ("fade", "follow", "continuation", "gap-and-go", "gap and go", "reversal")):
        labels.append("index_gap_response")
    return tuple(label for label in MECHANISM_LABELS if label in labels)


def parse_card(path: Path) -> CardRecord:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    front = _front_matter(text)
    ea_id = _scalar(front, "ea_id") or path.name.split("_", 2)[0]
    raw_family = _scalar(front, "family") or _scalar(front, "strategy_family")
    raw_mechanism = _scalar(front, "mechanism") or _scalar(front, "strategy_mechanic")
    symbols = tuple(_list(front, "target_symbols"))
    concepts = _list(front, "concepts")
    flags = _list(front, "strategy_type_flags")
    title_match = re.search(r"(?m)^#\s+(.+?)\s*$", text)
    title = title_match.group(1) if title_match else ""
    # Keep inference on identity metadata and the title.  Searching the whole
    # prose would count generic risk/disclosure language (for example every
    # card that mentions a news blackout) as part of the traded mechanism.
    searchable = "\n".join(
        (front, path.stem, title, raw_family, raw_mechanism, " ".join(concepts), " ".join(flags))
    )
    return CardRecord(
        path=path,
        ea_id=ea_id,
        raw_family=raw_family,
        raw_mechanism=raw_mechanism,
        symbols=symbols,
        searchable=searchable,
        family=canonical_family(searchable),
        mechanisms=classify_mechanisms(searchable, symbols),
    )


def load_cards(directory: Path) -> list[CardRecord]:
    return [parse_card(path) for path in sorted(directory.glob("*.md"))]


def frontier_ea_ids(census_csv: Path, minimum_gate: str = "Q08") -> tuple[set[str], int]:
    minimum = FRONTIER_ORDER[minimum_gate]
    ea_ids: set[str] = set()
    pair_count = 0
    with census_csv.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            gate = (row.get("highest_contiguous_valid_gate") or "").strip()
            if FRONTIER_ORDER.get(gate, -1) >= minimum:
                pair_count += 1
                ea_ids.add((row.get("ea_id") or "").strip())
    return ea_ids, pair_count


def distribution(cards: Iterable[CardRecord]) -> dict[str, dict[str, int]]:
    card_list = list(cards)
    family = Counter(card.family for card in card_list)
    mechanism = Counter(label for card in card_list for label in card.mechanisms)
    raw_family = Counter(card.raw_family for card in card_list if card.raw_family)
    raw_mechanism = Counter(card.raw_mechanism for card in card_list if card.raw_mechanism)
    return {
        "family": dict(sorted(family.items())),
        "mechanism": {label: mechanism.get(label, 0) for label in MECHANISM_LABELS},
        "raw_family_field": dict(sorted(raw_family.items())),
        "raw_mechanism_field": dict(sorted(raw_mechanism.items())),
    }


def build_census(approved_dir: Path, census_csv: Path) -> dict[str, object]:
    cards = load_cards(approved_dir)
    frontier_ids, frontier_pair_count = frontier_ea_ids(census_csv)
    by_ea = {card.ea_id: card for card in cards}
    frontier_cards = [by_ea[ea_id] for ea_id in sorted(frontier_ids) if ea_id in by_ea]
    return {
        "approved_card_count": len(cards),
        "approved": distribution(cards),
        "q08_valid_pair_count": frontier_pair_count,
        "q08_valid_distinct_ea_count": len(frontier_ids),
        "q08_valid_joined_card_count": len(frontier_cards),
        "q08_valid_unjoined_ea_ids": sorted(frontier_ids - set(by_ea)),
        "q08_valid": distribution(frontier_cards),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved-dir", type=Path, required=True)
    parser.add_argument("--census-csv", type=Path, required=True)
    parser.add_argument("--output-json", type=Path)
    args = parser.parse_args()
    result = build_census(args.approved_dir, args.census_csv)
    payload = json.dumps(result, indent=2, sort_keys=True)
    if args.output_json:
        args.output_json.write_text(payload + "\n", encoding="utf-8")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
