---
ea_id: QM5_21509
slug: qs-emv-trend-ndx
type: strategy
source_id: 0b564ef2-810c-5b1d-9084-342ddb20575c
sources:
  - "[[sources/quantifiedstrategies-ease-of-movement]]"
concepts:
  - "[[concepts/ease-of-movement]]"
  - "[[concepts/volume-price-relationship]]"
  - "[[concepts/trend-confirmation]]"
indicators:
  - "[[indicators/emv]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr-stop]]"
strategy_type_flags: [emv-trend-confirm, single-symbol, atr-hard-stop, both-direction, mid-frequency, volume-proxy]
target_symbols: [NDX.DWX]
single_symbol_only: true
logical_symbol: QM5_21509_NDX_EMV_TREND_D1
period: D1
expected_trade_frequency: "A 14-bar-smoothed EMV zero-cross AND SMA50 trend agreement on NDX D1 is conservatively estimated at about 8-12 joint signals/year."
expected_trades_per_year_per_symbol: 10
last_updated: 2026-08-15
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Anonymous-author-OK per 2026-06-30 revision; source is QuantifiedStrategies.com 'Ease Of Movement Indicator (EMV) as a Trading Strategy (Backtest)' (https://www.quantifiedstrategies.com/ease-of-movement/), which documents Richard Arms' EMV indicator and the article's own suggested combination: 'buy when EMV crosses above zero during an uptrend..., sell when it crosses below in a downtrend,' explicitly combined with a moving-average trend filter for reliability."
r2_mechanical: PASS
r2_reasoning: "Deterministic: EMV is a closed-form formula from High/Low/Volume; entry triggers on EMV zero-cross confirmed by an SMA trend-direction filter, exactly the combination the source itself recommends. No discretion."
r3_data_available: PASS
r3_reasoning: "NDX.DWX native D1 High/Low/Close/tick-volume are sufficient. MT5 CFD volume is tick volume, not exchange share volume; used here as the standard proxy consistent with existing OBV/MFI/Chaikin cards already in the book."
r4_ml_forbidden: PASS
r4_reasoning: "No ML, no adaptive/PnL-dependent parameters; EMV and its trend filter depend only on price/volume history. No grid/martingale."
pipeline_phase: G0
expected_pf: 1.12
expected_dd_pct: 20.0
risk_class: medium
ml_required: false
g0_approval_reasoning: "R1 single linked QS lineage recorded; R2 EMV zero-cross plus SMA50 filter with trend/ATR/time exits is mechanical at a conservative 10 trades/year; R3 NDX.DWX OHLC and tick volume suffice with no external feed; R4 deterministic, ML-free, one position per magic."
---

# NDX Ease of Movement (EMV) Trend-Confirmation Strategy

## Source

- Source: [[sources/quantifiedstrategies-ease-of-movement]]
- Citation: QuantifiedStrategies.com, "Ease Of Movement Indicator (EMV) as
  a Trading Strategy (Backtest)." https://www.quantifiedstrategies.com/ease-of-movement/
- Key finding used here: the article states EMV is best used "for
  confirmation rather than primary signals: buy when EMV crosses above
  zero during an uptrend (or after a pullback), sell when it crosses
  below in a downtrend," and recommends combining it with a trend filter
  (moving average for direction, ADX for strength, or RSI for
  overbought/oversold) "to improve reliability." This card implements
  that exact recommended combination (EMV zero-cross + SMA trend filter).

## Edge / Thesis

Richard Arms' Ease of Movement indicator measures how much price moves
per unit of volume-implied "effort" (box-ratio-scaled midpoint change).
A rising EMV during an established uptrend indicates the market is
advancing on relatively light volume/effort, consistent with a healthy
low-friction trend; combining the EMV zero-cross with an independent
SMA trend-direction filter (as the source itself recommends) should
reduce false EMV signals generated in non-trending regimes.

This is a price+tick-volume implementation; no options, futures
term-structure, or macro-feed data is used.

## Markets And Timeframe

- Target symbol: `NDX.DWX` only.
- Period: D1.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: native MT5 D1 OHLC and tick volume on NDX only; no
  external feed, no ML model.

## Entry Rules

- Evaluate only on a new completed D1 bar.
- Compute raw EMV on completed bars:
  - `Midpoint_Move[1] = ((High[1]+Low[1])/2) - ((High[2]+Low[2])/2)`.
  - `Box_Ratio[1] = (Volume[1] / strategy_volume_divisor) / (High[1] - Low[1])`,
    with `Box_Ratio = 0` (no EMV update, carry prior smoothed value) if
    `High[1] == Low[1]` or `Volume[1] == 0`.
  - `EMV_raw[1] = Midpoint_Move[1] / Box_Ratio[1]`.
  - `EMV[1] = SMA(EMV_raw, strategy_emv_smooth_period)[1]` (smoothed EMV,
    default 14-period).
- Compute `SMA(strategy_trend_period, D1)` on completed closes for the
  trend filter (default 50).
- Open LONG when `EMV[1]` crosses from `<=0` to `>0` AND `Close[1] >
  SMA(strategy_trend_period)[1]` (uptrend filter agrees) AND no long
  position is already open.
- Open SHORT when `EMV[1]` crosses from `>=0` to `<0` AND `Close[1] <
  SMA(strategy_trend_period)[1]` (downtrend filter agrees) AND no short
  position is already open.
- An EMV zero-cross that disagrees with the SMA trend filter is ignored
  (no entry, no forced close of an existing position).
- No entry if NDX spread exceeds `strategy_max_spread_points`.
- No entry if fewer than `strategy_trend_period + strategy_emv_smooth_period
  + 5` completed D1 bars of history are available.

## Exit Rules

- Trend-failure exit: close LONG when `Close[1] < SMA(strategy_trend_period)[1]`;
  close SHORT when `Close[1] > SMA(strategy_trend_period)[1]`.
- Stop loss: fixed hard SL at `strategy_atr_sl_mult` x `ATR(strategy_atr_period,
  D1)` from entry.
- Max-hold exit: close after `strategy_max_hold_bars` completed D1 bars
  (default 50) as a stale-position guard.
- Friday close remains enabled by the V5 framework.
- No trailing stop, no take-profit, no partial close in v1.

## Filters

- Only trade `NDX.DWX` on D1.
- Framework news, kill-switch, magic, and Friday-close guards remain active.
- Spread cap via `strategy_max_spread_points`.

## Trade Management Rules

- Both long and short.
- One open position per magic.
- No pyramiding, gridding, martingale, or scale-in.
- No partial close.
- No re-entry in the same direction until a fresh EMV zero-cross that
  agrees with the SMA trend filter occurs.

## Parameters To Test

- name: strategy_emv_smooth_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_volume_divisor
  default: 10000
  sweep_range: [1000, 10000, 100000]
- name: strategy_trend_period
  default: 50
  sweep_range: [30, 50, 80]
- name: strategy_atr_period
  default: 14
  sweep_range: [10, 14, 20]
- name: strategy_atr_sl_mult
  default: 2.5
  sweep_range: [2.0, 2.5, 3.0]
- name: strategy_max_hold_bars
  default: 50
  sweep_range: [30, 50, 70]
- name: strategy_max_spread_points
  default: 500
  sweep_range: [300, 500, 800]

## Dedup Assessment

| Card | Overlap? | Verdict |
|---|---|---|
| Any `obv*` / `mfi*` / `chaikin*` card (9 + 14 + 5 in book) | All are "volume-derived confirmation indicator" family | DIFFERENT FORMULA -- OBV is cumulative signed volume, MFI is a volume-weighted RSI-style oscillator, Chaikin blends accumulation/distribution with volume; EMV instead scales the High/Low midpoint move by a volume-to-range "box ratio," a distinct construction none of the existing cards use |
| Any `adx*` trend-filter card | Both use "oscillator zero-cross + independent trend filter" pattern | DIFFERENT SIGNAL SOURCE -- the confirming oscillator here is EMV (volume-effort based), not ADX (directional-movement based); the source article explicitly lists ADX/MA/RSI as alternative, not equivalent, filter choices, and this card implements the MA-filter variant |
| Book-wide keyword scan | `ease-of-movement` / `emv` (as a distinct token) | ZERO existing cards in the current ~3500-card book use this indicator (verified by full-book slug grep 2026-08-13) |

## Low-Correlation Argument

- EMV's volume-effort construction is unlike any existing volume
  indicator in the book (OBV/MFI/Chaikin/AD), giving a distinct signal
  source even though tick volume is the common input.
- Applied to NDX (index CFD) rather than an FX pair or metal, adding
  cross-asset-class diversity to the book's confirmation-filter family.

## Net-Cost Check

NDX commission/spread is moderate for an index CFD. ~8-12 trades/year
with the trend-filter requirement reducing false EMV crosses in
non-trending regimes keeps turnover manageable; gross should reasonably
approximate net.

## Initial Risk Profile

- expected_pf: 1.12
- expected_dd_pct: 20.0
- expected_trade_frequency: approximately 8-12 trades/year.
- risk_class: medium.
- gridding: false.
- scalping: false.
- ml_required: false.

## Framework Alignment

- no_trade: D1 NDX.DWX guard, history-length/warm-up guard, spread cap.
- trade_entry: EMV zero-cross confirmed by SMA trend-direction filter.
- trade_management: ATR hard stop, 50-bar max-hold time stop.
- trade_close: trend-filter-flip exit, ATR stop, time stop, framework
  Friday close.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-08-13 | PENDING | this card |
