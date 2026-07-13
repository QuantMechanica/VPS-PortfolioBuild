# QM5_13204 — Std-Dev Reversal off the First Significant Swing

**Origin:** ICT/SMC video `zw_J5RP31cA` (analysis:
`docs/research/VIDEO_zw_J5RP31cA_ANALYSIS_2026-07-12.md`). OWNER-directed build
(2026-07-12): "build the concrete hypothesis."

**Status:** HYPOTHESIS, not a faithful port. The video's defining input ("first
*significant* swing") is explicitly discretionary ("train your eyes… stand out like a
sore thumb"). This EA pins that judgment to concrete rules so the deterministic pipeline
(Q02) can judge it. Same class as ICT Silver Bullet — no faithful mechanization exists
without an OWNER reference definition.

## Mechanism (single position, single target)
Direction-symmetric (long + short). On each closed bar:
1. **Swing extreme** — lowest low (long) / highest high (short) over `swing_lookback`
   closed bars, at index `iL`/`iH`.
2. **First-swing leg** — for a long, the rally high `SH` = max high of the bars more
   recent than the low; leg `R = SH − SL`. "Significant" ⇔ `R ≥ sig_atr_mult × ATR`.
3. **Sweep + reclaim** — the last closed bar wicks BEYOND the extreme by
   `≤ sweep_atr_mult × ATR` and CLOSES back inside (liquidity grab then reversal).
4. **Entry** — market on the reclaim (long after a swept low, short after a swept high).
5. **Stop** — beyond the sweep wick: `sweep_low − sl_buffer_atr × ATR` (long).
6. **Target** — `entry + tp_r_mult × R` (long) — the std-dev projection of the first swing.
7. **Time stop** — flat after `max_hold_bars`.

Broker-stops-level + spread guards reject unfillable/over-cost setups.

## Inputs (defaults)
| input | default | meaning |
|---|---|---|
| `strategy_swing_lookback` | 30 | bars to locate the swing extreme |
| `strategy_atr_period` | 14 | ATR (pooled `QM_ATR`, shift 1) |
| `strategy_sig_atr_mult` | 1.5 | leg significance floor (R ≥ this·ATR) |
| `strategy_sweep_atr_mult` | 0.6 | max wick beyond the extreme |
| `strategy_sl_buffer_atr` | 0.3 | stop beyond the sweep wick |
| `strategy_tp_r_mult` | 2.0 | take-profit as R-multiple |
| `strategy_max_hold_bars` | 48 | time stop |
| `strategy_max_spread_stop_pct` | 15.0 | reject if spread > % of SL distance |
| `strategy_allow_long/short` | true | direction gates |

## Compliance
- **No** grid / martingale / averaging / recovery / hedging (single entry, hard stop).
- **No** ML. `RISK_FIXED` for backtest / `RISK_PERCENT` for live.
- `symbol_slot` set explicitly in the entry hook.

## Target market / timeframe (first test)
`NDX.DWX` (routable index; ICT content hints indices — "extreme volatility"), `M15`
working TF (video uses 15-min entries). Q02 on full history, Model 4.

## v2 levers (documented, not in v1)
- Higher-TF **PD-array confluence** (FVG / new-day / new-week opening gap) gating the sweep.
- **Break-even after 1R** + scale-out (TP1/TP2 + runner to 3R) per the video's management.
- Multi-symbol basket once the single-symbol edge (if any) is established.
