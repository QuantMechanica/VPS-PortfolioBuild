# FTMO Phase 1 measured as a first-passage problem

Date: 2026-07-27
Author: Claude
Script: `tools/strategy_farm/portfolio/challenge_firstpassage.py`
Reproduce: `python tools/strategy_farm/portfolio/challenge_firstpassage.py`

## What changed

Every campaign figure produced on 2026-07-26/27 answered

> P(+10% **within 22 trading days**)

FTMO removed the maximum trading period in 2024. Codex verified this against
ftmo.com under task `9b7c6aaf` and recorded it in the campaign audit: *"The
challenge now has no maximum trading period. The 22-day horizon is an
OWNER-imposed sprint objective, not an FTMO rule."* The rule FTMO actually
applies is a first-passage problem between two barriers:

> reach +10% on **balance**, before -5% on any day or -10% total, no deadline.

`challenge_as_deployed.py`'s own docstring (lines 24-27) dismissed the unlimited
horizon on sample-size grounds - *"a 250-day window leaves roughly three
independent samples"*. That dismissal conflated two different estimators. A
longer **fixed window** does collapse the sample count. **First passage** does
not: every start day runs until it resolves, so every start day yields an
outcome, and time-to-resolution becomes an output rather than a constraint. The
dismissal was wrong and this document supersedes it.

## Three corrections to the instrument, all tightening

1. **Target on end-of-day balance.** FTMO requires the balance above target with
   all positions closed. The earlier scripts passed on the intraday closing event
   that first crossed the target, while other positions might still have been
   open (`challenge_final.py:168`). Codex raised this. For this sleeve class -
   flat overnight by construction - an end-of-day balance test is exactly right.
2. **Four-trading-day minimum enforced.** FTMO requires it; no earlier script
   checked it. Codex raised this.
3. **Censoring reported, not hidden.** Starts that reach the end of the data
   still alive are counted as FAIL in every headline and shown separately. All
   rates below are therefore lower bounds.

## A defect this found in my own filter

`challenge_as_deployed.py` and the first run of this script treated a missing
`entry_time` as zero span, which silently reclassified sleeves of unknown
holding period as intraday-flat. `12823/USDJPY` (0 of 1548 records carry
`entry_time`) entered the book that way and appeared in several top
combinations. Coverage is now a **precondition**: a sleeve whose span cannot be
established is excluded as unknown, not assumed flat. Eleven sleeves are excluded
on this ground.

## A defect this found in the adversarial review

The 2026-07-26 Codex review reported that all six cited stream files "lack usable
`entry_time` on every record", listing `10553: 2,615/2,615 missing; 10848:
1,344/1,344; 13036: 1,352/1,352; 13108: 553/553; 13213: 1,596/1,596; 13301:
551/551`, and concluded that "the available data permit an actual rate of
**0/830**".

Measured against the files on disk on 2026-07-27, every one of those six has
**100% coverage**:

| stream | rows | with `entry_time` | missing |
|---|---:|---:|---:|
| `10553_XAUUSD_DWX.jsonl` | 2615 | 2615 | 0 |
| `10848_XAUUSD_DWX.jsonl` | 1344 | 1344 | 0 |
| `13036_GDAXI_DWX.jsonl` | 1352 | 1352 | 0 |
| `13108_XTIUSD_DWX.jsonl` | 553 | 553 | 0 |
| `13213_USDJPY_DWX.jsonl` | 1596 | 1596 | 0 |
| `13301_GDAXI_DWX.jsonl` | 551 | 551 | 0 |

The row counts match the review exactly, so the population was identified
correctly and the presence test was inverted. 119 of 189 streams carry
`entry_time`. The "0/830 is admissible" conclusion does not hold: multi-day spans
are identifiable from current evidence, which is why this script can partition
sleeves rather than distrust all of them. Sample record from
`9936_USDJPY_DWX.jsonl`: `"time":1507579200,"entry_time":1507544806`.

This does **not** rescue intraday equity. Span is not a path; the daily-loss cap
still cannot be evaluated exactly for sleeves that hold over a day. It changes
who must be excluded, not what is measurable.

## The structural result: leverage inverts

Under a 22-day sprint, size is what reaches the target in time. Against fixed
barriers, size is pure variance: as leverage rises, drift per unit of noise falls
and P(pass) decays toward the driftless 10/(10+10) = 50%.

OOS pass rate by leverage, overlay held at each sleeve's in-sample choice.
Parenthesis is the censored share:

| sleeve | 1x | 2x | 3x | 5x |
|---|---|---|---|---|
| 13036:GDAXI | 16% (84%) | 64% (36%) | 67% (33%) | 61% (14%) |
| 13213:USDJPY | **73%** (10%) | 58% (8%) | 49% (7%) | 9% (0%) |
| 13301:GDAXI | **82%** (14%) | 63% (6%) | 61% (2%) | 20% (1%) |
| 9936:USDJPY | **91%** (9%) | 64% (8%) | 67% (6%) | 11% (0%) |

For the three sleeves fast enough to resolve, P(pass) falls monotonically with
leverage. 13036 rises only because at 1x it is too slow to resolve inside the
data - 84% of its starts are censored, not breached.

**Consequence: wiring `QM_FrameworkSetRiskCapPct` to raise the cap above 1% would
lower the campaign's success probability, not raise it.** That reverses the
recommendation I gave on 2026-07-26 ("the entire 79.5% -> 4.7% gap is one
unwired constraint"). The gap is real but the sign was wrong: the 1% clamp in
`QM_Common.mqh:182` is close to the right setting for a barrier problem. Codex
independently reached "do not raise risk caps" from a governance argument; this
is the quantitative case for the same conclusion.

## Headline: the preregistered policy

Every sleeve at 1x with no overlay is not a fitted choice - it is what
`QM_Common.mqh:182` enforces and what the EAs contain. Nothing in this block is
selected on any period.

Per sleeve, OOS:

| sleeve | Q08 | OOS | breach | censored | median d | p90 d |
|---|---|---:|---:|---:|---:|---:|
| 9936:USDJPY | FAIL_SOFT | 75.3% | 16.0% | 8.7% | 63 | 175 |
| 13301:GDAXI | PASS | 72.5% | 13.1% | 14.4% | 108 | 351 |
| 13213:USDJPY | FAIL_SOFT | 67.8% | 22.7% | 9.5% | 87 | 213 |
| 13036:GDAXI | PASS | 15.8% | 0.0% | 84.2% | 476 | 550 |

Campaign, all combinations measured, none picked in-sample:

| N | OOS | breach | censored | median d | p90 d | ESS | +-95% | accounts |
|---:|---:|---:|---:|---:|---:|---:|---:|---|
| 3 | **88.3%** | **0.0%** | 11.7% | 62 | 375 | 12 | 18% | 13036, 13301, 9936 |
| 4 | 88.3% | 0.0% | 11.7% | 57 | 375 | 13 | 17% | 13036, 13213, 13301, 9936 |
| 2 | 85.2% | 6.1% | 8.7% | 60 | 194 | 13 | 19% | 13301, 9936 |
| 1 | 75.3% | 16.0% | 8.7% | 63 | 175 | 12 | 24% | 9936 |

Selection period 2017-10-09..2022-11-23; scoring 2022-11-23..2025-12-30.

## What this does and does not establish

**Establishes.** At the sizing the framework actually enforces, the failure mode
of a three-account book is *time*, not *ruin*: breach 0.0%, censoring 11.7%. The
book does not blow up; roughly one start in nine had not yet resolved when the
data ended. Median time to pass is 62 trading days, about three months.

**Does not establish.**

- **The 0.80 bar is met by the point estimate, not by the interval.** ESS is
  about 12 (overlapping starts divided by median resolution time), giving a Wald
  half-width near 18pp and a lower bound near 70%. No combination clears 0.80 on
  its lower bound.
- **Admission is unchanged.** All these sleeves carry a latest Q09
  `FAIL_PORTFOLIO`. Nothing here admits them; that is a pipeline decision.
- **The tail is long.** p90 is 375 trading days for the best book - about 18
  months. Median 62 days is the typical case, not the planning case.
- **Only four sleeves qualify** after the entry_time and multi-day preconditions,
  and two of the four are GDAXI.
- **Inactivity risk is unquantified.** Trading-day gaps measured from the
  streams: 13213 max 26d, 9936 max 27d, 13301 max 36d (one gap >30d), **13036 max
  279d with three gaps >30d**. Whether FTMO breaches a dormant account, and at
  what threshold, is **not** established by any source in this repo - task
  `9b7c6aaf`'s official-source artifact contains no inactivity clause. This must
  be verified against ftmo.com before 13036 is relied on, and 13036 is the sleeve
  supplying the 0.0% breach property.
- **9936's Q08 changed during this session**, from no completed verdict to
  `FAIL_SOFT`. The qualifying set is not stable.

## Relationship to the campaign-close recommendation

Codex recommends closing the campaign
(`docs/ops/evidence/2026-07-27_codex_ftmo_next_step_recommendation.md`), resting
on the 4.7% executable figure. That figure is a correct measurement of
P(+10% in 22 trading days) at 1x. It is not a measurement of the FTMO Phase 1
rule, which has no deadline. The parts of the Codex case untouched by this
document - Q09 inadmissibility, sleeve-supply scarcity, and "do not raise risk
caps" - stand.
