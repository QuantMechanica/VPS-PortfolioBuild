<!--
QuantMechanica V5 — EA Spec Document
Required by Q01 Build & Spec gate (Vault: `03 Pipeline/Q01 Build & Spec.md`)
Validator: `framework/scripts/validate_spec_doc.py`
-->

# QM5_20005_kurisko-quad-rotation-retest — Strategy Spec

**EA ID:** QM5_20005
**Slug:** `kurisko-quad-rotation-retest`
**Source:** `OWNER-DIRECTIVE-2026-07-17_KURISKO-QUADROT` (John Kurisko / DayTradingRadio "Quad Rotation", OWNER mechanization spec 2026-07-17)
**Author of this spec:** Claude
**Last revised:** 2026-07-17

---

## 1. Strategy Logic

Four stochastic oscillators of increasing period (9-3-3, 14-3-3, 44-3-3,
60-10-3) measure momentum stretch on four timescales. The EA first finds a
horizontal consolidation: a box of the last 36 closed M5 bars whose height is
between 0.8x and 3.0x ATR(14). When a closed bar then closes beyond the box
boundary by at least 0.10x ATR, that side is "armed" (long above, short
below) for up to 72 bars. While armed long, the EA maintains a BUY LIMIT
resting exactly at the broken upper boundary — but only on bars where ALL
FOUR stochastic MAIN lines sit below 20 (the "Quad Rotation" oversold
confluence); when the confluence lapses the order is pulled, so a boundary
retest can only fill while structure and momentum agree. Shorts mirror this
(broken lower boundary, all four above 80). There is never more than one
order or position, and never an OCO pair. A long exits at market when the
fastest stochastic (9-3-3) reaches 80 on a closed bar; a short exits when it
reaches 20. Every order carries a fail-safe hard SL (default 2.0x ATR) and TP
(default 4.0x ATR); explicit pip inputs override the ATR derivation. A closed
bar back inside the box beyond its midpoint, or window expiry, disarms the
setup and the scan restarts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_stoch1_k/d/slow` | 9/3/3 | 3-30 | Fast (trigger) stochastic — entry confluence + exit line |
| `strategy_stoch2_k/d/slow` | 14/3/3 | 5-40 | Second stochastic |
| `strategy_stoch3_k/d/slow` | 44/3/3 | 20-80 | Third stochastic |
| `strategy_stoch4_k/d/slow` | 60/10/3 | 30-120 | Slow stochastic (heaviest smoothing) |
| `strategy_zone_oversold` | 20.0 | 5-40 | Oversold threshold (long confluence, short exit) |
| `strategy_zone_overbought` | 80.0 | 60-95 | Overbought threshold (short confluence, long exit) |
| `strategy_range_bars` | 36 | 12-96 | Consolidation box lookback (closed bars, discrete lattice) |
| `strategy_range_min_atr_mult` | 0.8 | 0.3-2.0 | Box height floor vs ATR (kills degenerate boxes) |
| `strategy_range_max_atr_mult` | 3.0 | 1.5-6.0 | Box height ceiling vs ATR (consolidation definition) |
| `strategy_breakout_buffer_atr` | 0.10 | 0.0-0.5 | Close must clear boundary by this x ATR |
| `strategy_retest_window_bars` | 72 | 12-288 | Armed-state lifetime in closed bars |
| `strategy_atr_period` | 14 | 7-30 | ATR period for scaling/stops |
| `strategy_sl_pips` | 0 | 0-10000 | Fail-safe SL distance in pips; 0 = ATR-derived |
| `strategy_tp_pips` | 0 | 0-10000 | Fail-safe TP distance in pips; 0 = ATR-derived |
| `strategy_sl_atr_mult` | 2.0 | 0.5-5.0 | SL = this x ATR when `strategy_sl_pips` = 0 |
| `strategy_tp_atr_mult` | 4.0 | 1.0-10.0 | TP = this x ATR when `strategy_tp_pips` = 0 |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — Kurisko's home market (S&P/US equities); index commission
  class (~$4.4/trade) is benign at M5 cadence.
- `NDX.DWX` — second US large-cap index; same microstructure, live-tradable.
- `WS30.DWX` — third US large-cap index (P2 saturation basket completion).

**Explicitly NOT for:**
- FX pairs — ~$45/round-trip commission kills M5 scalping economics (DL-072
  cost model); the card is an index-scalping mandate (OWNER 2026-07-06
  index/metals-first track).
- `GDAXI.DWX` / `UK100.DWX` — EU session microstructure differs from the US
  cash-session behaviour the methodology was taught on; not in card R3.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none (all four stochastics on PERIOD_CURRENT) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 (declared; quad confluence gates hard) |
| Typical hold time | minutes to hours (fast-stoch rotation exit) |
| Expected drawdown profile | many small stoch-exit wins/losses, occasional 2-ATR SL hits; expected max DD ~15% |
| Regime preference | breakout + pullback-continuation; starves in one-way melt-ups (short side) |
| Win rate target (qualitative) | medium-high (limit fills at structure with momentum exhaustion) |

Behaviour notes (deliberate, reviewed):
- Pending-order maintenance (quad-lapse removal, midpoint invalidation,
  window expiry) advances once per closed bar inside `Strategy_EntrySignal`,
  which sits below the news gate — during a news blackout a resting limit
  stays in the market and may fill (same class as Balke stop orders riding
  through news); management/exits keep running per the 2026-07-02 OnTick
  ordering rule.
- `g_strategy_retest_bars_left` decrements only on bars where the entry path
  runs, so news windows extend the armed window in wall-clock terms —
  deterministic and reproducible.
- Failed indicator reads return 0.0 from the pooled reader; all oversold-side
  checks carry a `k > 0.0` guard so unwarmed buffers can neither arm long
  confluence nor false-trigger the short exit.

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `OWNER-DIRECTIVE-2026-07-17_KURISKO-QUADROT`
**Source type:** OWNER (verbatim mechanization spec, session 2026-07-17), methodology attributed to John Kurisko / DayTradingRadio (URL https://daytradingradio.com)
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_20005_kurisko-quad-rotation-retest.md`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_20005_kurisko-quad-rotation-retest.md`

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
| v1 | 2026-07-17 | Initial build from card | build task cd277cc3-db75-428f-a8fb-25a7320cb393 |
