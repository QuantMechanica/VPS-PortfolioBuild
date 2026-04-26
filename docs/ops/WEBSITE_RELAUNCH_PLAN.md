# Website Relaunch Plan

> **V5 Source:** Notion `Website Relaunch Plan` (id `34947da5-8f4a-814f-9267-c66ba0f2a169`)
> **Migrated to repo:** 2026-04-26

**Horizon:** Relaunch targeted for month 3-4 of V5 build (~2026-07 / 2026-08).
**Hosting:** Continue on easyname (already paid).
**Stack:** Static site generator (Astro or 11ty) + Netlify CDN + Paperclip-style live operations dashboard.
**Update cadence:** hourly public snapshot by VPS Task Scheduler; sensitive T6/live details remain private.

## Core Sections (Revised from March 2026 version)

1. **Hero — The Build in Public Story**
   - One-paragraph: "I'm building a trading-strategy factory live on YouTube. Every source, every EA, every cent of spend documented."
   - Latest YouTube episode embed

2. **Live Dashboard**
   - Pipeline state snapshot (how many strategies extracted, how many in which phase per `PIPELINE_PHASE_SPEC.md` 15-phase model)
   - Live EA performance (from Myfxbook + DarwinexZero APIs)
   - Portfolio composite equity curve
   - Updated hourly per `QUANTMECHANICA_DASHBOARD_SPEC.md`

3. **Strategy Archive (USP, retained and rebuilt with new V5 data)**
   - Public list of every V5-tested strategy plus legacy strategy-seeds clearly marked as pending re-test
   - Source citation, Strategy Card, PASS/FAIL/REJECT, phase history, why
   - Searchable + filterable by source, market, timeframe, style, phase, status, live/demo usage
   - Visual style: QuantMechanica brand voice + Paperclip operations-board density (status chips, evidence links, agent decisions, manifest references)
   - Locked detail-pages available to newsletter subscribers (soft-gate CTA)

4. **Episode Library**
   - All YouTube episodes with show notes, transcript, code links
   - Cross-linked to Strategy Archive

5. **Public Expense Log** (mirror of `expenses/PUBLIC_EXPENSE_LOG.md`)

6. **Newsletter Signup (Buttondown)**

7. **About / Contact / Legal**
   - Keep the get-in-contact path visible and direct
   - Separate collaboration/investor inquiries from project donations

8. **Process Roadmap**
   - Public view of how the Paperclip company works: processes, owners, checklist status, review cadence, latest lessons learned
   - Generated from internal process registry with private details redacted

9. **Support the Build**
   - Buy-me-a-coffee CTA on episode pages, YouTube descriptions, and optional dashboard footer
   - Must be framed as project support, not an investment ask

## Paperclip-Style Dashboard Principle

The website remains QuantMechanica first: pipeline, strategy archive, contact, legal, newsletter, and the existing professional dark/teal design direction stay. The relaunch extends with a public operations board: current phase, agents, blockers, strategy factory, T6 Live/Demo status, deploy manifests, expenses, process roadmap, latest episode evidence.

## Live Dashboard Technical Spec

### Data Flow

```text
VPS Windows Task Scheduler (hourly HH:07) → export_public_snapshot.ps1
Paperclip SQLite/API + T6 logs + reports + expenses + process registry → redacted public-data/*.json
public-data/*.json → git commit/push when changed → Netlify rebuild/cache refresh → dashboard read
Notion + expenses.csv → hourly docs/expense export → dashboard read
```

Primary scheduler: Windows Task Scheduler on Hetzner VPS. GitHub Actions and Netlify Scheduled Functions are fallback/support tools only, because they do not own the local MT5/Paperclip state.

### Tech Choices

- **Frontend:** Astro + Tailwind (current brand palette: Slate-950 + Emerald per `branding/brand_tokens.json`)
- **Charts:** Observable Plot or Recharts (pick based on bundle size)
- **Hosting:** Netlify (same as current)
- **CMS for episode/blog content:** Notion-to-Markdown export via GitHub Action

### Dashboard Widgets

Full dashboard spec: `docs/ops/QUANTMECHANICA_DASHBOARD_SPEC.md`.

| Widget | Source | Refresh | Notes |
|---|---|---|---|
| Strategies in pipeline by phase | Paperclip DB | hourly | bar chart, 15 phases |
| Portfolio equity curve | Myfxbook | hourly | line chart |
| Live EAs: win rate, PF, DD | DarwinexZero | hourly | card grid |
| Latest PASS | Paperclip DB | on event | banner |
| Total cost to date | Expense Log | manual update + hourly | tile |
| YouTube subscriber count | YT API | daily | tile |

## Content Migration

Current site (March 2026 version) has: Hero, Archive teaser, Myfxbook embed, Shop, Newsletter. Keep the copy voice (professional, data-driven, first-person "I"), keep the current design direction, keep the Pipeline and Get in Contact paths, and keep the Strategy Archive as a core asset.

Relaunch adds: Paperclip-style Project Dashboard, rebuilt Strategy Archive with fresh V5 data, Episode Library, Expense Log, Deploy Manifest Ledger, Process Roadmap, Buy-me-a-coffee support CTA.

Deprecate: Shop (defer — no EA sales until live portfolio has 90-day track record).

## Launch Criteria

- [ ] Dashboard pulls real data (not mock) for all 6 widgets
- [ ] At least 10 published strategies in Archive
- [ ] At least 10 YouTube episodes published
- [ ] Expense Log up to date
- [ ] Newsletter integration tested (signup confirm + welcome)
- [ ] Legal / imprint compliant with AT law
- [ ] Board pre-launch review passed
