# QuantMechanica V5 — Project Charter

> **V5 Source:** Notion `Project Charter` (id `34947da5-8f4a-81a2-9de5-c04561b50eba`)
> **Migrated to repo:** 2026-04-26

## Mission

Operate the QuantMechanica strategy-mining factory on clean infrastructure with
deterministic local state, evidence-bound gates, and OWNER authority. Document
the work on YouTube as the Build-in-Public series. End-goal: a profitable,
publicly-tracked live portfolio of mechanical trading strategies by month 12.

## Success Criteria (12-Month Horizon)

| Dimension | Target | How measured |
|---|---|---|
| Live portfolio | ≥5 live EAs, combined PF ≥1.3, max DD ≤15% | Myfxbook / DarwinexZero |
| Research depth | ≥10 distinct sources mined, ≥100 EA candidates tested | Pipeline DB + Git |
| Content | ≥20 YouTube episodes published | youtube.com/@quantmechanica |
| Community | ≥1000 newsletter subscribers, ≥500 YT subs | Buttondown + YT analytics |
| Transparency | 100% of costs logged publicly | Expense Log |
| Board cadence | Weekly Board review, monthly phase gate | Meeting notes |

## Decision Rights

| Decision | Final Authority | Board Input | Veto |
|---|---|---|---|
| Live deploy (real money) | OWNER | Claude-Assistant, Codex | OWNER |
| Infrastructure spend > €200 | OWNER | Board | OWNER |
| Worker/tool selection | OWNER | Claude-Assistant, Codex | OWNER |
| Source authorization and G0 approval | OWNER | Claude-Assistant, Codex | OWNER |
| Build integrity and test PASS/FAIL | Deterministic repository gates | Claude-Assistant, Codex audit | OWNER may stop, never waive evidence |
| T6/live promotion | OWNER | Deterministic test evidence + Claude-Assistant/Codex audit | OWNER |
| YouTube episode publish | OWNER | Board | OWNER |
| Blog / newsletter publish | OWNER | Board | OWNER |
| Website changes | OWNER | Board | OWNER |

## Stakeholders

- **OWNER (Fabian Grabner)** — Founder, Final Authority, on-camera host
- **Claude-Assistant (Opus 4.7 1M)** — Board Member, strategy sparring, playbook author
- **Codex** — Code review + phase-boundary audit
- **YouTube viewers** — Witnesses, feedback channel, eventual customers
- **Darwinex** — Broker + data source

## Out of Scope (V5)

- NinjaScript + Futures (deferred to V6, planned Summer 2026)
- Mobile app / iOS client
- Multi-user orchestration workspace (still solo operator)
- Sub-ms HFT strategies
- Any manual-discretionary trading
- Machine Learning in EAs (V5 ban; sources can be collected for V6 reconsideration)

## Risk Register (Top 5)

1. **Same-VPS factory/live contention** (T1-T5 sweeps could degrade T6 Live/Demo) → mitigation: T6 isolation, process priority, factory pause thresholds
2. **Darwinex data outages** (observed historically) → mitigation: Tick Data Suite local cache as fallback
3. **YouTube tone drifts from data-driven to hype** → mitigation: Board review every episode pre-publish
4. **Automation loop failures** (observed historically) → mitigation:
   deterministic local state transitions, idempotent workers, bounded retries,
   and evidence-linked stop conditions
5. **Solo-founder burnout** → mitigation: weekly Board cadence, OWNER sets pace
6. **Drive-sync vs `.git/` mass-delete-incident-class** → mitigation: PC1-00 (Drive `.git/` exclusion + git mutex) before Wave 0 starts concurrent writes (per `lessons-learned/2026-04-20_mass_delete_incident.md`)
