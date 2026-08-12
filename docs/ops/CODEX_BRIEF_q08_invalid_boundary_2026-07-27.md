# Codex brief — stop flattening Q08 `INVALID` into `INFRA_FAIL`

Date: 2026-07-27
Priority: high. This is your own finding; it is now cleared for implementation.

## Background

Your read-only diagnosis under task `4458d308`
(`docs/ops/evidence/2026-07-27_q08_valid_setfile_infra_fail_distribution.md`,
reviewed and APPROVED by Claude) split the 158 Q08 `INFRA_FAIL` rows that hold valid
current set files into 7 disjoint causes. Only **2 of 158** are transient
(`ACTIVE_TIMEOUT`); **at least 129 are deterministic** with unchanged inputs.

You identified the boundary defect yourself:

```text
if verdict_upper == "INVALID":
    return "INFRA_FAIL", reason or "phase_runner_invalid_report"
```

in `tools/strategy_farm/farmctl.py`. Q08 had already recorded deterministic evidence
insufficiency, and the work-item boundary erased the distinction and made it look
generically retryable. 32 rows are exactly this.

Your own recommended boundary behaviour, which this brief authorises:

1. Preserve `INVALID` (or a dedicated non-retryable `EVIDENCE_INVALID`) through the
   work-item boundary.
2. Permit automatic retry only for an allow-list of transient reasons such as
   timeout/runner-loss, with bounded attempts.
3. Bind Q08 evidence to set-file and upstream-artifact hashes: a repaired current file
   must create a fresh row, never make an old aggregate look valid.
4. Treat `FAIL_HARD` as strategy evidence and never convert it to infra.

## Why it matters now

`INFRA_FAIL` is not a merit verdict, so these rows are invisible to sleeve accounting
while consuming retry capacity. Sleeve supply is the binding constraint on the FTMO
programme: only 15 sleeves are gate-clean with usable evidence, and the best one scores
0.41 against a target of 1.0
(`docs/ops/evidence/2026-07-27_sleeve_improvement_targets.md`). Rows misfiled as
retryable infra are both wasted tester time and hidden information about which sleeves
are genuinely dead.

## What to do

1. Implement items 1, 2 and 4 above. Item 3 (hash binding) may be a separate change if
   it is large — say so rather than half-doing it.
2. **Do not mass-requeue.** Reclassification is the deliverable; requeues are a separate
   decision. Report how many rows change class and what each new class means.
3. Verify no existing surface breaks: dashboards, cockpit, `phase_label()`, and any
   consumer that assumes the current verdict vocabulary. Qxx naming rules apply to
   operator surfaces — never expose raw `P*` keys.
4. Add a regression test that an upstream `INVALID` does not become a retryable
   `INFRA_FAIL`.

## Constraints

- Do NOT run `Factory_OFF.ps1` or `Factory_ON.ps1`.
- Do NOT interrupt running backtests; do not touch `C:/QM/mt5/T_Live`.
- Do NOT requeue or mutate work items beyond the reclassification the fix itself
  performs, and state exactly what it performs.
- Commit with explicit pathspecs. Evidence over claims.

## Deliverable

The fix plus `docs/ops/evidence/2026-07-27_q08_invalid_boundary_fix.md`: what changed,
the before/after class counts across all 204 `INFRA_FAIL` rows, which surfaces were
checked, and the test.
