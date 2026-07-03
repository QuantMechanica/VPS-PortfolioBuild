---
ea_id: QM5_12998
slug: xti-spr-relief
type: strategy
source_id: EIA-SPR-RELIEF-2026
sources:
  - "U.S. Energy Information Administration, Weekly Petroleum Status Report, https://www.eia.gov/petroleum/supply/weekly/"
  - "U.S. Energy Information Administration, Weekly U.S. Ending Stocks of Crude Oil in SPR, https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCSSTUS1"
  - "U.S. Department of Energy, SPR Quick Facts, https://www.energy.gov/hgeo/opr/spr-quick-facts"
concepts:
  - "strategic-petroleum-reserve-policy-buffer"
  - "failed-energy-extreme"
  - "weekly-official-release-window"
indicators:
  - "SMA"
  - "ATR"
  - "Donchian extreme"
strategy_type_flags: [spr-policy-buffer, failed-breakout-reversion, structural-energy, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12998_XTI_SPR_RELIEF_D1
period: D1
expected_trade_frequency: "Weekly SPR/WPSR release-window failed 126-D1 extreme reversal; estimate 3-8 trades/year after extreme, rejection, stretch, spread, and one-position filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.10
expected_dd_pct: 18.0
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-03: R1 PASS official EIA WPSR and SPR series plus DOE SPR structural reference; R2 PASS deterministic D1 failed-extreme reversal on the regular SPR/WPSR release proxy window with ATR, SMA, time exit, and one-position guard; R3 PASS XTIUSD.DWX available in the local symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus existing WTI sleeves because this is a symmetric 126-D1 failed-extreme SPR data-window reversal, not QM5_12755 fixed-price long-only SPR refill-zone reclaim, WPSR continuation/fade/inside-bar/pre-event, Cushing, refinery, OPEC, IEA, DPR, rig-count, hurricane, roll, seasonality, ratio, carry, or RSI commodity logic."
---

# XTI SPR Relief

## Source

- Primary official information cycle: U.S. Energy Information Administration,
  "Weekly Petroleum Status Report", URL
  https://www.eia.gov/petroleum/supply/weekly/.
- SPR data lineage: U.S. Energy Information Administration, "Weekly U.S. Ending
  Stocks of Crude Oil in SPR", URL
  https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCSSTUS1.
- Structural policy reference: U.S. Department of Energy, "SPR Quick Facts",
  URL https://www.energy.gov/hgeo/opr/spr-quick-facts.

## Concept

The Strategic Petroleum Reserve is an official U.S. crude-oil buffer, and its
stock changes are published in the same weekly official petroleum information
cycle that reprices WTI. This card does not forecast SPR policy and does not
ingest the EIA series at runtime. It uses the regular Wednesday/Thursday
WPSR/SPR release proxy window and asks a narrower question: did WTI probe a
major 126-D1 extreme during that window and fail back inside it?

The QM expression is a policy-buffer reversal sleeve. It fades failed
multi-month extremes only after an official release-window bar has a large ATR
range, rejects the prior 126-D1 high or low, and remains stretched from a slow
SMA anchor.

## Non-Duplicate Rationale

This card is intentionally different from existing WTI event builds:

- `QM5_12755_wti-spr-refill-bounce` is a long-only fixed DOE refill-zone
  reclaim around a USD policy level. `QM5_12998` has no fixed price-zone,
  no tender/refill level, and can be long or short only after a failed 126-D1
  high/low during the weekly SPR stock disclosure window.
- `QM5_12988_xti-eia-inventory-momentum` requires two same-direction weekly
  WPSR reaction bars and follows breakout continuation.
- `QM5_12579_eia-wti-aftershock` follows one large WPSR event-day reaction.
- `QM5_12590_eia-wti-wpsr-fade` fades generic one-bar WPSR exhaustion near
  SMA(50), without the 126-D1 failed-extreme policy-zone requirement.
- `QM5_12752_eia-wti-wpsr-idbrk` waits for post-event inside-bar breakout.
- `QM5_12996_xti-dpr-mom`, `QM5_12992_eia-steo-brk`, `QM5_12994_iea-omr-fade`,
  and `QM5_12995_opec-momr-brk` use monthly/separate official report windows,
  not weekly SPR stock disclosure.
- Seasonality, roll, expiry, Cushing, refinery, hurricane, rig-count, XTI/XNG,
  oil-metal, XAU/XAG, XNG, index, and RSI commodity sleeves are different
  mechanisms and exposures.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 3-8 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC, spread, broker calendar, ATR, and SMA only.
  No EIA CSV/API, inventory surprise feed, analyst forecast, futures curve, or
  ML model is used at runtime.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Treat the prior completed D1 bar as an SPR/WPSR release proxy only when its
  broker calendar day is Wednesday or Thursday.
- Compute ATR(`strategy_atr_period`) and SMA(`strategy_mean_period`) on the
  prior completed D1 bar.
- Compute the prior `strategy_extreme_lookback` D1 high and low, excluding the
  release proxy bar.
- Require the release proxy bar range to be at least
  `strategy_min_range_atr` times ATR.
- Failed-high short setup:
  - Event high exceeds the prior lookback high by at least
    `strategy_min_probe_atr` times ATR.
  - Event close falls back below the prior lookback high by at least
    `strategy_min_reject_atr` times ATR.
  - Event close is in the lower `strategy_reject_close_ratio` part of the bar.
  - Event close is above SMA by at least `strategy_min_stretch_atr` times ATR.
  - Event close is below event open.
- Failed-low long setup:
  - Event low breaches the prior lookback low by at least
    `strategy_min_probe_atr` times ATR.
  - Event close reclaims the prior lookback low by at least
    `strategy_min_reject_atr` times ATR.
  - Event close is in the upper `strategy_reject_close_ratio` part of the bar.
  - Event close is below SMA by at least `strategy_min_stretch_atr` times ATR.
  - Event close is above event open.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when the prior completed D1 close reaches or exceeds
  SMA(`strategy_mean_period`).
- Close a short when the prior completed D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 3-8 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 official source: EIA WPSR, EIA SPR weekly stock series, and DOE SPR
  structural reference.
- [x] R2 mechanical: fixed weekday release proxy, failed 126-D1 extreme,
  ATR/SMA gates, ATR stop, and deterministic mean/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data, and one position per magic.
- [x] Non-duplicate: not the `QM5_12755` fixed-price long-only SPR refill
  bounce, WPSR continuation, generic WPSR fade, post-event inside-bar
  breakout, pre-WPSR positioning, DPR, STEO, OPEC, IEA, Cushing, refinery,
  hurricane, rig-count, roll, seasonality, ratio, XNG, XAU/XAG, or RSI
  commodity logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: official release-window failed extreme plus ATR range,
  SMA stretch, close-location, and one-position filters.
- trade_management: slow-SMA mean-reversion target and fixed max-hold exit.
- trade_close: hard ATR stop plus deterministic time/mean exits and framework
  Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-03.
- Q01: implemented as `framework/EAs/QM5_12998_xti-spr-relief`.
- Q02: queued after compile.
