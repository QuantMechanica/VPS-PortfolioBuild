# XNG Seasonal-Residual Momentum — Source Approval

- Date: 2026-09-09
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency XNG card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `xng-seas-resid-mom`
- Strategy ID: `KELOHARJU-MOP-XNG-SEASRESMOM-2026_S01`
- Planned source packet:
  `strategy-seeds/sources/KELOHARJU-MOP-XNG-SEASRESMOM-2026/source.md`
- Dedup receipt:
  `artifacts/qm5_xng_seas_resid_mom_preallocation_dedup_20260909.json`

## Authority And Complete-Read Basis

The current OWNER pacer instruction authorizes one reputable-source,
structural, low-frequency commodity/energy card and build and explicitly
permits a second `XNGUSD` edge when its logic differs from `QM5_12567`.

Before this approval, the following durable governed packets were read end to
end:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, which records a
   complete review of Keloharju, Linnainmaa, and Nyberg (2016), *Return
   Seasonalities*, *Journal of Finance* 71(4), 1557-1590, DOI
   `10.1111/jofi.12398`. Natural gas is explicit in the commodity panel.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, which records a complete
   review and durable hash of Moskowitz, Ooi, and Pedersen (2012), *Time
   Series Momentum*, *Journal of Financial Economics* 104(2), 228-250, DOI
   `10.1016/j.jfineco.2011.11.003`. Natural gas is explicit in the commodity
   universe and one-month formation/holding is tested at the pooled commodity
   level.
3. `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`,
   used only as a governed XNG arithmetic, endpoint, and realized-sample-
   exclusion precedent. Its contrarian evidence and pipeline outcomes do not
   transfer.

## Locked Mechanic

At the first tradable `XNGUSD.DWX` D1 bar of each broker month, reconstruct
the just-completed monthly log return. Estimate that same calendar month's
mean and sample standard deviation from up to ten earlier exact years,
excluding the realized observation and requiring at least five samples.
Standardize the realized-minus-seasonal residual. Buy above strict
`+0.50 + 1e-10`, sell below strict `-0.50 - 1e-10`, and consume the month flat
inside the band or on invalid state. Hold until the next broker month with a
40-day stale repair, frozen `3.5*ATR(20,D1)` hard stop, no target, a 3,000-point
XNG spread ceiling, `RISK_FIXED=1000`, and `RISK_PERCENT=0`.

No current-month price, oscillator, moving average, inventory, weather,
futures curve, external runtime feed, learned component, optimizer output,
target, trail, scale-in, pyramid, grid, martingale, or retry is permitted.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: two peer-reviewed
  primary lineages with complete-read records and explicit natural-gas
  membership support same-calendar structure and own-return continuation;
  their exact standardized conjunction and the single continuous-CFD port are
  explicitly untested.
- R2 `PASS`: clock, label convention, endpoints, exclusion, sample, arithmetic
  mean, n-1 scale, strict band, continuation side, attempt, risk, stop, spread,
  renewal, and repair are deterministic.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XNGUSD.DWX` D1 history and MT5 state supply every runtime input.
- R4 `PASS`: native calendar, price, logarithm, arithmetic, square-root, ATR,
  quote, position, deal, and persistent-state operations only; no banned
  indicator, ML, external data, grid, martingale, or pyramid.

## Duplicate Decision

The canonical checker found no exact registry or card collision and surfaced
the two expected fuzzy siblings. The Strategy Wiki root was unavailable and
is recorded as `MISSING_ROOT`; this approval therefore makes no claim about
an unread external node.

- `QM5_41209_wti-seas-resid-mom` uses the same estimator and continuation
  orientation on WTI. The exact XNG carrier is load-bearing and no WTI result
  transfers.
- `QM5_41208_xng-seas-surprise-rv` uses the same XNG standardized residual but
  trades the opposite, contrarian side under different natural-gas evidence.
  Continuation direction and Moskowitz-Ooi-Pedersen lineage are load-bearing.
- `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative-RSI(2)
  pullback aligned to a slow moving-average trend and held for at most five
  bars. This candidate is symmetric, monthly, seasonally adjusted, and has no
  oscillator or trend average.
- `QM5_20204_xng-tsmom1m` follows every nonzero completed-month return. This
  candidate removes a same-calendar expectation, scales the residual, and
  remains flat inside a strict band.
- `QM5_20100_xng-samecal`, `QM5_41205_xng-samecal-huber10`, and
  `QM5_41225_xng-medcal` forecast the upcoming month's seasonal sign and do not
  observe a standardized just-completed residual.

Verdict:
`DISTINCT_XNG_STANDARDIZED_SEASONAL_RESIDUAL_MOMENTUM_AFTER_MANUAL_REVIEW`.

## Authorization Boundary

This approval permits one bounded source packet and approved card,
deterministic identity/magic allocation, V5 branch build, mandatory PACER
input-pin audit before compile enqueue, strict Q01, and one paced Q02 enqueue
below the hard CPU ceiling. It excludes manual backtests, optimization,
portfolio admission, correlation waivers, portfolio-gate edits, deployment,
live manifests, `T_Live`, AutoTrading, terminal control, or live use.
