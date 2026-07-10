# QM5_13115 Energy Same-Calendar Q02 Enqueue Evidence

Date: 2026-07-10
Branch: `agents/board-advisor`

## Outcome

`QM5_13115_energy-samecal` was built as a low-frequency, paired XTI/XNG
same-calendar-month seasonality basket and enqueued to Q02 as one logical
symbol: `QM5_13115_ENERGY_SAMECAL_D1`.

- Work item: `43841062-306a-4f8a-9b2f-d9a513e6ed77`
- Status at handoff: `pending`, unclaimed
- Host: `XTIUSD.DWX` D1
- Traded legs: `XTIUSD.DWX`, `XNGUSD.DWX`
- Build task: `ff26ecf6-23ab-4bbe-a06d-8bb7164eab9d`, `done`
- Strict compile: `PASS`, 0 errors, 0 warnings
- Build check: `PASS`, 0 failures, 0 warnings
- Symbol scope: `BASKET_OK`, 0 violations
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Edge Boundary

At each new broker month, the EA reconstructs synchronized historical returns
for that same calendar month. It buys the energy leg with the higher average
same-month return and shorts the lower leg, then rolls the paired package at
the next month. The port is deliberately distinct from the repository's
existing XTI/XNG momentum, mean-reversion, breakout, carry, and volatility
screens. Pre-allocation dedup was `CLEAN`.

The primary research basis is Keloharju, Linnainmaa, and Nyberg, *Return
Seasonalities*, Journal of Finance 71(4), DOI `10.1111/jofi.12398`, with the
complete NBER Working Paper 20815 used for extraction. The source studies a
diversified commodity-futures cross-section; this two-leg CFD carrier is a
high-risk translation that Q02 must validate independently.

## Paced-Fleet Guard

At `2026-07-10T13:21:05+00:00`, T1, T2, T3, T4, and T8 were already running
path-anchored Q02 work. The CPU ceiling was therefore treated as reached. No
manual smoke, dispatch tick, or backtest was launched; the new work item was
left pending for the fleet pacer.

No `T_Live` file, AutoTrading setting, portfolio gate, portfolio manifest, or
deploy manifest was changed.
