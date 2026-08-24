# QM5_37003_hurst-exponent-dynamic-regime-switch — Strategy Spec

**EA ID:** QM5_37003
**Slug:** `hurst-exponent-dynamic-regime-switch`
**Source:** `hurst-exponent-dynamic-regime-switch-official-source` (see `strategy-seeds/sources/hurst-exponent-dynamic-regime-switch-official-source/`)
**Author of this spec:** Codex
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Calculates the rolling Rescaled Range Hurst exponent as `H = ln(R/S) / ln(n)` from closed H1 log returns over 100 bars. When H > 0.55, a close beyond the preceding 20-bar high or low opens a trend trade with a 1.5x ATR initial stop and a 2.0R take profit. When H < 0.45, a close at or beyond the 20-bar, 2.0-deviation Bollinger Band opens a mean-reversion trade with the same ATR stop and the Bollinger midline as its target.

Mean-reversion entries fail closed when the current Bollinger midline is not a valid favorable-side target; no fixed-R substitute is authorized. Open-position midline management runs before entry-only rollover/spread/loss filters. Account risk rails are a 2.0% closed-PnL entry halt, restart-safe 2.5% daily equity hard stop, and 5.0% account-level total-DD signal threshold.

The approved card does not state Bollinger period/deviation values, so the build exposes the conventional 20-bar/2.0-deviation definition explicitly in source and every governed setfile. The lifecycle diagram names break-even and trailing transitions but supplies no trigger distances; those illustrative transitions are therefore not activated. The executable exit contract is the card's Section 3.4 broker-side ATR stop plus trend 2.0R or mean-reversion midline target.

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
| `strategy_daily_loss_halt_pct` | 2.0 | fixed | Account realized-loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.5 | fixed | Framework daily equity hard stop |
| `strategy_total_dd_halt_pct` | 5.0 | fixed | Account-level total-DD signal threshold |
| `strategy_per_trade_risk_cap_pct` | 0.5 | fixed | Framework per-trade risk cap |
| `strategy_max_slippage_ticks` | 3.0 | 0 - 3.0 | Maximum market-order slippage in symbol ticks |

`RISK_PERCENT` remains a framework input rather than a duplicate strategy input. Zero is required for backtests; when selected by a live preset, this EA additionally enforces the card's declared 0.20%-1.00% range.

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
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 70 (`expected_trades_per_year_per_symbol`) |
| Expected trade frequency | 80-160 high-conviction trades per year (`expected_trade_frequency`) |
| Typical hold time | Not specified in the approved card |
| Expected drawdown profile | 15% ordering prior (`expected_dd_pct`); runtime hard stops remain 2.5% daily and 5.0% total |
| Regime preference | Dual regime: trend-following above the high-Hurst threshold and mean-reverting below the low-Hurst threshold |
| Win rate target (qualitative) | Not accepted as a gate target; the source claim is ignored per the G0 reasoning |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `hurst-exponent-dynamic-regime-switch-official-source`
**Source type:** verified quantitative model / book lineage
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_37003_hurst-exponent-dynamic-regime-switch.md`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_37003_hurst-exponent-dynamic-regime-switch.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`; the static build gate reports an unconfigured risk path as `EA_RISK_SIZER_UNCONFIGURED`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-24 | Initial build from card | 10fc0415-d492-4f6d-aec3-744819207eb9 |
