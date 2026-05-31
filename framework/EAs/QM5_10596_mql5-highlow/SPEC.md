# QM5_10596_mql5-highlow - Strategy Spec

**EA ID:** QM5_10596
**Slug:** mql5-highlow
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

This EA trades the HighsLowsSignal star rule on completed H4 bars. A bullish star occurs when the configured count of recent closed bars has both higher highs and higher lows; a bearish star occurs when the configured count has both lower highs and lower lows. The EA opens long on a bullish star and short on a bearish star, exits on the opposite star, and uses a fallback time stop after 16 completed H4 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_how_many_candles` | 3 | 1-20 | Number of directed candles required for a bullish or bearish HighsLowsSignal star. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | 0.1-20.0 | ATR multiple used to place the catastrophic stop from entry. |
| `strategy_max_hold_bars` | 16 | 1-200 | Maximum completed H4 bars to hold before the fallback time stop closes the trade. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `AUDUSD.DWX` - primary source analog from the published AUDUSD H4 test.
- `EURUSD.DWX` - major FX pair suitable for OHLC-derived H4 price-action signals.
- `GBPUSD.DWX` - major FX pair suitable for OHLC-derived H4 price-action signals.
- `USDJPY.DWX` - major FX pair suitable for OHLC-derived H4 price-action signals.

**Explicitly NOT for:**
- Non-DWX symbols - pipeline and backtest artifacts must use canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 |
| Typical hold time | Up to 16 completed H4 bars by fallback time stop |
| Expected drawdown profile | Stop-defined directional price-action reversals with fixed-risk backtest sizing |
| Regime preference | Closed-bar directional high-low continuation and reversal regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase
**Pointer:** https://www.mql5.com/en/code/2314 and `artifacts/cards_approved/QM5_10596_mql5-highlow.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10596_mql5-highlow.md`

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
| v1 | 2026-05-31 | Initial build from card | b8bf9e34-7ddc-430c-a2db-e91b4e55be52 |
