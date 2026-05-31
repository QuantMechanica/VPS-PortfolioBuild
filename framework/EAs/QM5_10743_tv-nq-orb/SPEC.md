# QM5_10743_tv-nq-orb - Strategy Spec

**EA ID:** QM5_10743
**Slug:** tv-nq-orb
**Source:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7 (see TradingView source citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-05-31

---

## 1. Strategy Logic

The EA defines the New York opening range from 09:30 to 09:45 on M5 bars. After that range is complete, it enters long on the first confirmed M5 close above the opening-range high, or short on the first confirmed M5 close below the opening-range low. The opening range must be between 0.25 and 2.50 times ATR(14). The stop is the opposite side of the opening range, the target is 2.0R, and any still-open trade is closed when the New York session reaches 16:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_ny_session_start_hhmm | 930 | 0000-2359 | New York session start used to begin the opening range. |
| strategy_ny_session_end_hhmm | 1600 | 0000-2359 | New York time-flat cutoff and final entry boundary. |
| strategy_opening_range_minutes | 15 | >=1 | Minutes from session start used for the opening range. |
| strategy_atr_period | 14 | >=1 | ATR period for opening-range height validation. |
| strategy_min_range_atr_mult | 0.25 | >0 | Minimum opening-range height as a multiple of ATR(14). |
| strategy_max_range_atr_mult | 2.50 | >0 | Maximum opening-range height as a multiple of ATR(14). |
| strategy_tp_rr | 2.00 | >0 | Take-profit distance in R from entry to stop. |
| strategy_max_spread_points | 1000 | >=0 | No-trade spread cap in points; 0 disables the cap. |
| strategy_or_scan_bars | 128 | 4-512 effective | Bounded closed-bar scan used to locate today's opening-range bars. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - direct Nasdaq 100 port for the NQ-origin opening-range breakout.
- WS30.DWX - liquid US large-cap index basket member for P2 saturation.
- GDAXI.DWX - matrix-valid DAX 40 proxy for the card-stated GER40.DWX.
- XAUUSD.DWX - card-approved liquid metals CFD basket member.

**Explicitly NOT for:**
- GER40.DWX - named in the card but absent from `dwx_symbol_matrix.csv`; registered as GDAXI.DWX instead.
- SPX500.DWX, SPY.DWX, ES.DWX - unavailable/non-canonical symbols under DWX discipline.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 100 |
| Typical hold time | Intraday; from post-opening-range entry until 2R/SL or 16:00 New York flat exit. |
| Expected drawdown profile | Breakout losses cluster on false opening-range breaks and range-bound sessions. |
| Regime preference | Volatility-expansion breakout after the New York open. |
| Win rate target (qualitative) | Medium; 2R target allows lower than 50% win rate. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
**Source type:** TradingView script
**Pointer:** TradingView script `NQ Opening Range Breakout`, author handle `blinkzssss`, published 2025-09-26.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10743_tv-nq-orb.md`

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
| v1 | 2026-05-31 | Initial build from card | 1d99b187-a062-4280-a169-0ebcceddcd32 |
