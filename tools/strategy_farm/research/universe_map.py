"""Strategy universe economic map — the §19 / §46 white-space projector.

Deterministic, read-only generator (schema ``qm.strategy-universe-map/v1``). It
projects the *current* strategy universe — every ``ea_id x symbol`` pair that has
been exercised in the pipeline (a ``work_items`` row at Q02 or later) — onto the
economic axes the OWNER follow-up directive §19 names:

    mechanism family x holding-duration class x session x symbol / asset class
    x style (trend / mean-reversion / breakout / pattern / basket / other)
    x frequency class x pipeline status x DXZ relevance x FTMO relevance

It carries the qualified / incumbent overlays (from the book-evolution read-models
and the candidate-universe read-model), answers the §19 example questions with
numbers, and ranks the empty / thin *white-space* cells by an explicitly
documented expected-value rule (FTMO gap first per §47, then DXZ).

Hard invariants:

* Never mutates the DB (URI ``mode=ro`` + ``PRAGMA query_only`` via the canonical
  clean view); never re-walks the gzip evidence trees; pure file reads otherwise.
* Every classifier is the same deterministic, read-only heuristic the canonical
  OBSERVE projector uses (imported, never re-implemented), so the map and the
  research dataset agree cell-for-cell.
* Descriptive overlays only. ``dxz_relevance`` / ``ftmo_profile`` are white-space
  *descriptors*, NOT gate verdicts or a qualification path — a gate threshold is
  never read, weakened or invented here.
* An underivable value is an explicit token (``UNKNOWN`` / ``unspecified`` /
  ``EVIDENCE_MISSING``), never a guess.
* Deterministic + idempotent: with ``now`` fixed and the same inputs the emitted
  JSON is byte-identical; ``inputs_sha256`` fingerprints the real inputs so a
  consumer can detect genuine change independent of the wall-clock stamp.

CLI::

    python universe_map.py --db <farm_state.sqlite> --out <strategy_universe_map.json> \
        --doc <STRATEGY_UNIVERSE_MAP_2026-09.md>
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable

# Self-bootstrap the sibling module path so this runs both as ``research.universe_map``
# (package) and as a bare script.
_SF = Path(__file__).resolve().parents[1]
if str(_SF) not in sys.path:
    sys.path.insert(0, str(_SF))

import work_item_clean_view  # noqa: E402
from research import observe_projector as op  # noqa: E402

MAP_SCHEMA = "qm.strategy-universe-map/v1"

_REPO_ROOT = _SF.parents[1]
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_REGISTRY = _REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
DEFAULT_STATE_DIR = Path(r"D:\QM\reports\state")
DEFAULT_OUT = DEFAULT_STATE_DIR / "strategy_universe_map.json"
DEFAULT_DOC = _REPO_ROOT / "docs" / "research" / "STRATEGY_UNIVERSE_MAP_2026-09.md"
DEFAULT_BOOK_DXZ = DEFAULT_STATE_DIR / "book_evolution_dxz.json"
DEFAULT_BOOK_FTMO = DEFAULT_STATE_DIR / "book_evolution_ftmo.json"
DEFAULT_CANDIDATE_UNIVERSE = (
    _REPO_ROOT
    / "docs"
    / "ops"
    / "evidence"
    / "2026-09-15_continuous_book_evolution"
    / "audit"
    / "candidate_universe.csv"
)

# Coarse mechanism family (op.classify_family vocabulary) -> the §19 style axis.
_FAMILY_TO_STYLE: dict[str, str] = {
    "trend": "trend",
    "momentum": "trend",
    "mean_reversion": "mean-reversion",
    "breakout": "breakout",
    "gap": "breakout",
    "pattern": "pattern",
    "pairs": "basket",
    # everything without a directional style prior collapses to "other":
    "news": "other",
    "fomc": "other",
    "carry": "other",
    "seasonal": "other",
    "volatility": "other",
    "other": "other",
    "unclassified": "other",
}
STYLE_VALUES = ("trend", "mean-reversion", "breakout", "pattern", "basket", "other")

# Pipeline gate ordering for the "furthest stage reached" descriptor. This is a
# *reached* descriptor (the pair has a work_item row at that phase) — NOT a
# pass/verdict claim; the qualified overlay carries the authoritative PASS set.
_GATE_ORDER: tuple[str, ...] = (
    "Q00", "Q01", "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09",
    "Q09_NEWS", "Q09_PORTFOLIO", "Q10_NEWS", "Q10", "Q11", "Q12", "Q13", "Q14",
    "Q15", "Q16", "Q17",
)
_GATE_ORDINAL = {name: i for i, name in enumerate(_GATE_ORDER)}


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def style_of(family: str) -> str:
    """Map a mechanism family to the coarse §19 style axis ('other' default)."""
    return _FAMILY_TO_STYLE.get(str(family or "").strip().lower(), "other")


def _window_years(start: Any, end: Any) -> float | None:
    """Approximate calendar span (years) of a ``YYYY.MM.DD``/ISO window, or None."""
    def _parse(token: Any) -> dt.date | None:
        text = str(token or "").strip()[:10]
        if not text:
            return None
        for sep in (".", "-", "/"):
            if sep in text:
                parts = text.split(sep)
                if len(parts) == 3 and all(p.isdigit() for p in parts):
                    y, m, d = (int(p) for p in parts)
                    try:
                        return dt.date(y, m, d)
                    except ValueError:
                        return None
        return None

    lo, hi = _parse(start), _parse(end)
    if lo is None or hi is None or hi <= lo:
        return None
    return (hi - lo).days / 365.25


def classify_frequency(trades: Any, window_years: float | None) -> str:
    """Bucket a representative full-window trade count into a frequency class.

    Deterministic, per trades-per-year. ``UNKNOWN`` when the trade count or a
    positive window is missing (never guessed).
    """
    try:
        n = float(trades)
    except (TypeError, ValueError):
        return "UNKNOWN"
    if n <= 0:
        return "zero"
    if not window_years or window_years <= 0:
        return "UNKNOWN"
    per_year = n / window_years
    if per_year >= 250:
        return "scalp_hf"      # >= ~1/day
    if per_year >= 100:
        return "active"
    if per_year >= 30:
        return "moderate"
    if per_year >= 10:
        return "selective"
    return "sparse"


FREQ_VALUES = ("scalp_hf", "active", "moderate", "selective", "sparse", "zero", "UNKNOWN")


# --- input loaders (all read-only; every one tolerated absent) ---------------

def _read_json(path: Path) -> Any:
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def load_incumbent_pairs(book_path: Path) -> set[tuple[str, str]]:
    """Read a venue book-evolution read-model's incumbent sleeve set (ea_key, symbol)."""
    data = _read_json(book_path)
    out: set[tuple[str, str]] = set()
    if not isinstance(data, dict):
        return out
    inc = data.get("incumbent") or {}
    for sleeve in inc.get("sleeves") or []:
        if not isinstance(sleeve, dict):
            continue
        ea = op._registry_ea_key(sleeve.get("ea_id"))
        sym = str(sleeve.get("symbol") or "").strip()
        if ea and sym:
            out.add((ea, sym))
    return out


def load_qualified_pairs(candidate_universe_csv: Path) -> dict[tuple[str, str], dict[str, str]]:
    """Read the candidate-universe read-model -> {(ea_key, symbol): row}."""
    out: dict[tuple[str, str], dict[str, str]] = {}
    path = Path(candidate_universe_csv)
    if not path.exists():
        return out
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            ea = op._registry_ea_key(row.get("ea_id"))
            sym = str(row.get("symbol") or "").strip()
            if ea and sym:
                out[(ea, sym)] = row
    return out


def _sha256_bytes(*chunks: bytes) -> str:
    digest = hashlib.sha256()
    for chunk in chunks:
        digest.update(chunk)
    return digest.hexdigest()


def _file_fingerprint(path: Path) -> str:
    try:
        raw = Path(path).read_bytes()
    except OSError:
        return "ABSENT"
    return hashlib.sha256(raw).hexdigest()


# --- descriptive relevance overlays (NOT verdicts) ---------------------------

def dxz_relevance(reached_ordinal: int, qualified: bool, incumbent: bool) -> str:
    """Descriptive DXZ-relevance label for a pair (white-space descriptor)."""
    if incumbent:
        return "INCUMBENT"
    if qualified:
        return "QUALIFIED"
    if reached_ordinal >= _GATE_ORDINAL["Q08"]:
        return "DEEP_CANDIDATE"
    if reached_ordinal >= _GATE_ORDINAL["Q04"]:
        return "MID_PIPELINE"
    return "EARLY"


# FTMO-fit profile heuristic. Anchored to the measured FTMO edge lesson
# (research_state.most_important_failed_lesson + directive §47/§48): the FTMO-fit
# direction is session-flat / low-swap / intraday-or-shorter on liquid index/FX,
# NOT swing cousins with an overnight swap tail. This is a descriptive PROFILE
# label to steer white-space research — it is explicitly NOT a fitness verdict
# and reads no gate threshold.
def ftmo_profile(holding_class: str, session: str, symbol_class: str, incumbent: bool) -> str:
    if incumbent:
        return "INCUMBENT"
    holding = str(holding_class or "").lower()
    liquid = symbol_class in {"index", "fx_major", "fx_jpy", "metal"}
    session_defined = session not in {"", "unspecified", "overnight"}
    intraday_or_shorter = holding in {"scalp", "intraday"}
    if intraday_or_shorter and liquid:
        return "PROFILE_FIT"
    if session_defined and liquid:
        return "PROFILE_FIT"
    if holding == "position" or session == "overnight":
        return "PROFILE_MISFIT"
    if not holding:
        return "UNKNOWN"
    return "PROFILE_WEAK"


# --- pair projection ----------------------------------------------------------

_SQL_PAIRS = (
    "SELECT ea_id, symbol, phase, setfile_path, data_window_start, data_window_end "
    "FROM work_items_clean ORDER BY ea_id, symbol"
)
_SQL_TRADES = (
    "SELECT ea_id, symbol, trades, work_item_id FROM ea_metrics "
    "WHERE phase = 'Q02' ORDER BY work_item_id"
)


def _project_pairs(
    connection,
    families: dict[str, dict[str, str]],
    q02_trades: dict[tuple[str, str], int],
    q02_window: dict[tuple[str, str], tuple[Any, Any]],
    qualified: dict[tuple[str, str], dict[str, str]],
    dxz_inc: set[tuple[str, str]],
    ftmo_inc: set[tuple[str, str]],
) -> list[dict[str, Any]]:
    """One read-only pass over the clean view -> per-pair attribute rows."""

    # Aggregate per (ea, symbol): reached gate ordinal + a representative setfile
    # path (the deepest gate's, so the timeframe token is a real evaluated tf).
    reached: dict[tuple[str, str], int] = {}
    best_setfile: dict[tuple[str, str], str] = {}
    for row in connection.execute(_SQL_PAIRS):
        ea = str(row["ea_id"] or "").strip()
        sym = str(row["symbol"] or "").strip()
        if not ea or not sym:
            continue
        phase = str(row["phase"] or "").strip()
        ordv = _GATE_ORDINAL.get(phase, -1)
        key = (ea, sym)
        prev = reached.get(key, -2)
        if ordv > prev:
            reached[key] = ordv
        # Keep a setfile path from a real gate row (any phase with one) if we
        # have none yet, preferring a deeper-gate one.
        sf = str(row["setfile_path"] or "").strip()
        if sf and (key not in best_setfile or ordv >= reached.get(key, -2)):
            best_setfile[key] = sf

    pairs: list[dict[str, Any]] = []
    for key in sorted(reached):
        ea, sym = key
        reached_ord = reached[key]
        # Base the universe on pairs that reached Q02+ (matches universe_matrix.csv).
        if reached_ord < _GATE_ORDINAL["Q02"]:
            continue
        fam_meta = families.get(ea) or {}
        slug = fam_meta.get("slug", "")
        family = fam_meta.get("family") or op.classify_family(slug)
        setfile = best_setfile.get(key, "")
        timeframe = op.classify_timeframe(setfile)
        holding = op.classify_holding(timeframe)
        symbol_class = op.classify_symbol_class(sym)
        # fx_jpy refinement (the whitespace audit splits JPY out of fx crosses).
        if symbol_class == "fx_cross" and "JPY" in sym.upper():
            symbol_class = "fx_jpy"
        session = op.classify_session(slug)
        style = style_of(family)
        win = q02_window.get(key, (None, None))
        freq = classify_frequency(q02_trades.get(key), _window_years(*win))
        is_qual = key in qualified
        in_dxz = key in dxz_inc
        in_ftmo = key in ftmo_inc
        reached_label = (
            _GATE_ORDER[reached_ord] if 0 <= reached_ord < len(_GATE_ORDER) else "UNKNOWN"
        )
        pairs.append(
            {
                "ea_id": ea,
                "symbol": sym,
                "slug": slug,
                "family": family,
                "style": style,
                "timeframe": timeframe or "UNKNOWN",
                "holding_class": holding or "UNKNOWN",
                "symbol_class": symbol_class or "UNKNOWN",
                "session": session,
                "frequency_class": freq,
                "reached_gate": reached_label,
                "qualified": is_qual,
                "in_dxz_incumbent": in_dxz,
                "in_ftmo_incumbent": in_ftmo,
                "dxz_relevance": dxz_relevance(reached_ord, is_qual, in_dxz),
                "ftmo_profile": ftmo_profile(holding, session, symbol_class, in_ftmo),
            }
        )
    return pairs


# --- white-space ranking ------------------------------------------------------

# Explicit, documented expected-value weights. FTMO is the larger strategic gap
# (directive §47), so the FTMO-fit terms dominate; DXZ terms break ties toward
# liquid, tradeable, portfolio-diversifying cells. Integers only, so the ranking
# is reproducible and auditable. Changing these weights is a documentation-level
# tuning, never a gate change.
RANKING_RULE: dict[str, Any] = {
    "description": (
        "White-space expected value = ftmo_weight*ftmo_fit + dxz_weight*dxz_fit, "
        "evaluated only on cells with zero qualified pairs (true white space). "
        "Cells are (style, holding_class, session, symbol_class). FTMO is the "
        "larger strategic gap (§47) so its terms dominate; DXZ terms break ties "
        "toward liquid, portfolio-diversifying cells. A cell already thinly "
        "covered (n_pairs>0) keeps a small coverage discount so genuinely empty "
        "cells rank above merely-thin ones."
    ),
    "ftmo_weight": 3,
    "dxz_weight": 1,
    "ftmo_fit_points": {
        "holding_class": {"scalp": 3, "intraday": 3, "swing": 0, "position": -2, "UNKNOWN": 0},
        "session": {"open": 3, "london": 2, "ny": 2, "asian": 2, "unspecified": 0, "overnight": -2},
        "symbol_class": {"index": 3, "fx_major": 2, "fx_jpy": 2, "metal": 2, "energy": 1,
                          "fx_cross": 1, "crypto": -1, "other": 0, "UNKNOWN": 0},
        "style": {"breakout": 1, "mean-reversion": 1, "pattern": 1, "trend": 0, "basket": 0, "other": 0},
    },
    "dxz_fit_points": {
        "symbol_class": {"index": 2, "fx_major": 2, "fx_jpy": 1, "metal": 2, "energy": 1,
                          "fx_cross": 1, "crypto": 0, "other": 0, "UNKNOWN": 0},
        "holding_class": {"position": 2, "swing": 2, "intraday": 1, "scalp": 0, "UNKNOWN": 0},
        "style": {"trend": 1, "mean-reversion": 1, "breakout": 1, "basket": 1, "pattern": 0, "other": 0},
    },
    "coverage_discount_per_existing_pair": 1,
    "coverage_discount_cap": 4,
    "empty_cell_universe": (
        "the Cartesian product of {style} x {holding scalp,intraday,swing,position} "
        "x {session open,london,ny,asian,unspecified} x {symbol_class index,fx_major,"
        "fx_jpy,metal,energy} — the tradeable, decision-relevant subspace."
    ),
}

_WHITESPACE_HOLDINGS = ("scalp", "intraday", "swing", "position")
_WHITESPACE_SESSIONS = ("open", "london", "ny", "asian", "unspecified")
_WHITESPACE_SYMCLASS = ("index", "fx_major", "fx_jpy", "metal", "energy")


def _fit_score(points: dict[str, dict[str, int]], cell: dict[str, str]) -> int:
    total = 0
    for axis, table in points.items():
        total += int(table.get(cell.get(axis, ""), 0))
    return total


def _rank_whitespace(
    coverage: dict[tuple[str, str, str, str], dict[str, int]],
) -> list[dict[str, Any]]:
    """Rank the tradeable decision subspace by the documented expected-value rule."""
    ranked: list[dict[str, Any]] = []
    fw = RANKING_RULE["ftmo_weight"]
    dw = RANKING_RULE["dxz_weight"]
    disc = RANKING_RULE["coverage_discount_per_existing_pair"]
    disc_cap = RANKING_RULE["coverage_discount_cap"]
    for style in STYLE_VALUES:
        for holding in _WHITESPACE_HOLDINGS:
            for session in _WHITESPACE_SESSIONS:
                for symclass in _WHITESPACE_SYMCLASS:
                    key = (style, holding, session, symclass)
                    cov = coverage.get(key, {"n_pairs": 0, "n_qualified": 0})
                    if cov.get("n_qualified", 0) > 0:
                        continue  # not white space — already has a qualified pair
                    cell = {
                        "style": style,
                        "holding_class": holding,
                        "session": session,
                        "symbol_class": symclass,
                    }
                    ftmo_fit = _fit_score(RANKING_RULE["ftmo_fit_points"], cell)
                    dxz_fit = _fit_score(RANKING_RULE["dxz_fit_points"], cell)
                    penalty = min(disc * int(cov.get("n_pairs", 0)), disc_cap)
                    score = fw * ftmo_fit + dw * dxz_fit - penalty
                    ranked.append(
                        {
                            **cell,
                            "n_pairs": int(cov.get("n_pairs", 0)),
                            "n_qualified": 0,
                            "ftmo_fit": ftmo_fit,
                            "dxz_fit": dxz_fit,
                            "coverage_penalty": penalty,
                            "expected_value": score,
                        }
                    )
    # Deterministic order: score desc, then the cell tuple asc.
    ranked.sort(key=lambda c: (-c["expected_value"], c["style"], c["holding_class"],
                               c["session"], c["symbol_class"]))
    return ranked


# --- directive §19 example-question answers ----------------------------------

def _directive_answers(pairs: list[dict[str, Any]]) -> dict[str, Any]:
    total = len(pairs)

    def _share(pred) -> dict[str, Any]:
        n = sum(1 for p in pairs if pred(p))
        return {"count": n, "share_pct": round(100.0 * n / total, 2) if total else 0.0}

    breakout = _share(lambda p: p["style"] == "breakout")
    mean_rev = _share(lambda p: p["style"] == "mean-reversion")
    short_fx = _share(
        lambda p: p["holding_class"] in {"scalp", "intraday"}
        and p["symbol_class"] in {"fx_major", "fx_jpy", "fx_cross"}
    )
    gold = _share(lambda p: p["symbol_class"] == "metal" and p["symbol"].upper().startswith("XAU"))
    session_tagged = _share(lambda p: p["session"] != "unspecified")
    # "high-density FTMO systems": PROFILE_FIT and active/scalp frequency.
    hi_density_ftmo = _share(
        lambda p: p["ftmo_profile"] in {"PROFILE_FIT", "INCUMBENT"}
        and p["frequency_class"] in {"scalp_hf", "active"}
    )
    return {
        "total_pairs": total,
        "breakout_derivative_share": breakout,
        "mean_reversion": mean_rev,
        "short_duration_fx_systems": short_fx,
        "gold_share": gold,
        "session_diversification": {
            **session_tagged,
            "by_session": dict(Counter(p["session"] for p in pairs)),
        },
        "high_density_ftmo_systems": hi_density_ftmo,
    }


def _marginals(pairs: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    axes = (
        "family", "style", "holding_class", "session", "symbol_class",
        "frequency_class", "reached_gate", "dxz_relevance", "ftmo_profile",
    )
    out: dict[str, dict[str, int]] = {}
    for axis in axes:
        c = Counter(p[axis] for p in pairs)
        out[axis] = dict(sorted(c.items(), key=lambda kv: (-kv[1], kv[0])))
    return out


def _cells(pairs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Group by the decision grid (style, holding, session, symbol_class) with overlays."""
    grid: dict[tuple[str, str, str, str], dict[str, int]] = defaultdict(
        lambda: {"n_pairs": 0, "n_qualified": 0, "n_dxz_incumbent": 0, "n_ftmo_incumbent": 0}
    )
    for p in pairs:
        key = (p["style"], p["holding_class"], p["session"], p["symbol_class"])
        cell = grid[key]
        cell["n_pairs"] += 1
        cell["n_qualified"] += int(p["qualified"])
        cell["n_dxz_incumbent"] += int(p["in_dxz_incumbent"])
        cell["n_ftmo_incumbent"] += int(p["in_ftmo_incumbent"])
    out = []
    for key in sorted(grid):
        style, holding, session, symclass = key
        out.append(
            {
                "style": style,
                "holding_class": holding,
                "session": session,
                "symbol_class": symclass,
                **grid[key],
            }
        )
    return out


def build_universe_map(
    db_path: Path | str = DEFAULT_DB,
    *,
    registry_path: Path | str = DEFAULT_REGISTRY,
    book_dxz_path: Path | str = DEFAULT_BOOK_DXZ,
    book_ftmo_path: Path | str = DEFAULT_BOOK_FTMO,
    candidate_universe_csv: Path | str = DEFAULT_CANDIDATE_UNIVERSE,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Assemble the ``qm.strategy-universe-map/v1`` read-model dict deterministically."""

    db_path = Path(db_path)
    families = op.load_idea_families(Path(registry_path))
    qualified = load_qualified_pairs(Path(candidate_universe_csv))
    dxz_inc = load_incumbent_pairs(Path(book_dxz_path))
    ftmo_inc = load_incumbent_pairs(Path(book_ftmo_path))

    connection = work_item_clean_view.open_clean_view_connection(db_path)
    try:
        import sqlite3

        connection.row_factory = sqlite3.Row
        # Representative Q02 trade count + window per pair (max trades wins; a
        # bigger sample is the more representative full-window run).
        q02_trades: dict[tuple[str, str], int] = {}
        wid_key: dict[Any, tuple[str, str]] = {}
        for r in connection.execute(_SQL_TRADES):
            ea = str(r["ea_id"] or "").strip()
            sym = str(r["symbol"] or "").strip()
            if not ea or not sym:
                continue
            key = (ea, sym)
            try:
                n = int(r["trades"]) if r["trades"] is not None else None
            except (TypeError, ValueError):
                n = None
            if n is not None and n > q02_trades.get(key, -1):
                q02_trades[key] = n
                wid_key[r["work_item_id"]] = key
        # Window for the representative Q02 rows.
        q02_window: dict[tuple[str, str], tuple[Any, Any]] = {}
        for r in connection.execute(
            "SELECT id, data_window_start, data_window_end FROM work_items_clean WHERE phase='Q02'"
        ):
            key = wid_key.get(r["id"])
            if key is not None:
                q02_window[key] = (r["data_window_start"], r["data_window_end"])

        pairs = _project_pairs(
            connection, families, q02_trades, q02_window, qualified, dxz_inc, ftmo_inc
        )
    finally:
        connection.close()

    cells = _cells(pairs)
    coverage = {
        (c["style"], c["holding_class"], c["session"], c["symbol_class"]): {
            "n_pairs": c["n_pairs"],
            "n_qualified": c["n_qualified"],
        }
        for c in cells
    }
    whitespace = _rank_whitespace(coverage)

    inputs_sha = _sha256_bytes(
        str(db_path.stat().st_size if db_path.exists() else 0).encode(),
        _file_fingerprint(Path(registry_path)).encode(),
        _file_fingerprint(Path(book_dxz_path)).encode(),
        _file_fingerprint(Path(book_ftmo_path)).encode(),
        _file_fingerprint(Path(candidate_universe_csv)).encode(),
    )

    return {
        "schema": MAP_SCHEMA,
        "generated_at_utc": (now.isoformat() if now else _utc_now_iso()),
        "inputs_sha256": inputs_sha,
        "inputs": {
            "db": str(db_path),
            "registry": str(registry_path),
            "book_evolution_dxz": str(book_dxz_path),
            "book_evolution_ftmo": str(book_ftmo_path),
            "candidate_universe": str(candidate_universe_csv),
        },
        "definitions": {
            "unit": "ea_id x symbol pair with a work_items row at Q02 or later",
            "reached_gate": "furthest pipeline phase with any work_item row (reached, NOT a pass claim)",
            "qualified": "present in the candidate-universe read-model (authoritative terminal-gate PASS set)",
            "dxz_relevance": "descriptive white-space label, NOT a gate verdict",
            "ftmo_profile": "descriptive FTMO-fit profile heuristic (§47/§48 + measured FTMO lesson), NOT a fitness verdict",
            "frequency_class": (
                "trades/year from the flat ea_metrics.trades column at Q02; that column is "
                "populated for only a minority of pairs (per-trade counts otherwise live in "
                "ea_metrics.detail_json, not projected here for CPU reasons), so most pairs are "
                "UNKNOWN — holding_class is the reliable duration axis"
            ),
        },
        "axes": {
            "style": list(STYLE_VALUES),
            "frequency_class": list(FREQ_VALUES),
            "holding_class": ["scalp", "intraday", "swing", "position", "UNKNOWN"],
            "symbol_class": ["index", "fx_major", "fx_jpy", "fx_cross", "metal", "energy", "crypto", "other", "UNKNOWN"],
            "session": ["open", "london", "ny", "asian", "overnight", "unspecified"],
        },
        "totals": {
            "pairs": len(pairs),
            "qualified": sum(1 for p in pairs if p["qualified"]),
            "dxz_incumbent": sum(1 for p in pairs if p["in_dxz_incumbent"]),
            "ftmo_incumbent": sum(1 for p in pairs if p["in_ftmo_incumbent"]),
        },
        "directive_answers": _directive_answers(pairs),
        "marginals": _marginals(pairs),
        "cells": cells,
        "ranking_rule": RANKING_RULE,
        "whitespace_ranked": whitespace,
    }


# --- markdown overview --------------------------------------------------------

def _pct(block: dict[str, Any]) -> str:
    return f"{block['count']} ({block['share_pct']}%)"


def render_doc(model: dict[str, Any]) -> str:
    da = model["directive_answers"]
    marg = model["marginals"]
    tot = model["totals"]
    lines: list[str] = []
    lines.append("# Strategy Universe Economic Map — 2026-09")
    lines.append("")
    lines.append(
        "Generated by `tools/strategy_farm/research/universe_map.py` "
        f"(schema `{model['schema']}`). Read-only projection of the current strategy "
        "universe onto the OWNER follow-up directive §19 economic axes. Unit: "
        "**one `ea_id x symbol` pair with a Q02-or-later pipeline row**. "
        "`reached_gate` is a *reached* descriptor, not a pass claim; the qualified "
        "overlay carries the authoritative terminal-gate PASS set."
    )
    lines.append("")
    lines.append(f"- Total pairs in universe: **{tot['pairs']}**")
    lines.append(f"- Qualified (terminal-gate PASS-class): **{tot['qualified']}**")
    lines.append(f"- DXZ incumbent pairs: **{tot['dxz_incumbent']}** · FTMO incumbent pairs: **{tot['ftmo_incumbent']}**")
    lines.append(f"- `inputs_sha256`: `{model['inputs_sha256']}`")
    lines.append("")
    lines.append("## §19 example questions — answered with numbers")
    lines.append("")
    lines.append(f"- **Are candidates mostly breakout derivatives?** breakout style = {_pct(da['breakout_derivative_share'])} of pairs.")
    lines.append(f"- **Do we have almost no mean-reversion?** mean-reversion = {_pct(da['mean_reversion'])}.")
    lines.append(f"- **No short-duration FX systems?** intraday/scalp FX pairs = {_pct(da['short_duration_fx_systems'])}.")
    lines.append(f"- **Too much Gold?** XAU (gold) pairs = {_pct(da['gold_share'])}.")
    lines.append(f"- **Too little session diversification?** session-tagged pairs = {_pct(da['session_diversification'])}; "
                 f"by session = {json.dumps(da['session_diversification']['by_session'], sort_keys=True)}.")
    lines.append(f"- **Missing high-density FTMO systems?** FTMO-profile-fit AND active/scalp frequency = {_pct(da['high_density_ftmo_systems'])}.")
    lines.append("")
    lines.append("## Marginal distributions")
    lines.append("")
    for axis in ("style", "family", "holding_class", "symbol_class", "session", "frequency_class", "reached_gate", "ftmo_profile", "dxz_relevance"):
        top = list(marg.get(axis, {}).items())
        rendered = ", ".join(f"{k}: {v}" for k, v in top[:12])
        lines.append(f"- **{axis}** — {rendered}")
    lines.append("")
    lines.append("> Data caveats: `frequency_class` uses the flat `ea_metrics.trades` column "
                 "(populated for only a minority of pairs; the rest are `UNKNOWN` — "
                 "`holding_class` is the reliable duration axis). `session` is inferred from the "
                 "registry slug; the ~95% `unspecified` share is itself the sharpest measured "
                 "white space (§46), not a projector gap.")
    lines.append("")
    lines.append("## White-space cells — ranked by expected FTMO/DXZ value")
    lines.append("")
    lines.append("Ranking rule (deterministic, integer weights): "
                 f"expected_value = {model['ranking_rule']['ftmo_weight']}*ftmo_fit "
                 f"+ {model['ranking_rule']['dxz_weight']}*dxz_fit - coverage_penalty, "
                 "over the tradeable decision subspace, restricted to cells with **zero qualified pairs**. "
                 "See `ranking_rule` in the JSON for the full point tables.")
    lines.append("")
    lines.append("| rank | style | holding | session | symbol_class | n_pairs | ftmo_fit | dxz_fit | expected_value |")
    lines.append("|---:|---|---|---|---|---:|---:|---:|---:|")
    for i, c in enumerate(model["whitespace_ranked"][:25], start=1):
        lines.append(
            f"| {i} | {c['style']} | {c['holding_class']} | {c['session']} | {c['symbol_class']} "
            f"| {c['n_pairs']} | {c['ftmo_fit']} | {c['dxz_fit']} | {c['expected_value']} |"
        )
    lines.append("")
    lines.append("## How to consume")
    lines.append("")
    lines.append("- Mission Control Research view + Kimi/Fable prioritisation read the compact "
                 "summary folded into `D:/QM/reports/state/research_state.json` (`universe_map` block).")
    lines.append("- The full cell grid + white-space ranking live in "
                 "`D:/QM/reports/state/strategy_universe_map.json`.")
    lines.append("- This map is regenerated by the 15-min read-model task; do not hand-edit.")
    lines.append("")
    return "\n".join(lines)


def write_outputs(
    model: dict[str, Any],
    out_json: Path | str = DEFAULT_OUT,
    out_doc: Path | str = DEFAULT_DOC,
) -> dict[str, Any]:
    out_json = Path(out_json)
    out_doc = Path(out_doc)
    out_json.parent.mkdir(parents=True, exist_ok=True)
    out_json.write_text(
        json.dumps(model, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    out_doc.parent.mkdir(parents=True, exist_ok=True)
    out_doc.write_text(render_doc(model) + "\n", encoding="utf-8", newline="\n")
    return {"json": str(out_json), "doc": str(out_doc)}


def summary_for_research_state(model: dict[str, Any]) -> dict[str, Any]:
    """Compact, decision-relevant slice for the research_state read-model."""
    da = model["directive_answers"]
    return {
        "schema": model["schema"],
        "generated_at_utc": model["generated_at_utc"],
        "inputs_sha256": model["inputs_sha256"],
        "totals": model["totals"],
        "breakout_share_pct": da["breakout_derivative_share"]["share_pct"],
        "mean_reversion_pairs": da["mean_reversion"]["count"],
        "short_duration_fx_pairs": da["short_duration_fx_systems"]["count"],
        "gold_share_pct": da["gold_share"]["share_pct"],
        "session_tagged_pct": da["session_diversification"]["share_pct"],
        "high_density_ftmo_pairs": da["high_density_ftmo_systems"]["count"],
        "top_whitespace": model["whitespace_ranked"][:5],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DEFAULT_DB)
    parser.add_argument("--registry", type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument("--book-dxz", type=Path, default=DEFAULT_BOOK_DXZ)
    parser.add_argument("--book-ftmo", type=Path, default=DEFAULT_BOOK_FTMO)
    parser.add_argument("--candidate-universe", type=Path, default=DEFAULT_CANDIDATE_UNIVERSE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    args = parser.parse_args(argv)
    model = build_universe_map(
        args.db,
        registry_path=args.registry,
        book_dxz_path=args.book_dxz,
        book_ftmo_path=args.book_ftmo,
        candidate_universe_csv=args.candidate_universe,
    )
    written = write_outputs(model, args.out, args.doc)
    print(json.dumps({
        "out_json": written["json"],
        "out_doc": written["doc"],
        "total_pairs": model["totals"]["pairs"],
        "qualified": model["totals"]["qualified"],
        "breakout_share_pct": model["directive_answers"]["breakout_derivative_share"]["share_pct"],
        "top_whitespace": model["whitespace_ranked"][0] if model["whitespace_ranked"] else None,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
