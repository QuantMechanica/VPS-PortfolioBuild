# QM5_10964_ftmo-va-break — Strategy Spec

**EA ID:** QM5_10964
**Slug:** ftmo-va-break
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA builds the prior regular-session value area from M5 tick-volume bars using a 70% volume-area histogram. A setup is valid only when the current session opens inside the prior value area and the prior value-area width is between 1.0 and 4.0 times H1 ATR(14). It records an M30 breakout close beyond the prior VAH or VAL with at least 1.2 times the prior 20-bar average M30 tick volume, then enters at market when price pulls back to the broken value-area boundary within 0.15 ATR(14,M30) and closes back in the breakout direction within the next six M30 bars.

Long stops are the lower of the pullback low and prior VAH minus 0.5 ATR(14,M30). Short stops are the higher of the pullback high and prior VAL plus 0.5 ATR(14,M30). Final TP is fixed at 2.5R, and the EA moves SL to breakeven after a 1.0R touch; it exits any open position at the configured regular-session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_profile_bins` | 48 | 12-96 | Number of price buckets used for the prior-session tick-volume profile. |
| `strategy_value_area_pct` | 70.0 | 50.0-90.0 | Percent of prior-session tick volume included in the value area. |
| `strategy_atr_period` | 14 | 1-200 | ATR period for H1 width filter and M30 pullback/stop distances. |
| `strategy_min_va_width_atr` | 1.0 | >=0.0 | Minimum prior value-area width as a multiple of H1 ATR. |
| `strategy_max_va_width_atr` | 4.0 | >=0.0 | Maximum prior value-area width as a multiple of H1 ATR. |
| `strategy_breakout_vol_mult` | 1.2 | >=0.0 | Required breakout-bar tick volume multiple versus the prior M30 average. |
| `strategy_volume_lookback` | 20 | 1-200 | Number of prior M30 bars used for breakout volume comparison. |
| `strategy_pullback_bars` | 6 | 1-200 | Maximum M30 bars after breakout allowed for pullback entry. |
| `strategy_pullback_atr_mult` | 0.15 | >=0.0 | Pullback tolerance around VAH/VAL as a multiple of M30 ATR. |
| `strategy_sl_atr_mult` | 0.5 | >=0.0 | ATR offset beyond VAH/VAL used in the stop-loss formula. |
| `strategy_final_rr` | 2.5 | >0.0 | Final take-profit multiple of initial risk. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-time hour used as the regular-session start for profile/session state. |
| `strategy_session_end_hour` | 23 | 0-23 | Broker-time hour used as the regular-session end and time-exit trigger. |
| `strategy_max_spread_points` | 0 | >=0 | Optional spread guard in points; 0 disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 index exposure named in the card; valid DWX custom symbol for backtest.
- `NDX.DWX` — Nasdaq 100 index exposure named in the card and present in the DWX matrix.
- `WS30.DWX` — Dow 30 index exposure named in the card and present in the DWX matrix.
- `XAUUSD.DWX` — gold CFD exposure named in the card and present in the DWX matrix.

**Explicitly NOT for:**
- Non-DWX symbols — build and backtest artifacts must use canonical `.DWX` names.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` — these are not the canonical available S&P 500 custom symbol.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | M5 prior-session profile, H1 ATR(14), M30 ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | Intraday; exits no later than configured regular-session end. |
| Expected drawdown profile | Breakout strategy with fixed initial risk, 1R breakeven management, and 2.5R final target. |
| Regime preference | Value-area breakout / volatility expansion after an inside-value session open. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** blog
**Pointer:** FTMO, "Master Volume Profile Trading with the VA Breakout Strategy", 2025-12-07, https://ftmo.com/en/master-volume-profile-trading-with-the-va-breakout-strategy/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10964_ftmo-va-break.md`

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
| v1 | 2026-06-06 | Initial build from card | 773a1239-7c10-49dd-9550-9a53e3e1f454 |
