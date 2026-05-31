# QuantMechanica V5 — Project Backlog

Created: 2026-04-26
Owner of this file: OWNER + Claude Board Advisor
Refresh cadence: every meaningful state change (new commit / new decision / phase boundary)
Source of truth: filesystem + this file. Phase-0 detail in `docs/ops/PHASE0_EXECUTION_BOARD.md`.

This file is the single backlog across all phases of V5. It started (2026-04-26) when Paperclip was not yet installed. **As of 2026-04-27, Wave 0 is LIVE** (CEO, CTO, Research, Documentation-KM hired); **Phase 1 closed** under DL-024; **Phase 2 closed** 2026-05-01 (QUA-639 + `decisions/2026-05-01_phase2_acceptance.md`); **Phase 3 in flight** (QM5_1003 baseline, QUA-660), currently blocked on Codex token-quota outage (recovery Tue 2026-05-05 07:30 W. Europe).

**State pointers:**
- Live phase pointer (refreshed every CEO heartbeat per DL-053): `paperclip/governance/PHASE_STATE.md`.
- Tuesday restart runbook (single-sheet, 9 steps): `docs/ops/TUESDAY_RESTART_RUNBOOK_2026-05-05.md`.
- 2026-05-01 progress (this date's deliverables — see "Today's wins" below).

## Today's wins (2026-05-01) — durable changes landed

- **Phase 0 P0-21 remediated** — v2 bar compilation script forced `CustomRatesUpdate` for 33 missing-history `.DWX` symbols, T1 53M bars total written then propagated byte-identical to T2-T10 (`docs/ops/QUA-684_D2_BAR_COMPILATION_AUDIT_2026-05-01.md`, `framework/scripts/mt5/Compile_Custom_Bars_QM_v2.mq5`).
- **DL-054** anti-theater pass criteria — five binding gates a `(ea_id, phase, symbol)` run must pass before `verdict=PASS` may land in `report.csv`. Companion `framework/registry/tester_defaults.json` codifies OWNER's 100k deposit + 1000 fixed-risk.
- **DL-054 gate library** + standalone CLI runner — `framework/scripts/dl054_gates.py` + `dl054_gate_runner.py` (smoke-tested across canonical / non-canonical / stub-only / v2-recompiled symbols). CTO splices Tuesday per `framework/scripts/dl054_integration.md`.
- **QUA-662 phantom-PASS matrix invalidated** — 36/36 PASS rows quarantined; full audit + DL-054 + tester_defaults addresses every concurrent failure mode.
- **DL-055** token-burn watch ownership — CEO chose option (b) DevOps + QUA-527.
- **DL-056** Chief-of-Staff (OS-Controller scope) hired — Claude Sonnet, narrow scope (roster hygiene + token-burn watch + model-selection oversight), distinct from Wave-6 founder-comms CoS.
- **DL-057** Research-resume gate amended — was "first V5 EA reaches P7"; now "no EA queued for baseline test" (queue-empty-gated, hours-day cadence, not weeks).
- **Cost reduction**: Doc-KM + Quality-Business moved Opus 4.7 → Sonnet 4.6 (matches laptop pattern); 4 Codex agents heartbeat-disabled until Tuesday Codex restore.
- **Roster hygiene**: 6 orphan agent dirs moved to `.retired_2026-05-01/`; CEO stale memory archived; skills directory populated with 9 laptop-validated skills + `_VPS_PATHS_TRANSLATION.md` companion.
- **DevOps QUA-671 churn stopped** — 4 scheduled tasks disabled (`QM_AggregatorState_1min`, `QM_QUA95_BlockerRefresh`, `QM_RuntimeHealthScan_15min`, `QM_InfraHealthCheck_5min`), agent paused.

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

## Today's Reality (refreshed 2026-05-21 per mass-terminal audit)

Live phase pointer: see `paperclip/governance/PHASE_STATE.md`. Updated every CEO heartbeat per DL-053.

Current phase: **Phase 3 — First V5 EA Through Pipeline**. Phase 1 (Paperclip Bootstrap) closed 2026-04-27 under DL-024. Phase 2 (V5 Framework) closed 2026-05-01 under QUA-639.

| Actor | Agent ID | Status | Can do |
|---|---|---|---|
| OWNER (the human) | `local-board` | active | gate decisions, MT5 operations, sign-offs, real-money approvals, T_Live toggles, charter changes |
| Board Advisor Claude (on VPS) | n/a | active | docs, repo work, scripts, validation walkthroughs, evidence capture, brand work |
| CEO | `7795b4b0` | LIVE since 2026-04-27 | strategy, hiring, delegation, phase progression, DL ratification under DL-023 / DL-032 waivers |
| CTO | `241ccf3c` | LIVE since 2026-04-27 | framework + EA review (DL-036 gate), infra/code sign-off, build/compile validation |
| Research | `7aef7a17` | LIVE (paused per DL-044 — wake-on-demand only until first V5 EA reaches P7) | Strategy Card extraction (G0), source survey, V5 hard-rule filter |
| Documentation-KM | `8c85f83f` | LIVE since 2026-04-27 | DL recording, lessons-learned, process registry, Notion mirror, runtime-health docs, **PHASE_STATE.md ownership (per QUA-677 D1)** |
| DevOps | `86015301` | LIVE since 2026-04-29 | T1-T10 infra, worktree isolation, scheduler, log rotation, PC1-00 mitigation |
| Pipeline-Operator | `46fc11e5` | LIVE | T1-T10 backtest dispatch, 36-symbol matrix, P0..P10 phase runner, RISK_FIXED setfile generation |
| Development | `ebefc3a6` | LIVE | EA implementation from APPROVED Strategy Cards (CTO DL-036 gate before P2) |
| Quality-Tech | `c1f90ba8` | LIVE since 2026-04-28 (DL-045 early trigger) | sub-gate calibration, Step 25 framework gate, CTO peer review |
| Quality-Business | `0ab3d743` | LIVE since 2026-04-28 (DL-045 early trigger + DL-039 8-cap waiver) | G1 verdict on Strategy Cards, P9 portfolio composition review |
| Codex (laptop) | n/a | read-only | filesystem search, copy to Drive pack, source verification — no VPS write, no GitHub write |
| Paperclip Wave 3+ (Controlling, Observability-SRE, LiveOps, R&D) | n/a | NOT YET HIRED | trigger when role-specific design-intent gate fires (per `paperclip/agents/wave_plan.md`) |
| Chief of Staff (Wave 6 / Phase Final / founder-comms) | n/a | DEFERRED | Phase Final only; per DL-052 distinct from the retired OS-Controller variant (DL-048) |

- Repo: `C:\QM\repo` · Paperclip: `C:\QM\paperclip` · Live terminal: `C:\QM\mt5\T_Live` · Factory: `D:\QM\mt5\T1..T10`

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
- 🟡 P0-29 Framework trade-mgmt + chart UI extension — **DESIGN DONE, implementation pending**.

### Not started — actionable today

- ⬜ **P0-04 / P0-05 MT5 T1-T10 + T_Live install + isolation proof** — OWNER walks the install, Board Advisor scripts the validation.
- ⬜ **P0-06 DarwinexZero / MT5 access confirmation** — OWNER confirms Demo + Live login work.
- ✅ **P0-21 REMEDIATED 2026-05-01** — bar compilation forced via `framework/scripts/mt5/Compile_Custom_Bars_QM_v2.mq5`. Propagation T1 → T2-T10 byte-identical.
- ⬜ **P0-13 T6 deploy manifest schema** — schema.yaml exists; needs dry-run.
- ⬜ **P0-15 Public expense log v0**.
- ⬜ **P0-16 quantmechanica.com dashboard snapshot schema**.
- ⬜ **P0-17 Process registry + roadmap**.
- ⬜ **P0-19 Buy-me-a-coffee + get-in-contact CTA**.

### Phase 0 acceptance gate (per board)

Phase 0 closes when: T1-T10 + T_Live isolation proven, Paperclip V5 company exists, public repo exists, process registry + skill matrix + first milestone board exist, expense log contains real Hetzner order, news calendar verified, EP01 published.

---

## Phase 1 — Paperclip Bootstrap ✅ CLOSED 2026-04-27 (DL-024)

**Goal:** install Paperclip on the VPS, hire Wave 0, prove the agent runtime works.

---

## Phase 2 — V5 Framework Implementation ✅ CLOSED 2026-05-01 (QUA-639)

**Goal:** implement shared library + EA template + harness.

---

## Phase 3 — First V5 EA Through Pipeline

**Goal:** take one V5 EA from Research to Shadow Deploy.

### Workstream

- ⬜ **PC3-01 to PC3-14** (Research → Sweep → Walk-Forward → Stress → Statistical Validation → News Impact)

---

## Phase 4 — V5 Portfolio Build

**Goal:** scale to 5+ EAs, P9 portfolio composition, P10 shadow deploys.

- ⬜ **PC4-01 Controlled symbol-expansion sweeps after backlog drain** — once the
  Q02/Q03/Q04 MT5 queue is no longer backpressure-limited, take the strongest
  surviving EAs and run targeted out-of-family symbol sweeps. Do not assume that
  the original card/setfile symbol family is the only viable market: include FX
  minors/crosses, oil, metals, indices, and other canonical `.DWX` symbols when
  the strategy mechanics plausibly transfer. Expansion must be evidence-led:
  record which symbols were added, why they are plausible for the strategy, and
  whether they PASS/FAIL before promoting any new lane.

---

## Phase 5 — Live Deployment on T_Live

**Goal:** first V5 sleeve goes live with money at risk.

---

## Phase 6 — Public Dashboard Live

**Goal:** quantmechanica.com shows real V5 project state via hourly snapshot.

---

## Phase Final — Founder-Comms / Chief of Staff

**Status:** DEFERRED.

- Phase 0 closed
- Tester commission / swap / DST / broker-time documented
- T1-T10 + T_Live isolation proven
- Public dashboard hourly snapshot stable

---

## What Board Advisor Claude Can Do Today (with OWNER)

1. **DST/custom-symbol validation on T1**.
2. **MT5 T1-T10 + T_Live isolation proof**.
3. **VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json**.
4. **Public snapshot schema + skeleton script**.

## Open / Weak Items (review 2026-05-21)

1. **Mass-terminal fleet sync** — confirmed 10 factory terminals (T1-T10) on D: and one live terminal (T_Live) on C:. Doc updated.
2. **Custom Tick Data verified** — 35/35 symbols ready.
3. **Slippage calibration** — pending measurement on T1.

## How To Read This File

- ✅ = done
- 🟡 = in progress
- ⬜ = not started
- 🚫 = blocked
