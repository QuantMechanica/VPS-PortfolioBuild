# QM5_4006_fx-session-flow — Strategy Spec

**EA ID:** 4006  
**Strategy:** SRC09_S01  
**Symbol / timeframe:** EURUSD.DWX / M15  
**Approval:** OWNER-delegated CEO/CTO after independent Quality-Business review, 2026-07-17

## Executable rule

- On each valid Monday-Friday London civil date, sell EURUSD on the first executable tick at or after 07:00 Europe/London, no later than 300 seconds.
- Close the short at 08:00 America/New_York. Only after confirmed flat, buy EURUSD at that same boundary.
- Close the long at 16:00 America/New_York.
- Entries are one-shot. Mandatory exits retry at most once per five seconds; after 60 seconds the EA latches the affected strategy day, blocks new entries and keeps trying to flatten. The day latch releases only after confirmed flat and arrival of a later valid London business date; account-level kill switches are unaffected.
- London and New-York boundaries are independently resolved to UTC and broker time. The local clock helper fails closed and self-tests 2017-2026 DST transitions on initialization.
- Generic broker-Friday close is disabled under the approved execution contract; the source-defined Friday 16:00 New-York exit owns flattening.

## Risk and costs

- Prior closed D1 ATR(20) × 1.0 is frozen at entry as a non-alpha catastrophic stop; there is no TP, trail, break-even, partial close, grid, or re-entry.
- Q03 may vary only `strategy_stop_atr_mult` over `0.50,0.75,1.00,1.25,1.50,1.75,2.00`; clocks and all other strategy parameters stay locked and the plateau median is selected.
- Backtests use RISK_FIXED 1000. Phase 1 design risk is 0.25% per leg and at most 0.50% planned family risk per day. The US leg is blocked after a full one-leg realized family loss.
- Baseline uses native Model-4 bid/ask ticks and an entry-only 30-point spread ceiling. The dated FTMO seed is USD 5/lot round trip, long swap -9.36 points, short swap +0.22 points, followed by 2x execution-cost stress.

## Parameters

| Parameter | Default | Q03 status |
|---|---:|---|
| `strategy_enable_eu_leg` | true | locked |
| `strategy_enable_us_leg` | true | locked |
| `strategy_entry_delay_max_seconds` | 300 | locked; later execution stress only |
| `strategy_exit_retry_interval_seconds` | 5 | locked |
| `strategy_exit_escalation_seconds` | 60 | locked |
| `strategy_stop_atr_period_d1` | 20 | locked |
| `strategy_stop_atr_mult` | 1.0 | sole axis: 0.50…2.00 |
| `strategy_max_spread_points` | 30 | locked |

## Lineage

The canonical approved card is `strategy-seeds/cards/fx-session-flow_card.md`. Build, Q02, later pipeline evidence, deployment approval, and AutoTrading authorization are separate gates.
