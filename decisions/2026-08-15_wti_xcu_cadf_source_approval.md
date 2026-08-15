# WTI/Copper CADF Residual Reversion — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. A Q02 enqueue is not authority to dispatch a
manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-xcu-cadf`
- proposed strategy ID: `CHAN-EIA-USGS-WTI-XCU-CADF-2026_S01`
- proposed source ID: `CHAN-EIA-USGS-WTI-XCU-CADF-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- companion/traded slot 1: `XCUUSD.DWX`, D1
- logical topology: one opposite-leg WTI/copper residual-reversion package
- signal: a fresh standardized residual crossing from a 252-observation
  log-WTI-on-log-copper OLS fit, admitted only when the fitted residual passes
  the locked CADF proxy and half-life gates

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository evidence was read before this
decision:

1. Ernest P. Chan (2009), *Quantitative Trading: How to Build Your Own
   Algorithmic Trading Business*, Wiley, ISBN 978-0-470-28488-9. The bounded
   complete extraction of Examples 3.6, 7.2, 7.3, and 7.5 and the stationarity
   narrative is preserved at
   `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`, SHA-256
   `183A1624AE3EB4432DDE9BA8883E3F5B16E0107A191E468864CA9600D8D45D64`.
   The parent source was CEO-ratified on 2026-04-28. It supplies the OLS hedge,
   CADF qualification, standardized spread fade, mean-band exit, and
   half-life discipline.
2. The complete official-carrier packet
   `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md`, SHA-256
   `6FEB0CE3B231D03255C95B5C2872AFDA28B388DF5284974062B2995A0A243958`,
   records the U.S. Energy Information Administration crude-oil driver
   reference, CME Copper Futures reference, and U.S. Geological Survey copper
   statistics reference.
3. The complete same-pair reversion boundary
   `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-RSPREAD-2026/source.md`,
   SHA-256
   `26B943B0F10682B71AD657610716A51C7DFF262852FFB83B3E0221EADDCDE140`,
   is used to separate this price-level OLS/CADF state from the existing
   fixed-window return-spread fade.

No fresh public-page text, proxy, cache, authentication, or unavailable
content is used. The governed packets are the source evidence of record.

Chan demonstrates the pair-trade method on GLD/GDX and says cointegration is
not implied by correlation. He does not test WTI/copper. EIA, CME, and USGS
establish distinct energy and industrial-base-metal carrier contexts; they do
not establish a WTI/copper cointegrating relation or trading efficacy.

The two-CFD carrier, rolling synchronized fit, simple one-lag CADF proxy,
positive-beta and half-life bounds, ATR stops, spread ceilings, aggregate risk
split, atomic repair, and restart behavior are transparent QM translations.
No source return, Sharpe ratio, significance, drawdown, density, cost, hedge
ratio, CFD equivalence, neutrality, decorrelation, or portfolio result
transfers.

## Locked Mechanic

On each new `XTIUSD.DWX` D1 bar:

1. Load exactly 252 synchronized completed positive finite D1 closes for WTI
   and copper, with exact timestamps and a newest endpoint no more than ten
   calendar days stale.
2. Fit `log(WTI) = alpha + beta * log(copper) + residual` by closed-form OLS.
   Require non-singular copper variance and `beta` in `[0.10, 3.00]`.
3. Regress each residual change on its lagged residual with an intercept.
   Require a negative adjustment coefficient, a t-statistic no greater than
   `-3.043`, AR coefficient strictly in `(0,1)`, and implied half-life in
   `[2,60]` D1 observations. This is the locked simple CADF proxy; it is not a
   claim of permanent cointegration.
4. Standardize the newest two OLS residuals by the 252-observation sample
   residual standard deviation. A fresh cross above `+1.0` sells WTI and buys
   copper; a fresh cross below `-1.0` buys WTI and sells copper. An
   already-extreme, tied, invalid, missing, stale, or desynchronized state
   stays flat.
5. Open at most one opposite-leg package with aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`. Split stop-risk in relative weights
   `1.0` for WTI and `abs(beta)` for copper, normalize the shares, and attach
   one frozen `3.5 * ATR(20,D1)` hard stop to each leg. Signal magnitude never
   scales risk.
6. Require WTI/copper spreads no greater than 1,500/1,200 points. Open WTI
   first and copper second; flatten all owned exposure after any partial-open
   or final-package validation failure.
7. Close both legs when `abs(z) <= 0.5`, the model/data/package becomes
   invalid, or sixty calendar days elapse. Friday close and all news modes are
   OFF for the multiweek hold.

The carrier, log orientation, observation count, OLS intercept, CADF proxy,
critical boundary, positive beta, half-life gate, fresh crossing, paired
direction, risk weights, and atomic lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS`: a CEO-ratified complete Wiley book extraction plus governed
  official EIA, CME, and USGS carrier evidence.
- R2 `PASS`: history, estimator, stationarity proxy, direction, lifecycle,
  aggregate risk, stops, spreads, and repair are deterministic and locked.
- R3 `PASS`: registered WTI and copper D1 routes supply every runtime input;
  Q02 owns synchronized-history, stationarity, density, and fill proof.
- R4 `PASS`: native arithmetic and framework state only; no trained output,
  banned signal indicator, external runtime feed, grid, martingale, scale-in,
  or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,397 EA-registry rows and 493
root cards and returned `CLEAN` with no exact or fuzzy match. Manual review
fixes the nearest boundaries:

- `QM5_13090_xti-xcu-rspread` fades a short-window standardized return
  difference; it does not fit log levels or require a residual CADF gate.
- `QM5_13094_xti-xcu-brk` follows a log-price spread channel; this candidate
  fades a qualified OLS residual after a fresh standardized crossing.
- `QM5_21524_wti-xcu-relmom` follows a twelve-completed-month relative rank
  and renews monthly; this candidate uses daily residual convergence.
- `QM5_20237_xtixng-ecm-rv` is an oil/gas, trend-augmented XNG-on-XTI model
  sourced to the weak oil/gas tie. This candidate is WTI-on-copper, has no
  time trend, and requires the locked residual CADF proxy.
- `QM5_20161_xauxag-ols-rv` carries precious metals rather than energy versus
  industrial base metal and has no WTI/copper CADF contract.
- `QM5_12567_cum-rsi2-commodity` is a long-only XNG oscillator pullback.

Verdict: `CLEAN_WTI_COPPER_CADF_RESIDUAL_REVERSION_PACKAGE`.

## Kill And Safety Boundary

Expected cadence is approximately five to twelve completed packages per full
post-warm-up year. Q02 must retire below five/year, on zero trades, failure of
the stationarity gate, or nonpositive governed economics. Q09 alone may
establish realized correlation with the certified book. Opposite sides and
beta-weighted stop risk do not prove dollar, beta, volatility, factor, market,
or portfolio neutrality.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once; if the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.

