# QM5_11325 — EMA Cascade/MACD Partial Exit

**EA ID:** QM5_11325
**Slug:** tc-m5-9-ema50-100-macd-partial-exit
**Approved card:** `docs/strategy_card.md`
**Last revised:** 2026-08-17

## 1. Strategy Logic

Signals are evaluated once per completed M5 bar and entered on the following
bar. A long requires the completed close above EMA(50) and EMA(100), at least
10 pips above EMA(50), plus a MACD(12,26,9) main-line zero cross during the
last five completed bars. A short mirrors those conditions below both EMAs.

The initial stop uses the nearer of the five-bar structure extreme and
ATR(14) × 1.5. At 2R, the EA closes 50% of the initial volume when broker lot
constraints permit and moves the remainder's stop to breakeven. The remainder
exits after a completed close crosses 10 pips back through EMA(50). The
strategy is deterministic and contains no adaptive or ML component.

## 2. Parameters

| Parameter | P2 value | Meaning |
|---|---:|---|
| `strategy_ema_fast_period` | 50 | Fast EMA and trailing-exit reference. |
| `strategy_ema_slow_period` | 100 | Slow EMA cascade filter. |
| `strategy_breakout_pips` | 10 | Minimum completed-close distance beyond EMA(50). |
| `strategy_macd_fast` | 12 | MACD fast period. |
| `strategy_macd_slow` | 26 | MACD slow period. |
| `strategy_macd_signal` | 9 | MACD signal period. |
| `strategy_macd_lookback_bars` | 5 | Zero-cross lookback. |
| `strategy_sl_lookback_bars` | 5 | Structure-stop lookback. |
| `strategy_atr_period` | 14 | Stop-cap volatility period. |
| `strategy_atr_sl_cap_mult` | 1.5 | ATR stop-distance cap. |
| `strategy_partial_tp_rr` | 2.0 | Partial-exit R multiple. |
| `strategy_partial_close_fraction` | 0.5 | Fraction requested at the partial exit. |
| `strategy_trail_exit_pips` | 10 | EMA(50) break-back exit threshold. |
| `strategy_max_spread_pips` | 15 | Fresh-entry spread cap. |

The approved card defines no news-based edge. Defaults and all sealed
backtest setfiles therefore use `QM_NEWS_TEMPORAL_OFF`,
`QM_NEWS_COMPLIANCE_NONE`, and legacy `QM_NEWS_OFF` (numeric `0/0/0`), so P2
does not acquire an undocumented calendar dependency.

## 3. Symbol Universe

| Registry slot | Symbol | Magic |
|---:|---|---:|
| 0 | EURUSD.DWX | 113250000 |
| 1 | GBPUSD.DWX | 113250001 |
| 2 | USDJPY.DWX | 113250002 |

Only these approved `.DWX` FX symbols are in scope.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe references | none |
| Entry gating | one evaluation per new M5 bar |
| Signal data | completed bars only |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 36 |
| Regime preference | directional EMA cascade with recent MACD confirmation |
| Hold profile | structure/ATR stop, partial 2R scale-out, EMA(50) remainder exit |
| Position concurrency | one framework-managed position per magic |

## 6. Source Citation

The approved card attributes the mechanics to Thomas Carter, *20 Forex
Trading Strategies (5 Minute Time Frame)*, System #9, source ID
`e78a9f1f-4e6a-563c-a080-915133d6ed28`. The line-for-line approved card
snapshot is retained in `docs/strategy_card.md`. G0 is OWNER-authorized
`APPROVED`; R2, R3, and R4 are PASS, while R1 is informational under the
OWNER policy recorded on the card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| P2/Q02 backtest | `RISK_FIXED` | 1000 |
| P2/Q02 percentage risk | `RISK_PERCENT` | 0 |

All three backtest presets seal fixed-dollar sizing and their registry slot.
No live preset or deployment artifact is part of this build repair.
