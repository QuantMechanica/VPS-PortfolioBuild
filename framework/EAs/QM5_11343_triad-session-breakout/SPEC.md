# QM5_11343_triad-session-breakout - Strategy Spec

**EA ID:** QM5_11343
**Slug:** triad-session-breakout
**Source:** 581facd5-aecc-5b86-8121-1eaa3eaf1a45
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

The EA trades H1 breakouts during the first three bars after configured major FX session opens. For the conservative P2 variant, it builds the prior in-session high and low from bars since the session start, then buys when the latest closed H1 bar breaks above that prior session high or sells when it breaks below that prior session low. The P2 stop is fixed at 10 pips, the take-profit is fixed at 12 pips, and any still-open position is closed once the entry bar has completed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_est_to_broker_offset_hours | 7 | -23 to 23 | Converts the card's EST session-open hours into broker-hour session starts. |
| strategy_trade_asian_session | false | true/false | Enables the 7pm EST Asian session breakout window. |
| strategy_trade_european_session | false | true/false | Enables the 2am EST European session breakout window. |
| strategy_trade_london_session | true | true/false | Enables the 3am EST London session breakout window. |
| strategy_trade_ny_session | true | true/false | Enables the 8am EST New York session breakout window. |
| strategy_signal_valid_bars | 3 | 1 to 6 | Number of H1 bars after session open where breakout entries are allowed. |
| strategy_tp_pips | 12 | 1 to 100 | Fixed take-profit distance in pips. |
| strategy_sl_pips | 10 | 1 to 100 | Fixed stop-loss distance in pips. |
| strategy_spread_cap_pips | 3.0 | 0.1 to 20.0 | Maximum allowed spread before new entries are suppressed. |
| strategy_min_session_range_pips | 5.0 | 0.0 to 100.0 | Minimum prior session high-low range required before a breakout can trade. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid FX pair with H1 DWX data.
- GBPUSD.DWX - card-listed liquid FX pair with H1 DWX data.
- GBPJPY.DWX - card-listed active session-breakout FX cross with H1 DWX data.
- USDJPY.DWX - card-listed liquid FX pair with H1 DWX data.

**Explicitly NOT for:**
- Non-DWX symbols - V5 backtests require the canonical `.DWX` symbol matrix.
- Indices, metals, and energy symbols - the approved card lists FX instruments only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 300 |
| Typical hold time | One H1 entry bar unless SL or TP is hit first |
| Expected drawdown profile | Short-hold breakout losses bounded by fixed 10-pip stops |
| Regime preference | Session-open volatility expansion and directional breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 581facd5-aecc-5b86-8121-1eaa3eaf1a45
**Source type:** book / PDF
**Pointer:** Jason Fielder, Triad Cheat Sheets, Cheat Sheet #2 - Session Open Breakout Scalping, local PDF `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\254938836-TriadCheatSheets-pdf.pdf`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11343_triad-session-breakout.md`

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
| v1 | 2026-06-08 | Initial build from card | 33dd6d28-e60f-4fb3-b23c-e0ba56f1e0da |
