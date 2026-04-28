---
name: qm-zero-trades-recovery
description: Use when a backtest report has zero trades AND the EA was expected to trade (cohort threshold ≥5 ZTs across the 5-symbol baseline). Don't use for intentional no-trade gates (e.g. P8 `news_only` mode with no news in window) and don't use when cohort ZT count <5 (that is symbol-specific noise, document only).
owner: Strategy-Analyst (drafts hypothesis) + R-and-D (signoff) + CEO (dispatch) + CTO (build)
reviewer: Quality-Tech (on request)
last-updated: 2026-04-27
basis: processes/02-zt-recovery.md (board policy 2026-04-19) + V5 enhancement loop QUA-236
---

# qm-zero-trades-recovery

Procedure for handling Zero-Trade (ZT) / `NO_REPORT` outcomes from pipeline runs. The rule is **analyze-and-propose, not auto-rebuild** — ZT EAs are never silently eliminated; the protocol is a pipeline for proposals.

`no v2 indicated` is a valid terminal outcome for session-bound / event-driven designs.

## When to use

- Pipeline phase yields `NO_REPORT` (no artifact produced) and file is size-0, or
- Phase produced a report but the trade sample is empty / clustered to one cluster, AND
- The EA was **expected** to trade (not a gate-suppressed no-trade)

## When NOT to use

- `NO_REPORT` produced by an intentional gate (P8 `news_only` with no news in window, or `OFF` mode by design)
- Build failure (`compile_one.ps1` failed) — that is build territory, not ZT recovery
- `SETUP_DATA_MISSING` / `SETUP_DATA_MISMATCH` verdicts — those are setup-quality issues, fix the setup first
- Cohort ZT count is below threshold (see § Cohort threshold)

## Cohort threshold (board policy 2026-04-19)

The full dispatch chain only fires when **N ≥ 5 ZT-detections across the 5-symbol baseline cohort** (3 Forex pairs + Gold + 1 Index).

| Cohort ZT count | Verdict | Action |
|---|---|---|
| `< 5` | Symbol-specific noise, not strategy defect | Document in `ZT_RootCause` only; **no dispatch** |
| `≥ 5` | Strategy-edge concern | Full dispatch chain (steps below) |

Rationale: <5 ZT means the failure is isolated to one or two symbols → symbol-parameter concern, not EA-edge concern.

## Iteration policy (max depth)

| Stage | Threshold | Action |
|---|---|---|
| v1 → v2 | N ≥ 5 ZTs on v1 across cohort | Strategy-Analyst drafts hypothesis |
| v2 → v3 | N ≥ 5 ZTs on v2 | Same |
| v3 → v4 | N ≥ 5 ZTs on v3 | Same |
| **Hard cap** | v4 ALSO trips ≥5 ZTs | **Permanent REJECT** — flag `Company/data/ea_registry.json` `status: permanently_rejected`, `rejection_reason: zt_cohort_after_v4`. Never auto-requeue. |

After 4 iterations, edge is either absent or hypothesis is fundamentally wrong → further rebuilds consume budget without producing signal.

## V5 framing (per QUA-236)

In V5 the recovery loop is **`_v2` enhancement loop**:

- `_v2` is filed as a new EA from P1 onward (full pipeline, not restart from a later phase)
- Same Strategy Card lineage preserved; new pipeline-history row added
- `_v2` gets its own `ea_id` allocation (or sub-slot allocation per CTO convention)
- Issue assignee = CTO

This replaces V4's "modify in place" pattern that lost evidence trails.

## Procedure

### 1. Detect

A pipeline phase finishes with verdict `NO_REPORT` or zero-trade sample.

- **First disambiguation: file-size check on `.htm`.** Per `docs/ops/PIPELINE_PHASE_SPEC.md` § Hard Rules: a size-0 `.htm` is `NO_REPORT`. Never declare a "dead EA" without this check.
- If size > 0 but zero trades parsed: classify as `NO_REPORT` and continue.

### 2. Cohort scan

Pull all phase results for this `ea_id` across the 5-symbol baseline cohort:

```text
Cohort: 3 Forex pairs + Gold + 1 Index (per board policy 2026-04-19)
Count ZT-class verdicts: NO_REPORT + zero-trade-sample + intent-trade-but-no-fills
```

If count < 5 → write `ZT_RootCause_<SM_ID>_<YYYYMMDD>.md` with **terminal** verdict "below-threshold, symbol-specific". No dispatch. Stop.

If count ≥ 5 → proceed to step 3.

### 3. Strategy-Analyst drafts hypothesis

Strategy-Analyst writes `ZT_RootCause_<SM_ID>_<YYYYMMDD>.md` with:

- Failure hypothesis (one of: missing input data / wrong filter / wrong calibration / EA bug / session-bound design)
- Cohort table (per-symbol verdict)
- Proposed v(N+1) modification (or `no v2 indicated` if session-bound)
- Reference to the original Strategy Card

Strategy-Analyst does **not** dispatch directly — must wait for R-and-D signoff.

### 4. R-and-D signoff (gate)

R-and-D reviews the hypothesis. Two outcomes:

| Verdict | Effect |
|---|---|
| `acknowledged` | CEO may dispatch the v(N+1) build |
| `reject — <reason>` | Hypothesis returned; Strategy-Analyst iterates OR hypothesis is terminal (e.g. `reject — session-bound/event-driven`) |

If Strategy-Analyst and R-and-D cannot reach agreement, both positions go to CEO as a tie-break.

### 5. CEO dispatch

On every CEO heartbeat, scan `Company/Analysis/ZT_RootCause_*` for entries with R-and-D signoff. For each cohort-≥5, signed-off entry, create:

```text
Sub-Issue:
  title: "ZT Recovery v(N+1)-build <SM_ID> <YYYYMMDD>"
  assignee: CTO
  body: link to ZT_RootCause file + Strategy Card
```

CEO never skips the signoff gate.

### 6. CTO builds v(N+1)

CTO builds `<SM_ID>_v(N+1).mq5` per V5 framework conventions (see `qm-build-ea-from-card`). Treats v(N+1) as a new EA from P1 onward.

### 7. Pipeline-Operator queues v(N+1) in baseline

Once `.ex5` compiled and registered, Pipeline-Operator queues v(N+1) on the cohort. Logs recovery lineage (parent ea_id, version, hypothesis link).

### 8. Strategy-Analyst writes comparison

After v(N+1) baseline lands: Strategy-Analyst writes `v1_vs_v(N+1)_<SM_ID>_<YYYYMMDD>.md` showing:

- Per-symbol cohort outcome v1 vs vN+1
- Did the hypothesis fix the ZT class?
- Metrics improved or degraded vs prior version?

### 9. Re-evaluate

| v(N+1) cohort result | Action |
|---|---|
| `< 5 ZTs` AND metrics improve | Promote to P5 candidate. Close dispatch parent with comparison link. |
| `≥ 5 ZTs` AND depth < v4 | Re-enter chain at step 3 (next iteration) |
| `≥ 5 ZTs` AND depth = v4 | **Permanent REJECT**. Flag `ea_registry.json`. Documentation-KM archives the four-version hypothesis trail. |

## SLA

- Detection → `ZT_RootCause` draft: **1 heartbeat** (Strategy-Analyst 15-min cadence)
- R-and-D signoff verdict: **1-2 business days**
- CEO dispatch after signoff: **same heartbeat** as scan
- CTO v(N+1) build → Pipeline-Operator v(N+1) baseline: **1-3 business days**
- Strategy-Analyst comparison: **1 heartbeat** after vN+1 baseline lands
- Total budget per iteration: **5 business days** from `ZT_RootCause` draft to pass / reject / next-iteration. Exceeding auto-escalates to CEO + board.

## Boundary

- This skill does **not** silently eliminate ZT EAs — analyze-and-propose only.
- This skill does **not** modify the original v1 EA — `_v(N+1)` is always a new EA from P1.
- Strategy-Analyst does **not** dispatch directly — R-and-D signoff is mandatory.
- CEO does **not** skip the signoff gate.

## References

- `processes/02-zt-recovery.md` — full ZT / NO_REPORT recovery flow
- `processes/14-ea-enhancement-loop.md` — V5 `_v2` enhancement loop wrapper (forthcoming, QUA-236 child #4)
- `CLAUDE.md` § "ZT Recovery Protocol" — protocol source
- `docs/ops/PIPELINE_PHASE_SPEC.md` § Hard Rules — `NO_REPORT` size-0 disambiguation
- `processes/01-ea-lifecycle.md` — Actors table (G4 Support roles)
- Auto-memory anchor (Fabian): "ZT EAs must be analysed + v2-rebuilt, never silently eliminated" — feedback memory in agent layer
