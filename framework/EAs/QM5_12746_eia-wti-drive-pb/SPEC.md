# QM5_12746_eia-wti-drive-pb - Strategy Spec

**EA ID:** QM5_12746
**Slug:** `eia-wti-drive-pb`
**Source:** `EIA-WTI-DRIVE-PB-2026`
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency structural WTI sleeve on `XTIUSD.DWX`.
On each new D1 bar it trades only inside the EIA gasoline driving-season window
from April 15 through August 31. It opens long after a short pullback when the
prior D1 close is at or below a 5-day completed-bar low, down at least 0.75%
close-to-close, still above SMA(50), and still below SMA(5). It exits on
rebound to SMA(5), loss of the SMA(50) trend filter, season end, max hold, or
ATR hard stop.

The strategy is intentionally not a duplicate of `QM5_12737_eia-wti-drive`:
that EA buys D1 channel breakouts in the same broad seasonal window. This card
is pullback mean reversion inside the season. It is also not WPSR, hurricane,
refinery, OPEC, expiry, ETF-roll, weekday/month WTI, XTI/XNG, XAU/XAG,
oil/gold, oil/silver, XNG, or RSI commodity logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pullback_lookback` | 5 | 3-8 | Completed D1 bars used for the pullback low |
| `strategy_min_down_return_pct` | 0.75 | 0.50-1.00 | Minimum prior D1 close-to-close drop |
| `strategy_trend_period` | 50 | 40-75 | Slow SMA trend filter |
| `strategy_rebound_period` | 5 | 3-8 | Rebound SMA exit |
| `strategy_atr_period` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 7 | 5-10 | Calendar-day max hold |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude-oil CFD proxy.

**Explicitly NOT for:**
- `XNGUSD.DWX` - current book already has XNG exposure and separate gas cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal exposure is already in the book.
- Equity index symbols - the mission is genuinely different commodity/energy exposure.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 6-12 |
| Typical hold time | 1-7 calendar days |
| Expected drawdown profile | medium-high crude-oil volatility bounded by ATR stop |
| Regime preference | driving-season support with short-term downside pullback |
| Win rate target | medium |

## 6. Source Citation

This card was mechanized from:

**Source ID:** `EIA-WTI-DRIVE-PB-2026`
**Source type:** official government energy research
**Pointer:** `strategy-seeds/sources/EIA-WTI-DRIVE-PB-2026/`
**Primary URL:** `https://www.eia.gov/energyexplained/gasoline/price-fluctuations.php`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial build from card | branch-local build |
