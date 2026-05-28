# QM5_10426_et-seq-break - Strategy Spec

**EA ID:** QM5_10426
**Slug:** `et-seq-break`
**Source:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe` (see `strategy-seeds/sources/d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-27

---

## 1. Strategy Logic

The EA watches completed bars for a repeated close-vs-close lag sequence. A long entry is opened when at least `strategy_sequence_min` prior bars each closed below the close `strategy_close_lag_bars` bars earlier, and the latest completed bar interrupts that downside condition. A short entry mirrors the rule after an upside sequence. Open trades use a fixed ATR stop, a fixed ATR target, a time exit after `strategy_time_exit_bars`, and an opposite sequence interruption exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_sequence_min` | 5 | 1+ | Minimum completed-bar sequence length before an interruption can trigger. |
| `strategy_close_lag_bars` | 3 | 1+ | Close comparison lag used in `Close[bar]` vs `Close[bar + lag]`. |
| `strategy_atr_period` | 20 | 1+ | ATR period used for initial stop and target distances. |
| `strategy_sl_atr_mult` | 1.5 | >0 | Initial stop distance in ATR multiples. |
| `strategy_tp_atr_mult` | 2.0 | >0 | Profit target distance in ATR multiples. |
| `strategy_time_exit_bars` | 10 | 0+ | Maximum holding time in bars; 0 disables the time exit. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major with portable OHLC and ATR history for sequence testing.
- `GBPUSD.DWX` - FX major with portable OHLC and ATR history for sequence testing.
- `XAUUSD.DWX` - liquid metal symbol supported by DWX custom history.
- `SP500.DWX` - S&P 500 custom symbol; valid for backtest use per the DWX matrix.
- `NDX.DWX` - liquid US index proxy supported by DWX custom history.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data set is not canonical for them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | `5-20 H4 bars` |
| Expected drawdown profile | Countertrend entries can draw down in persistent trends; ATR stop and time exit bound each trade. |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe`
**Source type:** `forum`
**Pointer:** `https://www.elitetrader.com/et/threads/a-variation-of-sequential-signal.21633/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10426_et-seq-break.md`

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
| v1 | 2026-05-27 | Initial build from card | 8a1a8f25-c0ca-4365-98de-c6ee2fde6b9e |
