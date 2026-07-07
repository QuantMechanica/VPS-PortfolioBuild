---
ea_id: QM5_13037
slug: xng-prod-brk
type: strategy
strategy_id: EIA-XNG-DRYPROD-BRK-2026
source_id: EIA-XNG-DRYPROD-BRK-2026
source_citation: "U.S. Energy Information Administration. Natural Gas Monthly; Natural Gas Data; Natural Gas Dry Production table."
strategy_type_flags: [official-release-window, structural-supply, channel-breakout, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13037_XNG_DRYPROD_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA dry-production release-window compression breakout; estimate 4-9 entries/year before Q02."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, donchian-channel, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-management, news-gate, friday-close, setfile-risk]
---

# XNG Dry-Production Release-Window Breakout

Approved structural XNG D1 sleeve. Full canonical card lives at
`strategy-seeds/cards/approved/QM5_13037_xng-prod-brk_card.md`.

The EA trades `XNGUSD.DWX` on D1 using a price-only late-month EIA
dry-production supply-window compression breakout with Donchian channel,
slow-SMA slope, ATR stop/target, and one entry per month. It is distinct from
XNG RSI, storage, weather, LNG, broad seasonality, month-opening range,
weekend, COT, rig-count, and energy basket sleeves.

Q01 build validation passed on 2026-07-07. Q02 queue evidence:
`artifacts/qm5_13037_q02_enqueue_20260707.json`; work item
`53d0ecbf-ed77-49f1-bde5-4947dd8d2397`.
