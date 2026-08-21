# QM5_37005_chan-bollinger-adx-mean-reversion — Strategy Spec

**EA ID:** QM5_37005
**Slug:** `chan-bollinger-adx-mean-reversion`
**Source:** `chan-bollinger-adx-mean-reversion-official-source` (see `strategy-seeds/sources/chan-bollinger-adx-mean-reversion-official-source/`)
**Author of this spec:** Research+Development
**Last revised:** 2026-08-18

---

## 1. Strategy Logic

Implements Dr. Ernest P. Chan's classic Bollinger Band mean-reversion model conditioned on an ADX regime filter on closed H1 bars. Only executes when $\text{ADX}(14) < 20.0$, mathematically identifying stationary, non-trending market conditions. Enters long when $\text{Low}[1] \le \text{LowerBB}[1]$ and $\text{Close}[1] > \text{Open}[1]$ (bullish rejection from lower band). Enters short when $\text{High}[1] \ge \text{UpperBB}[1]$ and $\text{Close}[1] < \text{Open}[1]$ (bearish rejection from upper band). Initial stop loss is placed at $1.5 \times \text{ATR}(14)$ and take profit is targeted at the 20-period SMA midline.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_37005_chan-bollinger-adx-mean-reversion.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 14 - 30 | Bollinger Bands period |
| `strategy_bb_dev` | 2.00 | 1.5 - 2.5 | Standard deviation multiplier |
| `strategy_adx_period` | 14 | 7 - 25 | ADX indicator period |
| `strategy_max_adx` | 20.0 | 15.0 - 25.0 | Maximum ADX ranging filter ceiling |
| `strategy_atr_period` | 14 | 7 - 30 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.50 | 1.0 - 3.0 | Stop loss ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 3.0 | Spread filter ATR multiplier |
| `strategy_max_spread_points` | 100 | 50 - 300 | Absolute spread cap in points |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (primary FX major)
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA (secondary FX major)
- `AUDCAD.DWX` — registered in magic_numbers.csv for this EA (cross pair)

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
| Typical hold time | Intraday to multi-day (6-36 hours) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Low ADX / range-bound mean-reversion |
| Win rate target (qualitative) | high (65-75%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `chan-bollinger-adx-mean-reversion-official-source`
**Pointer:** `strategy-seeds/sources/chan-bollinger-adx-mean-reversion-official-source/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_37005_chan-bollinger-adx-mean-reversion.md`

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
| v1 | 2026-08-18 | Initial build from approved card | 98fb1997-3c5d-4bfa-af26-6f46dd7c8a1b |
