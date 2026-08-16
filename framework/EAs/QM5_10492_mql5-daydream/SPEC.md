# QM5_10492_mql5-daydream — Strategy Spec

**EA ID:** QM5_10492
**Slug:** `mql5-daydream`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Author of this spec:** Codex
**Last revised:** 2026-08-16

---

## 1. Strategy Logic

On each new H1 bar, the EA compares the most recently completed close with the
high/low channel formed by the preceding 20 completed bars. A close below the
channel low opens long; a close above the channel high opens short. Only one
position for the EA's symbol and magic may be open. The protective stop is
ATR(14) × 1.0 from entry and the broker-side target is 1.5 times initial risk.
An opposite channel-overshoot signal or a 48-bar holding period closes the
position. All signal calculations use completed bars.

## 2. Parameters

| Parameter | Default | Governed use | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | H1 | Card-fixed baseline | Signal and time-stop timeframe |
| `strategy_model` | 1 | Implementation-fixed | Price-channel overshoot reversal model |
| `strategy_channel_bars` | 20 | P3 sweep only | Completed bars in the price channel |
| `strategy_atr_period` | 14 | Card baseline | ATR period for the protective stop |
| `strategy_atr_sl_mult` | 1.0 | Card baseline | Stop distance in ATR units |
| `strategy_tp_r_mult` | 1.5 | Card baseline | Take-profit distance in initial-risk units |
| `strategy_time_stop_bars` | 48 | Card baseline | Maximum H1 holding period |
| `strategy_max_spread_points` | 250 | Execution guard | Reject entries above this spread |
| `strategy_min_atr_points` | 0 | Disabled baseline | Optional minimum-ATR entry filter |

## 3. Symbol Universe

The approved P2 basket is `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and
`XAUUSD.DWX`. Each backtest setfile binds one symbol to its allocated registry
slot; the EA does not place cross-symbol orders from a single chart instance.

## 4. Timeframe

The base and signal timeframe is H1. There are no higher- or lower-timeframe
references. Entries are gated to new bars, and entry/exit signals read closed
bars only.

## 5. Expected Behaviour

The approved card estimates approximately eight trades per year per symbol,
based on 2024 smoke evidence of nine USDJPY trades and six EURUSD trades. The
edge is low-frequency structural mean reversion after a channel overshoot, with
typical holding time bounded at 48 hours. It is expected to work best when
overshoots revert rather than expand into persistent breakouts.

## 6. Source Citation

Scriptor (idea) and Vladimir Karputov / barabashkakvn (code), “Daydream,” MQL5
CodeBase, published 2018-10-25: https://www.mql5.com/en/code/22021. The approved
card records R1, R2, R3, and R4 as PASS and contains no ML, grid, martingale, or
adaptive-volume mechanic.

## 7. Risk Model

Q02–Q10 backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. `QM_FrameworkInit` enforces the environment-to-risk-mode
contract. Live sizing and deployment remain outside this build/repair unit and
require their later governed approvals.

---

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-16 | Document the approved card and existing implementation during the GBPUSD Q02 infrastructure repair |
