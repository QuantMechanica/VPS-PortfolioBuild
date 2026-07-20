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

  B) METRICS / EXECUTION PRIOR (0.35) - half expected quality (frequency/PF/DD),
     20% venue cost class, and 30% live-book symbol orthogonality. Card metrics
     remain research ESTIMATES (claims); venue and book inputs are read-only,
     provenance-labelled observations. All only influence ORDER, never a gate
     verdict (Hard Rule: evidence over claims). Missing inputs map to neutral 0.5
     and are never treated as evidence of cheapness or portfolio novelty.

This module is pure + side-effect free except the --dry-run CLI, which only READS
the cards dir and the farm-state DB and prints a ranking. Wiring into farmctl
(ready-inventory sort, _card_build_priority, backtest priority_track) is a
separate, later step gated on OWNER reviewing the ranking.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import sqlite3
from pathlib import Path

W_DIV_DEFAULT = 0.65
W_MET_DEFAULT = 0.35
PRIORITY_TRACK_FRACTION = 0.20  # top 20% of candidates get backtest-queue fast-track

DEFAULT_CARDS_DIR = Path(r"D:\QM\strategy_farm\artifacts\cards_approved")
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_VENUE_COST_MODEL = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"
# Follow the same explicit manifest pointer as live_book_pulse. The reviewed
# 2026-07-19 book remains the fallback; a new book is never selected merely
# because a newer-looking file appeared in the report directory.
DEFAULT_LIVE_BOOK_MANIFEST = Path(
    os.environ.get(
        "QM_DXZ_BOOK_MANIFEST",
        r"D:\QM\reports\portfolio\portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json",
    )
)

MET_EXPECTED_WEIGHT = 0.50
MET_COST_WEIGHT = 0.20
MET_ORTHOGONALITY_WEIGHT = 0.30
NEUTRAL_COMPONENT = 0.50

# Sequencing tiers from the 2026-07-19 backlog-priority wiring proposal. They are
# ordering priors, not cost-gate constants. A symbol only receives a tier when
# the venue model supplies either a resolved per-symbol rate or an applicable
# canonical class model; unresolved rates remain neutral.
_COST_TIER = {
    "ws30": 1.00,
    "index": 0.85,
    "metal": 0.80,
    "energy": 0.55,
    "forex": 0.30,
}

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
#  Read-only execution-prior inputs (venue cost model + live-book manifest)
# --------------------------------------------------------------------------- #
def _json_object(path: Path, kind: str) -> tuple[dict | None, dict]:
    """Read one JSON object with stable provenance and no raised I/O errors."""
    p = Path(path)
    provenance = {
        "kind": kind,
        "path": str(p),
        "sha256": None,
        "load_status": "unavailable",
    }
    try:
        raw = p.read_bytes()
    except OSError as exc:
        provenance["error"] = type(exc).__name__
        return None, provenance
    provenance["sha256"] = hashlib.sha256(raw).hexdigest()
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        provenance["load_status"] = "invalid"
        provenance["error"] = type(exc).__name__
        return None, provenance
    if not isinstance(value, dict):
        provenance["load_status"] = "invalid"
        provenance["error"] = "root_not_object"
        return None, provenance
    provenance["load_status"] = "loaded"
    return value, provenance


def load_venue_cost_model(path: Path = DEFAULT_VENUE_COST_MODEL) -> tuple[dict | None, dict]:
    """Load the authoritative venue-cost registry; invalid shapes degrade neutral."""
    model, provenance = _json_object(Path(path), "venue_cost_model")
    if model is None:
        return None, provenance
    if not isinstance(model.get("symbols"), dict) or not isinstance(
        model.get("canonical_engine"), dict
    ):
        provenance["load_status"] = "invalid"
        provenance["error"] = "missing_symbols_or_canonical_engine"
        return None, provenance
    provenance["generated"] = model.get("generated")
    provenance["artifact"] = model.get("_artifact")
    return model, provenance


def normalize_symbol(symbol: str, venue_model: dict | None = None) -> str:
    """Normalize .DWX names and follow registry alias_of chains deterministically."""
    current = re.sub(r"\.DWX$", "", str(symbol).upper().strip())
    entries = venue_model.get("symbols", {}) if isinstance(venue_model, dict) else {}
    seen: set[str] = set()
    while current and current not in seen:
        seen.add(current)
        entry = entries.get(current)
        alias = entry.get("alias_of") if isinstance(entry, dict) else None
        if not alias:
            break
        current = re.sub(r"\.DWX$", "", str(alias).upper().strip())
    return current


def load_live_book_counts(
    path: Path = DEFAULT_LIVE_BOOK_MANIFEST,
    venue_model: dict | None = None,
) -> tuple[dict[str, int] | None, dict]:
    """Load canonical-symbol sleeve counts from one explicitly selected manifest."""
    manifest, provenance = _json_object(Path(path), "live_book_manifest")
    if manifest is None:
        return None, provenance
    sleeves = manifest.get("sleeves")
    if not isinstance(sleeves, list):
        provenance["load_status"] = "invalid"
        provenance["error"] = "sleeves_not_list"
        return None, provenance
    declared_sleeves = manifest.get("n_sleeves")
    if declared_sleeves is not None:
        if isinstance(declared_sleeves, bool) or not isinstance(declared_sleeves, int):
            provenance["load_status"] = "invalid"
            provenance["error"] = "n_sleeves_not_integer"
            return None, provenance
        if declared_sleeves < 0 or declared_sleeves != len(sleeves):
            provenance["load_status"] = "invalid"
            provenance["error"] = "n_sleeves_mismatch"
            provenance["declared_sleeves"] = declared_sleeves
            provenance["actual_sleeves"] = len(sleeves)
            return None, provenance
    counts: dict[str, int] = {}
    symbol_rows = 0
    for index, sleeve in enumerate(sleeves):
        if not isinstance(sleeve, dict):
            provenance["load_status"] = "invalid"
            provenance["error"] = "sleeve_not_object"
            provenance["invalid_sleeve_index"] = index
            return None, provenance
        raw_symbol = sleeve.get("symbol")
        if not isinstance(raw_symbol, str):
            provenance["load_status"] = "invalid"
            provenance["error"] = "sleeve_symbol_not_string"
            provenance["invalid_sleeve_index"] = index
            return None, provenance
        symbol = normalize_symbol(raw_symbol, venue_model)
        if symbol in ("", "UNKNOWN", "UNRESOLVED", "NA", "N/A", "NONE", "ALL"):
            provenance["load_status"] = "invalid"
            provenance["error"] = "sleeve_symbol_unresolved"
            provenance["invalid_sleeve_index"] = index
            return None, provenance
        symbol_rows += 1
        counts[symbol] = counts.get(symbol, 0) + 1
    provenance.update({
        "book": manifest.get("book"),
        "declared_status": manifest.get("status"),
        "declared_sleeves": manifest.get("n_sleeves"),
        "symbol_rows": symbol_rows,
        "alias_model_status": "loaded" if venue_model is not None else "unavailable",
    })
    return counts, provenance


def _card_symbols(fm: dict) -> list[str]:
    """Return explicit structured targets only; missing targets are not inferred."""
    values = _as_list(fm.get("target_symbols"))
    if not values:
        values = _as_list(fm.get("primary_target_symbols"))
    out: list[str] = []
    seen: set[str] = set()
    for value in values:
        symbol = re.sub(r"\.DWX$", "", str(value).upper().strip())
        if symbol in ("", "UNKNOWN", "UNRESOLVED", "NA", "N/A", "NONE", "ALL"):
            continue
        if symbol not in seen:
            seen.add(symbol)
            out.append(symbol)
    return out


def _resolved_cost_entry(symbol: str, venue_model: dict) -> tuple[str, dict | None]:
    canonical = normalize_symbol(symbol, venue_model)
    entry = venue_model.get("symbols", {}).get(canonical)
    return canonical, entry if isinstance(entry, dict) else None


def _has_class_cost(symbol_class: str, venue_model: dict) -> bool:
    key = "forex" if symbol_class in ("fx_major", "fx_cross") else symbol_class
    class_model = venue_model.get("canonical_engine", {}).get("class_model", {})
    return isinstance(class_model.get(key), dict)


def _symbol_cost_component(symbol: str, venue_model: dict) -> tuple[float, dict]:
    """Return one evidence-bounded cost tier plus auditable resolution detail."""
    canonical, entry = _resolved_cost_entry(symbol, venue_model)
    symbol_class = _symbol_class(symbol)
    rate = _to_float(entry.get("worst_case_rt_per_lot_usd")) if entry else None
    if rate is not None and (not math.isfinite(rate) or rate < 0):
        rate = None

    # Exact entries with unresolved worst-case values (for example SP500/XNGUSD)
    # must not be rewarded merely because their broad class looks inexpensive.
    if entry is not None and rate is None:
        return NEUTRAL_COMPONENT, {
            "symbol": symbol,
            "canonical_symbol": canonical,
            "cost_class": symbol_class,
            "worst_case_rt_per_lot_usd": None,
            "source": "registry_unresolved",
        }

    source = "registry_exact" if entry is not None else "class_fallback"
    # _symbol_class deliberately defaults unknown instruments to "index" for
    # portfolio bucketing. That broad fallback is not adequate cost evidence.
    if entry is None and (
        symbol_class == "index" or not _has_class_cost(symbol_class, venue_model)
    ):
        return NEUTRAL_COMPONENT, {
            "symbol": symbol,
            "canonical_symbol": canonical,
            "cost_class": "unknown",
            "worst_case_rt_per_lot_usd": None,
            "source": "unresolved",
        }

    if canonical == "WS30" and rate is not None:
        score, cost_class = _COST_TIER["ws30"], "ws30"
    elif symbol_class == "index":
        score, cost_class = _COST_TIER["index"], "index"
    elif symbol_class == "metal":
        score, cost_class = _COST_TIER["metal"], "metal"
    elif symbol_class == "energy":
        score, cost_class = _COST_TIER["energy"], "energy"
    elif symbol_class in ("fx_major", "fx_cross"):
        score, cost_class = _COST_TIER["forex"], "forex"
    else:
        score, cost_class, source = NEUTRAL_COMPONENT, "unknown", "unresolved"
    return score, {
        "symbol": symbol,
        "canonical_symbol": canonical,
        "cost_class": cost_class,
        "worst_case_rt_per_lot_usd": rate,
        "source": source,
    }


def cost_component(fm: dict, venue_model: dict | None) -> tuple[float, dict]:
    """Cost-class prior (0..1); missing model/symbols are neutral, never cheap."""
    symbols = _card_symbols(fm)
    if venue_model is None:
        return NEUTRAL_COMPONENT, {"status": "model_unavailable", "symbols": []}
    if not symbols:
        return NEUTRAL_COMPONENT, {"status": "symbols_unresolved", "symbols": []}
    resolved = [_symbol_cost_component(symbol, venue_model) for symbol in symbols]
    sources = {item[1]["source"] for item in resolved}
    if sources <= {"unresolved", "registry_unresolved"}:
        status = "unresolved"
    elif sources & {"unresolved", "registry_unresolved"}:
        status = "partially_resolved"
    else:
        status = "resolved"
    return sum(item[0] for item in resolved) / len(resolved), {
        "status": status,
        "symbols": [item[1] for item in resolved],
    }


def orthogonality_component(
    fm: dict,
    book_symbol_counts: dict[str, int] | None,
    venue_model: dict | None = None,
) -> tuple[float, dict]:
    """Observed symbol novelty: 1/(1+sleeve overlap), neutral when unavailable."""
    symbols = _card_symbols(fm)
    if book_symbol_counts is None:
        return NEUTRAL_COMPONENT, {"status": "manifest_unavailable", "overlap_count": None}
    if not symbols:
        return NEUTRAL_COMPONENT, {"status": "symbols_unresolved", "overlap_count": None}
    canonical = sorted({normalize_symbol(symbol, venue_model) for symbol in symbols})
    overlap_count = sum(int(book_symbol_counts.get(symbol, 0)) for symbol in canonical)
    return 1.0 / (1.0 + overlap_count), {
        "status": "resolved",
        "canonical_symbols": canonical,
        "overlap_count": overlap_count,
    }


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


def expected_metrics_component(fm: dict) -> float:
    """Legacy expected-quality prior; all missing claims remain 0.5-neutral."""
    pf = _to_float(fm.get("expected_pf"))
    dd = _to_float(fm.get("expected_dd_pct"))
    freq = _to_float(fm.get("expected_trades_per_year_per_symbol"))
    pf_c = _clamp01((pf - 1.0) / 1.0) if pf is not None else NEUTRAL_COMPONENT
    dd_c = _clamp01(1.0 - (dd / 30.0)) if dd is not None else NEUTRAL_COMPONENT
    freq_c = _clamp01(freq / 200.0) if freq is not None else NEUTRAL_COMPONENT
    return 0.5 * freq_c + 0.25 * pf_c + 0.25 * dd_c


def metrics_breakdown(
    fm: dict,
    venue_model: dict | None = None,
    book_symbol_counts: dict[str, int] | None = None,
) -> dict:
    """Return the 35%-bucket components and their input-resolution evidence.

    The expected-quality prior keeps its historical frequency/PF/DD formula and
    occupies half of this bucket. Cost (20%) and observed live-book symbol
    orthogonality (30%) use read-only inputs. None of these is a gate verdict.
    """
    expected = expected_metrics_component(fm)
    cost, cost_detail = cost_component(fm, venue_model)
    orth, orth_detail = orthogonality_component(fm, book_symbol_counts, venue_model)
    value = (
        MET_EXPECTED_WEIGHT * expected
        + MET_COST_WEIGHT * cost
        + MET_ORTHOGONALITY_WEIGHT * orth
    )
    return {
        "value": value,
        "expected": expected,
        "cost": cost,
        "orthogonality": orth,
        "cost_detail": cost_detail,
        "orthogonality_detail": orth_detail,
    }


def metrics_component(
    fm: dict,
    venue_model: dict | None = None,
    book_symbol_counts: dict[str, int] | None = None,
) -> float:
    """Metrics/execution prior (0..1); unavailable inputs are neutral 0.5."""
    return metrics_breakdown(fm, venue_model, book_symbol_counts)["value"]


def score_cards(cards: list[dict], built_counts: dict, built_eas: set,
                w_div: float = W_DIV_DEFAULT, w_met: float = W_MET_DEFAULT,
                venue_model: dict | None = None,
                book_symbol_counts: dict[str, int] | None = None,
                cost_provenance: dict | None = None,
                book_provenance: dict | None = None) -> list[dict]:
    """Diversified ranking. The diversification term is NOT just 'is the bucket
    empty' (that ties every empty bucket at 1.0); it is 1/(1+effective_position),
    where effective_position = (EAs already BUILT in this bucket) + (this card's
    rank AMONG candidates competing in the same bucket). So:
      - the 1st candidate of an under-built bucket scores highest,
      - the 2nd/3rd/... of the SAME bucket are progressively demoted (a crowded
        family like 351 mql5 cards can't flood the top - only its best few surface),
      - a bucket already covered by built EAs starts further back.
    Within a bucket, candidates are ordered by the metrics/execution prior then
    ea_id, so evidenced cost/book novelty and populated card estimates decide who
    represents the bucket first.
    Pure + deterministic; recompute each run as the portfolio evolves."""
    enriched = []
    for c in cards:
        fm = c["fm"]
        b = bucket_of(fm)
        forced = str(fm.get("force_build", "")).strip().lower() in ("1", "true", "yes")
        met_detail = metrics_breakdown(fm, venue_model, book_symbol_counts)
        enriched.append({**c, "bucket": b, "met": met_detail["value"],
                         "met_detail": met_detail,
                         "built": c["ea_id"] in built_eas, "forced": forced})

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
        if e["forced"] and not e["built"]:
            # OWNER force-forward (2026-06-09): pin a curated card to the top of the
            # build queue regardless of div/metrics. This is the only lever that
            # bypasses the frequency bias in expected_metrics_component (frequency
            # is 0.5 of expected quality and 0.25 of the full metrics bucket),
            # tuned for Q08's 50/100/200 thresholds) which otherwise buries the
            # most-survivable LOW-frequency structural edges (turn-of-month, FOMC,
            # seasonal). Additive bonus → forced cards sort above all organic ones,
            # ordered among themselves by their organic score. Flag/ordering prior
            # only, never a gate. See docs/research/EDGE_QUALITY_*_2026-06-09.md.
            score += 1000.0
        out.append({
            "ea_id": e["ea_id"], "slug": e["slug"],
            "mechanism": b[0], "asset": b[1], "tf": b[2],
            "built": e["built"], "eff_pos": eff, "forced": e["forced"],
            "div": round(div, 3), "met": round(e["met"], 3), "score": round(score, 2),
            "met_expected": round(e["met_detail"]["expected"], 3),
            "met_cost": round(e["met_detail"]["cost"], 3),
            "met_orthogonality": round(e["met_detail"]["orthogonality"], 3),
            "met_weights": {
                "expected": MET_EXPECTED_WEIGHT,
                "cost": MET_COST_WEIGHT,
                "orthogonality": MET_ORTHOGONALITY_WEIGHT,
            },
            "cost_detail": e["met_detail"]["cost_detail"],
            "orthogonality_detail": e["met_detail"]["orthogonality_detail"],
            "cost_model_provenance": cost_provenance or {
                "kind": "venue_cost_model",
                "path": None,
                "load_status": "injected" if venue_model is not None else "unavailable",
            },
            "live_book_provenance": book_provenance or {
                "kind": "live_book_manifest",
                "path": None,
                "load_status": "injected" if book_symbol_counts is not None else "unavailable",
            },
            "priority_track": False,
        })

    # flag the top PRIORITY_TRACK_FRACTION of UNBUILT candidates as "test first"
    # (consumed by the T1-T10 backtest queue via work_items.payload_json).
    cand = sorted(
        (s for s in out if not s["built"]),
        key=lambda s: (-s["score"], s["ea_id"]),
    )
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


def _file_cache_token(path: Path) -> tuple:
    """Include input replacement/updates in the per-process memoization key."""
    p = Path(path)
    try:
        stat = p.stat()
        return str(p), stat.st_size, stat.st_mtime_ns
    except OSError:
        return str(p), None, None


def compute_scores(cards_dir=DEFAULT_CARDS_DIR, db=DEFAULT_DB,
                   w_div: float = W_DIV_DEFAULT, w_met: float = W_MET_DEFAULT,
                   venue_cost_model_path=DEFAULT_VENUE_COST_MODEL,
                   live_book_manifest_path=DEFAULT_LIVE_BOOK_MANIFEST) -> dict:
    """Entrypoint for farmctl. Returns {ea_id: score_dict}. Memoized per process
    (farmctl runs are short-lived). Fully guarded: any failure returns {} so the
    caller falls back to its existing ordering - the pump must never break on a
    scorer error."""
    try:
        key = (
            str(cards_dir), str(db), round(w_div, 4), round(w_met, 4),
            _file_cache_token(Path(venue_cost_model_path)),
            _file_cache_token(Path(live_book_manifest_path)),
        )
    except Exception:
        return {}
    if key in _SCORE_CACHE:
        return _SCORE_CACHE[key]
    try:
        cards = _load_cards(Path(cards_dir))
        bucket_by_ea = {c["ea_id"]: bucket_of(c["fm"]) for c in cards if c["ea_id"]}
        counts, _ = load_portfolio_counts(Path(db), bucket_by_ea)
        built = _read_built_eas(Path(db))
        venue_model, cost_provenance = load_venue_cost_model(Path(venue_cost_model_path))
        book_counts, book_provenance = load_live_book_counts(
            Path(live_book_manifest_path), venue_model
        )
        scored = score_cards(
            cards, counts, built, w_div, w_met,
            venue_model=venue_model,
            book_symbol_counts=book_counts,
            cost_provenance=cost_provenance,
            book_provenance=book_provenance,
        )
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
    ap.add_argument("--venue-cost-model", type=Path, default=DEFAULT_VENUE_COST_MODEL)
    ap.add_argument("--live-book-manifest", type=Path, default=DEFAULT_LIVE_BOOK_MANIFEST)
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

    venue_model, cost_provenance = load_venue_cost_model(args.venue_cost_model)
    book_counts, book_provenance = load_live_book_counts(args.live_book_manifest, venue_model)
    scored = score_cards(
        cards, counts, built_eas, args.w_div, args.w_met,
        venue_model=venue_model,
        book_symbol_counts=book_counts,
        cost_provenance=cost_provenance,
        book_provenance=book_provenance,
    )
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
    print(f"venue cost input    : {cost_provenance['load_status']} "
          f"{cost_provenance['path']} sha256={cost_provenance.get('sha256')}")
    print(f"live-book input     : {book_provenance['load_status']} "
          f"{book_provenance['path']} sha256={book_provenance.get('sha256')}")
    distinct_top = len({(s['mechanism'], s['asset'], s['tf']) for s in candidates[:args.top]})
    print(f"distinct buckets in top {args.top}: {distinct_top}/{args.top}  (higher = more diversified)")
    print()
    print(f"TOP {args.top} (build/test first):")
    print(f"{'#':>3} {'score':>6} {'div':>5} {'met':>5} {'cost':>5} {'orth':>5} {'eff':>3} "
          f"{'mechanism':<15} {'asset':<9} {'tf':<4} {'ea_id':<11} slug")
    for i, s in enumerate(candidates[:args.top], 1):
        print(f"{i:>3} {s['score']:>6.2f} {s['div']:>5.2f} {s['met']:>5.2f} "
              f"{s['met_cost']:>5.2f} {s['met_orthogonality']:>5.2f} {s['eff_pos']:>3} "
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
