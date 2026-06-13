# QM5_10639_et-macd-xover — Strategy Spec

**EA ID:** QM5_10639
**Slug:** `et-macd-xover`
**Source:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64` (see `strategy-seeds/sources/cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades H1 MACD(12,26,9) signal-line crosses in the direction of a 100/200 SMA trend filter. A long entry requires the completed H1 bar's MACD line to cross above the signal line, close above SMA100, and either SMA100 at or above SMA200 or close above SMA200; shorts mirror that logic below SMA100. Entries are skipped when the current MACD histogram is less than 10% of its 100-bar median absolute histogram, or when spread exceeds 20% of ATR(14). Open trades use a 1.5 ATR initial stop, move to breakeven after +1R, and close on an opposite MACD cross or after 72 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | 1-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 26 | fast+1-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 1-100 | MACD signal smoothing period. |
| `strategy_sma_fast` | 100 | 1-500 | Fast trend SMA used for close filter. |
| `strategy_sma_slow` | 200 | fast+1-1000 | Slow trend SMA used for long-term context. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for stop distance and spread filter. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | Initial stop distance in ATR multiples. |
| `strategy_breakeven_rr` | 1.0 | 0.1-5.0 | R multiple needed before moving stop to breakeven. |
| `strategy_time_exit_bars` | 72 | 1-500 | Maximum H1 bars to hold before strategy close. |
| `strategy_hist_median_bars` | 100 | 3-500 | Lookback for median absolute MACD histogram filter. |
| `strategy_hist_min_fraction` | 0.10 | 0.0-1.0 | Minimum current histogram as fraction of median absolute histogram. |
| `strategy_max_spread_atr_fraction` | 0.20 | 0.0-1.0 | Maximum spread as fraction of ATR(14). |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed DWX forex target for instrument-agnostic MACD testing.
- `GDAXI.DWX` — DAX custom symbol available in the matrix; used as the DWX port for card-listed `GER40.DWX`.
- `XAUUSD.DWX` — card-listed DWX gold target for cross-asset MACD testing.

**Explicitly NOT for:**
- `GER40.DWX` — card-stated name is not present in `framework/registry/dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

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
| Trades / year / symbol | `30` |
| Typical hold time | Up to 72 H1 bars, usually hours to a few days. |
| Expected drawdown profile | Momentum-continuation drawdowns during choppy low-histogram or high-spread regimes. |
| Regime preference | trend / momentum-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64`
**Source type:** forum
**Pointer:** `https://www.elitetrader.com/et/threads/moving-average.173282/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10639_et-macd-xover.md`

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
| v1 | 2026-06-13 | Initial build from card | 3ef4aaac-4d95-49e8-bf8f-91e41ea9a1be |
