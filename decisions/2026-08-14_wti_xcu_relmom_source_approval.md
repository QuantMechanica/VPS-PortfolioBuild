# WTI/Copper Twelve-Month Relative Momentum — Source Approval

Date: 2026-08-14

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 handoff if the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-xcu-relmom`
- proposed strategy ID: `FMR-EIA-USGS-WTI-XCU-RELMOM-2026_S01`
- canonical source ID: `FMR-EIA-USGS-WTI-XCU-RELMOM-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1
- companion/traded slot 1: `XCUUSD.DWX`, D1
- logical topology: one opposite-leg WTI/copper package
- decision clock: first processed WTI D1 bar after a genuine broker-month
  transition
- active rule: buy the higher and short the lower of WTI and copper when
  ranked by the arithmetic mean of exactly twelve synchronized completed
  monthly simple returns

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository packets were read before this
decision:

1. Fuertes, Miffre, and Rallis (2010), "Tactical Allocation in Commodity
   Futures Markets: Combining Momentum and Term Structure Signals,"
   *Journal of Banking & Finance* 34(10), 2530-2548, DOI
   `10.1016/j.jbankfin.2010.04.009`. The complete 47-page accepted-manuscript
   review, methodology locations, robustness boundary, and institutional
   repository URL are recorded at
   `strategy-seeds/sources/FMR-MOMTS-2010/source.md`, SHA-256
   `1F4F4977B0D9646A8BF56543D1881CCBC1513D4644DE72C350614580F3FF7417`.
2. The official-carrier packet
   `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-BRK-2026/source.md`, SHA-256
   `6FEB0CE3B231D03255C95B5C2872AFDA28B388DF5284974062B2995A0A243958`,
   records the U.S. Energy Information Administration crude-oil price-driver
   reference, CME Copper Futures reference, and U.S. Geological Survey copper
   statistics reference. It establishes WTI's energy supply/demand and shock
   exposure and copper's industrial/base-metal carrier context only.
3. The same-pair reversion boundary was read completely at
   `strategy-seeds/sources/EIA-CME-USGS-XTI-XCU-RSPREAD-2026/source.md`,
   SHA-256
   `26B943B0F10682B71AD657610716A51C7DFF262852FFB83B3E0221EADDCDE140`.
   It is used only to prove separation from the existing short-horizon
   return-spread fade, not as positive evidence for continuation.

No fresh public-page text, proxy, cache, authentication, or quotation is used.
The complete governed packets are the source evidence of record.

Fuertes, Miffre, and Rallis explicitly test one-, three-, and twelve-month
cross-sectional commodity-futures momentum rankings with a one-month hold.
The source uses a broad collateralized futures universe. It does not test a
two-name WTI/copper CFD package. The official EIA/CME/USGS material establishes
the economically distinct physical-commodity carriers; it does not claim
relative-momentum profitability.

The exact two-CFD subset, synchronized broker-month endpoints, fixed
equal-risk split, hard stops, spread ceilings, atomic repair, and restart
ledger are transparent QM translations. No source return, alpha, Sharpe
ratio, significance, drawdown, trade count, cost, hedge ratio, neutrality,
CFD equivalence, decorrelation, or portfolio result transfers.

## Locked Mechanic

At the first processed host D1 bar after each genuine broker-month transition,
after closing prior-month owned exposure and consuming the new month before
every fallible gate:

1. Load bounded completed `XTIUSD.DWX` and `XCUUSD.DWX` D1 histories and
   derive exactly thirteen consecutive common broker-month endpoints ending
   in the immediately completed month.
2. Require positive finite closes, exact endpoint timestamp agreement,
   chronological order, consecutive broker months, and a newest common
   endpoint no more than ten calendar days stale.
3. Calculate exactly twelve simple monthly returns per leg and their
   arithmetic means:

```text
avg12_wti = sum(WTI_month_close[m] / WTI_month_close[m-1] - 1,
                m=1..12) / 12
avg12_xcu = sum(XCU_month_close[m] / XCU_month_close[m-1] - 1,
                m=1..12) / 12
relative_momentum = avg12_wti - avg12_xcu
```

4. Buy WTI and sell copper only when `relative_momentum > 1e-10`. Sell WTI
   and buy copper only when `relative_momentum < -1e-10`. Consume a tie,
   deadband, invalid, missing, stale, or misaligned state flat.
5. Open at most one opposite-leg package with aggregate
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one equal $500 stop-risk half per
   leg. Each leg receives a frozen `3.5 * ATR(20,D1)` broker hard stop and no
   take-profit.
6. Require WTI and copper entry spreads no greater than 1,500 and 1,200
   points respectively. Open WTI then copper; flatten every owned leg if the
   second order or final package validation fails.
7. Close both legs before monthly replacement or after forty calendar days.
   Immediately flatten an orphan, duplicate, same-direction, wrong-symbol,
   wrong-magic, or missing-stop package. Friday close and both news axes are
   OFF for the source-aligned monthly hold.

The exact endpoint count, simple-return arithmetic mean, twelve-month horizon,
strict rank, two opposite traded legs, equal fixed-risk halves, monthly clock,
and one consumed attempt are load-bearing. A log-price channel, rolling D1
z-score, mean-reversion sign, single-carrier order, volatility rank, carry
proxy, optimization sweep, or alternate horizon is outside this approval.

## Reputable-Source Criteria

- R1 `PASS`: a fully reviewed peer-reviewed *Journal of Banking & Finance*
  paper with DOI and institutional accepted manuscript, plus governed official
  EIA, CME, and USGS carrier references.
- R2 `PASS`: exact common month endpoints, twelve simple returns, arithmetic
  means, strict direction map, attempt state, equal fixed risk, hard stops,
  rollover, stale guard, and atomic repair are fixed.
- R3 `PASS`: both `XTIUSD.DWX` and `XCUUSD.DWX` are already registered and
  exercised in governed V5 builds; Q02 owns synchronized-history and fill
  validation.
- R4 `PASS`: deterministic native price/calendar arithmetic and framework
  state only; no trained output, banned signal indicator, external runtime
  feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,396 EA-registry rows and 492
root cards and returned `CLEAN` with no fuzzy match for the proposed slug,
strategy ID, authors, or complete mechanic. Manual review fixes the closest
boundaries:

- `QM5_13094_xti-xcu-brk` follows a daily price-level log-spread channel and
  exits on a shorter channel. This candidate ranks exactly twelve completed
  broker-month simple returns and renews only monthly.
- `QM5_13090_xti-xcu-rspread` fades a short-window return-spread z-score. This
  candidate follows, rather than fades, a twelve-month cross-sectional rank
  and forms no z-score.
- `QM5_12733_xti-xng-xmom` uses WTI/natural gas, a 126-D1 cumulative return,
  a percentage deadband, and Friday close. This candidate uses copper,
  thirteen exact common month ends, twelve arithmetic monthly returns, a
  numerical tie tolerance, and a full-month hold.
- `QM5_20050_xauxag-xmom12` is the precious-metal carrier of the same source
  horizon. This candidate expresses energy versus industrial base metal and
  contains no gold or silver exposure.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback and shares neither topology, state, direction map, nor clock.

Verdict:
`CLEAN_WTI_COPPER_TWELVE_MONTH_CROSS_SECTIONAL_MOMENTUM_PACKAGE`.

## Kill And Safety Boundary

Expected cadence is approximately twelve completed packages per full
post-warm-up year. Q02 must retire below five packages/year or on nonpositive
governed economics. Q09 alone may establish realized correlation with the
certified XAU, SP500, NDX, and XNG book. Opposite direction and equal stop-risk
halves do not prove dollar, beta, volatility, factor, or portfolio neutrality.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. If the
paced factory CPU ceiling is binding before enqueue, stop and record the
capacity state without starting, stopping, reserving, reaping, or
reprioritizing a terminal.
