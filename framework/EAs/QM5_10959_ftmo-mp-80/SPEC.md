# QM5_10959_ftmo-mp-80 - Strategy Spec

**EA ID:** QM5_10959
**Slug:** ftmo-mp-80
**Source:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA builds the previous regular-session value area from closed M30 bars. It approximates the value area as a 70 percent centered range around the highest tick-volume TPO block's typical price, then waits for the current session to open outside that prior value area and close back inside it for two consecutive M30 blocks. Long entries occur after an open below prior VAL and two closes above VAL; short entries occur after an open above prior VAH and two closes below VAH. The final target is the opposite value-area boundary, TP1 handling occurs when price touches prior POC, and any remaining position is closed at the configured regular-session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_session_start_hour | 16 | 0-23 | Broker-hour start of the regular session used for profile construction. |
| strategy_session_start_minute | 30 | 0-59 | Broker-minute start of the regular session. |
| strategy_session_end_hour | 23 | 0-23 | Broker-hour end of the regular session and time exit. |
| strategy_session_end_minute | 0 | 0-59 | Broker-minute end of the regular session. |
| strategy_profile_lookback_bars | 500 | 120+ | Closed M30 bars copied for prior-session and current-session profile state. |
| strategy_value_area_fraction | 0.70 | 0.01-1.00 | Fraction of prior-session range used as the value-area approximation. |
| strategy_atr_period | 14 | 1+ | ATR period for M30 stop cap and H1 value-width filter. |
| strategy_min_va_width_atr_h1 | 1.0 | 0+ | Minimum previous value-area width as a multiple of H1 ATR. |
| strategy_max_va_width_atr_h1 | 4.0 | 0+ | Maximum previous value-area width as a multiple of H1 ATR. |
| strategy_stop_atr_cap_mult | 1.20 | 0+ | Maximum stop distance as a multiple of M30 ATR. |
| strategy_confirm_blocks | 2 | 1+ | Consecutive M30 closes required after re-entry into value. |
| strategy_tp1_close_percent | 50.0 | 0-99 | Partial-close percent when prior POC is touched. |
| strategy_be_buffer_points | 0 | 0+ | Breakeven stop buffer in raw symbol points after TP1 touch. |
| strategy_max_spread_points | 0 | 0+ | Optional entry spread cap; zero disables the strategy-specific cap. |

---

## 3. Symbol Universe

**Designed for:**
- SP500.DWX - S&P 500 custom symbol included in the approved card basket; backtest-only caveat applies.
- NDX.DWX - Nasdaq 100 index exposure included in the approved card basket.
- WS30.DWX - Dow 30 index exposure included in the approved card basket.
- XAUUSD.DWX - Gold exposure included in the approved card basket.

**Explicitly NOT for:**
- SPX500.DWX - unavailable DWX symbol variant; SP500.DWX is the canonical S&P 500 backtest symbol.
- SPY.DWX - unavailable ETF variant; not present in the DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M30 |
| Multi-timeframe refs | H1 ATR width filter |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) via framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Intraday, from value re-entry confirmation to POC/opposite value boundary or session end |
| Expected drawdown profile | One position per symbol/session with capped ATR stop distance |
| Regime preference | Previous-session value-area mean reversion |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** c11dc4d3-bdfb-5076-aeed-5d943e9ef03f
**Source type:** FTMO blog
**Pointer:** https://ftmo.com/en/blog/market-profile-master-the-80-trading-strategy-hidden-magnets/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10959_ftmo-mp-80.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | 647d5aea-f039-4af6-8ee1-67802b8f3d07 |
