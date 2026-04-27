<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34947da58f4a81a29de5c04561b50eba
Title: Project Charter
Mirrored: 2026-04-27T11:24:00Z by Documentation-KM (QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
-->

# Project Charter

## Mission

Rebuild the QuantMechanica strategy-mining factory on clean infrastructure, operated by a revised Paperclip multi-agent company, fully documented on YouTube as the Build-in-Public series. End-goal: a profitable, publicly-tracked live portfolio of mechanical trading strategies by month 12.

## Success Criteria (12-Month Horizon)

| Dimension | Target | How measured |
|---|---|---|
| **Live portfolio** | ≥5 live EAs, combined PF ≥1.3, max DD ≤15% | Myfxbook / DarwinexZero |
| **Research depth** | ≥10 distinct sources mined, ≥100 EA candidates tested | Pipeline DB + Git |
| **Content** | ≥20 YouTube episodes published | youtube.com/@quantmechanica |
| **Community** | ≥1000 newsletter subscribers, ≥500 YT subs | Buttondown + YT analytics |
| **Transparency** | 100% of costs logged publicly | Expense Log sub-page |
| **Board cadence** | Weekly Board review, monthly phase gate | Meeting notes |

## Decision Rights

| Decision | Final Authority | Board Input | Veto |
|---|---|---|---|
| Live deploy (real money) | Fabian | Claude-Assistant, Codex | Fabian |
| Infrastructure spend > €200 | Fabian | Board | Fabian |
| Paperclip agent hire/fire | Fabian | Board | Fabian |
| Strategy PASS/FAIL judgement | Paperclip CEO (agent) | Quality-Tech | Fabian |
| Sweep/research dispatch | Paperclip CEO (agent) | — | Fabian |
| YouTube episode publish | Fabian | Board | Fabian |
| Blog / newsletter publish | Fabian | Board | Fabian |
| Website changes | Fabian | Board | Fabian |

## Stakeholders

- **Fabian Grabner** — Founder, CEO, Final Authority, on-camera host
- **Claude-Assistant** (Opus 4.7 1M) — Board Member, strategy sparring, playbook author
- **Codex** — Code review + phase-boundary audit
- **Paperclip CEO Agent** — Operational CEO inside the Paperclip company (distinct from Fabian the human CEO)
- **YouTube viewers** — Witnesses, feedback channel, eventual customers
- **Darwinex** — Broker + data source

## Out of Scope (V5)

- NinjaScript + Futures (deferred to V6, planned Summer 2026)
- Mobile app / iOS client
- Multi-user Paperclip workspace (still solo operator)
- Sub-ms HFT strategies
- Any manual-discretionary trading

## Risk Register (Top 5)

1. **Same-VPS factory/live contention** (T1-T5 sweeps could degrade T6 Live/Demo) → mitigation: T6 isolation, process priority, factory pause thresholds, optional fallback Live VPS if unsafe
2. **Darwinex data outages** (observed historically) → mitigation: Tick Data Suite local cache as fallback
3. **YouTube tone drifts from data-driven to hype** → mitigation: Board review every episode pre-publish
4. **Paperclip agent-loop failures** (observed in V1) → mitigation: fresh company, no old QUAA issue import, revised prompts with explicit halt-and-ask triggers
5. **Solo-founder burnout** — mitigation: weekly Board cadence, Fabian sets pace
