---
ea_id: QM5_13046
slug: xti-vrp-proxy
type: strategy
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008_XTI_PROXY
sources:
  - "Trolle, Anders B. and Schwartz, Eduardo S. (2008). Variance risk premia in energy commodities. https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf"
  - "BIS Working Papers No. 619. Volatility risk premia and future commodities returns. https://www.bis.org/publ/work619.pdf"
concepts:
  - "energy-volatility-risk-premium"
  - "realized-volatility-quartile-proxy"
  - "high-volatility-stretch-reversion"
indicators:
  - "realized volatility"
  - "ATR"
  - "SMA"
strategy_type_flags: [structural-energy, realized-volatility-regime, mean-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13046_XTI_VRP_PROXY_D1
period: D1
expected_trade_frequency: "D1 high-realized-volatility stretch reversion; estimate 6-14 trades/year after top-quartile RV, stretch, spread, and one-position filters."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.10
expected_dd_pct: 18.0
g0_approval_reasoning: "Mission-directed commodity sleeve approval 2026-07-07: R1 PASS Trolle-Schwartz energy VRP academic source plus BIS commodity VRP supplement; R2 PASS deterministic OHLC-only realized-volatility percentile proxy with return-stretch, ATR, SMA, time, spread, and one-position rules; R3 PASS XTIUSD.DWX available in local DWX matrix; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus existing XTI sleeves because this is a realized-volatility-regime stretch-reversion proxy, not WPSR/EIA/OPEC/IEA/COT/rig-count/seasonality/weekday/expiry/roll/carry/oilgas/oilmetal/VCB/TSMOM/RSI logic."
---

# XTI VRP Proxy

## Source

- Primary: Trolle and Schwartz, "Variance risk premia in energy commodities",
  public paper copy, URL
  https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf.
- Supplement: BIS Working Papers No. 619, "Volatility risk premia and future
  commodities returns", URL https://www.bis.org/publ/work619.pdf.

## Concept

Energy options literature documents persistent and time-varying variance risk
premia in crude oil and natural gas. V5 cannot read option chains or variance
swap rates at runtime, so this card does not build a true implied-minus-realized
VRP trader. It builds a spot-CFD proxy: when WTI realized volatility is in its
own top quartile, fade short-horizon directional stretches back toward a slow
D1 mean with a hard ATR stop.

The intended portfolio role is a structural energy sleeve with a different
driver from index, metal, XNG, WPSR, OPEC, EIA, COT, weekday, expiry, carry,
oil/gas ratio, oil/metal ratio, VCB, TSMOM, and RSI commodity logic.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Runtime data: Darwinex MT5 OHLC, spread, broker calendar, ATR, SMA, and
  realized volatility computed from closed D1 returns only.
- No options data, EIA data, futures curve, CSV/API, or external feed is used.

## Entry Rules

- Evaluate only on a new D1 bar.
- Host chart must be `XTIUSD.DWX` on D1 and magic slot 0.
- Compute current realized volatility from the last
  `strategy_rv_period` closed D1 log returns.
- Compute the percentile rank of that realized volatility versus the prior
  `strategy_rv_rank_lookback` rolling realized-volatility samples.
- Trade only when the percentile rank is at least
  `strategy_entry_rv_percentile`.
- Long setup:
  - `strategy_return_lookback` D1 close-to-close return is negative by at
    least `strategy_min_return_atr` times ATR.
  - Prior D1 close is below SMA(`strategy_mean_period`) by at least
    `strategy_min_stretch_atr` times ATR.
  - Prior D1 candle closes bullish and in the upper half of its range.
- Short setup mirrors the long setup after a positive return stretch, close
  above SMA, bearish prior D1 candle, and lower-half close.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close a long when the prior completed D1 close reaches or exceeds
  SMA(`strategy_mean_period`).
- Close a short when the prior completed D1 close reaches or falls below
  SMA(`strategy_mean_period`).
- Close any open position when realized-volatility percentile falls below
  `strategy_exit_rv_percentile`.
- Close after `strategy_max_hold_days` calendar days.
- Friday close remains enabled by the V5 framework.

## Risk

- expected_pf: 1.10.
- expected_dd_pct: 18.
- expected_trade_frequency: approximately 6-14 trades/year.
- risk_class: medium-high for crude-oil volatility.
- gridding: false.
- scalping: false.
- ml_required: false.

## Strategy Allowability Check

- [x] R1 reputable source: academic energy VRP source plus BIS supplement.
- [x] R2 mechanical: fixed realized-vol percentile, return stretch, ATR stop,
  SMA/vol/time exits.
- [x] R3 testable: `XTIUSD.DWX` exists in
  `framework/registry/dwx_symbol_matrix.csv`; proxy uses MT5 OHLC only.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale,
  no external runtime data, and one position per magic.
- [x] Non-duplicate: not WTI WPSR, EIA product flow, OPEC, IEA, STEO, COT,
  rig-count, Cushing, SPR, refinery, hurricane, weekday, weekend, expiry,
  roll, carry, month seasonality, TSMOM, RSI, VCB, XTI/XNG, oil/gold,
  oil/silver, or XNG logic.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: realized-volatility top-quartile state plus short-horizon
  return stretch and reversal candle confirmation.
- trade_management: SMA mean-reversion exit, realized-vol percentile exit, and
  max-hold exit.
- trade_close: hard ATR stop plus deterministic time/mean/vol exits and
  framework Friday close.

## Pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-07.
- Q01: implemented as `framework/EAs/QM5_13046_xti-vrp-proxy`.
- Q02: queued after compile.

