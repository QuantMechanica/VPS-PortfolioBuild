# XNG Monthly Seasonal-Surprise Reversion - Source Approval

Date: 2026-08-30

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced `XNGUSD.DWX` Q02 enqueue while the active factory remains below its
hard CPU ceiling. Enqueue does not authorize a manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. It requests one genuinely new structural,
low-frequency commodity or energy sleeve outside the certified directional
XAU/SP500/NDX/XNG book, explicitly permits a second XNG edge only when its
logic differs from `QM5_12567`, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xng-seas-surprise-rv`
- proposed strategy ID:
  `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026_S01`
- proposed source ID: `KELOHARJU-MISHRA-XNG-SEASSURPRISE-2026`
- host / traded slot 0: exact `XNGUSD.DWX`, D1
- clock: first executable D1 tick of each genuine broker month
- state: the just-completed XNG monthly log return minus the mean return for
  that same calendar month in up to ten earlier years, standardized by the
  historical sample standard deviation
- lifecycle: fade only a strict standardized seasonal surprise and hold the
  one-leg XNG package until the next genuine broker-month boundary

The atomic governed allocator owns the EA ID. This source decision neither
predicts nor reserves an ID.

## Approved Source Basis And Claim Boundary

The extraction must use only these completely read governed records:

1. `strategy-seeds/sources/KELOHARJU-RETSEAS-2016/source.md`, covering
   Keloharju, Linnainmaa, and Nyberg (2016), "Return Seasonalities," *The
   Journal of Finance* 71(4), 1557-1590, DOI `10.1111/jofi.12398`, including
   the complete 57-page NBER working-paper review and explicit natural-gas
   membership.
2. `strategy-seeds/sources/MISHRA-SMYTH-XNG-PRED-2016/source.md`, covering
   Mishra and Smyth (2016), "Are Natural Gas Spot and Futures Prices
   Predictable?", *Economic Modelling* 54, 178-186, DOI
   `10.1016/j.econmod.2015.12.034`, including the complete 36-page author
   manuscript and its fixed-frequency contrarian simulations.
3. `strategy-seeds/sources/KELOHARJU-SCHWEIKERT-XAUXAG-SEASRV-2026/source.md`
   only as a previously governed arithmetic/lifecycle precedent for excluding
   the realized observation from a same-calendar sample. Its metals carrier,
   relation evidence, results, and two-leg claims do not transfer.

Keloharju et al. supply the recurring same-calendar commodity expectation and
explicit natural-gas universe membership. Mishra and Smyth supply direct
natural-gas fixed-frequency contrarian evidence and explicit warnings that
their strongest result may be sample- or strategy-specific. Their conjunction
supports one falsifiable question: after subtracting its recurring calendar
expectation, does an unusually large completed XNG monthly return reverse over
the following month?

Neither source tests this exact standardized surprise, a ten-year cap, a
half-standard-deviation band, the Darwinex continuous CFD, fixed-risk sizing,
ATR stop, spread ceiling, or the current portfolio. No source profit factor,
return, significance, drawdown, density, cost, CFD-equivalence, decorrelation,
or portfolio result transfers.

## Locked Mechanic

At the first executable `XNGUSD.DWX` D1 tick of broker month `M`:

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
   `surprise_z=(realized_J-seasonal_mean)/seasonal_sd`.
5. At `surprise_z > +0.50 + 1e-10`, sell XNG. At
   `surprise_z < -0.50 - 1e-10`, buy XNG. Otherwise consume `M` flat.
6. Apply one `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1` budget to the sole position, attach a frozen
   `3.5*ATR(20,D1)` hard stop, set no target, and admit nonnegative modeled
   `.DWX` spread only up to 3,000 points while rejecting crossed quotes.
7. Close at the first genuine later broker-month boundary, repair malformed
   state immediately, and enforce a 40-calendar-day stale guard.

Both news axes, legacy news mode, and framework Friday close are OFF. No
current-bar signal, historical-current-month forecast, unconditional
contrarian fallback, Huber/median/MAD estimator, result-dependent parameter,
magnitude sizing, target, trail, partial close, scale-in, grid, martingale,
pyramid, trained output, banned indicator, or external runtime feed is
authorized.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_SOURCE_CONJUNCTION_AND_CFD_RISK`: two complete-read,
  peer-reviewed records directly cover commodity same-calendar returns and
  natural-gas contrarian predictability; the exact conjunction is untested.
- R2 `PASS`: calendar mapping, endpoints, realized-sample exclusion, bounded
  historical sample, mean, `n-1` scale, band, side, attempt, fixed risk, stop,
  spread, renewal, and repair are locked before Q02.
- R3 `PASS_WITH_ENERGY_LABEL_AND_CONTINUOUS_CFD_RISK`: registered native
  `XNGUSD.DWX` D1 history, broker calendar, quotes, metadata, positions,
  deals, and terminal-global attempt state supply every runtime input.
- R4 `PASS`: deterministic dates, completed OHLC, logarithms, sums, square
  roots, comparisons, and ATR risk plumbing only; no ML or prohibited signal
  component.

## Non-Duplicate Decision

The canonical checker examined 4,707 registry identities, 1,353 card files,
and 45 Strategy Wiki nodes. It returned `CLEAN` with no exact or fuzzy match:
`artifacts/qm5_xng_seassurprise_rv_preallocation_dedup_20260830.json`.

Manual family review fixes the executable boundary:

- `QM5_12567_cum-rsi2-commodity` is a two-day cumulative-RSI2 pullback in a
  slow-trend state with a five-bar hold; this card has no oscillator, moving
  average, D1 pullback, or short holding rule.
- `QM5_20054_xng-1m-contr` fades every nonzero completed monthly return; this
  card first subtracts a same-calendar historical expectation, scales the
  residual, and remains flat inside a strict band.
- `QM5_20100_xng-samecal` and `QM5_41205_xng-samecal-huber10` forecast the
  upcoming calendar month from historical same-month location and follow its
  sign; this card observes the just-completed month and trades against only
  the unexpected component.
- `QM5_21517_xauxag-seas-rv` applies related surprise arithmetic to a
  synchronized, opposite-leg precious-metals return and owns no XNG; the new
  card is a one-leg natural-gas carrier supported by direct gas contrarian
  evidence.

The just-completed XNG month, exclusion of that observation, same-calendar
historical expectation, sample scaling, strict contrarian band, sole energy
carrier, and next-month lifecycle are jointly load-bearing. Verdict:
`CLEAN_XNG_STANDARDIZED_SEASONAL_SURPRISE_REVERSION_AFTER_CANONICAL_AND_MANUAL_REVIEW`.

## Kill And Safety Boundary

Q02 retires the unchanged candidate on zero trades, below five completed
positions in any full post-warm-up year, nonpositive governed economics, or
any label, endpoint, sample-membership, leakage, mean, scale, score, side,
attempt, fixed-risk, stop, spread, lifecycle, or determinism defect. A failed
result may not be rescued by changing the sample, threshold, direction,
carrier, stop, hold, spread, or retry rule.

Different signal logic does not prove low correlation with `QM5_12567` or the
certified book. Unchanged downstream Q09 alone owns realized decorrelation.
This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; terminal control; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers.
