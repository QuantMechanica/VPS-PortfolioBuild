"""Dispatch CTO+DevOps for Dashboard + Strategy Archive redesign per OWNER 2026-05-09."""
import sys, urllib.request, urllib.error, json
sys.stdout.reconfigure(encoding='utf-8')

API='http://127.0.0.1:3100/api'
COMPANY='03d4dcc8-4cea-4133-9f68-90c0d99628fb'
GOAL='4662e91e-8e9b-458e-9383-b1f67751965b'
DEVOPS='86015301-1a40-4216-9ded-398f09f02d26'

BODY="""## Aufgabe — Dashboard + Strategy Archive Redesign (OWNER 2026-05-09)

OWNER 2026-05-09: "Dashboard koennte huebscher und aussagekraeftiger gemacht werden. Strategy Archive sollte taeglich aktualisiert werden, alle Strategien zeigen (auch G0-only / G1-approved noch nicht gebaut)."

Aktuell:
- `current.html` (31 KB) zeigt Kanban + Agents (jetzt 17, Dev-Claude added per manual render 13:48Z)
- `strategies.html` (47 KB) zeigt **nur 4 EAs** (ALLE bereits compiled). Aber 29 Strategy Cards auf disk + 14 frische SRC06 Singh cards (QUA-1058 in_review) fehlen
- Beide files: gutes dark-theme Design aber inkonsistent zur Daily-Mail-Brand-Tokens

Ich (Board Advisor) habe bereits:
- Manual render gerade gefeuert (beide files frisch, Dev-Claude jetzt im current.html)
- Windows Task `QM_DashboardRender_Hourly` registriert (alle Stunde, ab 22:00 lokal)

## Was zu tun

### Teil A: Strategy Archive Redesign (`render_strategies.py`)

**Mission**: zeige die volle Pipeline-Lage, nicht nur compiled EAs. OWNER will sehen wo wir stehen Richtung Portfolio.

1. **Alle Strategy Cards anzeigen**, nicht nur compiled:
   - **G0 candidates** (Strategy-Card extracted, awaiting QB G1): sollte Liste zeigen
   - **G1 approved** (QB R1-R4 PASS): in Build-Queue
   - **G1 + scaffolded** (.mq5 in framework/EAs/, awaiting compile)
   - **G1 + compiled** (.ex5 ready)
   - **In Pipeline** (P1+ running, currently QM5_1014)
   - **Pipeline FAIL** (killed e.g. QM5_1003)
   - **Pipeline PASS** (P0..P8 done, ready for T6)
   - **Live on T6** (deployed, real money)

2. **Lane-Diversitaet sichtbar machen** (per Phase 4 Plan): Trend X / MR Y / Other Z target balance vs current basket
3. **Source-Aggregat**: pro SRC# wie viele Cards extracted, wie viele approved, wie viele in pipeline

### Teil B: Dashboard Redesign (`render_dashboard.py`)

**Mission KPIs nach vorne** (entsprechend OWNER's no-phasing + MT5-saturation = success metric):

1. **Mission-Hero-Section** (oben):
   - MT5-Saturation: X/5 active mit Live-Update (lese WMIC tasklist oder D:/QM/reports/pipeline/dispatch_state.json)
   - Heureka-Distance: best alive EA + max phase + missing gates (DXZ-portfolio-gate, T6-toggle)
   - Codex weekly + Anthropic week quota (color-coded green<60% / amber<85% / red>=85%) — read from `/api/companies/{id}/costs/quota-windows`
   - Pipeline-Throughput: cards/week, EAs through P0..P8/week (rolling)

2. **Workstream-Status** (per DL-061 Endausbaustufe-Modus, no phasing):
   - Strategy Pipeline: status + today's progress
   - Portfolio Composition: status + composition state
   - LiveOps Readiness: status + T6 readiness gate state
   - Public Channels: dashboard refresh + YouTube/Newsletter background
   - Operations Infrastructure: token governance + agent fleet hygiene

3. **Active Agents**: 17 listed mit Live-Status, Dev-Codex + Dev-Claude prominent (provider-diversification angle)

### Teil C: Brand-Konsistenz

Beide files sollten den gleichen Brand-Stack verwenden wie `daily_status_mail.py`:
- Surface: `#020617` -> `#0f172a` -> `#1e293b`
- Text: `#f8fafc` / `#cbd5e1` / `#94a3b8`
- Brand emerald: `#10b981` (status pass)
- Status colors: pass/promising/fail/dead/live (per `branding/brand_tokens.json`)
- Font: Inter

Source: `branding/brand_tokens.json` (single source of truth fuer alle visual styles).

### Teil D: Refresh-Schedule

- Windows Task `QM_DashboardRender_Hourly` ist registriert (Board Advisor 2026-05-09) → laeuft alle Stunde
- Paperclip-Routine "Hourly public dashboard export" zeigt lastFired=None — entweder reparieren oder retiren falls QM_DashboardRender_Hourly ausreicht

### Teil E: Mobile + Print

- Responsive (CSS @media queries) damit OWNER auch mobil checken kann
- Print-friendly fuer audit reviews

## Acceptance

1. `strategies.html` zeigt alle 29+ Cards mit ihrem Pipeline-Status (nicht nur compiled)
2. `current.html` hat Mission-Hero-Section oben mit MT5/Heureka/Quota/Throughput
3. Dev-Codex + Dev-Claude beide sichtbar mit ihrem Routing-Modell
4. Brand-Tokens konsistent zur Daily-Mail
5. Mobile-friendly (mind. iPhone 14 width)
6. Daily auto-refresh laeuft (Windows Task verifiziert)

## Aufgaben-Verteilung

- **DevOps** (you): Implementation (render scripts redesign)
- **CTO** kann reviewen / approve. Falls beide-Devs frei, koennen die parallel auch helfen (Dev-Claude oder Dev-Codex je nach Codex-Auslastung)
- Board Advisor reviewt das Endergebnis (Brand-Konsistenz + Mission-KPI-Anzeige)

## Pfade

- Source: `paperclip/tools/ops/render_dashboard.py` + `render_strategies.py`
- Brand: `branding/brand_tokens.json` (daily_status_mail.py nutzt das schon — gleiches Schema)
- Strategy Cards: `strategy-seeds/cards/` (29 Files)
- Source extracts: `strategy-seeds/sources/SRC*/` (incl. SRC06 Singh 14 cards)
- Pipeline reports: `D:/QM/reports/pipeline/<EA>/`
- Quota API: `GET /api/companies/{id}/costs/quota-windows` (Memory `reference_paperclip_quota_windows_api.md`)

## Constraints

- Codex weekly aktuell ~94%, Anthropic week 59%. DevOps ist process-adapter fuer DwxHourly aber claude_local fuer issue-work; Anthropic-Subscription hat headroom.
- KEINE OWNER-class actions
- DL-046: comment-then-PATCH bei Status-Aenderung
- Inhalt > Style — wenn Mission-KPIs noch nicht alle berechenbar sind (z.B. Heureka-distance live), zumindest Placeholder + log gap

Prio: MEDIUM (nicht akut blocking, aber visibility-impact gross)
"""

req=urllib.request.Request(f'{API}/companies/{COMPANY}/issues',
    data=json.dumps({
        'title': 'Dashboard + Strategy Archive Redesign — Brand-konsistent + Mission-KPIs + alle Strategy Cards',
        'description': 'OWNER 2026-05-09: dashboard huebscher + aussagekraeftiger; strategies.html zeigt nur 4/29 cards. Redesign mit Brand-Tokens, Mission-Hero, no-phasing-workstreams, Dev-Codex+Claude visibility, daily refresh.',
        'priority': 'medium',
        'assigneeAgentId': DEVOPS,
        'goalId': GOAL,
        'createdByUserId': 'local-board',
    }).encode('utf-8'),
    headers={'Content-Type':'application/json'}, method='POST')
try:
    resp=urllib.request.urlopen(req); d=json.loads(resp.read())
    iid=d['id']; ident=d['identifier']
    print(f'Issue: {ident} | id={iid}')
    req2=urllib.request.Request(f'{API}/issues/{iid}',
        data=json.dumps({'status':'todo'}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='PATCH')
    urllib.request.urlopen(req2)
    req3=urllib.request.Request(f'{API}/issues/{iid}/comments',
        data=json.dumps({'body':BODY}).encode('utf-8'),
        headers={'Content-Type':'application/json'}, method='POST')
    resp3=urllib.request.urlopen(req3); print(f'Comment: {resp3.status}')
except urllib.error.HTTPError as e:
    print(f'ERR: {e.status} {e.read().decode()[:300]}')
