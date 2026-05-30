# QM5_10407_et-macd-zero - Strategy Spec

**EA ID:** QM5_10407
**Slug:** `et-macd-zero`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-25

---

## 1. Strategy Logic

The EA trades M5 index CFDs when the MACD main line crosses the zero line. It opens long when MACD(12,26,9) crosses from zero or below to above zero, and opens short when it crosses from zero or above to below zero. Open positions close on the opposite MACD zero-line cross, at the end of the configured liquid session, or after 36 bars when open profit remains below 0.25R. Each entry receives a protective stop at 1.5 x ATR(20).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_macd_fast` | 12 | 1-100 | Fast EMA period for MACD main line. |
| `strategy_macd_slow` | 26 | 2-200 | Slow EMA period for MACD main line; must exceed fast period. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal period used by the platform MACD calculation. |
| `strategy_atr_period` | 20 | 1-200 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the initial protective stop. |
| `strategy_session_end_hhmm` | 2100 | 0-2359 | Broker-time HHMM when open trades are flattened. |
| `strategy_time_stop_bars` | 36 | 0-500 | Bars held before the low-profit time stop can close a trade. |
| `strategy_time_stop_min_r` | 0.25 | 0.0-5.0 | Minimum open profit in R required to avoid the time stop. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol matching the ES/SPX-style index exposure from the source.
- `NDX.DWX` - Nasdaq 100 index CFD in the approved US large-cap basket.
- `WS30.DWX` - Dow 30 index CFD in the approved US large-cap basket.
- `GDAXI.DWX` - verified DAX custom symbol used as the DWX matrix equivalent for the card's `GER40.DWX`.

**Explicitly NOT for:**
- `GER40.DWX` - card-stated symbol is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable S&P variants; `SP500.DWX` is the canonical custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `minutes to a few hours; optional stop after 36 M5 bars` |
| Expected drawdown profile | `High whipsaw sensitivity in sideways sessions because no trend filter is active.` |
| Regime preference | `trend-following` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/simple-mechanical-system.165101/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10407_et-macd-zero.md`

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
| v1 | 2026-05-25 | Initial build from card | c4a89a37-c09b-4aac-b67b-af0378d36880 |
