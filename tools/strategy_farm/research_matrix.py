"""research_matrix.py — matrix-directed research coverage (DL-064 R-064-1).

Research demand should fill empty cells of a Logic x Market matrix, not just top
up a flat reservoir count — otherwise the farm grows 200 correlated trend
followers and the portfolio layer (DL-064) has nothing to anti-correlate.

This module is ADVISORY in v1: it classifies the existing ready Strategy Cards
into matrix cells, reports per-cell coverage and the thinnest (most under-served)
cells. Wiring it into the agent_router research-demand decision is a separate,
minimal hook (see README/spec) — keep this a clean, testable library.

Market cluster reuses the canonical symbol->class map in
framework/registry/live_commission.json (forex / index / commodity), so the
matrix and the cost model never drift apart. Logic type is a keyword heuristic
over the card slug + body (cards carry no explicit logic-type field today).
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[2]
COMMISSION_REGISTRY = REPO_ROOT / "framework" / "registry" / "live_commission.json"

LOGIC_TYPES = ("trend", "mean_reversion", "seasonality_volatility")
MARKET_CLUSTERS = ("forex", "index", "commodity")

# Keyword heuristics for the logic type (first matching family wins, in order).
_LOGIC_KEYWORDS: dict[str, tuple[str, ...]] = {
    "trend": ("trend", "breakout", "momentum", "ma-cross", "ema", "macd", "supertrend",
              "donchian", "channel-break", "follow", "orb"),
    "mean_reversion": ("revert", "reversion", "mean-rev", "mr", "fade", "bollinger", "bb",
                       "rsi", "oversold", "overbought", "vwap-ret", "range", "stat-arb",
                       "pairs", "harami"),
    "seasonality_volatility": ("season", "seasonal", "time-of-day", "session", "day-of-week",
                               "volatility", "vol-", "atr", "squeeze", "news", "expiry",
                               "fomc", "carry", "liquidity"),
}


def load_symbol_clusters(registry_path: Path = COMMISSION_REGISTRY) -> dict[str, str]:
    """symbol -> {forex,index,commodity} from the canonical commission registry."""
    try:
        data = json.loads(registry_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return {str(k): str(v) for k, v in data.get("symbol_class", {}).items()}


def classify_logic(slug: str, body: str) -> str:
    """Best-effort logic type from slug + body keywords; default trend (most common)."""
    hay = f"{slug} {body}".lower()
    scores = {lt: sum(hay.count(kw) for kw in kws) for lt, kws in _LOGIC_KEYWORDS.items()}
    best = max(scores, key=lambda lt: scores[lt])
    return best if scores[best] > 0 else "trend"


def classify_market(symbols: list[str], clusters: dict[str, str]) -> str | None:
    """Dominant market cluster across the card's symbols; None if unknown."""
    counts: dict[str, int] = {}
    for sym in symbols:
        cluster = clusters.get(sym) or clusters.get(sym.upper())
        if cluster:
            counts[cluster] = counts.get(cluster, 0) + 1
    if not counts:
        return None
    return max(counts, key=lambda c: counts[c])


def _extract_symbols(text: str, clusters: dict[str, str]) -> list[str]:
    """Pull known .DWX-style symbols out of card text (frontmatter or body)."""
    found = [sym for sym in clusters if sym in text or sym.upper() in text]
    # also catch bare tokens like NDX / EURUSD that map via the registry keys
    bare = set(re.findall(r"\b[A-Z]{3,6}(?:\.DWX)?\b", text.upper()))
    for sym in clusters:
        root = sym.replace(".DWX", "")
        if root in bare and sym not in found:
            found.append(sym)
    return sorted(set(found))


def classify_card(card_path: Path, clusters: dict[str, str]) -> tuple[str, str | None]:
    """(logic_type, market_cluster|None) for one card file."""
    text = card_path.read_text(encoding="utf-8", errors="ignore")
    slug = card_path.stem
    symbols = _extract_symbols(text, clusters)
    return classify_logic(slug, text), classify_market(symbols, clusters)


def coverage(cards_dir: Path, *, registry_path: Path = COMMISSION_REGISTRY) -> dict[str, Any]:
    """Per-cell counts over the cards in cards_dir, plus the thinnest cells."""
    clusters = load_symbol_clusters(registry_path)
    cells: dict[tuple[str, str], int] = {(lt, mc): 0 for lt in LOGIC_TYPES for mc in MARKET_CLUSTERS}
    unclassified_market = 0
    total = 0
    if cards_dir.is_dir():
        for card in sorted(cards_dir.glob("*.md")):
            logic, market = classify_card(card, clusters)
            total += 1
            if market is None:
                unclassified_market += 1
                continue
            cells[(logic, market)] = cells.get((logic, market), 0) + 1
    cell_list = [{"logic": lt, "market": mc, "count": cells[(lt, mc)]}
                 for lt in LOGIC_TYPES for mc in MARKET_CLUSTERS]
    min_count = min((c["count"] for c in cell_list), default=0)
    thinnest = [c for c in cell_list if c["count"] == min_count]
    return {
        "total_cards": total,
        "unclassified_market": unclassified_market,
        "cells": cell_list,
        "thinnest_cells": thinnest,
        "min_count": min_count,
    }


def next_research_target(cards_dir: Path, *, registry_path: Path = COMMISSION_REGISTRY) -> dict[str, str]:
    """The single thinnest cell research should target next (deterministic tie-break)."""
    cov = coverage(cards_dir, registry_path=registry_path)
    target = sorted(cov["thinnest_cells"], key=lambda c: (c["logic"], c["market"]))[0]
    return {"logic": target["logic"], "market": target["market"], "count": str(target["count"])}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Logic x Market research coverage (DL-064 R-064-1)")
    ap.add_argument("--cards-dir", type=Path,
                    default=Path(r"D:\QM\strategy_farm\artifacts\cards_approved"))
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    cov = coverage(args.cards_dir)
    if args.json:
        print(json.dumps(cov, indent=2))
    else:
        print(f"=== research matrix coverage ({cov['total_cards']} cards, "
              f"{cov['unclassified_market']} unclassified market) ===")
        for lt in LOGIC_TYPES:
            row = " ".join(f"{mc[:4]}={next(c['count'] for c in cov['cells'] if c['logic']==lt and c['market']==mc):>3}"
                           for mc in MARKET_CLUSTERS)
            print(f"  {lt:<24} {row}")
        t = cov["thinnest_cells"]
        print(f"thinnest (count={cov['min_count']}): " + ", ".join(f"{c['logic']}/{c['market']}" for c in t))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
