"""Mission Control v2 — primary cockpit renderer (``qm.mission_control.v2``).

Renders the Mission Control v2 data contract to a single self-contained HTML
page at ``D:\\QM\\strategy_farm\\dashboards\\cockpit_v2.html`` — a **shadow**
surface that runs in parallel to the live ``cockpit.html`` until the OWNER
signs it off. This module makes **zero data decisions**: it imports
``build_contract`` from ``mission_control_v2_data`` and binds the emitted
fields verbatim (Single Source of Truth). Design is fixed by
``docs/ops/MISSION_CONTROL_V2_RENDER_SPEC.md`` (the orchestrator's design lane).

Hard rendering discipline:

  * OWNER controls write document-only receipts through a loopback service.
    They can never touch factory / deploy / T_Live / AutoTrading; execution
    remains a separate governed workflow.
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
    from tools.strategy_farm.operator_surfaces import (
        compact_operator_snapshot,
        render_frontier_explorer_html,
        render_operator_surface_html,
    )
except ModuleNotFoundError:  # direct ``python tools/strategy_farm/render_cockpit_v2.py``
    from mission_control_v2_data import build_contract
    from operator_surfaces import (
        compact_operator_snapshot,
        render_frontier_explorer_html,
        render_operator_surface_html,
    )


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
          · {_int(cs.get('owner_executions_open'))} Umsetzung · {_int(od.get('q12_review_ready'))} Q12-ready</div>
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


def _render_execution_plan_choice(label: str, plan: dict) -> str:
    if not plan:
        return '<div class="mc-plan-choice mc-plan-missing">Plan nicht verfuegbar</div>'
    actions = "".join(f"<li>{e(value)}</li>" for value in (plan.get("allowed_actions") or []))
    acceptance = "".join(f"<li>{e(value)}</li>" for value in (plan.get("acceptance") or []))
    return f'''
          <div class="mc-plan-choice" data-plan-choice="{e(label)}">
            <div class="mc-plan-head"><b>{e(label)}</b><code>{e(plan.get('mode'))}</code></div>
            <div class="mc-plan-impact"><b>Impact</b><span>{e(plan.get('impact'))}</span></div>
            <div><b>Erlaubte Schritte</b><ul>{actions}</ul></div>
            <div><b>Pruefbedingungen</b><ul>{acceptance}</ul></div>
            <div class="mc-plan-containment"><b>Rueckweg / Containment</b>
              <span>{e(plan.get('containment'))}</span></div>
          </div>'''


def _render_owner_decisions(contract: dict) -> str:
    od = contract.get("owner_decisions", {}) or {}
    items = od.get("items") or []
    executions = od.get("executions") or []
    count = int(od.get("count") or len(items))
    if count == 0 and not executions:
        return ""
    intake = od.get("intake", {}) or {}
    enabled = bool(intake.get("enabled") and intake.get("token"))
    service_disabled = "" if enabled else " disabled"
    categories = sorted({str(item.get("category") or "DECISION") for item in items})
    category_options = "".join(
        f'<option value="{e(category.lower())}">{e(category)}</option>'
        for category in categories
    )
    rows = []
    for index, it in enumerate(items):
        sev = str(it.get("severity") or "info").lower()
        col = _SEV_COLOR.get(sev, "var(--text-3)")
        due = it.get("due")
        detail = it.get("detail") or ""
        decision_id = str(it.get("id") or f"OWNER-UNPREPARED-{index + 1:03d}")
        question = it.get("question") or it.get("title") or "?"
        recommendation = it.get("recommendation") or (
            "VERTAGT — dieser Eintrag ist noch nicht als vollständiger Entscheid aufbereitet."
        )
        yes_effect = it.get("yes_effect") or "Nur die Antwort wird dokumentiert."
        no_effect = it.get("no_effect") or "Nur die Antwort wird dokumentiert."
        cost = it.get("cost_of_wait") or "nicht angegeben"
        status = str(it.get("status") or "OPEN").upper()
        execution_plan = it.get("execution_plan") or {}
        execution_ready = bool(execution_plan.get("ready"))
        plan_hash = str(execution_plan.get("plan_sha256") or "")
        card_hash = str(it.get("decision_card_sha256") or "")
        choices = execution_plan.get("choices") or {}
        yes_plan = choices.get("YES") or {}
        no_plan = choices.get("NO") or {}
        terminal_disabled = "" if enabled and execution_ready else " disabled"
        plan_badge = (
            '<span class="mc-badge mc-badge-ok">CLAUDE READY</span>'
            if execution_ready else
            '<span class="mc-badge mc-badge-warn">HANDOFF-PLAN FEHLT</span>'
        )
        evidence = " · ".join(str(value) for value in (it.get("evidence") or []))
        evidence_html = (
            f'<div class="mc-dec-evidence"><b>Evidenz:</b> {e(evidence)}</div>'
            if evidence else ""
        )
        dependencies = [str(value) for value in (it.get("depends_on") or [])]
        dependency_html = (
            '<div class="mc-dec-deps"><b>Abhaengigkeiten:</b> '
            + " · ".join(f"<code>{e(value)}</code>" for value in dependencies)
            + "</div>"
            if dependencies else
            '<div class="mc-dec-deps"><b>Abhaengigkeiten:</b> keine</div>'
        )
        plan_html = ""
        if execution_ready:
            plan_html = f'''
        <details class="mc-dec-plan">
          <summary>Claude-Ausfuehrungsplan, Pruefbedingungen und Rueckweg</summary>
          <div class="mc-plan-grid">
            {_render_execution_plan_choice('JA', yes_plan)}
            {_render_execution_plan_choice('NEIN', no_plan)}
          </div>
          <div class="mc-plan-hash">Planbindung <code>{e(plan_hash)}</code></div>
        </details>'''
        search_text = " ".join(
            str(value or "") for value in (
                decision_id, it.get("category"), status, question, recommendation, detail
            )
        ).lower()
        rows.append(f'''
      <article class="mc-dec-row" data-decision-id="{e(decision_id)}"
        data-decision-category="{e(str(it.get('category') or '').lower())}"
        data-decision-status="{e(status.lower())}"
        data-decision-severity="{e(sev)}"
        data-decision-search="{e(search_text)}"
        data-decision-card-sha256="{e(card_hash)}"
        data-execution-plan-sha256="{e(plan_hash)}">
        <div class="mc-dec-head">
          <span class="mc-chip" style="color:{col};border-color:{col}">{e(sev.upper())}</span>
          <span class="mc-dec-status">{e(status)}</span>
          <span class="mc-dec-cat">{e(it.get('category'))}</span>
          <code>{e(decision_id)}</code>
          {plan_badge}
          <span class="mc-dec-due">{e(due) if due else "ohne Frist"}</span>
        </div>
        <div class="mc-dec-question">{e(question)}</div>
        <div class="mc-dec-rec"><b>Empfehlung:</b> {e(recommendation)}</div>
        <div class="mc-dec-effects">
          <div><b>Bei JA</b><span>{e(yes_effect)}</span></div>
          <div><b>Bei NEIN</b><span>{e(no_effect)}</span></div>
          <div><b>Cost of Wait</b><span>{e(cost)}</span></div>
        </div>
        <div class="mc-dec-detail">{e(detail)}</div>
        {evidence_html}
        {dependency_html}
        {plan_html}
        <div class="mc-dec-controls">
          <label for="mc-note-{index}">OWNER-Notiz</label>
          <textarea id="mc-note-{index}" maxlength="4000" rows="2"
            placeholder="Optional: Begründung, Bedingung oder Wiedervorlage"{service_disabled}></textarea>
          <div class="mc-dec-buttons">
            <button type="button" data-decision-choice="YES"
              data-decision-effect="{e(yes_effect)}"
              data-plan-mode="{e(yes_plan.get('mode'))}"
              data-plan-impact="{e(yes_plan.get('impact'))}"
              data-plan-containment="{e(yes_plan.get('containment'))}"{terminal_disabled}>JA</button>
            <button type="button" data-decision-choice="NO"
              data-decision-effect="{e(no_effect)}"
              data-plan-mode="{e(no_plan.get('mode'))}"
              data-plan-impact="{e(no_plan.get('impact'))}"
              data-plan-containment="{e(no_plan.get('containment'))}"{terminal_disabled}>NEIN</button>
            <button type="button" data-decision-choice="DEFERRED"
              data-decision-effect="Keine Umsetzung; Entscheidung bleibt offen."{service_disabled}>VERTAGT</button>
          </div>
          <div class="mc-dec-result" role="status" aria-live="polite"></div>
        </div>
      </article>''')
    execution_rows = []
    for execution in executions:
        ex_status = str(execution.get("status") or "UNKNOWN")
        sla = execution.get("sla") or {}
        sla_state = str(sla.get("state") or "UNKNOWN")
        sla_colour = (
            "var(--fail)" if sla_state == "BREACH" else
            "var(--warn)" if sla_state in {"WARN", "PENDING"} else
            "var(--pass)" if sla_state == "MET" else "var(--signal)"
        )
        if execution.get("complete"):
            colour = "var(--pass)"
        elif ex_status in {"FAILED", "BLOCKED", "OPS_FIX_REQUIRED"}:
            colour = "var(--fail)"
        elif ex_status in {"RUNNING", "AWAITING_REVIEW", "ACCEPTED", "RECYCLE"}:
            colour = "var(--warn)"
        else:
            colour = "var(--signal)"
        artifact = execution.get("artifact_path") or "Evidenz noch ausstehend"
        execution_rows.append(f'''
      <article class="mc-exec-row">
        <div class="mc-exec-head">
          <span class="mc-chip" style="color:{colour};border-color:{colour}">{e(ex_status)}</span>
          <span class="mc-chip" style="color:{sla_colour};border-color:{sla_colour}">
            SLA {e(sla_state)}</span>
          <code>{e(execution.get('decision_id'))}</code>
          <b>{e(execution.get('decision'))}</b>
          <span>{e(execution.get('assigned_agent') or 'noch nicht geroutet')}</span>
        </div>
        <div class="mc-exec-question">{e(execution.get('question') or '')}</div>
        <div class="mc-exec-meta">Task <code>{e(execution.get('task_id'))}</code> ·
          State {e(execution.get('task_state') or 'PENDING')} · Stage {e(sla.get('stage'))} ·
          Alter {_reltime_from_seconds(sla.get('age_seconds'))} · {e(artifact)}</div>
        <div class="mc-exec-verdict">{e(execution.get('verdict') or '')}</div>
      </article>''')
    execution_html = ""
    if execution_rows:
        execution_html = f'''
    <div class="mc-exec-block">
      <div class="mc-h3">Entscheidung → Umsetzung
        <span>{_int(od.get('execution_open_count'))} offen · {_int(len(executions))} gesamt</span></div>
      <div class="mc-exec-list">{''.join(execution_rows)}</div>
    </div>'''
    meta_badge = _stale_badge(od.get("meta", {}))
    service_label = (
        '<span class="mc-badge mc-badge-ok" data-decision-service-state>INTAKE BEREIT</span>'
        if enabled else
        '<span class="mc-badge mc-badge-warn" data-decision-service-state>INTAKE AUS</span>'
    )
    degraded = intake.get("degraded_reason")
    degraded_html = (
        f'<div class="mc-exbox">Entscheidungsdienst: {e(degraded)}</div>'
        if degraded else ""
    )
    router = od.get("router_health") or {}
    router_state = str(router.get("state") or "UNKNOWN")
    router_colour = (
        "var(--pass)" if router_state == "HEALTHY" else
        "var(--warn)" if router_state == "DEGRADED" else "var(--fail)"
    )
    router_age = _reltime_from_seconds(router.get("last_reconcile_age_seconds"))
    router_html = f'''
    <div class="mc-router-health" style="border-color:{router_colour}">
      <span class="mc-chip" style="color:{router_colour};border-color:{router_colour}">
        ROUTER {e(router_state)}</span>
      <span>Letzter bestaetigter Receipt-Reconcile: {e(router_age)} ·
        {_int(router.get('consecutive_router_failures'))} allgemeine Router-Fehler in Folge.</span>
      <span>{"Claude-Zuweisung kann verzoegert sein." if router.get('assignment_may_be_delayed') else "Zuweisungs-SLA im Soll."}</span>
    </div>'''
    return f'''
  <section class="mc-section mc-decisions" id="owner-decisions"
    data-intake-enabled="{str(enabled).lower()}"
    data-intake-endpoint="{e(intake.get('endpoint') or '')}"
    data-intake-token="{e(intake.get('token') or '')}">
    <div class="mc-h2"><span>Owner Decision Queue</span>
      <span class="mc-h2-aux">{_int(count)} offen/vertagt · {_int(od.get('alert_count'))} alert ·
        {_int(od.get('execution_open_count'))} Umsetzungen offen {service_label} {meta_badge}</span></div>
    <div class="mc-dec-boundary"><b>Ausführungskette:</b> JA oder NEIN erzeugt nach dem
      unveränderlichen Receipt genau einen begrenzten Claude-Router-Auftrag. VERTAGT erzeugt
      keinen Auftrag. Der Klick selbst führt nichts an Factory oder Live-Systemen aus; T_Live,
      AutoTrading und Deployments bleiben separat gesperrt.</div>
    {router_html}
    {degraded_html}
    <div class="mc-dec-tools" aria-label="Entscheidungen filtern">
      <input type="search" data-decision-filter-search placeholder="Entscheidungen durchsuchen">
      <select data-decision-filter-category>
        <option value="">Alle Kategorien</option>{category_options}
      </select>
      <select data-decision-filter-status>
        <option value="">Alle Status</option>
        <option value="open">OPEN</option>
        <option value="deferred">DEFERRED</option>
      </select>
      <select data-decision-filter-severity>
        <option value="">Alle Prioritaeten</option>
        <option value="alert">ALERT</option><option value="action">ACTION</option>
        <option value="warn">WARN</option><option value="info">INFO</option>
      </select>
      <span data-decision-filter-count>{_int(count)} sichtbar</span>
    </div>
    <div class="mc-dec-list">
      {''.join(rows)}
    </div>
    {execution_html}
  </section>'''


def _render_risk_freeze(contract: dict) -> str:
    freeze = contract.get("risk_freeze", {}) or {}
    status = str(freeze.get("status") or "UNKNOWN")
    held = freeze.get("held")
    if status == "ACTIVE" and held is True:
        colour, held_label = "var(--pass)", "JA"
    elif status == "ACTIVE" and held is False:
        colour, held_label = "var(--fail)", "NEIN"
    elif held is None:
        colour, held_label = "var(--warn)", "—"
    else:
        colour, held_label = "var(--warn)", "NEIN"

    conditions = freeze.get("lift_conditions") or []
    rows = []
    for condition in conditions:
        if not isinstance(condition, dict):
            continue
        detail = condition.get("blocked_by") or condition.get("requirement") or "—"
        rows.append(f'''
        <tr>
          <td class="mono">{e(condition.get('id'))}</td>
          <td>{e(condition.get('status') or 'OPEN')}</td>
          <td title="{e(detail)}">{e(condition.get('requirement') or detail)}</td>
        </tr>''')
    drift = freeze.get("drift") or []
    drift_html = "".join(f"<li>{e(item)}</li>" for item in drift)
    if not drift_html:
        drift_html = "<li>keine Abweichung gemeldet</li>"

    return f'''
  <section class="mc-section" id="risk-freeze">
    <div class="mc-h2"><span>Live Risk Freeze</span>
      <span class="mc-h2-aux"><span class="mc-dot" style="background:{colour}"></span>
        {e(status)} · held {held_label} {_stale_badge(freeze.get('meta', {}))}</span></div>
    <table class="mc-table">
      <thead><tr><th></th><th class="mc-num">Baseline</th><th class="mc-num">Ist</th></tr></thead>
      <tbody>
        <tr><td class="mc-rowlabel">Sleeves</td><td class="mc-num">{_int(freeze.get('baseline_sleeve_count'))}</td>
          <td class="mc-num">{_int(freeze.get('current_sleeve_count'))}</td></tr>
        <tr><td class="mc-rowlabel">Total RISK_PERCENT</td>
          <td class="mc-num">{_de(freeze.get('baseline_total_risk_percent'), 4)}</td>
          <td class="mc-num">{_de(freeze.get('current_total_risk_percent'), 4)}</td></tr>
      </tbody>
    </table>
    <div class="mc-foot">
      <div class="mc-foot-line"><b>Abweichung:</b><ul>{drift_html}</ul></div>
      <div class="mc-foot-line"><b>Lift-Regel:</b> {e(freeze.get('lift_rule') or 'explicit written OWNER lift required')}</div>
    </div>
    <table class="mc-table">
      <thead><tr><th>Lift-Bedingung</th><th>Status</th><th>Anforderung</th></tr></thead>
      <tbody>{''.join(rows)}</tbody>
    </table>
  </section>'''


def _render_q09_ftmo_recommendation(contract: dict) -> str:
    recommendation = contract.get("q09_ftmo_recommendation") or {}
    if not recommendation:
        return ""
    available = recommendation.get("available") is True
    yes = int(recommendation.get("suitable_yes") or 0)
    no = int(recommendation.get("suitable_no") or 0)
    total = int(recommendation.get("total") or 0)
    reasons = recommendation.get("reason_counts") or {}
    reason_rows = "".join(
        f'<tr><td class="mono">{e(reason)}</td><td class="mc-num">{_int(count)}</td></tr>'
        for reason, count in sorted(reasons.items())
    )
    if not reason_rows:
        reason_rows = '<tr><td class="mc-dim">keine ausgewerteten Q09-Paare</td><td class="mc-num">0</td></tr>'
    status = f"{yes} JA · {no} NEIN" if available else "UNAVAILABLE"
    return f'''
  <section class="mc-section" id="q09-ftmo-recommendation">
    <div class="mc-h2"><span>Q09 News Impact · FTMO geeignet</span>
      <span class="mc-h2-aux">{e(status)} · {total} Paare</span></div>
    <table class="mc-table">
      <thead><tr><th>Begründung aus ftmo_q09_admission</th><th class="mc-num">Paare</th></tr></thead>
      <tbody>{reason_rows}</tbody>
    </table>
    <div class="mc-foot"><div class="mc-foot-line">
      Reine Präsentation der bestehenden Q09-Zulassungslogik; keine Schwellen-,
      Verdikt-, Challenge- oder Deployment-Autorität.
    </div></div>
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


def _render_path_to_25(contract: dict) -> str:
    metrics = contract.get("path_to_25", {}) or {}
    if not metrics:
        return ""
    news = metrics.get("news_gate", {}) or {}
    opt = metrics.get("opt_fork", {}) or {}
    backfill = metrics.get("backfill", {}) or {}
    committed = metrics.get("committed_work", {}) or {}
    reservoir = metrics.get("reservoir", {}) or {}
    rates = metrics.get("completion_rates", {}) or {}
    definition = metrics.get("counting_definition", {}) or {}
    eta_contract = metrics.get("eta_to_25", {}) or {}
    eta = eta_contract.get("eta_days", metrics.get("eta_days"))
    eta_text = f"{_de(eta, 2)} Tage" if eta is not None else "nicht belastbar"
    eta_reliability = str(eta_contract.get("reliability") or "UNKNOWN")

    frontier = "".join(
        f'<span class="mc-p25-gate"><b>{e(gate)}</b>{_int(count)}</span>'
        for gate, count in (metrics.get("frontier_histogram") or {}).items()
        if int(count or 0) > 0
    )
    if not frontier:
        frontier = '<span class="mc-dim">noch keine lückenlose Qxx-Frontier</span>'

    opt_rows = "".join(
        '<tr>'
        f'<td class="mc-rowlabel">{gate}</td>'
        f'<td class="mc-num">{_int((opt.get(gate) or {}).get("pending"))}</td>'
        f'<td class="mc-num">{_int((opt.get(gate) or {}).get("done"))}</td>'
        '</tr>'
        for gate in ("Q12", "Q13", "Q14")
    )
    verdicts = " · ".join(
        f"{key} {_int(value)}"
        for key, value in (opt.get("terminal_verdicts") or {}).items()
    ) or "keine"
    committed_rows = "".join(
        '<tr>'
        f'<td class="mc-rowlabel">{e(label)}</td>'
        f'<td class="mc-num">{_int(values.get("declared"))}</td>'
        f'<td class="mc-num">{_int(values.get("materialized"))}</td>'
        f'<td class="mc-num">{_int(values.get("receipts"))}</td>'
        '</tr>'
        for label, values in (committed.get("classes") or {}).items()
    )
    if not committed_rows:
        committed_rows = (
            '<tr><td class="mc-rowlabel">keine</td>'
            '<td class="mc-num">0</td><td class="mc-num">0</td>'
            '<td class="mc-num">0</td></tr>'
        )

    rate_labels = {
        "Q10_CHOSEN": "Q10 chosen",
        "Q11": "Q11",
        "Q12": "Q12",
        "Q13": "Q13",
        "Q14": "Q14",
    }
    rate_rows = "".join(
        '<tr>'
        f'<td class="mc-rowlabel">{e(rate_labels[key])}</td>'
        f'<td class="mc-num">{_int(((rates.get("stages") or {}).get(key) or {}).get("completed_pairs"))}</td>'
        f'<td class="mc-num">{_de(((rates.get("stages") or {}).get(key) or {}).get("pairs_per_day"), 2)}</td>'
        '</tr>'
        for key in rate_labels
    )

    def pair_state(pair: dict, field: str) -> str:
        item = pair.get(field) or {}
        state = str(item.get("state") or "NOT_STARTED")
        verdict = str(item.get("latest_verdict") or "")
        if verdict and state in {"DONE", "NOT_VALID"}:
            return f"{state} · {verdict}"
        return state

    pair_rows = "".join(
        '<tr>'
        f'<td class="mc-mono">{e(pair.get("ea_id"))}</td>'
        f'<td class="mc-mono">{e(pair.get("symbol"))}</td>'
        f'<td>{"PASS" if pair.get("in_q09_reservoir") else "—"}</td>'
        f'<td>{"chosen" if pair.get("news_chosen") else "—"}</td>'
        f'<td>{e(pair_state(pair, "q11"))}</td>'
        f'<td>{e(pair_state(pair, "q12"))}</td>'
        f'<td>{e(pair_state(pair, "q13"))}</td>'
        f'<td>{e(pair_state(pair, "q14"))}</td>'
        '</tr>'
        for pair in (metrics.get("pair_progress") or [])
    )
    if not pair_rows:
        pair_rows = '<tr><td colspan="8" class="mc-dim">keine v4-Paardaten</td></tr>'

    diagnostic_chips = "".join(
        f'<span class="mc-p25-gate" title="{e(option.get("description"))}">'
        f'<b>Diagnostik · {e(option.get("id"))} · kein Trigger</b>'
        f'{_int(option.get("count"))}</span>'
        for option in (definition.get("diagnostics") or [])
    )
    definition_footnote = definition.get("footnote") or (
        "Zähldefinition fehlt; Anzeige ist nicht für eine OWNER-Entscheidung belastbar."
    )
    definition_authority = definition.get("authority_path") or "Authority fehlt"

    return f'''
  <section class="mc-section mc-p25" id="path-to-25">
    <div class="mc-h2"><span>Weg zu 25</span>
      <span class="mc-h2-aux">Q14 terminal · ETA zu 25 {e(eta_text)} · Rate {e(eta_reliability)}</span></div>
    <div class="mc-p25-head">
      <div><span class="mc-p25-value">{_int(metrics.get("qualified_pairs"))}<small>/25</small></span>
        <span class="mc-p25-label">voll qualifizierte Paare</span></div>
      <div class="mc-p25-stat"><b>{_int(metrics.get("distinct_eas"))}</b><span>EAs</span></div>
      <div class="mc-p25-stat"><b>{_int(metrics.get("families"))}</b><span>Familien</span></div>
      <div class="mc-p25-stat"><b>{e(eta_text)}</b><span>ETA zu 25</span></div>
    </div>
    <div class="mc-p25-definition"><b>Zählung VERSIEGELT · {e(definition.get("rendered_definition_id"))}</b>
      <span>{e(definition_footnote)}</span>
      <div class="mc-p25-frontier"><span>OWNER-Entscheid</span><b>{e(definition_authority)}</b></div>
      <div class="mc-p25-frontier"><span>Sekundärdiagnostik · KEIN Trigger</span>{diagnostic_chips}</div>
    </div>
    <div class="mc-p25-frontier"><span>Q09-Reservoir</span>
      <b>{_int(reservoir.get("q09_pass_pairs"))}</b><span>PASS</span>
      <b>{_int(reservoir.get("news_chosen_pairs"))}</b><span>Q10 chosen</span>
      <b>{_int(reservoir.get("q11_pass_pairs"))}</b><span>Q11 PASS</span>
      <b>{_int(reservoir.get("q12_valid_pairs"))}</b><span>Q12 valid</span>
      <b>{_int(reservoir.get("q13_valid_pairs"))}</b><span>Q13 valid</span>
      <b>{_int(reservoir.get("q14_terminal_rows"))}</b><span>Q14 raw terminal</span>
    </div>
    <div class="mc-p25-frontier"><span>Frontier</span>{frontier}</div>
    <div class="mc-p25-frontier"><span>Committed</span>
      <b>{_int(committed.get("unmaterialized", 0))}</b>
      <span class="mc-dim">noch nicht materialisierte Zellen · {_int(committed.get("parents", 0))} Parents</span>
    </div>
    <table class="mc-table"><thead><tr><th>Klasse</th><th class="mc-num">deklariert</th>
      <th class="mc-num">materialisiert</th><th class="mc-num">Receipts</th></tr></thead>
      <tbody>{committed_rows}</tbody></table>
    <div class="mc-p25-grid">
      <div>
        <div class="mc-sublabel">Q10 News</div>
        <table class="mc-table"><tbody>
          <tr><td class="mc-rowlabel">konklusive Verdikte · 7 T</td><td class="mc-num">{_int(news.get("conclusive_verdicts_7d"))}</td></tr>
          <tr><td class="mc-rowlabel">PASS · 7 T</td><td class="mc-num">{_int(news.get("pass_7d"))}</td></tr>
          <tr><td class="mc-rowlabel">pending/aktiv</td><td class="mc-num">{_int(news.get("pending"))}</td></tr>
          <tr><td class="mc-rowlabel">Holds</td><td class="mc-num">{_int(news.get("holds"))}</td></tr>
        </tbody></table>
      </div>
      <div>
        <div class="mc-sublabel">Opt-Fork</div>
        <table class="mc-table"><thead><tr><th></th><th class="mc-num">pending</th><th class="mc-num">done</th></tr></thead>
          <tbody>{opt_rows}</tbody></table>
        <div class="mc-foot"><b>Q14 terminal:</b> {e(verdicts)}</div>
      </div>
      <div>
        <div class="mc-sublabel">Gemessene Abschlussraten · {e(rates.get("window_days"))} T</div>
        <table class="mc-table"><thead><tr><th>Gate</th><th class="mc-num">Paare</th><th class="mc-num">/ Tag</th></tr></thead>
          <tbody>{rate_rows}</tbody></table>
        <div class="mc-foot"><b>ETA-Basis:</b> {e(eta_contract.get("basis"))}<br>{e(eta_contract.get("caveat"))}</div>
      </div>
    </div>
    <div class="mc-foot"><b>Backfill:</b> heute {_int(backfill.get("enqueued_today"))} enqueued ·
      RERUN_INFRA offen {_int(backfill.get("rerun_infra_open"))}. Queue-leer-ETA bleibt ein separater Wert.</div>
    <details class="mc-p25-details">
      <summary>Paarschritte Q09–Q14 · payload-abgeleitet ({_int(len(metrics.get("pair_progress") or []))})</summary>
      <div class="mc-p25-table-wrap"><table class="mc-table"><thead><tr>
        <th>EA</th><th>Symbol</th><th>Q09</th><th>Q10</th><th>Q11</th><th>Q12</th><th>Q13</th><th>Q14</th>
      </tr></thead><tbody>{pair_rows}</tbody></table></div>
    </details>
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
  .mc-p25{--path25-accent:#2954d4;border-left:4px solid var(--path25-accent)}
  .mc-p25 .mc-h2>span:first-child{color:var(--path25-accent)}
  .mc-p25-head{display:grid;grid-template-columns:2fr repeat(3,1fr);gap:var(--space-4);
    padding:var(--space-4);background:var(--surface-2);border:1px solid var(--border)}
  .mc-p25-value{font-family:var(--font-mono);font-size:var(--fs-3xl);color:var(--text)}
  .mc-p25-value small{font-size:var(--fs-md);color:var(--path25-accent);margin-left:var(--space-1)}
  .mc-p25-label,.mc-p25-stat span{display:block;font-family:var(--font-mono);font-size:var(--fs-xs);
    color:var(--text-3);text-transform:uppercase;letter-spacing:.08em}
  .mc-p25-stat{border-left:1px solid var(--border);padding-left:var(--space-4)}
  .mc-p25-stat b{display:block;font-family:var(--font-mono);font-size:var(--fs-lg);color:var(--text)}
  .mc-p25-frontier{display:flex;align-items:center;gap:var(--space-2);flex-wrap:wrap;
    margin:var(--space-4) 0;font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3)}
  .mc-p25-gate{display:inline-flex;gap:var(--space-2);padding:var(--space-1) var(--space-2);
    border:1px solid var(--border-2);color:var(--text-2)}
  .mc-p25-gate b{color:var(--path25-accent)}
  .mc-p25-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:var(--space-6)}
  .mc-p25-definition{margin:var(--space-4) 0;padding:var(--space-3);
    border:1px solid var(--warn);background:var(--surface-2);font-size:var(--fs-xs);
    color:var(--text-2);line-height:var(--lh-normal)}
  .mc-p25-definition>b,.mc-p25-definition>span{display:block}
  .mc-p25-definition>b{font-family:var(--font-mono);color:var(--warn);
    margin-bottom:var(--space-1)}
  .mc-p25-details{margin-top:var(--space-4);border:1px solid var(--border);
    padding:var(--space-3)}
  .mc-p25-details summary{cursor:pointer;font-family:var(--font-mono);
    font-size:var(--fs-xs);font-weight:700;color:var(--path25-accent)}
  .mc-p25-table-wrap{overflow-x:auto;margin-top:var(--space-3)}
  .mc-p25-table-wrap .mc-table{min-width:1050px}
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
  .mc-dec-row{display:block;padding:var(--space-5) 0;border-bottom:1px solid var(--border)}
  .mc-dec-row:last-child{border-bottom:none}
  .mc-dec-head{display:flex;align-items:center;gap:var(--space-2);flex-wrap:wrap;
    font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3)}
  .mc-dec-head code{color:var(--text-2)}
  .mc-dec-status{padding:var(--space-1) var(--space-2);border:1px solid var(--border-2);
    color:var(--warn)}
  .mc-chip{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:700;
    letter-spacing:0.1em;padding:var(--space-1) var(--space-2);border:1px solid var(--border-2);
    white-space:nowrap}
  .mc-dec-cat{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    white-space:nowrap}
  .mc-dec-question{font-size:var(--fs-md);font-weight:700;color:var(--text);
    margin:var(--space-3) 0 var(--space-2)}
  .mc-dec-rec{padding:var(--space-3);border-left:3px solid var(--signal);
    background:var(--surface-2);font-size:var(--fs-sm);color:var(--text-2)}
  .mc-dec-rec b{color:var(--signal)}
  .mc-dec-effects{display:grid;grid-template-columns:repeat(3,1fr);gap:var(--space-3);
    margin:var(--space-3) 0}
  .mc-dec-effects>div{border:1px solid var(--border);padding:var(--space-3)}
  .mc-dec-effects b,.mc-dec-effects span{display:block}
  .mc-dec-effects b{font-family:var(--font-mono);font-size:var(--fs-xs);
    color:var(--text-3);text-transform:uppercase;margin-bottom:var(--space-1)}
  .mc-dec-effects span{font-size:var(--fs-xs);color:var(--text-2);line-height:var(--lh-normal)}
  .mc-dec-detail,.mc-dec-evidence{font-size:var(--fs-xs);color:var(--text-3);
    line-height:var(--lh-normal);margin-top:var(--space-2)}
  .mc-dec-evidence b{color:var(--text-2)}
  .mc-dec-due{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3);
    white-space:nowrap;margin-left:auto}
  .mc-dec-boundary{padding:var(--space-3);margin-bottom:var(--space-2);
    border:1px solid var(--warn);font-size:var(--fs-xs);color:var(--text-2)}
  .mc-dec-boundary b{color:var(--warn)}
  .mc-router-health{display:flex;align-items:center;gap:var(--space-3);flex-wrap:wrap;
    border:1px solid var(--border);padding:var(--space-3);margin-bottom:var(--space-2);
    font-size:var(--fs-xs);color:var(--text-2)}
  .mc-dec-tools{display:grid;grid-template-columns:minmax(220px,1fr) repeat(3,auto) auto;
    gap:var(--space-2);align-items:center;margin:var(--space-3) 0}
  .mc-dec-tools input,.mc-dec-tools select{border:1px solid var(--border-2);
    background:var(--surface-2);color:var(--text);padding:var(--space-2);font:inherit}
  .mc-dec-tools span{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-3)}
  .mc-dec-deps{font-size:var(--fs-xs);color:var(--text-3);margin-top:var(--space-2)}
  .mc-dec-deps b{color:var(--text-2)}
  .mc-dec-plan{border:1px solid var(--border);margin-top:var(--space-3);padding:var(--space-2)}
  .mc-dec-plan summary{cursor:pointer;font-family:var(--font-mono);font-size:var(--fs-xs);
    color:var(--signal);font-weight:700}
  .mc-plan-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space-3);
    margin-top:var(--space-3)}
  .mc-plan-choice{border:1px solid var(--border-2);padding:var(--space-3);
    font-size:var(--fs-xs);color:var(--text-2)}
  .mc-plan-head{display:flex;justify-content:space-between;gap:var(--space-2);
    margin-bottom:var(--space-2)}
  .mc-plan-choice b{display:block;color:var(--text);margin-bottom:var(--space-1)}
  .mc-plan-choice ul{margin:var(--space-1) 0 var(--space-2) var(--space-4)}
  .mc-plan-choice li{margin-bottom:var(--space-1)}
  .mc-plan-impact,.mc-plan-containment{padding:var(--space-2);background:var(--surface-1);
    margin-bottom:var(--space-2)}
  .mc-plan-hash{font-family:var(--font-mono);font-size:var(--fs-xs);color:var(--text-4);
    margin-top:var(--space-2);overflow-wrap:anywhere}
  .mc-dec-controls{display:grid;grid-template-columns:1fr auto;gap:var(--space-2);
    margin-top:var(--space-3);align-items:end}
  .mc-dec-controls label{grid-column:1/-1;font-family:var(--font-mono);
    font-size:var(--fs-xs);color:var(--text-3)}
  .mc-dec-controls textarea{width:100%;box-sizing:border-box;resize:vertical;
    border:1px solid var(--border-2);background:var(--surface-2);color:var(--text);
    padding:var(--space-2);font:inherit}
  .mc-dec-buttons{display:flex;gap:var(--space-2);align-items:stretch}
  .mc-dec-buttons button{border:1px solid var(--border-2);background:var(--surface-2);
    color:var(--text);padding:var(--space-2) var(--space-3);font-family:var(--font-mono);
    font-size:var(--fs-xs);font-weight:700;cursor:pointer}
  .mc-dec-buttons button[data-decision-choice="YES"]{border-color:var(--pass);color:var(--pass)}
  .mc-dec-buttons button[data-decision-choice="NO"]{border-color:var(--fail);color:var(--fail)}
  .mc-dec-buttons button[data-decision-choice="DEFERRED"]{border-color:var(--warn);color:var(--warn)}
  .mc-dec-buttons button:disabled,.mc-dec-controls textarea:disabled{cursor:not-allowed;
    color:var(--text-4);border-color:var(--border)}
  .mc-dec-result{grid-column:1/-1;font-family:var(--font-mono);font-size:var(--fs-xs);
    color:var(--text-3);min-height:1.2em}
  .mc-dec-row.mc-dec-recorded{border-left:3px solid var(--pass);padding-left:var(--space-3)}
  .mc-dec-row[hidden]{display:none}
  .mc-exec-block{margin-top:var(--space-5);padding-top:var(--space-4);border-top:1px solid var(--border)}
  .mc-h3{display:flex;justify-content:space-between;gap:var(--space-3);font-weight:700;
    margin-bottom:var(--space-2)}
  .mc-h3 span{font-family:var(--font-mono);font-size:var(--fs-xs);font-weight:400;color:var(--text-3)}
  .mc-exec-list{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:var(--space-2)}
  .mc-exec-row{padding:var(--space-3);border:1px solid var(--border);background:var(--surface-2)}
  .mc-exec-head{display:flex;align-items:center;gap:var(--space-2);flex-wrap:wrap;
    font-family:var(--font-mono);font-size:var(--fs-xs)}
  .mc-exec-question{margin-top:var(--space-2);font-weight:600}
  .mc-exec-meta,.mc-exec-verdict{margin-top:var(--space-2);font-size:var(--fs-xs);
    color:var(--text-3);overflow-wrap:anywhere}

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
    .mc-p25-grid{grid-template-columns:1fr}
    .mc-queue-grid{grid-template-columns:1fr}
  }
  @media(max-width:720px){
    .mc-strip{grid-template-columns:repeat(2,1fr)}
    .mc-cell{border-right:none}
    .mc-t-grid{grid-template-columns:1fr}
    .mc-dec-effects{grid-template-columns:1fr}
    .mc-plan-grid{grid-template-columns:1fr}
    .mc-dec-tools{grid-template-columns:1fr}
    .mc-dec-controls{grid-template-columns:1fr}
    .mc-dec-buttons{flex-wrap:wrap}
    .mc-exec-list{grid-template-columns:1fr}
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


_DECISION_SCRIPT = r"""
(function(){
  var root=document.getElementById('owner-decisions');
  if(!root)return;
  var enabled=root.getAttribute('data-intake-enabled')==='true';
  var endpoint=root.getAttribute('data-intake-endpoint')||'';
  var token=root.getAttribute('data-intake-token')||'';
  var serviceState=root.querySelector('[data-decision-service-state]');
  var filterSearch=root.querySelector('[data-decision-filter-search]');
  var filterCategory=root.querySelector('[data-decision-filter-category]');
  var filterStatus=root.querySelector('[data-decision-filter-status]');
  var filterSeverity=root.querySelector('[data-decision-filter-severity]');
  var filterCount=root.querySelector('[data-decision-filter-count]');
  function requestId(){
    if(window.crypto&&typeof window.crypto.randomUUID==='function')return window.crypto.randomUUID();
    return 'mc-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);
  }
  function setDisabled(row,value){
    var controls=row.querySelectorAll('button,textarea');
    for(var i=0;i<controls.length;i++)controls[i].disabled=value;
  }
  function applyDecisionFilters(){
    var query=(filterSearch&&filterSearch.value||'').trim().toLowerCase();
    var category=(filterCategory&&filterCategory.value||'').toLowerCase();
    var status=(filterStatus&&filterStatus.value||'').toLowerCase();
    var severity=(filterSeverity&&filterSeverity.value||'').toLowerCase();
    var rows=root.querySelectorAll('.mc-dec-row');
    var visible=0;
    for(var i=0;i<rows.length;i++){
      var row=rows[i];
      var show=(!query||(row.getAttribute('data-decision-search')||'').indexOf(query)>=0)&&
        (!category||row.getAttribute('data-decision-category')===category)&&
        (!status||row.getAttribute('data-decision-status')===status)&&
        (!severity||row.getAttribute('data-decision-severity')===severity);
      row.hidden=!show;
      if(show)visible++;
    }
    if(filterCount)filterCount.textContent=visible+' sichtbar';
  }
  [filterSearch,filterCategory,filterStatus,filterSeverity].forEach(function(control){
    if(!control)return;
    control.addEventListener(control===filterSearch?'input':'change',applyDecisionFilters);
  });
  if(enabled&&endpoint){
    try{
      var health=new URL('/health',endpoint).toString();
      fetch(health,{method:'GET',cache:'no-store'}).then(function(response){
        if(!response.ok)throw new Error('HTTP '+response.status);
        return response.json();
      }).then(function(payload){
        if(!payload.ok||payload.mode!=='ROUTER_HANDOFF')throw new Error('ungueltiger Dienstvertrag');
        if(serviceState)serviceState.textContent='INTAKE VERBUNDEN';
      }).catch(function(){
        if(serviceState)serviceState.textContent='INTAKE NICHT ERREICHBAR';
      });
    }catch(_error){
      if(serviceState)serviceState.textContent='INTAKE NICHT ERREICHBAR';
    }
  }
  root.addEventListener('click',function(event){
    var button=event.target.closest('button[data-decision-choice]');
    if(!button||!root.contains(button))return;
    var row=button.closest('[data-decision-id]');
    var result=row.querySelector('.mc-dec-result');
    var note=row.querySelector('textarea');
    var decision=button.getAttribute('data-decision-choice');
    var effect=button.getAttribute('data-decision-effect')||'';
    var planMode=button.getAttribute('data-plan-mode')||'';
    var planImpact=button.getAttribute('data-plan-impact')||'';
    var planContainment=button.getAttribute('data-plan-containment')||'';
    var cardHash=row.getAttribute('data-decision-card-sha256')||'';
    var planHash=row.getAttribute('data-execution-plan-sha256')||'';
    var id=row.getAttribute('data-decision-id');
    if(!enabled||!endpoint||!token){
      result.textContent='Dokumentationsdienst ist nicht verbunden.';
      return;
    }
    if(!/^[0-9a-f]{64}$/.test(cardHash)){
      result.textContent='Entscheidungskarte ist nicht gebunden; Mission Control neu laden.';
      return;
    }
    if(decision!=='DEFERRED'&&!/^[0-9a-f]{64}$/.test(planHash)){
      result.textContent='Ausfuehrungsplan ist nicht gebunden; Mission Control neu laden.';
      return;
    }
    var handoff=(decision==='DEFERRED')
      ? 'Es wird kein Agent-Auftrag erzeugt.'
      : 'Danach wird genau ein begrenzter Claude-Auftrag erzeugt.';
    var preview=(decision==='DEFERRED')?'':
      '\n\nModus: '+planMode+'\nImpact: '+planImpact+'\nRueckweg/Containment: '+planContainment;
    if(!window.confirm(id+' = '+decision+'\n\nFolge: '+effect+preview+'\n\n'+handoff))return;
    setDisabled(row,true);
    result.textContent='Entscheidung wird receiptiert ...';
    fetch(endpoint+'/'+encodeURIComponent(id),{
      method:'POST',
      cache:'no-store',
      headers:{'Content-Type':'application/json','X-QM-Decision-Token':token},
      body:JSON.stringify({decision:decision,notes:note?note.value:'',request_id:requestId(),
        decision_card_sha256:cardHash,execution_plan_sha256:planHash})
    }).then(function(response){
      return response.json().catch(function(){return {};}).then(function(payload){
        if(!response.ok)throw new Error(payload.detail||payload.error||('HTTP '+response.status));
        return payload;
      });
    }).then(function(payload){
      row.classList.add('mc-dec-recorded');
      if(payload.decision==='DEFERRED'){
        result.textContent='VERTAGT · Receipt '+payload.receipt_id+' · kein Agent-Auftrag';
      }else{
        result.textContent='BEAUFTRAGT: '+payload.decision+' · Task '+payload.execution_task_id+
          ' · '+payload.handoff_state+' · Umsetzung nur innerhalb der Kartenfolge';
      }
    }).catch(function(error){
      setDisabled(row,false);
      result.textContent='NICHT GESPEICHERT: '+error.message;
    });
  });
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
        _render_risk_freeze(contract),
        _render_path_to_25(contract),
        _render_q09_ftmo_recommendation(contract),
        _render_owner_decisions(contract),
        _render_progress(contract),
        _render_terminals(contract, ea_page_exists=ea_page_exists),
        _render_queue(contract),
        _render_exceptions(contract),
        render_operator_surface_html(contract.get("operator_surface") or {}),
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
        "<script>\n" + _REL_SCRIPT + "\n" + _DECISION_SCRIPT + "\n</script>\n"
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
        # Build the full census once. It feeds the separate drill-down; only a
        # compact exception-focused preview remains in the main cockpit.
        contract = build_contract(args.db, operator_pair_detail_limit=None)

    explorer_doc = None
    if not from_json:
        full_operator = contract.get("operator_surface") or {}
        explorer_doc = render_frontier_explorer_html(full_operator)
        contract = dict(contract)
        contract["operator_surface"] = compact_operator_snapshot(
            full_operator, limit=30
        )
    dur_ms = (time.perf_counter() - t0) * 1000.0

    output = Path(args.output)
    doc = render(contract, from_json=from_json, source_path=source_path,
                 duration_ms=dur_ms,
                 ea_page_exists=_ea_page_exists_factory(output.parent))

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(doc, encoding="utf-8", newline="\n")
    if explorer_doc is not None:
        (output.parent / "linear_frontier.html").write_text(
            explorer_doc, encoding="utf-8", newline="\n"
        )
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
