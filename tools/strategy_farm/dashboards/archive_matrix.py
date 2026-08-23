"""Strategy Archive: the card x gate x symbol matrix and the per-card evidence sections.

Authority: ``docs/ops/STRATEGY_ARCHIVE_MATRIX_SPEC_2026-08-23.md`` v1.0 (OWNER decisions
F1-F8, 2026-08-23).

The point of the matrix is not to show successes but **gaps**: a cell whose predecessor
gate passed and that still carries no row at all. Everything else on the page exists to
make that one signal readable.

Read-only. No write path, no action elements, no verdict interpretation beyond the
existing ``work_items_clean`` taxonomy.

Consumed by ``render_dashboards.py``:
  * :func:`render_matrix_page`      -> ``strategy_archive.html``
  * :func:`render_card_section`     -> the Strategy section of ``ea_<id>.html``
  * :func:`render_backtests_section`-> the complete run table of ``ea_<id>.html``
"""
from __future__ import annotations

import datetime as dt
import html
import json
import os
import re
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
if str(REPO_ROOT / "tools" / "strategy_farm") not in sys.path:
    sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from phase_ids import PHASE_NAME  # noqa: E402
from work_item_clean_view import open_clean_view_connection  # noqa: E402

FARM_ROOT = Path("D:/QM/strategy_farm")
DB = FARM_ROOT / "state" / "farm_state.sqlite"
CARD_BUCKETS = ("cards_approved", "cards_review", "cards_draft", "cards_rejected",
                "cards_recovery", "cards_blocked_r3_data")
REPORT_ROOTS = ("D:/QM/reports/work_items", "D:/QM/reports/pipeline")

# Column order follows the FLOW (OWNER decision F2): the optimization fork sits where it
# is walked, between Q10 and Q11, and already carries its future name Q10.1-Q10.3. In
# storage those stages remain Q14-Q16 until gate manifest v4 (DL pending).
COLUMNS: list[tuple[str, str, str, str]] = [
    ("Q02", "Q02", "eval", ""), ("Q03", "Q03", "eval", ""), ("Q04", "Q04", "eval", ""),
    ("Q05", "Q05", "eval", ""), ("Q06", "Q06", "eval", ""), ("Q07", "Q07", "eval", ""),
    ("Q08", "Q08", "eval", ""), ("Q09", "Q09", "eval", ""), ("Q10", "Q10", "eval", ""),
    ("Q14", "Q10.1", "opt", "today Q14"),
    ("Q15", "Q10.2", "opt", "today Q15"),
    ("Q16", "Q10.3", "opt", "today Q16"),
    ("Q11", "Q11", "port", ""), ("Q12", "Q12", "port", ""), ("Q13", "Q13", "port", ""),
]
GATE_IDX = {c[0]: i for i, c in enumerate(COLUMNS)}
# The ordinary chain drives the gap test. The optimization fork is optional and can
# therefore never be "missing".
ORDINARY = ["Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08", "Q09", "Q10",
            "Q11", "Q12", "Q13"]

ST_PASS, ST_SOFT, ST_FAIL, ST_VOID, ST_OPEN, ST_HOLE, ST_NONE = range(7)
ST_CLASS = {ST_PASS: "p", ST_SOFT: "s", ST_FAIL: "f", ST_VOID: "v",
            ST_OPEN: "o", ST_HOLE: "h", ST_NONE: ""}
ST_NAME = {ST_PASS: "PASS", ST_SOFT: "PASS (conditional)", ST_FAIL: "FAIL",
           ST_VOID: "VOID", ST_OPEN: "running/queued", ST_HOLE: "GAP", ST_NONE: "-"}

RETIRE_TOKENS = ("RETIRE", "RETIRED_LOW_FREQ", "OBSOLETE_NON_DWX_SYMBOL",
                 "SUPERSEDED", "SUPERSEDED_BY_LOGICAL_BASKET", "CANCELLED")

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


def gate_of(phase: str | None) -> str | None:
    if not phase:
        return None
    if phase.startswith("Q09"):
        return "Q09"
    if phase == "P2":                       # legacy alias of Q02
        return "Q02"
    return phase if phase in GATE_IDX else None


def state_of(taxonomy: str, verdict: str) -> int:
    if taxonomy == "open":
        return ST_OPEN
    if taxonomy in ("infra", "invalid"):
        return ST_VOID
    if taxonomy == "strategy":
        if verdict in ("PASS_SOFT", "PASS_LOWFREQ"):
            return ST_SOFT
        return ST_PASS if verdict.startswith("PASS") else ST_FAIL
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
    for line in head.split("\n"):
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
                       + "".join(f"<th>{md_inline(c)}</th>" for c in head)
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
            out.append(f"<h{lvl}>{md_inline(m.group(2))}</h{lvl}>")
            i += 1
            continue
        if re.match(r"^\s*[-*]\s+", ln):
            if list_tag != "ul":
                close_list()
                out.append("<ul>")
                list_tag = "ul"
            out.append("<li>" + md_inline(re.sub(r"^\s*[-*]\s+", "", ln)) + "</li>")
            i += 1
            continue
        if re.match(r"^\s*\d+[.)]\s+", ln):
            if list_tag != "ol":
                close_list()
                out.append("<ol>")
                list_tag = "ol"
            out.append("<li>" + md_inline(re.sub(r"^\s*\d+[.)]\s+", "", ln)) + "</li>")
            i += 1
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
    """One pass over work_items_clean -> matrix cells, gaps, and per-EA run lists."""
    t0 = time.perf_counter()
    conn = open_clean_view_connection(db)

    latest: dict[tuple[str, str, str], tuple[str, str, str, str]] = {}
    all_items: dict[str, list[dict]] = defaultdict(list)
    retired: set[tuple[str, str]] = set()
    held: set[str] = set()
    skipped_phase: Counter = Counter()
    dropped_relic: Counter = Counter()
    rows_seen = 0

    for wid, ea, sym, phase, verdict, tax, upd, evidence in conn.execute(
        "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at, "
        "evidence_path FROM work_items_clean"
    ):
        rows_seen += 1
        if not ea:
            continue
        symbol = (sym or "").strip() or "BASKET"
        if symbol_class(symbol) == "relic":
            dropped_relic[symbol] += 1
            continue
        v = (verdict or "").upper()
        all_items[ea].append({"id": wid, "symbol": symbol, "phase": phase, "verdict": v,
                              "tax": tax or "unknown", "upd": upd or "",
                              "evidence": evidence or ""})
        gate = gate_of(phase)
        if gate is None:
            skipped_phase[phase or "<null>"] += 1
            continue
        if any(v.startswith(t) for t in RETIRE_TOKENS):
            retired.add((ea, symbol))
        key = (ea, symbol, gate)
        cur = latest.get(key)
        if cur is None or (upd or "") > cur[0]:
            latest[key] = ((upd or ""), v, (tax or "unknown"), wid)

    for (wid,) in conn.execute("SELECT work_item_id FROM work_item_holds WHERE active = 1"):
        held.add(wid)
    conn.close()

    slugs: dict[str, str] = {}
    ea_dir = REPO_ROOT / "framework" / "EAs"
    if ea_dir.is_dir():
        for d in os.scandir(ea_dir):
            if d.is_dir() and d.name.startswith("QM5_"):
                parts = d.name.split("_", 2)
                if len(parts) == 3:
                    slugs[f"{parts[0]}_{parts[1]}"] = parts[2]

    targets = _card_targets()

    by_card: dict[str, dict[str, dict[str, tuple]]] = defaultdict(lambda: defaultdict(dict))
    for (ea, symbol, gate), val in latest.items():
        by_card[ea][symbol][gate] = val

    cards: list[dict] = []
    stats: Counter = Counter()
    hole_by_gate: Counter = Counter()
    untested_targets = 0

    for ea, sym_map in by_card.items():
        for tsym in targets.get(ea, []):
            if tsym not in sym_map:
                sym_map[tsym] = {}
                untested_targets += 1
        symbols = sorted(sym_map)
        cells: dict[str, list[int]] = {}
        n_pass = n_fail = n_void = n_open = n_hole = 0
        hp_idx = -1
        last_upd = ""

        for si, symbol in enumerate(symbols):
            gates = sym_map[symbol]
            # (1) draw everything stored. An early chain break must never swallow a
            # measured cell on a page that claims to show the whole database.
            for token, _l, _g, _s in COLUMNS:
                cell = gates.get(token)
                if cell is None:
                    continue
                upd, verdict, tax, wid = cell
                st = ST_OPEN if (wid in held and tax == "open") else state_of(tax, verdict)
                cells.setdefault(token, []).append((si << 3) | st)
                stats[st] += 1
                if st in (ST_PASS, ST_SOFT):
                    n_pass += 1
                    hp_idx = max(hp_idx, GATE_IDX[token])
                elif st == ST_FAIL:
                    n_fail += 1
                elif st == ST_VOID:
                    n_void += 1
                elif st == ST_OPEN:
                    n_open += 1
                last_upd = max(last_upd, upd)
            # (2) separately: the gap. Retired pairs never produce one (F5).
            if (ea, symbol) in retired:
                continue
            for gi, gate in enumerate(ORDINARY):
                if gates.get(gate) is not None:
                    continue
                prev_ok = True
                if gi > 0:
                    pc = gates.get(ORDINARY[gi - 1])
                    prev_ok = pc is not None and pc[1].startswith("PASS")
                if prev_ok:
                    cells.setdefault(gate, []).append((si << 3) | ST_HOLE)
                    n_hole += 1
                    hole_by_gate[gate] += 1
                break

        cards.append({"ea": ea, "slug": slugs.get(ea, ""), "symbols": symbols,
                      "cells": cells, "hp": hp_idx, "pass": n_pass, "fail": n_fail,
                      "void": n_void, "open": n_open, "hole": n_hole, "upd": last_upd})

    # F6: highest gate passed first, gaps as the tiebreak.
    cards.sort(key=lambda c: (-c["hp"], -c["hole"], c["ea"]))
    return {"cards": cards, "stats": stats, "hole_by_gate": hole_by_gate,
            "all_items": all_items, "slugs": slugs, "cells": len(latest),
            "rows_seen": rows_seen, "skipped_phase": skipped_phase,
            "dropped_relic": dropped_relic, "untested_targets": untested_targets,
            "retired_pairs": len(retired), "held_items": len(held),
            "cards_with_targets": len(targets),
            "collect_s": round(time.perf_counter() - t0, 2)}


def _card_targets() -> dict[str, list[str]]:
    """Target symbols from approved-card frontmatter.

    SECOND SOURCE, deliberately kept separate and labelled as such on the page: the
    matrix itself stands on work_items alone (F8). This only adds the "target symbol
    that never ran at all" gap.
    """
    out: dict[str, list[str]] = {}
    d = FARM_ROOT / "artifacts" / "cards_approved"
    if not d.is_dir():
        return out
    pat = re.compile(r"^target_symbols:\s*\[([^\]]*)\]", re.M)
    for path in d.glob("QM5_*.md"):
        parts = path.name.split("_", 2)
        if len(parts) < 3:
            continue
        ea = f"{parts[0]}_{parts[1]}"
        try:
            head = path.read_text(encoding="utf-8", errors="replace")[:4000]
        except OSError:
            continue
        m = pat.search(head)
        if not m:
            continue
        syms = [s.strip().strip('"\'') for s in m.group(1).split(",") if s.strip()]
        syms = [s for s in syms if symbol_class(s) != "relic"]
        if syms:
            out[ea] = syms
    return out


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


_RUNS_BY_EA: dict[str, list[dict]] | None = None


def runs_for_ea(ea_id: str, db: Path = DB) -> list[dict]:
    """Every stored run of one EA, newest first.

    Loaded once for the whole process in a single pass — ``render_dashboards`` calls this
    for ~3,000 EAs, and a query (plus TEMP-view install) per EA would dominate the render.
    Relic symbols are excluded here exactly as they are in the matrix.
    """
    global _RUNS_BY_EA
    if _RUNS_BY_EA is None:
        acc: dict[str, list[dict]] = defaultdict(list)
        conn = open_clean_view_connection(db)
        for wid, ea, sym, phase, verdict, tax, upd, evidence, payload in conn.execute(
            "SELECT id, ea_id, symbol, phase, verdict, verdict_taxonomy, updated_at, "
            "evidence_path, payload_json FROM work_items_clean WHERE ea_id IS NOT NULL"
        ):
            symbol = (sym or "").strip() or "BASKET"
            if symbol_class(symbol) == "relic":
                continue
            acc[ea].append({"id": wid, "symbol": symbol, "phase": phase or "",
                            "verdict": (verdict or "").upper(), "tax": tax or "unknown",
                            "upd": upd or "", "evidence": evidence or "",
                            "reason": _reason_of(payload)})
        conn.close()
        for v in acc.values():
            v.sort(key=lambda r: r["upd"], reverse=True)
        _RUNS_BY_EA = acc
    return _RUNS_BY_EA.get(ea_id, [])


# ── sections embedded into ea_<id>.html ───────────────────────────────────────

CARD_SECTION_CSS = """
.sc-wrap{padding:22px 24px;background:var(--surface-1);border:1px solid var(--border);
margin-bottom:24px}
.sc-kicker{font-family:var(--font-mono);font-size:10px;font-weight:700;color:var(--text-3);
text-transform:uppercase;letter-spacing:.2em;margin-bottom:14px}
.sc-facts{display:grid;grid-template-columns:repeat(auto-fill,minmax(210px,1fr));gap:1px;
background:var(--border);border:1px solid var(--border);margin:0 0 16px}
.sc-facts div{background:var(--surface-2);padding:8px 11px}
.sc-facts b{display:block;color:var(--text-4);font-size:10px;text-transform:uppercase;
letter-spacing:.07em;font-weight:500;margin-bottom:2px}
.sc-facts span{font-size:12.5px;color:var(--text)}
.sc-src{border-left:3px solid var(--border-3);padding:8px 12px;margin:0 0 16px;
color:var(--text-3);font-size:11.5px;line-height:1.6}
.sc-body{font-size:13px;line-height:1.7;color:var(--text-2)}
.sc-body h3{font-size:14px;color:var(--text);margin:20px 0 6px}
.sc-body h4{font-size:12.5px;color:var(--text-2);margin:16px 0 4px;
text-transform:uppercase;letter-spacing:.06em}
.sc-body p{margin:0 0 9px}
.sc-body ul,.sc-body ol{margin:0 0 10px 20px;padding:0}
.sc-body li{margin:0 0 4px}
.sc-body table{border-collapse:collapse;width:100%;font-size:11.5px;margin:8px 0}
.sc-body th{text-align:left;color:var(--text-3);border-bottom:1px solid var(--border-2);
padding:4px 7px}
.sc-body td{border-bottom:1px solid var(--border);padding:3px 7px;vertical-align:top}
.sc-body pre{background:var(--surface-2);padding:9px 11px;overflow-x:auto;font-size:11px}
.sc-none{color:var(--text-4);font-size:12px}
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


def render_card_section(ea_id: str) -> str:
    """The full strategy card, rendered. Replaces the three-paragraph teaser."""
    path, bucket = find_card(ea_id)
    if not path:
        return ('<div class="sc-wrap"><div class="sc-kicker">Strategy</div>'
                '<div class="sc-none">No strategy card on disk for this EA id. '
                'The pipeline evidence below is unaffected.</div></div>')
    try:
        raw = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return ('<div class="sc-wrap"><div class="sc-kicker">Strategy</div>'
                f'<div class="sc-none">Card unreadable: {e(exc)}</div></div>')
    fm, body = split_frontmatter(raw)
    facts = "".join(f"<div><b>{e(lbl)}</b><span>{e(fm[k])}</span></div>"
                    for k, lbl in FM_KEYS if fm.get(k))
    src = (f'<div class="sc-src"><strong>Source:</strong> {md_inline(fm["source_citation"])}</div>'
           if fm.get("source_citation") else "")
    return (f'<div class="sc-wrap"><div class="sc-kicker">Strategy · card bucket '
            f'{e(bucket)}</div>'
            f'<div class="sc-facts">{facts}</div>{src}'
            f'<div class="sc-body">{md_to_html(body, base_level=3)}</div></div>')


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
        rows.append(
            f'<tr><td class="bt-v">{e((it.get("upd") or "")[:16].replace("T", " "))}</td>'
            f'<td class="bt-v">{e(it.get("phase") or "")}</td>'
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
--void:#e19a24;--open:#6b7280;--hole:#84a2ff;--eval:#3455a8;--opt:#a86a20;--port:#6b4ba8}
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
thead tr.g th.eval{background:var(--eval)}
thead tr.g th.opt{background:var(--opt)}
thead tr.g th.port{background:var(--port)}
thead tr.g th.blank{background:var(--s2)}
thead tr.h th{top:24px;padding:6px 8px;cursor:pointer;user-select:none}
thead tr.h th:hover{color:var(--tx);background:var(--s3)}
thead tr.h th small{display:block;font-size:9px;color:var(--tx4);font-weight:400}
thead tr.h th.eval{border-bottom:2px solid var(--eval)}
thead tr.h th.opt{border-bottom:2px solid var(--opt)}
thead tr.h th.port{border-bottom:2px solid var(--port)}
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
var NCOL=15,SC=['p','s','f','v','o','h',''],
    SN=['PASS','PASS conditional','FAIL','VOID','running/queued','GAP','-'];
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
    row[1].forEach(function(c){by[c[0]]=c[1];});
    var h='<td class="id">'+SYM[si]+'</td><td class="n"></td><td class="n"></td><td class="n"></td>';
    for(var i=0;i<NCOL;i++){
      if(by[i]===undefined){h+='<td class="c"></td>';}
      else{h+='<td class="c"><div class="strip"><i class="'+SC[by[i]]+' y'+si+
              '" title="'+SYM[si]+' '+SN[by[i]]+'"></i></div></td>';}
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
    stats = data["stats"]
    hbg = data["hole_by_gate"]
    all_syms = sorted({s for c in cards for s in c["symbols"]})
    sym_idx = {s: i for i, s in enumerate(all_syms)}
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()

    def strip(packed_list: list[int], symbols: list[str], gate: str) -> str:
        if not packed_list:
            return ""
        out = []
        for packed in packed_list:
            si, st = packed >> 3, packed & 7
            sym = symbols[si]
            out.append(f'<i class="{ST_CLASS[st]} y{sym_idx[sym]}" '
                       f'title="{e(sym)} {gate} {ST_NAME[st]}"></i>')
        return '<div class="strip">' + "".join(out) + "</div>"

    body, model = [], []
    for n, c in enumerate(cards):
        symbols = c["symbols"]
        tds = "".join(f'<td class="c">{strip(c["cells"].get(tok, []), symbols, tok)}</td>'
                      for tok, _l, _g, _s in COLUMNS)
        rowmodel = []
        for si, sym in enumerate(symbols):
            gcells = []
            for ci, (tok, _l, _g, _s) in enumerate(COLUMNS):
                for packed in c["cells"].get(tok, []):
                    if (packed >> 3) == si:
                        gcells.append([ci, packed & 7])
                        break
            rowmodel.append([sym_idx[sym], gcells])
        model.append(rowmodel)
        symkey = "|" + "|".join(str(sym_idx[s]) for s in symbols) + "|"
        hp = COLUMNS[c["hp"]][1] if c["hp"] >= 0 else "—"
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
    for grp, label in (("eval", "Evaluation"), ("opt", "Optimization"),
                       ("port", "Portfolio build")):
        g1.append(f'<th class="{grp}" colspan="{sum(1 for c in COLUMNS if c[2] == grp)}">'
                  f'{label}</th>')
    g2 = ['<th data-k="ea">Strategy Card</th><th data-k="hp">highest&nbsp;PASS</th>'
          '<th data-k="hole">gaps</th><th data-k="void">VOID</th>']
    for tok, label, grp, sub in COLUMNS:
        sub_html = f"<small>{e(sub)}</small>" if sub else ""
        g2.append(f'<th class="{grp}" data-k="hp" title="{e(PHASE_NAME.get(tok, tok))}">'
                  f'{e(label)}{sub_html}</th>')

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
        '<span class="lg" style="color:var(--tx4)">empty cell = no run and none due</span>')
    holes = " · ".join(f"{g} {fmt(n)}" for g, n in
                       sorted(hbg.items(), key=lambda kv: -kv[1]) if n) or "-"

    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Strategy Archive Matrix</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>{MATRIX_CSS}{sym_css}</style></head><body>
<header>
<h1>Strategy Archive Matrix</h1>
<div class="sub">{fmt(len(cards))} strategy cards · {fmt(tot_cells)} stored cells ·
{fmt(sum(hbg.values()))} reachable gaps · as of {now} · source <code>work_items_clean</code>
over <code>farm_state.sqlite</code> · <a href="strategies.html">Strategy Archive</a> ·
<a href="cockpit.html">Mission Control</a></div>
</header>
<div class="warn"><b>The stale-pass state (spec F4) is not rendered.</b> The database carries no
usable build identity per cell (<code>expected_ex5_sha256</code> in 0.3% of rows; the
<code>.ex5</code> timestamp would flag 73.6% of all PASS rows as stale and is polluted by
recompiles that never touch the EA). Until schema hardening SH-2 lands, the pre-registered
fallback applies: latest verdict, visibly warned. Branch columns already carry their future
names <b>Q10.1-Q10.3</b>; in storage they remain Q14-Q16 until gate manifest v4.</div>
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
({fmt(data['cards_with_targets'])} cards read).<br>
<b>Empty, not a gap:</b> {fmt(data['retired_pairs'])} (card, symbol) pairs are retired via
RETIRE/OBSOLETE/SUPERSEDED and {fmt(data['held_items'])} work items sit under an active hold.<br>
<b>Storage phases not shown:</b>
{e(', '.join(f'{k} {v}' for k, v in data['skipped_phase'].most_common(6))) or '-'}<br>
Read-only. No action paths. Collected in {data['collect_s']}s over
{fmt(data['rows_seen'])} work-item rows.
</footer>
<script id="mdl" type="application/json">{json.dumps(model, separators=(",", ":"))}</script>
<script id="syms" type="application/json">{json.dumps(all_syms, separators=(",", ":"))}</script>
<script>{MATRIX_JS}</script></body></html>"""


def main() -> int:
    """Standalone render, for iteration outside the hourly dashboard task."""
    data = collect()
    out = FARM_ROOT / "dashboards" / "strategy_archive.html"
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
