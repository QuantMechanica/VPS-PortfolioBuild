# QM5_41339_wti-adf-lz-agree-tr - Strategy Spec

**EA ID:** 41339  
**Slug:** `wti-adf-lz-agree-tr`  
**Symbol / timeframe:** `XTIUSD.DWX` / D1  
**Magic:** `413390000` (slot 0)  
**Card:** `strategy-seeds/cards/approved/QM5_41339_wti-adf-lz-agree-tr_card.md`

## Mechanical identity

At the first executable D1 tick of a new broker month, reconstruct sixty
consecutive completed WTI month-end log closes. Require both:

1. lag-one intercept/no-time-trend ADF `t >= -2.594`;
2. exact LZ76 exhaustive-history complexity `<= 6` on the newest twenty
   monthly return signs, with a `1e-12` tie band.

Follow the strict sign of the newest twelve-month log return for one broker
month. Consume the month before every fallible entry gate and never retry.

## Execution and risk

- Backtest: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen hard stop: `3.5 * ATR(20,D1)`; no target.
- Entry spread ceiling: 1,500 points; zero modeled spread is allowed.
- News temporal/compliance and legacy mode OFF; Friday close OFF; stress OFF.
- Exit on the first later broker month or after forty calendar days.
- One position only; no scale-in, partial close, trail, grid, martingale,
  pyramid, external runtime data, randomness, adaptive state, or ML.

## Framework alignment

- `Strategy_NoTradeFilter`: identity, risk, news, Friday, stress, and locked-input guards.
- `Strategy_EntrySignal`: monthly clock, persistent attempt, shared endpoint reconstruction, ADF, LZ76, momentum side, spread/quote/ATR/stop checks.
- `Strategy_ManageOpenPosition`: malformed exposure repair, direction recovery, later-month exit, and stale exit.
- `Strategy_ExitSignal`: framework close path; broker hard stop and kill switch remain authoritative.
- `Strategy_NewsFilterHook`: callable entry-only news hook, card-locked OFF.

## Source and non-duplicate boundary

The source approval and G0 decision bind complete governed ADF, LZ76, and
peer-reviewed WTI continuation records. This exact conjunction is distinct
from either single diagnostic and from ADF agreements using KPSS, spectral
entropy, or raw von Neumann dispersion. It is an untested falsification
candidate, not a performance or decorrelation claim; Q09 remains authoritative.

## Safety boundary

Non-live build and pipeline evidence only. No manual backtest, live/demo/
shadow/stress preset, portfolio-gate change, correlation waiver, deployment,
live manifest, `T_Live`, or AutoTrading action is authorized.
