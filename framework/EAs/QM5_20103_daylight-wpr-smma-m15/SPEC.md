# QM5_20103_daylight-wpr-smma-m15 - Strategy Spec

**EA ID:** QM5_20103
**Slug:** `daylight-wpr-smma-m15`
**Source:** FF-LAURAT-DAYLIGHT-1086170 (see card QM5_20103)
**Author of this spec:** Claude (reconciled with Codex blind spec)
**Last revised:** 2026-07-24

---

## 1. Strategy Logic

M15 indices trend-continuation ("Daylight", LauraT). Green = SMMA(5) of
closes; Red = the same SMMA displaced +5 bars (one unshifted handle read at
shifts 1 and 6). Sub-window: Williams %R(14) smoothed in-EA by SMMA(8) [Red]
and SMMA(21) [Blue], fixed 400-bar seeded recursion. SHORT when, on the
closed bar: Red−Green ≥ 1 tick (main daylight), close < Green, and WPR
SMMA8−SMMA21 ≥ 4.0 (pullback-depth daylight; ledger-bound colour mapping);
LONG mirrors. Entry only on a false→true transition of the full condition
(edge trigger; natural re-entry throttle). Exit = source option 2: main-MA
recross as a closed-bar LEVEL condition (Red ≥ Green closes longs; mirror
shorts); no TP. Emergency stop 4×ATR(14) at entry, never moved (mechanizes
"emergency stops far away"; value unsourced, flagged). One position, no
stacking, opposite signal never reverses.

Authoritative hook-level spec:
`docs/ops/source_harvest/strategies/STR-004-daylight-wpr-ma-trend/04_spec_final.md`
(reconciliation in `03_reconciliation.md`).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ma_period` | 5 | 5 | SMMA close, main chart (source-fixed) |
| `strategy_ma_displacement` | 5 | 5 | red-line displacement (source-fixed) |
| `strategy_wpr_period` | 14 | 14 | Williams %R (source-fixed) |
| `strategy_sub_fast_period` | 8 | 8 | WPR SMMA fast/Red (source-fixed) |
| `strategy_sub_slow_period` | 21 | 21 | WPR SMMA slow/Blue (source-fixed) |
| `strategy_sub_daylight_min` | 4.0 | 4.0 | sub-window daylight, WPR units (source p.17) |
| `strategy_atr_period` | 14 | 14 | emergency-stop ATR |
| `strategy_emergency_atr_mult` | 4.0 | 3-5 | "far away" stop (unsourced mechanization, variant DAYL_004_ATR4EMERG) |
| `strategy_smma_seed_depth` | 400 | 400 | fixed WPR-SMMA recursion seed (determinism) |

---

## 3. Symbol Universe

NDX.DWX (0), GDAXI.DWX (1) — index cohort per author preference. Magics
201030000-201030001.

---

## 4. Timeframe

M15 execution; closed-bar reads only; WPR-SMMA series recomputed once per
closed bar (bounded by seed depth).

---

## 5. Expected Behaviour

Trend-continuation entries after pullbacks through the green line; chop
filtered by both daylight conditions. Est. 100-300 signals/yr/symbol — churn
economics judged by Q02+. Wide emergency stop → small position sizes under
RISK_FIXED; most exits via MA recross.

---

## 6. Source Citation

LauraT (2021), "Daylight Trading Strategy", ForexFactory thread 1086170,
https://www.forexfactory.com/thread/1086170/daylight-trading-strategy — posts
#1-2 (setup + rules 1-3 + exit options + emergency stops), p.17 (daylight ≥4),
p.14-15 (indices/M15 guidance). Card: QM5_20103 (g0 cross-approval codex).

---

## 7. Risk Model

RISK_FIXED backtest / RISK_PERCENT live (<=1% at the emergency stop; sizing
floor miss → skip trade); KS_DAILY_LOSS 3%; KS_PORTFOLIO_DD external guard;
news blackout fail-closed; Friday close 21:00 broker.

---

## Revision History

- 2026-07-24 — initial spec (harvest build run tranche 2, ledger STR-004).
