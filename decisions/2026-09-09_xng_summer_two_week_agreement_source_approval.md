# XNG Summer Two-Week Agreement Momentum — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `xng-summer-w2agree`
- Strategy ID: `EIA-MOP-XNG-SUMMER-W2AGREE-2026_S01`
- Source packet:
  `strategy-seeds/sources/EIA-MOP-XNG-SUMMER-W2AGREE-2026/source.md`
- Dedup receipt:
  `artifacts/qm5_xng_summer_w2agree_preallocation_dedup_20260909.json`

## Authority And Source Quality

The current OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The child source
packet preserves two completely read governed parents: official U.S. Energy
Information Administration natural-gas seasonality context and Moskowitz,
Ooi, and Pedersen's peer-reviewed commodity time-series-momentum paper.

EIA supports only recurring summer electric-generation demand. MOP supports
own-return continuation at monthly horizons. The two-week agreement, exact
months, one-week hold, risk, stop, spread, and lifecycle are disclosed QM
mechanizations. No efficacy or diversification claim transfers.

## Locked Mechanic

1. Trade preset-bound `XNGUSD.DWX` on D1 only.
2. Decide once at the first tradable D1 bar of a normalized broker week whose
   Monday anchor lies in June, July, or August.
3. Reconstruct the two immediately completed adjacent three-to-five-session
   weeks and compute each `ln(final_close / first_open)`.
4. Continue only strict agreement: two positives buy, two negatives sell;
   mixed signs, equality, or invalid state remain flat.
5. Consume the attempt before fallible gates and close at the next normalized
   week; ten elapsed days is stale repair only.
6. Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, a frozen
   `3.5*ATR(20,D1)` stop, no target, and a 1,500-point spread ceiling.

No oscillator, moving average, volatility rank, magnitude threshold, external
runtime feed, learned component, target, trail, scale-in, pyramid, grid,
martingale, or retry is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_AND_HORIZON_TRANSLATION_RISK`: one governed child
  source preserves official-government and complete-read peer-reviewed
  lineages; the exact conjunction is untested.
- R2 `PASS`: calendar, two weekly packages, strict agreement, continuation
  side, attempt, fixed risk, stop, spread, and rollover are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XNGUSD.DWX` D1 history
  supplies all runtime market inputs.
- R4 `PASS`: native timestamp, OHLC, logarithm, ATR, quote, position, deal, and
  persistent-state arithmetic only; no ML, banned indicator, grid, or
  martingale.

## Duplicate Decision

The canonical checker scanned 4,876 registry rows, 1,488 cards, and 45
Strategy Wiki nodes. It raised the expected fuzzy seasonal-week neighbors
`QM5_41392` and `QM5_41395`, with no exact slug or strategy-ID collision.
Manual review separates the new summer two-week same-sign conjunction from
the shoulder one-week fade and winter unconditional one-week continuation.
The two adjacent packages, strict agreement, summer anchor, and lifecycle are
jointly load-bearing. `QM5_12567` instead uses cumulative RSI and a slow trend
filter.

Verdict:
`DISTINCT_XNG_SUMMER_TWO_ADJACENT_WEEK_AGREEMENT_MOMENTUM_AFTER_FAMILY_REVIEW`.

## Authorization Boundary

This approval permits one approved card and G0 decision, deterministic
identity/magic allocation, bounded V5 build, mandatory PACER input-pin audit
before compile enqueue, strict Q01, and one paced Q02 enqueue below the CPU
ceiling. It excludes manual backtests, optimization, portfolio admission,
correlation waivers, portfolio-gate edits, deployment, live manifests,
`T_Live`, AutoTrading, and live use.
