# QM5_9919_ff-holo-h1-open-fade-m5 - Strategy Spec

**EA ID:** QM5_9919
**Slug:** `ff-holo-h1-open-fade-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades M5 return-to-level fades around the current broker-day highest and lowest completed H1 opens. After at least three completed H1 bars, a short is signaled when price first trades above the current-day highest H1 open by at least 0.20 ATR(14,M5), then a completed M5 bar closes back below that H1-open level within 12 M5 bars; the long side mirrors this at the current-day lowest H1 open. Initial stops use the larger of 15 pips and 1.2 ATR(14,M5), capped at 2.2 ATR, with XAUUSD using ATR-only stop sizing; targets are the closer of 1.2R and 15 pips, with break-even at +5 pips plus 1 pip and a 24-bar time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for through threshold, stop sizing, and XAUUSD stop distance. |
| `strategy_through_atr_mult` | 0.20 | 0.01-2.00 | Minimum move beyond the H1-open extreme before a retest can signal. |
| `strategy_retest_window_bars` | 12 | 1-100 | Maximum M5 bars between through move and return-close. |
| `strategy_signal_extreme_atr_max` | 1.50 | 0.10-10.00 | Maximum signal-bar excursion beyond the faded H1-open level. |
| `strategy_min_completed_h1_bars` | 3 | 1-24 | Minimum completed current-day H1 opens before trading. |
| `strategy_skip_day_open_minutes` | 90 | 0-360 | No-trade window after broker-day open. |
| `strategy_adr_period_days` | 14 | 2-100 | Completed D1 bars used for ADR filter. |
| `strategy_daily_range_adr_max` | 1.30 | 0.10-5.00 | Blocks new entries once current day range exceeds this ADR multiple. |
| `strategy_fixed_stop_pips` | 15 | 1-500 | Fixed stop floor for non-XAU symbols. |
| `strategy_atr_stop_mult` | 1.20 | 0.10-10.00 | ATR multiple for initial stop. |
| `strategy_atr_stop_cap_mult` | 2.20 | 0.10-10.00 | ATR cap for initial stop. |
| `strategy_tp_rr` | 1.20 | 0.10-10.00 | R-multiple target before fixed-pip cap. |
| `strategy_tp_cap_pips` | 15 | 1-500 | Fixed-pip TP cap. |
| `strategy_be_trigger_pips` | 5 | 1-500 | Profit threshold for break-even move. |
| `strategy_be_buffer_pips` | 1 | 0-100 | Break-even buffer after trigger. |
| `strategy_time_stop_bars` | 24 | 1-500 | Maximum M5 holding time. |
| `strategy_session_close_hour_broker` | 22 | 0-23 | Broker-hour session close used for end-of-session exit. |
| `strategy_session_close_min_broker` | 0 | 0-59 | Broker-minute session close used for end-of-session exit. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - Card R3 names this liquid FX pair for M5 HOLO level-fade testing.
- `GBPUSD.DWX` - Card R3 names this liquid FX pair for M5 HOLO level-fade testing.
- `USDJPY.DWX` - Card R3 names this liquid FX pair for M5 HOLO level-fade testing.
- `XAUUSD.DWX` - Card R3 names gold and includes a specific ATR-only stop convention for XAUUSD.

**Explicitly NOT for:**
- `SP500.DWX` - The card is FX/metals-specific and not an index-card build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `H1` current-day completed opens, `D1` ADR/current-day range |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `120` |
| Typical hold time | Intraday, capped at 24 M5 bars or about 2 hours |
| Expected drawdown profile | Mean-reversion drawdowns during strong breakout days, mitigated by ADR filter |
| Regime preference | Session mean-reversion / intraday level fade |
| Win rate target (qualitative) | Medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `https://www.forexfactory.com/thread/post/8944866`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9919_ff-holo-h1-open-fade-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | 8e98e47a-cd2a-470d-971a-8968d4acc9a7 |
