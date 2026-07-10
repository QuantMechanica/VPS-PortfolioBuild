---
strategy_id: PAPAILIAS-RSM-2021_XNG_S01
source_id: PAPAILIAS-RSM-2021
ea_id: QM5_13116
slug: xng-signmom
status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
strategy_type_flags: [momentum, time-stop, symmetric-long-short, atr-hard-stop]
primary_target_symbols: [XNGUSD.DWX]
timeframes: [D1]
review_focus: "XNG monthly return-sign persistence, mechanically distinct from QM5_12567 RSI pullback; Q09 judges realized orthogonality."
---

# Approved XNG Return-Sign Momentum Card

The complete canonical card is `strategy-seeds/cards/xng-signmom_card.md` and
the complete runtime G0 artifact is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_13116_xng-signmom.md`.

Source: Papailias, Liu, and Thomakos (2021), "Return Signal Momentum,"
*Journal of Banking & Finance* 124, 106063,
https://doi.org/10.1016/j.jbankfin.2021.106063. Natural gas is explicit in the
paper's 24-commodity futures panel.

Approved entry: at the first `XNGUSD.DWX` D1 bar of each broker month, calculate
the equal-weight fraction of non-negative returns over the prior 12 completed
months. BUY at or above fixed threshold 0.40; otherwise SELL. Require valid
history, spread and ATR, one magic position, and no prior current-month attempt.

Approved exit: close at the next monthly renewal or after 35 calendar days;
retain a frozen ATR(20)*3.5 broker stop. Friday close is disabled to preserve
the monthly hold. No same-month re-entry, target, trailing, partial close, scale,
grid, martingale, adaptive threshold, external data, or ML.

Q02 setfile risk is `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. Retire below five trades/year. No live/T_Live manifest,
portfolio gate, `T_Live`, or AutoTrading mutation is authorized.

