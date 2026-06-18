# QM5_11889_lien-xtreme-fade-double-bb-adx - Strategy Spec

**EA ID:** QM5_11889
**Slug:** lien-xtreme-fade-double-bb-adx
**Source:** b840c053-5cd2-5e17-b25b-d495e73a33ab (see local PDF archive)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

This EA trades a M15 volatility fade using two Bollinger Band envelopes and an ADX range filter. A short setup requires the previous candle to close at or above the BB(20, 3.0) upper band, then the immediately following candle to close back below the BB(20, 2.0) upper band while ADX(14) is below 25. A long setup mirrors the rule at the lower bands. Entries are market orders on the next M15 bar, with stops 18 pips beyond the Step-1 candle extreme, partial exit at 1R, and the remainder trailed behind M15 fractals.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_bb_period | 20 | 2+ | Bollinger Band period for both inner and outer envelopes |
| strategy_bb_outer_stddev | 3.0 | > inner stddev | Step-1 extreme band deviation |
| strategy_bb_inner_stddev | 2.0 | > 0 | Step-2 re-entry band deviation |
| strategy_adx_period | 14 | 2+ | ADX lookback for range-regime filter |
| strategy_adx_max_for_range | 25.0 | > 0 | Maximum ADX allowed at Step-2 close |
| strategy_sl_pips | 18 | 1+ | Stop buffer beyond the Step-1 swing high or low |
| strategy_rr_target_partial | 1.0 | > 0 | R multiple where half the position is closed |
| strategy_rr_target_full | 2.0 | > 0 | Initial full-position take-profit R multiple |
| strategy_trade_window_utc_start_hhmm | 600 | 0000-2359 | UTC start of permitted trade window |
| strategy_trade_window_utc_end_hhmm | 2000 | 0000-2359 | UTC end of permitted trade window |
| strategy_partial_close_fraction | 0.50 | 0-1 | Fraction closed when the 1R partial target is reached |
| strategy_fractal_shift | 2 | 2+ | M15 fractal shift used to trail the remainder |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid DWX major forex pair named by the card.
- GBPUSD.DWX - liquid DWX major forex pair named by the card.
- USDJPY.DWX - liquid DWX major forex pair named by the card.
- USDCAD.DWX - liquid DWX major forex pair named by the card.
- USDCHF.DWX - liquid DWX major forex pair named by the card.
- AUDUSD.DWX - liquid DWX major forex pair named by the card.
- NZDUSD.DWX - liquid DWX major forex pair named by the card.

**Explicitly NOT for:**
- Non-DWX symbols - the build and pipeline use Darwinex `.DWX` tester symbols.
- JPY crosses outside USDJPY.DWX - the card excludes them from the default list to reduce correlation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday; partial at 1R with remainder trailed behind M15 fractals |
| Expected drawdown profile | Mean-reversion losses cluster when ADX rises into trend conditions |
| Regime preference | mean-reversion / range |
| Win rate target (qualitative) | medium-high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b840c053-5cd2-5e17-b25b-d495e73a33ab
**Source type:** book
**Pointer:** Lien, K. (2011), Battle Tested Forex Trading Strategies, X-Treme Fade chapter slides 50-64. URL: local PDF archive.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11889_lien-xtreme-fade-double-bb-adx.md`

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
| v1 | 2026-06-18 | Initial build from card | 2720e042-b910-49dd-a40a-e7cdfe3c3259 |
