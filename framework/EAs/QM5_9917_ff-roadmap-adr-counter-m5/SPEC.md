<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_9917_ff-roadmap-adr-counter-m5 — Strategy Spec

**EA ID:** QM5_9917
**Slug:** `ff-roadmap-adr-counter-m5`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Enters a mean-reversion trade after the day's range has completed at least 95% of the 14-day Average Daily Range (ADR) and price has touched or penetrated the ADR boundary level. On the long side, once the ADR low is touched, the EA waits up to 5 M5 bars for a bar to close back above the ADR low. Entry is confirmed by RSI(14) crossing above 35 from below 30 within the last 4 bars, or by the M5 close returning above the 8-period EMA. The short side mirrors this at the ADR high, with RSI crossing below 65 from above 70 or close below EMA(8). An M30 expansion filter suppresses entry if the higher-timeframe M30 is still trending away from the ADR level by more than 1 ATR over the last 3 bars. Stop loss is placed below (long) or above (short) the swing extreme since the touch, buffered by 0.25×ATR(14,M5). Take-profit targets the daily open or 1.4R, whichever is closer; EMA(200,M5) and daily open also trigger exits on bar close. A 36-bar M5 time stop closes the position if neither SL nor TP is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_adr_period` | 14 | 7-21 | ADR lookback in D1 bars |
| `strategy_adr_completion_pct` | 0.95 | 0.80-1.00 | Minimum fraction of ADR reached before entry |
| `strategy_rsi_period` | 14 | 7-21 | RSI period on M5 |
| `strategy_ema_fast` | 8 | 5-13 | Fast EMA period on M5 (reversal confirmation) |
| `strategy_ema_slow` | 200 | 100-300 | Slow EMA period on M5 (TP reference) |
| `strategy_touch_window_bars` | 5 | 2-10 | M5 bars after ADR touch within which reversal must occur |
| `strategy_rsi_window_bars` | 4 | 2-6 | Bars back to check for RSI cross |
| `strategy_entry_buffer_atr` | 0.10 | 0.05-0.20 | Max allowed entry distance beyond ADR (× ATR M5) |
| `strategy_sl_buffer_atr` | 0.25 | 0.10-0.50 | SL buffer beyond swing extreme (× ATR M5) |
| `strategy_sl_min_atr` | 0.70 | 0.50-1.20 | Reject trade if SL < this × ATR M5 |
| `strategy_sl_max_atr` | 2.80 | 1.50-4.00 | Reject trade if SL > this × ATR M5 |
| `strategy_exit_breach_atr` | 0.20 | 0.10-0.40 | Exit on bar close beyond ADR by this × ATR M5 |
| `strategy_time_stop_bars` | 36 | 12-72 | Time stop in M5 bars (3 hours) |
| `strategy_tp_r_multiple` | 1.40 | 1.00-2.50 | Hard TP at this R multiple |
| `strategy_m30_expand_atr` | 1.00 | 0.50-2.00 | M30 expansion filter threshold (× ATR M30) |
| `strategy_session_start_h` | 9 | 7-12 | Session start hour (broker time) |
| `strategy_session_end_h` | 21 | 16-23 | Session end hour (broker time) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — Primary FX liquid pair; active London/NY session, strong ADR patterns
- `GBPUSD.DWX` — Wide ADR, strong mean-reversion tendency after range completion
- `EURJPY.DWX` — Cross with reliable ADR extremes driven by carry flow
- `XAUUSD.DWX` — Gold intraday ADR counter-moves well-documented in Roadmap thread

**Explicitly NOT for:**
- Indices (NDX/WS30/SP500) — ADR counter is FX/metals specific; index patterns differ

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | D1 (ADR / daily open), M30 (expansion filter) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 30 min – 3 hours (up to 36 M5 bars) |
| Expected drawdown profile | Short, bounded by 0.7–2.8 ATR SL; mean-reversion recovery |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** LauraT, "Roadmap - A Way To Read Markets", ForexFactory, 2020, post #790/#791, https://www.forexfactory.com/thread/post/12905491
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9917_ff-roadmap-adr-counter-m5.md`

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
| v1 | 2026-06-11 | Initial build from card | d804e94e-d6c8-49a0-b9e5-6dd366ef2f32 |
