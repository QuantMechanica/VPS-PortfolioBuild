# QM5_12480_gh-shoot-star - Strategy Spec

**EA ID:** QM5_12480
**Slug:** gh-shoot-star
**Source:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a short-only shooting-star reversal on the chart timeframe, intended for D1. It waits for a bearish shooting-star candle after two rising closes, then requires the next completed candle to confirm with a lower or equal high and lower or equal close. A short entry is sent on the next bar, with a 5 percent profit target, a 5 percent stop capped by 3.0 ATR(20) when tighter, and a time stop after 7 base-timeframe bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_lower_bound | 0.2 | greater than 0 | Maximum lower wick size as a multiple of shooting-star body size. |
| strategy_body_size | 0.5 | greater than 0 | Maximum shooting-star body size as a multiple of the 60-bar average body estimate. |
| strategy_stop_threshold_pct | 5.0 | greater than 0 | Symmetric source stop/profit threshold in percent. |
| strategy_holding_bars | 7 | greater than 0 | Maximum holding period in base-timeframe bars. |
| strategy_warmup_bars | 60 | 3 or more | Closed-bar warmup window used for average body estimate. |
| strategy_atr_period | 20 | greater than 0 | ATR period for the emergency loss cap. |
| strategy_atr_stop_mult | 3.0 | greater than 0 | ATR multiple used when tighter than the 5 percent loss stop. |
| strategy_spread_lookback_days | 60 | greater than 0 | D1 closed-bar spread sample for the median-spread entry filter. |
| strategy_spread_median_mult | 2.0 | greater than 0 | Entry is skipped when positive spread exceeds this multiple of the median sample. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Card target; liquid major FX OHLC series suitable for candle reversal tests.
- GBPUSD.DWX - Card target; liquid major FX OHLC series suitable for candle reversal tests.
- USDJPY.DWX - Card target; liquid major FX OHLC series suitable for candle reversal tests.
- XAUUSD.DWX - Card target; liquid metals OHLC series suitable for candle reversal tests.
- NDX.DWX - Card target; liquid index OHLC series suitable for candle reversal tests.
- WS30.DWX - Card target; liquid index OHLC series suitable for candle reversal tests.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available to the DWX tester universe.
- Non-OHLC external macro or alternative-data symbols - the strategy uses only native candle data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 8 |
| Typical hold time | Up to 7 D1 bars |
| Expected drawdown profile | Low-cadence short reversal with gap and continuation risk controlled by fixed percent and ATR-capped stops. |
| Regime preference | Mean-revert bearish reversal after short uptrend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** af7930c8-6c65-52d1-9c01-040490b5ad39
**Source type:** GitHub source code
**Pointer:** https://github.com/je-suis-tm/quant-trading/blob/master/Shooting%20Star%20backtest.py
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12480_gh-shoot-star.md`

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
| v1 | 2026-06-18 | Initial build from card | 3d840d53-eb2c-430d-9ca1-d150bdfcc551 |
