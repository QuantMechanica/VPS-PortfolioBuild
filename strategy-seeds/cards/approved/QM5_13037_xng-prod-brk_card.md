---
ea_id: QM5_13037
slug: xng-prod-brk
type: strategy
strategy_id: EIA-XNG-DRYPROD-BRK-2026
source_id: EIA-XNG-DRYPROD-BRK-2026
source_citation: "U.S. Energy Information Administration. Natural Gas Monthly; Natural Gas Data; Natural Gas Dry Production table."
source_citations:
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Natural Gas Monthly."
    location: https://www.eia.gov/naturalgas/monthly/
    quality_tier: A
    role: primary
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Natural Gas Data."
    location: https://www.eia.gov/naturalgas/data.php
    quality_tier: A
    role: supporting
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Natural Gas Dry Production table."
    location: https://www.eia.gov/dnav/ng/ng_prod_sum_a_epg0_fpd_mmcf_a.htm
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-supply, channel-breakout, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
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

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xng-prod-brk_card.md`.

The EA trades `XNGUSD.DWX` on D1. It uses official EIA Natural Gas Monthly dry
production as structural supply lineage, then trades a price-only late-month
D1 compression breakout when the signal bar closes outside a Donchian channel
in the same direction as a slow SMA slope. It limits entries to one per
calendar month.

This is not XNG RSI commodity logic, not storage report aftershock/fade/inside
day/pre-event logic, not hurricane/freeze weather logic, not LNG export demand,
not broad XNG seasonality, not month-opening range, not weekend gap, not XNG
COT, not rig-count, and not an XTI/XNG or gas/metal basket. Backtests use
`RISK_FIXED=1000`, no external runtime data, no ML, no grid, no martingale, and
no live/deploy manifest changes.

## hypothesis

EIA monthly dry natural gas production is a structural supply input. The test is
whether `XNGUSD.DWX` D1 compression breaks during the late-month production
release window persist after confirmation by trend and channel structure.

## rules

Runtime rules are deterministic and price-only: late-month day gate,
compression filter, Donchian breakout, slow-SMA slope, ATR stop/target, channel
or SMA exit, time stop, framework news gate, Friday close, and one entry per
calendar month.

## 4. entry rules

- Host chart must be `XNGUSD.DWX` D1 with magic slot 0.
- Prior completed D1 bar must fall on day-of-month 25-31.
- Require compression over the prior lookback, excluding the signal bar.
- Long: bullish signal close above prior Donchian high and rising slow SMA.
- Short: bearish signal close below prior Donchian low and falling slow SMA.
- Skip if an open position exists, the month already traded, or spread exceeds
  `strategy_max_spread_points`.

## 5. exit rules

- ATR hard stop and ATR profit target are set at entry.
- Exit on slow-SMA failure, opposite exit-channel break, max-hold timeout,
  framework Friday close, or kill switch.

## 6. filters (no-trade module)

- Reject non-`XNGUSD.DWX` symbols, non-D1 periods, nonzero magic slots, invalid
  inputs, missing ATR/SMA/channel/OHLC data, and excessive spread.

## 7. trade management rules

- Symmetric long/short breakout.
- One position per magic/symbol, no pyramiding, no grid, no martingale, no ML,
  no external runtime data, no discretionary input.

## risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
No T_Live, AutoTrading, deploy manifest, or portfolio gate changes.

Q01 build validation passed on 2026-07-07. Q02 queue evidence:
`artifacts/qm5_13037_q02_enqueue_20260707.json`; work item
`53d0ecbf-ed77-49f1-bde5-4947dd8d2397`.
