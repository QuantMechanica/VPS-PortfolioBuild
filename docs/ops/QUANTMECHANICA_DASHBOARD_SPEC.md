# quantmechanica.com Paperclip Dashboard Spec

> **V5 Source:** Notion `quantmechanica.com Paperclip Dashboard Spec` (id `34947da5-8f4a-8174-858f-f8ed7926cef2`)
> **Migrated to repo:** 2026-04-26
> **Note:** complementary to `docs/ops/WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` (laptop-version, migrated earlier). Where the two diverge, this Notion mirror is the authoritative product spec; the laptop version covers Paperclip-style UI patterns in more depth.

**Purpose:** keep quantmechanica.com as the public QuantMechanica website and extend it with a Paperclip-style project dashboard. The existing pipeline, strategy archive, get-in-contact path, newsletter, and professional design direction stay; the new layer is the live operating surface.

## Product Position

The site should feel like a public Paperclip board:

- live project state
- agent activity
- phase gates
- portfolio status
- expense log
- episode artifacts
- decision trail

It should not become a generic sales landing page or a pure dashboard that hides the brand. The first screen should show the build state and still make it obvious what QuantMechanica is.

## Update Cadence

Default cadence: **hourly**.

**Implementation decision:** the primary scheduler is **Windows Task Scheduler on the Hetzner VPS**, not GitHub Actions cron, Netlify Scheduled Functions, or Paperclip heartbeat alone. The VPS owns the real data sources: Paperclip state, MT5/T6 logs, local reports, expenses, process registry, and redaction state.

```text
Windows Task Scheduler on VPS (hourly, e.g. HH:07)
  -> C:\QM\repo\scripts\export_public_snapshot.ps1
  -> write validated JSON files under C:\QM\repo\public-data\
  -> git commit + push only when data changed
  -> Netlify rebuild via GitHub push or Build Hook fallback
  -> quantmechanica.com reads current public-data/*.json
```

Why this is the default:

- GitHub Actions cannot reliably access local MT5/Paperclip/VPS state.
- Netlify Scheduled Functions are too lightweight/time-limited for this job.
- Paperclip heartbeat is a business-process signal, not the system cron.
- Windows Task Scheduler can run without an interactive user and without visible Python/terminal popups when configured correctly.

Task command:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\QM\repo\scripts\export_public_snapshot.ps1
```

## Data Contracts

| Data | Refresh | Source | Public? |
|---|---|---|---|
| Pipeline phase counts | hourly | Paperclip DB export | yes |
| Agent heartbeat summary | hourly | Paperclip API/DB export | partial |
| Latest decisions | hourly/on event | Paperclip issues + Notion | yes after redaction |
| Expense totals | on edit + hourly export | expenses.csv / Notion | yes |
| Live/Demo portfolio KPIs | hourly | T6 logs / Darwinex / Myfxbook | yes |
| Open positions | 15 min internal, hourly public aggregate | T6 / broker | aggregate only |
| Deploy manifests | on approval | `deploy-manifests/*.yaml` | yes after redaction |
| Raw logs, account IDs, credentials | never | local/VPS only | no |

## Public Widgets

1. **Now:** current phase, latest episode, latest major decision, cost-to-date.
2. **Paperclip Board:** agents online/offline, issue counts by state, blockers, latest completed heartbeat summaries.
3. **Strategy Factory:** strategy cards extracted, EAs built, candidates by phase, PASS/FAIL/REJECT counts.
4. **Strategy Archive:** retained QuantMechanica archive, rebuilt with V5 data, source citations, phase history, evidence links, Paperclip-style status chips.
5. **Live/Demo Portfolio:** T6 status, Demo vs backtest drift, PF/DD/trade count, risk state.
6. **Deployment Ledger:** approved manifests, EA/symbol/timeframe, magic number, approval date, verification proof.
7. **Expense Log:** total spend, budget used, latest expense, monthly burn.
8. **Episode Library:** latest episode, artifact pack, decisions covered, related strategies/issues.
9. **Process Roadmap:** active company processes, milestone state, checklist progress, last review date, latest lesson learned.
10. **Get in Contact / Support:** contact CTA, newsletter, collaboration inquiry path, Buy-me-a-coffee support CTA. Donation/support wording must stay separate from portfolio performance claims.

## Paperclip Style UI

Use the visual language of an operations board inside the existing QuantMechanica brand system (per `branding/QM_BRANDING_GUIDE.md`):

- dense tables
- status chips (PASS / PROMISING / FAIL / DEAD / LIVE)
- activity feed
- command/approval ledger
- agent lanes
- phase pipeline
- evidence links
- restrained color (Emerald `#10b981` accent, dark surface)

Homepage first viewport should answer:

```text
What is QuantMechanica?
What is running?
What changed?
What is blocked?
What did it cost?
What is the next gate?
```

## Process Roadmap Surface

The website exposes a readable version of the company operating system: research process, EA build process, backtest/retest process, quality review process, deploy manifest process, live monitoring process, incident process, episode publishing process, lessons-learned process. Generated from the same process registry the agents use internally, with private details redacted.

## Public Snapshot JSON

Initial schema:

```json
{
  "generated_at": "2026-04-21T09:00:00Z",
  "phase": "P0 Foundation",
  "agents": { "online": 4, "offline": 0, "blocked": 0 },
  "pipeline": {
    "strategy_cards": 0,
    "eas_built": 0,
    "by_phase": { "P1": 0, "P2": 0, "P3": 0, "P8": 0, "P9": 0 }
  },
  "t6": { "status": "offline", "autotrading": false, "risk_state": "green" },
  "expenses": { "spent_eur": 0, "budget_eur": 1850 }
}
```

V5 update: `by_phase` keys must reflect 15-phase pipeline (G0, P1, P2, P3, P3.5, P4, P5, P5b, P5c, P6, P7, P8, P9, P9b, P10), not the legacy 10-phase shorthand.

## Stale-Warning Rule

If `generated_at` is older than 90 minutes, the public dashboard renders a stale-warning state. Hourly export runs at HH:07; missing two consecutive runs (90+ min) means infrastructure attention needed.

## Paperclip Live Portfolio Autonomy

Paperclip can manage the live portfolio operationally if permissions are structured correctly:

- CEO decides gate progression.
- LiveOps executes approved deploy manifests.
- Observability-SRE watches health and pages on risk.
- Controlling publishes public and private KPIs.
- OWNER remains final authority for live-money P9 and emergency restart after halt.

Paperclip should not have unlimited discretionary trading authority. It can run the operating system, but every money-at-risk action must be traceable to a manifest and an approval event.

## MT5 UI Automation Strategy

Preferred order:

1. Templates/profiles first.
2. Scripted chart bootstrap.
3. Calibrated UI automation fallback.

The automation must prove: target terminal is T6, symbol exists and chart is open, timeframe matches manifest, EA is attached, setfile inputs match hash/manifest, AutoTrading state is correct, logs are clean. If any proof fails, LiveOps aborts and asks for review instead of guessing.

## Launch Criteria

- [ ] Public dashboard reads real snapshot JSON, not mock data
- [ ] Hourly export runs for 72h without manual repair
- [ ] T6 status appears on dashboard even before live deployment
- [ ] Expense log matches Notion and repo CSV
- [ ] Deploy manifest ledger is visible with redactions
- [ ] Board approves public/private data boundary
