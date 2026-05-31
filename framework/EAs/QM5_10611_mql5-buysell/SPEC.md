# QM5_10611_mql5-buysell - Strategy Spec

**EA ID:** QM5_10611
**Slug:** `mql5-buysell`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `sources/mql5-codebase-mt5-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA trades the BuySell semaphore reversal rule on completed H4 bars. The BuySell source indicator forms a bullish square when its moving-average slope changes from falling to rising, and a bearish square when the slope changes from rising to falling. The EA opens long on a bullish square and short on a bearish square, exits on the opposite square, and also exits after 16 completed H4 bars if no opposite square appears. It uses a catastrophic stop at 2.5 x ATR(14) from entry and no take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H4` | MT5 timeframe enum | Timeframe used for BuySell signal evaluation. |
| `strategy_signal_bar` | `1` | `>=1` | Closed bar shift used for signal reads. |
| `strategy_buysell_ma_period` | `14` | `>1` | BuySell source moving-average period. |
| `strategy_buysell_ma_method` | `MODE_SMA` | MT5 MA method enum | BuySell source moving-average method. |
| `strategy_buysell_ma_price` | `PRICE_CLOSE` | MT5 applied price enum | Price source for the BuySell moving average. |
| `strategy_buysell_atr_period` | `60` | `>0` | BuySell source ATR period used to validate semaphore buffers. |
| `strategy_atr_period` | `14` | `>0` | ATR period for the catastrophic stop. |
| `strategy_atr_sl_mult` | `2.5` | `>0` | Stop distance multiplier applied to ATR(14). |
| `strategy_time_stop_bars` | `16` | `>=0` | Maximum completed signal-timeframe bars to hold a trade. |
| `strategy_use_ema_filter` | `false` | `true/false` | Optional P3 200 EMA trend filter; disabled for baseline. |
| `strategy_ema_filter_period` | `200` | `>1` | EMA period used when the optional filter is enabled. |

---

## 3. Symbol Universe

**Designed for:**
- `USDCHF.DWX` - source test used USDCHF H4 and the symbol is present in the DWX matrix.
- `EURUSD.DWX` - liquid DWX FX major for portable semaphore reversal testing.
- `GBPUSD.DWX` - liquid DWX FX major for portable semaphore reversal testing.
- `XAUUSD.DWX` - liquid DWX metal included by the approved card target basket.

**Explicitly NOT for:**
- Non-DWX symbols - registry and pipeline use `.DWX` backtest symbols only.
- Symbols not listed in `framework/registry/dwx_symbol_matrix.csv` - not valid for this build.

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
| Trades / year / symbol | `80` |
| Typical hold time | Up to 16 completed H4 bars, about 64 trading hours before fallback time stop. |
| Expected drawdown profile | Reversal system with ATR catastrophic stop and no take profit; drawdown controlled by fixed-risk sizing. |
| Regime preference | Trend-reversal / semaphore-signal regimes. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** MQL5 CodeBase article "Exp_BuySell - expert for MetaTrader 5", code 1109.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10611_mql5-buysell.md`

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
| v1 | 2026-05-31 | Initial build from card | 33a604a1-850d-4a51-98f0-30db16d34396 |
