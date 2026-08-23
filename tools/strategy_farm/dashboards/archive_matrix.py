"""Strategy Archive: the card x gate x symbol matrix and the per-card evidence sections.

Authority: ``docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md`` v1.0 (OWNER decisions
F1-F8, 2026-08-23).

The point of the matrix is not to show successes but **gaps**: the governed planner's
``FILL_MISSING`` / ``RERUN_INFRA`` / ``REBIND_STALE`` action at the earliest prerequisite.
Card-frontmatter targets that never ran are shown as a separately labelled second source.

Read-only. No write path, no action elements, no verdict interpretation beyond the
existing ``work_items_clean`` taxonomy.

Consumed by ``render_dashboards.py``:
  * :func:`render_matrix_page`      -> ``strategy_archive.html``
  * :func:`render_card_section`     -> the Strategy section of ``ea_<id>.html``
  * :func:`render_backtests_section`-> the complete run table of ``ea_<id>.html``
"""
from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from dataclasses import dataclass
from functools import lru_cache
from itertools import groupby
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

import gate_manifest  # noqa: E402
import operator_surfaces  # noqa: E402
import rebaseline_census  # noqa: E402
from phase_ids import advancement_table, phase_label, phase_qid  # noqa: E402
from work_item_clean_view import open_clean_view_connection  # noqa: E402
from card_heading_language import normalise_heading  # noqa: E402

FARM_ROOT = Path("D:/QM/strategy_farm")
DB = FARM_ROOT / "state" / "farm_state.sqlite"
CARD_BUCKETS = ("cards_approved", "cards_review", "cards_draft", "cards_rejected",
                "cards_recovery", "cards_blocked_r3_data")
REPORT_ROOTS = ("D:/QM/reports/work_items", "D:/QM/reports/pipeline")
BACKFILL_PLAN = Path("D:/QM/reports/rebaseline/backfill_plan_2026-08-23.csv")


@dataclass(frozen=True)
class ArchiveColumn:
    gate_id: str
    name: str
    band_id: str
    band_name: str
    css_class: str
    owner_manual: bool


def build_archive_columns(
    manifest: gate_manifest.GateManifest | None = None,
) -> list[ArchiveColumn]:
    """Build the Q02+ archive topology from the shared manifest surface model."""

    active = manifest or gate_manifest.load_gate_manifest()
    gates = {gate.id: gate for gate in active.gates}
    bands = operator_surfaces.macro_phase_bands(active)
    columns: list[ArchiveColumn] = []
    for band_index, band in enumerate(bands):
        owner_manual = band_index == len(bands) - 1
        band_name = str(band["name"])
        if owner_manual:
            band_name = f"{band_name} · Buch/Betrieb (OWNER)"
        for row in band["gates"]:
            gate_id = str(row["gate_id"])
            gate = gates.get(gate_id)
            # F8 begins at the third top-level gate. Display-only evidence stages
            # (v3 Q10A) are deliberately excluded from the matrix columns.
            if gate is None or gate.ordinal < 2:
                continue
            columns.append(ArchiveColumn(
                gate_id=gate_id,
                name=gate.name,
                band_id=str(band["id"]),
                band_name=band_name,
                css_class=f"m{band_index + 1}",
                owner_manual=owner_manual,
            ))
    return columns


ST_PASS, ST_SOFT, ST_FAIL, ST_VOID, ST_OPEN, ST_HOLE, ST_NONE, ST_CARD_HOLE = range(8)
ST_CLASS = {ST_PASS: "p", ST_SOFT: "s", ST_FAIL: "f", ST_VOID: "v",
            ST_OPEN: "o", ST_HOLE: "h", ST_NONE: "", ST_CARD_HOLE: "ct"}
ST_NAME = {ST_PASS: "PASS", ST_SOFT: "PASS (conditional)", ST_FAIL: "FAIL",
           ST_VOID: "VOID", ST_OPEN: "running/queued", ST_HOLE: "GAP", ST_NONE: "-",
           ST_CARD_HOLE: "nie getestet (Card-Ziel)"}

FM_KEYS = [
    ("period", "Timeframe"), ("target_symbols", "Target symbols"),
    ("expected_trades_per_year_per_symbol", "Expected trades / year / symbol"),
    ("expected_pf", "Expected profit factor"), ("expected_dd_pct", "Expected max DD %"),
    ("risk_class", "Risk class"), ("primary_archetype", "Archetype"),
    ("g0_status", "G0 status"), ("status", "Card status"),
    ("r1_track_record", "R1 source"), ("r2_mechanical", "R2 mechanical"),
    ("r3_data_available", "R3 data"), ("r4_ml_forbidden", "R4 no-ML"),
    ("last_updated", "Card updated"),
]


def e(s) -> str:
    return html.escape(str(s), quote=True)


def fmt(n: int) -> str:
    return f"{n:,}"


def symbol_class(symbol: str) -> str:
    """tradable / basket / relic.

    OWNER 2026-08-23: symbols without ``.DWX`` are relics and do not belong on the
    surfaces. Measured, that was only 9 bare tickers (228 rows, deleted 2026-08-23 after
    an explicit go); the other ~1,000 non-.DWX rows are **logical basket symbols** and
    empty-symbol basket hosts, which are current work and stay.
    """
    if symbol.endswith(".DWX"):
        return "dwx"
    if symbol.startswith("TBD_"):
        return "relic"
    if symbol == "BASKET" or "_" in symbol:
        return "basket"
    return "relic"


@lru_cache(maxsize=256)
def resolved_gate(phase: str | None, contract_version: str | None) -> str | None:
    """Resolve a stored token into the active manifest's top-level gate."""

    resolved = phase_qid(phase, contract_version)
    table = advancement_table()
    row = next((item for key, item in table.items() if key.upper() == resolved.upper()), None)
    return row.canonical_phase if row is not None else resolved or None


def state_of(taxonomy: str, verdict: str) -> int:
    if taxonomy == "open":
        return ST_OPEN
    verdict_class = rebaseline_census.vclass(verdict)
    if verdict_class == "PASS":
        if verdict in ("PASS_SOFT", "PASS_LOWFREQ"):
            return ST_SOFT
        return ST_PASS
    if verdict_class == "ECON_FAIL":
        return ST_FAIL
    if verdict_class in ("INFRA", "INVALID", "STALE", "NA"):
        return ST_VOID
    # governance / review / draft_defect / measurement / unknown carry no economic
    # judgement and are not an open run either.
    return ST_VOID


# ── strategy cards ────────────────────────────────────────────────────────────

def find_card(ea: str) -> tuple[Path | None, str]:
    for bucket in CARD_BUCKETS:
        d = FARM_ROOT / "artifacts" / bucket
        if not d.is_dir():
            continue
        for path in d.glob(f"{ea}_*.md"):
            return path, bucket
    return None, ""


def split_frontmatter(text: str) -> tuple[dict[str, str], str]:
    """Scalar keys and inline lists only — the raw card is rendered underneath, so a
    parser shortcut can never silently drop content."""
    if not text.startswith("---"):
        return {}, text
    end = text.find("\n---", 3)
    if end < 0:
        return {}, text
    head, body = text[3:end], text[end + 4:]
    fm: dict[str, str] = {}
    for line in head.split(chr(10)):
        if not line or line[0] in " \t-#" or ":" not in line:
            continue
        k, _, v = line.partition(":")
        v = v.strip().strip('"').strip("'")
        if v:
            fm[k.strip()] = v
    return fm, body


_MD_INLINE = [(re.compile(r"`([^`]+)`"), r"<code>\1</code>"),
              (re.compile(r"\*\*([^*]+)\*\*"), r"<strong>\1</strong>")]


def md_inline(s: str) -> str:
    out = e(s)
    for pat, rep in _MD_INLINE:
        out = pat.sub(rep, out)
    return out


def md_to_html(md: str, base_level: int = 3) -> str:
    """A small, predictable Markdown subset: headings, lists, tables, code, rules.

    Hard-wrapped source lines are joined into one paragraph — rendering each source line
    as its own ``<p>`` makes a card unreadable.
    """
    lines = md.split("\n")
    out: list[str] = []
    i = 0
    in_code = False
    list_tag = None

    def close_list():
        nonlocal list_tag
        if list_tag:
            out.append(f"</{list_tag}>")
            list_tag = None

    while i < len(lines):
        ln = lines[i].rstrip()
        if ln.startswith("```"):
            close_list()
            out.append("</pre>" if in_code else "<pre>")
            in_code = not in_code
            i += 1
            continue
        if in_code:
            out.append(e(ln))
            i += 1
            continue
        if not ln.strip():
            close_list()
            i += 1
            continue
        if (ln.startswith("|") and i + 1 < len(lines)
                and set(lines[i + 1].replace("|", "").strip()) <= set("-: ")):
            close_list()
            head = [c.strip() for c in ln.strip("|").split("|")]
            out.append("<table><thead><tr>"
                       + "".join(f"<th>{md_inline(normalise_heading(c))}</th>" for c in head)
                       + "</tr></thead><tbody>")
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip("|").split("|")]
                out.append("<tr>" + "".join(f"<td>{md_inline(c)}</td>" for c in cells) + "</tr>")
                i += 1
            out.append("</tbody></table>")
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", ln)
        if m:
            close_list()
            lvl = min(len(m.group(1)) + base_level - 1, 6)
            out.append(f"<h{lvl}>{md_inline(normalise_heading(m.group(2)))}</h{lvl}>")
            i += 1
            continue
        m_ul = re.match(r"^\s*[-*]\s+", ln)
        m_ol = re.match(r"^\s*\d+[.)]\s+", ln)
        if m_ul or m_ol:
            want = "ul" if m_ul else "ol"
            if list_tag != want:
                close_list()
                out.append(f"<{want}>")
                list_tag = want
            first = re.sub(r"^\s*(?:[-*]|\d+[.)])\s+", "", ln)
            item = [first.strip()]
            i += 1
            # A hard-wrapped item continues on the following lines. Treating those as
            # separate paragraphs is what tore bullets apart and restarted <ol> at 1.
            while i < len(lines):
                nxt = lines[i].rstrip()
                if not nxt.strip():
                    break
                if (re.match(r"^\s*(?:[-*]|\d+[.)])\s+", nxt)
                        or nxt.startswith(("#", "|", "```"))
                        or (set(nxt.strip()) <= set("-") and len(nxt.strip()) >= 3)):
                    break
                item.append(nxt.strip())
                i += 1
            out.append("<li>" + md_inline(" ".join(item)) + "</li>")
            continue
        if set(ln.strip()) <= set("-") and len(ln.strip()) >= 3:
            close_list()
            out.append("<hr>")
            i += 1
            continue
        close_list()
        para = [ln.strip()]
        i += 1
        while i < len(lines):
            nxt = lines[i].rstrip()
            if not nxt.strip():
                break
            if (nxt.startswith(("#", "|", "```", "- ", "* "))
                    or re.match(r"^\s*\d+[.)]\s+", nxt)
                    or (set(nxt.strip()) <= set("-") and len(nxt.strip()) >= 3)):
                break
            para.append(nxt.strip())
            i += 1
        out.append(f"<p>{md_inline(' '.join(para))}</p>")
    close_list()
    if in_code:
        out.append("</pre>")
    return "\n".join(out)


# ── native MT5 reports ────────────────────────────────────────────────────────

_UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
_REPORT_INDEX: dict[str, list[str]] | None = None


def build_report_index(force: bool = False) -> dict[str, list[str]]:
    """work_item_id -> native MetaTrader 5 report files still on disk.

    ONE filesystem walk, cached for the process — a glob per work item would cost
    minutes. Coverage is never assumed: DL-090 governs what survives, and a run whose
    artifact was purged simply does not appear here.
    """
    global _REPORT_INDEX
    if _REPORT_INDEX is not None and not force:
        return _REPORT_INDEX
    idx: dict[str, list[str]] = {}
    for base in REPORT_ROOTS:
        if not os.path.isdir(base):
            continue
        for root, _dirs, files in os.walk(base):
            hits = [f for f in files
                    if f.lower().endswith((".htm", ".html", ".htm.gz", ".html.gz"))]
            if not hits:
                continue
            wid = None
            for seg in root.replace("\\", "/").split("/"):
                mm = _UUID_RE.search(seg)
                if mm:
                    wid = mm.group(0)
                    break
            if wid:
                idx.setdefault(wid, []).extend(os.path.join(root, f) for f in hits)
    _REPORT_INDEX = idx
    return idx


def reports_for(work_item_id: str) -> list[str]:
    return build_report_index().get(work_item_id, [])


# ── data collection ───────────────────────────────────────────────────────────

def collect(db: Path = DB) -> dict:
    """Collect manifest-resolved cells plus shared census/planner frontiers."""
    t0 = time.perf_counter()
    columns = build_archive_columns()
    column_index = {column.gate_id: index for index, column in enumerate(columns)}
    column_ids = set(column_index)
    conn = open_clean_view_connection(db)

    latest: dict[tuple[str, str, str], dict] = {}
    economic_latest: dict[tuple[str, str, str], dict] = {}
    all_items: dict[str, list[dict]] = defaultdict(list)
    held: set[str] = set()
    pair_for_work_item: dict[str, tuple[str, str]] = {}
    skipped_phase: Counter = Counter()
    dropped_relic: Counter = Counter()
    rows_seen = 0

    for wid, ea, sym, phase, verdict, tax, upd, evidence, contract_version in conn.execute(
        "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at, "
        "evidence_path, gate_contract_version FROM work_items_clean"
    ):
        rows_seen += 1
        if not ea:
            continue
        symbol = (sym or "").strip() or "BASKET"
        if symbol_class(symbol) == "relic":
            dropped_relic[symbol] += 1
            continue
        v = (verdict or "").upper()
        display = phase_label(phase, contract_version, include_name=True)
        all_items[ea].append({"id": wid, "symbol": symbol, "phase": phase, "verdict": v,
                              "tax": tax or "unknown", "upd": upd or "",
                              "evidence": evidence or "", "contract_version": contract_version,
                              "phase_label": display})
        pair_for_work_item[wid] = (ea, symbol)
        gate = resolved_gate(phase, contract_version)
        if gate not in column_ids:
            skipped_phase[gate or "non-gate"] += 1
            continue
        key = (ea, symbol, gate)
        item = {"upd": upd or "", "verdict": v, "tax": tax or "unknown", "id": wid,
                "phase_label": display, "gate": gate}
        cur = latest.get(key)
        if cur is None or (item["upd"], wid) > (cur["upd"], cur["id"]):
            latest[key] = item
        if v in rebaseline_census.ECON_FAIL:
            cur_fail = economic_latest.get(key)
            if cur_fail is None or (item["upd"], wid) > (cur_fail["upd"], cur_fail["id"]):
                economic_latest[key] = item

    tables = {row[0] for row in conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    )}
    if "work_item_holds" in tables:
        for (wid,) in conn.execute("SELECT work_item_id FROM work_item_holds WHERE active = 1"):
            held.add(wid)
    conn.close()
    held_pairs = {pair_for_work_item[wid] for wid in held if wid in pair_for_work_item}

    plan_path = BACKFILL_PLAN if Path(db).resolve() == DB.resolve() else None
    frontiers = {
        (str(row["ea_id"]), str(row["symbol"]).strip()): row
        for row in operator_surfaces.build_pair_frontier_rows(
            db, backfill_plan_path=plan_path
        )
    }

    slugs: dict[str, str] = {}
    ea_dir = REPO_ROOT / "framework" / "EAs"
    if ea_dir.is_dir():
        for d in os.scandir(ea_dir):
            if d.is_dir() and d.name.startswith("QM5_"):
                parts = d.name.split("_", 2)
                if len(parts) == 3:
                    slugs[f"{parts[0]}_{parts[1]}"] = parts[2]

    card_meta = _card_metadata()
    targets = card_meta["targets"]
    universes = card_meta["universes"]
    buckets = card_meta["buckets"]

    by_card: dict[str, dict[str, dict[str, dict]]] = defaultdict(lambda: defaultdict(dict))
    for (ea, symbol, gate), val in latest.items():
        by_card[ea][symbol][gate] = val

    cards: list[dict] = []
    stats: Counter = Counter()
    hole_by_gate: Counter = Counter()
    action_counts: Counter = Counter()
    untested_targets = 0

    for ea, sym_map in by_card.items():
        synthetic_targets: set[str] = set()
        for tsym in targets.get(ea, []):
            if tsym not in sym_map:
                sym_map[tsym] = {}
                synthetic_targets.add(tsym)
                untested_targets += 1
        symbols = sorted(sym_map)
        cells: dict[str, list[dict]] = {}
        empty_reasons: dict[str, list[dict]] = {}
        n_pass = n_fail = n_void = n_open = n_hole = n_card_hole = 0
        hp_idx = -1
        last_upd = ""

        for si, symbol in enumerate(symbols):
            gates = sym_map[symbol]
            frontier = frontiers.get((ea, symbol), {})
            action = str(frontier.get("backfill_action") or "")
            action_reason = str(frontier.get("backfill_action_reason") or "")
            target_gate = str(frontier.get("earliest_missing_prerequisite") or "")
            rendered: dict[str, dict] = {}

            # Draw the latest stored evidence at every manifest gate first.
            for column in columns:
                token = column.gate_id
                cell = gates.get(token)
                if cell is None:
                    continue
                st = (ST_OPEN if cell["id"] in held and cell["tax"] == "open"
                      else state_of(cell["tax"], cell["verdict"]))
                rendered[token] = _cell(si, st, symbol, cell)
                last_upd = max(last_upd, cell["upd"])

            # Work-item gap semantics are exactly the governed planner actions.
            # Infra/stale rows become actionable gap chips; economic stops remain FAIL.
            if target_gate in column_ids and action in {
                "FILL_MISSING", "RERUN_INFRA", "REBIND_STALE"
            }:
                source = gates.get(target_gate)
                rendered[target_gate] = _cell(
                    si, ST_HOLE, symbol, source,
                    gate=target_gate, action=action, action_reason=action_reason,
                )
                action_counts[action] += 1
                hole_by_gate[target_gate] += 1
            elif target_gate in column_ids and action == "STOP_ECONOMIC_FAIL":
                source = economic_latest.get((ea, symbol, target_gate)) or gates.get(target_gate)
                rendered[target_gate] = _cell(
                    si, ST_FAIL, symbol, source,
                    gate=target_gate, action=action, action_reason=action_reason,
                )
            elif target_gate in column_ids and action == "STOP_NOT_APPLICABLE":
                rendered.pop(target_gate, None)

            # Card-frontmatter targets are explicitly a second source, never
            # represented as planner work.
            if symbol in synthetic_targets:
                first_gate = columns[0].gate_id
                rendered[first_gate] = _cell(
                    si, ST_CARD_HOLE, symbol, None, gate=first_gate,
                    action="CARD_TARGET_UNTESTED",
                    action_reason="nie getestet (Card-Ziel)",
                )

            contiguous = str(frontier.get("highest_contiguous_valid_gate") or "")
            hp_idx = max(hp_idx, column_index.get(contiguous, -1))
            universe = set(universes.get(ea, []))
            bucket = buckets.get(ea, "")

            for column in columns:
                token = column.gate_id
                cell = rendered.get(token)
                if cell is not None:
                    cells.setdefault(token, []).append(cell)
                    st = cell["state"]
                    stats[st] += 1
                    if st in (ST_PASS, ST_SOFT):
                        n_pass += 1
                    elif st == ST_FAIL:
                        n_fail += 1
                    elif st == ST_VOID:
                        n_void += 1
                    elif st == ST_OPEN:
                        n_open += 1
                    elif st == ST_HOLE:
                        n_hole += 1
                    elif st == ST_CARD_HOLE:
                        n_card_hole += 1
                    continue

                reason = _empty_reason(
                    column=column, symbol=symbol, synthetic=symbol in synthetic_targets,
                    universe=universe, bucket=bucket, held=(ea, symbol) in held_pairs,
                    action=action, target_gate=target_gate,
                )
                empty_reasons.setdefault(token, []).append({"symbol_index": si, "reason": reason})

        cards.append({"ea": ea, "slug": slugs.get(ea, ""), "symbols": symbols,
                      "cells": cells, "empty_reasons": empty_reasons,
                      "hp": hp_idx, "pass": n_pass, "fail": n_fail,
                      "void": n_void, "open": n_open, "hole": n_hole,
                      "card_hole": n_card_hole, "upd": last_upd})

    # F6/T4: highest contiguous-valid frontier first, gaps as the tiebreak.
    cards.sort(key=lambda c: (-c["hp"], -c["hole"], c["ea"]))
    return {"cards": cards, "columns": columns, "stats": stats,
            "hole_by_gate": hole_by_gate, "action_counts": action_counts,
            "all_items": all_items, "slugs": slugs, "cells": len(latest),
            "rows_seen": rows_seen, "skipped_phase": skipped_phase,
            "dropped_relic": dropped_relic, "untested_targets": untested_targets,
            "held_items": len(held),
            "cards_with_targets": len(targets),
            "collect_s": round(time.perf_counter() - t0, 2)}


def _cell(
    symbol_index: int,
    state: int,
    symbol: str,
    item: dict | None,
    *,
    gate: str | None = None,
    action: str = "",
    action_reason: str = "",
) -> dict:
    resolved = gate or str((item or {}).get("gate") or "")
    phase_display = str((item or {}).get("phase_label") or phase_label(
        resolved, include_name=True
    ))
    verdict = str((item or {}).get("verdict") or "NO_ROW")
    updated = str((item or {}).get("upd") or "-")
    work_item_id = str((item or {}).get("id") or "-")
    parts = [
        symbol, phase_display, ST_NAME[state],
        f"verdict={verdict}", f"date={updated[:10] if updated != '-' else '-'}",
        f"work_item_id={work_item_id}",
    ]
    if action:
        parts.append(f"action={action}")
    if action_reason:
        parts.append(action_reason)
    return {"symbol_index": symbol_index, "state": state, "title": " · ".join(parts),
            "action": action, "gate": resolved}


def _empty_reason(
    *, column: ArchiveColumn, symbol: str, synthetic: bool, universe: set[str],
    bucket: str, held: bool, action: str, target_gate: str,
) -> str:
    if column.owner_manual:
        return "Buch/Betrieb (OWNER): manual gate; no reachable-gap chip"
    if synthetic:
        return "nie getestet (Card-Ziel): no work_items row"
    if bucket in {"cards_rejected", "cards_blocked_r3_data"}:
        return f"card bucket {bucket}: no automatic work planned"
    if action == "STOP_ECONOMIC_FAIL":
        return f"stopped after economic FAIL at {target_gate}; no backfill"
    if action == "STOP_NOT_APPLICABLE":
        return "not applicable under the planner contract"
    if held:
        return "active work-item hold: no automatic gap"
    if universe and symbol not in universe:
        return "outside the card target universe"
    if action:
        return f"planner action {action} at {target_gate or 'none'}; no action at this gate"
    return "no run; no planner action due at this gate"


def _card_metadata() -> dict[str, dict[str, list[str]] | dict[str, str]]:
    """Card targets/buckets, with approved targets kept as the second gap source.

    SECOND SOURCE, deliberately kept separate and labelled as such on the page: the
    matrix itself stands on work_items alone (F8). This only adds the "target symbol
    that never ran at all" gap.
    """
    targets: dict[str, list[str]] = {}
    universes: dict[str, list[str]] = {}
    buckets: dict[str, str] = {}
    pat = re.compile(r"^target_symbols:\s*\[([^\]]*)\]", re.M)
    for bucket in CARD_BUCKETS:
        directory = FARM_ROOT / "artifacts" / bucket
        if not directory.is_dir():
            continue
        for path in directory.glob("QM5_*.md"):
            parts = path.name.split("_", 2)
            if len(parts) < 3:
                continue
            ea = f"{parts[0]}_{parts[1]}"
            buckets.setdefault(ea, bucket)
            try:
                head = path.read_text(encoding="utf-8", errors="replace")[:4000]
            except OSError:
                continue
            match = pat.search(head)
            if not match:
                continue
            syms = [s.strip().strip('"\'') for s in match.group(1).split(",") if s.strip()]
            syms = [s for s in syms if symbol_class(s) != "relic"]
            if syms:
                universes[ea] = syms
                if bucket == "cards_approved":
                    targets[ea] = syms
    return {"targets": targets, "universes": universes, "buckets": buckets}


_REASON_KEYS = ("verdict_reason", "invalidated_reason", "reason", "failure_class",
                "prior_failure", "promotion_reason")


def _reason_of(payload_json: str | None) -> str:
    """The first durable human-readable reason a run carries.

    Without this a cell like ``QM5_13213 | XAUUSD.DWX`` shows a bare ``RETIRE`` and reads
    as unexplained, when the payload in fact records an OWNER-approved exclusion with its
    evidence path. An unexplained terminal verdict is what makes people re-run a
    documented negative.
    """
    if not payload_json:
        return ""
    try:
        d = json.loads(payload_json)
    except (ValueError, TypeError):
        return ""
    if not isinstance(d, dict):
        return ""
    for key in _REASON_KEYS:
        v = d.get(key)
        if isinstance(v, str) and v.strip():
            return v.strip()
    disp = d.get("mnt009_legacy_disposition")
    if isinstance(disp, dict):
        cat = disp.get("category")
        if isinstance(cat, str) and cat:
            return f"disposition: {cat}"
    return ""


_RUNS_BY_DB: dict[str, dict[str, list[dict]]] = {}


def runs_for_ea(ea_id: str, db: Path = DB) -> list[dict]:
    """Every stored run of one EA, newest first.

    Loaded once for the whole process in a single pass — ``render_dashboards`` calls this
    for ~3,000 EAs, and a query (plus TEMP-view install) per EA would dominate the render.
    Relic symbols are excluded here exactly as they are in the matrix.
    """
    cache_key = str(Path(db).resolve())
    if cache_key not in _RUNS_BY_DB:
        acc: dict[str, list[dict]] = defaultdict(list)
        conn = open_clean_view_connection(db)
        for (wid, ea, sym, phase, verdict, tax, upd, evidence, payload,
             contract_version) in conn.execute(
            "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at, "
            "evidence_path, payload_json, gate_contract_version FROM work_items_clean "
            "WHERE ea_id IS NOT NULL"
        ):
            symbol = (sym or "").strip() or "BASKET"
            if symbol_class(symbol) == "relic":
                continue
            acc[ea].append({"id": wid, "symbol": symbol, "phase": phase or "",
                            "verdict": (verdict or "").upper(), "tax": tax or "unknown",
                            "upd": upd or "", "evidence": evidence or "",
                            "reason": _reason_of(payload),
                            "contract_version": contract_version,
                            "phase_label": phase_label(
                                phase, contract_version, include_name=True
                            )})
        conn.close()
        for v in acc.values():
            v.sort(key=lambda r: r["upd"], reverse=True)
        _RUNS_BY_DB[cache_key] = acc
    return _RUNS_BY_DB[cache_key].get(ea_id, [])


# ── sections embedded into ea_<id>.html ───────────────────────────────────────

CARD_SECTION_CSS = """
/* ── strategy card ─────────────────────────────────────────────────── */
.sc{border:1px solid var(--border);background:var(--surface-1);margin-bottom:26px}
.sc-head{padding:16px 22px 14px;border-bottom:1px solid var(--border)}
.sc-kicker{font-family:var(--font-mono);font-size:9.5px;font-weight:700;color:var(--text-4);
text-transform:uppercase;letter-spacing:.22em;margin-bottom:9px;display:flex;gap:10px;
align-items:center;flex-wrap:wrap}
.sc-bucket{border:1px solid var(--border-2);padding:1px 7px;letter-spacing:.1em;
color:var(--text-3)}
.sc-bucket.warn{border-color:var(--warn);color:var(--warn)}
.sc-title{font-size:17px;line-height:1.35;font-weight:600;color:var(--text);
letter-spacing:-.01em;max-width:80ch}
.sc-lede{margin-top:8px;font-size:12.5px;line-height:1.6;color:var(--text-3);max-width:88ch}

.sc-chips{display:flex;flex-wrap:wrap;gap:5px;margin-top:12px;align-items:center}
.sc-chips+.sc-chips{margin-top:7px}
.sc-chiplabel{font-family:var(--font-mono);font-size:9px;letter-spacing:.16em;
text-transform:uppercase;color:var(--text-4);margin-right:3px;min-width:74px}
.chip{font-family:var(--font-mono);font-size:10.5px;letter-spacing:.04em;padding:2px 8px;
border:1px solid var(--border-2);color:var(--text-2);white-space:nowrap}
.chip.sym{border-color:var(--signal-dim);color:var(--signal-bright)}
.chip.tf{border-color:var(--border-3);color:var(--text)}
.chip.flag{border-style:dashed;color:var(--text-3)}
.chip.r{padding-left:6px}
.chip.r b{font-weight:500;color:var(--text-4);margin-right:5px}
.chip.r.pass{border-color:var(--pass)}
.chip.r.pass span{color:var(--pass)}
.chip.r.fail{border-color:var(--fail)}
.chip.r.fail span{color:var(--fail)}
.chip.r.other span{color:var(--text-3)}

.sc-stats{display:flex;flex-wrap:wrap;gap:0;border-top:1px solid var(--border);
border-bottom:1px solid var(--border);background:var(--surface-2)}
.sc-stat{padding:9px 18px 8px;border-right:1px solid var(--border);min-width:132px;flex:1 1 auto}
.sc-stat:last-child{border-right:0}
.sc-stat b{display:block;font-size:9.5px;text-transform:uppercase;letter-spacing:.11em;
color:var(--text-4);font-weight:500;margin-bottom:3px}
.sc-stat span{font-family:var(--font-mono);font-size:14px;color:var(--text)}
.sc-stat span.txt{font-family:inherit;font-size:12.5px;color:var(--text-2)}

.sc-src{padding:11px 22px;border-bottom:1px solid var(--border);color:var(--text-3);
font-size:11.5px;line-height:1.6;background:var(--surface-2)}
.sc-src b{color:var(--text-4);font-weight:500;text-transform:uppercase;font-size:9.5px;
letter-spacing:.12em;display:block;margin-bottom:3px}
.sc-src a{color:var(--signal)}

.sc-body{padding:18px 22px 22px;font-size:13px;line-height:1.72;color:var(--text-2)}
/* prose stays readable at a measure; the clause grid gets the whole width */
.sc-body>p,.sc-body>ul,.sc-body>ol,.sc-body>table{max-width:82ch}
.sc-body h3{font-size:13px;color:var(--text);margin:22px 0 8px;padding-left:10px;
border-left:2px solid var(--signal-dim);text-transform:uppercase;letter-spacing:.1em;
font-weight:600}
.sc-body h3:first-child{margin-top:0}
.sc-body h4{font-size:12px;color:var(--text-2);margin:16px 0 5px;font-weight:600;
letter-spacing:.03em}
.sc-body h5{font-size:11.5px;color:var(--text-3);margin:12px 0 4px;font-weight:600}
.sc-body p{margin:0 0 10px}
.sc-body ul,.sc-body ol{margin:0 0 11px 18px;padding:0}
.sc-body li{margin:0 0 5px}
.sc-body li::marker{color:var(--text-4)}
.sc-body code{background:var(--surface-2);padding:1px 4px;font-size:11.5px;
color:var(--text)}
.sc-body pre{background:var(--surface-2);border-left:2px solid var(--border-2);
padding:10px 12px;overflow-x:auto;font-size:11px;color:var(--text-3)}
.sc-body hr{border:0;border-top:1px solid var(--border);margin:16px 0}
.sc-body table{border-collapse:collapse;width:100%;font-size:11.5px;margin:9px 0}
.sc-body th{text-align:left;color:var(--text-4);font-weight:500;font-size:9.5px;
text-transform:uppercase;letter-spacing:.09em;border-bottom:1px solid var(--border-2);
padding:5px 8px}
.sc-body td{border-bottom:1px solid var(--border);padding:4px 8px;vertical-align:top}
.sc-body tr:hover td{background:var(--surface-2)}
.sc-body details{border:1px solid var(--border);margin:12px 0;background:var(--surface-2)}
.sc-body details>summary{cursor:pointer;padding:8px 12px;font-size:11.5px;
color:var(--text-3);list-style:none;user-select:none}
.sc-body details>summary::-webkit-details-marker{display:none}
.sc-body details>summary::before{content:"+ ";color:var(--text-4);font-family:var(--font-mono)}
.sc-body details[open]>summary::before{content:"- "}
.sc-body details[open]>summary{border-bottom:1px solid var(--border);color:var(--text-2)}
.sc-body details>div{padding:12px 14px 2px}
.sc-body details h3{margin-top:0}
.sc-none{padding:18px 22px;color:var(--text-4);font-size:12px}

/* the edge thesis is the one paragraph that says WHY the strategy should work —
   it gets the weight of a lead, not the weight of a bullet */
.thesis{border-left:2px solid var(--signal);background:var(--surface-2);
padding:14px 18px;margin:0 0 6px;font-size:13.5px;line-height:1.75;color:var(--text-2);
max-width:86ch}
.thesis p:last-child{margin-bottom:0}
.thesis strong{color:var(--text)}

/* mechanization rules read as a set of parallel clauses, not a scroll */
.rules-intro{margin:0 0 12px;color:var(--text-3);font-size:12px}
/* multi-column flow, not a grid: grid rows align to the tallest cell, which opened a
   void whenever a short clause sat beside a long one */
.rules-grid{columns:3 300px;column-gap:14px;margin:2px 0 16px}
@media(max-width:1100px){.rules-grid{columns:2 300px}}
@media(max-width:720px){.rules-grid{columns:1}}
.rule{break-inside:avoid;-webkit-column-break-inside:avoid;page-break-inside:avoid;
background:var(--surface-2);border:1px solid var(--border);padding:12px 15px 13px;
margin:0 0 14px;min-width:0}
.rule-h{font-family:var(--font-mono);font-size:9.5px;font-weight:700;letter-spacing:.13em;
text-transform:uppercase;color:var(--signal-bright);margin-bottom:9px;
padding-bottom:7px;border-bottom:1px solid var(--border-2)}
.rule-note{display:block;margin-top:3px;font-weight:400;letter-spacing:.04em;
text-transform:none;color:var(--text-4);font-size:9.5px;line-height:1.4}
.rule ul,.rule ol{margin:0 0 0 16px;padding:0}
.rule li{margin:0 0 6px;font-size:12.5px;line-height:1.6}
.rule li:last-child{margin-bottom:0}
.rule p{margin:0 0 7px;font-size:12.5px;line-height:1.6}
.rule p:last-child{margin-bottom:0}
.rule code{font-size:11px}
@media(max-width:760px){.rules-grid{grid-template-columns:1fr}}

/* ── all backtests table ───────────────────────────────────────────── */
.bt-wrap{margin:26px 0}
.bt-note{border-left:3px solid var(--warn);background:rgba(184,114,10,.06);padding:8px 12px;
color:var(--text-3);font-size:11.5px;line-height:1.55;margin-bottom:10px}
.bt-table{border-collapse:collapse;width:100%;font-size:11.5px}
.bt-table th{text-align:left;color:var(--text-3);font-weight:500;padding:5px 8px;
border-bottom:1px solid var(--border-2);white-space:nowrap}
.bt-table td{border-bottom:1px solid var(--border);padding:3px 8px;vertical-align:top}
.bt-table tr:hover td{background:var(--surface-1)}
.bt-v{font-family:var(--font-mono);font-size:10.5px;white-space:nowrap}
.bt-v.p{color:var(--pass)}.bt-v.f{color:var(--fail)}.bt-v.v{color:var(--warn)}
.bt-v.o{color:var(--dead)}.bt-v.g{color:var(--text-4)}
.bt-gone{color:var(--text-4)}
.bt-reason{color:var(--text-3);font-size:11px;line-height:1.45;max-width:420px}
"""

# Sections that are reference material rather than the strategy itself. They stay on the
# page — nothing is dropped — but collapsed, so the mechanism is what the eye lands on.
COLLAPSE_HEADINGS = (
    "source", "related strategies", "pipeline history", "gaps", "gap register",
    "documented deviations", "documented deviations from source",
    "unverified claims", "r1-r4 assessment", "concepts", "indicators",
    "cost & compliance notes", "cost and compliance notes",
)

_LIST_KEYS = ("concepts", "indicators", "strategy_type_flags", "target_symbols",
              "timeframes", "markets", "sources")


def _block_lists(head: str) -> dict[str, list[str]]:
    """YAML block lists (``key:`` then ``  - value`` lines) that the scalar reader skips.

    ``concepts`` and ``indicators`` are present on 599 of 600 sampled cards and were simply
    not being shown.
    """
    out: dict[str, list[str]] = {}
    key = None
    for line in head.split(chr(10)):
        if re.match(r"^[a-z0-9_]+:\s*$", line):
            key = line.split(":")[0]
            out[key] = []
            continue
        m = re.match(r"^\s+-\s+(.*)$", line)
        if m and key:
            val = m.group(1).strip().strip('"').strip("'")
            val = re.sub(r"^\[\[|\]\]$", "", val)
            if "/" in val:
                val = val.split("/")[-1]
            if val:
                out[key].append(val)
            continue
        if line and not line[0].isspace():
            key = None
    return {k: v for k, v in out.items() if v}


def _inline_list(value: str) -> list[str]:
    return [x.strip().strip('"').strip("'") for x in
            value.strip().lstrip("[").rstrip("]").split(",") if x.strip()]


_R_KEYS = (("r1_track_record", "R1 source"), ("r2_mechanical", "R2 mechanical"),
           ("r3_data_available", "R3 data"), ("r4_ml_forbidden", "R4 no-ML"))
_STATS = (("expected_trades_per_year_per_symbol", "Trades / year / symbol", False),
          ("expected_pf", "Expected PF", False), ("expected_dd_pct", "Expected max DD %", False),
          ("risk_class", "Risk class", True), ("period", "Timeframe", True),
          ("pipeline_phase", "Card phase", True))


# Card sections whose body is a set of bold-labelled clauses ("**Entry:**" and a list)
# rather than prose. Those become a grid — read side by side, they are comparable;
# stacked, they are a scroll.
GRID_SECTIONS = ("rules", "mechanics", "mechanization", "execution", "trade management")
THESIS_SECTIONS = ("edge thesis", "thesis", "edge", "rationale")

_LABEL_P = re.compile(r"<p><strong>(.*?)</strong>\s*:?\s*</p>", re.S)
_SUBHEAD = re.compile(r"<h[45]>(.*?)</h[45]>", re.S)


def _gridify(chunk: str) -> str:
    """Split a bold-labelled section into rule cards. Falls back to the original
    markup when there is nothing to split — a prose section must not be forced into
    a grid it cannot fill."""
    parts = _LABEL_P.split(chunk)
    if len(parts) < 3:
        # most cards structure their mechanism with sub-headings rather than bold
        # labels — same shape, different markup.
        parts = _SUBHEAD.split(chunk)
        if len(parts) < 3:
            return chunk
    intro = parts[0].strip()
    cards = []
    for i in range(1, len(parts) - 1, 2):
        label = re.sub(r"<.*?>", "", parts[i]).strip().rstrip(":")
        content = parts[i + 1].strip()
        if not content:
            continue
        # a long parenthetical in the label wrecks a small-caps header — demote it
        main, _, note = normalise_heading(html.unescape(label)).partition(" (")
        note_html = (f'<span class="rule-note">{e(note.rstrip(")"))}</span>'
                     if note else "")
        cards.append(f'<div class="rule"><div class="rule-h">{e(main)}{note_html}</div>'
                     f'{content}</div>')
    if len(cards) < 2:
        return chunk
    out = f'<div class="rules-intro">{intro}</div>' if intro else ""
    return out + f'<div class="rules-grid">{"".join(cards)}</div>'


def _style_sections(doc: str) -> str:
    """Give each card section the shape its content actually has."""
    parts = re.split(r"(<h3>.*?</h3>)", doc)
    out = [parts[0]] if parts else []
    i = 1
    while i < len(parts):
        head, chunk = parts[i], parts[i + 1] if i + 1 < len(parts) else ""
        title = html.unescape(re.sub(r"<.*?>", "", head)).strip().lower()
        if any(t in title for t in THESIS_SECTIONS):
            out.append(head + f'<div class="thesis">{chunk}</div>')
        elif any(t in title for t in GRID_SECTIONS):
            out.append(head + _gridify(chunk))
        else:
            out.append(head + chunk)
        i += 2
    return "".join(out)


def _collapse_reference_sections(doc: str) -> str:
    """Wrap reference sections in <details> without dropping a single line."""
    parts = re.split(r"(<h3>.*?</h3>)", doc)
    out = [parts[0]] if parts else []
    i = 1
    while i < len(parts):
        head, chunk = parts[i], parts[i + 1] if i + 1 < len(parts) else ""
        title = re.sub(r"<.*?>", "", head).strip().lower().replace("&amp;", "&")
        if any(title.startswith(c) for c in COLLAPSE_HEADINGS):
            # the heading text is already HTML-escaped; unescape before re-escaping
            label = html.unescape(re.sub(r"<.*?>", "", head).strip())
            # the header already carries the citation, so a bare "Source" summary
            # right underneath reads as a duplicate rather than as the detail it is
            if label.strip().lower() == "source":
                label = "Source detail & citations"
            out.append(f"<details><summary>{e(label)}</summary><div>{chunk}</div></details>")
        else:
            out.append(head + chunk)
        i += 2
    return "".join(out)


def render_card_section(ea_id: str) -> str:
    """The strategy card as a readable document: identity, universe, expectations,
    provenance, mechanism. Reference material is collapsed, never removed."""
    path, bucket = find_card(ea_id)
    if not path:
        return ('<div class="sc"><div class="sc-head"><div class="sc-kicker">Strategy</div>'
                '</div><div class="sc-none">No strategy card on disk for this EA id. '
                'The pipeline evidence below is unaffected.</div></div>')
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return ('<div class="sc"><div class="sc-head"><div class="sc-kicker">Strategy</div>'
                f'</div><div class="sc-none">Card unreadable: {e(exc)}</div></div>')

    fm, body = split_frontmatter(raw)
    head_raw = raw[3:raw.find(chr(10) + "---", 3)] if raw.startswith("---") else ""
    lists = _block_lists(head_raw)

    # title: the card's own H1, else the slug
    m = re.search(r"^#\s+(.*)$", body, re.M)
    title = m.group(1).strip() if m else (fm.get("slug") or ea_id)
    if m:
        body = body[:m.start()] + body[m.end():]

    incomplete = fm.get("card_body_incomplete") or fm.get("card_body_missing")
    bucket_cls = "sc-bucket warn" if bucket != "cards_approved" else "sc-bucket"
    kicker = (f'<span>Strategy card</span><span class="{bucket_cls}">{e(bucket)}</span>'
              + (f'<span class="sc-bucket warn">body {e(incomplete)}</span>' if incomplete else ""))

    # Three labelled rows instead of one undifferentiated run of twenty chips:
    # what it trades, what kind of thing it is, and whether it cleared G0.
    syms = (_inline_list(fm["target_symbols"]) if fm.get("target_symbols")
            else lists.get("target_symbols", []))
    row_universe = [f'<span class="chip sym">{e(x)}</span>' for x in syms[:14]]
    for tf in ([fm["period"]] if fm.get("period") else []) + lists.get("timeframes", [])[:3]:
        row_universe.append(f'<span class="chip tf">{e(tf)}</span>')

    row_kind = []
    for flag in (_inline_list(fm["strategy_type_flags"]) if fm.get("strategy_type_flags")
                 else lists.get("strategy_type_flags", []))[:8]:
        row_kind.append(f'<span class="chip flag">{e(flag)}</span>')
    for kind in ("concepts", "indicators"):
        for val in lists.get(kind, [])[:8]:
            row_kind.append(f'<span class="chip">{e(val)}</span>')

    row_g0 = []
    for key, label in _R_KEYS:
        val = (fm.get(key) or "").strip()
        if not val:
            continue
        cls = ("pass" if val.upper() == "PASS"
               else "fail" if val.upper().startswith("FAIL") else "other")
        why = fm.get(key.split("_")[0] + "_reasoning") or ""
        row_g0.append(f'<span class="chip r {cls}" title="{e(why[:300])}">'
                      f'<b>{e(label)}</b><span>{e(val)}</span></span>')

    chip_rows = "".join(
        f'<div class="sc-chips"><span class="sc-chiplabel">{lbl}</span>{"".join(row)}</div>'
        for lbl, row in (("Universe", row_universe), ("Character", row_kind),
                         ("G0 checks", row_g0)) if row)

    stats = []
    for key, label, is_text in _STATS:
        if not fm.get(key):
            continue
        cls = ' class="txt"' if is_text else ""
        stats.append(f'<div class="sc-stat"><b>{e(label)}</b><span{cls}>{e(fm[key])}</span></div>')

    lede = fm.get("expected_trade_frequency") or fm.get("g0_approval_reasoning") or ""
    src = ""
    if fm.get("source_citation"):
        cite = md_inline(fm["source_citation"])
        cite = re.sub(r"(https?://[^\s,;)\]]+)", r'<a href="\1">\1</a>', cite)
        src = f'<div class="sc-src"><b>Source</b>{cite}</div>'

    # base_level 2: the card title was lifted into the header, so its "##" sections
    # become h3 and carry the accent rule; sub-sections drop to h4/h5.
    body_html = _collapse_reference_sections(
        _style_sections(md_to_html(body, base_level=2)))

    return (f'<div class="sc"><div class="sc-head"><div class="sc-kicker">{kicker}</div>'
            f'<div class="sc-title">{e(title)}</div>'
            + (f'<div class="sc-lede">{md_inline(lede[:400])}</div>' if lede else "")
            + chip_rows
            + "</div>"
            + (f'<div class="sc-stats">{"".join(stats)}</div>' if stats else "")
            + src
            + f'<div class="sc-body">{body_html}</div></div>')


def _vclass(verdict: str, tax: str) -> str:
    if tax == "open":
        return "o"
    if tax in ("infra", "invalid"):
        return "v"
    if verdict.startswith("PASS"):
        return "p"
    return "f" if tax == "strategy" else "g"


def render_backtests_section(items: list[dict]) -> str:
    """Every stored run, newest first, with a link to the native MT5 report."""
    if not items:
        return ""
    rows = []
    have = 0
    for it in sorted(items, key=lambda r: r.get("upd") or "", reverse=True):
        rl = reports_for(it["id"])
        if rl:
            have += 1
            links = " ".join(
                f'<a href="file:///{e(p.replace(chr(92), "/"))}">report {n + 1}'
                f'{" (gzip)" if p.lower().endswith(".gz") else ""}</a>'
                for n, p in enumerate(rl[:4]))
        else:
            links = '<span class="bt-gone">report purged</span>'
        ev = it.get("evidence") or ""
        ev_link = (f'<a href="file:///{e(ev.replace(chr(92), "/"))}">evidence</a>'
                   if ev and os.path.exists(ev) else "")
        gate_display = it.get("phase_label") or phase_label(
            it.get("phase"), it.get("contract_version"), include_name=True
        )
        rows.append(
            f'<tr><td class="bt-v">{e((it.get("upd") or "")[:16].replace("T", " "))}</td>'
            f'<td class="bt-v">{e(gate_display)}</td>'
            f'<td class="bt-v">{e(it.get("symbol") or "")}</td>'
            f'<td><span class="bt-v {_vclass(it.get("verdict") or "", it.get("tax") or "")}">'
            f'{e(it.get("verdict") or "-")}</span></td>'
            f'<td class="bt-v" style="color:var(--text-4)">{e(it.get("tax") or "")}</td>'
            f'<td>{links} {ev_link}</td>'
            f'<td class="bt-v" style="color:var(--text-4)">{e(it["id"][:8])}</td>'
            f'<td class="bt-reason">{e((it.get("reason") or "")[:220])}</td></tr>')
    return (f'<div class="bt-wrap"><h2 class="acc-title">All backtests · {fmt(len(items))} '
            f'stored runs, {fmt(have)} with a native MT5 report</h2>'
            '<div class="bt-note">Every stored run for this EA, newest first — superseded '
            'attempts and voided runs included. A native MetaTrader 5 report is linked where '
            'the file still exists; retention is governed by DL-090, and a purged run says so '
            'instead of linking into nothing.</div>'
            '<table class="bt-table"><thead><tr><th>updated (UTC)</th><th>gate</th>'
            '<th>symbol</th><th>verdict</th><th>taxonomy</th><th>artifacts</th>'
            '<th>work item</th><th>reason</th></tr></thead>'
            f'<tbody>{"".join(rows)}</tbody></table></div>')


# ── the matrix page ───────────────────────────────────────────────────────────

MATRIX_CSS = """
:root{--bg:#0c0f16;--s1:#151a23;--s2:#1c2330;--s3:#27303f;--tx:#e8ebf0;--tx2:#b6bdc8;
--tx3:#868e9c;--tx4:#5b6472;--bd:#222a37;--bd2:#313a49;--pass:#30be69;--fail:#f05a5e;
--void:#e19a24;--open:#6b7280;--hole:#84a2ff;--m1:#3455a8;--m2:#a86a20;--m3:#6b4ba8}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--tx);
font:13px/1.5 "Inter",-apple-system,Segoe UI,system-ui,sans-serif}
code,.mono{font-family:"JetBrains Mono",ui-monospace,Consolas,monospace}
header{padding:18px 22px 12px;border-bottom:1px solid var(--bd);background:var(--s1)}
h1{margin:0 0 4px;font-size:17px;font-weight:600;letter-spacing:-.01em}
.sub{color:var(--tx3);font-size:11.5px}
.sub a{color:var(--hole)}
.warn{margin:10px 22px 0;padding:9px 12px;border-left:3px solid var(--void);
background:rgba(225,154,36,.07);color:var(--tx2);font-size:11.5px;line-height:1.55}
.legend{display:flex;flex-wrap:wrap;gap:14px;padding:11px 22px;border-bottom:1px solid var(--bd);
background:var(--s1);font-size:11.5px;color:var(--tx2);align-items:center}
.legend b{color:var(--tx);font-weight:500}
.controls{display:flex;flex-wrap:wrap;gap:9px;padding:11px 22px;border-bottom:1px solid var(--bd);
align-items:center;background:var(--s1);position:sticky;top:0;z-index:5}
input,select{background:var(--s2);border:1px solid var(--bd2);color:var(--tx);
padding:5px 8px;font-size:12px;border-radius:0;font-family:inherit}
input:focus,select:focus{outline:1px solid var(--hole);border-color:var(--hole)}
.cnt{color:var(--tx3);font-size:11.5px;margin-left:auto}
.cnt strong{color:var(--tx)}
.wrap{overflow:auto;max-height:calc(100vh - 215px)}
table{border-collapse:collapse;width:100%;font-size:12px}
thead th{position:sticky;background:var(--s2);z-index:3;font-weight:500;color:var(--tx2);
border-bottom:1px solid var(--bd2);text-align:left;white-space:nowrap}
thead tr.g th{top:0;font-size:10px;letter-spacing:.08em;text-transform:uppercase;
padding:5px 8px;color:#fff;text-align:center}
thead tr.g th.m1{background:var(--m1)}
thead tr.g th.m2{background:var(--m2)}
thead tr.g th.m3{background:var(--m3)}
thead tr.g th.blank{background:var(--s2)}
thead tr.h th{top:24px;padding:6px 8px;cursor:pointer;user-select:none}
thead tr.h th:hover{color:var(--tx);background:var(--s3)}
thead tr.h th small{display:block;font-size:9px;color:var(--tx4);font-weight:400}
thead tr.h th.m1{border-bottom:2px solid var(--m1)}
thead tr.h th.m2{border-bottom:2px solid var(--m2)}
thead tr.h th.m3{border-bottom:2px solid var(--m3)}
tbody td{border-bottom:1px solid var(--bd);padding:3px 8px;vertical-align:middle}
tbody tr:hover{background:var(--s1)}
tr.card{cursor:pointer}
tr.card td.id{white-space:nowrap}
tr.card td.id b{font-family:"JetBrains Mono",monospace;font-weight:500;font-size:11.5px}
tr.card td.id span{color:var(--tx4);margin-left:7px;font-size:11px}
tr.card td.n{color:var(--tx3);text-align:right;font-family:"JetBrains Mono",monospace;
font-size:11px;white-space:nowrap}
tr.pair{background:#10141c}
tr.pair td{padding:2px 8px;border-bottom:1px solid #171d27}
tr.pair td.id{padding-left:26px;color:var(--tx3);font-size:11px;
font-family:"JetBrains Mono",monospace}
td.c{padding:3px 4px;min-width:26px}
.strip{display:flex;gap:2px;flex-wrap:wrap}
i{display:block;width:9px;height:9px;flex:0 0 auto}
i.p{background:var(--pass)}
i.s{background:transparent;border:1.5px solid var(--pass)}
i.f{background:var(--fail)}
i.v{background:repeating-linear-gradient(45deg,var(--void) 0 2px,transparent 2px 4px);
outline:1px solid var(--void)}
i.o{background:transparent;border:1.5px solid var(--open)}
i.h{background:var(--hole);box-shadow:0 0 0 2px rgba(132,162,255,.30);position:relative}
i.h::after{content:"";position:absolute;inset:3px;background:var(--bg)}
i.ct{background:transparent;border:1.5px dashed var(--hole);transform:rotate(45deg)}
.lg i{display:inline-block;vertical-align:-1px;margin-right:5px}
footer{padding:14px 22px 30px;color:var(--tx4);font-size:11px;line-height:1.7;
border-top:1px solid var(--bd)}
footer b{color:var(--tx3);font-weight:500}
.hidden{display:none}
a.lnk{color:var(--hole);text-decoration:none}
a.lnk:hover{text-decoration:underline}
"""

MATRIX_JS = """
(function(){
var tb=document.getElementById('tb'),rows=[],pairs={};
var MDL=JSON.parse(document.getElementById('mdl').textContent);
var SYM=JSON.parse(document.getElementById('syms').textContent);
var RSN=JSON.parse(document.getElementById('rsn').textContent);
var NCOL=__NCOL__,SC=['p','s','f','v','o','h','','ct'];
function esc(s){return String(s).replace(/[&<>\"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
Array.prototype.forEach.call(tb.rows,function(r){if(r.className==='card')rows.push(r);});
var fq=document.getElementById('q'),ff=document.getElementById('f'),
    fs=document.getElementById('sym'),fo=document.getElementById('so'),
    cn=document.getElementById('cn'),tm=document.getElementById('tm');
function apply(){
  var t0=performance.now();
  var q=(fq.value||'').toLowerCase().trim(),f=ff.value,s=fs.value,v=0;
  document.body.className=s?('symf s'+s):'';
  rows.forEach(function(r){
    var hide=false;
    if(q&&r.getAttribute('data-s').indexOf(q)<0)hide=true;
    if(!hide&&f==='hole'&&r.getAttribute('data-hole')==='0')hide=true;
    if(!hide&&f==='void'&&r.getAttribute('data-void')==='0')hide=true;
    if(!hide&&f==='open'&&r.getAttribute('data-open')==='0')hide=true;
    if(!hide&&s&&r.getAttribute('data-sym').indexOf('|'+s+'|')<0)hide=true;
    r.classList.toggle('hidden',hide);
    if(pairs[r.id])pairs[r.id].forEach(function(p){p.classList.toggle('hidden',hide);});
    if(!hide)v++;
  });
  cn.textContent=v.toLocaleString('en-US');
  tm.textContent=(performance.now()-t0).toFixed(0);
}
function sort(key,dir){
  var t0=performance.now();
  var sorted=rows.slice().sort(function(a,b){
    var x,y;
    if(key==='ea'){x=a.getAttribute('data-ea');y=b.getAttribute('data-ea');
      return (x<y?-1:x>y?1:0)*dir;}
    x=parseFloat(a.getAttribute('data-'+key))||0;
    y=parseFloat(b.getAttribute('data-'+key))||0;
    if(x===y){var m=a.getAttribute('data-ea'),n=b.getAttribute('data-ea');
      return m<n?-1:m>n?1:0;}
    return (x-y)*dir;
  });
  var frag=document.createDocumentFragment();
  sorted.forEach(function(r){frag.appendChild(r);
    if(pairs[r.id])pairs[r.id].forEach(function(p){frag.appendChild(p);});});
  tb.appendChild(frag);
  tm.textContent=(performance.now()-t0).toFixed(0);
}
function build(tr){
  var idx=parseInt(tr.getAttribute('data-i'),10),model=MDL[idx],out=[],ref=tr.nextSibling;
  model.forEach(function(row){
    var si=row[0],by={};
    row[1].forEach(function(c){by[c[0]]=c;});
    var h='<td class="id">'+SYM[si]+'</td><td class="n"></td><td class="n"></td><td class="n"></td>';
    for(var i=0;i<NCOL;i++){
      if(by[i]===undefined){h+='<td class="c" title="'+esc(RSN[row[2][i]])+'"></td>';}
      else{h+='<td class="c"><div class="strip"><i class="'+SC[by[i][1]]+' y'+si+
              '" title="'+esc(by[i][2])+'"></i></div></td>';}
    }
    var el=document.createElement('tr');el.className='pair';el.innerHTML=h;
    tb.insertBefore(el,ref);out.push(el);
  });
  return out;
}
tb.addEventListener('click',function(e){
  if(e.target.closest('a'))return;
  var tr=e.target.closest('tr.card');if(!tr)return;
  var t0=performance.now();
  if(!pairs[tr.id]){pairs[tr.id]=build(tr);}
  else{pairs[tr.id].forEach(function(el){el.classList.toggle('hidden');});}
  tm.textContent=(performance.now()-t0).toFixed(0);
});
document.querySelectorAll('thead th[data-k]').forEach(function(th){
  th.addEventListener('click',function(){
    var k=th.getAttribute('data-k');
    var d=th.getAttribute('data-d')==='1'?-1:1;
    th.setAttribute('data-d',d===1?'1':'0');
    sort(k,k==='ea'?d:-d);
  });
});
fq.addEventListener('input',apply);ff.addEventListener('change',apply);
fs.addEventListener('change',apply);
fo.addEventListener('change',function(){var v=fo.value;sort(v,v==='ea'?1:-1);});
})();
"""


def render_matrix_page(data: dict) -> str:
    cards = data["cards"]
    columns: list[ArchiveColumn] = data["columns"]
    stats = data["stats"]
    hbg = data["hole_by_gate"]
    all_syms = sorted({s for c in cards for s in c["symbols"]})
    sym_idx = {s: i for i, s in enumerate(all_syms)}
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()

    def strip(cell_list: list[dict], symbols: list[str]) -> str:
        if not cell_list:
            return ""
        out = [
            f'<i class="{ST_CLASS[cell["state"]]} y{sym_idx[symbols[cell["symbol_index"]]]}" '
            f'title="{e(cell["title"])}"></i>'
            for cell in cell_list
        ]
        return '<div class="strip">' + "".join(out) + "</div>"

    reasons: list[str] = []
    reason_ids: dict[str, int] = {}

    def reason_id(reason: str) -> int:
        if reason not in reason_ids:
            reason_ids[reason] = len(reasons)
            reasons.append(reason)
        return reason_ids[reason]

    body, model = [], []
    for n, c in enumerate(cards):
        symbols = c["symbols"]
        tds_parts = []
        for column in columns:
            cell_list = c["cells"].get(column.gate_id, [])
            title = ("" if cell_list else
                     ' title="No rendered chip; expand the card for the per-symbol reason."')
            tds_parts.append(f'<td class="c"{title}>{strip(cell_list, symbols)}</td>')
        tds = "".join(tds_parts)
        rowmodel = []
        for si, sym in enumerate(symbols):
            gcells = []
            row_reasons = []
            for ci, column in enumerate(columns):
                token = column.gate_id
                for cell in c["cells"].get(token, []):
                    if cell["symbol_index"] == si:
                        gcells.append([ci, cell["state"], cell["title"]])
                        break
                else:
                    reason = next(
                        entry["reason"] for entry in c["empty_reasons"].get(token, [])
                        if entry["symbol_index"] == si
                    )
                    row_reasons.append(reason_id(reason))
                    continue
                row_reasons.append(reason_id("cell has rendered evidence"))
            rowmodel.append([sym_idx[sym], gcells, row_reasons])
        model.append(rowmodel)
        symkey = "|" + "|".join(str(sym_idx[s]) for s in symbols) + "|"
        hp = columns[c["hp"]].gate_id if c["hp"] >= 0 else "—"
        body.append(
            f'<tr class="card" id="r{n}" data-i="{n}" data-ea="{e(c["ea"])}" '
            f'data-hp="{c["hp"]}" data-hole="{c["hole"]}" data-void="{c["void"]}" '
            f'data-open="{c["open"]}" data-pass="{c["pass"]}" '
            f'data-s="{e((c["ea"] + " " + c["slug"]).lower())}" data-sym="{e(symkey)}">'
            f'<td class="id"><a class="lnk" href="ea_{e(c["ea"])}.html"><b>{e(c["ea"])}</b></a>'
            f'<span>{e(c["slug"][:34])}</span></td>'
            f'<td class="n">{hp}</td><td class="n">{c["hole"] or ""}</td>'
            f'<td class="n">{c["void"] or ""}</td>{tds}</tr>')

    g1 = ['<th class="blank" colspan="4"></th>']
    for (_band_id, band_name, css_class), grouped in groupby(
        columns, key=lambda column: (column.band_id, column.band_name, column.css_class)
    ):
        grouped_columns = list(grouped)
        g1.append(f'<th class="{css_class}" colspan="{len(grouped_columns)}">'
                  f'{e(band_name)}</th>')
    g2 = ['<th data-k="ea">Strategy Card</th><th data-k="hp">contiguous&nbsp;frontier</th>'
          '<th data-k="hole">gaps</th><th data-k="void">VOID</th>']
    for column in columns:
        sub_html = '<small>OWNER/manual · no gap chips</small>' if column.owner_manual else ""
        g2.append(f'<th class="{column.css_class}" data-k="hp" title="{e(column.name)}">'
                  f'{e(column.gate_id)}{sub_html}</th>')

    sym_css = "".join(f"body.symf.s{i} i:not(.y{i}){{opacity:.10}}"
                      for i in range(len(all_syms)))
    use: Counter = Counter()
    for c in cards:
        for s in c["symbols"]:
            use[s] += 1
    dwx = sorted((s for s in all_syms if symbol_class(s) == "dwx"), key=lambda s: (-use[s], s))
    baskets = sorted((s for s in all_syms if symbol_class(s) == "basket"),
                     key=lambda s: (-use[s], s))
    sym_opts = ('<optgroup label="tradable DWX symbols">'
                + "".join(f'<option value="{sym_idx[s]}">{e(s)} · {use[s]}</option>' for s in dwx)
                + '</optgroup><optgroup label="logical basket symbols">'
                + "".join(f'<option value="{sym_idx[s]}">{e(s)} · {use[s]}</option>'
                          for s in baskets) + "</optgroup>")

    tot_cells = sum(stats.values())
    legend = (
        f'<span class="lg"><i class="p"></i><b>PASS</b> {fmt(stats[ST_PASS])}</span>'
        f'<span class="lg"><i class="s"></i><b>PASS conditional</b> {fmt(stats[ST_SOFT])}</span>'
        f'<span class="lg"><i class="f"></i><b>FAIL</b> {fmt(stats[ST_FAIL])}</span>'
        f'<span class="lg"><i class="v"></i><b>VOID - run burnt</b> {fmt(stats[ST_VOID])}</span>'
        f'<span class="lg"><i class="o"></i><b>running / queued</b> {fmt(stats[ST_OPEN])}</span>'
        f'<span class="lg"><i class="h"></i><b>reachable gap</b> {fmt(sum(hbg.values()))}</span>'
        f'<span class="lg"><i class="ct"></i><b>nie getestet (Card-Ziel)</b> '
        f'{fmt(stats[ST_CARD_HOLE])}</span>'
        '<span class="lg" style="color:var(--tx4)">empty cell = no run and none due</span>')
    holes = " · ".join(f"{g} {fmt(n)}" for g, n in
                       sorted(hbg.items(), key=lambda kv: -kv[1]) if n) or "-"

    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Strategy Archive Matrix</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>{MATRIX_CSS}{sym_css}</style></head><body>
<header>
<h1>Strategy Archive Matrix</h1>
<div class="sub">{fmt(len(cards))} strategy cards · {fmt(tot_cells)} rendered chips ·
{fmt(sum(hbg.values()))} reachable gaps · as of {now} · source <code>work_items_clean</code>
over <code>farm_state.sqlite</code> · <a href="strategies.html">Strategy Archive</a> ·
<a href="cockpit.html">Mission Control</a></div>
</header>
<div class="warn"><b>The stale-pass state (spec F4) is not rendered.</b> The database carries no
usable build identity per cell (<code>expected_ex5_sha256</code> in 0.3% of rows; the
<code>.ex5</code> timestamp would flag 73.6% of all PASS rows as stale and is polluted by
recompiles that never touch the EA). Until schema hardening SH-2 lands, the pre-registered
fallback applies: latest verdict, visibly warned. Gate columns, order and bands are loaded
from the active manifest; historical rows retain their contract provenance.</div>
<div class="legend">{legend}</div>
<div class="controls">
<input id="q" type="search" placeholder="search card or slug..." style="width:210px">
<select id="f"><option value="">all cards</option>
<option value="hole">with gaps only</option><option value="void">with VOID only</option>
<option value="open">with running cells only</option></select>
<select id="sym"><option value="">all symbols</option>{sym_opts}</select>
<select id="so"><option value="hp">sort: highest gate passed</option>
<option value="hole">sort: most gaps</option><option value="void">sort: most VOID</option>
<option value="ea">sort: card number</option></select>
<span class="cnt"><strong id="cn">{fmt(len(cards))}</strong> cards visible ·
last operation <strong id="tm">0</strong> ms</span>
</div>
<div class="wrap"><table>
<thead><tr class="g">{''.join(g1)}</tr><tr class="h">{''.join(g2)}</tr></thead>
<tbody id="tb">{''.join(body)}</tbody></table></div>
<footer>
<b>Gaps per gate:</b> {holes}<br>
<b>What this page does NOT show:</b> cards without a single gate row do not appear
(OWNER decision F8: one source, one freshness). The queue <i>before</i> the factory — approved
cards never built — belongs to the drain programme. Absence here is never evidence of
completeness.<br>
<b>Second source, kept separate:</b> {fmt(data['untested_targets'])} target symbols from card
frontmatter have no run at all and appear as a Q02 gap
labelled <b>nie getestet (Card-Ziel)</b>
({fmt(data['cards_with_targets'])} cards read).<br>
<b>Work-item gap contract:</b>
{e(' · '.join(f'{k} {v}' for k, v in sorted(data['action_counts'].items())) or '-')}.
Actions are read from the governed 2026-08-23 backfill plan when rendering the farm DB;
economic STOP cells remain FAIL; OWNER/manual gates never receive gap chips.<br>
<b>Empty, not a gap:</b> {fmt(data['held_items'])} work items sit under an active hold;
every empty pair cell exposes its derived reason on hover.<br>
<b>Storage phases not shown:</b>
{e(', '.join(f'{k} {v}' for k, v in data['skipped_phase'].most_common(6))) or '-'}<br>
Read-only. No action paths. Collected in {data['collect_s']}s over
{fmt(data['rows_seen'])} work-item rows.
</footer>
<script id="mdl" type="application/json">{json.dumps(model, separators=(",", ":"))}</script>
<script id="syms" type="application/json">{json.dumps(all_syms, separators=(",", ":"))}</script>
<script id="rsn" type="application/json">{json.dumps(reasons, separators=(",", ":"))}</script>
<script>{MATRIX_JS.replace('__NCOL__', str(len(columns)))}</script></body></html>"""


def main(argv: list[str] | None = None) -> int:
    """Standalone render, for iteration outside the hourly dashboard task."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=DB)
    parser.add_argument(
        "--output", type=Path,
        default=FARM_ROOT / "dashboards" / "strategy_archive.html",
    )
    args = parser.parse_args(argv)
    data = collect(args.db)
    out = args.output
    out.parent.mkdir(parents=True, exist_ok=True)
    doc = render_matrix_page(data)
    out.write_text(doc, encoding="utf-8")
    idx = build_report_index()
    print(json.dumps({
        "output": str(out), "mb": round(len(doc.encode()) / 1048576, 2),
        "cards": len(data["cards"]), "cells": data["cells"],
        "gaps": sum(data["hole_by_gate"].values()),
        "gaps_by_gate": dict(data["hole_by_gate"].most_common()),
        "relic_rows_dropped": sum(data["dropped_relic"].values()),
        "report_index_work_items": len(idx),
        "collect_s": data["collect_s"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
