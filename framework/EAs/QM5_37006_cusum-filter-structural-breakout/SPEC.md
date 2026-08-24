# QM5_37006_cusum-filter-structural-breakout — Strategy Spec

**EA ID:** QM5_37006
**Slug:** `cusum-filter-structural-breakout`
**Source:** `cusum-filter-structural-breakout-official-source` (see `strategy-seeds/sources/cusum-filter-structural-breakout-official-source/`)
**Author of this spec:** Research+Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Implements the symmetric Cumulative Sum (CUSUM) quality-control filter described by Marcos López de Prado (2018). Computes rolling price differences on closed M15 bars and accumulates the centered return $\Delta P_t - \mathrm{mean}(\Delta P, 50)$ in $S^+$ and $S^-$. When $S^+$ exceeds a dynamic volatility threshold $h = 1.50 \times \text{std}(\Delta P, 50)$, a long position is initiated. When $S^-$ drops below $-h$, a short position is initiated. Initial stop loss is set at $1.5 \times \text{ATR}(14)$ and take profit at $2.0 \times \text{SL\_Distance}$ (1:2.0 Risk-Reward). CUSUM accumulators reset only after the framework confirms trade execution. Live state is persisted on every processed bar and restart gaps are replayed fail-closed from bounded closed-bar history.

Entry/exit logic is encoded in the five `Strategy_*` hooks in `QM5_37006_cusum-filter-structural-breakout.mq5`. Framework wiring (risk, magic, news, Friday close) is inherited from `QM_Common.mqh` and is not redocumented here.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_window` | 50 | 20 - 100 | Rolling return volatility window in M15 bars |
| `strategy_threshold_h` | 1.50 | 1.0 - 2.5 | Standard deviation multiplier for CUSUM threshold |
| `strategy_atr_period` | 14 | 7 - 30 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.50 | 1.0 - 3.0 | Stop loss ATR multiplier |
| `strategy_tp_rr` | 2.00 | 1.0 - 4.0 | Take profit risk-reward multiplier (1:2.0) |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 3.0 | Spread filter ATR multiplier |
| `strategy_max_slippage_ticks` | 3 | 1 - 3 | Maximum market-order deviation, converted from trade ticks to points |
| `strategy_daily_loss_limit_pct` | 2.0 | (0, 2.0] | Account realized-loss entry halt |
| `strategy_daily_drawdown_hard_stop_pct` | 2.5 | (0, 2.5] | Framework daily equity hard stop |
| `strategy_total_drawdown_stop_pct` | 5.0 | (0, 5.0] | Total drawdown stop from persisted initial equity |
| `strategy_per_trade_risk_cap_pct` | 1.0 | (0, 1.0] | Card maximum percentage risk rail for live mode |
| `strategy_state_rebuild_bars` | 512 | 50 - 4096 | Maximum restart replay gap; a larger gap fails initialization |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` — registered in magic_numbers.csv for this EA (primary index)
- `SP500.DWX` — registered in magic_numbers.csv for this EA (broad equity index)
- `XTIUSD.DWX` — registered in magic_numbers.csv for this EA (crude oil commodity)

**Explicitly NOT for:** any symbol not in the list above (no implicit universe expansion at runtime; the `QM_SymbolGuard` framework helper rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Intraday to multi-session (4-24 hours) |
| Expected drawdown profile | 2.0% realized-loss entry halt, 2.5% daily hard stop, 5.0% total-drawdown stop |
| Regime preference | Mean shifts / structural breakout regimes |
| Win rate target (qualitative) | moderate (50-60%) with 1:2.0 R:R |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `cusum-filter-structural-breakout-official-source`
**Pointer:** `strategy-seeds/sources/cusum-filter-structural-breakout-official-source/`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_37006_cusum-filter-structural-breakout.md`

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
| v1 | 2026-08-18 | Initial build from approved card | fc2c4254-fae3-4ad7-bd0c-c44be30334fb |
| v2 | 2026-08-24 | Review rework | Centered CUSUM recurrence; post-fill reset; loss/slippage rails; durable bounded restart recovery; removed unapproved absolute spread cap |
