#!/usr/bin/env python3
"""
QuantMechanica - Strategy build/test prioritization (v1).

Computes a deterministic priority_score (0..100, higher = build & backtest first)
for each strategy card, so more promising strategies move to the front of the
build queue and the T1-T10 backtest queue.

OWNER policy (2026-06-02): score = 65% portfolio-diversification + 35% expected
metrics.

  A) DIVERSIFICATION (0.65) - claim-free, computed from the cards + the current
     portfolio. Bucket = (mechanism x asset_class x timeframe). A card in an
     UNDER-represented bucket (few EAs already built/tested in it) scores high.
     This pushes new, uncorrelated edges to the front instead of grinding through
     350 near-identical cards of one family. Recomputed each run, so a bucket that
     fills up automatically demotes its remaining cards. (Mission: diversification
     = the win mechanism; DL-064 portfolio layer.)

  B) EXPECTED METRICS (0.35) - from the card's expected_pf / expected_dd_pct.
     These are research ESTIMATES (claims), so they only influence ORDER, never a
     gate verdict (Hard Rule: evidence over claims). MISSING values map to a
     neutral 0.5 - never invented. Today expected_pf is unpopulated on the whole
     backlog, so B is constant (~neutral) until research/G0 starts emitting it;
     diversification carries the ordering in the meantime.

This module is pure + side-effect free except the --dry-run CLI, which only READS
the cards dir and the farm-state DB and prints a ranking. Wiring into farmctl
(ready-inventory sort, _card_build_priority, backtest priority_track) is a
separate, later step gated on OWNER reviewing the ranking.
"""
from __future__ import annotations

import argparse
import re
import sqlite3
from pathlib import Path

W_DIV_DEFAULT = 0.65
W_MET_DEFAULT = 0.35
PRIORITY_TRACK_FRACTION = 0.20  # top 20% of candidates get backtest-queue fast-track

DEFAULT_CARDS_DIR = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")

_SCORE_CACHE: dict = {}  # per-process memo: key -> {ea_id: score_dict}


# --------------------------------------------------------------------------- #
#  Frontmatter parsing (no PyYAML dependency; handles inline + block lists)
# --------------------------------------------------------------------------- #
def parse_frontmatter(path: Path) -> dict:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    lines = m.group(1).splitlines()
    fm: dict = {}
    i = 0
    while i < len(lines):
        line = lines[i]
        km = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
        if not km:
            i += 1
            continue
        key, val = km.group(1), km.group(2).strip()
        if val == "":
            # possible block list on following indented "- " lines
            items = []
            j = i + 1
            while j < len(lines) and re.match(r"^\s*-\s+", lines[j]):
                items.append(re.sub(r"^\s*-\s+", "", lines[j]).strip().strip('"').strip("'"))
                j += 1
            if items:
                fm[key] = items
                i = j
                continue
            fm[key] = ""
        elif val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            fm[key] = [x.strip().strip('"').strip("'") for x in inner.split(",") if x.strip()] if inner else []
        else:
            fm[key] = val.strip().strip('"').strip("'")
        i += 1
    return fm


def _as_list(v) -> list[str]:
    if isinstance(v, list):
        return [str(x) for x in v]
    if isinstance(v, str) and v:
        return [v]
    return []


# --------------------------------------------------------------------------- #
#  Dimension extraction: mechanism x asset_class x timeframe
# --------------------------------------------------------------------------- #
# Ordered: first matching family wins (more specific patterns first).
_MECHANISM_PATTERNS = [
    ("relative_value", ("cointegrat", "pair", "spread", "relative-strength", "relative-momentum",
                         "cross-sectional", "relmom", "stat-arb", "basket")),
    ("carry",          ("carry", "rollover", "swap", "interest-rate-diff", "tfcarry")),
    ("seasonality",    ("seasonal", "time-of-day", "calendar", "day-of-week", "fomc", "open-range",
                         "session", "auction", "turn-of-month", "tokyo", "london", "asia")),
    ("breakout",       ("breakout", "channel", "donchian", "range-expansion", "orb", "straddle",
                        "smash-day", "outside-bar", "first-touch")),
    ("mean_reversion", ("mean-reversion", "reversion", "bollinger", "zscore", "z-score", "oversold",
                        "overbought", "rsi2", "fade", "midpoint", "vwap-revert")),
    ("momentum_trend", ("momentum", "trend", "moving-average", "ma-cross", "ema", "macd", "adx",
                        "ichimoku", "supertrend", "psar")),
    ("volatility",     ("volatility", "atr", "vol-expansion", "volatten", "squeeze")),
]


def mechanism_of(fm: dict) -> str:
    tokens = []
    for c in _as_list(fm.get("concepts")):
        # "[[concepts/mean-reversion]]" -> "mean-reversion"
        t = re.sub(r"[\[\]]", "", str(c)).split("/")[-1].lower()
        tokens.append(t)
    for f in _as_list(fm.get("strategy_type_flags")):
        tokens.append(str(f).lower())
    tokens.append(str(fm.get("slug", "")).lower())
    blob = " ".join(tokens)
    for name, pats in _MECHANISM_PATTERNS:
        if any(p in blob for p in pats):
            return name
    return "other"


_FX = {"EUR", "USD", "JPY", "GBP", "CHF", "AUD", "CAD", "NZD"}
_MAJORS = {"EURUSD", "USDJPY", "GBPUSD", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"}


def _symbol_class(sym: str) -> str:
    s = re.sub(r"\.DWX$", "", str(sym).upper().strip())
    if s[:3] in ("XAU", "XAG"):
        return "metal"
    if s in ("WTI", "BRENT", "USOIL", "UKOIL", "XTIUSD", "XBRUSD", "CRUDE"):
        return "energy"
    if s[:3] in ("BTC", "ETH", "LTC", "XRP"):
        return "crypto"
    if len(s) == 6 and s[:3] in _FX and s[3:] in _FX:
        return "fx_major" if s in _MAJORS else "fx_cross"
    # everything else treated as an index/CFD (NDX, WS30, SP500, GDAXI, UK100, ...)
    return "index"


def asset_class_of(fm: dict) -> str:
    syms = _as_list(fm.get("target_symbols"))
    if not syms:
        return "unknown"
    classes = [_symbol_class(s) for s in syms]
    # dominant class (ties -> alphabetical for determinism)
    counts: dict[str, int] = {}
    for c in classes:
        counts[c] = counts.get(c, 0) + 1
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[0][0]


def timeframe_of(fm: dict) -> str:
    p = str(fm.get("period", "")).upper().strip()
    return p if p else "NA"


def bucket_of(fm: dict) -> tuple[str, str, str]:
    return (mechanism_of(fm), asset_class_of(fm), timeframe_of(fm))


# --------------------------------------------------------------------------- #
#  Score components
# --------------------------------------------------------------------------- #
def _clamp01(x: float) -> float:
    return 0.0 if x < 0 else 1.0 if x > 1 else x


def _to_float(v):
    try:
        return float(str(v).strip())
    except (TypeError, ValueError):
        return None


def metrics_component(fm: dict) -> float:
    """0.5 neutral when missing (never invented). pf: 1.0->0, 2.0+->1.
    dd: 0%->1, 30%+->0."""
    pf = _to_float(fm.get("expected_pf"))
    dd = _to_float(fm.get("expected_dd_pct"))
    pf_c = _clamp01((pf - 1.0) / 1.0) if pf is not None else 0.5
    dd_c = _clamp01(1.0 - (dd / 30.0)) if dd is not None else 0.5
    return 0.5 * pf_c + 0.5 * dd_c


def score_cards(cards: list[dict], built_counts: dict, built_eas: set,
                w_div: float = W_DIV_DEFAULT, w_met: float = W_MET_DEFAULT) -> list[dict]:
    """Diversified ranking. The diversification term is NOT just 'is the bucket
    empty' (that ties every empty bucket at 1.0); it is 1/(1+effective_position),
    where effective_position = (EAs already BUILT in this bucket) + (this card's
    rank AMONG candidates competing in the same bucket). So:
      - the 1st candidate of an under-built bucket scores highest,
      - the 2nd/3rd/... of the SAME bucket are progressively demoted (a crowded
        family like 351 mql5 cards can't flood the top - only its best few surface),
      - a bucket already covered by built EAs starts further back.
    Within a bucket, candidates are ordered by metrics (expected pf/dd) then ea_id,
    so once expected_pf/dd get populated they decide who represents the bucket first.
    Pure + deterministic; recompute each run as the portfolio evolves."""
    enriched = []
    for c in cards:
        fm = c["fm"]
        b = bucket_of(fm)
        enriched.append({**c, "bucket": b, "met": metrics_component(fm),
                         "built": c["ea_id"] in built_eas})

    # within-bucket rank among UNBUILT candidates (best metrics first, then ea_id)
    by_bucket: dict = {}
    for e in enriched:
        if e["built"]:
            continue
        by_bucket.setdefault(e["bucket"], []).append(e)
    for b, items in by_bucket.items():
        items.sort(key=lambda e: (-e["met"], e["ea_id"]))
        for r, e in enumerate(items):
            e["_wbr"] = r

    out = []
    for e in enriched:
        b = e["bucket"]
        if e["built"]:
            div = 0.0  # already built/tested - not a build candidate
            eff = None
        else:
            eff = built_counts.get(b, 0) + e["_wbr"]
            div = 1.0 / (1.0 + eff)
        score = 100.0 * (w_div * div + w_met * e["met"])
        out.append({
            "ea_id": e["ea_id"], "slug": e["slug"],
            "mechanism": b[0], "asset": b[1], "tf": b[2],
            "built": e["built"], "eff_pos": eff,
            "div": round(div, 3), "met": round(e["met"], 3), "score": round(score, 2),
            "priority_track": False,
        })

    # flag the top PRIORITY_TRACK_FRACTION of UNBUILT candidates as "test first"
    # (consumed by the T1-T10 backtest queue via work_items.payload_json).
    cand = sorted((s for s in out if not s["built"]), key=lambda s: -s["score"])
    if cand:
        cut = max(1, int(PRIORITY_TRACK_FRACTION * len(cand)))
        threshold = cand[cut - 1]["score"]
        for s in out:
            s["priority_track"] = (not s["built"]) and s["score"] >= threshold
    return out


# --------------------------------------------------------------------------- #
#  Portfolio composition (what is already built / tested), from the DB
# --------------------------------------------------------------------------- #
def load_portfolio_counts(db: Path, card_bucket_by_ea: dict) -> tuple[dict, dict]:
    """Count distinct already-built/tested EAs per bucket (work_items.ea_id).
    Returns (counts_by_bucket, stats)."""
    counts: dict = {}
    stats = {"work_item_eas": 0, "passed_eas": 0, "mapped": 0, "unmapped": 0}
    if not db.exists():
        return counts, stats
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        rows = con.execute("SELECT DISTINCT ea_id FROM work_items").fetchall()
        passed = {r[0] for r in con.execute(
            "SELECT DISTINCT ea_id FROM work_items WHERE verdict='PASS'").fetchall()}
    except sqlite3.Error:
        con.close()
        return counts, stats
    con.close()
    stats["work_item_eas"] = len(rows)
    stats["passed_eas"] = len(passed)
    for (ea,) in rows:
        b = card_bucket_by_ea.get(ea)
        if b is None:
            stats["unmapped"] += 1
            continue
        stats["mapped"] += 1
        counts[b] = counts.get(b, 0) + 1
    return counts, stats


def _read_built_eas(db: Path) -> set:
    if not db.exists():
        return set()
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        return {r[0] for r in con.execute("SELECT DISTINCT ea_id FROM work_items").fetchall()}
    except sqlite3.Error:
        return set()
    finally:
        con.close()


def compute_scores(cards_dir=DEFAULT_CARDS_DIR, db=DEFAULT_DB,
                   w_div: float = W_DIV_DEFAULT, w_met: float = W_MET_DEFAULT) -> dict:
    """Entrypoint for farmctl. Returns {ea_id: score_dict}. Memoized per process
    (farmctl runs are short-lived). Fully guarded: any failure returns {} so the
    caller falls back to its existing ordering - the pump must never break on a
    scorer error."""
    key = (str(cards_dir), str(db), round(w_div, 4), round(w_met, 4))
    if key in _SCORE_CACHE:
        return _SCORE_CACHE[key]
    try:
        cards = _load_cards(Path(cards_dir))
        bucket_by_ea = {c["ea_id"]: bucket_of(c["fm"]) for c in cards if c["ea_id"]}
        counts, _ = load_portfolio_counts(Path(db), bucket_by_ea)
        built = _read_built_eas(Path(db))
        scored = score_cards(cards, counts, built, w_div, w_met)
        result = {s["ea_id"]: s for s in scored if s["ea_id"]}
    except Exception:
        result = {}
    _SCORE_CACHE[key] = result
    return result


# --------------------------------------------------------------------------- #
#  Dry-run CLI
# --------------------------------------------------------------------------- #
def _load_cards(cards_dir: Path) -> list[dict]:
    out = []
    for f in sorted(cards_dir.glob("*.md")):
        fm = parse_frontmatter(f)
        if not fm:
            continue
        out.append({"path": f, "ea_id": str(fm.get("ea_id", "")), "slug": str(fm.get("slug", "")), "fm": fm})
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="Strategy build/test prioritization (v1)")
    ap.add_argument("--cards-dir", type=Path, default=DEFAULT_CARDS_DIR)
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--top", type=int, default=50)
    ap.add_argument("--w-div", type=float, default=W_DIV_DEFAULT)
    ap.add_argument("--w-met", type=float, default=W_MET_DEFAULT)
    ap.add_argument("--dry-run", action="store_true", help="print ranking only (no writes)")
    args = ap.parse_args()

    cards = _load_cards(args.cards_dir)
    bucket_by_ea = {c["ea_id"]: bucket_of(c["fm"]) for c in cards if c["ea_id"]}
    counts, stats = load_portfolio_counts(args.db, bucket_by_ea)

    # which EAs already entered the backtest queue (work_items)
    built_eas: set = set()
    if args.db.exists():
        con = sqlite3.connect(f"file:{args.db}?mode=ro", uri=True)
        try:
            built_eas = {r[0] for r in con.execute("SELECT DISTINCT ea_id FROM work_items").fetchall()}
        except sqlite3.Error:
            pass
        con.close()

    scored = score_cards(cards, counts, built_eas, args.w_div, args.w_met)
    candidates = [s for s in scored if not s["built"]]
    candidates.sort(key=lambda s: (-s["score"], s["ea_id"]))

    pf_filled = sum(1 for c in cards if _to_float(c["fm"].get("expected_pf")) is not None)
    print(f"cards scored        : {len(cards)}  (unbuilt candidates: {len(candidates)})")
    print(f"portfolio (built)   : work_item EAs={stats['work_item_eas']} "
          f"(mapped={stats['mapped']}, unmapped={stats['unmapped']}), PASS EAs={stats['passed_eas']}")
    print(f"distinct buckets    : {len(set(bucket_by_ea.values()))}")
    print(f"expected_pf populated: {pf_filled}/{len(cards)}  "
          f"(metrics component neutral 0.5 where missing)")
    print(f"weights             : div={args.w_div}  met={args.w_met}")
    distinct_top = len({(s['mechanism'], s['asset'], s['tf']) for s in candidates[:args.top]})
    print(f"distinct buckets in top {args.top}: {distinct_top}/{args.top}  (higher = more diversified)")
    print()
    print(f"TOP {args.top} (build/test first):")
    print(f"{'#':>3} {'score':>6} {'div':>5} {'met':>5} {'eff':>3} {'mechanism':<15} {'asset':<9} "
          f"{'tf':<4} {'ea_id':<11} slug")
    for i, s in enumerate(candidates[:args.top], 1):
        print(f"{i:>3} {s['score']:>6.2f} {s['div']:>5.2f} {s['met']:>5.2f} {s['eff_pos']:>3} "
              f"{s['mechanism']:<15} {s['asset']:<9} {s['tf']:<4} {s['ea_id']:<11} {s['slug']}")

    print("\nMOST-built buckets (already covered -> their remaining candidates demoted):")
    for b, n in sorted(counts.items(), key=lambda kv: -kv[1])[:10]:
        print(f"   {n:>4}  {b[0]:<15} {b[1]:<9} {b[2]}")
    print("\nMOST-CROWDED candidate buckets (many competing cards -> only the best few surface):")
    crowd: dict = {}
    for s in candidates:
        k = (s["mechanism"], s["asset"], s["tf"])
        crowd[k] = crowd.get(k, 0) + 1
    for b, n in sorted(crowd.items(), key=lambda kv: -kv[1])[:10]:
        print(f"   {n:>4}  {b[0]:<15} {b[1]:<9} {b[2]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
