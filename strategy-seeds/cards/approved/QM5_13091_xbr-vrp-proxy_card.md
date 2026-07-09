---
ea_id: QM5_13091
slug: xbr-vrp-proxy
type: strategy
source_id: TROLLE-SCHWARTZ-ENERGY-VRP-2008_XBR_PROXY
sources:
  - "Trolle, Anders B. and Schwartz, Eduardo S. (2008). Variance risk premia in energy commodities. https://www.anderson.ucla.edu/documents/areas/fac/finance/schwartz_risk_premia.pdf"
  - "BIS Working Papers No. 619. Volatility risk premia and future commodities returns. https://www.bis.org/publ/work619.pdf"
concepts:
  - "energy-volatility-risk-premium"
  - "realized-volatility-quartile-proxy"
  - "brent-high-volatility-stretch-reversion"
indicators:
  - "realized volatility"
  - "ATR"
  - "SMA"
strategy_type_flags: [structural-energy, realized-volatility-regime, mean-reversion, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XBRUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13091_XBR_VRP_PROXY_D1
period: D1
expected_trade_frequency: "D1 high-realized-volatility Brent stretch reversion; estimate 5-12 trades/year after top-quartile RV, stretch, spread, and one-position filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 20.0
g0_approval_reasoning: "Mission-directed commodity/energy sleeve approval 2026-07-09: R1 PASS Trolle-Schwartz academic energy VRP source plus BIS commodity VRP supplement; R2 PASS deterministic OHLC-only realized-volatility percentile proxy with return-stretch, ATR, SMA, time, spread, and one-position rules; R3 PASS XBRUSD.DWX has active local Brent routes and Q02 validates current history/fills; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate versus existing energy sleeves because this is a Brent realized-volatility-regime stretch-reversion proxy, not XTI/XNG VRP, Brent month/weekday/TOM/TSMOM/52-week/6-month reversal, WTI event/calendar/inventory, XTI/XNG, oil-metal, XNG, index, or commodity-RSI logic."
---

# XBR VRP Proxy

## thesis

Energy options literature documents persistent and time-varying variance risk
premia in crude oil and natural gas. V5 cannot read option chains or variance
swap rates at runtime, so this card does not build a true implied-minus-realized
VRP trader. It builds a spot-CFD proxy: when Brent realized volatility is in its
own top quartile, fade short-horizon directional stretches back toward a slow
D1 mean with a hard ATR stop.

The intended portfolio role is a new Brent energy sleeve with a different
driver from the current XAU/SP500/NDX/XNG book. It is also distinct from
`QM5_13046_xti-vrp-proxy` and `QM5_13051_xng-vrp-proxy` by benchmark and magic
route, so Q02 can test whether the Brent realization adds non-XNG energy
exposure rather than another metal, index, WTI, or natural-gas leg.

## market_universe

- Symbol: `XBRUSD.DWX`.
- Period: D1.
- Runtime data: Darwinex MT5 OHLC, spread, broker calendar, ATR, SMA, and
  realized volatility computed from closed D1 returns only.
- No options data, EIA data, futures curve, CSV/API, or external feed is used.

## timeframe

Evaluate only on the first tick of a new D1 bar. All signal reads use completed
D1 bars.

## entry

- Host chart must be `XBRUSD.DWX` on D1 and magic slot 0.
- Compute current realized volatility from the last
  `strategy_rv_period` closed D1 log returns.
- Compute the percentile rank of that realized volatility versus the prior
  `strategy_rv_rank_lookback` rolling realized-volatility samples.
- Trade only when the percentile rank is at least
  `strategy_entry_rv_percentile`.
- Long setup: the `strategy_return_lookback` D1 close-to-close return is
  negative by at least `strategy_min_return_atr` times ATR, the prior D1 close
  is below SMA(`strategy_mean_period`) by at least
  `strategy_min_stretch_atr` times ATR, and the prior D1 candle closes bullish
  in the upper half of its range.
- Short setup mirrors the long setup after a positive return stretch, close
  above SMA, bearish prior D1 candle, and lower-half close.
- No entry if an open `XBRUSD.DWX` position already exists for this EA magic.
- No entry if spread exceeds `strategy_max_spread_points`.

## exit

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

## risk

- Backtest mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- Live risk is not configured by this card.
- One open position per symbol magic. No grid, martingale, pyramiding, partial
  close, or external runtime data.

## filters

- D1 + `XBRUSD.DWX` only.
- Require valid ATR, SMA, D1 close, D1 candle range, and realized-volatility
  percentile state.
- Standard V5 news, kill-switch, magic, and Friday-close guards remain active.

## falsification

- Fail if Q02 produces fewer than 4 trades/year on the available test window.
- Fail if all positive contribution comes from one direction.
- Correlation-review kill if its event dates materially overlap the XNG or
  index/metal book; expected overlap should be low because this strategy only
  trades high-realized-volatility Brent stretch/reversal regimes.

## q08_q11_risks

Brent can gap sharply around macro, OPEC, shipping, and inventory shocks. The
Q05-Q08 pipeline must verify that the ATR stop, max-hold exit, and volatility
normalization exit contain crisis-path drawdown.

## implementation_notes

- Build path: `framework/EAs/QM5_13091_xbr-vrp-proxy`.
- One canonical Q02 setfile:
  `QM5_13091_xbr-vrp-proxy_XBRUSD.DWX_D1_backtest.set`.
- No `T_Live`, deploy manifest, portfolio gate, AutoTrading, or live setfile is
  touched.

## parameters_to_test

- name: strategy_rv_period
  default: 20
  sweep_range: [10, 20, 30]
- name: strategy_rv_rank_lookback
  default: 252
  sweep_range: [126, 252, 378]
- name: strategy_entry_rv_percentile
  default: 0.75
  sweep_range: [0.65, 0.75, 0.85]
- name: strategy_exit_rv_percentile
  default: 0.50
  sweep_range: [0.35, 0.50, 0.65]
- name: strategy_atr_sl_mult
  default: 2.75
  sweep_range: [2.00, 2.75, 3.50]

## framework_alignment

- no_trade: D1 and `XBRUSD.DWX` guard, magic-slot guard, parameter guard, and
  spread cap.
- trade_entry: realized-volatility top-quartile state plus short-horizon
  return stretch and reversal candle confirmation.
- trade_management: SMA mean-reversion exit, realized-vol percentile exit, and
  max-hold exit.
- trade_close: hard ATR stop plus deterministic time/mean/vol exits and
  framework Friday close.

## pipeline

- G0: APPROVED by mission-directed card criteria on 2026-07-09.
- Q01: implemented as `framework/EAs/QM5_13091_xbr-vrp-proxy`.
- Q02: enqueue after compile.

