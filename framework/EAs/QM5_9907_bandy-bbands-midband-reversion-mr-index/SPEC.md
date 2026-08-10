# QM5_9907_bandy-bbands-midband-reversion-mr-index — Strategy Spec

**EA ID:** QM5_9907
**Slug:** `bandy-bbands-midband-reversion-mr-index`
**Source:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016` (see `strategy-seeds/sources/9ef19e06-5ca6-5b35-aa06-b8187aa0e016/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Long-only Bollinger-Band mean reversion on D1. On each daily close, the EA
computes a 20-period Bollinger Band (2.0 std-dev) and a 200-period regime SMA.
It goes long at the next bar's open when the just-closed bar's close is below
the lower Bollinger band AND above the 200-SMA regime filter (a pullback
inside an established uptrend, not a trend break). The position exits at the
next bar's open once a closed bar's close reverts to the 20-SMA centerline
(the middle band), or after 7 trading days if the centerline hasn't been
touched (time stop). A 2.0×ATR(14) catastrophic stop sits below entry as a
backstop that is rarely hit because the midband and time-stop exits dominate.
One position per magic; no short side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 15-25 | Bollinger Band SMA/stdev lookback |
| `strategy_bb_std_mult` | 2.0 | 1.5-2.5 | Bollinger Band standard-deviation multiplier |
| `strategy_regime_sma_period` | 200 | 100-300 | Long-term regime filter SMA period |
| `strategy_atr_period` | 14 | fixed | ATR period for the catastrophic stop |
| `strategy_atr_stop_mult` | 2.0 | fixed | ATR multiplier for the catastrophic stop distance |
| `strategy_time_stop_days` | 7 | 5-10 | Trading (D1) days before the time-stop exit fires |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

Which `.DWX` symbols this EA is designed for. Be explicit about both inclusions
and exclusions.

**Designed for:**
- `SP500.DWX` — S&P 500 index CFD; R3 PASS primary backtest instrument, card-cited.
- `NDX.DWX` — Nasdaq 100 index CFD; R3 PASS portable basket member, same D1 index MR profile.
- `WS30.DWX` — Dow 30 index CFD; R3 PASS portable basket member, same D1 index MR profile.

**Explicitly NOT for:**
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not canonical Custom Symbol names; SP500.DWX is the only available S&P 500 alias.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

How this EA should behave in production. Calibrates downstream gate expectations.

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~28 |
| Typical hold time | 1-7 trading days |
| Expected drawdown profile | Shallow, frequent small mean-reversion swings; rare catastrophic-stop tail hits |
| Regime preference | mean-revert (pullback within an established uptrend) |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `9ef19e06-5ca6-5b35-aa06-b8187aa0e016`
**Source type:** `book`
**Pointer:** Howard B. Bandy, "Quantitative Technical Analysis: An Integrated Approach to Trading System Development and Trade Management", Blue Owl Press, 2015, ISBN 9780979183850, https://books.google.com/books/about/Quantitative_Technical_Analysis.html?id=LTJJngEACAAJ
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_9907_bandy-bbands-midband-reversion-mr-index.md`

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
| v1 | 2026-08-10 | Initial build from card | 2c7e29bd-2a1b-4947-b7da-e3c764a8bb5b |

> When this EA cycles back to Q01 from a Q02 zero-trade event, add a row:
> `| v2 | YYYY-MM-DD | Q02 all-symbol zero-trades; widened entry filter X | <commit> |`
