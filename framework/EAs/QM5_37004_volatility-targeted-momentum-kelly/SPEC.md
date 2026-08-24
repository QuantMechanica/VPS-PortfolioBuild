# QM5_37004_volatility-targeted-momentum-kelly — Strategy Spec

**EA ID:** QM5_37004
**Slug:** `volatility-targeted-momentum-kelly`
**Source:** `volatility-targeted-momentum-kelly-official-source` (see `strategy-seeds/sources/volatility-targeted-momentum-kelly-official-source/`)
**Author of this spec:** Research+Development
**Last revised:** 2026-08-24

---

## 1. Strategy Logic

Combines exponentially weighted log-return momentum over 252 closed D1 bars with a 200-day baseline SMA. The exponential span uses `alpha = 2 / (momentum_days + 1)`, with the newest closed-bar return receiving the highest weight. It enters long when momentum is positive and price is above the 200-day SMA; it enters short when momentum is negative and price is below the SMA. The initial stop is 2.0x ATR(14), and open risk is managed every tick with a 3.0x ATR(14) Chandelier trail.

Position weight follows the card formula: 20-day sample volatility is annualized by `sqrt(252)`, inverse-volatility scaling targets 10%, and that scale is multiplied by half Kelly using the card's 68.5% win-rate and 2.5 payoff priors. The resulting weight scales `RISK_FIXED` in backtests and `RISK_PERCENT` in live mode through the framework's explicit risk-mode overload.

Entry/exit logic is encoded in the `Strategy_*` hooks in `QM5_37004_volatility-targeted-momentum-kelly.mq5`. Framework wiring (magic, news, Friday close, MAE, and risk sizing) remains in the `QM_Common.mqh` chain.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_vol_target_pct` | 10.0 | 5.0 - 15.0 | Annualized volatility target |
| `strategy_momentum_days` | 252 | 100 - 300 | Exponential momentum span in D1 returns |
| `strategy_kelly_fraction` | 0.50 | 0.25 - 0.75 | Fraction applied to full Kelly |
| `strategy_base_risk_percent` | 0.50 | 0.20 - 1.00 | Card live-risk ceiling and per-trade cap |
| `strategy_sma_period` | 200 | 100 - 250 | Trend baseline SMA period |
| `strategy_atr_period` | 14 | 7 - 30 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 2.00 | 1.0 - 4.0 | Stop loss ATR multiplier |
| `strategy_trail_atr_mult` | 3.00 | 1.5 - 5.0 | Chandelier trailing ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 3.0 | Spread filter ATR multiplier |
| `strategy_daily_loss_halt_pct` | 2.00 | fixed by card | Account realized-loss entry halt |
| `strategy_daily_hard_stop_pct` | 2.50 | fixed by card | Daily equity hard stop and flatten |
| `strategy_total_dd_halt_pct` | 5.00 | fixed by card | Total drawdown hard stop and flatten |
| `strategy_max_slippage_ticks` | 3.00 | 0 - 3.00 | Maximum market-order deviation in ticks |

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
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Multi-day to multi-week (5-30 days) |
| Expected drawdown profile | bounded by phase risk mode plus the card's 5% total-drawdown hard stop |
| Regime preference | long/short macro trend |
| Win rate target (qualitative) | high (60-70%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `volatility-targeted-momentum-kelly-official-source`
**Approved card:** `strategy-seeds/cards/approved/QM5_37004_volatility-targeted-momentum-kelly.md`
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_37004_volatility-targeted-momentum-kelly.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit`; an unconfigured risk mode is reported by the build contract as `EA_RISK_SIZER_UNCONFIGURED`.

The card-specific capital rails are separate from sizing: a 2.0% account realized-loss halt blocks new entries, the framework kill switch flattens at 2.5% daily equity loss, and a durable kill-switch trip flattens at 5.0% drawdown from initial EA equity.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | 6d2369c0-a412-427e-afab-8c5feed10cc3 |
| v2 | 2026-08-24 | Review rework | Restored exponential momentum, volatility/half-Kelly sizing, card loss rails, and entry-only filter ordering (`rework-37004`) |
