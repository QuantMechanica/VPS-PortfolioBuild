# QM5_12797_oil-silver-brk - Strategy Spec

**EA ID:** QM5_12797
**Slug:** `oil-silver-brk`
**Source:** `MACROTRENDS-SILVER-OIL-RATIO-2026` (see `strategy-seeds/sources/MACROTRENDS-SILVER-OIL-RATIO-2026/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural commodity relative-value sleeve as
a two-leg basket on `XTIUSD.DWX` and `XAGUSD.DWX`. It computes the D1 log spread
`ln(XTIUSD) - beta * ln(XAGUSD)`, converts it to a rolling z-score, opens a
long-ratio package above +1.75, opens a short-ratio package below -1.75, and
exits both legs when the breakout signal fails or the max hold expires. Each leg
carries an ATR(20) * 3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12606_oil-silver-ratio`:
that EA fades oil/silver z-score extremes. This EA follows relative breakouts.
It is also not a standalone WTI seasonality/news sleeve, an XTI/XNG energy
ratio, an XAU/XAG metals ratio, or an RSI pullback port.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_z_lookback_d1` | 180 | 120-252 | D1 bars used for spread mean and standard deviation |
| `strategy_beta` | 1.0 | 0.8-1.2 | Hedge coefficient in the log spread |
| `strategy_entry_z` | 1.75 | 1.5-2.25 | Absolute z-score threshold for breakout entry |
| `strategy_exit_z` | 0.25 | 0.0-0.5 | Signal-failure threshold for package exit |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 30 | 15-60 | Package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-350 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - host chart and oil numerator, magic slot 0.
- `XAGUSD.DWX` - hedge leg and silver denominator, magic slot 1.
- `QM5_12797_XTI_XAG_BRK_D1` - logical basket symbol for Q02 dispatch.

**Explicitly NOT for:**

- `XNGUSD.DWX` - covered by separate XNG and XTI/XNG sleeves.
- `XAUUSD.DWX` - covered by separate XAU/XAG and oil/gold ratios.
- Equity indices and FX pairs - different economic exposure from oil/silver.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework entry gate |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `7` |
| Typical hold time | `Days to weeks` |
| Expected drawdown profile | `Moderate to high; oil and silver can both gap during macro stress` |
| Regime preference | `oil/silver relative breakout continuation` |
| Win rate target (qualitative) | `medium` |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MACROTRENDS-SILVER-OIL-RATIO-2026`
**Source type:** `market data chart`
**Pointer:** `https://www.macrotrends.net/2612/silver-to-oil-ratio-historical-chart`
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/oil-silver-brk_card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial build from card | Q02 queued |
