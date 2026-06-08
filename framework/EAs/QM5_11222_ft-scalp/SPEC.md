# QM5_11222_ft-scalp - Strategy Spec

**EA ID:** QM5_11222
**Slug:** `ft-scalp`
**Source:** `1580128f-e465-5454-bb97-a7572a6cfd6d` (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades a long-only M1 scalp on closed bars. It enters long when the last closed bar opened below EMA(5) of lows, ADX(14) is above 30, Fast Stochastic 5/3/3 has both K and D below 30, and K crosses above D. It exits at a 1% ROI target, when the last closed bar opened at or above EMA(5) of highs, or when K or D crosses above 70. The initial stop uses ATR(14) x 1.2, with the source -4% stop retained as a disaster cap.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 5 | 5-13 | EMA channel period for low-entry and high-exit bands |
| `strategy_adx_period` | 14 | fixed | ADX lookback used by the source scalp filter |
| `strategy_adx_entry` | 30.0 | 20-40 | Minimum ADX required before a long entry |
| `strategy_stoch_k_period` | 5 | fixed | Fast Stochastic K period |
| `strategy_stoch_d_period` | 3 | fixed | Fast Stochastic D period |
| `strategy_stoch_slowing` | 3 | fixed | Fast Stochastic slowing |
| `strategy_stoch_oversold` | 30.0 | 20-40 | Maximum K and D values allowed for entry |
| `strategy_stoch_exit` | 70.0 | 60-80 | K or D cross threshold for signal exit |
| `strategy_atr_period` | 14 | fixed | ATR lookback for the baseline stop |
| `strategy_atr_stop_mult` | 1.2 | 1.0-1.5 | ATR multiplier for the baseline stop |
| `strategy_roi_pct` | 1.0 | fixed | Source ROI target percentage |
| `strategy_disaster_stop_pct` | 4.0 | fixed | Maximum source stop distance retained as disaster cap |
| `strategy_max_spread_stop_fraction` | 0.05 | fixed | Maximum spread as a fraction of planned stop distance |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card-listed liquid forex major with M1 DWX data.
- `GBPUSD.DWX` - Card-listed liquid forex major with M1 DWX data.
- `USDJPY.DWX` - Card-listed liquid forex major with M1 DWX data.
- `XAUUSD.DWX` - Card-listed gold symbol with M1 DWX data and scalp-compatible liquidity profile.

**Explicitly NOT for:**
- `SP500.DWX` - Not listed in the card's R3 basket.
- `NDX.DWX` - Not listed in the card's R3 basket.
- `WS30.DWX` - Not listed in the card's R3 basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | Minutes; exact hold time is not specified in the card |
| Expected drawdown profile | High-risk scalp profile; card leaves PF and DD as TBD |
| Regime preference | M1 stochastic/EMA scalp with ADX trend-strength gate |
| Win rate target (qualitative) | Medium |

Expected trade frequency: `M1 stochastic/EMA scalp; conservative one-position V5 estimate 120-300 trades/year/symbol.`

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1580128f-e465-5454-bb97-a7572a6cfd6d`
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/berlinguyinca/Scalp.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11222_ft-scalp.md`

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
| v1 | 2026-06-08 | Initial build from card | a5447497-0053-433e-96b5-094d81db1d56 |
