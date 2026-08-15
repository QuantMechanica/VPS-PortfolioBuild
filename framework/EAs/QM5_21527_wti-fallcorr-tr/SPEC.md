# QM5_21527 wti-fallcorr-tr

## Identity

- EA ID: 21527
- Slug: wti-fallcorr-tr
- Host/traded symbol: XTIUSD.DWX, D1, slot 0, magic 215270000
- Read-only factor: SP500.DWX, D1
- Strategy Card: strategy-seeds/cards/approved/QM5_21527_wti-fallcorr-tr_card.md
- G0 decision: decisions/2026-08-15_qm5_21527_wti_fallcorr_trend_g0.md

## Locked Mechanic

On the first processed XTIUSD.DWX D1 bar after a broker-month transition:

1. Repair malformed owned state and close the prior-month position.
2. Persist the new month as consumed before every fallible entry gate.
3. Reconstruct exactly thirteen consecutive completed WTI broker-month-end
   closes and compute the exact twelve-month log-return sign.
4. Intersect completed WTI and SP500 D1 closes by exact timestamp and retain
   exactly 127 newest common closes.
5. Form exactly 126 simple returns and split them into newest and immediately
   preceding 63-return blocks without overlapping a return observation.
6. Compute a block-local Pearson correlation for each block.
7. Enter only when abs(rho_recent) + 1e-12 < abs(rho_preceding): buy WTI for
   positive twelve-month trend and sell WTI for negative trend.
8. Place one fixed-risk WTI position with a frozen 3.5 * ATR(20,D1) hard stop,
   no target, and a 1,500-point spread ceiling.
9. Close before monthly replacement, after forty calendar days, or on
   malformed owned state. Friday close and all news modes remain OFF.

SP500.DWX is read-only. It has no magic, sizing, or order path.

## Inputs

All Q02 inputs are locked:

| input | value |
|---|---:|
| qm_ea_id | 21527 |
| qm_magic_slot_offset | 0 |
| RISK_PERCENT | 0 |
| RISK_FIXED | 1000 |
| PORTFOLIO_WEIGHT | 1 |
| strategy_trend_months | 12 |
| strategy_trend_history_bars_d1 | 500 |
| strategy_corr_returns_per_block | 63 |
| strategy_corr_recent_block_offset | 0 |
| strategy_corr_preceding_block_offset | 63 |
| strategy_corr_common_closes | 127 |
| strategy_corr_history_bars_d1 | 350 |
| strategy_corr_tolerance | 1e-12 |
| strategy_variance_epsilon | 1e-16 |
| strategy_max_endpoint_gap_days | 10 |
| strategy_atr_period_d1 | 20 |
| strategy_atr_sl_mult | 3.5 |
| strategy_max_hold_days | 40 |
| strategy_max_spread_points | 1500 |

## Framework Alignment

- No-Trade: exact host/timeframe/EA/slot and locked-input contract.
- Entry: consumed month, independent trend history, synchronized WTI/SP500
  correlation history, strict falling-absolute-correlation gate, quote,
  spread, ATR, stop, and fixed-risk checks.
- Management: malformed-state repair, monthly rollover, and stale close run
  before entry-only gates.
- Close: framework close helper, broker hard stop, and kill switch.

## Safety Boundary

Backtest/Q01/Q02 only. No manual backtest, live/demo/shadow/stress/optimization
setfile, AutoTrading, T_Live access, deploy manifest, portfolio-gate change,
portfolio admission, or correlation waiver is authorized.

