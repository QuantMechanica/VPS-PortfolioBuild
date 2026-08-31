# WTI Monthly Centered-CUSUM Shift Trend — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded WTI structural-trend Strategy
Card, deterministic EA-ID and one-slot magic allocation, one branch-only
non-live build, strict Q01 validation, and one paced Q02 enqueue only while
the governed whole-host CPU ceiling remains clear. This decision does not
authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve outside the certified
XAU/SP500/NDX/XNG carrier set, reputable-source criteria, a `RISK_FIXED`
backtest preset, committed non-duplicate work, and one paced Q02 handoff. It
forbids live, AutoTrading, portfolio-gate, and `T_Live` manifest mutations.

## Candidate Identity

- proposed slug: `wti-mcusum-shift-tr`
- proposed strategy ID: `AI-CODEX-WTI-MCUSUM-20260831_S01`
- source ID: `AI-CODEX-WTI-MCUSUM-20260831`
- host / slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick after a genuine broker-month transition
- signal: one unique central maximum of the mean-centered cumulative-sum path
  over twelve completed monthly WTI log returns; follow the post-split mean
  return sign
- lifecycle: one consumed monthly attempt, one fixed-risk position, frozen
  ATR stop, next-month renewal, and forty-calendar-day stale repair

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Single Governed Source And Supporting Evidence

The single R1 lineage is the AI-originated governed packet
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/source.md`. The canonical
R1 rule in `processes/qb_reputable_source_criteria.md` expressly permits an
AI-originated strategy when its prompt/output trail, claim boundary, and one
source ID are durable.

The packet was synthesized only after reading the complete governed WTI
source `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
That packet records a complete 23-page read of Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, *Journal of Financial Economics* 104(2),
228-250, DOI `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI
membership and monthly own-return continuation findings.

The method boundary was verified against two primary records on 2026-08-31:

- E. S. Page (1954), "Continuous Inspection Schemes," *Biometrika* 41(1/2),
  100-115, DOI `10.1093/biomet/41.1-2.100`. Oxford Academic exposed complete
  bibliographic metadata but not the article body; no inaccessible formula or
  claim is attributed to the paper.
- NIST/SEMATECH Engineering Statistics Handbook, "CUSUM Control Charts,"
  `https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc323.htm`. The
  complete public page defines cumulative sums around an estimated mean and
  explains that sustained mean shifts drive the path away from zero.

The reproducible access record is
`strategy-seeds/sources/AI-CODEX-WTI-MCUSUM-20260831/retrieval_route_20260831.json`.
The Page and NIST records are supporting method evidence; they do not become
additional card source IDs.

## Locked Mechanic

At the first executable D1 tick of each genuine broker month:

1. Persist the normalized broker-month key before history, signal, news,
   spread, quote, stop, sizing, margin, or order checks. Never retry the same
   month.
2. Reconstruct thirteen consecutive completed WTI broker-month end closes,
   oldest to newest, and form twelve adjacent log returns `r[0..11]`.
3. Require finite positive endpoints, strict month continuity, finite returns,
   and a nonzero return path. Define `mean = sum(r)/12`.
4. For split counts `k=1..11`, compute
   `S[k] = sum(r[0..k-1]) - k*mean`. Exclude the identically zero terminal
   sum at `k=12`.
5. Find the maximum absolute `|S[k]|`. Qualify only when exactly one split is
   within `1e-12` of that maximum and `4 <= k <= 8`, leaving at least four
   returns in both segments.
6. Compute the arithmetic mean of the post-split returns `r[k..11]`. Buy when
   it is greater than `1e-12`; sell when it is less than `-1e-12`; otherwise
   consume the month flat. CUSUM magnitude never scales risk.
7. Open at most one exact-WTI slot-0 position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
   `3.5 * ATR(20,D1)` broker hard stop, no target, and a 1,500-point spread
   ceiling.
8. Close at the next genuine broker month or after forty calendar days.
   Both news axes and Friday close remain off so the one-month hold is not
   rewritten into weekly packages.

This is a retrospective, fixed-window centered-CUSUM trading translation,
not Page's sequential control-chart procedure and not a significance test.
The window, central split band, unique-maximum rule, post-segment direction,
carrier, risk, stop, and lifecycle are pre-result QM choices.

## Reputable-Source Criteria

- R1 `PASS_WITH_AI_SYNTHESIS_AND_METHOD_ACCESS_BOUNDARY`: exactly one durable
  AI-originated source ID, a complete-read peer-reviewed WTI trading packet,
  a named peer-reviewed method record, and a complete official NIST method
  page are preserved. No inaccessible Page content or source efficacy is
  imported.
- R2 `PASS`: month clock, endpoints, return orientation, centering, every
  cumulative sum, uniqueness tolerance, central split, post-segment side,
  attempt, risk, hard stop, spread, and exits are deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1 history and MT5 execution state supply every runtime input.
  Futures-to-CFD, roll, financing, gap, and broker-month-label risks remain.
- R4 `PASS`: timestamps, completed prices, logarithms, finite sums, means,
  comparisons, ATR risk control, and native position/deal state only; no ML,
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The corrected-root canonical receipt
`artifacts/qm5_wti_mcusum_shift_tr_preallocation_dedup_20260831.json`,
SHA-256 `F397FDCF63414FF4CFE1C64AA9D1EEE9DE368643F30B3451F2785F06B61C45D2`,
scanned 4,744 registry identities, 1,382 card files, and 45 Strategy Wiki
nodes. It returned `CLEAN` with no exact or fuzzy match.

Manual mechanic review fixes the semantic boundary:

- `QM5_41172_wti-mpettitt-shift-tr` ranks thirteen price levels and takes the
  sign of a cumulative rank sum. This candidate centers twelve adjacent log
  returns in native magnitude units and takes the sign of the post-split
  return mean.
- `QM5_41183_wti-mks-shift-tr` fixes a six/six split and keeps only a signed
  maximum ECDF count gap among price levels. This candidate searches all
  eleven return splits, retains the unique maximum centered excursion, and
  applies an explicit central-band rule.
- `QM5_41176_wti-mwilcoxon-shift-tr` sums every old/new price-level pair win
  at a fixed split. This candidate neither ranks nor counts pair wins.
- `QM5_20261_wti-lr-trend` fits one OLS line to log price and gates on
  `R^2`; this candidate fits no line and estimates a return-mean transition.
- `QM5_41224_wti-samecal-regimeshift` compares exact same-calendar returns
  from ten years. This candidate uses one contiguous twelve-month path and no
  calendar-month recurrence.
- certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback above a slow trend. This candidate is symmetric,
  monthly, direct WTI, and contains no oscillator or XNG exposure.

Verdict:
`CLEAN_WTI_MONTHLY_CENTERED_RETURN_CUSUM_UNIQUE_CENTRAL_SHIFT_POST_MEAN_CONTINUATION`.

## Kill And Safety Boundary

The central-band design admits at most twelve entries/year and is expected to
produce roughly five to nine completed positions/year before execution gates;
that is a design prior, not test evidence. Q02 retires the unchanged baseline
on zero positions, fewer than five positions in any full scored year,
nonpositive governed economics, future leakage, wrong centering, omitted
split, tied-maximum entry, edge-split entry, wrong side, missing stop, invalid
risk mode, malformed lifecycle, or nondeterminism. Failure may not be rescued
by changing the window, split band, tolerance, side, stop, or hold.

WTI supplies physical crude-oil exposure absent from the certified book, but
this approval does not assert realized independence. Q09 alone may evaluate
portfolio overlap.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers.
