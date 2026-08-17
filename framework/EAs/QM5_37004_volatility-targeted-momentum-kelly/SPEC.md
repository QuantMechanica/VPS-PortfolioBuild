# QM5_37004_volatility-targeted-momentum-kelly — Strategy Spec

**EA ID:** QM5_37004
**Slug:** `volatility-targeted-momentum-kelly`
**Source:** `volatility-targeted-momentum-kelly-official-source` (see `strategy-seeds/sources/volatility-targeted-momentum-kelly-official-source/`)
**Author of this spec:** Research+Development
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Combines 12-month exponential momentum (252 D1 bars) with a 200-day baseline SMA on closed daily bars. Enters long when 12-month momentum is positive and price is above the 200-day SMA; enters short when 12-month momentum is negative and price is below the 200-day SMA. Uses an initial stop loss of 2.0x ATR(14) and dynamic position management via a 3.0x ATR(14) Chandelier trailing stop.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_37004_volatility-targeted-momentum-kelly.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_days` | 252 | 100 - 300 | Momentum lookback in D1 bars |
| `strategy_sma_period` | 200 | 100 - 250 | Trend baseline SMA period |
| `strategy_atr_period` | 14 | 7 - 30 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 2.00 | 1.0 - 4.0 | Stop loss ATR multiplier |
| `strategy_trail_atr_mult` | 3.00 | 1.5 - 5.0 | Chandelier trailing ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 3.0 | Spread filter ATR multiplier |
| `strategy_max_spread_points` | 300 | 100 - 600 | Absolute spread cap in points |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — registered in magic_numbers.csv for this EA (primary index)
- `NDX.DWX` — registered in magic_numbers.csv for this EA (tech index)
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA (crude oil commodity)
- `XAUUSD.DWX` — registered in magic_numbers.csv for this EA (gold commodity)

**Explicitly NOT for:** any symbol not in the list above (no implicit universe expansion at runtime; the `QM_SymbolGuard` framework helper rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Multi-day to multi-week (5-30 days) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | long/short macro trend |
| Win rate target (qualitative) | high (60-70%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `volatility-targeted-momentum-kelly-official-source`
**Pointer:** `strategy-seeds/sources/volatility-targeted-momentum-kelly-official-source/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_37004_volatility-targeted-momentum-kelly.md`

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
| v1 | 2026-08-17 | Initial build from approved card | 6d2369c0-a412-427e-afab-8c5feed10cc3 |
