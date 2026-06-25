# QM5_11635_fsr-adv6-ema20-40-adx-h4 - Strategy Spec

**EA ID:** QM5_11635
**Slug:** `fsr-adv6-ema20-40-adx-h4`
**Source:** `5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d` (see `artifacts/cards_approved/QM5_11635_fsr-adv6-ema20-40-adx-h4.md`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA trades an EMA(20) pullback limit inside an ADX-confirmed trend on H4. When ADX(14) is above 30 and current price is above EMA(40), it places a buy limit at EMA(20); when current price is below EMA(40), it places a sell limit at EMA(20). The stop is placed beyond EMA(40) by a 10-pip buffer with a 20-pip minimum floor from entry. There is no fixed take-profit; an open position is closed when ADX(14) falls below 30.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast_period` | 20 | 2-100 | Pullback EMA used as the pending limit entry price. |
| `strategy_ema_slow_period` | 40 | 3-200 | Trend EMA used as the price-side filter and stop boundary. |
| `strategy_adx_period` | 14 | 2-100 | ADX period used for trend confirmation and exit. |
| `strategy_adx_threshold` | 30.0 | 0.0-100.0 | Minimum ADX value required before placing a limit entry. |
| `strategy_adx_exit_threshold` | 30.0 | 0.0-100.0 | Close open positions when ADX falls below this value. |
| `strategy_sl_buffer_pips` | 10 | 1-100 | Pip buffer beyond EMA(40) for stop placement. |
| `strategy_sl_min_floor_pips` | 20 | 1-250 | Minimum stop distance in pips from the EMA(20) limit price. |
| `strategy_pending_expiration_hours` | 4 | 1-168 | Pending EMA(20) limit order expiration in hours. |
| `strategy_spread_pct_of_stop` | 15.0 | 0.0-100.0 | Blocks only genuinely wide spread when spread exceeds this percent of the minimum stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX forex pair with H4 history for EMA/ADX pullback testing.
- `GBPUSD.DWX` - card-listed DWX forex pair with H4 history for EMA/ADX pullback testing.
- `USDJPY.DWX` - card-listed DWX forex pair with H4 history for EMA/ADX pullback testing.
- `XAUUSD.DWX` - card-listed DWX metal symbol included in the approved portable basket.

**Explicitly NOT for:**
- `SP500.DWX` - not part of the approved forex/metals target set.
- `NDX.DWX` - not part of the approved forex/metals target set.
- `WS30.DWX` - not part of the approved forex/metals target set.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `hours to days` |
| Expected drawdown profile | `trend-following pullback whipsaw risk when ADX weakens late` |
| Regime preference | `trend / pullback` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `5e9e8c4d-0c88-5dc6-a550-b3b070a5b44d`
**Source type:** `forum / collection archive`
**Pointer:** `forex-strategies-revealed.com, "Advanced System #6 (EMA Bounce)"; local card D:/QM/strategy_farm/artifacts/cards_approved/QM5_11635_fsr-adv6-ema20-40-adx-h4.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11635_fsr-adv6-ema20-40-adx-h4.md`

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
| v1 | 2026-06-25 | Initial build from card | 8e7caea8-5f0c-4356-b132-b1074532e61c |
