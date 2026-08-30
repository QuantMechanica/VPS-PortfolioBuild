---
source_id: KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026
title: WTI same-calendar chronological regime-shift seasonality
publisher: QuantMechanica governed composite of peer-reviewed evidence
source_type: governed_peer_reviewed_composite_translation_packet
status: approved_source_complete
approved_by: OWNER commodity/energy portfolio mission
approved_at: 2026-08-30
source_approval: decisions/2026-08-30_wti_same_calendar_regime_shift_source_approval.md
parent_sources:
  - strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md
  - strategy-seeds/sources/MOP-TSMOM-2012/source.md
strategy_ids: [KELOHARJU-MOP-WTI-SAMECAL-REGIMESHIFT-2026_S01]
---

# WTI Same-Calendar Regime-Shift Source Packet

## Bounded source basis

The durable source decision
`decisions/2026-08-30_wti_same_calendar_regime_shift_source_approval.md`
was committed as `2a0ace4ac` before extraction. Both governed packets named
by that decision were then read completely. Hash, byte, line, and repository
commit evidence is bound in
`artifacts/qm5_wti_samecal_regimeshift_source_provenance_20260830.json`.

Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, supply the
same-calendar-month commodity-return information object, explicit crude-oil
membership, monthly renewal, and a minimum five-year history condition. Their
commodity test ranks a diversified futures cross-section. It does not report
this single-WTI chronological block rule.

Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`, supply explicit WTI membership, own-return
directional interpretation, and monthly renewal. They do not use a
same-calendar sample, split earlier observations into chronological blocks,
or condition on a seasonal sign reversal.

No source tests this exact conjunction, a five/five split, a Darwinex
continuous CFD, fixed-risk sizing, ATR stops, spread ceilings, or the current
portfolio. No source or sibling return, alpha, significance, density, profit
factor, transaction cost, drawdown, futures/CFD equivalence, decorrelation,
or portfolio result transfers. The chronological disagreement trigger is a
locked QM falsification choice, not a fitted or source-claimed optimum.

## Approved mechanical translation

On the first executable `XTIUSD.DWX` D1 tick after a genuine normalized
broker-calendar month transition in `(Y,M)`:

1. Repair owned exposure, then persist current broker `yyyymm` before every
   fallible entry gate. A flat, blocked, rejected, failed, stopped, or
   restarted month never retries.
2. Under one uniform native or `+1` energy D1-label convention, reconstruct
   completed WTI log returns for calendar month `M` in every exact year
   `Y-1..Y-10`. Require strict adjacent-month endpoints and a confirming
   following bar. All ten observations are mandatory, without replacement or
   age compression. The current decision month contributes no price.
3. Compute the equal arithmetic mean of recent block `Y-1..Y-5` and the equal
   arithmetic mean of older block `Y-6..Y-10`. Require both finite and outside
   the inclusive `1e-12` tie band.
4. When the two means have strict opposite signs, enter in the recent block's
   direction: positive recent/negative older buys WTI; negative recent/
   positive older sells WTI. Equal signs, either tie, or invalid state
   consumes the month flat. Magnitude never changes risk.
5. Use one `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1` budget,
   one frozen `3.5*ATR(20,D1)` hard stop, no target, a nonnegative 1,500-point
   spread cap, next-month renewal, and a forty-calendar-day stale repair.

Both news axes, legacy news mode, and framework Friday close are disabled.
Runtime uses native completed WTI D1 time/close, ATR, quote, point metadata,
positions, deals, broker calendar, and framework state only. It may not use a
futures curve, contract chain, inventory, storage, volume, open interest,
COT, weather, event release, external file or API, trained output, optimizer
artifact, another EA's state, or a banned signal indicator.

## Source-defined rules versus QM interpretations

Source-defined support is limited to recurring same-calendar commodity-return
information, explicit crude-oil/WTI membership, an own-return directional
interpretation, monthly renewal, and a five-year information floor.

The following are QM interpretations fixed before Q02: single-WTI absolute
direction; exactly ten years; exact recent and older five-year blocks; all ten
years mandatory; logarithmic continuous-CFD returns; strict block-sign
disagreement; following the recent block; the epsilon; entry grace; fixed
risk; ATR stop; spread cap; attempt ledger; next-month close; and stale repair.
No efficacy claim attaches to those choices.

## Non-duplicate boundary

The corrected-root receipt
`artifacts/qm5_wti_samecal_regimeshift_preallocation_dedup_20260830.json`
scanned the registry, repository card set, and Strategy Wiki before allocation.
It found no exact collision and surfaced the expected raw WTI same-calendar
neighbor for manual resolution.

- `QM5_20099_wti-samecal` follows the arithmetic mean across one combined
  historical sample. This rule requires a chronological sign reversal and
  follows the recent five-year block.
- `QM5_41055_wti-medcal`, `QM5_41199_wti-samecal-trim5`,
  `QM5_41201_wti-samecal-hl5`, `QM5_41202_wti-samecal-win5`, and
  `QM5_41204_wti-samecal-huber10` replace or robustify one location estimate.
  None compares fixed recent and older chronological blocks.
- `QM5_41211_wti-samecal-tstat` studentizes one magnitude mean, while
  `QM5_41212_wti-samecal-signscore` uses one Bernoulli count. Neither has a
  two-block reversal state or recent-block direction.
- `QM5_41223_wti-samecal-expw4` continuously decays year-age influence and
  always follows its weighted sign outside equality. This rule has no decay
  kernel and is flat when seasonal direction is stable across blocks.
- `QM5_41172_wti-mpettitt-shift-tr` detects a daily location break within the
  just-completed month. It neither forecasts the upcoming named month from
  exact prior-year occurrences nor uses a recent-versus-older seasonal split.

For recent-to-old returns
`[+.01,+.01,+.01,+.01,+.01,-.03,-.03,-.03,-.03,-.03]`, the full equal mean
is negative and the raw rule sells. This rule observes a positive recent mean
against a negative older mean and buys. If all ten returns share a sign, raw,
robust, or decay siblings may trade while this rule must remain flat. The
chronological split, opposite-sign requirement, and recent-block side are
therefore executable and load bearing.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_WTI_SAMECAL_CHRONOLOGICAL_REGIME_SHIFT`.

## Reputable-source criteria

- R1 `PASS_WITH_TWO_BLOCK_SINGLE_CARRIER_CFD_TRANSLATION_RISK`: two complete,
  DOI-bearing peer-reviewed sources cover the bounded information family and
  WTI membership; the exact chronological disagreement conjunction is not a
  source result.
- R2 `PASS`: clock, endpoint identity, two exact block sizes, arithmetic,
  strict sign reversal, recent-block direction, consumed attempt, fixed risk,
  stop, spread, and exit are deterministic and locked.
- R3 `PASS_WITH_TEN_YEAR_WARMUP_AND_CONTINUOUS_FUTURES_CFD_BASIS_RISK`:
  registered native WTI D1 is sufficient; history depth, label convention,
  rolls, financing, gaps, and CFD basis remain falsification risks.
- R4 `PASS`: closed-form native calendar and return arithmetic only; no ML,
  banned signal indicator, external runtime data, grid, martingale, scale-in,
  or pyramiding.

## Falsification and safety boundary

Expected frequency is `UNKNOWN_Q02_MEASURES`; the calendar offers at most
twelve decisions per full post-warm-up year, and the disagreement gate may
produce fewer than five positions. Q02 retires the unchanged candidate on
zero positions, any full post-warm-up year below five completed positions,
nonpositive governed economics, or a rule-conformance defect. Missing years,
ties, equal block signs, invalid history, and rejected execution consume the
month; they do not authorize a fallback.

The WTI carrier and chronological regime-shift state are structurally outside
the certified XAU/SP500/NDX/XNG book, but only Q09 may judge realized overlap.
This packet authorizes no manual tester action, live/demo/shadow/stress/
optimization preset, terminal control, AutoTrading change, `T_Live`, deploy
or live manifest, portfolio-gate mutation, portfolio admission, correlation
waiver, or certification claim.
