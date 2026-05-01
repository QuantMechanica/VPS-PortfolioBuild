# DL-040 — Token-Discipline Throttle: Single-Active-Strategy + Single-Active-Source + Heartbeat Tuning + Matrix-Dispatch Hold

- **Date:** 2026-04-28
- **Authority:** OWNER directive 2026-04-28 ~17:55 local (relayed via Board Advisor on [QUA-504](/QUA/issues/QUA-504))
- **Recording task:** [QUA-504](/QUA/issues/QUA-504)
- **Operates under:** DL-017 + DL-023 + DL-032 (CEO unilateral on operational + internal-process classes)
- **Relationship to:** DL-029 (Strategy Research Workflow — operationalises and re-emphasises), DL-038 (Seven Binding Backtest Rules — adds explicit hold on first 36-symbol matrix dispatch)

## Source directive (verbatim)

> *"we have to be careful about token usage! so only one strategy and project after another, not too much in parallel."*
> — OWNER 2026-04-28 17:55 (local), to Board Advisor

Trigger: Anthropic org monthly cap + Codex shared-adapter usage cap hit simultaneously. Without budget-alarm pre-emption (rejected at `ab75321e`), parallelism multiplied spend faster than expected.

## Binding rule (sequential by default)

```
SRC<N>            (one source at a time — research extraction + pipeline)
  ↓
  S<n>            (one strategy at a time within the active SRC)
    ↓
    P<phase>      (one phase at a time within the active strategy)
      ↓
      36 symbols × T1-T5      (parallel — KEEP, this is the necessary parallelism)
```

**Cross-strategy parallelism = OFF.** **Cross-phase parallelism = OFF.** **Cross-source parallelism = OFF.**
**Per-symbol parallelism within a single phase on a single strategy = ON** (DL-038 Rule 2 stays binding).

### Single-active-strategy

ONE Strategy Card actively in P1 → P10 at any time. When that strategy reaches a verdict (PASS-through, FAIL-at-phase per DL-038, zero-trades-`_v2`-loop), the next sub-issue under the active SRC parent unblocks.

Already codified per QUA-236 (DL-029) + DL-038 Rule 4 (fail-fast). **Re-emphasized: this rule was not being honored.** Multiple cards were being scaffolded by Development simultaneously (`davey-eu-night`, `davey-eu-day`, `davey-baseline-3bar`, `davey-es-breakout`, `davey-worldcup`, `chan-pairs-stat-arb`, multiple Lien strategies). Stop.

### Single-active-source

Already codified per DL-029 + `paperclip-prompts/research.md` § THE CORE RULE. **Re-emphasized: violated.** Research extracted SRC02 (Chan QT) → SRC03 (Williams) → SRC04 (Lien) → SRC05 (Chan AT WS) overlapping. Stop.

CEO does NOT open SRC<N+1> until SRC<N> has all strategies extracted AND all those strategies have moved through the pipeline (PASS-through or final verdict).

### First-matrix-dispatch hold

DL-038 Rule 2 (36-symbol matrix per phase across T1-T5) stays binding *as a rule*, but the **first** execution of that rule on the **first** EA is held until OWNER explicitly green-lights. ~150-200 backtest runs (multi-pass, 36-symbol × 5-terminal) is meaningful tester compute + agent-coordinated logging tokens. OWNER decides when to spend that budget.

Until then, single-symbol P2 baseline runs on ONE EA at a time stay OK as long as Pipeline-Op respects the single-active-strategy rule.

## Heartbeat tuning (applied this heartbeat)

| Agent | Pre-DL-040 | Post-DL-040 | Rationale |
|---|---|---|---|
| CEO (`7795b4b0`) | 1800s (30 min, DL-024) | **3600s (60 min)** | Reverts DL-024 30-min cadence under throttle pressure; wakeOnDemand still on for OWNER-triggered work |
| Pipeline-Operator (`46fc11e5`) | 600s (10 min) | **1800s (30 min)** | Reduces idle polling; Pipeline-Op woken by OWNER posts and child-issue events |
| Development (`ebefc3a6`) | 600s (10 min) timer | **event-only (heartbeat.enabled = false)** | Aligns with DL-029 / `paperclip-prompts/development.md` event-driven model; idle polling adds zero value, multiplies Codex spend |
| CTO (`241ccf3c`) | 3600s (60 min) | unchanged | Already at target |
| DevOps (`0e8f04e5`) | 3600s (60 min) | unchanged | Already at target |
| Documentation-KM (`8c85f83f`) | 7200s (120 min) | unchanged | Already at target |
| Quality-Tech (`c1f90ba8`) | event-only (disabled) | unchanged | Already event-only |
| Quality-Business 2 (`0ab3d743`) | event-only (disabled) | unchanged | Already event-only |
| Research (`7aef7a17`) | event-only (disabled) | unchanged | Already event-only |

`wakeOnDemand: true` stays enabled everywhere. OWNER comments and assignment events still wake all agents instantly.

## Issue-level enforcement (applied this heartbeat)

- [QUA-393](/QUA/issues/QUA-393) (`lien-fade-double-zeros _v1` P1 build, SRC04_S03) → **blocked**, blocked by [QUA-302](/QUA/issues/QUA-302). Resumes after SRC01 verdict completion.
- [QUA-352](/QUA/issues/QUA-352) (SRC05 Chan AT extraction parent) → **blocked**. Research must not extract additional cards until SRC01 → SRC04 verdict-clear and CEO opens SRC05.
- All SRC01 davey siblings (QUA-277/278/279/280/281) and their P1 build issues (QUA-303/304/305/306) remain blocked behind the active strategy.
- All SRC02/SRC03/SRC04 strategy cards remain blocked.
- Active strategy: [QUA-302](/QUA/issues/QUA-302) (P1 davey-eu-night re-validate, SRC01_S1, parent QUA-277).
- Active source: SRC01 (Davey).

## Zombie-recovery sweep (applied this heartbeat)

QUA-471..QUA-499 sweep verified — all "Recover stalled issue" wrappers either `done` or `cancelled`. Two non-recovery items in that range remain useful:

- [QUA-479](/QUA/issues/QUA-479) (`backlog`) — CTO design task: stranded_assigned_issue recovery should detect shared-adapter rate-limit caps and skip the cascade. **Keep open** — directly addresses the root cause that made the cap-storm so noisy.

## Quality-Business state (deferred to next heartbeat)

DL-039 records original QB at `f2c79849`; that agent now lives as `quality-business-retired-2026-04-28`. `0ab3d743` (Quality-Business 2) is `idle` / `enabled: false`. Cleanest path is one-pass retirement of the duplicate when limits clear; deferred this heartbeat to keep the DL focused on the throttle directive.

## What CEO will NOT do under DL-040

- Pre-emptively pause any agent. `wakeOnDemand: true` is enough — pausing adds reattachment overhead without saving spend.
- Cancel in-flight build artifacts on QUA-393. The EA work is preserved on disk; we resume there when SRC01 verdicts clear.
- Open cancellation issues for in-flight work. Natural drain via DL-038 Rule 4 fail-fast handles most of it.

## Boundary

- T6 stays OFF LIMITS as ever (DL-025 / DL-030).
- Per-symbol parallelism within ONE phase on ONE strategy is the only parallel pattern allowed.
- OWNER green-light required before next 36-symbol matrix dispatch (first execution of DL-038 Rule 2 in production-shape).

## Reverse links

- DL-029 ↔ DL-040: DL-040 re-emphasises and operationalises the binding-sequential rule that DL-029 codified at the workflow level. DL-040 adds the agent-config-level enforcement (heartbeat tuning, sweep) that DL-029 alone could not deliver.
- DL-038 ↔ DL-040: DL-040 holds the **first** dispatch of DL-038 Rule 2 (36-symbol matrix) until OWNER green-light. The rule itself stays binding for all future phases.
- DL-024 ↔ DL-040: DL-040 reverts DL-024's 30-min CEO cadence to 60-min under throttle pressure. DL-024's authority basis (DL-023) is unchanged; DL-040 is a subsequent operational decision under the same waiver.
- DL-023 ↔ DL-040: DL-040 is recorded under the DL-023 broadened-authority waiver (class 4: internal process choices → throttle / sequencing / heartbeat cadence).

## 2026-04-29 Option B amendment (A1)

- **Date/time:** 2026-04-29 06:30 local
- **Authority:** OWNER wake comment on [QUA-504](/QUA/issues/QUA-504)
- **Recording task:** [QUA-508](/QUA/issues/QUA-508)

Source directive:
> "Lift matrix-dispatch hold for SINGLE-SYMBOL runs only."
> — OWNER, 2026-04-29 06:30 local (via wake comment)

Policy update:
- **GREEN-LIT now:** single-symbol-per-phase dispatch for one active strategy at a time, using one symbol (`primary_target_symbols[0]`, default `EURUSD.DWX`), across full phase progression.
- **Expected run-budget shape:** approximately 5-10 runs per strategy through P1-P10, versus approximately 150-200 runs for first full 36-symbol matrix fan-out.

Still gated:
- First full **36-symbol matrix** dispatch remains OWNER-gated.
- **Multi-EA parallelism** remains OFF under DL-040 sequential throttle.
- **T1-T5 simultaneous-EA on the same strategy** remains OFF until explicit matrix go.

Unlock conditions for first full 36-symbol matrix dispatch:
- QUA-372 fix implemented and verified.
- 3-5 consecutive days of stable token usage after this amendment.
- 1-2 strategies completed cleanly through P1-P10 under single-symbol mode.
- Explicit OWNER "matrix go" comment on [QUA-504](/QUA/issues/QUA-504).
