# QM5_10547_mql5-macdpat - Strategy Spec

**EA ID:** QM5_10547
**Slug:** `mql5-macdpat`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars by default. It opens long when the selected MACD main line crosses above the MACD signal line and opens short when the main line crosses below the signal line. The P2 baseline applies one simple moving average trend filter: longs require the last closed close above the MA, shorts require it below the MA. Open positions exit on the opposite MACD signal-line cross, or via the framework-managed ATR stop, target, Friday close, and global guards.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for MACD, MA, and ATR reads. |
| `strategy_macd_fast` | `12` | `1+` and below slow period | MACD fast EMA period. |
| `strategy_macd_slow` | `26` | above fast period | MACD slow EMA period. |
| `strategy_macd_signal` | `9` | `1+` | MACD signal smoothing period. |
| `strategy_ma_period` | `200` | `1+` | Simple moving average trend filter period. |
| `strategy_use_ma_filter` | `true` | `true/false` | Enables the P2 baseline MA direction filter. |
| `strategy_use_zero_filter` | `false` | `true/false` | Optional P3 zero-line direction filter, off for P2 baseline. |
| `strategy_atr_period` | `14` | `1+` | ATR period for hard stop sizing. |
| `strategy_atr_sl_mult` | `2.0` | `>0` | ATR multiple used for the hard stop. |
| `strategy_target_r_multiple` | `1.5` | `>0` | Take-profit distance as a multiple of stop risk. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed FX major with native DWX history for MACD and MA testing.
- `GBPUSD.DWX` - card-listed FX major with native DWX history for MACD and MA testing.
- `USDJPY.DWX` - card-listed FX major with native DWX history for MACD and MA testing.
- `XAUUSD.DWX` - card-listed metal with native DWX history for MACD and MA testing.

**Explicitly NOT for:**
- Non-DWX symbols - build and backtest artifacts must use canonical `.DWX` symbols from `dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Intraday to multi-day, depending on the next reverse MACD cross or ATR target/stop. |
| Expected drawdown profile | Moderate trend-following drawdown profile with hard ATR stop per trade. |
| Regime preference | Trend-following MACD crossover with MA direction filter. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** `https://www.mql5.com/en/code/17136`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10547_mql5-macdpat.md`

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
| v1 | 2026-05-29 | Initial build from card | 26ef0167-a0d9-416f-986d-d8848b353efb |
