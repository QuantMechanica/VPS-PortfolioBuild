# QM5_9930_ff-hline-do-breakout-m30 - Strategy Spec

**EA ID:** QM5_9930
**Slug:** ff-hline-do-breakout-m30
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

At the broker daily open, the EA treats the current D1 open as the daily-open horizontal line. On each closed M30 bar during the configured London/New York session window, it buys when the bar closes above daily open plus the symbol offset and sells when the bar closes below daily open minus the offset. The signal bar must have a range of at least 0.40 ATR(14), and the EA permits only one long and one short signal per broker day. Positions exit by SL/TP, a closed M30 recross of the daily open, the end of the configured New York session, or a 16-bar maximum hold.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period for XAU offset, SL sizing, and signal-range filter. |
| `strategy_fx_offset_pips` | 10 | 1-100 | Daily-open breakout offset for GBPUSD, EURUSD, and USDJPY. |
| `strategy_fx_stop_pips` | 11 | 1-200 | Minimum FX stop before ATR floor/cap is applied. |
| `strategy_fx_tp_pips` | 20 | 1-300 | Fixed FX take-profit candidate compared with 1.4R. |
| `strategy_xau_offset_atr_mult` | 0.35 | 0.05-5.00 | XAUUSD daily-open breakout offset as ATR multiple. |
| `strategy_xau_sl_atr_mult` | 1.00 | 0.10-5.00 | XAUUSD stop distance as ATR multiple. |
| `strategy_fx_sl_atr_floor_mult` | 0.80 | 0.10-5.00 | FX stop ATR floor. |
| `strategy_fx_sl_atr_cap_mult` | 1.80 | 0.10-10.00 | FX stop ATR cap. |
| `strategy_signal_range_atr_mult` | 0.40 | 0.00-5.00 | Minimum signal-candle range as ATR multiple. |
| `strategy_reward_r_multiple` | 1.40 | 0.10-10.00 | R-multiple TP candidate and XAUUSD primary TP. |
| `strategy_session_start_hour_broker` | 8 | 0-23 | Broker-hour start of the London/New York entry window. |
| `strategy_session_end_hour_broker` | 22 | 0-23 | Broker-hour end of the New York session and time-stop boundary. |
| `strategy_max_hold_bars` | 16 | 1-96 | Maximum M30 bars to hold a position. |
| `strategy_news_pause_minutes` | 15 | 0-240 | Legacy news pause before and after high-impact scheduled news. |
| `strategy_max_spread_points` | 0 | 0-10000 | Optional spread guard; 0 disables the guard. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Original source pair and explicit card target.
- `EURUSD.DWX` - FX major using the same 10-pip daily-open offset rule.
- `USDJPY.DWX` - FX major using the same 10-pip daily-open offset rule.
- `XAUUSD.DWX` - Explicit card target using ATR-scaled offset and stop rules.

**Explicitly NOT for:**
- `SP500.DWX`, `NDX.DWX`, `WS30.DWX` - Not in the card's R3 basket and not part of this FX/metals daily-open rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `PERIOD_D1` for broker daily open; `PERIOD_CURRENT` for M30 ATR and closed-bar signal checks |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `130` |
| Typical hold time | Intraday; exit at end of New York session or after 16 M30 bars. |
| Expected drawdown profile | Breakout strategy with losses concentrated around failed daily-open breaks. |
| Regime preference | Intraday momentum and volatility-expansion breakout away from broker daily open. |
| Win rate target (qualitative) | Medium. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum
**Pointer:** https://www.forexfactory.com/thread/1311677-horizontal-line-system
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9930_ff-hline-do-breakout-m30.md`

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
| v1 | 2026-06-11 | Initial build from card | 64dc490e-f8b5-4b7c-9663-9e7780320b5c |
