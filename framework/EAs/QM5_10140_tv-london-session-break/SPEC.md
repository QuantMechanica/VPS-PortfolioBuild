# QM5_10140_tv-london-session-break - Strategy Spec

**EA ID:** QM5_10140
**Slug:** `tv-london-session-break`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

The EA trades the first M5 close that breaks the New York-time London session range. It builds the range from 03:00 through 09:00 NY time using the complete M5 high-low window, then allows entries only from 09:30 through 11:00 NY time. A long opens when the first eligible M5 candle closes above the range high; a short opens when the first eligible M5 candle closes below the range low. The stop is placed beyond the breakout candle by the larger of 0.25 ATR(M5) or five symbol ticks, the take profit is 2R, and any open trade is closed after the entry window plus the configured grace period.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | `1+` | ATR period used for the DWX CFD stop buffer. |
| `strategy_atr_stop_mult` | 0.25 | `>0` | ATR multiple compared against the minimum tick buffer. |
| `strategy_reward_r_multiple` | 2.0 | `>0` | Take-profit distance as an R multiple from entry to stop. |
| `strategy_min_stop_ticks` | 5 | `1+` | Minimum stop buffer in symbol ticks beyond the breakout candle. |
| `strategy_range_start_hhmm` | 300 | `0000-2359` | NY-time start of the London range window. |
| `strategy_range_end_hhmm` | 900 | `0000-2359` | NY-time end of the London range window. |
| `strategy_entry_start_hhmm` | 930 | `0000-2359` | NY-time start of the breakout entry window. |
| `strategy_entry_end_hhmm` | 1100 | `0000-2359` | NY-time end of the breakout entry window. |
| `strategy_exit_grace_minutes` | 15 | `0+` | Minutes after the entry window before time exit closes open trades. |
| `strategy_range_scan_bars` | 220 | `100+` | M5 closed bars scanned to reconstruct the same-day range. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - primary Nasdaq 100 port for the source's NQ-style extended-hours breakout.
- `SP500.DWX` - S&P 500 analog from the approved R3 basket; backtest-only custom symbol.
- `WS30.DWX` - Dow 30 analog from the approved R3 basket for a second live-tradable US index.

**Explicitly NOT for:**
- Any symbol outside the three registered US index symbols above - the card does not approve forex, commodities, or non-US index expansion for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday; usually minutes to about 105 minutes, capped by the 11:15 NY default time exit. |
| Expected drawdown profile | Breakout system with fixed 1R stop and 2R target; losing streaks expected during non-expansion sessions. |
| Regime preference | Volatility-expansion / session-breakout conditions after the London range completes. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `London Session Breakout - Joovier Gems`, author handle `EddyPips`, published 2026-05-18.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10140_tv-london-session-break.md`

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
| v1 | 2026-06-20 | Initial build from card | 70d1bf1a-b6fa-4f08-be13-1595e5b75732 |
