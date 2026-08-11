# QM5_9641_bandy-cci-extreme-fade-mr-index — Strategy Spec

**EA ID:** QM5_9641
**Slug:** `bandy-cci-extreme-fade-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-11

---

## 1. Strategy Logic

Daily-close, long-only mean-reversion fade on US equity indices. On each
closed D1 bar, compute `CCI(20)` (Lambert's classic typical-price formula)
and a `SMA(200)` regime filter. Enter long at next session open when
`CCI(20) <= -100` (deeply oversold) AND `close > SMA(200)` (still in a
long-term uptrend — the regime gate keeps the fade out of bear-market
freefalls). A vol-chaos guard skips new entries when `ATR(14)/close` sits in
the top 1st percentile of the trailing 252 closed D1 bars. Exit on the next
closed bar after `CCI(20) >= 0` (back to the zero line) or after 7 trading
days, whichever comes first. Hard stop at `2.5×ATR(14)` from entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 20 | 14-30 | CCI lookback (Lambert typical-price CCI) |
| `strategy_entry_cci` | -100.0 | -150 to -80 | Entry threshold: CCI must be at/below this |
| `strategy_exit_cci` | 0.0 | -50 to +50 | Exit threshold: CCI zero-line take-profit |
| `strategy_regime_sma_period` | 200 | 100-300 | Long-only regime filter (close > SMA) |
| `strategy_atr_period` | 14 | 10-20 | ATR period for stop-loss and vol-chaos filter |
| `strategy_atr_stop_mult` | 2.5 | fixed | Hard SL distance in ATR multiples |
| `strategy_time_stop_days` | 7 | 5-14 | Max holding period (trading days) before forced exit |
| `strategy_vol_lookback_bars` | 252 | fixed | Lookback window for the vol-chaos percentile filter |
| `strategy_vol_percentile` | 99.0 | fixed | Skip entries when ATR/close sits at/above this percentile |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index CFD; Bandy's original CCI-fade exemplar instrument class
- `NDX.DWX` — Nasdaq 100; live-tradable index CFD with the same daily-bar MR dynamics
- `WS30.DWX` — Dow 30; live-tradable index CFD, completes the US large-cap basket

**Explicitly NOT for:**
- FX pairs / metals / energies — the card's regime asymmetry rationale (equity drawdowns
  vs rallies) is specific to equity indices; not tested on other asset classes

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `7` |
| Typical hold time | `1-7 trading days` |
| Expected drawdown profile | `~18% (card expected_dd_pct)` |
| Regime preference | `mean-revert (uptrend regime only)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** Howard Bandy, "Quantitative Technical Analysis", Blue Owl Press, 2015, ISBN 978-0-9791037-7-1
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9641_bandy-cci-extreme-fade-mr-index.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-11 | Initial build from card | claude-orchestration-3 router task fead18b1 |
