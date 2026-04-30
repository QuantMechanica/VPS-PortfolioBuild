# QuantMechanica V5 — Project Backlog

Created: 2026-04-26
Owner of this file: OWNER + Claude Board Advisor
Refresh cadence: every meaningful state change (new commit / new decision / phase boundary)
Source of truth: filesystem + this file. Phase-0 detail in `docs/ops/PHASE0_EXECUTION_BOARD.md`.

This file is the single backlog across all phases of V5. It was created on 2026-04-26 when Paperclip was not yet installed and the only actors were OWNER + Board Advisor. As of 2026-05-01, Paperclip is online, Wave 0 is hired, and the org has expanded into Wave 1+ ahead of strict bootstrap order — the live picture lives in § Today's Reality below and the canonical machine-readable runtime source is [`public-data/company-runtime.json`](public-data/company-runtime.json) (postgres-backed snapshot, regenerated hourly). Per-item "Today's owner: Board Advisor" annotations later in this file are stale and tracked for cleanup under QUA-588 follow-ups.

## Specification Density Principle (2026-04-26)

OWNER position: Paperclip should work things out itself wherever it can. This file pre-specifies less than it could.

What this file pins down:

- **Phases and their outer boundary** (acceptance gate per phase, dependencies between phases)
- **Today's actor labelling** (so OWNER knows what is actually unblocked)
- **Hard constraints** that Paperclip cannot override (CLAUDE.md hard rules, brand tokens, magic-number scheme, T6 isolation, Phase Final trigger)

What this file deliberately leaves to Paperclip Wave 0+:

- **Per-issue decomposition** of any workstream item — that is CEO + CTO + the responsible role's job once they exist
- **Sub-process design** inside each named process — `processes/01..12-*.md` are starting templates from the laptop, not frozen specs
- **Routine cadences** beyond the few that must hit hard rules (hourly snapshot, daily briefing trigger, P10 KS-test cadence)
- **EA design content** — strategy logic, parameter starting points, lane choices
- **Org evolution** — which roles get hired in which Wave beyond the Wave 0 / Wave 6 endpoints already named

When Paperclip is online and asks "what should I do here?", the answer is usually: *what do you propose, given the constraints?* — not *here is the answer pre-baked*.

## Today's Reality

_Last refreshed: 2026-05-01 (W. Europe). Canonical runtime source: [`public-data/company-runtime.json`](public-data/company-runtime.json) — postgres-backed snapshot, regenerated hourly. Numbers in this section must match that file ± one refresh window; if they drift, this file is wrong, not the JSON._

Paperclip is installed and operating in `monitor_only` autonomy with `overall_status = alert` (per the snapshot at 2026-04-30T22:31 UTC). 14 agents in roster, 9 active, 5 terminated/paused.

### Phase status

| Phase | Status | What's true on 2026-05-01 |
|---|---|---|
| Phase 0 — VPS Foundation + Specs | 🟡 partial | Most P0 specs migrated. Open: T1-T5 + T6 isolation proof, P0-21 TDM verification, VPS slippage/latency calibration JSON. |
| Phase 1 — Paperclip Bootstrap | 🟡 partial | Paperclip company exists; Wave 0 hired (CEO, CTO, Documentation-KM live; Research idle since 2026-04-28). PC1-00 (Drive `.git/` exclusion) closed. Org has expanded into Wave 1+ (DevOps, Pipeline-Operator, Development, Quality-Tech, Quality-Business) ahead of strict bootstrap order. |
| Phase 2 — V5 Framework Implementation | ⬜ not yet executed | Smoke EA gate not cleared. Operating under DL-040 sequential model — single SRC + single strategy + first-matrix-hold; first matrix dispatch OWNER-gated. |
| Phases 3–6 | ⬜ blocked | Sequential gating per phase map below. |
| Phase Final — Founder-Comms | 🚫 deferred | per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`. |

### Agent roster (14 total · 9 active · 5 terminated/paused)

#### Live — heartbeat enabled, producing runs

| Agent | Role | Cadence | Snapshot status | In-flight / blocked |
|---|---|---|---|---|
| CEO | ceo | ~12 runs/h | running | 1 in_progress, 17 blocked |
| CTO | cto | ~32 runs/h | idle (heartbeat-on) | 0 in_progress, 11 blocked |
| Documentation-KM | general | ~7 runs/h | idle (heartbeat-on) | 0 in_progress, 1 blocked |
| DevOps (`86015301`) | devops | ~3 runs/h | running | 0 in_progress, 4 blocked |
| Pipeline-Operator | engineer | ~9 runs/h, throttled | idle (heartbeat-on) | 0 in_progress, 7 blocked — first-matrix-hold per DL-040 |

#### Wake-on-demand — heartbeat off, fires only on assignment

| Agent | Role | Last heartbeat | Snapshot status | Notes |
|---|---|---|---|---|
| Research | researcher | 2026-04-28 | idle | 2 blocked; awaiting OWNER reboot decision (QUA-588 F5/F7) |
| Quality-Tech | qa | 2026-05-01 | idle | 0 blocked |
| Quality-Business | qa | 2026-04-29 | idle | 0 blocked |
| Development | engineer | 2026-04-29 | running flag, `stuck_session` finding | 12 blocked; **effectively paused** — runtime stuck-session detector active, no real runs in 50h. Treat as paused for planning. |

#### Paused / terminated (5)

| Agent | Role | State | Notes |
|---|---|---|---|
| DevOps 2 (`0e8f04e5`) | devops | paused | Pause set 2026-04-29 |
| DevOps (`12c5c03f`) | devops | terminated | Superseded by `86015301` |
| DevOps 2 (`9f2e41f3`) | devops | terminated | Duplicate retirement 2026-04-29 |
| FoundingEngineer | engineer | terminated | Superseded by Development + CTO split |
| Quality-Business (`f2c79849`) | qa | terminated | Retired 2026-04-28, replaced by `0ab3d743` |

OWNER (Fabian) remains the gate decision-maker (real-money approval, T6 ops, manifest sign-off, agent hire/fire, DL-040 first-matrix release). Codex on the laptop is no longer a routing actor — the VPS Paperclip CTO agent now owns CTO duties.

### Live initiatives

- **Reboot plan landing (QUA-588 F5):** `docs/ops/PAPERCLIP_COMPANY_REBOOT_PLAN_2026-04-30.md` and `_ISSUES_2026-04-30.md` exist on disk but are untracked in git. CEO-level GO/NO-GO decision pending. **Link will go live here once F5 GO is recorded;** until then, treat the plan as proposal-only.
- **DL-040 sequential operating model in effect:** single SRC + single strategy + first-matrix-hold; 36-symbol parallelism only within one phase on one strategy; first matrix dispatch OWNER-gated. Pipeline-Operator + Development are deliberately throttled until OWNER lifts the hold. See `decisions/DL-040_*` and the QUA-588 audit transcript.
- **PROJECT_BACKLOG.md realignment (QUA-588 F1–F8):** this F4 commit closes one of eight follow-ups against the 2026-05-01 Board Advisor audit. The other seven (worktree-discipline sweep, garbage-file cleanup, DL-029 limbo, reboot GO, token-burn triage, Research pause vs build-queue, T1-T5 parallel dispatch evidence) are tracked under QUA-588 sub-issues.

### Burn rate

| Metric | 2026-05-01 value | Trend target |
|---|---|---|
| Weekly run count | ≈14,656 runs/week (audit baseline ≈14,639) | Hold or decline |
| Projected monthly | ≈58,624 runs/month | Below 60k until Phase 2 closes |
| Provider run cap | 0 (not configured) | n/a — threshold ratio 0.9 |
| Throughput vs spend | 14k+ runs/week, **zero V5 EAs through P10** | Trend down once QUA-211 (Pipeline-Op process_loss) and QUA-372 (Development hot-poll) close |

Any backlog item assigned to a Paperclip role below routes to that agent's worktree branch (`agents/<role>`). The legacy "Today's owner: OWNER + Board Advisor" annotations in Phase 0–6 sections predate Paperclip and are being cleaned up under QUA-588 follow-ups; until then, re-route by reading the role name, not the actor name.

## Phase Map (the real sequence)

```
Phase 0 — VPS Foundation + Specs                     ← we are here
Phase 1 — Paperclip Bootstrap (install + Wave 0)
Phase 2 — V5 Framework Implementation                ← needs Wave 0 + Codex
Phase 3 — First V5 EA Through Pipeline               ← needs Wave 1-2
Phase 4 — V5 Portfolio Build                         ← needs Wave 2-3
Phase 5 — Live Deployment on T6                      ← needs Wave 4 (LiveOps)
Phase 6 — Public Dashboard Live                      ← parallel-eligible from Phase 1
Phase Final — Founder-Comms / Chief of Staff         ← Wave 6, all triggers must hold
```

Phases are mostly sequential, with Phase 6 (public dashboard) eligible to run partly in parallel from Phase 1 onward (snapshot schema can be built before there's much to display).

---

## Phase 0 — VPS Foundation + Specs (in progress)

Anchor doc: `docs/ops/PHASE0_EXECUTION_BOARD.md` (rows P0-01 to P0-29).

### Done

- ✅ P0-01 Hetzner AX42-U ordered + Windows Server 2022 installed (2026-04-22)
- ✅ P0-02 / P0-03 Windows hardening (RDP port move, IPBan, admin rename) (2026-04-22)
- ✅ P0-07 Public repo skeleton (`QuantMechanica/VPS-PortfolioBuild`)
- ✅ P0-20 News calendar seed installed + verified on `D:\QM\data\news_calendar\` (2026-04-24)
- ✅ P0-21 Canonical reconstruction docs migrated from laptop (2026-04-25)
- ✅ P0-22 Pipeline phase spec rewritten (15-phase V2.1 model) (2026-04-25)
- ✅ P0-23 Process registry migrated (12 process docs + README, byte-identical from laptop) (2026-04-25)
- ✅ P0-24 V5 strategy artifacts migrated as labelled legacy reference (2026-04-26)
- ✅ P0-25 V4 news-impact tooling decision (RUNNER NOT PRESENT — V5 builds new) (2026-04-26)
- ✅ P0-27 V5 sub-gate spec reconstructed (`docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`) (2026-04-26)
- ✅ P0-28 Brand system migrated + V5 brand guide (`branding/`) (2026-04-26)

### In progress (today's actual owner = OWNER and/or Board Advisor)

- 🟡 P0-26 V5 EA framework — **DESIGN DONE, defaults locked, implementation pending**.
  - Today's owner: blocked on Phase 1 (Paperclip + Codex agent for MQL5 work). Board Advisor Claude can author MQL5 by hand if OWNER prioritizes that over waiting for Paperclip — but that bypasses the agent-routing per `ORG_SELF_DESIGN_MODEL.md`.
  - Recommendation: defer until Phase 1.
- 🟡 P0-29 Framework trade-mgmt + chart UI extension — **DESIGN DONE, implementation pending** (continues from P0-26, same blocker).

### Not started — actionable today

- ⬜ **P0-04 / P0-05 MT5 T1-T5 + T6 install + isolation proof** — OWNER walks the install, Board Advisor scripts the validation. Today's owner: OWNER + Board Advisor.
- ⬜ **P0-06 DarwinexZero / MT5 access confirmation** — OWNER confirms Demo + Live login work. Today's owner: OWNER.
- 🟡 **P0-21 Verify Tick Data Manager DarwinexZero GMT/DST settings + install Custom Tick Data** — **CURRENT ACTIVE TASK per OWNER 2026-04-26.** Per `docs/ops/TICK_DATA_MANAGER_DARWINEX_TIME.md`. Pflicht-Voraussetzung vor jedem Backtest UND vor sinnvollem Paperclip-Bootstrap (Wave 0 CTO/Pipeline-Operator brauchen funktionierende TDM). Today's owner: OWNER + Board Advisor (script) + manual MT5 walkthrough. Evidence target: `D:\QM\reports\setup\tick-data-timezone\`. *This is the bridge between Phase 0 closeout and Phase 1 (Paperclip Bootstrap).*
- ⬜ **P0-13 T6 deploy manifest schema** — schema.yaml exists in `LIVE_T6_AUTOMATION_RUNBOOK.md`; needs first dry-run validation. Today's owner: Board Advisor (spec review), deferred for execution to Phase 5 LiveOps.
- ⬜ **P0-15 Public expense log v0** — CSV + repo. Today's owner: OWNER (data) + Board Advisor (format).
- ⬜ **P0-16 quantmechanica.com dashboard snapshot schema** — already specced in `docs/ops/WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md`. JSON contract needs first version. Today's owner: Board Advisor.
- ⬜ **P0-17 Process registry + roadmap** — process docs migrated; public-facing roadmap surface still TBD. Today's owner: Board Advisor (draft) + OWNER (sign-off).
- ⬜ **P0-19 Buy-me-a-coffee + get-in-contact website CTA contract** — copy + page spec. Today's owner: OWNER (decision) + Board Advisor (spec).

### Not started — blocked on Phase 1+

- 🚫 **P0-10 Install fresh Paperclip company** — *this IS Phase 1*. Listed in P0 board for completeness but Phase 1 belongs to Phase 1.
- 🚫 **P0-11 Hire first four agents (CEO, CTO, Research, Documentation-KM)** — Phase 1.
- 🚫 **P0-12 Seed-strategy import list** — Research agent's first issue, blocked on Phase 1.
- 🚫 **P0-14 EP01 recording** — Documentation-KM's task, plus video editing. Today's owner: OWNER alone if launched manually before Phase 1.
- 🚫 **P0-18 Agent skill matrix** — `docs/ops/AGENT_SKILL_MATRIX.md` exists but is a forward-looking doc; activation depends on Wave 0 hiring.

### Phase 0 acceptance gate (per board)

Phase 0 closes when: T1-T5 + T6 isolation proven, Paperclip V5 company exists with no QUAA imports, public repo exists from commit 1 (✅), process registry + skill matrix + first milestone board exist (✅ for first two; milestone board lives in Paperclip = Phase 1), expense log contains real Hetzner order, news calendar verified (✅), EP01 published or ready for human approval, Codex sign-off on Notion-vs-repo no contradictions.

**Realistic gap to close Phase 0:** MT5 install + DST validation + T6 isolation proof + first manifest dry run + EP01 ready. Paperclip install is overlapping Phase 0 / Phase 1 boundary.

---

## Phase 1 — Paperclip Bootstrap

**Goal:** install Paperclip on the VPS, hire Wave 0 (CEO, CTO, Research, Documentation-KM), prove the agent runtime works.

**Anchor doc:** `docs/ops/PAPERCLIP_V2_BOOTSTRAP.md` (this is the canonical plan — do not invent a new bootstrap sequence).

**Today's owner:** OWNER (install + agent prompt approval) + Board Advisor (validation + evidence capture).

**Prerequisite from Phase 0:** P0-21 Custom Tick Data verification must pass. CTO + Pipeline-Operator agents cannot do useful Phase 2 work without verified TDM data.

### Workstream

- ⬜ **PC1-00 Drive-sync `.git/` exclusion + repo isolation pattern** — **NEW + CRITICAL** based on V4 mass-delete incident 2026-04-20 (see `lessons-learned/2026-04-20_mass_delete_incident.md`). Before Paperclip writes to the repo concurrently, the VPS must mirror the architectural fix V4 never closed: `.git/` excluded from any Drive sync surface, per-repo git mutex strategy decided, stale `index.lock` monitor planned. Today's owner: OWNER + Board Advisor.
- ⬜ **PC1-01 Install Paperclip in `C:\QM\paperclip\`** — currently empty by design, awaiting installer
- ⬜ **PC1-02 Browser / control plane health check on `http://localhost:3100`**
- ⬜ **PC1-03 Migrate / author the 13 system prompts into Paperclip** — Drive has CTO Agent prompt as a reference (`Notion: CTO Agent — System Prompt`, with verbatim hard rules already aligned to V5); 4 Wave-0 prompts must ship for PC1 close. Existing V4 prompts on Drive `Company/Agents/` are V5 BASIS, not blank-page rewrites.
- ⬜ **PC1-04 Hire Wave 0**: CEO-Claude, CTO-Codex, Research-Claude, Documentation-KM-Claude with their V5 prompts
- ⬜ **PC1-05 Wire Paperclip to repo**: agents read `CLAUDE.md`, `docs/ops/`, `processes/`, `branding/`, `framework/`, `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md` as canonical
- ⬜ **PC1-06 First org-design issue** — CEO's first task per `docs/ops/ORG_SELF_DESIGN_MODEL.md`: propose which roles become live agents and when
- ⬜ **PC1-07 First milestone board** populated with Phase 0 closeout + Phase 2 framework implementation

### Phase 1 acceptance gate

Wave 0 agents online and producing heartbeats. CEO has produced first org proposal. Documentation-KM is mirroring decisions into Notion. CTO has reviewed `framework/V5_FRAMEWORK_DESIGN.md` and signaled GO for Phase 2.

---

## Phase 2 — V5 Framework Implementation

**Goal:** Codex (now hired as Paperclip CTO agent) implements the 25-step framework spec, producing compilable shared library + EA template + harness.

**Anchor doc:** `framework/V5_FRAMEWORK_DESIGN.md` § Implementation Order (steps 1–25).

**Today's owner:** blocked on Phase 1 close (need CTO-Codex agent).

### Workstream

- ⬜ **PC2-01 to PC2-25** = framework spec implementation steps (`QM_Errors` → `QM_Branding` → `QM_Logger` → ... → `QM_Common` → `EA_Skeleton` → harness scripts → smoke regression)
- ⬜ **PC2-26 Quality-Tech review** of full framework before any V5 strategy EA is built (Wave 2 hire required)
- ⬜ **PC2-27 sync_brand_tokens.ps1 + brand_report.ps1** scripts (per `framework/V5_FRAMEWORK_DESIGN.md`)

### Phase 2 acceptance gate

Smoke EA in `framework/tests/smoke/` compiles + runs + leaves expected evidence on T1. `build_check.ps1` passes strict on the whole `framework/` tree. CTO + Quality-Tech sign off.

---

## Phase 3 — First V5 EA Through Pipeline

**Goal:** take one V5 EA from G0 Research Intake all the way to P10 Shadow Deploy. This is the first full pipeline execution and the source of the first real V5 distributions Quality-Tech needs to recalibrate sub-gate defaults.

**Anchor docs:** `docs/ops/PIPELINE_PHASE_SPEC.md`, `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`, `processes/01-ea-lifecycle.md`.

**Today's owner:** blocked on Phase 2 close + Wave 1-2 hire (Pipeline-Operator + Development + Quality-Tech + Quality-Business).

### Workstream

- ⬜ **PC3-01 G0 Research Intake** — Research agent extracts a Strategy Card from one approved source. Card lives in `strategy-seeds/cards/`.
- ⬜ **PC3-02 ea_id allocation** — CEO + CTO add row to `framework/registry/ea_id_registry.csv`
- ⬜ **PC3-03 P1 Build Validation** — Development copies `EA_Skeleton.mq5`, fills strategy logic, `compile_one.ps1 -Strict` passes
- ⬜ **PC3-04 P2 Baseline Screening** — Pipeline-Operator runs DEV-2017-2022 baseline on T1
- ⬜ **PC3-05 P3 Parameter Sweep**
- ⬜ **PC3-06 P3.5 CSR**
- ⬜ **PC3-07 P4 Walk-Forward**
- ⬜ **PC3-08 P5 Stress** (V5 calibration JSON must exist — see PC3-08a below)
- ⬜ **PC3-08a Build VPS-side `VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`** by measuring real Darwinex demo on T1 (per `PIPELINE_V5_SUB_GATE_SPEC.md` § P5 calibration source)
- ⬜ **PC3-09 P5b Calibrated Noise**
- ⬜ **PC3-10 P5c Crisis Slices** (optional)
- ⬜ **PC3-11 P6 Multi-Seed**
- ⬜ **PC3-12 P7 Statistical Validation** (PBO/DSR/MC/FDR consolidated runner)
- ⬜ **PC3-13 P8 News Impact** (incl. Hybrid A+C compliance variants per `decisions/2026-04-25_news_compliance_variants_TBD.md`)
- ⬜ **PC3-14 Quality-Tech sub-gate first calibration pass** — re-evaluate provisional defaults from `PIPELINE_V5_SUB_GATE_SPEC.md` against the first real V5 distributions; produce ADR for any threshold changes

### Phase 3 acceptance gate

One V5 EA has cleared every gate from G0 through P8 with proper evidence under `D:\QM\reports\pipeline\<ea_id>\`. Quality-Tech has produced first sub-gate calibration ADR (no surprises = blank ADR is acceptable).

---

## Phase 4 — V5 Portfolio Build

**Goal:** more V5 EAs through pipeline, P9 portfolio composition active, P10 shadow deploys running.

**Today's owner:** blocked on Phase 3.

### Workstream (high level)

- ⬜ **PC4-01 5+ EAs through G0–P8** (parallel research + build + test queue)
- ⬜ **PC4-02 P9 Portfolio Construction** — first V5 basket with family-cap-3, symbol-cap-2, ENB
- ⬜ **PC4-03 P9b Operational Readiness** checklist execution per basket
- ⬜ **PC4-04 P10 Shadow Deploy** — first 14-day shadow window with KS-test kill-switch on T6 (AutoTrading off for live, on for shadow capture)

### Phase 4 acceptance gate

A V5 basket has cleared P10 shadow with KS p ≥ 0.01 over 14 days, and OWNER has reviewed shadow evidence.

---

## Phase 5 — Live Deployment on T6

**Goal:** first V5 sleeve goes live with money at risk, monitored.

**Today's owner:** blocked on Phase 4 + Wave 4 (LiveOps) + OWNER explicit live-money approval.

### Workstream

- ⬜ **PC5-01 LiveOps deploy manifest** drafted per `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`
- ⬜ **PC5-02 OWNER manifest approval**
- ⬜ **PC5-03 LiveOps places EA on T6 chart** per manifest (Level 0/1/2/3 automation per readiness)
- ⬜ **PC5-04 Verification contract** completed (terminal, symbol, magic, hash, AutoTrading state, no errors)
- ⬜ **PC5-05 First live heartbeat** + 24h smoke check window per `processes/03-v-portfolio-deploy.md`
- ⬜ **PC5-06 Live monitoring** ongoing (Observability-SRE)

### Phase 5 acceptance gate

First V5 sleeve has been live on T6 for 7 days with no incident requiring rollback, and OWNER signs off on continued live operation.

---

## Phase 6 — Public Dashboard Live (parallel-eligible)

**Goal:** quantmechanica.com shows real V5 project state via hourly snapshot.

**Anchor doc:** `docs/ops/WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md`.

**Today's owner:** Board Advisor can draft schema + first export script today (parallel to Phase 1). Real data display blocks on Phase 1+.

### Workstream

- ⬜ **PC6-01 Public snapshot JSON schema v1** (per existing dashboard doc) — Board Advisor today
- ⬜ **PC6-02 `scripts/export_public_snapshot.ps1` skeleton** — Board Advisor today (writes mock data)
- ⬜ **PC6-03 Windows Task Scheduler hourly job** — OWNER + Board Advisor
- ⬜ **PC6-04 Netlify wire-up** — needs Phase 1 (Paperclip data sources) for non-mock content
- ⬜ **PC6-05 Stale-warning UI** at >90 min — needs Phase 1
- ⬜ **PC6-06 First real hourly snapshot live** — gates on Phase 2 (real EA build counts) + Phase 5 (live KPIs)

### Phase 6 acceptance gate

Hourly snapshot runs for 72 h without manual repair and dashboard reads real (not mock) data.

---

## Phase Final — Founder-Comms / Chief of Staff

**Status:** explicitly DEFERRED per `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`. Do not start until OWNER says "now build founder-comms" AND all of these hold:

- Phase 0 closed
- Tester commission / swap / DST / broker-time documented
- T1-T5 + T6 isolation proven
- Public dashboard hourly snapshot stable
- At least one approved EA on T6 demo through manifest
- Issue board / decision log / risk register / lessons-learned / process registry populated enough that briefings have content

**This is the email-layer phase.** Chief of Staff agent operates `info@quantmechanica.com` Gmail via reused Chrome session: daily inbound triage + 05:00 W. Europe daily briefing to OWNER. Hard wall vs LiveOps / T6 / AutoTrading.

**Frozen scope, milestone gates, risks, supporting components, and the docs to author at activation are all in `docs/ops/PHASE_FINAL_FOUNDER_COMMS.md`.** Do not edit that doc until activation.

---

## What Board Advisor Claude Can Do Today (with OWNER)

Without waiting for Paperclip:

1. **DST/custom-symbol validation on T1** — script + walkthrough + evidence
2. **MT5 T1-T5 + T6 isolation proof** — install walkthrough + evidence
3. **VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json** — measure on Darwinex demo + JSON
4. **Public snapshot schema + skeleton script** (Phase 6 PC6-01/02)
5. **Tester commission + swap docs** for the symbols V5 will run
6. **EP01 artifact pack** if OWNER wants to record + publish solo before Phase 1
7. **Phase 1 install plan in detail** so OWNER's Paperclip install hour is unblocked
8. **More framework spec detail** if Codex needs more before implementing — but spec is currently complete; gate is not "more spec", it's "Paperclip running"
9. **Brand asset SVG copy into `branding/assets/`** — small, removes Drive-mount dependency
10. **Sub-gate calibration JSON skeletons** so Phase 3's PC3-08a doesn't start cold

## What Board Advisor Claude Cannot Do (without Paperclip or OWNER override)

1. Implement MQL5 framework code as a "Codex agent" — that's CTO-Codex's role per `ORG_SELF_DESIGN_MODEL.md`. Board Advisor can write MQL5 if OWNER asks, but it short-circuits the agent-routing.
2. Run gated decisions as "CEO" — those are CEO-Claude's per the same routing.
3. Approve a deploy manifest — that is OWNER's, not any agent's.
4. Touch T6 in any way — hard rule per CLAUDE.md.

## Open Decisions Pending OWNER

- News-Compliance variants Hybrid A+C confirmation (`decisions/2026-04-25_news_compliance_variants_TBD.md`)
- Brand Guide § 10 open items (logo SVG copy, sync auto-generation, mascot in framework)
- Framework § Confirmed Defaults — already locked, but OWNER can revisit
- 6 sub-gate spec open items (`PIPELINE_V5_SUB_GATE_SPEC.md` § Open Items)
- DST validation as next concrete physical-VPS task — confirm to start

---

## Open / Weak Items (honest review 2026-04-26)

This section enumerates known weaknesses, opens, and risks that are not closed. Reviewing these every commit prevents them from rotting silently. New items added at top.

### CRITICAL — architectural risks

1. **Drive-sync vs. `.git/` conflict (mass-delete incident class).** V4's `lessons-learned/2026-04-20_mass_delete_incident.md` shows Drive can batch-trash 12+ files in 13 s when concurrent multi-agent git writes leave orphaned `index.lock` files. **Same architecture is set up on the VPS** unless we mitigate before Paperclip Wave 0 starts writing concurrently. Mitigation tracked as PC1-00 (Phase 1 first task). Until closed, keep agent count low and serialize commits.
2. **Custom Tick Data NOT verified** — Phase 0 cannot close until P0-21 runs. Every backtest produced before this passes is `SETUP_DATA_MISMATCH` risk. **Active today.**
3. **VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json does not exist on VPS** — required for P5 Stress and P5b Calibrated Noise. V4 calibration on laptop is not transferable to new VPS. Must measure on Darwinex demo on T1 before Phase 3 runs. Tracked in `PIPELINE_V5_SUB_GATE_SPEC.md` § P5.
4. **No `.git/` exclusion documented for VPS Drive setup** — same as item 1 from a different angle. Infrastructure-Setup doc references Google Drive selective sync but does not call out `.git/` exclusion explicitly.

### HIGH — design assumptions not yet validated

5. **V5 framework is unimplemented** — full design spec exists (`framework/V5_FRAMEWORK_DESIGN.md`, 25 steps) but no MQL5 code. Until Codex implements + a smoke EA runs cleanly, the design is theory. Cannot prove the 4-module Modularity pattern, the BT-Fixed/Live-Percent ENV-enforcement, or the Friday Close hook actually compose without surprises.
6. **Sub-gate parameter defaults are provisional** — `PIPELINE_V5_SUB_GATE_SPEC.md` § Recalibration Triggers lists 6 thresholds Quality-Tech must validate after first V5 EA distributions. None of those distributions exist yet. Defaults may not survive contact with reality.
7. **News-Compliance Hybrid A+C is recommendation, not decision** — `decisions/2026-04-25_news_compliance_variants_TBD.md` is open. FTMO / 5ers blackout-window definitions not yet authored.
8. **Per-EA chart UI specced but not visually mocked** — design says 720×200 px panel with 6 tiles; whether it actually reads cleanly on T1-T6 chart density is untested. First implementation may force layout revision.
9. **13 Paperclip prompts not migrated into repo** — V4 prompts on Drive (`Company/Agents/<role>/system_prompt.md`) are reference only. Wave 0 needs V5-revised CTO + CEO + Research + Documentation-KM prompts in `paperclip-prompts/` before PC1-04. Today the repo `paperclip-prompts/` folder does not exist.
10. **EP01 artifact pack not produced** — Phase 0 acceptance gate requires EP01 published or ready; today nothing exists in `episodes/`.

### MEDIUM — process gaps

11. **Public snapshot schema + skeleton script not built** — `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md` specs the JSON contract and hourly export pattern, but no script exists in `scripts/` (folder still has only README stub).
12. **First T6 deploy manifest dry run not executed** — `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md` § "First Implementation Task" requires harmless demo dry-run before any real EA deploy. Not done.
13. **Commission / swap docs per symbol not authored** — `CLAUDE.md` § Tester Configuration requires it. Folder `docs/ops/` has no commission-per-symbol artifact.
14. **Codex doc/code-drift risk reintroduced** — `framework/V5_FRAMEWORK_DESIGN.md` references scripts that do not exist (`sync_brand_tokens.ps1`, `compile_one.ps1`, `build_check.ps1`, `run_smoke.ps1`, `brand_report.ps1`, `validate_setfile.ps1`, `rotate_logs.ps1`). This is the exact V4 failure mode L-D-08-adjacent. Mitigation: every script reference in spec docs gets a status badge `[SPEC ONLY — NOT IMPLEMENTED]` until Codex builds it.
15. **Notion ↔ Repo drift** — Notion `V5 Pipeline Design` carries my superseded-banner; Notion `Phase 0 Execution Board` is now divergent from repo (repo has P0-22..P0-31 added). Documentation-KM (Wave 0) owns reconciliation. Until then, **PROJECT_BACKLOG.md and PHASE0_EXECUTION_BOARD.md in the repo are the source of truth**, Notion lags.

### LOW — nice-to-have

16. **No logo SVG copy in `branding/assets/`** — Brand guide § 10 open question. Without it, dashboard rendering on VPS depends on Drive mount.
17. **No `framework/scripts/sync_brand_tokens.ps1` yet** — auto-generation of `QM_Branding.mqh` from `brand_tokens.json` is design-only.
18. **`PHASE_FINAL_FOUNDER_COMMS.md` and `DWX_IMPORT_AUTOMATION.md` are untracked in git** — both exist on disk but never committed. OWNER's call whether to commit or leave staged.
19. **Strategy Card template not authored** — `strategy-seeds/cards/` folder will hold V5 cards but no template defines what a Strategy Card must contain. Should be authored before first V5 Research extraction.
20. **Prop-firm rule sets (FTMO, 5ers) not authored as data** — once news-compliance decision lands, blackout-window definitions need to live as `framework/include/news_rules/{ftmo,5ers}.mqh` per the spec. Currently zero content.

### Resolved this session (for context)

- P0-21 number-drift (was conflicting with my reconstruction tasks) — fixed in PHASE0 board
- V4 learnings archive missing from repo — migrated to `lessons-learned/`
- Mass-delete incident learnings missing — migrated
- File-deletion policy missing — migrated
- V4 framework patterns (Friday Close, BT/Live convention, 4-module Modularity, gridding cap, ML ban) missing from V5_FRAMEWORK_DESIGN — added
- Framing of "V4 = legacy" too hard — corrected to "V4 = V5 BASIS, Paperclip professionalizes"

## How To Read This File

- ✅ = done with evidence
- 🟡 = in progress with current actor
- ⬜ = not started, today's actor identified
- 🚫 = blocked, blocker named
- Today's owner column tells you who can act *right now*. If the future owner is a Paperclip agent that doesn't exist, today's owner is "blocked on Phase 1" or an explicit OWNER + Board Advisor manual interim.

When status changes, update this file in the same commit as the change. When a weak/open item closes, move it to "Resolved this session" then archive on next commit.
