# QM5_13118 Energy Skewness Rank Q02 Enqueue Evidence

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

`QM5_13118_energy-skew-rank` was researched, carded, built, strict-compiled,
and enqueued as one low-frequency market-neutral commodity Q02 basket:

- Logical symbol: `QM5_13118_ENERGY_SKEW_RANK_D1`
- Work item: `c96f8b43-0802-4e49-a53a-c07eee9761c9`
- Status at handoff: `pending`, unclaimed
- Host: `XTIUSD.DWX`, D1
- Traded legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Build task: `5ae1f83a-bc79-4343-9b3c-a0fa41183192`, `done`
- Strict compile: `PASS`, 0 errors, 0 warnings
- Build check: `PASS`, 0 failures, 0 warnings
- Symbol scope: `BASKET_OK`, 0 violations
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Edge Boundary

At the first D1 bar of each broker month, the EA calculates each energy leg's
Pearson moment coefficient of skewness from completed daily log returns in the
preceding 12 complete broker months. It buys the lower-skew leg and shorts the
higher-skew leg, splits the fixed risk budget equally, and reranks monthly.

The primary source is Fernandez-Perez, Frijns, Fuertes, and Miffre (2018),
"The Skewness of Commodity Futures Returns", *Journal of Banking & Finance*
86, DOI `10.1016/j.jbankfin.2017.06.015`. The complete 44-page accepted
manuscript was reviewed. Crude oil and natural gas are explicit members of its
energy panel.

The source portfolio uses 27 commodity futures and extreme quintiles. This
two-leg continuous-CFD carrier is therefore a high-risk translation whose
frequency and economics must be established by Q02. No source performance or
portfolio-correlation claim is imported.

## Non-Duplicate Decision

Pre-allocation repository dedup was `CLEAN`. No realized-skewness or
third-moment commodity card/build existed. The mechanic is different from:

- `QM5_12567` XNG RSI pullback;
- `QM5_12733` XTI/XNG momentum rank;
- `QM5_12840` XTI/XNG return-spread reversion;
- `QM5_12850` XTI/XNG volatility-contraction breakout;
- `QM5_13089` XTI/XNG carry rank;
- `QM5_13113` energy momentum-IVol rank; and
- `QM5_13115` energy same-calendar-month rank.

Atomic allocation assigned `QM5_13118`, with magics `131180000` for XTI and
`131180001` for XNG. The Q02 basket manifest follows the established logical
basket recipe so neither standalone leg is misclassified as the strategy.

## Paced-Fleet Guard

At `2026-07-10T15:28:08+00:00`, seven path-anchored jobs were active on T1,
T2, T3, T4, T6, T7, and T8. The backtest CPU ceiling was reached. No manual
smoke, dispatch tick, or backtest was launched; the new logical Q02 row was
left pending for the paced worker fleet.

No `T_Live` file, AutoTrading setting, live/deploy manifest, portfolio gate,
portfolio admission, or portfolio KPI path was changed.
