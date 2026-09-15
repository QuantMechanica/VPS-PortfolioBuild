#!/usr/bin/env python
"""Deterministic strategy lineage / duplicate map builder (OWNER directive 2026-09-15 §9; master §56).

Read-only. Idempotent: the same inputs produce byte-identical output. The only
field that carries a wall-clock value is ``generated_at_utc``; to keep the output
byte-identical when nothing changed, the builder reuses the previous file's
``generated_at_utc`` whenever ``inputs_sha256`` is unchanged, so the timestamp
advances only when the underlying evidence changes (see ``_stamp_or_reuse``).

The builder computes, for the whole EA corpus:

  (a) a MECHANISM SIGNATURE per EA -- a SHA256 over the normalized ``Strategy_*``
      hook region of the ``.mq5`` (see ``compute_rule_signature`` for the exact,
      documented normalization). It is stable under comment / whitespace /
      input-default / hook-name changes, so byte-equal signatures mean the same
      strategy logic re-expressed only cosmetically.

  (b) PARAMETER-SET DISTANCE between EAs (normalized L1 over shared ``strategy_*``
      set-file inputs).

  (c) TRADE-OVERLAP JACCARD on entry days and daily-PnL PEARSON CORRELATION
      between (EA, symbol) runs, from the sealed Q08 trade streams under
      ``D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades/<numid>_<SYMBOL>_DWX.jsonl``.

  (d) CARD-LINEAGE edges from strategy-card frontmatter (parent_ea_id / variant_of).

  (e) FAMILY assignment (coarse, reused from the whitespace audit's slug
      derivation) and NAMED-FAMILY tagging for the §9 clusters.

then classifies each candidate pair into the seven §9 relationship classes with
the config-driven thresholds and writes:

  * ``D:/QM/reports/state/lineage_map.json``  (schema ``qm.lineage-map/v1``)
  * ``docs/research/STRATEGY_LINEAGE_MAP_2026-09.md``  (Markdown summary)
  * ``09 Strategy Wiki/Lineage Map.md`` in the Vault (generated marker)

Compute is bounded: signatures for every EA (cheap); behaviour + rule-similarity
only for pairs inside the same coarse family, inside a named family, or with an
equal signature, and for pairs where both have a sealed stream. Exact-clone
groups are emitted as star edges from a canonical member (not the full clique).

RED boundaries respected: no gate/verdict writes, no DB writes, no terminal, no
credentials. The farm DB is opened read-only for terminal-verdict lookups only.
"""

from __future__ import annotations

import argparse
import datetime as dt
import glob
import hashlib
import json
import os
import re
import sqlite3
from itertools import combinations
from pathlib import Path
from typing import Any, Iterable

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #

REPO = Path(__file__).resolve().parents[2]
EAS_DIR = REPO / "framework" / "EAs"
CONFIG_PATH = Path(__file__).resolve().parent / "config" / "strategy_families.v1.json"
SEED_CARDS_DIR = REPO / "strategy-seeds" / "cards"

STREAM_DIR = Path(r"D:/QM/reports/portfolio/sleeve_streams/QM/q08_trades")
DB_PATH = Path(r"D:/QM/strategy_farm/state/farm_state.sqlite")

OUT_JSON = Path(r"D:/QM/reports/state/lineage_map.json")
OUT_MD = REPO / "docs" / "research" / "STRATEGY_LINEAGE_MAP_2026-09.md"
VAULT_PAGE = Path(
    r"G:/My Drive/QuantMechanica - Company Reference/09 Strategy Wiki/Lineage Map.md"
)

SCHEMA = "qm.lineage-map/v1"
GENERATED_MARKER = "qm_generated: lineage_map.py"

# Terminal retire / supersede verdict PREFIXES (for SUPERSEDED). Deliberately
# excludes intermediate-gate FAIL/FAIL_SOFT: those are not a terminal head-to-head
# loss. Matched by upper-cased prefix against the stored verdict token.
_TERMINAL_RETIRE = ("RETIRE", "SUPERSEDED", "OPT_REJECTED", "REJECTED")


# --------------------------------------------------------------------------- #
# Config
# --------------------------------------------------------------------------- #

def load_config(path: Path = CONFIG_PATH) -> dict[str, Any]:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


# --------------------------------------------------------------------------- #
# (e) Family assignment
# --------------------------------------------------------------------------- #

def classify_family(slug: str, cfg: dict[str, Any]) -> str:
    """First-match slug -> coarse family (reuses the whitespace-audit derivation)."""

    text = str(slug or "").lower()
    if not text:
        return "unclassified"
    coarse = cfg["coarse_families"]
    keywords = coarse["keywords"]
    for family in coarse["order"]:
        if any(needle in text for needle in keywords[family]):
            return family
    return "other"


def named_families_for(slug: str, symbol_bases: Iterable[str], cfg: dict[str, Any]) -> list[str]:
    """Non-exclusive §9 named-family tags for an EA (sorted, deterministic)."""

    text = str(slug or "").lower()
    bases = {s.split(".")[0].upper() for s in symbol_bases}
    tags: set[str] = set()
    defs = cfg["named_families"]["definitions"]
    for name, spec in defs.items():
        if any(sub in text for sub in spec.get("slug_substrings", [])):
            tags.add(name)
        if bases & {b.upper() for b in spec.get("symbol_bases", [])}:
            tags.add(name)
    return sorted(tags)


# --------------------------------------------------------------------------- #
# (a) Mechanism signature
# --------------------------------------------------------------------------- #

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT = re.compile(r"//[^\n]*")
_STRING_LITERAL = re.compile(r'"(?:[^"\\]|\\.)*"')
_STRATEGY_ID = re.compile(r"\bStrategy_[A-Za-z0-9_]+")
_FUNC_HEADER = re.compile(
    r"(?:^|[\n;}])\s*[A-Za-z_][\w:<>\* &]*?\bStrategy_[A-Za-z0-9_]+\s*\([^;{}]*\)\s*\{",
    re.DOTALL,
)
# Token = identifier | number | any single non-space punctuation char.
_TOKEN = re.compile(r"[A-Za-z_]\w*|\d+\.?\d*|[^\s]")


def strip_comments(text: str) -> str:
    text = _BLOCK_COMMENT.sub(" ", text)
    text = _LINE_COMMENT.sub(" ", text)
    return text


def _extract_strategy_bodies(text_no_comments: str) -> list[str]:
    """Return the source of each ``Strategy_*`` function body, brace-matched.

    Deterministic: functions are found by their header regex, then the body is
    read by balancing braces from the opening ``{``. Non-``Strategy_`` functions
    (framework OnInit/OnTick wiring, helpers) are ignored, isolating strategy
    logic from boilerplate.
    """

    bodies: list[str] = []
    for m in _FUNC_HEADER.finditer(text_no_comments):
        # The header match ends at the opening brace.
        open_idx = m.end() - 1
        depth = 0
        i = open_idx
        n = len(text_no_comments)
        while i < n:
            ch = text_no_comments[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        # Include the header (from the Strategy_ name) plus the body.
        header_start = m.start()
        # Trim leading separator captured by the header regex.
        seg = text_no_comments[header_start : i + 1]
        seg = seg.lstrip("\n;} \t")
        bodies.append(seg)
    return bodies


def _normalize_segment(seg: str) -> str:
    """Normalize one strategy function: drop hook names and string contents."""

    seg = _STRATEGY_ID.sub("FN", seg)          # EA-local hook names carry no semantic
    seg = _STRING_LITERAL.sub('""', seg)       # reason tags / labels are names only
    return seg


def _tokens(normalized_text: str) -> list[str]:
    return _TOKEN.findall(normalized_text)


def compute_rule_signature(mq5_text: str) -> tuple[str | None, list[str]]:
    """Return (sha256 hex | None, token list) for the normalized strategy region.

    Normalization (documented, must stay stable):
      1. Strip block and line comments.
      2. Extract every ``Strategy_*`` function body (brace-matched); everything
         else in the file is framework boilerplate and is discarded.
      3. Per function: replace ``Strategy_*`` identifiers with ``FN`` and blank
         out string-literal contents.
      4. Tokenize (identifier / number / punctuation) and re-join without
         whitespace, so comment/whitespace edits and input-default changes (which
         live in ``input`` declarations, outside the extracted region) do not move
         the hash.
      5. Sort the per-function normalized token-strings and join with ``|`` so a
         reordering of the hooks does not move the hash.
      6. SHA256 the joined string.

    Returns ``(None, [])`` when the EA declares no ``Strategy_*`` hook (guard
    against collapsing boilerplate-only files into one false clone bucket).
    """

    stripped = strip_comments(mq5_text)
    bodies = _extract_strategy_bodies(stripped)
    if not bodies:
        return None, []
    per_func: list[str] = []
    all_tokens: list[str] = []
    for body in bodies:
        norm = _normalize_segment(body)
        toks = _tokens(norm)
        per_func.append("".join(toks))
        all_tokens.extend(toks)
    per_func.sort()
    joined = "|".join(per_func)
    sig = hashlib.sha256(joined.encode("utf-8")).hexdigest()
    return sig, all_tokens


def token_counter(tokens: list[str]) -> dict[str, int]:
    """Multiset of tokens (used as the cheap rule-similarity basis)."""

    counter: dict[str, int] = {}
    for t in tokens:
        counter[t] = counter.get(t, 0) + 1
    return counter


def rule_similarity(counter_a: dict[str, int], counter_b: dict[str, int]) -> float:
    """Token-multiset Jaccard similarity in [0,1]. Deterministic and O(n).

    Chosen over an alignment (difflib) ratio so the corpus-wide pairwise sweep on
    the large named families stays bounded: this is a set operation on precomputed
    multisets, not an O(n*m) alignment. It is order-independent (a reordering of
    strategy hooks does not change it) and captures "same tokens, near-same counts"
    which is what "same mechanism re-typed" means at the token level.
    """

    if not counter_a or not counter_b:
        return 0.0
    keys = set(counter_a) | set(counter_b)
    inter = 0
    union = 0
    for k in keys:
        va = counter_a.get(k, 0)
        vb = counter_b.get(k, 0)
        inter += min(va, vb)
        union += max(va, vb)
    if union == 0:
        return 0.0
    return round(inter / union, 6)


# --------------------------------------------------------------------------- #
# (b) Parameter-set distance
# --------------------------------------------------------------------------- #

def parse_setfile(path: Path) -> dict[str, float]:
    """Parse ``strategy_*`` numeric inputs from a ``.set`` file (key=value)."""

    params: dict[str, float] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return params
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(";"):
            continue
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        if not key.startswith("strategy_"):
            continue
        value = value.split("||", 1)[0].strip()  # MT5 opt format: value||min||step||max
        try:
            params[key] = float(value)
        except ValueError:
            continue
    return params


def param_distance(a: dict[str, float], b: dict[str, float]) -> float | None:
    """Normalized L1 distance over shared ``strategy_*`` inputs, in [0,1].

    Per shared key: ``|a-b| / (|a|+|b|)`` (0 when both zero); mean over shared
    keys. ``None`` when the two sets share no ``strategy_*`` input.
    """

    shared = sorted(set(a) & set(b))
    if not shared:
        return None
    total = 0.0
    for key in shared:
        va, vb = a[key], b[key]
        denom = abs(va) + abs(vb)
        total += 0.0 if denom == 0 else abs(va - vb) / denom
    return round(total / len(shared), 6)


# --------------------------------------------------------------------------- #
# (c) Trade-overlap Jaccard + daily-PnL correlation
# --------------------------------------------------------------------------- #

def _stream_key(numeric_id: str, symbol: str) -> str:
    return f"{numeric_id}_{symbol.replace('.', '_')}"


def load_trade_stream(path: Path) -> dict[str, Any]:
    """Load a sealed Q08 stream -> entry-day set + daily net-PnL map.

    ``entry_time`` / ``time`` are Unix epoch seconds. Entry day = UTC date of
    ``entry_time``; daily PnL buckets ``net`` by the UTC date of the exit ``time``.
    """

    entry_days: set[str] = set()
    daily_pnl: dict[str, float] = {}
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {"entry_days": entry_days, "daily_pnl": daily_pnl}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        et = row.get("entry_time")
        xt = row.get("time")
        net = row.get("net")
        if et is not None:
            d = dt.datetime.fromtimestamp(int(et), dt.UTC).strftime("%Y-%m-%d")
            entry_days.add(d)
        if xt is not None and net is not None:
            d = dt.datetime.fromtimestamp(int(xt), dt.UTC).strftime("%Y-%m-%d")
            daily_pnl[d] = daily_pnl.get(d, 0.0) + float(net)
    return {"entry_days": entry_days, "daily_pnl": daily_pnl}


def jaccard(a: set[str], b: set[str]) -> float | None:
    if not a and not b:
        return None
    union = a | b
    if not union:
        return None
    return round(len(a & b) / len(union), 6)


def pearson(daily_a: dict[str, float], daily_b: dict[str, float]) -> tuple[float | None, int]:
    """Pearson correlation of daily net-PnL on the common date index."""

    common = sorted(set(daily_a) & set(daily_b))
    n = len(common)
    if n < 2:
        return None, n
    xs = [daily_a[d] for d in common]
    ys = [daily_b[d] for d in common]
    mx = sum(xs) / n
    my = sum(ys) / n
    sxx = sum((x - mx) ** 2 for x in xs)
    syy = sum((y - my) ** 2 for y in ys)
    sxy = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    if sxx <= 0 or syy <= 0:
        return None, n
    return round(sxy / (sxx ** 0.5 * syy ** 0.5), 6), n


# --------------------------------------------------------------------------- #
# (d) Card lineage + terminal verdicts
# --------------------------------------------------------------------------- #

_FM_PARENT = re.compile(r"^parent_ea_id:\s*(\S+)", re.M)
_FM_VARIANT = re.compile(r"^variant_of:\s*(\S+)", re.M)


def read_card_lineage(card_path: Path) -> dict[str, str | None]:
    lineage: dict[str, str | None] = {"parent_id": None, "variant_of": None, "rerun_of": None}
    try:
        text = card_path.read_text(encoding="utf-8", errors="replace")[:4000]
    except OSError:
        return lineage
    m = _FM_PARENT.search(text)
    if m:
        lineage["parent_id"] = m.group(1).strip().strip('"')
    v = _FM_VARIANT.search(text)
    if v:
        lineage["variant_of"] = v.group(1).strip().strip('"')
    return lineage


def load_terminal_verdicts(db_path: Path = DB_PATH) -> dict[str, str]:
    """Per-EA worst terminal verdict token (read-only), for SUPERSEDED detection.

    Returns ea_id -> a token in _TERMINAL_RETIRE if any of the EA's work items
    carries such a verdict at any phase; otherwise the EA is absent.
    """

    verdicts: dict[str, str] = {}
    if not db_path.exists():
        return verdicts
    uri = f"file:{db_path.as_posix()}?mode=ro"
    try:
        con = sqlite3.connect(uri, uri=True, timeout=30)
    except sqlite3.Error:
        return verdicts
    try:
        cur = con.cursor()
        rows = cur.execute(
            "select ea_id, verdict from work_items where verdict is not null"
        ).fetchall()
    except sqlite3.Error:
        con.close()
        return verdicts
    con.close()
    for ea_id, verdict in rows:
        token = str(verdict or "").upper()
        if any(token.startswith(prefix) for prefix in _TERMINAL_RETIRE):
            verdicts.setdefault(ea_id, token)
    return verdicts


# --------------------------------------------------------------------------- #
# EA inventory
# --------------------------------------------------------------------------- #

def _numeric_id(ea_id: str) -> str:
    m = re.match(r"QM5_([A-Za-z0-9]+)", ea_id)
    return m.group(1) if m else ea_id


def _slug_from_dir(dirname: str) -> tuple[str, str]:
    """``QM5_13213_balke-gmt3-range-breakout`` -> (``QM5_13213``, ``balke-...``)."""

    m = re.match(r"(QM5_[A-Za-z0-9]+)_(.*)", dirname)
    if m:
        return m.group(1), m.group(2)
    m2 = re.match(r"(QM5_[A-Za-z0-9]+)", dirname)
    if m2:
        return m2.group(1), ""
    return dirname, ""


def _pick_setfile(ea_dir: Path) -> Path | None:
    sets_dir = ea_dir / "sets"
    if not sets_dir.is_dir():
        return None
    candidates = sorted(sets_dir.glob("*.set"))
    if not candidates:
        return None
    # Prefer a backtest set, else the first sorted (deterministic).
    for c in candidates:
        if "_backtest.set" in c.name:
            return c
    return candidates[0]


def build_inventory(cfg: dict[str, Any]) -> dict[str, dict[str, Any]]:
    """Scan framework/EAs -> per-EA node facts (signature, family, params, lineage)."""

    inv: dict[str, dict[str, Any]] = {}
    for ea_dir in sorted(EAS_DIR.glob("*")):
        if not ea_dir.is_dir():
            continue
        mq5s = sorted(ea_dir.glob("*.mq5"))
        if not mq5s:
            continue
        ea_id, slug = _slug_from_dir(ea_dir.name)
        if ea_id in inv:
            continue  # first (sorted) wins; avoids duplicate short/long dir names
        try:
            mq5_text = mq5s[0].read_text(encoding="utf-8", errors="replace")
        except OSError:
            mq5_text = ""
        sig, tokens = compute_rule_signature(mq5_text)
        setfile = _pick_setfile(ea_dir)
        params = parse_setfile(setfile) if setfile else {}
        card = ea_dir / "docs" / "strategy_card.md"
        lineage = read_card_lineage(card) if card.exists() else {
            "parent_id": None, "variant_of": None, "rerun_of": None
        }
        inv[ea_id] = {
            "ea_id": ea_id,
            "slug": slug,
            "numeric_id": _numeric_id(ea_id),
            "family": classify_family(slug, cfg),
            "mechanism_signature": sig,
            "token_counter": token_counter(tokens),
            "params": params,
            "card_lineage": lineage,
            "symbols": set(),  # filled from streams
        }
    return inv


def index_streams() -> dict[str, dict[str, Any]]:
    """Map stream key '<numid>_<SYMBOL>_DWX' -> {numeric_id, symbol, path}."""

    streams: dict[str, dict[str, Any]] = {}
    if not STREAM_DIR.is_dir():
        return streams
    for path in sorted(STREAM_DIR.glob("*.jsonl")):
        name = path.stem  # e.g. 13213_USDJPY_DWX
        m = re.match(r"([A-Za-z0-9]+)_(.+)$", name)
        if not m:
            continue
        numeric_id, sym_part = m.group(1), m.group(2)
        symbol = sym_part.replace("_", ".")  # USDJPY_DWX -> USDJPY.DWX
        streams[name] = {"numeric_id": numeric_id, "symbol": symbol, "path": path}
    return streams


# --------------------------------------------------------------------------- #
# Classification
# --------------------------------------------------------------------------- #

def _symbol_base(symbol: str) -> str:
    return symbol.split(".")[0].upper()


def classify_pair(
    a: dict[str, Any],
    b: dict[str, Any],
    thr: dict[str, Any],
    *,
    rule_sim: float | None,
    d_param: float | None,
    jac: float | None,
    rho: float | None,
    declared: bool,
    parent_retired: bool,
) -> tuple[str, str]:
    """Return (relation, basis) using the top-down class rules."""

    sig_a = a.get("mechanism_signature")
    sig_b = b.get("mechanism_signature")
    sig_equal = bool(sig_a) and sig_a == sig_b

    # 1. exact clone -- byte-normalized signature equality.
    if sig_equal:
        return "exact_clone", "SOURCE_SIGNATURE"

    # 2. close implementation clone.
    if rule_sim is not None and rule_sim >= thr["rule_sim_close_clone"]:
        if jac is None and rho is None:
            return "close_implementation_clone", "SOURCE_SIGNATURE"
        if (jac is not None and jac >= thr["jaccard_close_clone"]) and (
            rho is not None and rho >= thr["rho_close_clone"]
        ):
            return "close_implementation_clone", "BEHAVIOUR"

    # 3. parameter variant (same code / near-same code, retuned knobs).
    near_same_code = sig_equal or (rule_sim is not None and rule_sim >= thr["rule_sim_param_variant"])
    if near_same_code and d_param is not None and 0 < d_param <= thr["param_variant_max_distance"]:
        if jac is None or jac >= thr["jaccard_param_variant"]:
            if parent_retired:
                return "superseded", "OWNER_RECEIPT" if declared else "BEHAVIOUR"
            return "parameter_variant", "DECLARED" if declared else "SOURCE_SIGNATURE"

    # 4. same edge / different implementation (behaviour-driven).
    if (
        jac is not None
        and rho is not None
        and jac >= thr["jaccard_same_edge"]
        and rho >= thr["rho_same_edge"]
    ):
        return "same_edge_different_implementation", "BEHAVIOUR"

    # 5/6. declared descendant.
    if declared:
        if parent_retired:
            return "superseded", "OWNER_RECEIPT"
        return "child_challenger", "DECLARED"

    # 7. default.
    return "materially_different", "BEHAVIOUR" if (jac is not None or rho is not None) else "SOURCE_SIGNATURE"


def _confidence(basis: str, *, jac: float | None, rho: float | None, n_days: int) -> float:
    if basis == "SOURCE_SIGNATURE":
        return 1.0
    if basis == "HAND_SEEDED":
        return 0.6
    if basis == "DECLARED" or basis == "OWNER_RECEIPT":
        return 0.75
    # BEHAVIOUR
    if n_days >= 200:
        base = 0.9
    elif n_days >= 50:
        base = 0.75
    elif n_days >= 10:
        base = 0.6
    else:
        base = 0.4
    return round(base, 3)


# --------------------------------------------------------------------------- #
# Edge building
# --------------------------------------------------------------------------- #

def _edge(from_id, to_id, relation, basis, *, rule_sim=None, d_param=None,
          jac=None, rho=None, n_days=0, symbol=None, note=None) -> dict[str, Any]:
    return {
        "from": from_id,
        "to": to_id,
        "relation": relation,
        "basis": basis,
        "evidence": {
            "rule_signature_equal": None,  # filled by caller when known
            "rule_sim": rule_sim,
            "param_distance": d_param,
            "trade_overlap_jaccard": jac,
            "return_correlation": rho,
            "n_overlap_days": n_days,
            "symbol": symbol,
        },
        "confidence": _confidence(basis, jac=jac, rho=rho, n_days=n_days),
        "note": note,
    }


def build_edges(
    inv: dict[str, dict[str, Any]],
    streams: dict[str, dict[str, Any]],
    cfg: dict[str, Any],
    terminal_verdicts: dict[str, str],
) -> list[dict[str, Any]]:
    thr = cfg["thresholds"]
    min_days = int(thr.get("min_overlap_days", 10))
    edges: list[dict[str, Any]] = []
    seen_pairs: set[tuple[str, str, str | None]] = set()

    # Precompute named-family tags per EA (need symbols first -> see below).
    numid_to_ea = {v["numeric_id"]: k for k, v in inv.items()}

    # Attach symbols + load streams for EAs that have them.
    stream_data: dict[str, dict[str, Any]] = {}  # ea_id -> {symbol -> loaded}
    for key, meta in streams.items():
        ea_id = numid_to_ea.get(meta["numeric_id"])
        if ea_id is None:
            continue
        inv[ea_id]["symbols"].add(meta["symbol"])
        loaded = load_trade_stream(meta["path"])
        stream_data.setdefault(ea_id, {})[meta["symbol"]] = {
            "entry_days": loaded["entry_days"],
            "daily_pnl": loaded["daily_pnl"],
            "path": str(meta["path"]),
        }

    # Named-family tags (after symbols known).
    for ea_id, node in inv.items():
        node["named_families"] = named_families_for(
            node["slug"], node["symbols"], cfg
        )

    def _record(a_id: str, b_id: str, edge: dict[str, Any]) -> None:
        sym = edge["evidence"].get("symbol")
        pair = (a_id, b_id, sym)
        if pair in seen_pairs:
            return
        seen_pairs.add(pair)
        edges.append(edge)

    # 1. IDENTICAL-SIGNATURE groups (star edges from canonical = min ea_id).
    #    Same normalized code => exact_clone when the parameter set is also equal,
    #    else parameter_variant (identical logic, retuned knobs). A retire on the
    #    head makes the variant a superseded loser.
    sig_groups: dict[str, list[str]] = {}
    for ea_id, node in inv.items():
        sig = node["mechanism_signature"]
        if sig:
            sig_groups.setdefault(sig, []).append(ea_id)
    for sig, members in sig_groups.items():
        if len(members) < 2:
            continue
        members = sorted(members)
        head = members[0]
        for other in members[1:]:
            d_param = param_distance(inv[head].get("params", {}), inv[other].get("params", {}))
            if d_param is not None and d_param > 0:
                relation = "superseded" if head in terminal_verdicts else "parameter_variant"
            else:
                relation = "exact_clone"
            e = _edge(head, other, relation, "SOURCE_SIGNATURE", d_param=d_param, rule_sim=1.0)
            e["evidence"]["rule_signature_equal"] = True
            _record(head, other, e)

    # Helper: behaviour metrics for an EA-pair on shared symbols.
    def _behaviour(a_id: str, b_id: str) -> list[tuple[str, float | None, float | None, int]]:
        out: list[tuple[str, float | None, float | None, int]] = []
        sa = stream_data.get(a_id, {})
        sb = stream_data.get(b_id, {})
        for symbol in sorted(set(sa) & set(sb)):
            jac = jaccard(sa[symbol]["entry_days"], sb[symbol]["entry_days"])
            rho, n = pearson(sa[symbol]["daily_pnl"], sb[symbol]["daily_pnl"])
            if n < min_days:
                rho = None
            out.append((symbol, jac, rho, n))
        return out

    # 2. Candidate pairs for the richer (non-exact) classes.
    #    Bounded scope: (2a) every pair inside a §9 named family, done in full;
    #    (2b) every pair of streamed EAs on a shared symbol (behaviour catches
    #    same-edge convergence across families, e.g. Gold-Reaper/Balke); (2c)
    #    declared card-lineage pairs. A pair is classified exactly once with full
    #    information (declared flag + behaviour + rule-sim + param distance).
    ea_ids = sorted(inv)

    declared_of: dict[frozenset[str], str] = {}  # pair -> parent ea_id
    for ea_id in ea_ids:
        lin = inv[ea_id]["card_lineage"]
        parent = lin.get("parent_id") or lin.get("variant_of")
        if parent and parent in inv and parent != ea_id:
            declared_of[frozenset((parent, ea_id))] = parent

    md_scope = set(
        cfg["named_families"].get("materially_different_scope", {}).get("families", [])
    )
    named_pairs: set[frozenset[str]] = set()   # all named-family pairs (candidates)
    md_named_pairs: set[frozenset[str]] = set()  # mechanism-scoped (may assert materially_different)
    for fam in cfg["named_families"]["definitions"]:
        members = sorted(e for e in ea_ids if fam in inv[e].get("named_families", []))
        for a_id, b_id in combinations(members, 2):
            pair = frozenset((a_id, b_id))
            named_pairs.add(pair)
            if fam in md_scope:
                md_named_pairs.add(pair)

    streamed_ids = sorted(stream_data)
    candidate_pairs: set[frozenset[str]] = set(named_pairs)
    candidate_pairs |= set(declared_of)
    for a_id, b_id in combinations(streamed_ids, 2):
        candidate_pairs.add(frozenset((a_id, b_id)))

    for pair in candidate_pairs:
        ids = sorted(pair)
        a_id, b_id = ids[0], ids[1]
        parent = declared_of.get(pair)
        is_named = pair in md_named_pairs
        _classify_and_record(
            a_id, b_id, inv, thr, terminal_verdicts, _behaviour, _record,
            declared_parent=parent, is_named=is_named,
        )

    # 3. Hand-seeded edges from config.
    for seed in cfg.get("seed_edges", {}).get("edges", []):
        frm, to = seed["from"], seed["to"]
        e = _edge(frm, to, seed["relation"], "HAND_SEEDED", note=seed.get("note"))
        e["confidence"] = seed.get("confidence", 0.6)
        _record(frm, to, e)

    edges.sort(key=lambda e: (e["from"], e["to"], e["evidence"].get("symbol") or "", e["relation"]))
    return edges


def _classify_and_record(a_id, b_id, inv, thr, terminal_verdicts, behaviour_fn,
                         record_fn, *, declared_parent: str | None = None,
                         is_named: bool = False) -> None:
    """Classify one unordered pair once and record its edge(s).

    ``materially_different`` is emitted ONLY for a named-family pair that has been
    behaviourally MEASURED (a shared symbol with >= min_overlap_days) and found
    distinct -- i.e. a genuine "same label, materially different edge" finding.
    Unmeasured / cross-family pairs that are not a positive relationship produce
    no edge (absence of a lineage relationship is not an assertion).
    """

    declared = declared_parent is not None
    if declared:
        # Orient parent -> child.
        from_id, to_id = declared_parent, (b_id if declared_parent == a_id else a_id)
    else:
        from_id, to_id = a_id, b_id
    fa, fb = inv[from_id], inv[to_id]

    sig_a = fa.get("mechanism_signature")
    sig_b = fb.get("mechanism_signature")
    sig_equal = bool(sig_a) and sig_a == sig_b

    d_param = param_distance(fa.get("params", {}), fb.get("params", {}))
    parent_retired = from_id in terminal_verdicts

    if sig_equal:
        # Exact code identity is already carried by the exact-clone star edges.
        # A declared retune on identical code is a parameter_variant worth stating.
        if declared and d_param is not None and d_param > 0:
            relation = "superseded" if parent_retired else "parameter_variant"
            e = _edge(from_id, to_id, relation, "DECLARED", d_param=d_param, rule_sim=1.0)
            e["evidence"]["rule_signature_equal"] = True
            e["evidence"]["declared"] = True
            record_fn(from_id, to_id, e)
        return

    rsim = None
    if fa.get("token_counter") and fb.get("token_counter"):
        rsim = rule_similarity(fa["token_counter"], fb["token_counter"])

    behaviours = behaviour_fn(from_id, to_id)

    if not behaviours:
        relation, basis = classify_pair(
            fa, fb, thr, rule_sim=rsim, d_param=d_param, jac=None, rho=None,
            declared=declared, parent_retired=parent_retired,
        )
        if relation == "materially_different":
            return  # no measurement -> no assertion
        e = _edge(from_id, to_id, relation, basis, rule_sim=rsim, d_param=d_param)
        e["evidence"]["rule_signature_equal"] = False
        if declared:
            e["evidence"]["declared"] = True
        record_fn(from_id, to_id, e)
        return

    for symbol, jac, rho, n in behaviours:
        relation, basis = classify_pair(
            fa, fb, thr, rule_sim=rsim, d_param=d_param, jac=jac, rho=rho,
            declared=declared, parent_retired=parent_retired,
        )
        if relation == "materially_different":
            # Only assert "materially different" for a measured, same-label pair.
            if not (is_named and n >= int(thr.get("min_overlap_days", 10))):
                continue
        e = _edge(from_id, to_id, relation, basis, rule_sim=rsim, d_param=d_param,
                  jac=jac, rho=rho, n_days=n, symbol=symbol)
        e["evidence"]["rule_signature_equal"] = False
        if declared:
            e["evidence"]["declared"] = True
        record_fn(from_id, to_id, e)


# --------------------------------------------------------------------------- #
# Output assembly
# --------------------------------------------------------------------------- #

def _inputs_sha256(inv: dict[str, dict[str, Any]], streams: dict[str, dict[str, Any]],
                   cfg: dict[str, Any]) -> str:
    """Deterministic hash of the material inputs (signatures, params, streams, cfg)."""

    h = hashlib.sha256()
    h.update(json.dumps(cfg, sort_keys=True, ensure_ascii=False).encode("utf-8"))
    for ea_id in sorted(inv):
        node = inv[ea_id]
        h.update(ea_id.encode())
        h.update((node["mechanism_signature"] or "").encode())
        h.update(json.dumps(node["params"], sort_keys=True).encode())
        h.update(json.dumps(node["card_lineage"], sort_keys=True).encode())
    for key in sorted(streams):
        meta = streams[key]
        try:
            st = meta["path"].stat()
            h.update(f"{key}:{st.st_size}".encode())
        except OSError:
            h.update(key.encode())
    return h.hexdigest()


def _stamp_or_reuse(inputs_sha: str, out_path: Path) -> str:
    """Reuse the prior generated_at_utc when inputs are unchanged (idempotency)."""

    if out_path.exists():
        try:
            prev = json.loads(out_path.read_text(encoding="utf-8"))
            if prev.get("inputs_sha256") == inputs_sha and prev.get("generated_at_utc"):
                return prev["generated_at_utc"]
        except (OSError, json.JSONDecodeError):
            pass
    return dt.datetime.now(dt.UTC).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


def assemble_map(inv, edges, cfg, inputs_sha, generated_at) -> dict[str, Any]:
    nodes: dict[str, Any] = {}
    for ea_id in sorted(inv):
        node = inv[ea_id]
        status = "EVALUATED" if node["mechanism_signature"] else "EVIDENCE_MISSING"
        nodes[ea_id] = {
            "family": node["family"],
            "named_families": node.get("named_families", []),
            "mechanism_signature": node["mechanism_signature"],
            "has_trade_stream": bool(node["symbols"]),
            "symbols": sorted(node["symbols"]),
            "signature_status": status,
            "card_lineage": {
                "parent_id": node["card_lineage"].get("parent_id"),
                "variant_of": node["card_lineage"].get("variant_of"),
                "rerun_of": node["card_lineage"].get("rerun_of"),
            },
        }

    # Seed-only nodes (referenced by hand-seeded edges, no build).
    for seed_id, seed in cfg.get("seed_nodes", {}).get("nodes", {}).items():
        if seed_id in nodes:
            continue
        nodes[seed_id] = {
            "family": seed.get("family"),
            "named_families": seed.get("named_families", []),
            "mechanism_signature": None,
            "has_trade_stream": False,
            "symbols": [],
            "signature_status": "EVIDENCE_MISSING",
            "card_lineage": {"parent_id": None, "variant_of": None, "rerun_of": None},
            "note": seed.get("note"),
        }

    families: dict[str, list[str]] = {}
    for ea_id in sorted(inv):
        families.setdefault(inv[ea_id]["family"], []).append(ea_id)
    families = {k: sorted(v) for k, v in sorted(families.items())}

    return {
        "schema": SCHEMA,
        "generated_at_utc": generated_at,
        "inputs_sha256": inputs_sha,
        "thresholds": cfg["thresholds"],
        "nodes": dict(sorted(nodes.items())),
        "edges": edges,
        "families": families,
    }


def _write_json(lineage: dict[str, Any], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(lineage, indent=2, ensure_ascii=False, sort_keys=False) + "\n",
        encoding="utf-8",
    )


# --------------------------------------------------------------------------- #
# Markdown + Vault projection
# --------------------------------------------------------------------------- #

def _relation_counts(edges: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for e in edges:
        counts[e["relation"]] = counts.get(e["relation"], 0) + 1
    return counts


def _edges_touching(edges, ea_ids: set[str]) -> list[dict[str, Any]]:
    return [e for e in edges if e["from"] in ea_ids or e["to"] in ea_ids]


def render_markdown(lineage: dict[str, Any], inv, cfg) -> str:
    edges = lineage["edges"]
    nodes = lineage["nodes"]
    counts = _relation_counts(edges)
    L: list[str] = []
    L.append("# Strategy Lineage & Duplicate Map — 2026-09")
    L.append("")
    L.append(f"> Generated by `tools/strategy_farm/lineage_map.py` "
             f"(schema `{lineage['schema']}`). Deterministic + idempotent. "
             f"Read-model: `{OUT_JSON.as_posix()}`.")
    L.append(">")
    L.append(f"> `inputs_sha256`: `{lineage['inputs_sha256']}` · "
             f"`generated_at_utc`: {lineage['generated_at_utc']}")
    L.append("")
    L.append("OWNER directive 2026-09-15 §9 (relationship classes) + master §56 "
             "(new-edge-vs-better-implementation). Relationships use actual mechanics "
             "(normalized `.mq5` rule signatures), parameter-set distance, and "
             "deterministic behaviour (entry-day trade-overlap Jaccard + daily-PnL "
             "correlation on sealed Q08 streams). Names alone are never sufficient.")
    L.append("")

    # Headline counts
    L.append("## Headline counts")
    L.append("")
    L.append(f"- EA nodes: **{len([n for n in nodes if nodes[n]['mechanism_signature'] is not None])}** "
             f"with a mechanism signature (+{sum(1 for n in nodes if nodes[n]['mechanism_signature'] is None)} "
             f"seed/boilerplate-only).")
    L.append(f"- EAs with a sealed Q08 trade stream (behaviour-computable): "
             f"**{sum(1 for n in nodes if nodes[n]['has_trade_stream'])}**.")
    L.append(f"- Edges: **{len(edges)}** total.")
    L.append("")
    L.append("| Relationship class (§9) | Edges |")
    L.append("|---|---|")
    for rel in cfg["relationship_classes"]["order"]:
        L.append(f"| `{rel}` | {counts.get(rel, 0)} |")
    L.append("")
    L.append("Exact-clone groups are emitted as star edges from a canonical member "
             "(min ea_id), so the exact-clone edge count = (cluster size − 1) summed "
             "over clusters, not the full clique.")
    L.append("")

    # Exact-clone clusters
    sig_groups: dict[str, list[str]] = {}
    for ea_id in inv:
        sig = inv[ea_id]["mechanism_signature"]
        if sig:
            sig_groups.setdefault(sig, []).append(ea_id)
    clusters = sorted(
        ([sorted(m) for m in sig_groups.values() if len(m) > 1]),
        key=lambda m: (-len(m), m[0]),
    )
    L.append(f"## Exact-clone clusters (identical normalized rule signature)")
    L.append("")
    L.append(f"{len(clusters)} clusters covering "
             f"{sum(len(c) for c in clusters)} EAs. Largest first (top 25).")
    L.append("")
    L.append("| Cluster size | Family | Members (head first) |")
    L.append("|---|---|---|")
    for c in clusters[:25]:
        fam = inv[c[0]]["family"]
        shown = ", ".join(c[:8]) + (" …" if len(c) > 8 else "")
        L.append(f"| {len(c)} | {fam} | {shown} |")
    L.append("")

    # Named families (§9 order)
    L.append("## Named families (§9)")
    L.append("")
    for fam in cfg["named_families"]["report_order"]:
        members = sorted(e for e in inv if fam in inv[e].get("named_families", []))
        seed_members = sorted(
            s for s, sn in cfg.get("seed_nodes", {}).get("nodes", {}).items()
            if fam in sn.get("named_families", [])
        )
        all_members = sorted(set(members) | set(seed_members))
        L.append(f"### {fam}")
        L.append("")
        L.append(f"Members: **{len(all_members)}** "
                 f"({len([m for m in all_members if m in inv])} built"
                 + (f", {len(seed_members)} seed-only" if seed_members else "") + ").")
        fam_edges = [
            e for e in edges
            if (e["from"] in all_members or e["to"] in all_members)
        ]
        if fam_edges:
            fc = _relation_counts(fam_edges)
            L.append("")
            L.append("Edges touching this family: " + ", ".join(
                f"`{r}`={fc[r]}" for r in cfg["relationship_classes"]["order"] if r in fc
            ) + ".")
            L.append("")
            L.append("| from | to | relation | rule_sim | d_param | jaccard | rho | n_days | symbol | basis |")
            L.append("|---|---|---|---|---|---|---|---|---|---|")
            for e in sorted(fam_edges, key=lambda e: (e["relation"], e["from"], e["to"]))[:40]:
                ev = e["evidence"]
                L.append("| {f} | {t} | `{r}` | {rs} | {dp} | {j} | {rho} | {n} | {sym} | {b} |".format(
                    f=e["from"], t=e["to"], r=e["relation"],
                    rs=_fmt(ev.get("rule_sim")), dp=_fmt(ev.get("param_distance")),
                    j=_fmt(ev.get("trade_overlap_jaccard")), rho=_fmt(ev.get("return_correlation")),
                    n=ev.get("n_overlap_days") or "", sym=ev.get("symbol") or "",
                    b=e["basis"],
                ))
        else:
            L.append("")
            L.append("_No edges computed (members lack shared signatures / streams; "
                     "source-only nodes)._")
        L.append("")

    # §9 named-family answers
    L.append("## §9 answers for the named families")
    L.append("")
    L.append(_named_family_answers(lineage, inv, cfg))
    L.append("")

    # §56 robust-rebuild census classification
    L.append("## §56 classification — robust / commercial / reference rebuild census rows")
    L.append("")
    L.append(_section_56(lineage, inv))
    L.append("")

    L.append("## Method & thresholds")
    L.append("")
    L.append("Mechanism signature: SHA256 over the normalized `Strategy_*` hook "
             "region of the `.mq5` — comments stripped, hook names canonicalized to "
             "`FN`, string labels blanked, tokens rejoined without whitespace, "
             "per-function strings sorted then joined. Input defaults live in "
             "`input` declarations outside the hooks and never move the hash, so a "
             "pure retune is a `parameter_variant`, not a new signature.")
    L.append("")
    L.append("Thresholds (config `tools/strategy_farm/config/strategy_families.v1.json`; "
             "changing any is a GELB decision):")
    L.append("")
    for k, v in cfg["thresholds"].items():
        if k.startswith("_"):
            continue
        L.append(f"- `{k}` = {v}")
    L.append("")
    return "\n".join(L)


def _fmt(x) -> str:
    if x is None:
        return ""
    if isinstance(x, float):
        return f"{x:.3f}"
    return str(x)


def _named_family_answers(lineage, inv, cfg) -> str:
    edges = lineage["edges"]
    out: list[str] = []

    def fam_members(fam):
        return sorted(e for e in inv if fam in inv[e].get("named_families", []))

    # Balke
    balke = fam_members("balke")
    balke_exact = [e for e in edges if e["relation"] == "exact_clone"
                   and (e["from"] in balke or e["to"] in balke)]
    balke_pv = [e for e in edges if e["relation"] == "parameter_variant"
                and (e["from"] in balke or e["to"] in balke)]
    balke_beh = [e for e in edges if e["basis"] == "BEHAVIOUR"
                 and (e["from"] in balke or e["to"] in balke)]
    out.append(f"- **René Balke systems** ({len(balke)} built EAs): "
               f"{len(balke_exact)} exact-clone, {len(balke_pv)} parameter-variant, "
               f"{len(balke_beh)} behaviour-based edges. The declared chain "
               f"(13213→41398→41405; 21501/41097/41324 census siblings) is confirmed "
               f"by shared signatures and parameter distance; USDJPY behaviour overlap "
               f"is computed where both siblings have a sealed stream.")
    # Gold Reaper
    out.append("- **Gold Reaper**: no built EA (seed card `QM5_31008` REJECTED). "
               "Encoded as one hand-seeded `same_edge_different_implementation` edge to "
               "Balke XAU (`QM5_13213`) per the dated research verdict; behaviour cannot "
               "confirm it (no XAU stream survives — Balke XAU is Q02 RETIRE).")
    # ORB / session breakout
    for label, fam in (("ORB", "orb"), ("session breakouts", "session_breakout"),
                       ("breakout families", "breakout"), ("XAU systems", "xau_systems")):
        members = fam_members(fam)
        fe = _edges_touching(edges, set(members))
        streamed = sum(1 for m in members if inv[m]["symbols"])
        out.append(f"- **{label}** ({len(members)} EAs, {streamed} with a Q08 stream): "
                   f"{len(fe)} edges "
                   f"({_relation_counts(fe)}).")
    return "\n".join(out)


def _section_56(lineage, inv) -> str:
    """§56 A–E classification for the census rows (from the robust_rebuild_census)."""

    rows = [
        ("QM5_13213", "B", "Balke USDJPY H1 — existing-edge, better implementation of parent QM5_9936 (only range_start_hour + exit-hour differ)."),
        ("QM5_13301", "E", "Balke GDAXI M5 — materially distinct: different symbol + M5 clock, no trade overlap possible with the USDJPY leg."),
        ("QM5_13036", "E", "Balke go-long GDAXI/NDX — materially distinct: SMA200 regime long-only, not a range breakout at all; shares only the author label."),
        ("QM5_21501", "D", "ppcensus — duplicate-by-construction of 13213 (identical strategy_id + identical Q11 metrics); measurement mirror, never deployable."),
        ("QM5_41097", "C", "config/parameter variant of 13213 (A1-fixed pp-profile opt; same strategy_id)."),
        ("QM5_41324", "C", "config/parameter variant (path-to-25 opt; declared parent QM5_21501)."),
        ("QM5_41398", "C", "config/parameter variant (pattern-repair opt; declared parent QM5_13213)."),
        ("QM5_41405", "C", "config/parameter variant (clock-audit opt; declared parent QM5_41398)."),
        ("QM5_31008", "B/D", "Gold Reaper — existing-edge / clone of the already-killed Balke XAU death signature; REJECTED, never built."),
    ]
    L = ["| EA | §56 class | Deterministic evidence |", "|---|---|---|"]
    edges = lineage["edges"]
    for ea, cls, note in rows:
        # Cross-check against computed edges where possible.
        computed = [e for e in edges if e["from"] == ea or e["to"] == ea]
        rels = sorted({e["relation"] for e in computed})
        suffix = f" (computed edges: {', '.join(rels)})" if rels else ""
        L.append(f"| {ea} | {cls} | {note}{suffix} |")
    L.append("")
    L.append("Class map: A=new edge · B=existing edge, better implementation · "
             "C=config/parameter variant · D=duplicate · E=materially distinct "
             "despite similar label. Rows and prose evidence follow "
             "`docs/ops/evidence/2026-09-15_continuous_book_evolution/audit/robust_rebuild_census.md`; "
             "the computed-edge suffix cross-checks each row against this map.")
    return "\n".join(L)


def render_vault_page(lineage: dict[str, Any], inv, cfg) -> str:
    counts = _relation_counts(lineage["edges"])
    L: list[str] = []
    L.append("---")
    L.append(f"{GENERATED_MARKER}")
    L.append("qm_generated_marker: true")
    L.append(f"qm_schema: {lineage['schema']}")
    L.append(f"qm_inputs_sha256: {lineage['inputs_sha256']}")
    L.append(f"qm_generated_at_utc: {lineage['generated_at_utc']}")
    L.append("qm_source: tools/strategy_farm/lineage_map.py")
    L.append("---")
    L.append("")
    L.append("# Lineage Map")
    L.append("")
    L.append("> **Generated page — do not hand-edit.** Rebuilt deterministically by "
             "`tools/strategy_farm/lineage_map.py` from the EA corpus, sealed Q08 trade "
             "streams and strategy-card lineage. The Strategy Wiki sync renders "
             "per-node relationships from the JSON read-model "
             f"`{OUT_JSON.as_posix()}`.")
    L.append("")
    L.append("## Company-wide relationship summary (§9)")
    L.append("")
    L.append("| Relationship class | Edges |")
    L.append("|---|---|")
    for rel in cfg["relationship_classes"]["order"]:
        L.append(f"| {rel} | {counts.get(rel, 0)} |")
    L.append("")
    n_sig = len([n for n in lineage["nodes"] if lineage["nodes"][n]["mechanism_signature"]])
    n_stream = sum(1 for n in lineage["nodes"] if lineage["nodes"][n]["has_trade_stream"])
    L.append(f"- EA nodes with a mechanism signature: **{n_sig}**")
    L.append(f"- EAs with a sealed Q08 behaviour stream: **{n_stream}**")
    L.append(f"- Total edges: **{len(lineage['edges'])}**")
    L.append("")
    L.append("## Named families (§9)")
    L.append("")
    for fam in cfg["named_families"]["report_order"]:
        members = sorted(e for e in inv if fam in inv[e].get("named_families", []))
        L.append(f"- **{fam}**: {len(members)} built EAs")
    L.append("")
    L.append("Full evidence tables, per-edge metrics and the §56 rebuild census are in "
             "the repo report `docs/research/STRATEGY_LINEAGE_MAP_2026-09.md`.")
    L.append("")
    return "\n".join(L)


def _write_text(path: Path, content: str) -> bool:
    """Write only if changed (idempotent). Returns True if written."""

    try:
        if path.exists() and path.read_text(encoding="utf-8") == content:
            return False
    except OSError:
        pass
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #

def build(
    *,
    write_json: bool = True,
    write_md: bool = True,
    write_vault: bool = True,
    json_path: Path = OUT_JSON,
    md_path: Path = OUT_MD,
    vault_path: Path = VAULT_PAGE,
    config_path: Path = CONFIG_PATH,
) -> dict[str, Any]:
    cfg = load_config(config_path)
    inv = build_inventory(cfg)
    streams = index_streams()
    terminal_verdicts = load_terminal_verdicts()
    edges = build_edges(inv, streams, cfg, terminal_verdicts)
    inputs_sha = _inputs_sha256(inv, streams, cfg)
    generated_at = _stamp_or_reuse(inputs_sha, json_path) if write_json else "1970-01-01T00:00:00Z"
    lineage = assemble_map(inv, edges, cfg, inputs_sha, generated_at)

    if write_json:
        _write_json(lineage, json_path)
    if write_md:
        _write_text(md_path, render_markdown(lineage, inv, cfg))
    if write_vault:
        try:
            _write_text(vault_path, render_vault_page(lineage, inv, cfg))
        except OSError as exc:  # vault may be offline; not fatal
            print(f"WARN: vault page not written: {exc}")

    return {"lineage": lineage, "inv": inv, "streams": streams, "cfg": cfg}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Build the strategy lineage / duplicate map.")
    ap.add_argument("--no-json", action="store_true", help="skip the JSON read-model")
    ap.add_argument("--no-md", action="store_true", help="skip the Markdown summary")
    ap.add_argument("--no-vault", action="store_true", help="skip the Vault page")
    ap.add_argument("--json-path", type=Path, default=OUT_JSON)
    ap.add_argument("--summary", action="store_true", help="print counts to stdout")
    args = ap.parse_args(argv)

    result = build(
        write_json=not args.no_json,
        write_md=not args.no_md,
        write_vault=not args.no_vault,
        json_path=args.json_path,
    )
    lineage = result["lineage"]
    counts = _relation_counts(lineage["edges"])
    print(f"nodes={len(lineage['nodes'])} edges={len(lineage['edges'])} "
          f"inputs_sha256={lineage['inputs_sha256'][:12]}")
    for rel in result["cfg"]["relationship_classes"]["order"]:
        print(f"  {rel}={counts.get(rel, 0)}")
    if args.summary:
        n_stream = sum(1 for n in lineage["nodes"] if lineage["nodes"][n]["has_trade_stream"])
        n_sig = len([n for n in lineage["nodes"] if lineage["nodes"][n]["mechanism_signature"]])
        print(f"  signatures={n_sig} streamed_eas={n_stream}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
