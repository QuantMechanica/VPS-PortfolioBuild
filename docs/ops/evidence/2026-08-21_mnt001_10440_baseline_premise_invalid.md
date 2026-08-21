# MNT-001: QM5_10440/NDX KS baseline — premise invalid, no baseline generated

**Date:** 2026-08-21
**Router task:** `f421b62a-277b-421a-b638-33e6d8568bcd`
**Authority for this note:** Claude, orchestration cycle 2026-08-21T10:16Z
**Disposition:** STOP — do not generate or stage a baseline. Premise measured and found wrong.

## The ticket's premise

MNT-001 asked to "generate the KS baseline for 10440/NDX from its canonical Q10
full-history evidence and STAGE it" because `chk_ks_baseline_dormancy` reports
`no_baseline_file=['10440/NDX']` against `portfolio_manifest_live_24sleeve_20260724.json`.

## What was actually measured

1. **There is exactly one Q10 evidence row for QM5_10440/NDX.DWX, and it is a
   FAIL, not a PASS:**
   `D:/QM/reports/pipeline/QM5_10440/Q10/NDX_DWX/aggregate.json` —
   `verdict=FAIL`, `reason=dd_above_ceiling:dd_pct=31.01:max=25.0`, generated
   2026-07-25T16:36:18Z. Confirmed by grep of every `aggregate.json` under
   `D:/QM/reports/pipeline/QM5_10440/**` for `phase=="Q10"` — only this one row
   exists.
2. `framework/scripts/gen_q10_baseline.py` (the generator this ticket points at)
   only emits baselines for **Q10-PASS** aggregates — see
   `_iter_q10_pass_aggregates()` (filters `d.get("verdict") != "PASS"`) and the
   module docstring ("When an (EA, symbol) pair PASSes Q10 ... writes a ...
   baseline"). There is no PASS to generate from. Running the tool honestly
   would refuse (no PASS aggregate found) or require hand-feeding a FAIL report,
   which the ticket's own hard-stop forbids ("do not invent work to fill the
   ticket").
3. **This was already independently investigated and adjudicated twice before:**
   - `decisions/2026-07-26_book_final24b_minus10440_plus11422.md` — OWNER-delegated
     decision (2026-07-25/26) that **removed QM5_10440/NDX from the live book**
     specifically because of this Q10 FAIL (pf 1.07, dd 31.0%, 490 trades, "six
     points over the 25% ceiling, no boundary case"), and admitted QM5_11422/USDCAD
     in its place.
   - `docs/ops/evidence/2026-08-02_10440_q10_path.md` — a full lineage adjudication
     concluding the Q10 FAIL is real for its binary but lineage-invalid (missing
     Q02-Q09 chain), and explicitly recommending **against** any direct baseline
     work: "There is no honest existing one-line Q10 enqueue command: it would
     bypass the defects above. This ticket intentionally supplies none."

## Secondary finding: the health check is reading a stale manifest

`chk_ks_baseline_dormancy` computes `nofile=['10440/NDX']` from
`D:/QM/reports/portfolio/portfolio_manifest_live_24sleeve_20260724.json`
(2026-07-24). That manifest predates the 2026-07-26 FINAL24b decision that removed
10440 and admitted 11422. If the live book genuinely moved to FINAL24b (per the
decision doc) and the health checker still reads the superseded 24-sleeve
manifest as ground truth, the WARN itself may be stale/misattributed — it may be
measuring a sleeve that is no longer live rather than a real coverage gap.

This was **not verified against T_Live** (ROT: live account/book state is out of
scope for this task and for Claude's standing authorization to change
unilaterally) and no manifest, queue, baseline, or live state was touched.

## What was and was not done

- No baseline file was written (staging or live).
- No pipeline verdict, work item, manifest, or T_Live state was changed.
- This document is the only artifact produced.

## Recommendation (for the Entscheidungsschlange, not executed here)

1. Confirm whether T_Live is actually running FINAL24b (11422 in, 10440 out) or
   still the stale 07-24 24-sleeve set — this determines whether
   `chk_ks_baseline_dormancy`'s source-of-truth manifest needs to be repointed at
   the current live manifest.
2. If 10440 is confirmed off the live book, `no_baseline_file=['10440/NDX']`
   should be suppressed at the source (retired sleeves need no KS baseline) rather
   than surfaced as an actionable WARN every cycle.
3. MNT-001 as scoped should be closed as premise-invalid, not retried as-is.
