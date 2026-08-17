# QM5_37003_hurst-exponent-dynamic-regime-switch — Strategy Spec

**EA ID:** QM5_37003
**Slug:** `hurst-exponent-dynamic-regime-switch`
**Source:** `hurst-exponent-dynamic-regime-switch-official-source` (see `strategy-seeds/sources/hurst-exponent-dynamic-regime-switch-official-source/`)
**Author of this spec:** Research+Development
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Calculates the rolling Rescaled Range (R/S) Hurst Exponent H on closed H1 bars over a lookback window of 100 bars. When H > 0.55, the market is classified as persistent/trending, activating a 20-bar Donchian channel momentum breakout with 1.5x ATR initial stop and 2.0x R:R take profit. When H < 0.45, the market is classified as anti-persistent/mean-reverting, activating a 20-bar, 2.0-deviation Bollinger Band mean-reversion engine targeting the midline SMA(20) with 1.5x ATR initial stop.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_37003_hurst-exponent-dynamic-regime-switch.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_hurst_lookback` | 100 | 50 - 200 | Hurst R/S lookback bars |
| `strategy_trend_hurst` | 0.55 | 0.52 - 0.65 | Minimum Hurst for trending regime |
| `strategy_revert_hurst` | 0.45 | 0.35 - 0.48 | Maximum Hurst for mean-reversion regime |
| `strategy_donchian_period` | 20 | 10 - 50 | Donchian breakout channel period |
| `strategy_bb_period` | 20 | 10 - 50 | Bollinger Bands period |
| `strategy_bb_dev` | 2.00 | 1.5 - 3.0 | Bollinger Bands deviation |
| `strategy_atr_period` | 14 | 7 - 30 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.50 | 1.0 - 3.0 | Stop loss ATR multiplier |
| `strategy_trend_tp_rr` | 2.00 | 1.0 - 4.0 | Take profit R:R multiplier in trend mode |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 3.0 | Spread filter ATR multiplier |
| `strategy_max_spread_points` | 100 | 50 - 300 | Absolute spread cap in points |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (primary FX target)
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA (high-volatility FX pair)
- `SP500.DWX` — registered in magic_numbers.csv for this EA (liquid equity index)

**Explicitly NOT for:** any symbol not in the list above (no implicit universe expansion at runtime; the `QM_SymbolGuard` framework helper rejects foreign symbols).

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
| Trades / year / symbol | 70 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Intraday to multi-day (4-48 hours) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | dual-regime: trend-following in high-Hurst periods, mean-reverting in low-Hurst periods |
| Win rate target (qualitative) | high (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `hurst-exponent-dynamic-regime-switch-official-source`
**Pointer:** `strategy-seeds/sources/hurst-exponent-dynamic-regime-switch-official-source/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_37003_hurst-exponent-dynamic-regime-switch.md`

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
| v1 | 2026-08-17 | Initial build from approved card | 6b9b31bd-8511-4f7b-8400-9e42162b0bd1 |
