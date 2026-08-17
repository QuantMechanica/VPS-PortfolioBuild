# The exponent defect's real damage is false negatives: 15 EAs may have failed for the wrong reason

## What I went looking for, and what I found instead

Having fixed the generator, I swept all **31,014** setfiles for exponent notation to find
*doomed runs still in the queue*. There are **none** — 0 pending or active rows are bound to
an exponent-carrying setfile, so the bleeding is stopped.

The detector was self-tested first (5 must-hit and 8 must-miss cases, including a SHA-256
`build_hash` line that contains `e` and must not match) because a sweep reporting zero is
only meaningful if it is proven able to hit.

But 32 hits remain in 25 setfiles, and checking who they belong to inverted the whole
picture.

## QM5_41033 failing loudly was luck, not the normal case

QM5_41033 died in `OnInit` because it *had* a self-consistency guard
(`QM_InputRequireDouble`) that caught the truncated value. Across the 25 affected setfiles:

| | count |
|---|---:|
| EA guards the affected input → fails **loudly** in OnInit | **0** |
| EA does **not** guard it → runs **silently** with the wrong value | **25** |

So in every other case MT5 read the truncated value, the EA accepted it without complaint,
and the run produced a verdict that looks entirely normal. The loud failure was the
detectable case. The silent ones are the dangerous ones.

## 36 completed rows confirmed to have run with the truncated value

Confirmed by comparing each row's `expected_setfile_sha256` against the current file hash —
a path match alone is not evidence, since the file could have changed after the run:

| Taint state | Rows |
|---|---:|
| **CONFIRMED** (binding == current bytes) | **36** |
| NO_BINDING (cannot establish) | 22 |
| DIFFERENT (file changed since) | 1 |

Of the 36 confirmed: **19 PASS**, 7 FAIL, 8 INFRA_FAIL, 2 ZERO_TRADES, across 15 EAs
(QM5_13203, 13205, 20262, 20289, 20290, 20295–20302, 21516, 21527).

The affected inputs are all numerical guards: `variance_floor`, `skew_tolerance`,
`kurtosis_tolerance`, `vov_tolerance`, `rsj_tolerance`, `corr_tolerance`, `es_tolerance`,
`aliq_tolerance`, `max_tolerance`, `variance_epsilon`, `beta_tie_epsilon`, `slope_epsilon`.
Declared at `1e-8` … `1e-16`, observed by the EA as **0.1** — between 7 and 15 orders of
magnitude off.

## The impact is bounded, and that changes which risk matters

| Check | Result |
|---|---|
| EAs reaching Q08 or deeper | **none** — deepest is QM5_21516 at Q06 |
| Overlap with the Q14 optimisation cohort | **none** |
| Q10 survivors / live book members affected | **none** |
| Verdict at the deepest phase reached | **FAIL or ZERO_TRADES for all 15** |

So none of the 19 tainted PASSes admitted anything into the survivor pool — every affected
pair died later on economics. **No downstream decision rests on a tainted PASS.**

Which means the false-positive risk is nil and **the real risk is the inverse one**:

> These 15 EAs were evaluated with a numerical guard set 7–15 orders of magnitude too large.
> A `variance_floor` of 0.1 instead of 1e-12 floors variance far above any real value, so
> anything normalising by variance is crushed and the signal disappears. **They may have
> failed because the parameter was broken, not because the strategy has no edge.**

That is a false-negative — losing good strategies — and it is the more expensive error for a
farm whose job is to extract everything the strategies have. The affected family is exactly
the one where this matters: statistical-moment premium strategies on WTI and natural gas
(realised skew, kurtosis, vol-of-vol, RSJ, expected shortfall), all of which divide by a
variance estimate.

## What I am NOT claiming

I am not claiming these verdicts are wrong. Whether a tolerance of 0.1 versus 1e-12 changes
behaviour is **EA-specific and unmeasured**. What is established is that the parameter the EA
observed differed from its declared value by 7–15 orders of magnitude, which makes those 36
verdicts **unverified rather than invalid**.

The distinction matters because it determines the cheapest resolution: re-run with a
corrected setfile and compare. If the verdict is unchanged, the tolerance was inert and the
verdict stands as-is. If it changes, the original was an artefact and the EA re-enters the
funnel. Either outcome is decisive, and no verdict needs to be voided in advance.

## Required next step, and the trap in it

Regenerate the 25 setfiles and requeue the 15 EAs at Q02.

**The trap:** `gen_setfile.ps1` alone is *not* the regeneration path. I ran it directly on
QM5_41033 today and it silently dropped `qm_rng_seed`, every `qm_news_*` line,
`qm_friday_close_*` and `qm_stress_reject_probability`, and wrote `build_hash: pending`
(reverted, verified by hash). Regeneration must go through
`framework/scripts/build_check.ps1 -EALabel <label>` — **scoped**, because an unscoped
`build_check` mutated 9072 setfiles once before.

And the binding chain must be refreshed afterwards. Every regeneration changes the setfile
bytes, and QM5_41033 has already demonstrated that a repair which leaves `expected_*_sha256`
stale produces a row that cannot dispatch.

## Evidence

- `artifacts/exponent_setfile_sweep_20260817b.json` — 31,014 scanned, detector self-test recorded
- `artifacts/exponent_verdict_validity_20260817.json` — guard analysis per setfile
- `artifacts/exponent_taint_confirmed_20260817.json` — the 36 confirmed rows with binding proof
- `3844c472a` — the generator fix that prevents recurrence
- related: `2026-08-17_bars_zero_root_cause_closed_at_the_generator.md`,
  `2026-08-17_setfile_exponent_notation_kills_runs_deterministically.md`
