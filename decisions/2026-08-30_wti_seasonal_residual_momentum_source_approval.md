# WTI Monthly Seasonal-Residual Momentum - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced `XTIUSD.DWX` Q02 enqueue while the active factory remains below its
hard CPU ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly names structural WTI trend/seasonality as a
candidate, requires reputable-source criteria and `RISK_FIXED` backtests, and
forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-seas-resid-mom`
- proposed strategy ID:
  `KELOHARJU-MOP-WTI-SEASRESMOM-2026_S01`
- proposed source ID: `KELOHARJU-MOP-WTI-SEASRESMOM-2026`
- host / traded slot 0: exact `XTIUSD.DWX`, D1
- clock: first executable D1 tick of each genuine broker month
- state: the just-completed WTI monthly log return minus the mean return for
  that same calendar month in up to ten earlier years, standardized by the
  historical sample standard deviation
- lifecycle: follow only a strict standardized seasonal residual and hold the
  one-leg WTI package until the next genuine broker-month boundary

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The extraction must use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, covering
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
   Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, including
   the complete 57-page NBER working-paper review and explicit crude-oil
   membership.
2. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, covering Moskowitz, Ooi,
   and Pedersen (2012), "Time Series Momentum," *Journal of Financial
   Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, including
   the complete 23-page published-paper review, explicit WTI membership, and
   the source-declared one-month formation / one-month hold commodity test.
3. `strategy-seeds/sources/KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026/source.md`
   only as a previously governed arithmetic and lifecycle precedent for
   excluding the realized observation from a same-calendar sample. Its XNG
   carrier, contrarian direction, source evidence, and results do not transfer.

Keloharju et al. supply the recurring same-calendar commodity expectation and
explicit crude-oil universe membership. Moskowitz et al. supply own-return
continuation, explicit WTI membership, and a one-month formation / one-month
hold test at the pooled commodity level. Their conjunction supports one
falsifiable question: after subtracting its recurring calendar expectation,
does an unusually large completed WTI monthly residual continue over the
following month?

Neither source tests this exact standardized residual, a ten-year cap, a
half-standard-deviation band, the Darwinex continuous CFD, fixed-risk sizing,
ATR stop, spread ceiling, or the current portfolio. No source profit factor,
return, significance, drawdown, density, cost, CFD-equivalence, decorrelation,
or portfolio result transfers.

## Locked Mechanic

At the first executable `XTIUSD.DWX` D1 tick of broker month `M`:

1. Repair malformed owned exposure, close a surviving prior-month package,
   and persist month `M` before every fallible entry gate. Never retry `M`.
2. Under one uniform native or `+1` energy-D1 label convention, reconstruct
   the just-completed broker month `J=M-1` and its log return
   `realized_J=ln(close_end_J/close_end_(J-1))` from completed bars only.
3. Load the same calendar month `J` in up to exactly ten earlier years,
   excluding `realized_J`. Missing older years may be skipped without
   substitution; require at least five valid completed-month returns.
4. Compute the arithmetic mean and sample standard deviation with denominator
   `n-1`; require finite positive scale. Set
   `residual_z=(realized_J-seasonal_mean)/seasonal_sd`.
5. At `residual_z > +0.50 + 1e-10`, buy WTI. At
   `residual_z < -0.50 - 1e-10`, sell WTI. Otherwise consume `M` flat.
6. Apply one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` budget to the sole position, attach a frozen
   `3.5*ATR(20,D1)` hard stop, set no target, and admit nonnegative modeled
   `.DWX` spread only up to 1,500 points while rejecting crossed quotes.
7. Close at the first genuine later broker-month boundary, repair malformed
   state immediately, and enforce a 40-calendar-day stale guard.

Both news axes, legacy news mode, and framework Friday close are OFF. No
current-bar signal, historical-current-month forecast, raw-return fallback,
same-calendar-direction fallback, contrarian sign flip, Huber/median/MAD
estimator, result-dependent parameter, magnitude sizing, target, trail,
partial close, scale-in, grid, martingale, pyramid, trained output, banned
indicator, or external runtime feed is authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: two complete-read,
  peer-reviewed records directly cover same-calendar commodity returns and
  WTI own-return continuation; the exact residual conjunction is untested.
- R2 `PASS`: calendar mapping, endpoints, realized-sample exclusion, bounded
  historical sample, mean, `n-1` scale, band, side, attempt, fixed risk, stop,
  spread, renewal, and repair are locked before Q02.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XTIUSD.DWX` D1 history, broker calendar, quotes, metadata, positions,
  deals, and terminal-global attempt state supply every runtime input.
- R4 `PASS`: deterministic dates, completed OHLC, logarithms, sums, square
  roots, comparisons, and ATR risk plumbing only; no ML or prohibited signal
  component.

## Non-Duplicate Decision

The canonical checker examined 4,708 registry identities, 1,354 card files,
and 45 Strategy Wiki nodes. It returned `CLEAN` with no exact or fuzzy match:
`artifacts/qm5_wti_seas_resid_mom_preallocation_dedup_20260830.json`.

Manual family review fixes the executable boundary:

- `QM5_20187_wti-tsmom1m` follows the sign of every nonzero completed WTI
  monthly return. This card first removes a historical same-calendar
  expectation, scales the residual, and remains flat inside a strict band.
- `QM5_20099_wti-samecal` forecasts the upcoming calendar month from its
  historical same-month mean. This card observes the just-completed month and
  follows only its unexpected component during the next month.
- `QM5_20205_wti-calmom1` requires the upcoming-month seasonal sign and raw
  prior-month sign to agree. This card never uses the upcoming month's
  seasonal direction; it forms and follows the prior month's standardized
  realized-minus-expected residual.
- `QM5_20229_wti-seas-rev1` combines a fixed physical-season direction with
  an opposing raw prior-month sign. This card has no fixed winter/summer map
  and does not reverse the completed return.
- `QM5_41208_xng-seas-surprise-rv` uses analogous residual arithmetic on XNG
  but trades the opposite side. This card owns direct WTI exposure and tests
  residual continuation under WTI-specific peer-reviewed momentum lineage.
- `QM5_21517_xauxag-seas-rv` is a contrarian two-leg precious-metals basket;
  this card is a one-leg directional WTI trend/seasonality stream.

The WTI carrier, just-completed month, realized-sample exclusion,
same-calendar expectation, sample scaling, strict continuation band, and
next-month lifecycle are jointly load-bearing. Verdict:
`CLEAN_WTI_STANDARDIZED_SEASONAL_RESIDUAL_MOMENTUM_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero trades, below five completed
positions in any full post-warm-up year, nonpositive governed economics, or
any label, endpoint, sample-membership, leakage, mean, scale, score, side,
attempt, fixed-risk, stop, spread, lifecycle, or determinism defect. A failed
result may not be rescued by changing the sample, threshold, direction,
carrier, stop, hold, spread, or retry rule.

Structural WTI exposure does not prove low correlation with the certified
book. Unchanged downstream Q09 alone owns realized decorrelation. This
approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; terminal control; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers.
