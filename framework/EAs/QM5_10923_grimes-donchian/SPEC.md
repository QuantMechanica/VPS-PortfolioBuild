# QM5_10923_grimes-donchian - Strategy Spec

**EA ID:** QM5_10923
**Slug:** `grimes-donchian`
**Source:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c` (see `strategy-seeds/sources/fbfd7f6e-462a-55c8-9efa-9005a70c9f5c/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates completed D1 bars. It goes long when the last completed close breaks above the highest high of the prior 100 completed D1 bars, and goes short when the last completed close breaks below the lowest low of the prior 100 completed D1 bars. Same-direction re-entry is blocked until the opposite breakout direction has been taken, so a stop or time exit leaves the EA waiting for the next opposite flip. Initial stop distance is 3.0 x ATR(20), and after price has moved at least 2R in favor, the stop trails 4.0 x ATR(20) from the best closed-bar close since entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_bars` | 100 | 1+ | Completed D1 bars used for the prior high/low breakout channel. |
| `strategy_atr_period` | 20 | 1+ | ATR period for initial stop and trailing stop distance. |
| `strategy_initial_atr_mult` | 3.0 | >0 | ATR multiple for initial protective stop. |
| `strategy_trail_trigger_r` | 2.0 | >0 | Favorable move in initial-risk units required before trailing begins. |
| `strategy_trail_atr_mult` | 4.0 | >0 | ATR multiple used to trail from the best closed-bar close since entry. |
| `strategy_max_hold_bars` | 180 | 0+ | Maximum D1 bars to hold a trade; 0 disables the time exit. |
| `strategy_spread_stop_frac` | 0.05 | 0+ | Maximum spread as a fraction of initial stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - major FX pair in the card's currency/commodity basket.
- `GBPUSD.DWX` - major FX pair in the card's currency/commodity basket.
- `USDJPY.DWX` - major FX pair in the card's currency/commodity basket.
- `XAUUSD.DWX` - liquid metal CFD in the card's currency/commodity basket.
- `XTIUSD.DWX` - liquid oil CFD in the card's currency/commodity basket.

**Explicitly NOT for:**
- `SP500.DWX` - the card restricts P2 to currencies, metals, and oil.
- `NDX.DWX` - the card restricts P2 to currencies, metals, and oil.
- `WS30.DWX` - the card restricts P2 to currencies, metals, and oil.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `8` |
| Typical hold time | Up to 180 D1 bars unless an opposite channel flip or protective stop exits earlier. |
| Expected drawdown profile | Infrequent trend-following losses are bounded by the initial ATR stop and trailing stop once the trade reaches 2R. |
| Regime preference | Breakout / trend-following on currencies, metals, and oil. |
| Win rate target (qualitative) | Low to medium, with profits expected from larger trend runs. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`
**Source type:** blog
**Pointer:** Adam H. Grimes, "No, it's not all the same", 2015-10-13, https://www.adamhgrimes.com/no-its-not-all-the-same/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10923_grimes-donchian.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 5fe0fc14-3b23-4821-bb0a-7e10cbc6e1e5 |
