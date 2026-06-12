# QM5_10336_smallcap-volmom - Strategy Spec

**EA ID:** QM5_10336
**Slug:** smallcap-volmom
**Source:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA evaluates each closed M15 bar. It computes a 20-bar close-to-close return and divides it by 20-bar realized volatility from one-bar close returns. It opens long when the score is above 1.00 and short when the score is below -1.00, only after the same-time tick volume is above its 60-session median and current spread is below the rolling 80th percentile. Positions exit after 4 M15 bars, when the score crosses zero against the position, or when the configured cash-session window ends.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_momentum_lookback | 20 | 2-200 bars | Lookback for close-to-close momentum return. |
| strategy_realized_vol_lookback | 20 | 2-200 bars | Lookback for realized volatility of one-bar returns. |
| strategy_mom_threshold | 1.00 | 0.10-5.00 | Absolute momentum score threshold for long or short entry. |
| strategy_volume_sessions | 60 | 1-60 sessions | Same-time M15 tick-volume samples used for median liquidity filter. |
| strategy_spread_lookback | 80 | 1-128 bars | Rolling spread samples used for percentile filter. |
| strategy_spread_percentile | 80.0 | 1-100 | Maximum rolling spread percentile allowed for entry. |
| strategy_atr_period | 14 | 2-100 bars | ATR period for stop distance. |
| strategy_atr_sl_mult | 1.00 | 0.10-10.00 | ATR multiple for stop loss. |
| strategy_min_stop_spreads | 4.00 | 1-20 spreads | Minimum stop distance as a multiple of current spread. |
| strategy_max_hold_bars | 4 | 1-96 bars | Maximum holding time in M15 bars. |
| strategy_session_start_hhmm | 1530 | 0000-2359 | Broker-time cash-session start gate. |
| strategy_session_end_hhmm | 2200 | 0000-2359 | Broker-time cash-session end gate. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 index proxy named in the card; valid backtest-only custom symbol.
- NDX.DWX - Nasdaq 100 index proxy named in the card and available in the DWX matrix.
- WS30.DWX - Dow 30 index proxy named in the card and available in the DWX matrix.
- GDAXI.DWX - DWX matrix canonical DAX symbol used for the card's GER40.DWX target.

**Explicitly NOT for:**
- GER40.DWX - Not present in `framework/registry/dwx_symbol_matrix.csv`; mapped to GDAXI.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through framework `OnTick` entry gating |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | 4 M15 bars, about 1 hour, or earlier on zero-cross/session exit |
| Expected drawdown profile | Intraday ATR-stopped index momentum losses during choppy low-liquidity regimes |
| Regime preference | Intraday volatility-scaled momentum with liquidity confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** fd8c6a44-7c20-5e45-a7a8-c6a595ac47a9
**Source type:** paper
**Pointer:** SSRN abstract 5921742, Sandip Poudel, "Small-Cap Stock Trading Strategies for Retail Traders"
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10336_smallcap-volmom.md`

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
| v1 | 2026-06-13 | Initial build from card | 31ea8460-5b3c-4fd0-8d33-85410f9dec65 |
