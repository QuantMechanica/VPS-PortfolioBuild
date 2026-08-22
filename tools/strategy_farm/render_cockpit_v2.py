"""Mission Control v2 — primary cockpit renderer (``qm.mission_control.v2``).

Renders the Mission Control v2 data contract to a single self-contained HTML
page at ``D:\\QM\\strategy_farm\\dashboards\\cockpit_v2.html`` — a **shadow**
surface that runs in parallel to the live ``cockpit.html`` until the OWNER
signs it off. This module makes **zero data decisions**: it imports
``build_contract`` from ``mission_control_v2_data`` and binds the emitted
fields verbatim (Single Source of Truth). Design is fixed by
``docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md`` (the orchestrator's design lane).

Hard rendering discipline (from the spec, non-negotiable):

  * Read-only page — NO ``<button>`` / ``<form>`` / ``onclick`` action element
    can touch factory / deploy / AutoTrading. Owner decisions link only to
    evidence.
  * ``<link rel="stylesheet" href="style.css">`` (co-located in the output dir)
    plus a small page-grid ``<style>`` block using ONLY ``var(--*)`` tokens from
    that stylesheet. No new colours; ``border-radius:0``; no glow / gradient /
    blur / motion; hairline borders.
  * Gate vocabulary is Qxx only, straight from the contract (``phase_qid`` /
    ``phase_name``). No storage P-keys ever surface.
  * All contract strings are escaped with ``html.escape``. Numbers are
    right-aligned mono. Relative time is one small inline script, no libraries.

CLI::

    python tools/strategy_farm/render_cockpit_v2.py            # build fresh + write
    python tools/strategy_farm/render_cockpit_v2.py --from-json <snapshot.json>
    python tools/strategy_farm/render_cockpit_v2.py --output <path> --stdout
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import os
import sys
import time
from pathlib import Path
from typing import Any

try:  # package import (tests, module consumers)
    from tools.strategy_farm.mission_control_v2_data import build_contract
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/render_cockpit_v2.py``
    from mission_control_v2_data import build_contract


# Primary cockpit since OWNER approval 2026-08-21; cockpit_v2.html stays as an
# alias so pre-approval links keep working. Legacy layout: cockpit_advanced.html.
OUTPUT_PATH = Path(r"D:\QM\strategy_farm\dashboards\cockpit.html")
ALIAS_PATH = Path(r"D:\QM\strategy_farm\dashboards\cockpit_v2.html")


# ---------------------------------------------------------------------------
# escaping + formatting helpers
# ---------------------------------------------------------------------------
def e(s: Any) -> str:
    """HTML-escape with str() coercion; None -> "". Matches render_cockpit.e()."""
    return html.escape(str(s)) if s is not None else ""


def _de(x: Any, dec: int = 1) -> str:
    """German decimal formatting (comma), fixed places. None -> '—'."""
    if x is None:
        return "—"
    try:
        return f"{float(x):,.{dec}f}".replace(",", "\u0001").replace(".", ",").replace("\u0001", ".")
    except (TypeError, ValueError):
        return e(x)


def _int(x: Any) -> str:
    """Thousands-grouped integer (German: dot separator). None -> '—'."""
    if x is None:
        return "—"
    try:
        return f"{int(round(float(x))):,}".replace(",", ".")
    except (TypeError, ValueError):
        return e(x)


def _pct(frac: Any, dec: int = 1) -> str:
    """Fraction (0..1) -> German percent string. None -> '—'."""
    if frac is None:
        return "—"
    try:
        return _de(float(frac) * 100.0, dec) + " %"
    except (TypeError, ValueError):
        return "—"


def _epoch_ms(iso: str | None) -> int | None:
    """ISO-8601 UTC -> epoch milliseconds, for the client relative-time script."""
    if not iso:
        return None
    try:
        t = dt.datetime.fromisoformat(str(iso).replace("Z", "+00:00"))
        if t.tzinfo is None:
            t = t.replace(tzinfo=dt.timezone.utc)
        return int(t.timestamp() * 1000)
    except (TypeError, ValueError):
        return None


def _reltime_from_seconds(sec: int | None) -> str:
    """Server-side fallback for the relative-time script ('vor 3 min')."""
    if sec is None:
        return "—"
    sec = max(0, int(sec))
    if sec < 60:
        return f"vor {sec}s"
    m = sec // 60
    if m < 60:
        return f"vor {m} min"
    h = m // 60
    return f"vor {h} h {m % 60} min"


def _reltime_span(iso: str | None, fallback_seconds: int | None = None,
                  prefix: str = "") -> str:
    """A live relative-time span. JS fills it from data-epoch-ms; the server
    fallback keeps it meaningful with JS disabled."""
    epoch = _epoch_ms(iso)
    if fallback_seconds is None and iso:
        # derive a fallback age from the timestamp at render time
        ems = epoch
        if ems is not None:
            fallback_seconds = max(0, int(time.time() * 1000 - ems) // 1000)
    fb = _reltime_from_seconds(fallback_seconds) if fallback_seconds is not None else "—"
    attr = f' data-epoch-ms="{epoch}"' if epoch is not None else ""
    return f'<span class="mc-rel"{attr}>{e(prefix)}{e(fb)}</span>'


# ---------------------------------------------------------------------------
# factory traffic-light mapping (spec §1 — logic in the renderer, 4-case test)
# ---------------------------------------------------------------------------
def map_factory_light(factory_state: str | None) -> dict[str, str]:
    """Map the emitter's ``factory_state`` enum onto the ratified traffic-light.

    Ratified rule (feedback 2026-06-x, mirrored by the emitter precedence):
      * CRITICAL (red) ONLY when the factory truly stands — ceremony-incomplete,
        a factory-down check FAIL, i.e. no productive claims possible.
      * ``FACTORY_OFF.flag`` present -> MAINTENANCE (amber): an intentional stop.
      * a health FAIL while the factory is running -> DEGRADED (amber).
      * otherwise NOMINAL (green).

    The mapping only PRIORITISES the light; the raw emitter state and reason are
    always rendered as a subline so nothing is hidden.
    """
    s = (factory_state or "").upper()
    if s == "CRITICAL":
        return {"level": "critical", "color": "var(--fail)", "label": "CRITICAL"}
    if s == "MAINTENANCE":
        return {"level": "maintenance", "color": "var(--warn)", "label": "MAINTENANCE"}
    if s == "DEGRADED":
        return {"level": "degraded", "color": "var(--warn)", "label": "DEGRADED"}
    if s == "NOMINAL":
        return {"level": "ok", "color": "var(--pass)", "label": "NOMINAL"}
    return {"level": "unknown", "color": "var(--text-3)", "label": s or "UNKNOWN"}


# ---------------------------------------------------------------------------
# queue arithmetic (spec test 7 — displayed subsets add to the totals)
# ---------------------------------------------------------------------------
def queue_breakdown(contract: dict) -> dict[str, int]:
    """The queue subtotals the strip and the queue section both display.

    Invariants the renderer shows and the test asserts:
      pending_total = pending_executable + pending_parked
      queue_total   = pending_total + active
    """
    q = contract.get("queue", {})
    executable = int(q.get("pending_executable") or 0)
    parked = int(q.get("pending_parked") or 0)
    active = int(q.get("active") or 0)
    pending_total = int(q.get("pending_total") or (executable + parked))
    return {
        "pending_executable": executable,
        "pending_parked": parked,
        "pending_total": pending_total,
        "active": active,
        "queue_total": pending_total + active,
    }


# ---------------------------------------------------------------------------
# staleness helpers
# ---------------------------------------------------------------------------
def _stale_badge(meta: dict) -> str:
    """A STALE / DEGRADED chip for a section header, driven by meta."""
    if not isinstance(meta, dict):
        return ""
    if meta.get("degraded_reason"):
        return (f'<span class="mc-badge mc-badge-warn" '
                f'title="{e(meta.get("degraded_reason"))}">DEGRADED</span>')
    if str(meta.get("staleness") or "").upper() == "STALE":
        age = meta.get("age_seconds")
        t = f"source_as_of {e(meta.get('source_as_of'))}"
        return (f'<span class="mc-badge mc-badge-warn" title="{t}">STALE'
                + (f' · {_int(age)}s' if age is not None else "") + "</span>")
    return ""


# ---------------------------------------------------------------------------
# section renderers
# ---------------------------------------------------------------------------
def _render_control_strip(contract: dict) -> str:
    cs = contract.get("control_strip", {})
    q = contract.get("queue", {})
    br = queue_breakdown(contract)
    light = map_factory_light(cs.get("factory_state"))

    # Factory cell
    reason = cs.get("factory_state_reason") or ""
    raw_sub = (f"{cs.get('factory_state')} · health {cs.get('health_overall')}"
               f" ({_int(cs.get('health_fail_count'))} FAIL)")
    factory_cell = f'''
      <div class="mc-cell">
        <div class="mc-cell-label">Factory</div>
        <div class="mc-cell-main"><span class="mc-dot" style="background:{light['color']}"></span>
          <span style="color:{light['color']}">{e(light['label'])}</span></div>
        <div class="mc-cell-sub">{e(raw_sub)}</div>
        <div class="mc-cell-sub mc-clip" title="{e(reason)}">{e(reason)}</div>
      </div>'''

    # Freshness cell
    fresh = cs.get("data_freshness", {})
    any_stale = bool(fresh.get("any_stale"))
    oldest = fresh.get("oldest_age_seconds")
    oldest_name = "—"
    oldest_stale = "FRESH"
    rms = fresh.get("critical_readmodels") or []
    if rms:
        # the oldest critical readmodel
        aged = [r for r in rms if r.get("age_seconds") is not None]
        if aged:
            r0 = max(aged, key=lambda r: r["age_seconds"])
            oldest_name = r0.get("name") or "—"
            oldest_stale = r0.get("staleness") or "FRESH"
    fresh_badge = ('<span class="mc-badge mc-badge-warn">STALE</span>'
                   if any_stale else '<span class="mc-badge mc-badge-ok">FRESH</span>')
    fresh_cell = f'''
      <div class="mc-cell">
        <div class="mc-cell-label">Freshness</div>
        <div class="mc-cell-main">{fresh_badge}</div>
        <div class="mc-cell-sub">oldest: {e(oldest_name)} · {_reltime_from_seconds(oldest)} · {e(oldest_stale)}</div>
      </div>'''

    # Queue cell
    queue_cell = f'''
      <div class="mc-cell">
        <div class="mc-cell-label">Queue</div>
        <div class="mc-cell-main mc-num">{_int(br['pending_executable'])}</div>
        <div class="mc-cell-sub">+{_int(br['pending_parked'])} parked · {_int(br['active'])} active
          · <span title="pending_total + active">Σ {_int(br['queue_total'])}</span></div>
      </div>'''

    # Terminals cell
    tc = (contract.get("terminals", {}) or {}).get("counts", {})
    terminals_cell = f'''
      <div class="mc-cell">
        <div class="mc-cell-label">Terminals</div>
        <div class="mc-cell-main mc-num">{_int(tc.get('running'))}<span class="mc-cell-slash">/{_int(tc.get('fleet_size'))}</span></div>
        <div class="mc-cell-sub">{_int(tc.get('reserved'))} reserved · {_int(tc.get('idle'))} idle</div>
      </div>'''

    # Clear-ETA cell
    eta = q.get("eta_to_empty", {}) or {}
    basis = eta.get("basis") or ""
    p50 = cs.get("clear_eta_hours_p50")
    p90 = cs.get("clear_eta_hours_p90")
    if p50 is not None:
        eta_main = f"~{_de(p50 / 24.0, 1)} T"
        eta_sub = (f"P90 {_de(p90 / 24.0, 1)} T" if p90 is not None else "P90 —")
    else:
        eta_main = "—"
        eta_sub = "no 24 h throughput"
    eta_cell = f'''
      <div class="mc-cell" title="{e(basis)}">
        <div class="mc-cell-label">Clear-ETA</div>
        <div class="mc-cell-main mc-num">{eta_main}</div>
        <div class="mc-cell-sub">{e(eta_sub)}</div>
      </div>'''

    # OWNER cell
    od = contract.get("owner_decisions", {}) or {}
    open_n = cs.get("owner_decisions_open")
    alert_n = cs.get("owner_decisions_alert") or 0
    # oldest wait
    owner_cell = f'''
      <div class="mc-cell">
        <div class="mc-cell-label">OWNER</div>
        <div class="mc-cell-main mc-num">{_int(open_n)}</div>
        <div class="mc-cell-sub"><span style="color:var(--fail)">{_int(alert_n)} alert</span>
          · {_int(od.get('q12_review_ready'))} Q12-ready</div>
      </div>'''

    return f'''
  <div class="mc-strip">
    {factory_cell}
    {fresh_cell}
    {queue_cell}
    {terminals_cell}
    {eta_cell}
    {owner_cell}
  </div>'''


_SEV_COLOR = {
    "alert": "var(--fail)", "action": "var(--fail)",
    "warn": "var(--warn)", "info": "var(--text-3)",
}


def _render_owner_decisions(contract: dict) -> str:
    od = contract.get("owner_decisions", {}) or {}
    items = od.get("items") or []
    count = int(od.get("count") or len(items))
    if count == 0:
        return ""
    shown = items[:5]
    rows = []
    for it in shown:
        sev = str(it.get("severity") or "info").lower()
        col = _SEV_COLOR.get(sev, "var(--text-3)")
        due = it.get("due")
        detail = it.get("detail") or ""
        rows.append(f'''
      <div class="mc-dec-row">
        <span class="mc-chip" style="color:{col};border-color:{col}">{e(sev.upper())}</span>
        <span class="mc-dec-cat">{e(it.get('category'))}</span>
        <div class="mc-dec-body">
          <div class="mc-dec-title mc-clip" title="{e(it.get('title'))}">{e(it.get('title'))}</div>
          <div class="mc-dec-detail mc-clip" title="{e(detail)}">{e(detail)}</div>
        </div>
        <span class="mc-dec-due">{e(due) if due else "—"}</span>
      </div>''')
    more = ""
    if count > 5:
        more = (f'<div class="mc-more">… {_int(count - 5)} weitere — '
                f'vollständige Liste: Vault <span class="mono">12 ToDo/AI ToDos/OWNER.md</span></div>')
    meta_badge = _stale_badge(od.get("meta", {}))
    return f'''
  <section class="mc-section">
    <div class="mc-h2"><span>Owner Decision Queue</span>
      <span class="mc-h2-aux">{_int(count)} offen · {_int(od.get('alert_count'))} alert {meta_badge}</span></div>
    <div class="mc-dec-list">
      {''.join(rows)}
    </div>
    {more}
  </section>'''


def _render_progress(contract: dict) -> str:
    pr = contract.get("progress", {}) or {}
    today = pr.get("today", {}) or {}
    yday = pr.get("yesterday", {}) or {}
    avg = pr.get("seven_day_average", {}) or {}
    total = pr.get("total", {}) or {}

    def cell(v, kind="int"):
        if kind == "int":
            return f'<td class="mc-num">{_int(v)}</td>'
        if kind == "avg":
            return f'<td class="mc-num">{_de(v, 1)}</td>'
        if kind == "pct":
            return f'<td class="mc-num">{_pct(v, 1)}</td>'
        return f'<td class="mc-num">{e(v)}</td>'

    def row(label, key, kind_total="int", dim=False):
        cls = ' class="mc-dim"' if dim else ""
        if kind_total == "pct":
            cells = (cell(today.get(key), "pct") + cell(yday.get(key), "pct")
                     + cell(avg.get(key), "pct") + cell(total.get(key), "pct"))
        else:
            cells = (cell(today.get(key)) + cell(yday.get(key))
                     + cell(avg.get(key), "avg") + cell(total.get(key)))
        return f'<tr{cls}><td class="mc-rowlabel">{e(label)}</td>{cells}</tr>'

    since = total.get("since")
    caveats = pr.get("caveats") or []
    cav_html = "".join(f"<li>{e(c)}</li>" for c in caveats)
    counting = pr.get("counting_basis") or ""
    phase_set = [p for p in (pr.get("phase_set") or []) if not re.match(r"^P\d", str(p))]
    phase_html = e(", ".join(phase_set))

    return f'''
  <section class="mc-section">
    <div class="mc-h2"><span>Fortschrittsvergleich</span>
      <span class="mc-h2-aux">einheitliche Zähllogik über alle Fenster</span></div>
    <table class="mc-table">
      <thead><tr>
        <th></th><th class="mc-num">Heute</th><th class="mc-num">Gestern</th>
        <th class="mc-num">7-Tage-Ø</th>
        <th class="mc-num">Gesamt<span class="mc-since">seit {e(str(since)[:10]) if since else "—"}</span></th>
      </tr></thead>
      <tbody>
        {row("erledigte Work Items", "completed")}
        {row("eindeutige EA/Symbol-Paare", "distinct_ea_symbol")}
        {row("Gate PASS", "gate_pass")}
        {row("wirtschaftliche FAIL", "economic_fail")}
        {row("Infra/Transient-Quote (%)", "infra_rate", kind_total="pct", dim=True)}
      </tbody>
    </table>
    <div class="mc-foot">
      <div class="mc-foot-line"><b>Zählbasis:</b> {e(counting)}</div>
      <div class="mc-foot-line"><b>Phasen (Qxx):</b> {phase_html}</div>
      <ul class="mc-caveats">{cav_html}</ul>
    </div>
  </section>'''


_STATE_STYLE = {
    "RUNNING": ("var(--signal)", "RUNNING"),
    "RESERVED": ("var(--promising)", "RESERVED"),
    "IDLE": ("var(--dead)", "IDLE"),
    "ERROR": ("var(--fail)", "ERROR"),
}


def _render_terminals(contract: dict, ea_page_exists=None) -> str:
    tsec = contract.get("terminals", {}) or {}
    terminals = tsec.get("terminals") or []
    cards = []
    for t in terminals:
        state = str(t.get("state") or "IDLE").upper()
        col, lbl = _STATE_STYLE.get(state, ("var(--text-3)", state))
        if state == "RUNNING":
            ea_id = t.get("ea_id")
            slug = t.get("ea_slug")
            wid = t.get("work_item_id")
            wid_short = e(str(wid)[:8]) if wid else "—"
            # link to ea_<id>.html only when the page exists next to this file
            if ea_id and ea_page_exists and ea_page_exists(ea_id):
                wid_cell = (f'<a href="ea_{e(ea_id)}.html">{wid_short}</a>')
            else:
                wid_cell = wid_short
            body = f'''
        <div class="mc-t-ea">{e(ea_id)}<span class="mc-t-slug">{e(slug) if slug else ""}</span></div>
        <div class="mc-t-row"><span class="mc-t-k">Symbol</span><span class="mc-t-v">{e(t.get('symbol'))}</span></div>
        <div class="mc-t-row"><span class="mc-t-k">Gate</span><span class="mc-t-v">{e(t.get('phase_qid'))} · {e(t.get('phase_name'))}</span></div>
        <div class="mc-t-row"><span class="mc-t-k">Start</span><span class="mc-t-v">{e(str(t.get('start_utc'))[:19])} · {_reltime_span(t.get('start_utc'), t.get('elapsed_seconds'))}</span></div>
        <div class="mc-t-row"><span class="mc-t-k">WI</span><span class="mc-t-v mc-mono">{wid_cell}</span></div>'''
        elif state == "RESERVED":
            resv = t.get("reservation") or {}
            body = f'''
        <div class="mc-t-idle">{e(t.get('idle_reason'))}</div>
        <div class="mc-t-row"><span class="mc-t-k">by</span><span class="mc-t-v">{e(resv.get('reserved_by'))}</span></div>
        <div class="mc-t-row"><span class="mc-t-k">until</span><span class="mc-t-v">{e(str(resv.get('until_utc'))[:19])}</span></div>'''
        else:
            body = f'''
        <div class="mc-t-idle">{e(t.get('idle_reason') or 'idle')}</div>'''
        cards.append(f'''
      <div class="mc-t-card">
        <div class="mc-t-head">
          <span class="mc-t-id">{e(t.get('terminal'))}</span>
          <span class="mc-chip" style="color:{col};border-color:{col}">{e(lbl)}</span>
        </div>{body}
      </div>''')
    badge = _stale_badge(tsec.get("meta", {}))
    counts = tsec.get("counts", {})
    return f'''
  <section class="mc-section">
    <div class="mc-h2"><span>Terminal Board T1–T10</span>
      <span class="mc-h2-aux">{_int(counts.get('running'))} running · {_int(counts.get('idle'))} idle {badge}</span></div>
    <div class="mc-t-grid">
      {''.join(cards)}
    </div>
  </section>'''


def _render_queue(contract: dict) -> str:
    q = contract.get("queue", {}) or {}
    br = queue_breakdown(contract)
    ex = q.get("by_phase_executable") or []
    parked = q.get("by_phase_parked") or []

    def qrow(r):
        return (f'<tr><td class="mc-rowlabel">{e(r.get("phase_qid"))} · {e(r.get("phase_name"))}</td>'
                f'<td class="mc-num">{_int(r.get("pending"))}</td>'
                f'<td class="mc-mono mc-agecell">{e(str(r.get("oldest_created_at"))[:19])}</td></tr>')

    ex_rows = "".join(qrow(r) for r in ex)
    parked_rows = "".join(qrow(r) for r in parked)

    # bottleneck = phase with the largest executable backlog
    notes = q.get("notes") or ""
    bottleneck = ""
    if ex:
        top = max(ex, key=lambda r: int(r.get("pending") or 0))
        bottleneck = (f'<div class="mc-bottleneck"><b>Engpass:</b> '
                      f'{e(top.get("phase_qid"))} · {e(top.get("phase_name"))} '
                      f'({_int(top.get("pending"))} pending). {e(notes)}</div>')

    eta = q.get("eta_to_empty", {}) or {}
    basis = eta.get("basis") or ""
    p50 = eta.get("eta_hours_p50")
    p90 = eta.get("eta_hours_p90")
    tph = eta.get("throughput_per_hour_24h")
    if p50 is not None:
        eta_line = (f'P50 ~{_de(p50 / 24.0, 1)} T ({_de(p50, 0)} h) · '
                    f'P90 ~{_de(p90 / 24.0, 1)} T ({_de(p90, 0)} h)')
    else:
        eta_line = "keine 24 h-Durchsatzmessung (rate=0)"

    badge = _stale_badge(q.get("meta", {}))
    return f'''
  <section class="mc-section">
    <div class="mc-h2"><span>Queue &amp; Engpass</span>
      <span class="mc-h2-aux">Σ {_int(br['pending_total'])} pending = {_int(br['pending_executable'])} executable + {_int(br['pending_parked'])} parked {badge}</span></div>
    <div class="mc-queue-grid">
      <div>
        <div class="mc-sublabel">Executable (terminal-drainable)</div>
        <table class="mc-table">
          <thead><tr><th>Gate</th><th class="mc-num">Pending</th><th>ältester Eintrag</th></tr></thead>
          <tbody>{ex_rows}</tbody>
        </table>
      </div>
      <div>
        <div class="mc-sublabel">Parked — operator-gated, zählt nicht in die ETA</div>
        <table class="mc-table">
          <thead><tr><th>Gate</th><th class="mc-num">Pending</th><th>ältester Eintrag</th></tr></thead>
          <tbody>{parked_rows}</tbody>
        </table>
      </div>
    </div>
    {bottleneck}
    <div class="mc-foot">
      <div class="mc-foot-line"><b>Clear-ETA:</b> {eta_line} · Durchsatz {_de(tph, 2)}/h (24 h)</div>
      <div class="mc-foot-line mc-dim">{e(basis)}</div>
    </div>
  </section>'''


def _render_exceptions(contract: dict) -> str:
    boxes = []
    stale_sections = []
    for name in ("control_strip", "queue", "progress", "terminals", "owner_decisions"):
        sec = contract.get(name, {}) or {}
        meta = sec.get("meta", {}) or {}
        dr = meta.get("degraded_reason")
        if dr:
            boxes.append(f'<div class="mc-exbox"><b>{e(name)}</b> — {e(dr)}</div>')
        if str(meta.get("staleness") or "").upper() == "STALE":
            stale_sections.append(name)

    pr = contract.get("progress", {}) or {}
    caveats = pr.get("caveats") or []
    cs = contract.get("control_strip", {}) or {}
    hfc = cs.get("health_fail_count")

    stale_html = ""
    if stale_sections:
        stale_html = (f'<div class="mc-foot-line"><b>STALE-Sektionen:</b> '
                      f'{e(", ".join(stale_sections))}</div>')
    cav_html = "".join(f"<li>{e(c)}</li>" for c in caveats)
    health_html = (f'<div class="mc-foot-line"><b>health FAIL:</b> {_int(hfc)} '
                   f'— Detail: farmctl health / Heartbeat</div>')

    has_content = bool(boxes or stale_sections or caveats or (hfc and int(hfc) > 0))
    open_attr = " open" if has_content else ""
    boxes_html = "".join(boxes)
    inner = f'''
      {boxes_html}
      {stale_html}
      {health_html if hfc else ""}
      <ul class="mc-caveats">{cav_html}</ul>'''
    if not has_content:
        inner = '<div class="mc-foot-line mc-dim">keine Ausnahmen — alle Sektionen frisch.</div>'
    return f'''
  <details class="mc-section mc-details"{open_attr}>
    <summary class="mc-h2"><span>Ausnahmen &amp; Datenqualität</span>
      <span class="mc-h2-aux">degraded / stale / caveats</span></summary>
    <div class="mc-ex-body">{inner}</div>
  </details>'''


# ---------------------------------------------------------------------------
# page-grid CSS (ONLY var(--*) tokens; no new colours; radius 0; flat)
# ---------------------------------------------------------------------------
_PAGE_CSS = """
  .mc-wrap{max-width:1280px;margin:0 auto;padding:var(--space-6) var(--space-8) var(--space-16)}
  .mc-topbar{display:flex;justify-content:space-between;align-items:baseline;gap:var(--space-4);
    flex-wrap:wrap;margin-bottom:var(--space-4)}
  .mc-title{font-family:var(--font-mono);font-size:var(--fs-md);font-weight:700;
    letter-spacing:0.16em;text-transform:uppercase;color:var(--text)}
  .mc-title .mc-accent{color:var(--signal)}
  .mc-topaux{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    letter-spacing:0.08em;display:flex;gap:var(--space-3);align-items:center;flex-wrap:wrap}
  .mc-badge{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:700;
    letter-spacing:0.12em;padding:var(--space-1) var(--space-2);border:1px solid var(--border-2);
    color:var(--text-3)}
  .mc-badge-warn{color:var(--warn);border-color:var(--warn)}
  .mc-badge-ok{color:var(--pass);border-color:var(--pass)}

  .mc-strip{position:sticky;top:0;z-index:var(--z-nav);display:grid;
    grid-template-columns:repeat(6,1fr);gap:0;border:1px solid var(--border-2);
    background:var(--surface-1);margin-bottom:var(--space-8)}
  .mc-cell{padding:var(--space-3) var(--space-4);border-right:1px solid var(--border);
    display:flex;flex-direction:column;gap:var(--space-1);min-width:0}
  .mc-cell:last-child{border-right:none}
  .mc-cell-label{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:600;
    color:var(--text-3);letter-spacing:0.16em;text-transform:uppercase}
  .mc-cell-main{font-family:var(--font-mono);font-size:var(--fs-xl);font-weight:500;
    color:var(--text);line-height:1.1;display:flex;align-items:center;gap:var(--space-2)}
  .mc-cell-slash{color:var(--text-3);font-size:var(--fs-md)}
  .mc-cell-sub{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    line-height:var(--lh-normal)}
  .mc-clip{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .mc-dot{width:10px;height:10px;flex-shrink:0}
  .mc-num{font-family:var(--font-mono);font-variant-numeric:tabular-nums;
    font-feature-settings:"tnum";text-align:right}
  .mc-mono{font-family:var(--font-mono)}

  .mc-section{margin-bottom:var(--space-8);border:1px solid var(--border);
    background:var(--surface-1);padding:var(--space-5) var(--space-6)}
  .mc-h2{display:flex;justify-content:space-between;align-items:baseline;gap:var(--space-4);
    margin-bottom:var(--space-4);border-bottom:1px solid var(--border);
    padding-bottom:var(--space-2);flex-wrap:wrap}
  .mc-h2>span:first-child{font-family:var(--font-mono);font-size:var(--fs-md);font-weight:700;
    letter-spacing:0.08em;color:var(--text)}
  .mc-h2-aux{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    letter-spacing:0.06em;display:flex;gap:var(--space-2);align-items:center;flex-wrap:wrap}

  .mc-table{width:100%;border-collapse:collapse;font-family:var(--font-mono);
    font-size:var(--fs-sm)}
  .mc-table th{text-align:left;padding:var(--space-2) var(--space-3);font-size:var(--fs-xs);
    font-weight:700;color:var(--text-3);text-transform:uppercase;letter-spacing:0.12em;
    border-bottom:1px solid var(--border)}
  .mc-table th.mc-num{text-align:right}
  .mc-table td{padding:var(--space-2) var(--space-3);border-bottom:1px solid var(--border);
    color:var(--text-2)}
  .mc-table td.mc-num{color:var(--text)}
  .mc-rowlabel{font-family:var(--font-sans);color:var(--text-2)}
  .mc-dim,.mc-dim td{color:var(--text-3)}
  .mc-since{display:block;font-family:var(--font-mono);font-size:var(--fs-xs);
    font-weight:400;color:var(--text-4);letter-spacing:0.04em;text-transform:none}
  .mc-agecell{color:var(--text-3);font-size:var(--fs-xs)}

  .mc-foot{margin-top:var(--space-3);font-size:var(--fs-xs);color:var(--text-3);
    line-height:var(--lh-normal)}
  .mc-foot-line{margin-bottom:var(--space-1)}
  .mc-foot-line b{color:var(--text-2)}
  .mc-caveats{list-style:none;margin-top:var(--space-2)}
  .mc-caveats li{font-size:var(--fs-xs);color:var(--text-4);line-height:var(--lh-normal);
    padding-left:var(--space-3);position:relative;margin-bottom:var(--space-1)}
  .mc-caveats li::before{content:'·';position:absolute;left:0;color:var(--text-4)}

  .mc-dec-list{display:flex;flex-direction:column}
  .mc-dec-row{display:grid;grid-template-columns:auto auto 1fr auto;gap:var(--space-3);
    align-items:center;padding:var(--space-2) 0;border-bottom:1px solid var(--border)}
  .mc-dec-row:last-child{border-bottom:none}
  .mc-chip{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:700;
    letter-spacing:0.1em;padding:var(--space-1) var(--space-2);border:1px solid var(--border-2);
    white-space:nowrap}
  .mc-dec-cat{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    white-space:nowrap}
  .mc-dec-body{min-width:0}
  .mc-dec-title{font-size:var(--fs-sm);color:var(--text)}
  .mc-dec-detail{font-size:var(--fs-xs);color:var(--text-2);font-style:italic}
  .mc-dec-due{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    white-space:nowrap;text-align:right}
  .mc-more{margin-top:var(--space-3);font-family:var(--font-mono);font-size:var(--fs-xs)}
  .mc-more a{color:var(--signal)}

  .mc-t-grid{display:grid;grid-template-columns:repeat(5,1fr);gap:var(--space-3)}
  .mc-t-card{border:1px solid var(--border);background:var(--surface-2);
    padding:var(--space-3);display:flex;flex-direction:column;gap:var(--space-2);min-width:0}
  .mc-t-head{display:flex;justify-content:space-between;align-items:center;gap:var(--space-2)}
  .mc-t-id{font-family:var(--font-mono);font-size:var(--fs-lg);font-weight:700;color:var(--text)}
  .mc-t-ea{font-family:var(--font-mono);font-size:var(--fs-sm);color:var(--signal);
    white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .mc-t-slug{display:block;font-size:var(--fs-xs);color:var(--text-3);font-family:var(--font-sans);
    white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .mc-t-row{display:flex;justify-content:space-between;gap:var(--space-2);font-size:var(--fs-xs);
    min-width:0}
  .mc-t-k{font-family:var(--font-mono);color:var(--text-4);text-transform:uppercase;
    letter-spacing:0.08em;flex-shrink:0}
  .mc-t-v{font-family:var(--font-mono);color:var(--text-2);text-align:right;
    white-space:nowrap;overflow:hidden;text-overflow:ellipsis;min-width:0}
  .mc-t-v a{color:var(--signal)}
  .mc-t-idle{font-size:var(--fs-xs);color:var(--text-3);font-style:italic;line-height:var(--lh-normal)}

  .mc-queue-grid{display:grid;grid-template-columns:1fr 1fr;gap:var(--space-6)}
  .mc-sublabel{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:600;
    color:var(--text-3);letter-spacing:0.1em;text-transform:uppercase;margin-bottom:var(--space-2)}
  .mc-bottleneck{margin-top:var(--space-4);padding:var(--space-3);border:1px solid var(--border-2);
    background:var(--surface-2);font-size:var(--fs-sm);color:var(--text-2)}
  .mc-bottleneck b{color:var(--warn)}

  .mc-details{padding:0}
  .mc-details>summary{cursor:pointer;list-style:none;padding:var(--space-5) var(--space-6);
    margin-bottom:0;border-bottom:1px solid var(--border)}
  .mc-details>summary::-webkit-details-marker{display:none}
  .mc-ex-body{padding:var(--space-5) var(--space-6)}
  .mc-exbox{border:1px solid var(--fail);padding:var(--space-3);margin-bottom:var(--space-3);
    font-family:var(--font-mono);font-size:var(--fs-sm);color:var(--text-2)}
  .mc-exbox b{color:var(--fail)}

  .mc-footer{border-top:1px solid var(--border);margin-top:var(--space-8);
    padding-top:var(--space-4);font-family:var(--font-mono);font-size:var(--fs-xs);
    color:var(--text-4);display:flex;gap:var(--space-4);flex-wrap:wrap;
    justify-content:space-between;letter-spacing:0.04em}
  .mc-footer .mc-shadow{color:var(--warn)}

  @media(max-width:1200px){
    .mc-t-grid{grid-template-columns:repeat(2,1fr)}
    .mc-strip{grid-template-columns:repeat(3,1fr)}
    .mc-cell:nth-child(3n){border-right:none}
    .mc-queue-grid{grid-template-columns:1fr}
  }
  @media(max-width:720px){
    .mc-strip{grid-template-columns:repeat(2,1fr)}
    .mc-cell{border-right:none}
    .mc-t-grid{grid-template-columns:1fr}
    .mc-dec-row{grid-template-columns:auto 1fr}
  }
"""


_REL_SCRIPT = """
(function(){
  function fmt(ms){
    var s=Math.max(0,Math.floor((Date.now()-ms)/1000));
    if(s<60)return 'vor '+s+'s';
    var m=Math.floor(s/60);
    if(m<60)return 'vor '+m+' min';
    var h=Math.floor(m/60);
    return 'vor '+h+' h '+(m%60)+' min';
  }
  function tick(){
    var els=document.querySelectorAll('.mc-rel[data-epoch-ms]');
    for(var i=0;i<els.length;i++){
      var ms=parseInt(els[i].getAttribute('data-epoch-ms'),10);
      if(!isNaN(ms))els[i].textContent=fmt(ms);
    }
  }
  tick();
  setInterval(tick,30000);
})();
"""


# ---------------------------------------------------------------------------
# top-level render
# ---------------------------------------------------------------------------
def render(contract: dict, *, from_json: bool = False, source_path: str | None = None,
           duration_ms: float | None = None, ea_page_exists=None) -> str:
    """Render the full ``qm.mission_control.v2`` contract to an HTML document."""
    generated_at = contract.get("generated_at") or ""
    schema = contract.get("schema_version") or ""
    source_db = contract.get("source_db") or ""

    # Header STALE badge: any critical readmodel STALE, or a from-json snapshot.
    cs = contract.get("control_strip", {}) or {}
    any_stale = bool((cs.get("data_freshness") or {}).get("any_stale"))
    header_badges = []
    if from_json:
        age = None
        ems = _epoch_ms(generated_at)
        if ems is not None:
            age = max(0, int(time.time() * 1000 - ems) // 1000)
        header_badges.append(
            f'<span class="mc-badge mc-badge-warn" title="rendered from snapshot '
            f'{e(source_path)}">STALE · SNAPSHOT · {_reltime_from_seconds(age)}</span>'
        )
    if any_stale:
        header_badges.append('<span class="mc-badge mc-badge-warn">STALE READMODEL</span>')
    badges_html = "".join(header_badges)

    body = "".join([
        _render_control_strip(contract),
        _render_owner_decisions(contract),
        _render_progress(contract),
        _render_terminals(contract, ea_page_exists=ea_page_exists),
        _render_queue(contract),
        _render_exceptions(contract),
    ])

    dur = f"{duration_ms:.0f} ms" if duration_ms is not None else "—"
    gen_span = _reltime_span(generated_at, prefix="")

    return (
        "<!doctype html>\n<html lang=\"en\">\n<head>\n"
        "<meta charset=\"utf-8\">\n"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
        "<title>QuantMechanica // MISSION CONTROL</title>\n"
        "<link rel=\"stylesheet\" href=\"style.css\">\n"
        "<style>\n" + _PAGE_CSS + "\n</style>\n"
        "</head>\n<body>\n"
        "<div class=\"mc-wrap\">\n"
        "  <div class=\"mc-topbar\">\n"
        "    <div class=\"mc-title\">Mission <span class=\"mc-accent\">Control</span> v2 "
        "<span style=\"color:var(--warn)\">· SHADOW</span></div>\n"
        f"    <div class=\"mc-topaux\">{badges_html}"
        f"<span>generated {e(str(generated_at)[:19])} · {gen_span}</span></div>\n"
        "  </div>\n"
        + body +
        "\n  <div class=\"mc-footer\">\n"
        f"    <span>{e(schema)} · {e(source_db)}</span>\n"
        f"    <span>generated_at {e(generated_at)} · Renderdauer {e(dur)}</span>\n"
        "    <span class=\"mc-shadow\"><a href=\"cockpit_advanced.html\">Advanced (Legacy-Cockpit)</a>"
        " · MC-v2 primär seit OWNER-Abnahme 2026-08-21</span>\n"
        "  </div>\n"
        "</div>\n"
        "<script>\n" + _REL_SCRIPT + "\n</script>\n"
        "</body>\n</html>\n"
    )


def _ea_page_exists_factory(output_dir: Path):
    def _exists(ea_id: str) -> bool:
        try:
            return (output_dir / f"ea_{ea_id}.html").exists()
        except OSError:
            return False
    return _exists


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--db", type=Path, default=None,
                        help="override farm_state.sqlite path (fresh build)")
    parser.add_argument("--from-json", type=Path, default=None,
                        help="render from a contract snapshot JSON instead of a fresh build")
    parser.add_argument("--output", type=Path, default=OUTPUT_PATH,
                        help="output HTML path (default: primary cockpit.html; cockpit_v2.html alias is co-written)")
    parser.add_argument("--stdout", action="store_true",
                        help="also print the HTML to stdout")
    args = parser.parse_args(argv)

    t0 = time.perf_counter()
    from_json = False
    source_path = None
    if args.from_json is not None:
        from_json = True
        source_path = str(args.from_json)
        contract = json.loads(Path(args.from_json).read_text(encoding="utf-8-sig"))
    else:
        contract = build_contract(args.db)
    dur_ms = (time.perf_counter() - t0) * 1000.0

    output = Path(args.output)
    doc = render(contract, from_json=from_json, source_path=source_path,
                 duration_ms=dur_ms,
                 ea_page_exists=_ea_page_exists_factory(output.parent))

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(doc, encoding="utf-8", newline="\n")
    if output == OUTPUT_PATH:
        ALIAS_PATH.write_text(doc, encoding="utf-8", newline="\n")
    if args.stdout:
        sys.stdout.write(doc)

    cs = contract.get("control_strip", {})
    # Under pythonw.exe (scheduled task) sys.stderr is None; never let the
    # success-path summary raise after the artifact has been written.
    _err = sys.stderr if sys.stderr is not None else open(os.devnull, "w", encoding="utf-8")
    _err.write(
        f"[render_cockpit_v2] factory={cs.get('factory_state')} "
        f"terminals_running={(contract.get('terminals') or {}).get('counts', {}).get('running')} "
        f"owner_open={cs.get('owner_decisions_open')} "
        f"bytes={len(doc)} -> {output}\n"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
