---
dl: DL-036
date: 2026-04-28
title: EA Review Gate codification — APPROVED-card → P1..P10 backtest issues carry Review-only `executionPolicy` with CTO interim reviewer; Pipeline-Op may not P2-baseline an EA without sign-off
authority_basis: DL-023 (CEO broadened-autonomy waiver, class 4 — internal process choices) + DL-030 Class 3 (Review-only `_v[0-9]+` EA enhancement) — DL-036 is additive
recording_issue: QUA-301
related_g0_gate: QUA-276 (CEO G0 Strategy-Card review gate, Class 2)
status: active
---

# DL-036 — EA Review Gate Codification

Date: 2026-04-28
Issue: [QUA-297](/QUA/issues/QUA-297) (OWNER 2026-04-28 audit — operational changes triggered)
Recording issue: [QUA-301](/QUA/issues/QUA-301) (this entry's authoring task)
Owner: CEO (`7795b4b0-8ecd-46da-ab22-06def7c8fa2d`)
Recorder: Documentation-KM (`8c85f83f-db7e-4414-8b85-aa558987a13e`)
Authority: [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — class 4 "internal process choices → execution-policy convention" + [DL-030](./2026-04-27_execution_policies_v1.md) Class 3 (Review-only `_v[0-9]+` EA enhancement). DL-036 is **additive** to DL-030, not a supersede.
Status: Active. Additive to DL-030.

> **Recorder's note (Doc-KM scope per BASIS).** This DL records the *EA Review Gate* CEO codified on 2026-04-28 in response to OWNER audit feedback ("strategies should be reviewed by CEO before programmed, EA should also be reviewed, then backtests can start"). The CEO part of that directive is already gated by QUA-276 (G0 Strategy-Card review = Class 2 in DL-030). This DL closes the EA part: every APPROVED-card-→-pipeline-run issue carries Review-only execution policy with CTO as the interim reviewer (Quality-Tech swap on Wave 2 hire). The 5 PATCHes already applied to QUA-277 / 278 / 279 / 280 / 281 are the inflight evidence trail.

> **DL-NNN-collision note.** QUA-301 preallocated this entry as **DL-035**. While QUA-301 was being staged, `agents/docs-km` had already committed DL-033 for the OWNER addendum on no-strategy-prioritization + canonical lifecycle (recording task QUA-272, commit `f434e6b`). Per registry convention "skipped numbers are intentional gaps; do not reuse" and the "max(existing) + 1" allocation rule, the QUA-301 omnibus shifts up by one: heartbeat → DL-034, load-balancing → DL-035, this entry → **DL-036**. The work product itself is unchanged.

## Decision

Every issue with a title matching the regex

```
^SRC\d+_S\d+ — .* \(APPROVED card → P1\.\.P10 pipeline run\)$
```

is created (or PATCHed before `in_progress`) with a Review-only `executionPolicy` listing CTO as the participant (interim until Quality-Tech is hired in Wave 2; participants array swaps to QT agent id at hire). Pipeline-Operator may **not** P2-baseline (or move past P1 to P2) an EA whose APPROVED-card → P1..P10 issue has not received CTO Review-only sign-off.

This is **additive** to [DL-030](./2026-04-27_execution_policies_v1.md):

- **DL-030 Class 3** intercepts `_v[0-9]+` EA *enhancement* issues (`Trend_v2`, `Reversal_v3`, etc.) — those are rebuilds triggered by the closed list in [`processes/14-ea-enhancement-loop.md`](../processes/14-ea-enhancement-loop.md).
- **DL-036** intercepts the *first* P1..P10 backtest run for a freshly APPROVED card — the `_v1` baseline that DL-030 Class 3 does not match (since `_v1` typically isn't suffixed in the title).

The two together close the loop: every EA → backtest pathway is Review-gated regardless of whether it is a fresh build or a rebuild.

## Why

OWNER audit directive on 2026-04-28 (QUA-297), verbatim:

> Strategies should be reviewed by CEO before programmed, EA should also be reviewed, then backtests can start.

That sentence carries two gates:

1. **Strategy review (CEO)** — corresponds to G0, the Strategy-Card Review-only policy already in force as DL-030 Class 2 (interim reviewer = CEO, Wave 2 swap to Quality-Business). Tracking: [QUA-276](/QUA/issues/QUA-276).
2. **EA review (CTO interim → Quality-Tech)** — *not yet* codified before this DL. Pipeline-Op was nominally free to begin P2 baseline runs once a card was APPROVED, with no runtime gate enforcing CTO inspection of the actual MQL5 build. DL-036 is the missing runtime gate.

Without DL-036, Pipeline-Op's good behaviour was the only thing preventing a half-built EA from chewing through P1..P10 compute before CTO had a chance to flag obvious build issues (input parsing, magic-number drift, news-mode wiring, etc.). Runtime enforcement converts "should review" into "cannot self-close".

## Authority

- **Class 4 of [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md)** — "internal process choices → execution-policy convention for stakes-bearing flows".
- **Builds on [DL-030](./2026-04-27_execution_policies_v1.md) Class 3** — same shape (Review-only with CTO interim → Quality-Tech Wave 2), different scope test (title-pattern instead of `_v[0-9]+`).

CEO acted unilaterally per DL-023 ("err toward acting"). The 5 PATCHes already applied this heartbeat (QUA-277 / 278 / 279 / 280 / 281) are the in-flight enforcement; DL-036 is the audit trail and the convention for all future SRC0N_Sn issues.

## Implementation mechanism

**Per-issue, set at creation time, by convention.** Issue creators (CEO, Pipeline-Op, Development) attach the policy at creation; CEO sentinel sweep PATCHes any in-flight issue that slipped through.

### Scope test

Title regex (case-sensitive, anchored): `^SRC\d+_S\d+ — .* \(APPROVED card → P1\.\.P10 pipeline run\)$`.

Examples that match:

- `SRC03_S2 — Trend MA Cross (APPROVED card → P1..P10 pipeline run)`
- `SRC07_S1 — Reversal RSI Divergence (APPROVED card → P1..P10 pipeline run)`

Examples that don't match (handled elsewhere):

- `Trend_v2 fixes` (DL-030 Class 3)
- `T6 deploy QM5_0007` (DL-030 Class 1)
- `SRC03_S2 — extraction parent` (DL-030 Class 2)

If a title drifts off the regex (e.g. extra parenthetical, different phase suffix), the issue creator MUST either match the regex or attach the policy explicitly via PATCH. The convention is the regex; the policy is the substance.

### Policy (interim, until Quality-Tech is hired Wave 2)

```json
{
  "mode": "normal",
  "commentRequired": true,
  "stages": [
    {
      "type": "review",
      "participants": [
        { "type": "agent", "agentId": "241ccf3c-ab68-40d6-b8eb-e03917795878" }
      ]
    }
  ]
}
```

`agentId: "241ccf3c-ab68-40d6-b8eb-e03917795878"` is CTO. When Quality-Tech is hired, CEO PATCHes the participants array to the QT agent id on every in-flight DL-036 issue. The swap is identical to the DL-030 Class 3 swap and can be batched in one CEO heartbeat.

### Pipeline-Operator binding rule

Pipeline-Op may not move an EA past P1 (i.e. may not begin P2 baseline) until the parent `^SRC\d+_S\d+ — .* \(APPROVED card → P1\.\.P10 pipeline run\)$` issue has cleared the Review stage. Concretely: the issue's `executionState.status` must be `running` (not `pending`) on the Review stage, and the runtime must have intercepted the `done` transition successfully.

Pipeline-Op heartbeat checks include: "for each EA in active P2..P10 baseline, verify the parent SRC0N_Sn issue's `executionPolicy` Review stage was satisfied". If a P2..P10 run is observed for an EA whose Review stage is `pending`, Pipeline-Op safety-stops the cohort and posts a CEO escalation comment.

### CEO sentinel role

Per [DL-030](./2026-04-27_execution_policies_v1.md) § "Sentinel role", CEO scans for unpolicied issues in scope and PATCHes a policy in. This applies identically to DL-036 — every CEO heartbeat sweep includes "issues matching the DL-036 regex without a Class-3-shaped Review stage".

## Source change (in-flight evidence)

5 PATCHes already applied by CEO this heartbeat (the same heartbeat that filed QUA-301):

| Issue | EA | Status pre-PATCH | Status post-PATCH |
|---|---|---|---|
| QUA-277 | first SRC0N_S1 candidate | unpolicied | Review-only / CTO |
| QUA-278 | second candidate | unpolicied | Review-only / CTO |
| QUA-279 | third candidate | unpolicied | Review-only / CTO |
| QUA-280 | fourth candidate | unpolicied | Review-only / CTO |
| QUA-281 | fifth candidate | unpolicied | Review-only / CTO |

The 5 PATCHes are the operational change DL-036 codifies. CEO's [DL-027](./DL-027_basis_active_diff_propagation_rule.md) propagation classification for those PATCHes: `reference_only` (the policy attaches to the issue, not to an agent prompt body).

## Acceptance evidence

- [x] DL-036 entry filed (this document)
- [x] `decisions/REGISTRY.md` row added (alongside DL-034 and DL-035)
- [x] `processes/process_registry.md` references EA Review Gate (added in this commit alongside the existing DL-030 Class 3 row when the Execution Policies section reconciles into `agents/docs-km` in the next merge with `main`; for now, an EA Review Gate subsection is added inline so the convention is discoverable)
- [x] 5 in-flight QUA-277..281 PATCHes applied by CEO this heartbeat
- [ ] Pipeline-Op heartbeat check updated to include the DL-036 verification — Pipeline-Op task to follow under a child of QUA-301
- [ ] Class-3 reviewer participant swap from CTO interim to Quality-Tech when QT is hired Wave 2 (batched with the DL-030 Class 3 swap)

## Risk

- **Title-regex drift.** If an issue is created with a title that doesn't match the regex, the convention is bypassed. Mitigation: CEO sentinel sweep + the explicit PATCH path; issue creators are now bound by the convention.
- **Stale CTO interim.** If Wave 2 Quality-Tech hire never lands, CTO carries Class-3 + DL-036 review indefinitely. Mitigation is the same as DL-030 Class 3 — a one-line PATCH per in-flight issue at hire time. Both swaps can be batched.
- **Self-review prevention.** The runtime excludes the original executor from being selected as reviewer. CTO is rarely the executor on SRC0N_Sn issues (Pipeline-Op or Development executes), so this is a low-probability conflict. If CTO ever executes one of these issues, the runtime will reject the Review stage and CEO must PATCH a fallback participant in (e.g. CEO + OWNER, mirroring DL-030 Class 2).
- **Phase-1 ambiguity.** "P2-baseline an EA without CTO sign-off" is the binding rule. If a P1 dry-run is needed for sanity (e.g. compile + zero-trades probe), Pipeline-Op may execute P1 without the Review gate satisfied — but **must not** cross into P2 until the Review stage is cleared. The boundary is "P1 → P2", not "any backtest run".

## Cross-links

- **Authority basis:** [DL-023](./2026-04-27_ceo_autonomy_waiver_v2.md) — CEO Autonomy Waiver, broadened scope.
- **Companion (additive):** [DL-030](./2026-04-27_execution_policies_v1.md) Class 3 — same Review-only shape, different scope test (`_v[0-9]+` enhancement vs. APPROVED-card → P1..P10 baseline).
- **G0 sibling:** [QUA-276](/QUA/issues/QUA-276) — the strategy-review half of the OWNER directive (DL-030 Class 2 / CEO interim → Quality-Business Wave 2).
- **Source / driver:** [QUA-297](/QUA/issues/QUA-297) — OWNER 2026-04-28 audit ("strategies should be reviewed by CEO ... EA should also be reviewed, then backtests can start").
- **Recording task:** [QUA-301](/QUA/issues/QUA-301) — this DL entry's authoring task (the recording omnibus for DL-034 / DL-035 / DL-036).
- **Source change:** 5 in-flight PATCHes on QUA-277 / QUA-278 / QUA-279 / QUA-280 / QUA-281 applied by CEO this heartbeat.
- **Process file:** [`processes/process_registry.md`](../processes/process_registry.md) § "EA Review Gate" (added in this commit).
- **Registry:** [`decisions/REGISTRY.md`](./REGISTRY.md) — DL-036 row.
- **DL-027 propagation classification:** `reference_only` — no agent prompt body change. Pipeline-Op's heartbeat-check addition (above) will be a separate `config_patch` recorded under its own follow-up child issue.

## Boundary reminder

DL-036 only governs the SRC0N_Sn → P1..P10 baseline gate. T6 stays Approval-only via DL-030 Class 1 + V5 hard rule. T6 OFF LIMITS still applies regardless of any P1..P10 outcome — DL-036 says "CTO must Review before P2"; live deploy still says "OWNER must Approve before T6".

— CEO operational convention under DL-023 broadened-autonomy waiver, ratified 2026-04-28 in response to OWNER audit (QUA-297), additive to DL-030 Class 3. Recorded by Documentation-KM 2026-04-28.
