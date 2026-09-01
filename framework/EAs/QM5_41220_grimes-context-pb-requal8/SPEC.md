# QM5_41220_grimes-context-pb-requal8 — Strategy Spec

**EA ID:** QM5_41220

**Slug:** `grimes-context-pb-requal8`

**Source:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10939`

**Author of this spec:** Codex

**Last revised:** 2026-09-01

---

## 1. Strategy Logic

This EA is a new-identity, mechanically faithful port of
`QM5_10939_grimes-context-pb`, restricted by the approved manifest to
`GBPUSD.DWX`. On each completed H4 bar it looks for a quantified surprise leg
in the direction of an aligned D1 EMA trend with ADX at least 16, followed by a
three-to-ten-bar controlled pullback that holds H4 EMA(20).

It enters when the completed H4 close breaks the pullback's three-bar extreme.
The stop sits 0.25 ATR beyond the pullback extreme and must remain within 2.25
ATR; the target is 2R. The stop moves to breakeven at 1R, and the position exits
after 18 H4 bars or on a completed-bar breach of the surprise leg's adverse
61.8% retracement. There is no grid, martingale, averaging, pyramiding, or ML.

---

## 2. Parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `strategy_atr_period` | 20 | H4 ATR lookback. |
| `strategy_d1_fast_ema` | 20 | Fast D1 trend EMA and H4 pullback-quality EMA. |
| `strategy_d1_slow_ema` | 50 | Slow D1 trend EMA. |
| `strategy_d1_adx_period` | 14 | D1 ADX lookback. |
| `strategy_d1_adx_min` | 16.0 | Minimum D1 trend strength. |
| `strategy_surprise_lookback` | 12 | Maximum H4 surprise-leg formation window. |
| `strategy_breakout_lookback` | 30 | Prior H4 high/low breakout window. |
| `strategy_surprise_atr_mult` | 2.5 | Minimum surprise-leg size in ATR. |
| `strategy_climax_bar_atr_mult` | 3.0 | Maximum single surprise-leg bar in ATR. |
| `strategy_pullback_min_bars` | 3 | Minimum controlled-pullback length. |
| `strategy_pullback_max_bars` | 10 | Maximum controlled-pullback length. |
| `strategy_pullback_min_pct` | 25.0 | Minimum retracement percentage. |
| `strategy_pullback_max_pct` | 55.0 | Maximum retracement percentage. |
| `strategy_trigger_lookback` | 3 | Pullback extreme used for entry confirmation. |
| `strategy_pullback_bar_atr_mult` | 1.5 | Maximum pullback-bar range in ATR. |
| `strategy_stop_atr_buffer` | 0.25 | ATR buffer beyond the pullback extreme. |
| `strategy_max_stop_atr_mult` | 2.25 | Maximum permitted stop distance in ATR. |
| `strategy_target_r_mult` | 2.0 | Profit target in initial-risk units. |
| `strategy_breakeven_r_mult` | 1.0 | Profit threshold for breakeven movement. |
| `strategy_time_exit_h4_bars` | 18 | Maximum holding time in H4 bars. |
| `strategy_spread_stop_max_pct` | 8.0 | Maximum spread as a percentage of stop distance. |

---

## 3. Symbol Universe

- `GBPUSD.DWX` — exact manifest-bound requalification symbol; active magic
  slot 0 is `412200000`.

The reservation-only recovery card authorizes this single-symbol chain, so no
portable-basket expansion is included in this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe references | D1 EMA(20), D1 EMA(50), D1 ADX(14) |
| Entry gate | `QM_IsNewBar(_Symbol, PERIOD_H4)` |
| Signal inputs | completed H4 and D1 bars only |

---

## 5. Expected Behaviour

The approved parent card expects about 28 trades per year per symbol from
context-filtered continuation setups after a surprise leg and controlled
reaction. Positions usually last hours to roughly three trading days and are
bounded by a structural stop, 2R target, breakeven management, adverse
retracement exit, and 18-bar time exit. The strategy prefers directional D1
regimes with non-weak ADX and rejects climax legs, disorderly pullbacks, and
spreads above 8% of stop distance. This build asserts no profitability or
pipeline verdict.

---

## 6. Source Citation

**Recovery authority:** `OWNER-DEC-Q09HOLD-REQUAL-8-20260829:QM5_10939`

**Approved mechanics card:**
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_10939_grimes-context-pb.md`

The source lineage is Adam H. Grimes, “Context in Pullbacks: What Should
Happen?”, 2023-11-29, source ID
`fbfd7f6e-462a-55c8-9efa-9005a70c9f5c`. R1 lineage and R2–R4 PASS are
recorded in the approved parent card. The reserved recovery card is
`D:/QM/strategy_farm/artifacts/cards_review/QM5_41220_grimes-context-pb-requal8.md`
with `g0_status: APPROVED`. These records authorize build and non-live
requalification only.

---

## 7. Risk Model

| Environment | Active risk | Inactive risk |
|---|---|---|
| Backtest | `RISK_FIXED=1000` | `RISK_PERCENT=0` |
| Live | separately governed `RISK_PERCENT` | `RISK_FIXED=0` |

The bound setfile is backtest-only. This build does not authorize T_Live,
AutoTrading, deployment, or any pipeline verdict.

---

## Revision History

| Version | Date | Reason | Build task |
|---|---|---|---|
| v1 | 2026-09-01 | Initial governed requalification build from approved parent mechanics. | `e4782ee4-9fb4-4c3e-b9d5-9f9cd2ee3b8f` |
