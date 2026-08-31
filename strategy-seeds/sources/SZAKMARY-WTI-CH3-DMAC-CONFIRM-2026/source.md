---
source_id: SZAKMARY-WTI-CH3-DMAC-CONFIRM-2026
title: WTI monthly three-close channel with one-over-six neutral-band confirmation
publisher: QuantMechanica governed composite of one peer-reviewed commodity-trend source lineage
source_type: peer_reviewed_trading_paper_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md
parent_source_ids:
  - SZAKMARY-WTI-MCH3-2010
  - SZAKMARY-WTI-DMAC16-2010
parent_sha256:
  SZAKMARY-WTI-MCH3-2010: 9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727
  SZAKMARY-WTI-DMAC16-2010: 3F27E3A48EBA504DA98FAD487B8F0DA3135E40D4BC15B19C6156A286E987BCC6
created: 2026-08-31
created_by: Research
cards_extracted:
  - wti-ch3-dmac-confirm
---

# WTI Monthly CH3 / DMAC Confirmation Source Packet

## Approval And Complete-Read Boundary

The durable source decision is
`decisions/2026-08-31_wti_ch3_dmac_confirmation_source_approval.md`. It
authorizes one card, deterministic allocation, one branch-only non-live V5
build, strict Q01 validation, and one paced Q02 enqueue below the governed CPU
ceiling. It does not authorize a manual backtest or live action.

The following repository records were read completely under that decision:

1. `strategy-seeds/sources/SZAKMARY-WTI-MCH3-2010/source.md`, 110 lines,
   SHA-256
   `9E082864F7F6C85E88720FC7DC24674A8BE77C68C3479D441C7709B726691727`.
2. `strategy-seeds/sources/SZAKMARY-WTI-DMAC16-2010/source.md`, 81 lines,
   SHA-256
   `3F27E3A48EBA504DA98FAD487B8F0DA3135E40D4BC15B19C6156A286E987BCC6`.

Both records preserve one source lineage: Szakmary, Andrew C.; Shen, Qian;
and Sharma, Subhash C. (2010), "Trend-following trading strategies in
commodity futures: A re-examination," *Journal of Banking & Finance* 34(2),
409-426, DOI `10.1016/j.jbankfin.2009.08.004`. The channel record documents
the complete read of the authors' accessible predecessor manuscript, "Price
Momentum and Trading Volume in Commodity Futures Markets," which gives the
mechanical monthly rules.

## Trading-Source Findings Used

Szakmary, Shen, and Sharma study 28 commodity futures over 48 years with
monthly unit-value series. Their channel family compares the latest month-end
value with the maximum and minimum of the prior `L` month ends, enters only
outside the channel, stays flat inside it, and holds the resulting position
for one month. The source tests `L={3,6,9,12}`. This packet uses the
source-tested `L=3` member.

The same study's dual-moving-average family compares a short monthly value
with a longer monthly average and uses a neutral band. The governed WTI DMAC
record fixes the source member whose short value is the latest month end,
whose long value is the arithmetic mean of six completed month ends, and
whose symmetric band is 2.5%.

The study includes crude-oil futures and supports testing monthly trend rules
on a WTI carrier. It reports pooled commodity evidence, not a guaranteed
single-WTI result. It does not test an AND confirmation between the channel
and DMAC states. It also does not test a continuous Darwinex CFD, D1 endpoint
reconstruction, fixed-dollar risk, an ATR hard stop, a spread cap, restart
state, or the current portfolio.

No source performance number, trade density, WTI-only alpha, Sharpe ratio,
drawdown, transaction-cost result, futures/CFD equivalence, correlation, or
portfolio conclusion is imported into the card.

## Bounded QM Mechanization

At the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct six consecutive completed month-end closes, newest
first. Compute the source-tested prior-three channel state and the
source-tested one-over-six 2.5% DMAC state from the same completed endpoints.
Trade for one broker month only if both states point in the same direction.
Disagreement or either flat state consumes the month without entry.

The conjunction is a transparent QM falsification hypothesis. It is intended
to remove two parent-specific states: channel breakouts that are not far
enough from the six-month mean, and neutral-band trend states that have not
broken the last three month ends. This narrower decision set is not attributed
to the authors.

## Exact Calendar And Endpoint Contract

- Host and traded carrier: exact `XTIUSD.DWX`, D1, symbol slot zero.
- Decision time: first processed D1 bar whose broker-calendar `(year,month)`
  differs from the immediately preceding completed D1 bar.
- Required endpoint sample: exactly six consecutive completed broker-month
  closes, newest first, `C0..C5`.
- `C0` is the final completed D1 close of the month immediately before the
  current broker month. `C1..C5` are the five immediately preceding month-end
  closes without gaps or substitutions.
- Require a current-month D1 bar confirming that `C0` is complete, distinct
  consecutive month keys, strictly ordered timestamps, and positive finite
  close values.
- Read a bounded D1 buffer. Do not depend on materialized MN1 bars, current
  partial-month prices, external files, APIs, futures curves, inventory,
  volume, open interest, news forecasts, or portfolio state.
- Missing, repeated, nonconsecutive, nonpositive, or nonfinite endpoints
  consume the month flat. No shorter sample or available-history compression
  is allowed.

## Exact Signal Contract

For finite `C0..C5`, newest to oldest:

```text
channel_high = max(C1,C2,C3)
channel_low  = min(C1,C2,C3)

channel_state = +1 when C0 > channel_high
                -1 when C0 < channel_low
                 0 otherwise

mean6 = (C0+C1+C2+C3+C4+C5) / 6
upper = mean6 * 1.025
lower = mean6 * 0.975

dmac_state = +1 when C0 > upper
             -1 when C0 < lower
              0 otherwise

signal = +1 only when channel_state=+1 and dmac_state=+1
         -1 only when channel_state=-1 and dmac_state=-1
          0 otherwise
```

Every comparison is strict. Equality to a channel boundary or neutral-band
boundary is flat. Reject a nonpositive or nonfinite sum, mean, boundary, or
intermediate value. Signal magnitude is never used for sizing.

Do not change the channel horizon, long-average horizon, band, arithmetic
mean, comparison strictness, or AND relation. Do not substitute an OR, vote,
weighted score, return sign, moving daily channel, seasonal calendar, or
intramonth filter.

## Decision Fixtures

These fixed synthetic close sequences prove the candidate is not either
existing parent:

| `C0..C5` newest to oldest | CH3 state | DMAC state | candidate |
|---|---:|---:|---:|
| `[103,100,99,98,120,120]` | +1 | -1 | 0 |
| `[110,111,109,108,80,80]` | 0 | +1 | 0 |
| `[120,110,105,100,95,90]` | +1 | +1 | +1 |
| `[80,90,95,100,105,110]` | -1 | -1 | -1 |

Sign-reflected fixtures reverse every nonzero state. The first fixture is
traded by the built CH3 parent in the opposite direction from the built DMAC
parent; the conjunction stays flat. The second is traded by the DMAC parent
but not by CH3 or this candidate.

## Execution And Risk Contract

- At month transition, repair malformed owned state and close any old package
  before entry-only gates or signal renewal.
- Persist the current broker `yyyymm` attempt before history, signal, news,
  spread, quote, ATR, sizing, or submission. Never retry in that month after
  any failure or stop-out.
- Enter BUY only on signal `+1`; enter SELL only on signal `-1`; flat
  otherwise.
- Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1` for the
  sole non-live backtest setfile.
- Attach one frozen `4.0 * ATR(20,D1)` broker hard stop and no take-profit.
- Reject negative/crossed spreads and positive spreads above 1,500 points.
  A modeled zero spread remains valid.
- Close at the first later broker-month transition even when the signal would
  repeat. A 40-calendar-day guard repairs only a survivor.
- Close duplicate, wrong-symbol, invalid-side, wrong-magic, or stopless owned
  exposure immediately.
- Lock current news temporal/compliance axes and legacy news mode OFF. Disable
  Friday flattening because the source-aligned package spans weekends.
- Never scale in, pyramid, grid, martingale, partially close, trail, move to
  break even, optimize, retry, or carry the old package through renewal.

## Non-Duplicate Boundary

The corrected-root canonical receipt
`artifacts/qm5_wti_ch3_dmac_confirm_preallocation_dedup_20260831.json`,
SHA-256
`B61748E06968490A41476ED976043288A5C49046244B04EBFF0394B44364DF40`,
found no exact or above-threshold fuzzy identity across 4,740 registry rows,
1,378 cards, and 45 Strategy Wiki nodes.

- `QM5_20008_wti-month-ch3` uses only the prior-three channel and renews every
  nonflat channel package. It trades the first fixture.
- `QM5_13100_wti-dmac16` uses only the six-close mean/band state and can carry
  unchanged exposure across month boundaries. It trades the first two
  fixtures.
- Daily Donchian, monthly opening-range, 52-week anchor, raw return-sign,
  calendar-seasonal, event, inventory, oil/gas, oil/metal, and RSI systems do
  not use this exact two-state monthly agreement.

Removing either parent state or changing AND to OR recreates a materially
different decision surface. Verdict:
`SEMANTICALLY_DISTINCT_WTI_MONTHLY_CH3_BREAKOUT_AND_DMAC16_NEUTRAL_BAND_CONFIRMATION_SLEEVE`.

## Reputable-Source Criteria

- R1: `PASS_WITH_UNTESTED_CONJUNCTION_AND_SINGLE_CFD_TRANSLATION_RISK`. A
  named-author peer-reviewed Journal of Banking & Finance paper with DOI and a
  durable complete-manuscript review supplies both source-tested parent rule
  families and explicit crude-oil membership. The conjunction is a disclosed
  QM hypothesis.
- R2: `PASS`. Exact completed endpoints, strict channel, arithmetic mean,
  exact band, AND agreement, consumed attempt, hard stop, spread, and monthly
  renewal are deterministic and locked.
- R3: `PASS_WITH_CONTINUOUS_FUTURES_CFD_BASIS_RISK`. Registered
  `XTIUSD.DWX` D1 history and native MT5 state provide every runtime input.
  Futures rolls, financing, labels, gaps, and CFD basis remain falsification
  risks.
- R4: `PASS`. Native timestamps, closes, extrema, fixed arithmetic,
  comparisons, ATR risk control, quotes, positions, deals, and framework
  state only; no trained model, banned signal indicator, grid, martingale,
  scale-in, pyramid, or external runtime feed.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed packages per full
year based only on the parent CH3's local 8.21/year precheck and the fact that
the conjunction is a strict subset. Q02 owns the actual frequency and retires
the unchanged candidate below five in any full scored year. It also retires on
zero positions, wrong endpoints, current-month leakage, incorrect state,
repeat entry, missing stop, wrong renewal, nondeterminism, invalid risk mode,
or nonpositive governed economics. No failed baseline may be rescued by
relaxing the conjunction.

The WTI carrier targets a structural energy sleeve outside the certified
XAU/SP500/NDX/XNG set. That is an exposure hypothesis, not evidence of low
correlation. Only unchanged Q09 may measure realized overlap.

This packet authorizes no manual test, live/demo/shadow/stress/optimization
setfile, terminal control, AutoTrading action, `T_Live`, deployment artifact,
portfolio gate change, portfolio admission, decorrelation claim, or waiver.
