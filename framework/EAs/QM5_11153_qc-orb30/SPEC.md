# QM5_11153_qc-orb30 - Strategy Spec

**EA ID:** QM5_11153
**Slug:** qc-orb30
**Source:** 039cc5bd-2d25-557d-8315-43be9f1ea5a2 (see `strategy-seeds/sources/039cc5bd-2d25-557d-8315-43be9f1ea5a2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-26

---

## 1. Strategy Logic

The EA builds the high and low of the first 30 minutes after the US index cash-session analogue opens on the broker clock. After that range is sealed, it enters long when a closed M1 bar closes above the range high, or short when a closed M1 bar closes below the range low. Only one entry is allowed per symbol and session. The position is closed by the scheduled 13:30 New York equivalent, by the 210-minute hold fallback, or by the emergency session-end close if the scheduled exit was missed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `session_open_minute_broker` | 990 | 0-1439 | Broker-time minute of the US index cash-session open, 16:30 broker. |
| `range_minutes` | 30 | 1-240 | Number of minutes used to build the opening range. |
| `exit_minute_broker` | 1230 | 0-1439 | Broker-time minute for scheduled liquidation, 20:30 broker. |
| `hold_minutes_max` | 210 | 1-720 | Fallback maximum hold in minutes after session open. |
| `session_end_minute_broker` | 1320 | 0-1439 | Broker-time emergency close window, 22:00 broker. |
| `atr_period` | 14 | 2-100 | M30 ATR period used for the range cap and stop buffer. |
| `stop_buffer_atr_mult` | 0.10 | 0.0-5.0 | ATR fraction added beyond the opposite side of the opening range. |
| `stop_range_mult` | 1.00 | 0.1-5.0 | P3 sweep parameter for widening the opening-range stop distance. |
| `range_atr_cap_mult` | 1.50 | 0.1-10.0 | Skip ranges wider than this multiple of M30 ATR. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 custom symbol maps the source equity ORB concept to the broad US large-cap cash-session structure.
- `NDX.DWX` - Nasdaq 100 provides a liquid US index analogue with the same cash-session opening-range behaviour.
- `WS30.DWX` - Dow 30 provides the third portable US large-cap index analogue from the approved R3 basket.

**Explicitly NOT for:**
- Non-US cash-session symbols - the broker-time open and close inputs are calibrated for the US index session, not London, Frankfurt, Tokyo, or 24-hour FX sessions.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | `PERIOD_M30` ATR(14) for range cap and stop buffer |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the V5 skeleton entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 110 |
| Typical hold time | Intraday, from post-opening-range breakout until 13:30 New York equivalent or 210-minute fallback |
| Expected drawdown profile | Fixed-risk intraday breakout drawdown, controlled by the opposite-side opening-range stop |
| Regime preference | Breakout / intraday momentum |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 039cc5bd-2d25-557d-8315-43be9f1ea5a2
**Source type:** forum / educational boot camp mirror
**Pointer:** QuantConnect Boot Camp, "Opening Range Breakout"; Greg Kendall forum mirror at `https://www.quantconnect.com/forum/discussion/10724/boot-camp-5-opening-range-breakout-all-text-and-code/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11153_qc-orb30.md`

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
| v1 | 2026-06-26 | Initial build from card | aab09037-f1cf-46ed-9209-057bd2e61fa1 |
