#!/usr/bin/env python3
"""2026-09-03_treasure_hunt_eras_repro.py -- regenerator for the era treasure hunt.

READ-ONLY.  Opens ``D:/QM/strategy_farm/state/farm_state.sqlite`` exclusively through
``rebaseline_census.open_ro()`` (a ``file:...?mode=ro`` URI).  It never writes to the
database, never enqueues, never records, never starts a terminal.  Its only writes are
the two CSV artefacts and the metrics JSON, all under ``docs/ops/evidence/``.

Canonical command (from the repo/worktree root)::

    python docs/ops/evidence/2026-09-03_treasure_hunt_eras_repro.py \
        --db D:/QM/strategy_farm/state/farm_state.sqlite \
        --out-dir docs/ops/evidence \
        --metrics-json docs/ops/evidence/2026-09-03_treasure_hunt_eras_metrics.json

It regenerates, byte-for-byte from the live DB plus the repo:

  * ``2026-09-03_treasure_hunt_eras_inventory.csv``   (one row per (EA, formation era))
  * ``2026-09-03_treasure_hunt_eras_candidates.csv``  (ranked treasure candidates)
  * ``2026-09-03_treasure_hunt_eras_metrics.json``    (every number quoted in the report)

Classifier provenance
---------------------
The verdict classifier is imported *verbatim* from the production census, not
reimplemented here:

  ``tools/strategy_farm/rebaseline_census.py``
    * ``PASS_ECON``       lines 100-124  (includes ``CONFIG_LOCKED``,
                          ``NO_FILTER_CHANGE``, ``NO_PARAMETER_CHANGE``)
    * ``ECON_FAIL``       lines 125-129
    * ``INFRA_CLS``       line  130
    * ``INVALID_CLS``     lines 131-135
    * ``STALE_CLS``       lines 136-140
    * ``NA_CLS``          line  141
    * ``GATE_SCOPED_PASS`` line 182  -- ``{"Q08": {"FAIL_SOFT"}}``, the
                          OWNER-DEC-DL082-EXT-Q08-20260901 / CEO-ASK-20260902-2 receipt
    * ``vclass(verdict, gate=None)``  line 185
    * ``LEGACY_ALIAS``    lines 85-90
    * ``open_ro()``       line 209

Gate axis -- an explicit, documented choice
-------------------------------------------
The gate axis of this audit is **storage-phase space** (``storage_gate()``):

  * ``LEGACY_ALIAS`` verbatim -- P2->Q02, P3/P3.5->Q03, P4->Q04, P5*->Q05, P6->Q07,
    P7/P8->Q08;
  * a ``*_NEWS`` lane -> the ACTIVE manifest's news gate (``NEWS_GATE``, Q10 under v4).
    The v3->v4 renumber moved the news gate from ``Q09_NEWS`` to ``Q10_NEWS``, so both
    spellings denote the same gate;
  * a ``*_PORTFOLIO`` lane -> its parent numeric gate, flagged informational
    (``is_portfolio_lane``), faithful to ``rebaseline_census`` lines 362-369 where a
    portfolio sibling never advances the PASS frontier.

It is deliberately **NOT** ``rebaseline_census.canonical_gate(phase, gate_contract_version)``.
``canonical_gate`` additionally performs the v3->v4 contract translation, under which a
row stamped ``gate_contract_version='legacy'`` (111,587 of ~127,800 rows) has its stored
``Q10`` renumbered to ``Q11``.  That translation is correct for the contiguity census, but
it would renumber every evidence path, every ``aggregate.json`` directory
(``.../QM5_9510/Q09/XAUUSD_DWX/...``) and every OWNER-facing "Q09 PASS" sentence in this
corpus by one gate.

The choice is measured, not asserted: ``--gate-axis canonical`` recomputes the whole audit
under ``canonical_gate``, and ``gate_axis_divergence`` in the metrics JSON lists every row
class on which the two axes disagree (253 rows at the 2026-09-03 snapshot).  The audit's
conclusions are identical on both axes; only the Q10/Q11 gate labels differ.
"""
from __future__ import annotations

import argparse
import csv
import datetime as _dt
import importlib.util
import json
import math
import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path

_HERE = Path(__file__).resolve()
_REPO_ROOT = _HERE.parents[3]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

from tools.strategy_farm.rebaseline_census import (  # noqa: E402
    GATE_SCOPED_PASS,
    LEGACY_ALIAS,
    NEWS_GATE,
    canonical_gate,
    open_ro,
    vclass,
)

# DL-071 arithmetic, imported from the runner rather than restated.
_Q04_PATH = _REPO_ROOT / "framework" / "scripts" / "q04_walkforward.py"
_q04_spec = importlib.util.spec_from_file_location("qm_q04_walkforward", _Q04_PATH)
_q04 = importlib.util.module_from_spec(_q04_spec)
_q04_spec.loader.exec_module(_q04)
PF_NET_FLOOR_PER_FOLD = _q04.PF_NET_FLOOR_PER_FOLD
Q04_SOFT_MEAN_FLOOR = _q04.Q04_SOFT_MEAN_FLOOR
Q04_SOFT_MIN_FOLD_FLOOR = _q04.Q04_SOFT_MIN_FOLD_FLOOR
Q04_SOFT_MIN_POS_FRACTION = _q04.Q04_SOFT_MIN_POS_FRACTION
pf_measurement_issue = _q04.pf_measurement_issue

DEFAULT_DB = "D:/QM/strategy_farm/state/farm_state.sqlite"
RUNTIME_CARDS = Path("D:/QM/strategy_farm/artifacts/cards_approved")

ERAS = ("PRE_JUNE", "JUNE", "JULY", "AUGUST", "SEPTEMBER")
ERA_BOUNDS = {
    "PRE_JUNE": (None, "2026-06-01"),
    "JUNE": ("2026-06-01", "2026-07-01"),
    "JULY": ("2026-07-01", "2026-08-01"),
    "AUGUST": ("2026-08-01", "2026-09-01"),
    "SEPTEMBER": ("2026-09-01", None),
}
REPORT_ERAS = ("PRE_JUNE", "JUNE", "AUGUST")

# Gate ordering used for "deepest PASS".  Storage space, Q02 first.
GATE_ORDER = ["Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09",
              "Q10", "Q11", "Q12", "Q13", "Q14", "Q15", "Q16", "Q17"]
GATE_RANK = {g: i for i, g in enumerate(GATE_ORDER)}

# Storage lanes that are informational siblings of their parent gate.
PORTFOLIO_SUFFIX = "_PORTFOLIO"
NEWS_SUFFIX = "_NEWS"

EA_ID_RE = re.compile(r"(QM5_\d+)")
LIFECYCLE_KEYS = ("created", "created_at", "approved_at", "g0_approved_at", "last_updated")
DATE_RE = re.compile(r"(20\d\d)-(\d\d)-(\d\d)")

# An OWNER disposition is a NON-NULL ``owner_decision_id`` in the row payload.
# A substring test over payload_json is not sufficient: unrelated worker keys such
# as ``owner_approved`` match it and falsely tag pairs (QM5_9510/XAUUSD carried a
# bare ``owner_approved`` token on its Q07 row and was mis-labelled LEAVE).
OWNER_TAG_HINT = "owner_decision_id"


def owner_decision_of(payload: str | None) -> str:
    """Return the row's OWNER decision id, or "" when it carries none."""
    if not payload or OWNER_TAG_HINT not in payload:
        return ""
    try:
        d = json.loads(payload)
    except (ValueError, TypeError):
        return ""
    if not isinstance(d, dict):
        return ""
    val = d.get("owner_decision_id")
    return str(val).strip() if val else ""

# The removed ticket worktrees whose setfile paths the 2026-08-25 INVALID sweep bound.
DEAD_WORKTREE_RE = re.compile(r"^[A-Za-z]:[\\/]QM[\\/]worktrees[\\/]([^\\/]+)[\\/]", re.IGNORECASE)

D3_MIN_PF = 1.2          # 2026-07-03 detector D3: gross-edge floor
D3_MIN_TRADES = 20       # 2026-07-03 detector D3: minimum sample for that PF
IN_FLIGHT_CUTOFF = "2026-08-20"
STALE_PENDING_CUTOFF = "2026-08-01"


# ---------------------------------------------------------------------------
# gate axis
# ---------------------------------------------------------------------------

def storage_gate(phase: str | None) -> str | None:
    """Collapse a storage phase onto the display gate axis.

    * ``LEGACY_ALIAS`` is taken verbatim from rebaseline_census.py:85-90.
    * A ``*_NEWS`` lane resolves to the ACTIVE manifest's news gate
      (``rebaseline_census.NEWS_GATE`` = Q10 under v4), never to the numeric prefix of
      its own storage spelling.  The v3->v4 renumber moved the news gate from
      ``Q09_NEWS`` to ``Q10_NEWS``, so both spellings denote the same gate; the census
      makes the same identification for ``Q10_NEWS``/``Q10_PORTFOLIO``
      (rebaseline_census.py:77-83).  Stripping ``_NEWS`` to "Q09" instead would place a
      pending news row BELOW a standing Q09 PASS and make an already-seeded gate look
      unseeded -- exactly the class of error this revision exists to remove.
    * A ``*_PORTFOLIO`` lane keeps its parent numeric gate and is flagged informational
      (``is_portfolio_lane``), matching rebaseline_census.py:362-369.
    """
    p = (phase or "").strip().upper()
    if not p:
        return None
    if p in LEGACY_ALIAS:
        return LEGACY_ALIAS[p]
    if p.endswith(NEWS_SUFFIX):
        return NEWS_GATE if NEWS_GATE in GATE_RANK else None
    if p.endswith(PORTFOLIO_SUFFIX):
        p = p[: -len(PORTFOLIO_SUFFIX)]
    return p if p in GATE_RANK else None


def make_gate_fn(axis: str):
    """Return a memoised (phase, gate_contract_version) -> gate resolver."""
    cache: dict[tuple[str, str], str | None] = {}
    if axis == "storage":
        def fn(phase, gcv):
            key = (str(phase or ""), "")
            if key not in cache:
                cache[key] = storage_gate(phase)
            return cache[key]
        return fn
    if axis == "canonical":
        def fn(phase, gcv):
            key = (str(phase or ""), str(gcv or ""))
            if key not in cache:
                cache[key] = canonical_gate(phase, gcv)
            return cache[key]
        return fn
    raise SystemExit(f"unknown --gate-axis {axis!r}")


def vclass_pass(verdict: str | None, gate: str | None = None) -> bool:
    """True when the production classifier scores this verdict PASS at this gate."""
    return vclass(verdict, gate) == "PASS"


def is_portfolio_lane(phase: str | None) -> bool:
    return (phase or "").strip().upper().endswith(PORTFOLIO_SUFFIX)


# ---------------------------------------------------------------------------
# cohort
# ---------------------------------------------------------------------------

def era_of(date_str: str | None) -> str | None:
    if not date_str:
        return None
    d = date_str[:10]
    if not DATE_RE.match(d):
        return None
    for era in ERAS:
        lo, hi = ERA_BOUNDS[era]
        if (lo is None or d >= lo) and (hi is None or d < hi):
            return era
    return None


def _front_matter_dates(text: str) -> list[str]:
    """Pull lifecycle dates out of a strategy card's YAML front matter."""
    out: list[str] = []
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        body = lines[:60]
    else:
        body = []
        for line in lines[1:]:
            if line.strip() == "---":
                break
            body.append(line)
    for line in body:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        key, _, val = stripped.partition(":")
        if key.strip().lower() not in LIFECYCLE_KEYS:
            continue
        m = DATE_RE.search(val)
        if m:
            out.append(m.group(0))
    return out


def scan_cards(repo_root: Path) -> tuple[dict[str, set[str]], dict[str, str], dict[str, int]]:
    """Return (ea_id -> set(eras from card lifecycle dates), ea_id -> slug, stats)."""
    eras: dict[str, set[str]] = defaultdict(set)
    slugs: dict[str, str] = {}
    first_date: dict[str, str] = {}
    files = 0
    sources: list[Path] = []
    if RUNTIME_CARDS.is_dir():
        sources.extend(sorted(RUNTIME_CARDS.glob("*.md")))
    repo_cards = repo_root / "artifacts" / "cards_approved"
    if repo_cards.is_dir():
        sources.extend(sorted(repo_cards.glob("*.md")))
    sources.extend(sorted((repo_root / "framework" / "EAs").glob("*/docs/strategy_card.md")))
    for path in sources:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        files += 1
        m = re.search(r"^ea_id:\s*(QM5_\d+)", text, re.MULTILINE)
        ea = m.group(1) if m else None
        if ea is None:
            m2 = EA_ID_RE.search(path.stem if path.stem != "strategy_card" else path.parts[-3])
            ea = m2.group(1) if m2 else None
        if ea is None:
            continue
        ms = re.search(r"^slug:\s*(\S+)", text, re.MULTILINE)
        if ms and ea not in slugs:
            slugs[ea] = ms.group(1).strip().strip('"')
        elif ea not in slugs:
            stem = path.parts[-3] if path.stem == "strategy_card" else path.stem
            slugs[ea] = stem[len(ea) + 1:] if stem.startswith(ea + "_") else ""
        for d in _front_matter_dates(text):
            e = era_of(d)
            if e:
                eras[ea].add(e)
            if ea not in first_date or d < first_date[ea]:
                first_date[ea] = d
    return eras, slugs, {"card_files": files, "card_ea_ids": len(eras) or 0,
                         "_first_date": first_date}


def scan_git_touches(repo_root: Path):
    """Scan canonical git history for per-EA touches.

    Returns ``(card_eras, any_eras, first_touch)``:

      * ``card_eras``   ea_id -> eras in which a *card* file was touched
                        (``artifacts/cards_approved/*.md`` or
                        ``framework/EAs/<EA>/docs/strategy_card.md``);
      * ``any_eras``    ea_id -> eras in which ANY file under
                        ``framework/EAs/<EA>/`` or the card dirs was touched;
      * ``first_touch`` ea_id -> earliest commit date touching any of those paths.
    """
    card_eras: dict[str, set[str]] = defaultdict(set)
    any_eras: dict[str, set[str]] = defaultdict(set)
    first_touch: dict[str, str] = {}
    cmd = [
        "git", "-C", str(repo_root), "log", "--no-merges", "--name-only",
        "--pretty=format:@@%ad", "--date=short",
        "--", "artifacts/cards_approved", "framework/EAs",
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    except (OSError, subprocess.SubprocessError):
        return card_eras, any_eras, first_touch
    era = None
    date = ""
    for line in proc.stdout.splitlines():
        if line.startswith("@@"):
            date = line[2:].strip()
            era = era_of(date)
            continue
        if not line.strip():
            continue
        m = EA_ID_RE.search(line)
        if not m:
            continue
        ea = m.group(1)
        if date and (ea not in first_touch or date < first_touch[ea]):
            first_touch[ea] = date
        if era is None:
            continue
        any_eras[ea].add(era)
        if "cards_approved/" in line or line.endswith("docs/strategy_card.md"):
            card_eras[ea].add(era)
    return card_eras, any_eras, first_touch


# ---------------------------------------------------------------------------
# DB load
# ---------------------------------------------------------------------------

class Row:
    __slots__ = ("id", "ea_id", "symbol", "phase", "gate", "status", "verdict",
                 "cls", "updated_at", "created_at", "evidence_path", "setfile_path",
                 "payload", "gcv", "portfolio")

    def __init__(self, r, gate_fn):
        self.id = r["id"]
        self.ea_id = (r["ea_id"] or "").strip()
        self.symbol = (r["symbol"] or "").strip()
        self.phase = (r["phase"] or "").strip()
        self.gcv = r["gate_contract_version"]
        self.gate = gate_fn(self.phase, self.gcv)
        self.status = (r["status"] or "").strip()
        self.verdict = (r["verdict"] or "").strip()
        self.cls = vclass(self.verdict, self.gate)
        self.updated_at = norm_ts(r["updated_at"])
        self.created_at = norm_ts(r["created_at"])
        self.evidence_path = r["evidence_path"] or ""
        self.setfile_path = r["setfile_path"] or ""
        self.payload = r["payload_json"] or ""
        self.portfolio = is_portfolio_lane(self.phase)


def norm_ts(value) -> str:
    """Normalise the two stored timestamp spellings ('T' and ' ') to one sortable form."""
    if not value:
        return ""
    return str(value).replace("T", " ")[:19]


def load_rows(con, gate_fn) -> list[Row]:
    sql = ("SELECT id, ea_id, symbol, phase, status, verdict, updated_at, created_at, "
           "evidence_path, setfile_path, payload_json, gate_contract_version "
           "FROM work_items")
    return [Row(r, gate_fn) for r in con.execute(sql)]


def load_metrics(con) -> tuple[dict[tuple[str, str], list[dict]], dict[str, dict]]:
    """Return (by-pair index, by-work_item_id index) over ea_metrics."""
    by_pair: dict[tuple[str, str], list[dict]] = defaultdict(list)
    by_wid: dict[str, dict] = {}
    sql = ("SELECT work_item_id, ea_id, symbol, phase, verdict, profit_factor, trades, "
           "drawdown_pct, net_profit, detail_json, evidence_path "
           "FROM ea_metrics")
    for r in con.execute(sql):
        d = dict(r)
        by_pair[((r["ea_id"] or "").strip(), (r["symbol"] or "").strip())].append(d)
        wid = r["work_item_id"]
        if wid and wid not in by_wid:
            by_wid[wid] = d
    return by_pair, by_wid


# ---------------------------------------------------------------------------
# per-pair / per-EA state
# ---------------------------------------------------------------------------

def build_pairs(rows: list[Row]) -> dict[tuple[str, str], dict]:
    pairs: dict[tuple[str, str], dict] = {}
    for row in rows:
        if not row.ea_id or not row.symbol:
            continue
        rec = pairs.setdefault((row.ea_id, row.symbol), {"rows": []})
        rec["rows"].append(row)
    for key, rec in pairs.items():
        rec["rows"].sort(key=lambda r: (r.updated_at, r.created_at, r.id))
        chain = [r for r in rec["rows"] if r.gate]
        passes = [r for r in chain
                  if r.cls == "PASS" and r.status.lower() == "done" and not r.portfolio]
        rec["deepest_pass"] = (
            max(passes, key=lambda r: (GATE_RANK.get(r.gate, -1), r.updated_at))
            if passes else None
        )
        rec["portfolio_passes"] = sorted({r.gate for r in chain
                                          if r.portfolio and r.cls == "PASS"})
        rec["head"] = rec["rows"][-1] if rec["rows"] else None
        rec["chain"] = chain
        decisions = sorted({d for d in (owner_decision_of(r.payload) for r in rec["rows"]) if d})
        rec["owner_decisions"] = decisions
        rec["owner_tagged"] = bool(decisions)
        rec["in_flight"] = any(
            r.status.lower() in ("pending", "active", "claimed")
            and r.updated_at[:10] >= IN_FLIGHT_CUTOFF
            for r in rec["rows"]
        )
    return pairs


def build_eas(pairs, rows) -> dict[str, dict]:
    """Per-EA rollup.

    The EA head is the latest row of the EA over ALL its work items, including the
    symbol-less ``COMPILE_EA`` rows (586 in the corpus, verdicts COMPILE_OK /
    COMPILE_FAIL / INVALID).  Those rows form no (EA, symbol) pair, so restricting the
    head to pair heads silently drops every build-only EA into "PENDING".
    """
    eas: dict[str, dict] = defaultdict(lambda: {
        "n_work_items": 0, "pairs": [], "superseded_any": False, "all_rows": []})
    for row in rows:
        if row.ea_id:
            rec = eas[row.ea_id]
            rec["n_work_items"] += 1
            rec["all_rows"].append(row)
            if row.cls == "STALE":
                rec["superseded_any"] = True
    for (ea, sym), rec in pairs.items():
        eas[ea]["pairs"].append((sym, rec))
    for ea, rec in eas.items():
        deepest = [p["deepest_pass"] for _s, p in rec["pairs"] if p["deepest_pass"]]
        rec["deepest_pass"] = (
            max(deepest, key=lambda r: (GATE_RANK.get(r.gate, -1), r.updated_at)).gate
            if deepest else ""
        )
        rec["head"] = (max(rec["all_rows"], key=lambda r: (r.updated_at, r.id))
                       if rec["all_rows"] else None)
    return eas


# ---------------------------------------------------------------------------
# evidence-path helpers  (defect #3 fix)
# ---------------------------------------------------------------------------

def count_strategy_params(setfile_path: str) -> int | None:
    """Count ``strategy_*=`` assignments in a .set file (report S5.4 column)."""
    if not setfile_path or not os.path.exists(setfile_path):
        return None
    try:
        text = Path(setfile_path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    return sum(1 for line in text.splitlines()
               if line.strip().lower().startswith("strategy_") and "=" in line)


def path_exists(p: str | None) -> bool:
    if not p:
        return False
    try:
        return os.path.exists(p)
    except (OSError, ValueError):
        return False


def canonical_setfile_for(setfile_path: str, canonical_root: Path) -> tuple[str, bool]:
    """Rewrite a dead ``C:/QM/worktrees/<wt>/`` setfile path onto the canonical repo.

    Returns (canonical_path_or_empty, exists).  Used only for the T2 class, whose whole
    premise is that ``setfile_path`` points into a worktree that was removed; the
    canonical column answers "is the artefact recoverable today?" while
    ``evidence_present`` keeps answering "does the path in this row exist?".

    ``canonical_root`` is ``C:/QM/repo`` by default, NOT the audit worktree -- a shipped
    artefact must name the path an operator can act on.
    """
    if not setfile_path:
        return "", False
    m = DEAD_WORKTREE_RE.match(setfile_path)
    if not m:
        return "", False
    tail = setfile_path[m.end():]
    cand = canonical_root / tail.replace("\\", "/")
    return str(cand).replace("/", os.sep), cand.exists()


def metric_best(mrows: list[dict], plausible_only: bool = True) -> dict:
    """Best PF over a set of ea_metrics rows.

    ``plausible_only`` applies the runner's own guard
    (framework/scripts/q04_walkforward.py:111 ``pf_measurement_issue``): a PF of 666
    on 3 trades or the 999.0 zero-gross-loss sentinel is not a measurement and must
    never rank a candidate.  Without it the frozen-disposition list sorts by
    denominator artefacts instead of by edge.
    """
    best = {"pf": None, "trades": None, "dd_pct": None, "net_profit": None,
            "pf_guard": ""}
    for m in mrows or []:
        pf = m.get("profit_factor")
        if pf is None:
            continue
        guard = pf_measurement_issue(pf, int(m.get("trades") or 0))
        if plausible_only and guard:
            continue
        if best["pf"] is None or pf > best["pf"]:
            best = {"pf": pf, "trades": m.get("trades"), "dd_pct": m.get("drawdown_pct"),
                    "net_profit": m.get("net_profit"), "pf_guard": guard or ""}
    return best


# populated in run(); a plain module-level index keeps the detector code readable
_METRIC_BY_WID: dict[str, dict] = {}


def metric_for_row(_mrows, work_item_id: str) -> dict | None:
    return _METRIC_BY_WID.get(work_item_id)


# ---------------------------------------------------------------------------
# detectors
# ---------------------------------------------------------------------------

def successor_rows(rec: dict, standing: Row) -> list[Row]:
    """Every row of the pair at a gate strictly deeper than ``standing``.

    Defect #2 fix.  The first-edition detector tested ``updated_at > standing.updated_at``
    only, so a next-gate row seeded *hours before* the PASS landed was invisible and the
    pair was reported as "no successor" -- QM5_12710/XTIUSD carries a Q09 PASS at
    2026-08-29 20:38:36 and a Q10_NEWS row at 2026-08-29 17:43:40, and acting on that
    recommendation would have been a duplicate enqueue.

    Successorship is therefore ordinal, not chronological: the question an operator asks
    is "does a row at the NEXT gate already exist", and its answer must not depend on
    which of two rows minutes apart was written first.  Later activity at the same or a
    shallower gate is tracked separately by ``later_activity_rows``.
    """
    rank = GATE_RANK.get(standing.gate, -1)
    return [r for r in rec["rows"]
            if r.id != standing.id
            and r.gate is not None
            and GATE_RANK.get(r.gate, -1) > rank]


def later_activity_rows(rec: dict, standing: Row) -> list[Row]:
    """Rows later than the standing PASS that are NOT at a deeper gate.

    A pair with a fresh Q02 row after a Q09 PASS is being reworked from the front
    (recompile / new identity); it is not stalled, but its next gate is not seeded
    either.  Kept as its own signal so neither state is silently absorbed.
    """
    rank = GATE_RANK.get(standing.gate, -1)
    return [r for r in rec["rows"]
            if r.id != standing.id
            and r.updated_at > standing.updated_at
            and (r.gate is None or GATE_RANK.get(r.gate, -1) <= rank)]


def open_successor(rows: list[Row]) -> Row | None:
    """The first pending/active successor, i.e. the gate that is already seeded."""
    for r in sorted(rows, key=lambda r: (GATE_RANK.get(r.gate or "", -1), r.updated_at)):
        if r.status.lower() in ("pending", "active", "claimed"):
            return r
    return None


def frontier_state(standing: Row, succ: list[Row]) -> str:
    """Classify the frontier of a pair holding a standing deep PASS.

    Defect #2 fix, second half.  "Has a successor" is not the operational question --
    "is there an OPEN row at a deeper gate" is.  A closed successor that predates the
    standing PASS (QM5_9510/XAUUSD: Q10_NEWS REVIEW_REQUIRED 2026-08-25, Q09 PASS
    2026-08-30) neither blocks a re-seed nor proves the gate answered.
    """
    if not succ:
        return "NO_SUCCESSOR"
    if open_successor(succ) is not None:
        return "SUCCESSOR_PENDING"
    latest = max(succ, key=lambda r: r.updated_at)
    return ("SUCCESSOR_TERMINAL_AFTER_PASS" if latest.updated_at >= standing.updated_at
            else "SUCCESSOR_TERMINAL_BEFORE_PASS")



def next_gate_after(gate: str | None) -> str:
    if not gate or gate not in GATE_RANK:
        return ""
    idx = GATE_RANK[gate]
    return GATE_ORDER[idx + 1] if idx + 1 < len(GATE_ORDER) else ""


# ---------------------------------------------------------------------------
# main audit
# ---------------------------------------------------------------------------

def _tick(label: str, state=[None]) -> None:
    import time
    now = time.time()
    if state[0] is not None:
        print(f"[repro] {label}: {now - state[0]:.1f}s", file=sys.stderr, flush=True)
    state[0] = now


def run(args) -> dict:
    repo_root = Path(args.repo_root).resolve()
    canonical_root = Path(args.canonical_repo_root).resolve()
    _tick("start")
    gate_fn = make_gate_fn(args.gate_axis)
    con = open_ro(args.db)
    try:
        rows = load_rows(con, gate_fn)
        metrics, metric_by_wid = load_metrics(con)
        _METRIC_BY_WID.clear()
        _METRIC_BY_WID.update(metric_by_wid)
        holds = {r[0] for r in con.execute(
            "SELECT work_item_id FROM work_item_holds WHERE active=1")}
        portfolio_states: dict[tuple[str, str], list[str]] = defaultdict(list)
        for r in con.execute("SELECT ea_id, symbol, state FROM portfolio_candidates"):
            portfolio_states[((r[0] or "").strip(), (r[1] or "").strip())].append(r[2] or "")
        quarantine = list(con.execute(
            "SELECT ea_id, symbol, phase, active, verdict_reason, consecutive_failures, "
            "successes_ever, quarantined_at FROM poison_pill_quarantine"))
        fold_rows = list(con.execute(
            "SELECT w.id, w.ea_id, w.symbol, w.phase, w.verdict, m.detail_json, "
            "       m.evidence_path "
            "FROM work_items w LEFT JOIN ea_metrics m ON m.work_item_id = w.id "
            "WHERE w.phase IN ('Q04','P2','P3.5') "
            "  AND w.verdict IN ('FAIL','INVALID')"))
    finally:
        con.close()

    _tick("load_db")
    pairs = build_pairs(rows)
    eas = build_eas(pairs, rows)

    _tick("build_pairs_eas")
    runtime_card_eras, slugs, card_stats = scan_cards(repo_root)
    first_dates = card_stats.pop("_first_date")
    _tick("scan_cards")
    git_card_eras, git_any_eras, git_first = scan_git_touches(repo_root)
    _tick("scan_git")

    # Cohort rule, faithful to the July audit (f91d364b) and restated in report S2.1:
    # (a) every card file touched in canonical git during the month, UNION
    # (b) every runtime / checked-in card carrying a lifecycle date in that month.
    card_eras: dict[str, set[str]] = defaultdict(set)
    for src in (runtime_card_eras, git_card_eras):
        for ea, es in src.items():
            card_eras[ea] |= es
    # Second axis quoted in S2.1: the same union widened to any framework/EAs touch.
    union_eras: dict[str, set[str]] = defaultdict(set)
    for src in (runtime_card_eras, git_any_eras):
        for ea, es in src.items():
            union_eras[ea] |= es
    # first lifecycle date = earliest card lifecycle date, else earliest git touch
    for ea, d in git_first.items():
        if ea not in first_dates or d < first_dates[ea]:
            first_dates[ea] = d

    m: dict = {"snapshot": {}, "cohort": {}, "inventory": {}, "findings": {}}
    m["classifier"] = {
        "module": "tools/strategy_farm/rebaseline_census.py",
        "vclass_line": 185,
        "gate_scoped_pass_line": 182,
        "gate_scoped_pass": {k: sorted(v) for k, v in GATE_SCOPED_PASS.items()},
        "pass_econ_lines": "100-124",
        "legacy_alias_lines": "85-90",
        "open_ro_line": 209,
        "gate_axis": args.gate_axis,
    }
    m["snapshot"]["measured_at_utc"] = _dt.datetime.now(_dt.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")
    m["snapshot"]["db"] = args.db
    m["snapshot"]["db_mtime_utc"] = (
        _dt.datetime.fromtimestamp(os.path.getmtime(args.db), _dt.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%SZ") if os.path.exists(args.db) else "")
    m["snapshot"]["work_items_total"] = len(rows)
    m["snapshot"]["pairs_total"] = len(pairs)
    m["snapshot"]["eas_with_work_items"] = len({r.ea_id for r in rows if r.ea_id})

    # ---- cohorts -----------------------------------------------------------
    for era in ERAS:
        m["cohort"][era] = {
            "card_scoped": sum(1 for e in card_eras.values() if era in e),
            "union_any_git_touch": sum(1 for e in union_eras.values() if era in e),
            "first_lifecycle_disjoint": sum(1 for ea, d in first_dates.items()
                                            if era_of(d) == era),
        }
    m["cohort"]["_card_files_parsed"] = card_stats["card_files"]
    m["cohort"]["_ea_ids_with_runtime_card_era"] = len(runtime_card_eras)
    m["cohort"]["_ea_ids_with_any_lifecycle_date"] = len(first_dates)
    m["cohort"]["_ea_ids_in_any_era_card_scoped"] = len(card_eras)
    m["cohort"]["_ea_ids_in_any_era_union"] = len(union_eras)
    overlaps = Counter()
    for ea, es in card_eras.items():
        se = sorted(es, key=ERAS.index)
        for i in range(len(se)):
            for j in range(i + 1, len(se)):
                overlaps[f"{se[i]}_x_{se[j]}"] += 1
    m["cohort"]["overlaps_card_scoped"] = dict(sorted(overlaps.items()))

    # ---- inventory ---------------------------------------------------------
    inv_rows = []
    for era in REPORT_ERAS:
        members = sorted(ea for ea, es in card_eras.items() if era in es)
        gate_hist = Counter()
        head_verdicts = Counter()
        pair_cls = Counter()
        n_items = 0
        n_pairs = 0
        for ea in members:
            rec = eas.get(ea)
            if rec is None:
                gate_hist[""] += 1
                head_verdicts["NO_WORK_ITEMS"] += 1
                inv_rows.append({
                    "ea_id": ea, "era": era, "slug": slugs.get(ea, ""),
                    "first_lifecycle_date": first_dates.get(ea, ""),
                    "n_work_items": 0, "n_pairs": 0, "deepest_pass": "",
                    "head_phase": "", "head_verdict": "", "head_status": "",
                    "head_date": "", "superseded_any": False, "portfolio_states": "",
                })
                continue
            gate_hist[rec["deepest_pass"]] += 1
            n_items += rec["n_work_items"]
            n_pairs += len(rec["pairs"])
            head = rec["head"]
            head_verdicts[(head.verdict if head else "") or "PENDING"] += 1
            for sym, prec in rec["pairs"]:
                h = prec["head"]
                if h is None:
                    continue
                if h.status.lower() in ("pending", "active", "claimed"):
                    pair_cls["PENDING"] += 1
                else:
                    pair_cls[h.cls if h.cls != "OTHER" else "OTHER"] += 1
            pstates = sorted({s for sym, _p in rec["pairs"]
                              for s in portfolio_states.get((ea, sym), [])})
            inv_rows.append({
                "ea_id": ea, "era": era, "slug": slugs.get(ea, ""),
                "first_lifecycle_date": first_dates.get(ea, ""),
                "n_work_items": rec["n_work_items"], "n_pairs": len(rec["pairs"]),
                "deepest_pass": rec["deepest_pass"],
                "head_phase": head.phase if head else "",
                "head_verdict": head.verdict if head else "",
                "head_status": head.status if head else "",
                "head_date": (head.updated_at[:10] if head else ""),
                "superseded_any": rec["superseded_any"],
                "portfolio_states": ";".join(pstates),
            })
        m["inventory"][era] = {
            "eas": len(members),
            "work_items": n_items,
            "pairs": n_pairs,
            "deepest_pass_hist": {k or "none": v for k, v in
                                  sorted(gate_hist.items(),
                                         key=lambda kv: GATE_RANK.get(kv[0], -1))},
            "head_verdict_hist": dict(head_verdicts.most_common()),
            "pair_terminal_class": dict(pair_cls.most_common()),
        }

    # ---- Q08 FAIL_SOFT blast radius (defect #1 evidence) --------------------
    fs = [r for r in rows if r.gate == "Q08" and r.verdict.upper() == "FAIL_SOFT"]
    m["findings"]["q08_fail_soft"] = {
        "rows": len(fs),
        "pairs": len({(r.ea_id, r.symbol) for r in fs}),
        "eas": len({r.ea_id for r in fs}),
    }
    cl_rows = [r for r in rows if r.verdict.upper() == "CONFIG_LOCKED"]
    m["findings"]["config_locked"] = {
        "rows": len(cl_rows),
        "pairs": len({(r.ea_id, r.symbol) for r in cl_rows}),
    }
    for tok in ("NO_FILTER_CHANGE", "NO_PARAMETER_CHANGE"):
        tr = [r for r in rows if r.verdict.upper() == tok]
        m["findings"][tok.lower()] = {"rows": len(tr),
                                      "pairs": len({(r.ea_id, r.symbol) for r in tr})}

    _tick("inventory")
    # ---- classifier delta vs the pre-2026-09-02 census copy -----------------
    # The audit's first edition ran a rebaseline_census.py checkout that predated
    # 8baa00fde9 / 9bf85d95b8.  Its vclass() took no gate argument, had no
    # GATE_SCOPED_PASS, put CONFIG_LOCKED in STALE_CLS and lacked
    # NO_FILTER_CHANGE / NO_PARAMETER_CHANGE.  This block measures, from the same
    # rows, exactly what that cost -- so the correction is auditable rather than
    # asserted.
    stale_pass = {"PASS", "PASS_SOFT", "PASS_LOWFREQ", "PASS_PORTFOLIO",
                  "PROMOTE_CHALLENGER", "CHALLENGER_PROMOTED", "KEEP_INCUMBENT",
                  "ADMIT_BOTH"}

    def _deepest(rs, passfn):
        best = None
        for r in rs:
            if not r.gate or r.portfolio or r.status.lower() != "done":
                continue
            if not passfn(r):
                continue
            if best is None or GATE_RANK.get(r.gate, -1) > GATE_RANK.get(best.gate, -1):
                best = r
        return best

    new_fn = lambda r: vclass(r.verdict, r.gate) == "PASS"          # noqa: E731
    old_fn = lambda r: r.verdict.strip().upper() in stale_pass      # noqa: E731
    pair_changed = []
    q10_flip = []
    q08_flip = []
    ea_new: dict[str, Row] = {}
    ea_old: dict[str, Row] = {}
    for (ea, sym), rec in pairs.items():
        rs = rec["rows"]
        dn, do = _deepest(rs, new_fn), _deepest(rs, old_fn)
        if (dn.gate if dn else None) != (do.gate if do else None):
            pair_changed.append({
                "pair": f"{ea}/{sym}",
                "old": do.gate if do else None, "new": dn.gate if dn else None,
                "verdict": dn.verdict if dn else None,
                "phase": dn.phase if dn else None,
                "updated_at": dn.updated_at if dn else None,
            })
        # gate-local flips
        for gate, tokens, sink in (("Q10", {"CONFIG_LOCKED"}, q10_flip),
                                   ("Q08", {"FAIL_SOFT"}, q08_flip)):
            at = [r for r in rs if r.gate == gate and r.status.lower() == "done"
                  and not r.portfolio]
            if not at:
                continue
            had_old = any(old_fn(r) for r in at)
            tok = [r for r in at if r.verdict.strip().upper() in tokens]
            if tok and not had_old and any(new_fn(r) for r in at):
                sink.append({"pair": f"{ea}/{sym}",
                             "token": tok[-1].verdict,
                             "phase": tok[-1].phase,
                             "updated_at": tok[-1].updated_at})
        for store, d in ((ea_new, dn), (ea_old, do)):
            if d is None:
                continue
            cur = store.get(ea)
            if cur is None or GATE_RANK.get(d.gate, -1) > GATE_RANK.get(cur.gate, -1):
                store[ea] = d
    ea_changed = []
    for ea in set(ea_new) | set(ea_old):
        gn = ea_new[ea].gate if ea in ea_new else None
        go = ea_old[ea].gate if ea in ea_old else None
        if gn != go:
            r = ea_new.get(ea)
            ea_changed.append({
                "ea_id": ea, "old": go, "new": gn,
                "verdict": r.verdict if r else None,
                "phase": r.phase if r else None,
                "symbol": r.symbol if r else None,
                "updated_at": r.updated_at if r else None,
                "eras": sorted(card_eras.get(ea, set()),
                               key=lambda e: ERAS.index(e) if e in ERAS else 99),
            })
    ea_changed.sort(key=lambda d: d["ea_id"])
    m["classifier_delta"] = {
        "pairs_total": len(pairs),
        "pairs_with_changed_deepest_pass": len(pair_changed),
        "pairs_changed_detail": pair_changed,
        "eas_with_changed_deepest_pass": len(ea_changed),
        "eas_changed_detail": ea_changed,
        "eas_changed_inside_report_cohorts": sum(
            1 for d in ea_changed if set(d["eras"]) & set(REPORT_ERAS)),
        "eas_changed_by_report_era": dict(Counter(
            e for d in ea_changed for e in d["eras"] if e in REPORT_ERAS)),
        "pairs_gaining_q10_pass_from_config_locked": q10_flip,
        "pairs_gaining_q10_pass_from_config_locked_count": len(q10_flip),
        "pairs_gaining_q08_pass_from_fail_soft": len(q08_flip),
    }

    # ---- D1: standing deep PASS ------------------------------------------
    deep_pairs = []
    for (ea, sym), rec in pairs.items():
        dp = rec["deepest_pass"]
        if dp is None or GATE_RANK.get(dp.gate, -1) < GATE_RANK["Q09"]:
            continue
        succ = successor_rows(rec, dp)
        deep_pairs.append((ea, sym, rec, dp, succ))
    state_counts = Counter()
    stalled: list[tuple] = []          # actionable: no OPEN successor
    owner_retired = []
    for ea, sym, rec, dp, succ in deep_pairs:
        state = frontier_state(dp, succ)
        state_counts[state] += 1
        if state in ("NO_SUCCESSOR", "SUCCESSOR_TERMINAL_BEFORE_PASS"):
            later = later_activity_rows(rec, dp)
            quiet = not later
            reworking = any(r.status.lower() in ("pending", "active", "claimed")
                            for r in later)
            stalled.append((ea, sym, rec, dp, state, quiet, reworking))
        if state.startswith("SUCCESSOR_TERMINAL") and rec["owner_tagged"]:
            owner_retired.append((ea, sym))
    m["findings"]["deep_pass_frontier"] = {
        "pairs_with_pass_at_q09_or_deeper": len(deep_pairs),
        "eas": len({e for e, _s, _r, _d, _x in deep_pairs}),
        "states": dict(sorted(state_counts.items())),
        "state_semantics": {
            "SUCCESSOR_PENDING": ("an OPEN pending/active row at a deeper gate already "
                                  "exists -- re-seeding it would be a duplicate enqueue"),
            "NO_SUCCESSOR": "no row of any kind after the standing PASS gate",
            "SUCCESSOR_TERMINAL_AFTER_PASS": ("the next gate ran after the PASS and "
                                              "answered -- the pair is not stalled"),
            "SUCCESSOR_TERMINAL_BEFORE_PASS": ("every successor is closed AND older than "
                                               "the standing PASS -- the PASS re-opened "
                                               "the pair and nothing was seeded since"),
        },
        "successor_terminal_owner_tagged": len(owner_retired),
        "stalled_pairs_no_open_successor": sorted(
            f"{e}/{s}" for e, s, _r, _d, _st, _q, _rw in stalled),
        "stalled_pairs_count": len(stalled),
        # A pair with later rows at or BELOW its standing gate is being reworked from
        # the front (recompile / new identity), not parked.  Only the quiet ones are
        # a pure "nobody seeded the next gate" finding.
        "stalled_quiet_count": sum(1 for x in stalled if x[5]),
        "stalled_reworked_count": sum(1 for x in stalled if not x[5]),
        "stalled_reworked_with_open_row": sum(1 for x in stalled if x[6]),
        "stalled_quiet_pairs": sorted(f"{e}/{s}" for e, s, _r, _d, _st, q, _rw
                                      in stalled if q),
    }
    quiet_eras = Counter()
    for ea, sym, rec, dp, _st, q, _rw in stalled:
        if not q:
            continue
        es = sorted(card_eras.get(ea, set()) or {"UNATTRIBUTED"},
                    key=lambda x: ERAS.index(x) if x in ERAS else 99)
        quiet_eras["+".join(es)] += 1
    m["findings"]["deep_pass_frontier"]["stalled_quiet_formation_eras"] = dict(
        sorted(quiet_eras.items(), key=lambda kv: (-kv[1], kv[0])))
    era_split = Counter()
    for ea, sym, rec, dp, _st, _q, _rw in stalled:
        es = sorted(card_eras.get(ea, set()) or {"UNATTRIBUTED"}, key=lambda x: ERAS.index(x)
                    if x in ERAS else 99)
        era_split["+".join(es)] += 1
    m["findings"]["deep_pass_frontier"]["stalled_formation_eras"] = dict(
        sorted(era_split.items(), key=lambda kv: (-kv[1], kv[0])))

    # ---- the two flagship pairs the verifier named (defect #2) --------------
    flagship = {}
    for key in (("QM5_12710", "XTIUSD.DWX"), ("QM5_21507", "XAUUSD.DWX"),
                ("QM5_9510", "XAUUSD.DWX")):
        rec = pairs.get(key)
        if rec is None:
            continue
        dp = rec["deepest_pass"]
        succ = successor_rows(rec, dp) if dp else []
        flagship[f"{key[0]}/{key[1]}"] = {
            "standing_gate": dp.gate if dp else None,
            "standing_verdict": dp.verdict if dp else None,
            "standing_updated_at": dp.updated_at if dp else None,
            "successors": [
                {"phase": r.phase, "gate": r.gate, "status": r.status,
                 "verdict": r.verdict, "updated_at": r.updated_at}
                for r in sorted(succ, key=lambda r: r.updated_at)
            ],
        }
    m["findings"]["flagship_pairs"] = flagship

    # ---- Q10_NEWS lane -----------------------------------------------------
    news_rows = [r for r in rows if r.phase.upper() == "Q10_NEWS"]
    m["findings"]["q10_news_lane"] = dict(Counter(
        (r.verdict or r.status.upper()) for r in news_rows).most_common())
    rr_terminal = []
    for (ea, sym), rec in pairs.items():
        head = rec["head"]
        if head is None or head.phase.upper() != "Q10_NEWS":
            continue
        if head.verdict.upper() != "REVIEW_REQUIRED":
            continue
        rr_terminal.append((ea, sym, head))
    m["findings"]["q10_news_review_required_terminal"] = {
        "rows": len(rr_terminal),
        "pairs": len({(e, s) for e, s, _h in rr_terminal}),
        "eas": len({e for e, _s, _h in rr_terminal}),
        "list": sorted(f"{e}/{s}" for e, s, _h in rr_terminal),
    }

    # ---- stranded Q02 sweep ------------------------------------------------
    stranded = [r for r in rows
                if r.phase.upper() in ("Q02", "P2")
                and r.status.lower() == "pending"
                and r.updated_at and r.updated_at[:10] < STALE_PENDING_CUTOFF]
    tags = Counter()
    for r in stranded:
        for tag in ("claude_sweep_enqueue_2026-06-10.stranded",
                    "stranded_infra_fail", "record_build_result.auto_q02",
                    "sweep_enqueue.deferred_promotion"):
            if tag in (r.payload or ""):
                tags[tag] += 1
    m["findings"]["stranded_q02_sweep"] = {
        "rows": len(stranded),
        "eas": len({r.ea_id for r in stranded}),
        "symbols": dict(Counter(r.symbol for r in stranded).most_common(4)),
        "stamped_2026_07_26": sum(1 for r in stranded if r.updated_at[:10] == "2026-07-26"),
        "tags": dict(tags),
        "with_active_hold": sum(1 for r in stranded if r.id in holds),
    }
    pending_all = [r for r in rows if r.status.lower() == "pending"]
    m["findings"]["pending_inventory"] = {
        "rows": len(pending_all),
        "opt_census": sum(1 for r in pending_all if r.phase.upper() == "OPT_CENSUS"),
    }

    _tick("detectors_d1")
    # ---- T2: rb-universe-expansion setfile-path defect ----------------------
    t2 = []
    for r in rows:
        if r.verdict.upper() != "INVALID":
            continue
        if "setfile_missing" not in (r.payload or ""):
            continue
        m2 = DEAD_WORKTREE_RE.match(r.setfile_path or "")
        if not m2:
            continue
        canon, exists = canonical_setfile_for(r.setfile_path, canonical_root)
        t2.append((r, m2.group(1), canon, exists))
    sm_all = [r for r in rows if "setfile_missing" in (r.payload or "")]
    m["findings"]["setfile_missing_class"] = {
        "rows": len(sm_all), "eas": len({r.ea_id for r in sm_all})}
    m["findings"]["t2_dead_worktree"] = {
        "rows": len(t2),
        "eas": len({r.ea_id for r, _w, _c, _e in t2}),
        "worktrees": dict(Counter(w for _r, w, _c, _e in t2)),
        "canonical_setfile_present": sum(1 for _r, _w, _c, e in t2 if e),
        "evidence_path_present": sum(1 for r, _w, _c, _e in t2 if path_exists(r.evidence_path)),
        "setfile_path_present": sum(1 for r, _w, _c, _e in t2 if path_exists(r.setfile_path)),
    }
    m["findings"]["dead_worktree_dirs_exist"] = {
        w: os.path.isdir(f"C:/QM/worktrees/{w}")
        for w in sorted({w for _r, w, _c, _e in t2})
    }

    # ---- zero-trade deep FAIL (5.7a) ---------------------------------------
    zt = []
    for (ea, sym), rec in pairs.items():
        for r in rec["chain"]:
            if not r.verdict.upper().startswith("FAIL"):
                continue
            if GATE_RANK.get(r.gate, -1) < GATE_RANK["Q05"]:
                continue
            mm = metric_for_row(metrics.get((ea, sym)), r.id)
            if mm and (mm.get("trades") == 0) and (mm.get("profit_factor") in (0, 0.0)):
                zt.append((ea, sym, r))
    m["findings"]["zero_trade_deep_fail"] = {
        "rows": len(zt),
        "by_gate": dict(Counter(r.gate for _e, _s, r in zt).most_common()),
        "still_terminal": sorted(
            f"{e}/{s}" for e, s, r in zt if pairs[(e, s)]["head"].id == r.id),
    }

    # ---- Q08.5 neighbourhood blocker (defect #4) ---------------------------
    NEEDLE = ("q08_8.5_neighborhood:neighborhood_evidence_lineage_invalid:"
              "baseline_setfile_defect:empty_strategy_params")
    q085 = [r for r in rows if NEEDLE in (r.payload or "")]
    m["findings"]["q08_5_empty_strategy_params"] = {
        "needle": NEEDLE,
        "rows": len(q085),
        "eas": len({r.ea_id for r in q085}),
        "by_verdict": dict(Counter(r.verdict for r in q085).most_common()),
        "by_date": dict(Counter(r.updated_at[:10] for r in q085).most_common()),
        "detail": sorted(
            f"{r.ea_id}/{r.symbol} {r.phase} {r.verdict} {r.updated_at[:10]}"
            for r in q085),
        "ea_ids": sorted({r.ea_id for r in q085}),
    }

    _tick("detectors_t2_zt_q085")
    # ---- Q08.5 baseline setfile spot-check (report S5.7b) ------------------
    spot = {}
    for ea in sorted({r.ea_id for r in q085}):
        ea_dirs = sorted((canonical_root / "framework" / "EAs").glob(f"{ea}_*"))
        if not ea_dirs:
            spot[ea] = {"ea_dir": "", "declared_mq5_inputs": None, "setfile_params": None}
            continue
        d = ea_dirs[0]
        mq5 = sorted(d.glob("*.mq5"))
        declared = None
        if mq5:
            try:
                txt = mq5[0].read_text(encoding="utf-8", errors="replace")
                declared = len(re.findall(r"^\s*(?:input|sinput)\s+\S+\s+(strategy_\w+)",
                                          txt, re.MULTILINE))
            except OSError:
                declared = None
        sets = sorted((d / "sets").glob("*.set")) if (d / "sets").is_dir() else []
        setp = count_strategy_params(str(sets[0])) if sets else None
        spot[ea] = {
            "ea_dir": str(d),
            "mq5": str(mq5[0]) if mq5 else "",
            "declared_mq5_strategy_inputs": declared,
            "example_setfile": str(sets[0]) if sets else "",
            "setfile_strategy_params": setp,
            "defect_unrepaired": bool(declared and setp == 0),
        }
    m["findings"]["q08_5_empty_strategy_params"]["setfile_spot_check"] = spot

    # ---- DL-071 fall-through (report S1 / S5.8) ----------------------------
    # Population is defined on work_items (the verdict of record), joined to
    # ea_metrics.detail_json for the fold arithmetic.  The arithmetic is the
    # runner's own, imported from framework/scripts/q04_walkforward.py:676-736
    # with its constants at :53-61 and the plausibility guard
    # pf_measurement_issue() at :111.  A null / no-trade fold counts as pf_net 0.0
    # (q04_walkforward.py:687-688,727).
    dl071 = []
    pop = 0
    pop_fail_only = 0
    with_folds = 0
    for wid, ea, sym, phase, verdict, detail, ev in fold_rows:
        pop += 1
        if (verdict or "").upper() == "FAIL":
            pop_fail_only += 1
        if not detail:
            continue
        try:
            d = json.loads(detail)
        except (ValueError, TypeError):
            continue
        raw = d.get("folds")
        if not isinstance(raw, list) or len(raw) < 3:
            continue
        folds = [(x.get("pf_net"), x.get("trades")) for x in raw if isinstance(x, dict)]
        if len(folds) < 3:
            continue
        with_folds += 1
        pfs = [float(pf) if pf is not None else 0.0 for pf, _t in folds]
        n = len(pfs)
        n_pos = sum(1 for pf in pfs if pf > PF_NET_FLOOR_PER_FOLD)
        mean_pf = sum(pfs) / n
        min_pf = min(pfs)
        need_pos = math.ceil(Q04_SOFT_MIN_POS_FRACTION * n)
        if not (n_pos >= need_pos and mean_pf > Q04_SOFT_MEAN_FLOOR
                and min_pf >= Q04_SOFT_MIN_FOLD_FLOOR):
            continue
        guards = [g for g in (pf_measurement_issue(pf, int(t or 0)) for pf, t in folds)
                  if g]
        dl071.append({
            "work_item_id": wid, "ea_id": ea, "symbol": sym, "phase": phase,
            "verdict": verdict, "fold_pf_net": pfs,
            "fold_trades": [t for _pf, t in folds],
            "n_pos": n_pos, "need_pos": need_pos,
            "mean": round(mean_pf, 4), "min": min_pf,
            "plausibility_guard": guards,
            "survives_guard": not guards,
            "evidence_path": ev or "",
            "evidence_present": path_exists(ev or ""),
        })
    m["findings"]["dl071_fallthrough"] = {
        "criterion": (f"n_pos >= ceil({Q04_SOFT_MIN_POS_FRACTION:.6f}*n) and "
                      f"mean > {Q04_SOFT_MEAN_FLOOR} and min >= "
                      f"{Q04_SOFT_MIN_FOLD_FLOOR}; per-fold floor "
                      f"{PF_NET_FLOOR_PER_FOLD}; a null / no-trade fold counts as 0.0"),
        "source": ("framework/scripts/q04_walkforward.py:676-736 "
                   "(constants :53-61, guard :111-139)"),
        "population_sql": ("work_items w LEFT JOIN ea_metrics m ON m.work_item_id=w.id "
                           "WHERE w.phase IN ('Q04','P2','P3.5') "
                           "AND w.verdict IN ('FAIL','INVALID')"),
        "population_rows": pop,
        "population_rows_fail_only": pop_fail_only,
        "rows_with_ge3_folds": with_folds,
        "hits_bare_arithmetic": len(dl071),
        "hits_surviving_plausibility_guard": sum(1 for h in dl071 if h["survives_guard"]),
        "hits": dl071,
    }

    # ---- disposition era: the month of a pair's LAST word (report S5.2) -----
    disp = defaultdict(lambda: {"pairs": 0, "eas": set(), "cls": Counter()})
    for (ea, sym), rec in pairs.items():
        head = rec["head"]
        if head is None or head.status.lower() in ("pending", "active", "claimed"):
            continue
        era = era_of(head.updated_at)
        if era is None:
            continue
        d = disp[era]
        d["pairs"] += 1
        d["eas"].add(ea)
        d["cls"][head.cls] += 1
    m["findings"]["disposition_era"] = {
        era: {
            "pairs": d["pairs"], "eas": len(d["eas"]),
            "by_class": dict(d["cls"].most_common()),
            "non_economic": sum(v for k, v in d["cls"].items()
                                if k in ("INFRA", "INVALID", "STALE", "NA", "OTHER")),
        }
        for era, d in sorted(disp.items(), key=lambda kv: ERAS.index(kv[0]))
    }
    june_days = Counter()
    for (ea, sym), rec in pairs.items():
        head = rec["head"]
        if head is None or head.status.lower() in ("pending", "active", "claimed"):
            continue
        if era_of(head.updated_at) != "JUNE":
            continue
        if head.cls in ("INFRA", "INVALID", "STALE", "NA", "OTHER"):
            june_days[head.updated_at[:10]] += 1
    m["findings"]["june_non_economic_kill_days"] = dict(june_days.most_common(10))

    # ---- never-seeded builds (report S5.8) ---------------------------------
    compile_only = []
    for ea, rec in eas.items():
        if rec["pairs"]:
            continue
        cr = [r for r in rec["all_rows"] if r.phase.upper() == "COMPILE_EA"]
        if cr and len(cr) == rec["n_work_items"]:
            compile_only.append((ea, max(cr, key=lambda r: r.updated_at)))
    m["findings"]["never_seeded_builds"] = {
        "eas": len(compile_only),
        "by_head_verdict": dict(Counter(r.verdict or "PENDING"
                                        for _e, r in compile_only).most_common()),
        "compile_ok_all_on_or_after_2026_08_20": all(
            r.updated_at[:10] >= "2026-08-20"
            for _e, r in compile_only if r.verdict.upper() == "COMPILE_OK"),
        "compile_ok_earliest": min(
            [r.updated_at[:10] for _e, r in compile_only
             if r.verdict.upper() == "COMPILE_OK"] or [""]),
    }

    # ---- T2 per-EA breakdown (report S5.4) ---------------------------------
    t2_by_ea: dict[str, dict] = {}
    for r, wt, canon, exists in t2:
        d = t2_by_ea.setdefault(r.ea_id, {"rows": 0, "still_terminal": 0,
                                          "canonical_present": 0, "params": None,
                                          "example_canonical_setfile": ""})
        d["rows"] += 1
        if pairs[(r.ea_id, r.symbol)]["head"].id == r.id:
            d["still_terminal"] += 1
        if exists:
            d["canonical_present"] += 1
            if not d["example_canonical_setfile"]:
                d["example_canonical_setfile"] = canon
                d["params"] = count_strategy_params(canon)
    m["findings"]["t2_by_ea"] = dict(sorted(t2_by_ea.items()))

    # ---- OWNER dispositions (report S5.5) ----------------------------------
    owner_rows = Counter()
    owner_pairs: dict[str, set] = defaultdict(set)
    for r in rows:
        did = owner_decision_of(r.payload)
        if did:
            owner_rows[did] += 1
            if r.ea_id and r.symbol:
                owner_pairs[did].add((r.ea_id, r.symbol))
    m["findings"]["owner_dispositions"] = {
        "rule": "non-null work_items.payload_json['owner_decision_id']",
        "rows_total": sum(owner_rows.values()),
        "by_decision_rows": dict(owner_rows.most_common()),
        "by_decision_pairs": {k: len(v) for k, v in
                              sorted(owner_pairs.items(), key=lambda kv: -len(kv[1]))},
        "legacy_cohort_retire6_pairs": sorted(
            f"{e}/{s}" for e, s in
            owner_pairs.get("OWNER-DEC-LEGACY-COHORT-DISPO-20260830", set())),
    }

    # ---- poison pill -------------------------------------------------------
    m["findings"]["poison_pill"] = {
        "rows": len(quarantine),
        "active": sum(1 for q in quarantine if q[3]),
        "successes_ever_nonzero": sum(1 for q in quarantine if (q[6] or 0) > 0),
        "by_reason": dict(Counter(q[4] for q in quarantine if q[3]).most_common()),
        "by_date": dict(Counter((q[7] or "")[:10] for q in quarantine if q[3]).most_common()),
    }

    _tick("dl071")
    # ---- gate-axis divergence ---------------------------------------------
    div = Counter()
    keys = Counter((r.phase, str(r.gcv or "")) for r in rows)
    for (phase, gcv), n in keys.items():
        cg = canonical_gate(phase, gcv)
        sg = storage_gate(phase)
        if cg != sg:
            div[f"{phase}[{gcv}] storage={sg} canonical={cg}"] += n
    m["gate_axis_divergence"] = dict(div.most_common())

    _tick("gate_axis_divergence")
    # ---- candidates --------------------------------------------------------
    cand_rows = build_candidates(pairs, eas, metrics, card_eras, canonical_root, m)
    m["findings"]["candidates"] = {
        "rows": len(cand_rows),
        "by_class": dict(Counter(c["class"] for c in cand_rows).most_common()),
        "evidence_present_true": sum(1 for c in cand_rows if c["evidence_present"] == "True"),
        "canonical_setfile_present_true": sum(
            1 for c in cand_rows if c["canonical_setfile_present"] == "True"),
    }

    _tick("candidates")
    if args.out_dir:
        out = Path(args.out_dir)
        out.mkdir(parents=True, exist_ok=True)
        write_csv(out / "2026-09-03_treasure_hunt_eras_inventory.csv", inv_rows, [
            "ea_id", "era", "slug", "first_lifecycle_date", "n_work_items", "n_pairs",
            "deepest_pass", "head_phase", "head_verdict", "head_status", "head_date",
            "superseded_any", "portfolio_states"])
        write_csv(out / "2026-09-03_treasure_hunt_eras_candidates.csv", cand_rows, [
            "class", "ea_id", "symbol", "formation_eras", "disposition_date",
            "standing_gate", "standing_verdict", "pf", "trades", "dd_pct", "net_profit",
            "evidence_path", "evidence_present", "canonical_setfile_path",
            "canonical_setfile_present", "open_successor_phase", "open_successor_status",
            "open_successor_updated_at", "later_activity_at_or_below_gate",
            "blocker", "disposition", "owner_disposition"])
    return m


def build_candidates(pairs, eas, metrics, card_eras, canonical_root, m) -> list[dict]:
    out: list[dict] = []
    seen: set[tuple[str, str]] = set()
    ea_best_cache: dict[str, dict] = {}

    def eras_of(ea):
        es = sorted(card_eras.get(ea, set()), key=lambda x: ERAS.index(x) if x in ERAS else 99)
        return "+".join(es) if es else "UNATTRIBUTED"

    def base(cls, ea, sym, rec, standing: Row | None):
        mm = metric_for_row(metrics.get((ea, sym)), standing.id) if standing else None
        if mm is None:
            mm = metric_best(metrics.get((ea, sym))) if metrics.get((ea, sym)) else {}
        ev = (standing.evidence_path if standing else "") or ""
        canon, canon_ok = canonical_setfile_for(
            (standing.setfile_path if standing else "") or "", canonical_root)
        succ = successor_rows(rec, standing) if standing else []
        osucc = open_successor(succ)
        later = later_activity_rows(rec, standing) if standing else []
        later_open = [r for r in later
                      if r.status.lower() in ("pending", "active", "claimed")]
        return {
            "class": cls, "ea_id": ea, "symbol": sym,
            "formation_eras": eras_of(ea),
            "disposition_date": (rec["head"].updated_at[:10] if rec["head"] else ""),
            "standing_gate": standing.gate if standing else "",
            "standing_verdict": standing.verdict if standing else "",
            "pf": mm.get("profit_factor", mm.get("pf")) if mm else "",
            "trades": mm.get("trades") if mm else "",
            "dd_pct": mm.get("drawdown_pct", mm.get("dd_pct")) if mm else "",
            "net_profit": mm.get("net_profit") if mm else "",
            "evidence_path": ev,
            # defect #3 fix: this column now answers exactly one question --
            # does the path in this row exist on disk right now?
            "evidence_present": str(path_exists(ev)),
            "canonical_setfile_path": canon,
            "canonical_setfile_present": str(canon_ok),
            "open_successor_phase": osucc.phase if osucc else "",
            "open_successor_status": osucc.status if osucc else "",
            "open_successor_updated_at": osucc.updated_at if osucc else "",
            "later_activity_at_or_below_gate": (
                f"{later_open[0].phase} {later_open[0].status} "
                f"{later_open[0].updated_at}" if later_open
                else (f"{max(later, key=lambda r: r.updated_at).phase} "
                      f"{max(later, key=lambda r: r.updated_at).verdict or 'done'} "
                      f"{max(later, key=lambda r: r.updated_at).updated_at}")
                if later else ""),
            "blocker": "", "disposition": "",
            "owner_disposition": ";".join(rec["owner_decisions"]),
        }

    # T1 -- standing deep PASS, split by whether a successor gate is already seeded.
    for (ea, sym), rec in pairs.items():
        dp = rec["deepest_pass"]
        if dp is None or GATE_RANK.get(dp.gate, -1) < GATE_RANK["Q09"]:
            continue
        succ = successor_rows(rec, dp)
        state = frontier_state(dp, succ)
        osucc = open_successor(succ)
        nxt = next_gate_after(dp.gate)
        row = base(f"T1_STANDING_DEEP_PASS_{state}", ea, sym, rec, dp)
        if state == "SUCCESSOR_PENDING":
            row["blocker"] = (f"successor already seeded and open: {osucc.phase} "
                              f"{osucc.status} {osucc.updated_at}")
            row["disposition"] = "LEAVE (in flight -- a re-seed would be a duplicate)"
        elif state == "SUCCESSOR_TERMINAL_AFTER_PASS":
            latest = max(succ, key=lambda r: r.updated_at)
            row["blocker"] = (f"next gate already answered: {latest.phase} "
                              f"{latest.verdict or latest.status} {latest.updated_at}")
            row["disposition"] = ("LEAVE (OWNER disposition on the pair)"
                                  if rec["owner_tagged"] else "LEAVE (gate answered)")
        elif state == "SUCCESSOR_TERMINAL_BEFORE_PASS":
            latest = max(succ, key=lambda r: r.updated_at)
            row["blocker"] = (f"every successor is closed and older than the standing "
                              f"{dp.gate} PASS ({dp.updated_at}); latest successor "
                              f"{latest.phase} {latest.verdict or latest.status} "
                              f"{latest.updated_at}")
            row["disposition"] = ("LEAVE (OWNER disposition on the pair)"
                                  if rec["owner_tagged"]
                                  else f"REQUALIFY (re-seed {nxt or 'the next gate'})")
        else:
            la = later_activity_rows(rec, dp)
            la_open = [r for r in la
                       if r.status.lower() in ("pending", "active", "claimed")]
            row["blocker"] = (f"no row at any gate after {dp.gate} exists for this pair "
                              f"(next gate would be {nxt or 'n/a'})"
                              + (f"; but the pair is being reworked at "
                                 f"{la_open[0].phase} ({la_open[0].status}, "
                                 f"{la_open[0].updated_at})" if la_open else ""))
            row["disposition"] = ("LEAVE (OWNER disposition on the pair)"
                                  if rec["owner_tagged"]
                                  else f"REQUALIFY (seed {nxt or 'the next gate'})")
        out.append(row)
        seen.add((ea, sym))

    # T2 -- INVALID setfile_missing bound to a removed ticket worktree.
    for (ea, sym), rec in pairs.items():
        head = rec["head"]
        if head is None or head.verdict.upper() != "INVALID":
            continue
        if "setfile_missing" not in (head.payload or ""):
            continue
        if not DEAD_WORKTREE_RE.match(head.setfile_path or ""):
            continue
        row = base("T2_SETFILE_PATH_PROVENANCE_FALSE_INVALID", ea, sym, rec, head)
        wt = DEAD_WORKTREE_RE.match(head.setfile_path).group(1)
        row["blocker"] = (f"row bound to setfile in removed worktree C:/QM/worktrees/{wt}/ "
                          f"(dir exists: {os.path.isdir('C:/QM/worktrees/' + wt)})")
        row["disposition"] = ("REQUALIFY (append-only Q02 rerun against the canonical setfile)"
                              if row["canonical_setfile_present"] == "True"
                              else "REBUILD (canonical setfile absent -- regenerate first)")
        out.append(row)
        seen.add((ea, sym))

    # T3 -- non-economic terminal disposition with gross edge on the EA.
    for (ea, sym), rec in pairs.items():
        head = rec["head"]
        if head is None or head.cls not in ("INFRA", "INVALID", "STALE"):
            continue
        if head.status.lower() in ("pending", "active", "claimed"):
            continue
        if (ea, sym) in seen:
            continue
        best = metric_best(metrics.get((ea, sym)) or [])
        ea_best = ea_best_cache.get(ea)
        if ea_best is None:
            ea_best = ea_best_cache[ea] = metric_best(
                [mm for s, _p in eas[ea]["pairs"] for mm in (metrics.get((ea, s)) or [])])
        pf = ea_best.get("pf")
        tr = int(ea_best.get("trades") or 0)
        # D3 as specified on 2026-07-03: gross edge means PF >= 1.2 over >= 20 trades.
        # The trade floor is not decoration -- without it the list ranks by
        # denominator artefacts (PF 7.67 on 3 trades) instead of by edge.
        if pf is None or pf < D3_MIN_PF or tr < D3_MIN_TRADES:
            continue
        if rec["in_flight"]:
            continue
        row = base(f"T3_FROZEN_NONECONOMIC_{head.cls}", ea, sym, rec, head)
        row["pf"] = best.get("pf") if best.get("pf") is not None else ea_best.get("pf")
        row["trades"] = (best.get("trades") if best.get("pf") is not None
                         else ea_best.get("trades"))
        row["blocker"] = (f"terminal {head.verdict or head.status} at {head.phase} "
                          f"on {head.updated_at[:10]}; EA best plausible PF {pf} "
                          f"over {ea_best.get('trades')} trades")
        row["disposition"] = ("LEAVE (OWNER disposition on the pair)"
                              if rec["owner_tagged"] else "REQUALIFY (append-only rerun)")
        out.append(row)
        seen.add((ea, sym))

    out.sort(key=lambda c: (c["class"], -(float(c["pf"]) if c["pf"] not in ("", None) else 0.0),
                            c["ea_id"], c["symbol"]))
    return out


def write_csv(path: Path, rows: list[dict], fields: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", default=DEFAULT_DB)
    ap.add_argument("--repo-root", default=str(_REPO_ROOT),
                    help="checkout used for card scanning and git history")
    ap.add_argument("--canonical-repo-root", default="C:/QM/repo",
                    help="repo an operator would act on; T2 setfile paths resolve here")
    ap.add_argument("--out-dir", default="")
    ap.add_argument("--metrics-json", default="")
    ap.add_argument("--gate-axis", default="storage", choices=("storage", "canonical"))
    args = ap.parse_args(argv)
    m = run(args)
    text = json.dumps(m, indent=2, sort_keys=False, default=str)
    if args.metrics_json:
        Path(args.metrics_json).write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
