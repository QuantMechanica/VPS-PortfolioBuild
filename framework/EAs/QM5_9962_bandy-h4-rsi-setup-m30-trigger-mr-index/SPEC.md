# QM5_9962_bandy-h4-rsi-setup-m30-trigger-mr-index - Strategy Spec

**EA ID:** QM5_9962
**Slug:** bandy-h4-rsi-setup-m30-trigger-mr-index
**Source:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016 (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades long-only index mean reversion. On each completed M30 bar it requires the completed H4 RSI(4) to be at or below 30, the completed H4 close to be above the H4 SMA(200), and the completed M30 RSI(2) to be at or below 10. It opens a market long on the next M30 bar with a catastrophic stop 2.5 x ATR(14) on M30 below entry. It exits when the completed M30 RSI(2) reaches 70 or higher, or when the position has been open for 36 M30 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_h4_rsi_period` | 4 | >= 2 | H4 setup RSI period. |
| `strategy_h4_rsi_max` | 30.0 | 0-100 | Maximum H4 RSI value allowed for the long setup. |
| `strategy_h4_sma_period` | 200 | >= 2 | H4 SMA regime period; long entries require H4 close above this SMA. |
| `strategy_m30_rsi_period` | 2 | >= 2 | M30 trigger and exit RSI period. |
| `strategy_m30_rsi_entry_max` | 10.0 | 0-100 | Maximum M30 RSI value allowed for long entry. |
| `strategy_m30_rsi_exit_min` | 70.0 | 0-100 | M30 RSI value that triggers strategy exit. |
| `strategy_atr_period_m30` | 14 | >= 2 | M30 ATR period used for the catastrophic stop. |
| `strategy_atr_sl_mult` | 2.5 | > 0 | ATR multiple for the catastrophic stop distance. |
| `strategy_time_stop_bars` | 36 | > 0 | Maximum hold time measured in M30 bars. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom-symbol proxy named in the card as the primary backtest index.
- `NDX.DWX` - Nasdaq 100 index proxy named in the card as a live-routable US index fallback.
- `WS30.DWX` - Dow 30 index proxy named in the card as a live-routable US index fallback.

**Explicitly NOT for:**
- Non-index FX and commodity symbols - the card is an index mean-reversion sleeve with an H4 long-only equity-index regime filter.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - unavailable or non-canonical S&P 500 variants; the approved custom symbol is `SP500.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | H4 RSI(4), H4 SMA(200), H4 close |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 140 |
| Typical hold time | Up to 36 M30 bars, about 18 trading hours |
| Expected drawdown profile | Mean-reversion drawdowns bounded by 2.5 x M30 ATR catastrophic stop |
| Regime preference | Long-only index mean reversion inside an H4 up-regime |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 9ef19e06-5ca6-5b35-aa06-b8187aa0e016
**Source type:** book
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1, URL: https://books.google.com/books?isbn=9780979103771
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9962_bandy-h4-rsi-setup-m30-trigger-mr-index.md`

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
| v1 | 2026-06-20 | Initial build from card | 4b4666ae-e36a-464a-8c58-7a855f54ad17 |
