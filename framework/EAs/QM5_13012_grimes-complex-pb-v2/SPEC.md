# QM5_13012_grimes-complex-pb-v2 — Strategy Spec

**EA ID:** QM5_13012
**Slug:** `grimes-complex-pb-v2`
**Source:** `exit-surgery-10911` (Adam Grimes complex consolidation article; surgery evidence from EXIT_SURGERY_SCAN_2026-07-04.md)
**Author of this spec:** Claude
**Last revised:** 2026-07-04

---

## 1. Strategy Logic

Trend-following second-leg pullback continuation on H1 bars. Entry requires: (1) EMA(50) slope positive and price above EMA(50); (2) an impulse thrust bar (range >= 1× ATR14) within the last 20 bars that set a new 20-bar high; (3) a pullback of at least 0.8× ATR14 from the thrust high while staying above EMA(50); (4) a failed first resumption — price breaks above the prior bar high then closes back below the trigger bar low within 5 bars; (5) on the second attempt, price closes above the highest high of the failed resumption leg (entry trigger). Stop below the second pullback swing low minus 0.2× ATR14. Target 1.5R. EMA(20) close-through exits early. v2 surgical change: max-hold ceiling extended from 30 to 60 H1 bars (60h), because the 1-3d hold bucket had 72% WR with TIME_MGMT×29 kills at the 30h ceiling (EXIT_SURGERY_SCAN_2026-07-04.md §3.4).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_trend_period` | 50 | 20-100 | EMA period for trend direction filter |
| `strategy_ema_exit_period` | 20 | 10-50 | EMA period for close-through exit |
| `strategy_atr_period` | 14 | 10-20 | ATR period for thrust/stop sizing |
| `strategy_thrust_lookback_bars` | 20 | 10-40 | Max bars back to search for impulse thrust |
| `strategy_thrust_prior_high_bars` | 20 | 10-40 | Bars before thrust used for new-high confirmation |
| `strategy_thrust_range_atr_mult` | 1.00 | 0.5-2.0 | Min thrust bar range as ATR multiple |
| `strategy_pullback_atr_mult` | 0.80 | 0.5-1.5 | Min pullback depth from thrust high (ATR units) |
| `strategy_failure_window_bars` | 5 | 2-10 | Max bars after failed resumption trigger to see failure close |
| `strategy_min_thrust_to_entry_bars` | 8 | 4-20 | Min bars from thrust to current bar (avoids simple pullback) |
| `strategy_stop_buffer_atr_mult` | 0.20 | 0.1-0.5 | ATR buffer below/above swing low/high for stop |
| `strategy_target_r_mult` | 1.50 | 1.0-3.0 | Risk-reward ratio for take-profit |
| `strategy_max_hold_bars` | 60 | 20-120 | **v2 surgical change** — max H1 bars before forced exit (60h). Parent was 30. |

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — surgery evidence target; H1 trend-following pullbacks on the German DAX 40. Parent QM5_10911 Q08 FAIL_SOFT data is from this symbol.

**Explicitly NOT for (v2 scope):**
- `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX` — parent supports these; v2 restricts to GDAXI to isolate the surgical delta. Future v2-sweep cards may extend to other symbols if GDAXI passes Q08.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 (same as parent; entry mechanics unchanged) |
| Typical hold time | 12-60h (v2 extends ceiling from 30h to 60h) |
| Expected drawdown profile | Moderate; multiple-leg structural filter limits entries |
| Regime preference | Trend-following; requires clear impulse+pullback structure |
| Win rate target (qualitative) | Medium-high; hold-gradient evidence shows 72% WR at 1-3d holds |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `exit-surgery-10911`
**Source type:** Exit-surgery derivation from parent QM5_10911
**Pointer:** `docs/research/EXIT_SURGERY_SCAN_2026-07-04.md` §3.4; parent source: Adam H. Grimes, "How to trade Complex Consolidations", https://www.adamhgrimes.com/trade-complex-consolidations/
**R1–R4 verdict (Q00):** all PASS / see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_13012_grimes-complex-pb-v2.md`

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
| v1 | 2026-07-04 | Exit-surgery from parent QM5_10911; max_hold_bars 30->60 | e731e6b5-1d7d-42c3-935f-7a6885ef56d6 |
