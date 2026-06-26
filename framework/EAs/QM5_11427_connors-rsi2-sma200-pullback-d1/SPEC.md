# QM5_11427_connors-rsi2-sma200-pullback-d1 - Strategy Spec

**EA ID:** QM5_11427
**Slug:** connors-rsi2-sma200-pullback-d1
**Source:** 4932e25a-fdfb-50cd-b5f5-18e55f3045c2 (see `strategy-seeds/sources/4932e25a-fdfb-50cd-b5f5-18e55f3045c2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA trades daily Connors RSI(2) pullbacks with a 200-day SMA trend filter. It buys when the last closed D1 close is above SMA(200) and RSI(2) is below 5, and it sells when the last closed D1 close is below SMA(200) and RSI(2) is above 90. Longs exit when RSI(2) recovers above 65 or the close is above SMA(5); shorts use the mirrored recovery rule, RSI(2) below 35 or close below SMA(5). Entries use an ATR(14) x 1.5 protective stop capped at 80 pips and a 2R take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 2 | >=1 | RSI period for entry and exit signals. |
| `strategy_rsi_long_entry` | 5.0 | 0-100 | Long entry threshold; buy when RSI is below this level in an uptrend. |
| `strategy_rsi_short_entry` | 90.0 | 0-100 | Short entry threshold; sell when RSI is above this level in a downtrend. |
| `strategy_rsi_long_exit` | 65.0 | 0-100 | Long discretionary exit threshold. |
| `strategy_rsi_short_exit` | 35.0 | 0-100 | Mirrored short discretionary exit threshold. |
| `strategy_trend_sma_period` | 200 | >=2 | D1 SMA period for bull/bear regime. |
| `strategy_exit_sma_period` | 5 | >=1 | D1 SMA period for strength-recovery exit. |
| `strategy_atr_period` | 14 | >=1 | D1 ATR period for stop distance. |
| `strategy_atr_sl_mult` | 1.5 | >0 | ATR multiplier for protective stop. |
| `strategy_take_profit_rr` | 2.0 | >0 | Fixed take-profit multiple of initial risk. |
| `strategy_stop_cap_pips` | 80 | >=1 | Maximum protective stop distance in pips. |
| `strategy_spread_cap_pips` | 25 | >=1 | Maximum tradable spread in pips; zero modeled spread is allowed. |
| `strategy_shorts_enabled` | true | true/false | Enables the bearish-regime short side described by the card. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed D1 forex symbol with native DWX coverage.
- `GBPUSD.DWX` - card-listed D1 forex symbol with native DWX coverage.
- `USDJPY.DWX` - card-listed D1 forex symbol with native DWX coverage.
- `AUDUSD.DWX` - card-listed D1 forex symbol with native DWX coverage.
- `USDCAD.DWX` - card-listed D1 forex symbol with native DWX coverage.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline use Darwinex `.DWX` data names.
- Intraday-only symbols or timeframes - the card is D1-native.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | short-term, usually several daily bars |
| Expected drawdown profile | mean-reversion pullbacks with protective ATR stop losses |
| Regime preference | mean-revert pullbacks inside SMA200 trend regimes |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 4932e25a-fdfb-50cd-b5f5-18e55f3045c2
**Source type:** book
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\100324184-Short-Term-Trading-Strategies-That-Work-by-Larry-Connors-and-Cesar-Alvarez.pdf`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11427_connors-rsi2-sma200-pullback-d1.md`

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
| v1 | 2026-06-26 | Initial build from card | db3c523f-43a7-4620-8328-837295f71c7b |
