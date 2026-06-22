# QM5_11738_rfs-ha-adx-stoch-m5 - Strategy Spec

**EA ID:** QM5_11738
**Slug:** `rfs-ha-adx-stoch-m5`
**Source:** `b5a932a2-40b6-5628-840b-d5069ac35c4a` (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades M5 trend-continuation signals when Heiken Ashi candles, ADX, and Stochastic agree. A long opens on the next bar after two bullish Heiken Ashi candles, rising ADX above 22 with +DI above -DI, and rising Stochastic K. A short opens after two bearish Heiken Ashi candles, rising ADX above 22 with -DI above +DI, and falling Stochastic K. Positions exit only through the fixed 7-pip stop loss, fixed 12-pip take profit, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ha_seed_bars` | 80 | 20+ | Bounded history depth used to seed recursive Heiken Ashi candles |
| `strategy_adx_period` | 14 | 1+ | ADX and DI period |
| `strategy_adx_threshold` | 22.0 | 0+ | Minimum ADX trend-strength threshold |
| `strategy_stoch_k` | 5 | 1+ | Stochastic K period |
| `strategy_stoch_d` | 3 | 1+ | Stochastic D period |
| `strategy_stoch_slowing` | 3 | 1+ | Stochastic slowing period |
| `strategy_sl_pips` | 7 | 1+ | Fixed stop-loss distance in pips |
| `strategy_tp_pips` | 12 | 1+ | Fixed take-profit distance in pips |
| `strategy_max_spread_pips` | 0 | 0+ | Optional spread cap in pips; 0 disables this card-unspecified filter |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated liquid FX target with DWX M5 data available
- `GBPUSD.DWX` - card-stated liquid FX target with DWX M5 data available
- `USDJPY.DWX` - card-stated liquid FX target with DWX M5 data available
- `USDCHF.DWX` - card-stated liquid FX target with DWX M5 data available

**Explicitly NOT for:**
- Non-DWX symbols - pipeline backtests require registered `.DWX` symbols
- Symbols outside the card-stated FX basket - not part of this approved strategy card

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `300` |
| Typical hold time | minutes to hours |
| Expected drawdown profile | scalping-style fixed SL/TP drawdowns with many small trades |
| Regime preference | trend-following momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b5a932a2-40b6-5628-840b-d5069ac35c4a`
**Source type:** online compilation / local PDF archive
**Pointer:** `362359657-Robo-forex-strategy.pdf`, page 23; approved card at `artifacts/cards_approved/QM5_11738_rfs-ha-adx-stoch-m5.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11738_rfs-ha-adx-stoch-m5.md`

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
| v1 | 2026-06-23 | Initial build from card | 0a5c8f7e-6b85-41b5-8bbe-0ee01db92da5 |
