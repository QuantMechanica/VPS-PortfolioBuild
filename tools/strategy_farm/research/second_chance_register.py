"""Second-Chance Strategy Register (schema ``qm.second-chance-register/v1``).

Deterministic classification of every historical REJECTED / RETIRED / DRAFT
strategy record against Strategy Eligibility V2 (OWNER follow-up directive
2026-09-15 third, sections 23-28, 31-32, 38). For each record it derives:

* a single PRIMARY reason from the directive-24 enum (rule table
  ``config/second_chance_reasons.v1.json``; keyword + verdict-class + registry-
  reason + hold-code rules with documented precedence; unknown -> OTHER, never
  guessed),
* a second-chance status: ``STILL_INVALID`` / ``ELIGIBLE_FOR_RECONSIDERATION`` /
  ``SUPPRESSED_CLONE_OF <id>`` (duplicate suppression via the behaviour lineage
  map), plus a ``PORTFOLIO_UTILITY_CHALLENGER`` flag when the section-27
  counterfactual rescues an economically-rejected record,
* a priority score (directive 26) blending novelty, expected edge, validation
  cost, portfolio white-space, FTMO / DXZ relevance, independence, execution
  complexity and a tail-risk flag, with FTMO weighted highest (directive 31).

Also runs the section-27/28 counterfactual: for economically-rejected records
that own a sealed Q08 trade stream, it measures whether adding the sleeve's
holdout-window daily PnL to the current DXZ / FTMO roster improves the venue
objective out-of-sample, and emits the ``PORTFOLIO_UTILITY_CHALLENGER`` list
(or ``EVIDENCE_MISSING`` where no stream exists).

Outputs (deterministic; wall-clock only in ``generated_at_utc``):

* ``D:/QM/reports/state/second_chance_register.json`` (this schema),
* ``D:/QM/reports/state/second_chance_register.csv`` (one row per record),
* vault ``09 Strategy Wiki/Second-Chance Register.md`` (generated top-200 table).

No farm-DB write, no network, no LLM call, no terminal64 start. The farm DB is
opened read-only. Per-node projection onto the Strategy Wiki is a separate,
read-only join performed by ``strategy_wiki_sync.py`` when this register exists.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import io
import json
import re
import sqlite3
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable

try:  # package + script dual import
    from tools.strategy_farm import lineage_map as lineage_mod
    from tools.strategy_farm import vault_paths
except Exception:  # pragma: no cover - script mode
    import sys as _sys

    _sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    import lineage_map as lineage_mod  # type: ignore
    import vault_paths  # type: ignore

SCHEMA = "qm.second-chance-register/v1"
CHALLENGER_SCHEMA = "qm.portfolio-utility-challenger/v1"
GENERATOR = "second_chance_register/v1"

REPO_ROOT = Path(__file__).resolve().parents[3]
DEFAULT_STATE_DIR = Path(r"D:\QM\reports\state")
DEFAULT_CONFIG = REPO_ROOT / "tools" / "strategy_farm" / "config" / "second_chance_reasons.v1.json"
DEFAULT_REGISTRY = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
DEFAULT_LINEAGE = DEFAULT_STATE_DIR / "lineage_map.json"
DEFAULT_UNIVERSE = DEFAULT_STATE_DIR / "strategy_universe_map.json"
DEFAULT_DB = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
DEFAULT_ARTIFACTS_ROOT = Path(r"D:\QM\strategy_farm\artifacts")
# Card stores scanned for a rejection/disposition reason, in precedence order
# (a rejected-store card's reason wins over a review/draft twin sharing the id).
CARD_STORES = (
    "cards_rejected",
    "cards_review",
    "cards_blocked_r3_data",
    "cards_recovery",
    "cards_draft",
)
DEFAULT_BOOK_DXZ = DEFAULT_STATE_DIR / "book_evolution_dxz.json"
DEFAULT_BOOK_FTMO = DEFAULT_STATE_DIR / "book_evolution_ftmo.json"
DEFAULT_STREAM_DIR = Path(r"D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades")
DEFAULT_OUT_JSON = DEFAULT_STATE_DIR / "second_chance_register.json"
DEFAULT_OUT_CSV = DEFAULT_STATE_DIR / "second_chance_register.csv"
VAULT_PAGE_NAME = "Second-Chance Register.md"

# Population = these Strategy-Wiki projection classes (directive 23).
POPULATION_CLASSES = ("REJECTED", "RETIRED", "DRAFT")

# Holdout / OOS window convention.
#
# The canonical sealed OOS window is oos_2026_confirmation.py FROM_UTC..TO_UTC
# (2026-01-01..2026-04-06). The sealed Q08 sleeve streams that back this
# counterfactual, however, cover the FULL backtest history and end 2025-12-30 —
# they do not (yet) carry the 2026 confirmation runs — so a 2026 holdout is
# empty on them. To keep the counterfactual evidence-backed rather than
# EVIDENCE_MISSING-by-vintage, the register uses the last FULL calendar year
# present in the combined roster+candidate data as the deterministic out-of-
# sample split (in-sample = everything before it). If/when the 2026 confirmation
# streams are sealed into the sleeve-stream store, ``SEALED_OOS_*`` becomes the
# preferred split automatically (it has data).
SEALED_OOS_FROM = "2026-01-01"
SEALED_OOS_TO = "2026-04-06"

MISSING = "EVIDENCE_MISSING"
STILL_INVALID = "STILL_INVALID"
ELIGIBLE = "ELIGIBLE_FOR_RECONSIDERATION"

_EA_NUM_RE = re.compile(r"QM5[_-]?(\d+)")


# ---------------------------------------------------------------------------
# Records
# ---------------------------------------------------------------------------
@dataclass
class NodeRec:
    ea_id: str  # canonical "QM5_<n>"
    numeric_id: str
    slug: str
    projection_class: str
    name: str = ""
    lifecycle_status: str = ""
    strategy_family: str = ""
    timeframes: str = ""
    intended_symbols: str = ""
    terminal_verdict: str = ""
    current_blocker: str = ""
    canonical_repo_path: str = ""
    dxz_status: str = ""
    ftmo_status: str = ""


@dataclass
class Classification:
    ea_id: str
    reason: str
    matched_rule: str
    eligibility: str
    status: str  # STILL_INVALID / ELIGIBLE_FOR_RECONSIDERATION / SUPPRESSED_CLONE_OF:<id>
    suppressed_clone_of: str | None
    portfolio_utility_challenger: bool
    tail_risk_flag: bool
    priority: float
    score_components: dict[str, float]
    reason_evidence: str
    node: NodeRec = field(repr=False, default=None)  # type: ignore


# ---------------------------------------------------------------------------
# Loaders
# ---------------------------------------------------------------------------
def load_config(path: Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _slurp(path: Path) -> str:
    """Read a text file tolerant of a UTF-8 BOM and CRLF line endings."""
    raw = Path(path).read_bytes()
    enc = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    return raw.decode(enc, errors="replace").replace("\r\n", "\n").replace("\r", "\n")


def _read_frontmatter(text: str) -> dict[str, str]:
    text = text.lstrip("﻿").replace("\r\n", "\n").replace("\r", "\n")
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    body = m.group(1) if m else ""
    out: dict[str, str] = {}
    for line in body.splitlines():
        mm = re.match(r"^([a-z0-9_]+):\s*(.*)$", line)
        if mm:
            out[mm.group(1)] = mm.group(2).strip().strip('"')
    return out


def load_nodes(generated_dir: Path) -> list[NodeRec]:
    """Enumerate the second-chance population from the generated Strategy Wiki."""
    out: list[NodeRec] = []
    base = Path(generated_dir)
    for cls in POPULATION_CLASSES:
        d = base / cls
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.md")):
            fm = _read_frontmatter(_slurp(p))
            ea = (fm.get("ea_id") or "").strip()
            m = _EA_NUM_RE.search(ea) or _EA_NUM_RE.search(p.stem)
            if not m:
                continue
            num = m.group(1)
            out.append(
                NodeRec(
                    ea_id=f"QM5_{num}",
                    numeric_id=num,
                    slug=fm.get("slug", ""),
                    projection_class=cls,
                    name=fm.get("name", ""),
                    lifecycle_status=fm.get("lifecycle_status", ""),
                    strategy_family=fm.get("strategy_family", ""),
                    timeframes=fm.get("timeframes", ""),
                    intended_symbols=fm.get("intended_symbols", ""),
                    terminal_verdict=fm.get("terminal_verdict", ""),
                    current_blocker=fm.get("current_blocker", ""),
                    canonical_repo_path=fm.get("canonical_repo_path", ""),
                    dxz_status=fm.get("dxz_status", ""),
                    ftmo_status=fm.get("ftmo_status", ""),
                )
            )
    # De-dup by ea_id (a node can only project into one class, but be safe).
    seen: dict[str, NodeRec] = {}
    for rec in out:
        seen.setdefault(rec.ea_id, rec)
    return [seen[k] for k in sorted(seen)]


def load_registry(path: Path) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    p = Path(path)
    if not p.is_file():
        return out
    raw = p.read_bytes()
    enc = "utf-8-sig" if raw.startswith(b"\xef\xbb\xbf") else "utf-8"
    reader = csv.DictReader(io.StringIO(raw.decode(enc, errors="replace")))
    for row in reader:
        ea = (row.get("ea_id") or "").strip()
        m = _EA_NUM_RE.search(ea)
        num = m.group(1) if m else ea
        out[num] = row
    return out


def read_card_reason(card_path: str) -> str:
    """Return the rejection-reason text of a card, or '' when absent."""
    if not card_path or card_path in (MISSING, "NOT_APPLICABLE", ""):
        return ""
    p = Path(card_path)
    if not p.is_file():
        return ""
    fm = _read_frontmatter(_slurp(p))
    parts: list[str] = []
    for key in ("g0_rejection_reason", "rejection_reason", "card_body_missing"):
        v = fm.get(key)
        if v:
            parts.append(v)
    if fm.get("card_body_incomplete", "").lower() in ("true", "1", "yes"):
        parts.append("card_body_incomplete")
    return " | ".join(parts)


def _reason_from_frontmatter(fm: dict[str, str]) -> str:
    parts: list[str] = []
    for key in ("g0_rejection_reason", "rejection_reason", "card_body_missing"):
        v = fm.get(key)
        if v:
            parts.append(v)
    if fm.get("card_body_incomplete", "").lower() in ("true", "1", "yes"):
        parts.append("card_body_incomplete")
    return " | ".join(parts)


def load_card_store_reasons(artifacts_root: Path) -> dict[tuple[str, str], str]:
    """(numeric ea id, slug) -> rejection/disposition reason across the card stores.

    A card can have twins under different stores sharing one ea id (an approved
    card plus a rejected duplicate); the rejection reason then lives in the
    rejected/review store even when the Strategy-Wiki node's
    ``canonical_repo_path`` points at the approved twin. But an ea id is also
    *re-purposed* after a rejection (the reserved id is freed and re-pointed at a
    new strategy), leaving the old rejected card as debris under an id that now
    means something else (see the 2026-08-21 disposition doc). Keying by
    (id, slug) — matched against the node's own slug — attaches a store reason
    only to the record it actually describes, never to a repurposed twin.
    """
    out: dict[tuple[str, str], str] = {}
    root = Path(artifacts_root)
    if not root.is_dir():
        return out
    for store in reversed(CARD_STORES):  # lowest precedence first; higher overwrites
        d = root / store
        if not d.is_dir():
            continue
        for p in sorted(d.glob("*.md")):
            m = _EA_NUM_RE.search(p.stem)
            if not m:
                continue
            fm = _read_frontmatter(_slurp(p))
            num = m.group(1)
            slug = (fm.get("slug") or "").strip()
            reason = _reason_from_frontmatter(fm)
            if reason:
                out[(num, slug)] = reason
    return out


def load_lineage(path: Path) -> dict[str, Any]:
    p = Path(path)
    if not p.is_file():
        return {"nodes": {}, "edges": [], "families": {}}
    return json.loads(p.read_text(encoding="utf-8"))


def load_universe(path: Path) -> dict[str, Any]:
    p = Path(path)
    if not p.is_file():
        return {"cells": [], "whitespace_ranked": []}
    return json.loads(p.read_text(encoding="utf-8"))


def db_verdict_summary(db_path: Path) -> dict[str, dict[str, Any]]:
    """Read-only per-EA verdict/taxonomy + active-hold summary from the farm DB."""
    p = Path(db_path)
    if not p.is_file():
        return {}
    uri = f"file:{p.as_posix()}?mode=ro"
    out: dict[str, dict[str, Any]] = {}
    try:
        conn = sqlite3.connect(uri, uri=True)
    except sqlite3.Error:
        return {}
    try:
        for ea_id, verdict, tax, n in conn.execute(
            "SELECT ea_id, verdict, verdict_taxonomy, COUNT(*) "
            "FROM work_items WHERE ea_id IS NOT NULL "
            "GROUP BY ea_id, verdict, verdict_taxonomy"
        ):
            num = _norm_num(ea_id)
            if num is None:
                continue
            rec = out.setdefault(num, {"verdicts": {}, "taxonomies": set(), "holds": set()})
            if verdict:
                rec["verdicts"][str(verdict)] = rec["verdicts"].get(str(verdict), 0) + int(n)
            if tax:
                rec["taxonomies"].add(str(tax))
        # active hold codes joined to ea_id
        try:
            for ea_id, hold_code in conn.execute(
                "SELECT w.ea_id, h.hold_code FROM work_item_holds h "
                "JOIN work_items w ON w.id = h.work_item_id "
                "WHERE h.active = 1 AND w.ea_id IS NOT NULL"
            ):
                num = _norm_num(ea_id)
                if num is None:
                    continue
                rec = out.setdefault(num, {"verdicts": {}, "taxonomies": set(), "holds": set()})
                if hold_code:
                    rec["holds"].add(str(hold_code))
        except sqlite3.Error:
            pass
    finally:
        conn.close()
    return out


def _norm_num(ea_id: Any) -> str | None:
    s = str(ea_id or "").strip()
    m = _EA_NUM_RE.search(s)
    if m:
        return m.group(1)
    if s.isdigit():
        return s
    return None


# ---------------------------------------------------------------------------
# Classification (documented precedence in the config rule table)
# ---------------------------------------------------------------------------
def _match_any(text: str, needles: Iterable[str]) -> str | None:
    for n in needles:
        if n and n in text:
            return n
    return None


def classify(
    rec: NodeRec,
    card_reason: str,
    registry_row: dict[str, str] | None,
    db_summary: dict[str, Any] | None,
    config: dict[str, Any],
) -> tuple[str, str, str]:
    """Return (reason, matched_rule_id, evidence_snippet) via precedence rules.

    Every candidate rule that fires yields (precedence, reason, rule_id, snippet);
    the lowest precedence wins. Deterministic tie-break: precedence then rule id.
    """
    reason_text = " ".join(
        s for s in (card_reason, rec.current_blocker, rec.terminal_verdict) if s
    ).lower()
    reg_reason = ""
    if registry_row:
        reg_reason = " ".join(
            str(registry_row.get(k) or "")
            for k in ("retired_reason", "status")
        ).lower()

    candidates: list[tuple[int, str, str, str]] = []

    for rule in config.get("reason_text_rules", []):
        hit = _match_any(reason_text, rule.get("match_any", []))
        if hit:
            candidates.append((rule["precedence"], rule["reason"], rule["id"], hit))

    for rule in config.get("registry_reason_rules", []):
        hit = _match_any(reg_reason, rule.get("match_any", []))
        if hit:
            candidates.append((rule["precedence"], rule["reason"], rule["id"], hit))

    if db_summary:
        verdicts = set(db_summary.get("verdicts", {}).keys())
        taxonomies = set(db_summary.get("taxonomies", set()))
        holds = set(db_summary.get("holds", set()))
        for rule in config.get("verdict_class_rules", []):
            v_ok = bool(verdicts & set(rule.get("verdict_any", [])))
            t_ok = bool(taxonomies & set(rule.get("taxonomy_any", [])))
            if v_ok and (t_ok or not rule.get("taxonomy_any")):
                snippet = ",".join(sorted(verdicts & set(rule.get("verdict_any", []))))
                candidates.append((rule["precedence"], rule["reason"], rule["id"], snippet))
        hold_text = " ".join(sorted(holds)).lower()
        for rule in config.get("hold_code_rules", []):
            hit = _match_any(hold_text, rule.get("match_any", []))
            if hit:
                candidates.append((rule["precedence"], rule["reason"], rule["id"], hit))

    if not candidates:
        return "OTHER", "none", ""
    candidates.sort(key=lambda c: (c[0], c[2]))
    prec, reason, rule_id, snippet = candidates[0]
    return reason, rule_id, snippet


# ---------------------------------------------------------------------------
# Clone suppression (directive 25) via behaviour lineage map
# ---------------------------------------------------------------------------
def build_clone_index(
    lineage: dict[str, Any], config: dict[str, Any]
) -> dict[str, list[tuple[str, str]]]:
    """Map ea_id -> [(relation, other_ea_id), ...] for clone/material edges."""
    suppress = set(config.get("clone_relations_suppress", []))
    material = set(config.get("materially_different_relations", []))
    keep = suppress | material
    idx: dict[str, list[tuple[str, str]]] = {}
    for e in lineage.get("edges", []):
        rel = e.get("relation")
        if rel not in keep:
            continue
        a, b = e.get("from"), e.get("to")
        if a and b:
            idx.setdefault(a, []).append((rel, b))
            idx.setdefault(b, []).append((rel, a))
    return idx


def _clone_keeper(
    ea_id: str,
    neighbours: list[tuple[str, str]],
    node_class: dict[str, str],
    suppress: set[str],
) -> str | None:
    """Pick the surviving counterpart to suppress against, or None.

    Preference for the keeper: an ACTIVE_CANONICAL neighbour, else the lowest
    numeric ea_id among the clone neighbours (and this node). This node is
    suppressed only when the chosen keeper is a DIFFERENT record.
    """
    clone_neighbours = [b for rel, b in neighbours if rel in suppress]
    if not clone_neighbours:
        return None
    pool = set(clone_neighbours) | {ea_id}
    actives = sorted(
        n for n in pool if node_class.get(n, "").upper() in ("ACTIVE_CANONICAL", "ACTIVE")
    )
    if actives:
        keeper = actives[0]
    else:
        keeper = min(pool, key=_numeric_key)
    return keeper if keeper != ea_id else None


def _numeric_key(ea_id: str) -> tuple[int, str]:
    m = _EA_NUM_RE.search(ea_id)
    return (int(m.group(1)) if m else 10**9, ea_id)


# ---------------------------------------------------------------------------
# Priority scoring (directive 26)
# ---------------------------------------------------------------------------
def _symbol_tokens(rec: NodeRec) -> list[str]:
    raw = rec.intended_symbols or ""
    toks = [t.strip().upper() for t in re.split(r"[,\s]+", raw) if t.strip()]
    return [t.replace(".DWX", "") for t in toks if t not in ("UNKNOWN", "")]


def _ram_class(rec: NodeRec, scoring: dict[str, Any]) -> int:
    table = scoring.get("symbol_ram_class", {})
    heaviest = 0
    for sym in _symbol_tokens(rec):
        if sym in table:
            heaviest = max(heaviest, int(table[sym]))
    if heaviest:
        return heaviest
    # no known heavy index symbol -> light default
    return int(table.get("_default_light", 4))


def _ftmo_relevance(rec: NodeRec, scoring: dict[str, Any]) -> float:
    text = f"{rec.strategy_family} {rec.slug} {rec.name}".lower()
    tfs = {t.strip().upper() for t in re.split(r"[,\s]+", rec.timeframes or "") if t.strip()}
    score = 0.2
    if tfs & set(scoring.get("ftmo_intraday_timeframes", [])):
        score = max(score, 0.8)
    if _match_any(text, [m.lower() for m in scoring.get("ftmo_relevance_markers", [])]):
        score = max(score, 0.7)
    syms = _symbol_tokens(rec)
    prefixes = tuple(scoring.get("low_swap_symbol_prefixes", []))
    if syms and any(s.startswith(prefixes) for s in syms):
        score = max(score, min(1.0, score + 0.2))
    return round(min(1.0, score), 4)


def _dxz_relevance(rec: NodeRec) -> float:
    # DXZ takes a broader universe; index / metal / energy diversify a
    # majority-FX book. Baseline 0.6, +0.2 for a non-FX symbol class.
    syms = _symbol_tokens(rec)
    non_fx = any(not re.fullmatch(r"[A-Z]{6}", s) for s in syms) if syms else False
    return round(0.6 + (0.2 if non_fx else 0.0), 4)


def _novelty(ea_id: str, lineage: dict[str, Any], clone_idx: dict[str, list[tuple[str, str]]]) -> float:
    node = lineage.get("nodes", {}).get(ea_id, {})
    fam = node.get("family")
    fam_size = len(lineage.get("families", {}).get(fam, [])) if fam else 0
    base = 1.0
    for rel, _ in clone_idx.get(ea_id, []):
        if rel == "exact_clone":
            base = min(base, 0.0)
        elif rel == "close_implementation_clone":
            base = min(base, 0.3)
    # crowded family reduces novelty (cap the penalty at 0.3)
    base -= min(0.3, fam_size / 800.0)
    return round(max(0.0, base), 4)


def _expected_edge(ea_id: str, lineage: dict[str, Any], rec: NodeRec, db_summary: dict[str, Any] | None) -> float:
    node = lineage.get("nodes", {}).get(ea_id, {})
    has_stream = bool(node.get("has_trade_stream"))
    verdicts = set((db_summary or {}).get("verdicts", {}).keys())
    positive = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "MEASURED", "PRESCREEN_MEASURED", "OPT_ELIGIBLE"}
    if has_stream and (verdicts & positive):
        return 1.0
    if has_stream:
        return 0.6
    if rec.current_blocker and rec.current_blocker not in ("NOT_EVALUATED", "NOT_APPLICABLE", ""):
        return 0.35  # reached a gate -> some evidence exists
    if verdicts & positive:
        return 0.4
    return 0.1


def _independence(ea_id: str, clone_idx: dict[str, list[tuple[str, str]]]) -> float:
    # Fewer behaviour ties -> more independent. same_edge ties are captured via
    # the wider lineage; here penalise clone ties only (material edges are fine).
    n = sum(1 for rel, _ in clone_idx.get(ea_id, []) if rel != "materially_different")
    return round(max(0.2, 1.0 - 0.2 * n), 4)


def _execution_complexity_inv(reason: str, rec: NodeRec) -> float:
    text = f"{rec.strategy_family} {rec.slug}".lower()
    complex_markers = ("basket", "multi", "grid", "pyramid", "pair", "cross-sectional", "two-leg")
    hard = reason in ("MARTINGALE", "GRID", "PYRAMIDING", "MULTI_POSITION") or _match_any(text, complex_markers)
    return 0.5 if hard else 1.0


def _whitespace_bonus(rec: NodeRec, universe: dict[str, Any]) -> float:
    """Map the record onto the universe white-space cells (style x symbol_class).

    Coarse deterministic mapping: the record's style + symbol_class -> the best
    (max expected_value) white-space cell that matches, normalised by the map's
    top expected_value. 0.0 when it cannot be mapped.
    """
    ranked = universe.get("whitespace_ranked", [])
    if not ranked:
        return 0.0
    top_ev = max((c.get("expected_value", 0) for c in ranked), default=0) or 1
    style = _infer_style(rec)
    sym_class = _infer_symbol_class(rec)
    best = 0.0
    for c in ranked:
        if style and c.get("style") != style:
            continue
        if sym_class and c.get("symbol_class") != sym_class:
            continue
        best = max(best, float(c.get("expected_value", 0)) / top_ev)
    return round(best, 4)


def _infer_style(rec: NodeRec) -> str | None:
    t = f"{rec.strategy_family} {rec.slug} {rec.name}".lower()
    if _match_any(t, ["mean-reversion", "mean reversion", "reversion", "bounce", "fade", "rsi", "bollinger"]):
        return "mean-reversion"
    if _match_any(t, ["breakout", "donchian", "channel-break", "range-break"]):
        return "breakout"
    if _match_any(t, ["trend", "momentum", "ma-cross", "moving-average", "macd"]):
        return "trend"
    if _match_any(t, ["pattern", "candle", "pinbar", "engulf"]):
        return "pattern"
    if _match_any(t, ["basket", "pair", "portfolio", "rotation", "cross-sectional"]):
        return "basket"
    return None


def _infer_symbol_class(rec: NodeRec) -> str | None:
    syms = _symbol_tokens(rec)
    if not syms:
        return None
    s = syms[0]
    idx = {"SP500", "US500", "NDX", "NAS100", "WS30", "US30", "GDAXI", "GER40", "UK100", "FTSE", "NIKKEI", "STOXX50"}
    if s in idx:
        return "index"
    if s in ("XAUUSD", "XAGUSD", "GOLD", "SILVER"):
        return "metal"
    if s in ("XTIUSD", "OIL", "WTI", "BRENT"):
        return "energy"
    if re.fullmatch(r"[A-Z]{6}", s):
        if "JPY" in s:
            return "fx_jpy"
        if s[:3] == "USD" or s[3:] == "USD":
            return "fx_major"
        return "fx_cross"
    return "other"


def score_record(
    rec: NodeRec,
    reason: str,
    lineage: dict[str, Any],
    clone_idx: dict[str, list[tuple[str, str]]],
    universe: dict[str, Any],
    db_summary: dict[str, Any] | None,
    config: dict[str, Any],
) -> tuple[float, dict[str, float], bool]:
    scoring = config["scoring"]
    weights = scoring["weights"]
    comps = {
        "ftmo_relevance": _ftmo_relevance(rec, scoring),
        "expected_edge": _expected_edge(rec.ea_id, lineage, rec, db_summary),
        "whitespace_bonus": _whitespace_bonus(rec, universe),
        "novelty": _novelty(rec.ea_id, lineage, clone_idx),
        "independence": _independence(rec.ea_id, clone_idx),
        "dxz_relevance": _dxz_relevance(rec),
        "validation_cost_inv": float(
            scoring["ram_cost_inv"].get(str(_ram_class(rec, scoring)), 0.5)
        ),
        "execution_complexity_inv": _execution_complexity_inv(reason, rec),
    }
    total = 100.0 * sum(weights[k] * comps[k] for k in weights)
    tail_flag = reason in set(scoring.get("tail_risk_reasons", []))
    if tail_flag:
        total -= float(scoring.get("tail_penalty_if_unbounded", 0.0))
    return round(max(0.0, total), 3), comps, tail_flag


# ---------------------------------------------------------------------------
# Counterfactual (directive 27/28) — portfolio-utility challenger test
# ---------------------------------------------------------------------------
def _index_streams(stream_dir: Path) -> dict[str, list[Path]]:
    """Map numeric ea id -> [stream paths]."""
    out: dict[str, list[Path]] = {}
    d = Path(stream_dir)
    if not d.is_dir():
        return out
    for p in sorted(d.glob("*.jsonl")):
        m = re.match(r"(\d+)_", p.name)
        if m:
            out.setdefault(m.group(1), []).append(p)
    return out


def _daily_pnl_for_ids(numeric_ids: Iterable[str], stream_index: dict[str, list[Path]]) -> dict[str, float]:
    combined: dict[str, float] = {}
    for num in numeric_ids:
        for p in stream_index.get(num, []):
            loaded = lineage_mod.load_trade_stream(p)
            for day, net in loaded.get("daily_pnl", {}).items():
                combined[day] = combined.get(day, 0.0) + float(net)
    return combined


def _window_series(daily: dict[str, float], lo: str, hi: str) -> list[tuple[str, float]]:
    return sorted((d, v) for d, v in daily.items() if lo <= d <= hi)


def _venue_objective(series: list[tuple[str, float]]) -> dict[str, float]:
    """Calmar-like venue objective on a daily-PnL series: total / max drawdown.

    A larger objective is better. Max drawdown is computed on the cumulative
    equity curve; when there is no drawdown the objective is the total return
    (drawdown floored at a tiny epsilon to stay finite and deterministic).
    """
    total = 0.0
    peak = 0.0
    max_dd = 0.0
    cum = 0.0
    for _, v in series:
        cum += v
        total = cum
        peak = max(peak, cum)
        max_dd = max(max_dd, peak - cum)
    denom = max_dd if max_dd > 1e-9 else 1e-9
    return {"total": round(cum, 4), "max_dd": round(max_dd, 4), "objective": round(cum / denom, 6)}


def _choose_holdout(all_days: Iterable[str]) -> tuple[str, str, str]:
    """Pick the OOS split window. Prefer the sealed 2026 window when it holds
    data; otherwise the last full calendar year present. Returns (lo, hi, note).
    """
    days = sorted(set(all_days))
    if not days:
        return SEALED_OOS_FROM, SEALED_OOS_TO, "no data"
    if any(SEALED_OOS_FROM <= d <= SEALED_OOS_TO for d in days):
        return SEALED_OOS_FROM, SEALED_OOS_TO, "sealed 2026 OOS window (oos_2026_confirmation.py)"
    year = days[-1][:4]
    return f"{year}-01-01", f"{year}-12-31", f"trailing full calendar year {year} of sealed Q08 data"


def counterfactual(
    classifications: list[Classification],
    book_dxz: dict[str, Any],
    book_ftmo: dict[str, Any],
    stream_index: dict[str, list[Path]],
    config: dict[str, Any],
) -> dict[str, Any]:
    """Section-27 counterfactual for economically-rejected, streamed records."""

    def roster_ids(book: dict[str, Any]) -> list[str]:
        inc = book.get("incumbent", {}) or {}
        return [str(s.get("ea_id")) for s in inc.get("sleeves", []) if s.get("ea_id") is not None]

    venues: dict[str, dict[str, Any]] = {}
    challengers: list[dict[str, Any]] = []

    econ = [c for c in classifications if c.reason == "ECONOMIC_FAIL"]
    streamed = [c for c in econ if c.node and c.node.numeric_id in stream_index]
    missing = [c.ea_id for c in econ if not (c.node and c.node.numeric_id in stream_index)]

    # Determine the holdout window from all involved streams (roster+candidates).
    all_daily: dict[str, float] = {}
    for _, book in (("DXZ", book_dxz), ("FTMO", book_ftmo)):
        for d in _daily_pnl_for_ids(roster_ids(book), stream_index):
            all_daily[d] = 0.0
    for c in streamed:
        for d in _daily_pnl_for_ids([c.node.numeric_id], stream_index):
            all_daily[d] = 0.0
    holdout_from, holdout_to, holdout_note = _choose_holdout(all_daily.keys())

    method = {
        "holdout_from": holdout_from,
        "holdout_to": holdout_to,
        "holdout_convention": holdout_note,
        "sealed_oos_window": f"{SEALED_OOS_FROM}..{SEALED_OOS_TO} (preferred once sealed streams carry it)",
        "objective": "Calmar-like: cumulative holdout net PnL / max drawdown on the combined daily equity curve",
        "rule": "candidate is a PORTFOLIO_UTILITY_CHALLENGER when adding its holdout daily PnL to the venue roster raises the venue objective AND does not increase max drawdown beyond the roster's own max drawdown",
        "source_streams": "sealed Q08 trade streams (D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades)",
    }

    for venue, book in (("DXZ", book_dxz), ("FTMO", book_ftmo)):
        ids = roster_ids(book)
        base_daily = _daily_pnl_for_ids(ids, stream_index)
        base_series = _window_series(base_daily, holdout_from, holdout_to)
        base_obj = _venue_objective(base_series)
        venues[venue] = {
            "roster_ea_ids": ids,
            "roster_streams_found": sum(1 for i in ids if i in stream_index),
            "holdout_days": len(base_series),
            "base_objective": base_obj,
        }
        if not base_series:
            venues[venue]["status"] = MISSING
            continue
        venues[venue]["status"] = "EVALUATED"
        for c in streamed:
            cand_daily = _daily_pnl_for_ids([c.node.numeric_id], stream_index)
            cand_series = _window_series(cand_daily, holdout_from, holdout_to)
            if not cand_series:
                continue
            merged: dict[str, float] = dict(base_daily)
            for d, v in cand_daily.items():
                merged[d] = merged.get(d, 0.0) + v
            new_series = _window_series(merged, holdout_from, holdout_to)
            new_obj = _venue_objective(new_series)
            improves = (
                new_obj["objective"] > base_obj["objective"]
                and new_obj["max_dd"] <= base_obj["max_dd"] + 1e-9
            )
            if improves:
                challengers.append(
                    {
                        "ea_id": c.ea_id,
                        "venue": venue,
                        "candidate_holdout_days": len(cand_series),
                        "base_objective": base_obj["objective"],
                        "new_objective": new_obj["objective"],
                        "objective_delta": round(new_obj["objective"] - base_obj["objective"], 6),
                        "base_max_dd": base_obj["max_dd"],
                        "new_max_dd": new_obj["max_dd"],
                    }
                )

    challengers.sort(key=lambda x: (-x["objective_delta"], x["ea_id"], x["venue"]))
    return {
        "schema": CHALLENGER_SCHEMA,
        "method": method,
        "economic_fail_records": len(econ),
        "economic_fail_with_stream": len(streamed),
        "economic_fail_without_stream": sorted(missing),
        "venues": venues,
        "challengers": challengers,
        "evidence_missing": len(challengers) == 0 and len(streamed) == 0,
        "class_spec": _challenger_class_spec(),
    }


def _challenger_class_spec() -> dict[str, Any]:
    return {
        "class": "PORTFOLIO_UTILITY_CHALLENGER",
        "authority": "OWNER follow-up directive 2026-09-15 (third) section 28",
        "meaning": "Sufficient evidence exists to test portfolio utility despite failing an old standalone selection threshold. It does NOT rewrite the original gate PASS/FAIL.",
        "requirements": [
            "valid sealed evidence (a Q08/Q14 trade stream over the selection window)",
            "bounded risk (a deterministic per-sleeve and portfolio risk contract)",
            "an independent holdout (the 2026 OOS window, separate from selection)",
            "an explicit portfolio-role hypothesis (which venue, what diversification / tail role)",
        ],
        "does_not_grant": ["automatic live eligibility", "a gate PASS", "T_Live / AutoTrading authority"],
        "evaluated_against": "the current DXZ / FTMO book at portfolio level",
    }


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------
def _eligibility(
    reason: str,
    matched_rule: str,
    config: dict[str, Any],
    lineage_relations: list[tuple[str, str]],
    is_challenger: bool,
) -> str:
    default = config["eligibility_defaults"].get(reason, STILL_INVALID)
    # registry rule may pin an override (empty reservations stay invalid).
    for rule in config.get("registry_reason_rules", []):
        if rule["id"] == matched_rule and rule.get("eligibility_override"):
            default = rule["eligibility_override"]
    if reason == "DUPLICATE":
        material = {r for r in config.get("materially_different_relations", [])}
        if any(rel in material for rel, _ in lineage_relations):
            default = ELIGIBLE
    if reason == "ECONOMIC_FAIL" and is_challenger:
        default = ELIGIBLE
    return default


def build_register(
    *,
    generated_dir: Path,
    config_path: Path = DEFAULT_CONFIG,
    registry_path: Path = DEFAULT_REGISTRY,
    lineage_path: Path = DEFAULT_LINEAGE,
    universe_path: Path = DEFAULT_UNIVERSE,
    db_path: Path = DEFAULT_DB,
    artifacts_root: Path = DEFAULT_ARTIFACTS_ROOT,
    book_dxz_path: Path = DEFAULT_BOOK_DXZ,
    book_ftmo_path: Path = DEFAULT_BOOK_FTMO,
    stream_dir: Path = DEFAULT_STREAM_DIR,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    config = load_config(config_path)
    nodes = load_nodes(generated_dir)
    registry = load_registry(registry_path)
    lineage = load_lineage(lineage_path)
    universe = load_universe(universe_path)
    db_summary = db_verdict_summary(db_path)
    store_reasons = load_card_store_reasons(artifacts_root)
    book_dxz = _load_json(book_dxz_path)
    book_ftmo = _load_json(book_ftmo_path)
    stream_index = _index_streams(stream_dir)

    clone_idx = build_clone_index(lineage, config)
    suppress = set(config.get("clone_relations_suppress", []))
    node_class = {rec.ea_id: rec.projection_class for rec in nodes}
    # add active-canonical class from lineage-known nodes not in population
    for nid in lineage.get("nodes", {}):
        node_class.setdefault(nid, "ACTIVE_CANONICAL")

    classifications: list[Classification] = []
    for rec in nodes:
        card_reason = read_card_reason(rec.canonical_repo_path) or store_reasons.get(
            (rec.numeric_id, rec.slug), ""
        )
        reg_row = registry.get(rec.numeric_id)
        db_sum = db_summary.get(rec.numeric_id)
        reason, rule_id, snippet = classify(rec, card_reason, reg_row, db_sum, config)
        relations = clone_idx.get(rec.ea_id, [])
        eligibility = _eligibility(reason, rule_id, config, relations, is_challenger=False)
        keeper = _clone_keeper(rec.ea_id, relations, node_class, suppress)
        if keeper:
            status = f"SUPPRESSED_CLONE_OF:{keeper}"
        else:
            status = eligibility
        priority, comps, tail_flag = score_record(
            rec, reason, lineage, clone_idx, universe, db_sum, config
        )
        classifications.append(
            Classification(
                ea_id=rec.ea_id,
                reason=reason,
                matched_rule=rule_id,
                eligibility=eligibility,
                status=status,
                suppressed_clone_of=keeper,
                portfolio_utility_challenger=False,
                tail_risk_flag=tail_flag,
                priority=priority,
                score_components=comps,
                reason_evidence=(card_reason or snippet or "")[:280],
                node=rec,
            )
        )

    # Counterfactual + PORTFOLIO_UTILITY_CHALLENGER flag back-write.
    cf = counterfactual(classifications, book_dxz, book_ftmo, stream_index, config)
    challenger_ids = {c["ea_id"] for c in cf["challengers"]}
    for c in classifications:
        if c.ea_id in challenger_ids and c.reason == "ECONOMIC_FAIL":
            c.portfolio_utility_challenger = True
            if not c.suppressed_clone_of:
                c.eligibility = ELIGIBLE
                c.status = ELIGIBLE

    ts = (now or dt.datetime.now(dt.UTC)).replace(microsecond=0).isoformat()
    inputs_sha = _inputs_sha256(config, nodes, registry, lineage, universe, db_summary)

    counts = _counts(classifications)
    ranked = _ranked(classifications)

    register = {
        "schema": SCHEMA,
        "generator": GENERATOR,
        "generated_at_utc": ts,
        "inputs_sha256": inputs_sha,
        "authority": config.get("authority"),
        "population_classes": list(POPULATION_CLASSES),
        "config": {
            "path": _rel(config_path),
            "version": config.get("version"),
            "schema": config.get("schema"),
        },
        "counts": counts,
        "counterfactual": cf,
        "records": [_record_dict(c) for c in sorted(classifications, key=_numeric_key_c)],
        "ranked_top200": ranked[:200],
    }
    return register


def _numeric_key_c(c: Classification) -> tuple[int, str]:
    return _numeric_key(c.ea_id)


def _load_json(path: Path) -> dict[str, Any]:
    p = Path(path)
    if not p.is_file():
        return {}
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def _rel(path: Path) -> str:
    try:
        return Path(path).resolve().relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return Path(path).as_posix()


def _record_dict(c: Classification) -> dict[str, Any]:
    n = c.node
    return {
        "ea_id": c.ea_id,
        "slug": n.slug if n else "",
        "projection_class": n.projection_class if n else "",
        "primary_reason": c.reason,
        "matched_rule": c.matched_rule,
        "eligibility": c.eligibility,
        "second_chance_status": c.status,
        "suppressed_clone_of": c.suppressed_clone_of or "",
        "portfolio_utility_challenger": c.portfolio_utility_challenger,
        "tail_risk_flag": c.tail_risk_flag,
        "priority": c.priority,
        "score_components": c.score_components,
        "strategy_family": n.strategy_family if n else "",
        "timeframes": n.timeframes if n else "",
        "intended_symbols": n.intended_symbols if n else "",
        "reason_evidence": c.reason_evidence,
    }


def _counts(classifications: list[Classification]) -> dict[str, Any]:
    by_reason: dict[str, int] = {}
    by_status: dict[str, int] = {}
    matrix: dict[str, dict[str, int]] = {}
    challengers = 0
    suppressed = 0
    tail = 0
    for c in classifications:
        by_reason[c.reason] = by_reason.get(c.reason, 0) + 1
        skey = "SUPPRESSED_CLONE_OF" if c.suppressed_clone_of else c.eligibility
        by_status[skey] = by_status.get(skey, 0) + 1
        matrix.setdefault(c.reason, {})
        matrix[c.reason][skey] = matrix[c.reason].get(skey, 0) + 1
        if c.portfolio_utility_challenger:
            challengers += 1
        if c.suppressed_clone_of:
            suppressed += 1
        if c.tail_risk_flag:
            tail += 1
    eligible = sum(
        1 for c in classifications if c.status == ELIGIBLE or c.portfolio_utility_challenger
    )
    return {
        "total": len(classifications),
        "eligible_for_reconsideration": eligible,
        "still_invalid": by_status.get(STILL_INVALID, 0),
        "suppressed_clone": suppressed,
        "portfolio_utility_challengers": challengers,
        "tail_risk_flagged": tail,
        "by_reason": dict(sorted(by_reason.items())),
        "by_status": dict(sorted(by_status.items())),
        "reason_x_eligibility": {k: dict(sorted(v.items())) for k, v in sorted(matrix.items())},
    }


def _ranked(classifications: list[Classification]) -> list[dict[str, Any]]:
    elig = [
        c for c in classifications
        if (c.status == ELIGIBLE or c.portfolio_utility_challenger) and not c.suppressed_clone_of
    ]
    elig.sort(key=lambda c: (-c.priority, _numeric_key(c.ea_id)))
    return [
        {
            "rank": i + 1,
            "ea_id": c.ea_id,
            "slug": c.node.slug if c.node else "",
            "primary_reason": c.reason,
            "priority": c.priority,
            "portfolio_utility_challenger": c.portfolio_utility_challenger,
            "tail_risk_flag": c.tail_risk_flag,
            "ftmo_relevance": c.score_components.get("ftmo_relevance"),
            "intended_symbols": c.node.intended_symbols if c.node else "",
        }
        for i, c in enumerate(elig)
    ]


def _inputs_sha256(config, nodes, registry, lineage, universe, db_summary) -> str:
    payload = {
        "config": config.get("schema"),
        "config_version": config.get("version"),
        "nodes": sorted(
            (n.ea_id, n.projection_class, n.canonical_repo_path, n.terminal_verdict, n.current_blocker)
            for n in nodes
        ),
        "registry_keys": sorted(registry.keys()),
        "lineage_inputs": lineage.get("inputs_sha256"),
        "universe_inputs": universe.get("inputs_sha256"),
        "db_ids": sorted(db_summary.keys()),
    }
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------
CSV_COLUMNS = [
    "ea_id", "slug", "projection_class", "primary_reason", "matched_rule",
    "eligibility", "second_chance_status", "suppressed_clone_of",
    "portfolio_utility_challenger", "tail_risk_flag", "priority",
    "strategy_family", "timeframes", "intended_symbols", "reason_evidence",
]


def write_csv(register: dict[str, Any], path: Path) -> int:
    rows = register["records"]
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=CSV_COLUMNS, extrasaction="ignore", lineterminator="\n")
    w.writeheader()
    for r in rows:
        row = {k: r.get(k, "") for k in CSV_COLUMNS}
        w.writerow(row)
    _write_if_changed(Path(path), buf.getvalue())
    return len(rows)


def render_vault_page(register: dict[str, Any]) -> str:
    counts = register["counts"]
    cf = register["counterfactual"]
    lines: list[str] = []
    lines.append("---")
    lines.append("generated: true")
    lines.append(f"generator: {GENERATOR}")
    lines.append(f"schema: {SCHEMA}")
    lines.append(f"generated_at_utc: {register['generated_at_utc']}")
    lines.append(f"inputs_sha256: {register['inputs_sha256']}")
    lines.append("---")
    lines.append("")
    lines.append("# Second-Chance Register")
    lines.append("")
    lines.append(
        "> Generated node — do not edit. Managed by "
        "`tools/strategy_farm/research/second_chance_register.py`. "
        "Historical verdicts are immutable; this register only proposes NEW-lineage "
        "re-evaluation of records blocked by now-superseded style/policy rules "
        "(OWNER directive 2026-09-15 third, sections 23-28, 31-32, 38)."
    )
    lines.append("")
    lines.append("## Counts")
    lines.append("")
    lines.append(f"- Population (REJECTED / RETIRED / DRAFT): **{counts['total']}**")
    lines.append(f"- Eligible for reconsideration: **{counts['eligible_for_reconsideration']}**")
    lines.append(f"- Still invalid: **{counts['still_invalid']}**")
    lines.append(f"- Suppressed clones (directive 25): **{counts['suppressed_clone']}**")
    lines.append(f"- Portfolio-utility challengers (directive 27/28): **{counts['portfolio_utility_challengers']}**")
    lines.append(f"- Tail-risk flagged (martingale/grid/pyramiding): **{counts['tail_risk_flagged']}**")
    lines.append("")
    lines.append("### Reason x eligibility")
    lines.append("")
    lines.append("| Reason | Eligible | Still invalid | Suppressed clone |")
    lines.append("|---|---:|---:|---:|")
    for reason, row in counts["reason_x_eligibility"].items():
        lines.append(
            f"| {reason} | {row.get(ELIGIBLE, 0)} | {row.get(STILL_INVALID, 0)} | "
            f"{row.get('SUPPRESSED_CLONE_OF', 0)} |"
        )
    lines.append("")
    lines.append("## Counterfactual (directive 27/28)")
    lines.append("")
    lines.append(f"- Economic-fail records: {cf['economic_fail_records']}")
    lines.append(f"- With a sealed Q08 stream: {cf['economic_fail_with_stream']}")
    lines.append(f"- Portfolio-utility challengers found: {len(cf['challengers'])}")
    if cf["challengers"]:
        lines.append("")
        lines.append("| EA | Venue | obj delta | base obj | new obj |")
        lines.append("|---|---|---:|---:|---:|")
        for ch in cf["challengers"]:
            lines.append(
                f"| {ch['ea_id']} | {ch['venue']} | {ch['objective_delta']} | "
                f"{ch['base_objective']} | {ch['new_objective']} |"
            )
    elif cf["evidence_missing"]:
        lines.append("- Result: **EVIDENCE_MISSING** (no economically-rejected record owns a sealed stream).")
    lines.append("")
    lines.append("## Top 200 re-test candidates by expected portfolio value")
    lines.append("")
    lines.append("| # | EA | Reason | Priority | Challenger | Tail | FTMO rel | Symbols |")
    lines.append("|---:|---|---|---:|:--:|:--:|---:|---|")
    for r in register["ranked_top200"]:
        lines.append(
            f"| {r['rank']} | {r['ea_id']} | {r['primary_reason']} | {r['priority']} | "
            f"{'Y' if r['portfolio_utility_challenger'] else ''} | "
            f"{'Y' if r['tail_risk_flag'] else ''} | {r['ftmo_relevance']} | "
            f"{r['intended_symbols']} |"
        )
    lines.append("")
    return "\n".join(lines) + "\n"


def _write_if_changed(path: Path, content: str) -> bool:
    data = content.encode("utf-8")
    if path.is_file():
        try:
            if path.read_bytes() == data:
                return False
        except OSError:
            pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    return True


def write_all(
    register: dict[str, Any],
    *,
    out_json: Path = DEFAULT_OUT_JSON,
    out_csv: Path = DEFAULT_OUT_CSV,
    vault_override: Path | None = None,
) -> dict[str, Any]:
    _write_if_changed(Path(out_json), json.dumps(register, indent=2, ensure_ascii=False, sort_keys=False) + "\n")
    n = write_csv(register, out_csv)
    page = render_vault_page(register)
    vault_page = vault_paths.strategy_wiki_root(vault_override) / VAULT_PAGE_NAME
    _write_if_changed(vault_page, page)
    return {
        "json": str(out_json),
        "csv": str(out_csv),
        "csv_rows": n,
        "vault_page": str(vault_page),
    }


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Generate the Second-Chance Strategy Register.")
    ap.add_argument("--generated-dir", default=str(vault_paths.strategy_wiki_generated_dir()))
    ap.add_argument("--config", default=str(DEFAULT_CONFIG))
    ap.add_argument("--registry", default=str(DEFAULT_REGISTRY))
    ap.add_argument("--lineage", default=str(DEFAULT_LINEAGE))
    ap.add_argument("--universe", default=str(DEFAULT_UNIVERSE))
    ap.add_argument("--db", default=str(DEFAULT_DB))
    ap.add_argument("--artifacts-root", default=str(DEFAULT_ARTIFACTS_ROOT))
    ap.add_argument("--book-dxz", default=str(DEFAULT_BOOK_DXZ))
    ap.add_argument("--book-ftmo", default=str(DEFAULT_BOOK_FTMO))
    ap.add_argument("--stream-dir", default=str(DEFAULT_STREAM_DIR))
    ap.add_argument("--out-json", default=str(DEFAULT_OUT_JSON))
    ap.add_argument("--out-csv", default=str(DEFAULT_OUT_CSV))
    ap.add_argument("--vault-override", default=None)
    ap.add_argument("--dry-run", action="store_true", help="print counts, write nothing")
    args = ap.parse_args(argv)

    register = build_register(
        generated_dir=Path(args.generated_dir),
        config_path=Path(args.config),
        registry_path=Path(args.registry),
        lineage_path=Path(args.lineage),
        universe_path=Path(args.universe),
        db_path=Path(args.db),
        artifacts_root=Path(args.artifacts_root),
        book_dxz_path=Path(args.book_dxz),
        book_ftmo_path=Path(args.book_ftmo),
        stream_dir=Path(args.stream_dir),
    )
    counts = register["counts"]
    if args.dry_run:
        print(json.dumps(counts, indent=2))
        return 0
    written = write_all(
        register,
        out_json=Path(args.out_json),
        out_csv=Path(args.out_csv),
        vault_override=Path(args.vault_override) if args.vault_override else None,
    )
    print(json.dumps({"counts": counts, "written": written}, indent=2))
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
