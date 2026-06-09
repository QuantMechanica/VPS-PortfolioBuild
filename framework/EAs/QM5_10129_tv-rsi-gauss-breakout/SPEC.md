# QM5_10129_tv-rsi-gauss-breakout - Strategy Spec

**EA ID:** QM5_10129
**Slug:** `tv-rsi-gauss-breakout`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (TradingView public script page)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades H1 channel breakouts confirmed by RSI. A long signal fires when the last closed bar crosses above the upper channel and RSI(14) is above 50; a short signal fires when the last closed bar crosses below the lower channel and RSI(14) is below 50. The channel uses the card's 144 length and 1.414 multiplier with framework indicator readers, and the protective stop is 2.0 x ATR(14). Long positions close when price crosses back below the channel midline or RSI falls below 50; short positions close when price crosses back above the midline or RSI rises above 50.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | `PERIOD_H1` or `PERIOD_H4` | Timeframe used for channel, RSI, ATR, and closed-bar cross checks. |
| `strategy_rsi_period` | `14` | `2-100` | RSI period used for entry confirmation and midline exits. |
| `strategy_rsi_midline` | `50.0` | `1.0-99.0` | RSI threshold separating long and short confirmation. |
| `strategy_gauss_length` | `144` | `10-400` | Channel midline smoothing length from the card. |
| `strategy_channel_mult` | `1.414` | `0.1-5.0` | ATR channel width multiplier from the card. |
| `strategy_atr_period` | `14` | `2-100` | ATR period used for channel width and protective stop. |
| `strategy_atr_sl_mult` | `2.0` | `0.1-10.0` | Protective stop distance in ATR multiples. |
| `strategy_max_spread_frac` | `0.10` | `0.0-1.0` | Entry skip threshold: spread must be no more than this fraction of ATR stop distance. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card R3 basket FX major with full DWX coverage.
- `GBPUSD.DWX` - card R3 basket FX major with full DWX coverage.
- `XAUUSD.DWX` - card R3 basket gold CFD with full DWX coverage.
- `NDX.DWX` - card R3 basket liquid index CFD with full DWX coverage.

**Explicitly NOT for:**
- Any symbol not listed above - no implicit universe expansion is registered for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | Optional `H4` robustness via `strategy_signal_tf`; default setfiles use `H1`. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `50` |
| Typical hold time | `hours to days, until midline/RSI exit or ATR stop` |
| Expected drawdown profile | `fixed-risk trend breakout drawdowns during range-bound chop` |
| Regime preference | `breakout / trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView public script`
**Pointer:** `https://www.tradingview.com/script/oc2vZUcN-RSI-Gauss-WiP/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10129_tv-rsi-gauss-breakout.md`

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
| v1 | 2026-06-09 | Initial build from card | 4c05f3a7-3fa6-41e0-ac41-0282274308df |
