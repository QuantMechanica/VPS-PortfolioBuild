# QM5_11749_london-breakfast-asia-box-breakout - Strategy Spec

**EA ID:** QM5_11749
**Slug:** london-breakfast-asia-box-breakout
**Source:** a9d18254-30e7-52b3-8381-990257e0931e (see local source PDF `423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA builds an Asia session box from M15 bars between 00:00 and 07:00 UTC. From 07:00 UTC onward it waits for the first closed M15 bar of the day whose close is above the Asia high or below the Asia low. A close above the box opens a buy at the next bar's first available market price; a close below opens a sell. The stop is the opposite side of the breakout candle, the take-profit is 40 pips from entry, and any remaining position is closed at the London session cutoff.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_asia_start_hour_utc` | 0 | 0-23 | UTC hour when Asia-box collection starts. |
| `strategy_asia_end_hour_utc` | 7 | 1-24 | UTC hour when Asia-box collection ends; bars at this hour are excluded. |
| `strategy_breakout_start_hour_utc` | 7 | 0-23 | UTC hour when closed-bar breakout detection begins. |
| `strategy_session_cutoff_hour_utc` | 16 | 1-24 | UTC hour when open positions are closed and new entries stop. |
| `strategy_take_profit_pips` | 40 | 1+ | Fixed take-profit distance from market entry. |
| `strategy_history_bars_m15` | 96 | 32-192 enforced | Bounded M15 bar window used for same-day box and breakout scan. |
| `strategy_min_asia_bars` | 20 | 1+ | Minimum count of M15 Asia bars required before a box is valid. |
| `strategy_max_spread_points` | 0 | 0+ | Optional spread block; 0 disables the spread cap. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - card primary Cable market and present in the DWX forex matrix.
- `GBPJPY.DWX` - card-listed London-session forex cross and present in the DWX forex matrix.
- `EURUSD.DWX` - card-listed major FX pair with liquid London-session data.
- `USDJPY.DWX` - card-listed major FX pair with liquid London-session data.
- `AUDUSD.DWX` - card-listed major FX pair and present in the DWX forex matrix.

**Explicitly NOT for:**
- Index, metal, and energy `.DWX` symbols - the source describes a forex London-open Asia-box breakout, not CFD index or commodity sessions.
- FX symbols outside the registered set - they were not listed by the approved card for P2 saturation.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Expected trade frequency | One possible trade per day, first London-breakout only; card describes about 50 trades/year/symbol. |
| Typical hold time | Intraday, from London breakout until TP, SL, or same-day cutoff. |
| Expected drawdown profile | Breakout-loss clusters during false London breaks and low follow-through sessions. |
| Regime preference | Momentum breakout / volatility expansion after the Asia range. |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** a9d18254-30e7-52b3-8381-990257e0931e
**Source type:** local PDF / strategy article
**Pointer:** `423041768-London-Free-Breakfast-Forex-Trading-Strategy-1.pdf`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11749_london-breakfast-asia-box-breakout.md`

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
| v1 | 2026-06-11 | Initial build from card | 7e4afeb3-ed2a-4ead-a7e5-8f4c149a8d98 |

