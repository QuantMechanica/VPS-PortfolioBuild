# QuantMechanica.com Website + Project Dashboard - Paperclip Style

Purpose: keep quantmechanica.com as the public QuantMechanica website and extend it with a Paperclip-style project dashboard.

The relaunch is an extension, not a replacement. The current strengths stay:

- Build-in-public story and professional QuantMechanica brand
- Pipeline explanation
- Strategy archive
- Contact / get-in-contact path
- Newsletter
- Legal/imprint

The new layer is the live project dashboard: Paperclip company status, strategy factory state, public expense log, T6/DarwinexZero proof portfolio status, deploy ledger, process roadmap, and episode artifacts.

## Product Position

The site should feel like a QuantMechanica website with a public Paperclip board embedded as the operating surface:

- live project state
- agent activity
- phase gates
- portfolio status
- expense log
- episode artifacts
- decision trail
- process roadmap
- get-in-contact path

It should not become a pure dashboard that hides the brand, pipeline, archive, or contact path. The first screen should show the build state and still make it obvious what QuantMechanica is.

## Site Architecture

Recommended top-level navigation:

| Section | Purpose | Notes |
|---|---|---|
| Home | build-in-public status and latest episode | Keep the current design direction, add compact live state |
| Project Dashboard | Paperclip board, costs, blockers, current phase | Hourly snapshot, public-safe data |
| Pipeline | explain P0-P10 and promotion gates | Keep as evergreen educational page |
| Strategy Archive | searchable strategies and evidence | Existing asset retained, rebuilt with V5 data |
| Portfolio | DarwinexZero proof portfolio | Public aggregate KPIs only |
| Process Roadmap | how the Paperclip company works | SOPs, review cadence, milestones |
| Episodes | YouTube library and artifact packs | Every video links to artifacts and support CTA |
| Contact | get in contact | Keep visible and direct |

## Support CTA

Each video and episode page should include a small support CTA:

```text
Support the build: Buy me a coffee
```

Use it as project support, not as an investment ask. It belongs at:

- end screen / final 10-15 seconds of each video
- YouTube description
- episode page footer
- optional dashboard footer

Do not mix donations with portfolio performance claims. Keep donations separate from DarwinexZero, investor language, or managed-money claims.

## Update Cadence

Default cadence: hourly.

```text
Windows Task Scheduler on VPS (hourly, e.g. HH:07)
  -> C:\QM\repo\scripts\export_public_snapshot.ps1
  -> write validated JSON files under C:\QM\repo\public-data\
  -> git commit + push only when data changed
  -> Netlify rebuild via GitHub push or Build Hook fallback
  -> quantmechanica.com dashboard reads current public-data/*.json
```

Primary scheduler: Windows Task Scheduler on the Hetzner VPS. Do not use GitHub Actions cron, Netlify Scheduled Functions, or Paperclip heartbeat as the primary scheduler, because those do not own the local MT5/Paperclip/VPS state.

Task command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\QM\repo\scripts\export_public_snapshot.ps1
```

Dashboard stale rule: if `generated_at` is older than 90 minutes, public UI shows a stale-warning state.

Recommended split:

| Data | Refresh | Source | Public? |
|---|---:|---|---|
| Pipeline phase counts | hourly | Paperclip DB export | yes |
| Agent heartbeat summary | hourly | Paperclip API/DB export | partial |
| Latest decisions | hourly/on event | Paperclip issues + Notion | yes, redacted |
| Expense totals | on edit + hourly export | expenses.csv / Notion | yes |
| Live/Demo portfolio KPIs | hourly | T6 logs / Darwinex / Myfxbook | yes |
| Open positions | 15 min internal, hourly public aggregate | T6 / broker | aggregate only |
| Deploy manifests | on approval | deploy-manifests/*.yaml | yes after redaction |
| Raw logs, account IDs, credentials | never | local/VPS only | no |

## Public Dashboard Widgets

1. **Now**
   - current phase
   - latest episode
   - latest major decision
   - current cost-to-date

2. **Paperclip Board**
   - agents online/offline
   - issue counts by state
   - current blockers
   - latest completed heartbeat summaries

3. **Strategy Factory**
   - strategy cards extracted
   - EAs built
   - candidates by phase P1-P10
   - PASS/FAIL/REJECT counts

4. **Strategy Archive**
   - retained QuantMechanica archive rebuilt with V5 data
   - legacy strategies visible only as seed/re-test candidates until re-gated
   - source citations, phase history, evidence links, and Paperclip-style status chips
   - visual mix: QuantMechanica brand voice plus Paperclip operations-board density

5. **Live/Demo Portfolio**
   - T6 status
   - Demo vs backtest drift
   - PF/DD/trade count
   - risk state: green/yellow/red

6. **Deployment Ledger**
   - approved manifests
   - EA/symbol/timeframe
   - magic number
   - approval date
   - verification screenshot link

7. **Expense Log**
   - total spend
   - budget used
   - latest expense
   - monthly burn

8. **Episode Library**
   - latest episode
   - artifact pack
   - decisions covered
   - related strategies/issues

9. **Process Roadmap**
   - active company processes
   - current milestone
   - checklist completion
   - last review date
   - lessons learned added this week

10. **Get in Contact**
   - direct contact CTA
   - collaboration/investor inquiry path
   - newsletter signup
   - clear disclaimer: no investment solicitation

## Internal Dashboard Extension

Private admin-only view can include:

- exact account IDs
- open position detail
- full T6 journal excerpts
- raw Paperclip issue links
- failed automation traces
- emergency flatten controls

Public site must never expose credentials, account IDs, broker server IDs, IP addresses, RDP ports, or raw logs containing sensitive paths.

## Paperclip Style UI

Use the visual language of an operations board inside the existing QuantMechanica brand system:

- dense tables
- status chips
- activity feed
- command/approval ledger
- agent lanes
- phase pipeline
- evidence links
- restrained color
- existing dark/teal professional style retained

Avoid turning the homepage into a generic SaaS landing page. The homepage first viewport should answer:

```text
What is QuantMechanica?
What is running?
What changed?
What is blocked?
What did it cost?
What is the next gate?
```

## Export Contract

Create a public snapshot file:

```json
{
  "generated_at": "2026-04-21T09:00:00Z",
  "phase": "P0 Foundation",
  "agents": {
    "online": 4,
    "offline": 0,
    "blocked": 0
  },
  "pipeline": {
    "strategy_cards": 0,
    "eas_built": 0,
    "by_phase": {
      "P1": 0,
      "P2": 0,
      "P3": 0,
      "P8": 0,
      "P9": 0
    }
  },
  "t6": {
    "status": "offline",
    "autotrading": false,
    "risk_state": "green"
  },
  "expenses": {
    "spent_eur": 0,
    "budget_eur": 1350
  }
}
```

## Paperclip Live Portfolio Autonomy

Paperclip can manage the live portfolio operationally if the permissions are structured correctly:

- CEO decides gate progression.
- LiveOps executes approved deploy manifests.
- Observability-SRE watches health and pages on risk.
- Controlling publishes public and private KPIs.
- OWNER remains final authority for live-money P9 and emergency restart after halt.

Paperclip should not have unlimited discretionary trading authority. It can run the operating system, but every money-at-risk action must be traceable to a manifest and an approval event.

DarwinexZero is the primary live-test portfolio. The dashboard should frame it as a public track record and proof engine, not as a legal hedge fund or investment product unless that language is explicitly cleared.

Internally, the project goal is to reach the live portfolio MVP quickly: start with a small approved EA/symbol set on T6, then expand portfolio breadth through the same gated pipeline. Public copy should use "DarwinexZero live-test portfolio", "proof portfolio", or "public track record" until legal/compliance language is reviewed.

## Process Roadmap Surface

The website should expose a readable version of the company operating system:

- research process
- EA build process
- backtest/retest process
- quality review process
- deploy manifest process
- live monitoring process
- incident process
- episode publishing process
- lessons-learned process

This is not just content. The public roadmap should be generated from the same process registry the agents use internally, with private details redacted.

## MT5 UI Automation Strategy

Preferred order:

1. **Templates/profiles first.** Use MT5 templates/profiles to avoid repeated drag-and-drop where possible.
2. **Scripted chart bootstrap.** Open symbols/timeframes programmatically or through deterministic UI actions.
3. **Calibrated UI automation fallback.** Use mouse/keyboard automation only after dry-run calibration and screenshot/log verification.

The automation must prove:

- target terminal is T6
- symbol exists and chart is open
- timeframe matches manifest
- EA is attached
- setfile inputs match hash/manifest
- AutoTrading state is correct
- logs are clean

If any proof fails, LiveOps aborts and asks for review instead of guessing.

## Launch Criteria

- Public dashboard reads real snapshot JSON, not mock data.
- Hourly export runs for 72h without manual repair.
- T6 status appears on dashboard even before live deployment.
- Expense log matches Notion and repo CSV.
- Deploy manifest ledger is visible with redactions.
- Board approves public/private data boundary.
