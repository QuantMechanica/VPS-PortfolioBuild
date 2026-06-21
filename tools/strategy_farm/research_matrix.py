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


DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_CARDS_DIR = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
_BOMBERS = ("10809", "11072", "11092")


def robust_sleeves(db_path: Path = DEFAULT_DB) -> list[tuple[int, str]]:
    """Distinct (ea_int, symbol) of the robust book = Q08 FAIL_SOFT, minus bombers."""
    import sqlite3
    try:
        conn = sqlite3.connect(db_path)
    except sqlite3.Error:
        return []
    try:
        rows = conn.execute(
            "SELECT DISTINCT ea_id, symbol FROM work_items "
            "WHERE phase='Q08' AND verdict='FAIL_SOFT' AND symbol IS NOT NULL"
        ).fetchall()
    except sqlite3.Error:
        return []
    finally:
        conn.close()
    out: list[tuple[int, str]] = []
    for ea_id, symbol in rows:
        if any(b in str(ea_id) for b in _BOMBERS):
            continue
        # match QM5_(\d+), NOT \d+ (the latter grabs the '5' in the 'QM5' prefix)
        m = re.search(r"QM5_(\d+)", str(ea_id)) or re.fullmatch(r"\s*(\d+)\s*", str(ea_id))
        if m:
            out.append((int(m.group(1)), str(symbol)))
    return sorted(set(out))


def sleeve_coverage(
    *,
    db_path: Path = DEFAULT_DB,
    cards_dir: Path = DEFAULT_CARDS_DIR,
    registry_path: Path = COMMISSION_REGISTRY,
) -> dict[str, Any]:
    """Logic x Market coverage of the robust BOOK (sleeves), not the card reservoir.

    This is the DL-064 'portfolio matrix': what diversification the book actually HAS,
    classified per sleeve using the sleeve's traded symbol (not all card target_symbols).
    Empty cells are ranked thinnest-market-first — the directed-research shopping list.
    """
    clusters = load_symbol_clusters(registry_path)
    grid: dict[tuple[str, str], list[str]] = {
        (lt, mc): [] for lt in LOGIC_TYPES for mc in MARKET_CLUSTERS
    }
    for ea_id, symbol in robust_sleeves(db_path):
        cards = sorted(cards_dir.glob(f"QM5_{ea_id}_*.md")) if cards_dir.is_dir() else []
        if cards:
            text = cards[0].read_text(encoding="utf-8", errors="ignore")
            logic = classify_logic(cards[0].stem, text)
        else:
            logic = "trend"
        market = classify_market([symbol], clusters)
        if market and (logic, market) in grid:
            grid[(logic, market)].append(f"{ea_id}:{symbol}")
    market_counts = {mc: sum(len(v) for (lt, m), v in grid.items() if m == mc) for mc in MARKET_CLUSTERS}
    logic_counts = {lt: sum(len(v) for (l, m), v in grid.items() if l == lt) for lt in LOGIC_TYPES}
    empty = [k for k, v in grid.items() if not v]
    ranked = sorted(empty, key=lambda k: (market_counts[k[1]], logic_counts[k[0]],
                                          MARKET_CLUSTERS.index(k[1]), LOGIC_TYPES.index(k[0])))
    return {
        "n_sleeves": sum(len(v) for v in grid.values()),
        "filled": {f"{lt}|{mc}": v for (lt, mc), v in grid.items() if v},
        "empty_cells": [{"logic": lt, "market": mc} for (lt, mc) in empty],
        "ranked_targets": [{"logic": lt, "market": mc} for (lt, mc) in ranked],
        "market_counts": market_counts,
        "logic_counts": logic_counts,
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Logic x Market research coverage (DL-064 R-064-1)")
    ap.add_argument("--cards-dir", type=Path, default=DEFAULT_CARDS_DIR)
    ap.add_argument("--sleeves", action="store_true",
                    help="show the BOOK (robust sleeve) matrix instead of card-reservoir coverage")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    if args.sleeves:
        sc = sleeve_coverage(cards_dir=args.cards_dir)
        if args.json:
            print(json.dumps(sc, indent=2))
        else:
            print(f"=== BOOK matrix ({sc['n_sleeves']} robust sleeves) ===")
            for lt in LOGIC_TYPES:
                row = " ".join(
                    f"{mc[:4]}={len(sc['filled'].get(f'{lt}|{mc}', [])):>2}" for mc in MARKET_CLUSTERS
                )
                print(f"  {lt:<24} {row}")
            print("ranked empty target cells: "
                  + ", ".join(f"{t['logic']}/{t['market']}" for t in sc["ranked_targets"]))
        return 0
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
