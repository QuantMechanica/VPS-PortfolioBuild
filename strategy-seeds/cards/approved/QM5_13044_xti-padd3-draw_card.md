---
ea_id: QM5_13044
slug: xti-padd3-draw
type: strategy
strategy_id: EIA-XTI-PADD3-DRAW-2026
source_id: EIA-XTI-PADD3-DRAW-2026
source_citation: "U.S. Energy Information Administration Gulf Coast (PADD 3) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Gulf Coast (PADD 3) Ending Stocks excluding SPR of Crude Oil."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP31
    quality_tier: A
    role: primary
  - type: official_energy_data_table
    citation: "U.S. Energy Information Administration. Gulf Coast (PADD 3) Stocks of Crude Oil and Petroleum Products."
    location: https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r30_w.htm
    quality_tier: A
    role: supporting
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, pullback-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13044_XTI_PADD3_DRAW_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "April-October Gulf Coast PADD 3 crude-stock draw pressure window with one signal per month; estimate 3-7 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.05
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, closed-bar-reaction, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
target_modules: [framework-init, trade-entry, trade-management, news-gate, friday-close, setfile-risk]
---

# XTI Gulf Coast PADD 3 Stockdraw Momentum

## Hypothesis

EIA publishes weekly Gulf Coast PADD 3 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR tables. PADD 3 is a refinery,
pipeline, storage, and export-heavy physical crude region, so repeated regional
stock draws can create a different WTI pressure sleeve than national crude
inventory reactions or Cushing delivery-hub tightness.

This card uses EIA only as structural lineage. The EA imports no EIA data,
stock series, CSV, web page, analyst forecast, or external calendar at runtime.
It trades deterministic price-only confirmation on Darwinex `XTIUSD.DWX` D1
bars inside an April-October Gulf Coast draw-pressure window.

## Non-Duplicate Boundary

This is not `QM5_12988_xti-eia-inventory-momentum`, which requires two same-way
WPSR proxy reactions and a broad crude-inventory breakout. It is not Cushing
delivery-hub tightness (`QM5_12828`/`QM5_12829`), not product-specific gasoline,
distillate, residual fuel, propane, product-supplied, or days-of-supply logic,
and not PSM, DPR, field production, import/export, refinery utilization, SPR,
COT, rig-count, OPEC, IEA/STEO, expiry/roll, XTI/XNG, oil-metal, XAU/XAG, XNG
RSI, or index beta.

The edge is narrower: a long-only, monthly-capped Gulf Coast crude-stock draw
pressure proxy that requires a short pullback, a bullish Wednesday/Thursday
WPSR-window reclaim bar, a local high reclaim, and a rising D1 SMA.

## Rules

The strategy is a deterministic long-only D1 reaction model. On each new D1 bar
it inspects the previous completed bar. The signal bar must be Wednesday or
Thursday, inside the April-October PADD 3 draw-pressure season, and the EA may
consume at most one signal per broker-calendar month.

Entry requires:

- a short pullback over the configured lookback;
- a bullish signal bar with ATR-normalized range/body;
- a close in the upper portion of the signal bar;
- a close above a rising `SMA(70)`;
- a close reclaiming the prior short local high;
- spread below the configured cap and no open position for this EA magic.

The EA enters `XTIUSD.DWX` long at market with ATR-defined hard stop and target.
It exits on ATR stop, ATR target, max-hold timeout, close below the SMA trend
filter, leaving the April-October window, framework Friday close, or kill
switch.

## Market and Timeframe

- Host symbol: `XTIUSD.DWX`.
- Timeframe: D1 only.
- Magic slot: 0.
- Direction: long only.
- Runtime data: native MT5 OHLC, spread, ATR/SMA helpers, broker calendar.

## Parameters

| param | default | range | meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 4 | 4 | First Gulf Coast draw-pressure month |
| `strategy_season_end_month` | 10 | 10 | Last Gulf Coast draw-pressure month |
| `strategy_report_start_dow` | 3 | 3 | Wednesday WPSR proxy start |
| `strategy_report_end_dow` | 4 | 4 | Thursday WPSR holiday-drift proxy |
| `strategy_pullback_lookback` | 6 | 4-8 | Completed D1 bars used for pre-signal pullback |
| `strategy_reclaim_lookback` | 3 | 2-5 | Prior local high window reclaimed by signal close |
| `strategy_min_pullback_atr` | 0.35 | 0.20-0.60 | Minimum pre-signal pullback in ATR units |
| `strategy_sma_period` | 70 | 50-90 | D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period |
| `strategy_min_range_atr` | 0.65 | 0.45-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.12-0.35 | Minimum bullish body in ATR units |
| `strategy_min_close_location` | 0.68 | 0.58-0.80 | Minimum close location inside signal bar |
| `strategy_atr_sl_mult` | 2.85 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.70 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, portfolio gates, or live setfiles.

## R1-R4 Verdict

- R1 PASS: official EIA PADD 3 crude-stock data and WPSR tables.
- R2 PASS: deterministic D1 calendar, pullback, reclaim, SMA, ATR, spread,
  stop, target, and time-exit rules.
- R3 PASS: `XTIUSD.DWX` exists in the DWX symbol matrix.
- R4 PASS: no ML, no grid, no martingale, one position per magic/symbol, and
  no external runtime feed.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, slot guard, parameter guard, spread cap,
  April-October season, and one-signal-per-month gate.
- trade_entry: WPSR proxy bar pullback-reclaim momentum with SMA trend filter.
- trade_management: SMA invalidation, season invalidation, max-hold exit.
- trade_close: ATR stop/target plus deterministic strategy exits and framework
  Friday close.

## Pipeline

G0 approved for Q02 on 2026-07-07 by mission-directed commodity/energy sleeve
criteria. Q02 must validate or reject the mechanical Darwinex realization.
*** Add File: artifacts/cards_approved/QM5_13044_xti-padd3-draw.md
---
ea_id: QM5_13044
slug: xti-padd3-draw
type: strategy
strategy_id: EIA-XTI-PADD3-DRAW-2026
source_id: EIA-XTI-PADD3-DRAW-2026
source_citation: "U.S. Energy Information Administration Gulf Coast (PADD 3) weekly crude-oil stocks excluding SPR and Weekly Petroleum Status Report."
source_citations:
  - type: official_energy_data
    citation: "U.S. Energy Information Administration. Weekly Gulf Coast (PADD 3) Ending Stocks excluding SPR of Crude Oil."
    location: https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP31
    quality_tier: A
    role: primary
  - type: official_energy_report
    citation: "U.S. Energy Information Administration. Weekly Petroleum Status Report."
    location: https://www.eia.gov/petroleum/supply/weekly/
    quality_tier: A
    role: supporting
strategy_type_flags: [official-release-window, structural-energy, pullback-continuation, trend-filter-ma, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13044_XTI_PADD3_DRAW_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "April-October Gulf Coast PADD 3 crude-stock draw pressure window with one signal per month; estimate 3-7 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.05
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
modules_used: [calendar-window, closed-bar-reaction, sma-trend-filter, atr-risk, time-stop]
hard_rules_at_risk: [HR4_RISK_FIXED_BACKTEST, single-symbol-host-guard, one-position-per-magic, no-external-runtime-data]
---

# XTI Gulf Coast PADD 3 Stockdraw Momentum

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/approved/QM5_13044_xti-padd3-draw_card.md`.

## Hypothesis

EIA publishes weekly Gulf Coast PADD 3 crude-oil stock levels excluding the SPR
inside the official petroleum data family and WPSR tables. This card tests a
price-only `XTIUSD.DWX` D1 proxy for Gulf Coast crude-stock draw pressure:
inside April-October, a Wednesday/Thursday WPSR-window bullish reclaim after a
short pullback may continue for several D1 bars.

The EA imports no EIA data, CSV, web page, forecast, or external calendar at
runtime. It uses MT5 OHLC, spread, broker calendar, ATR, SMA, standard V5 news
and Friday-close handling, and one `RISK_FIXED=1000` D1 backtest setfile.

## Non-Duplicate Boundary

This is not broad two-event WPSR inventory momentum, not Cushing delivery-hub
tightness, not product-specific gasoline/distillate/residual/propane/product
supplied, not days-of-supply, PSM, DPR, production, import/export, refinery,
SPR, COT, rig-count, OPEC, IEA/STEO, expiry/roll, XTI/XNG, oil-metal,
XAU/XAG, XNG RSI, or index logic.

## Risk

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. The build does not touch T_Live, AutoTrading, deploy
manifests, live setfiles, or portfolio gates.
*** Add File: framework/EAs/QM5_13044_xti-padd3-draw/docs/strategy_card.md
---
ea_id: QM5_13044
slug: xti-padd3-draw
type: strategy
strategy_id: EIA-XTI-PADD3-DRAW-2026
source_id: EIA-XTI-PADD3-DRAW-2026
status: APPROVED
pipeline_phase: Q02
---

# XTI Gulf Coast PADD 3 Stockdraw Momentum

Build-time strategy-card copy. Canonical card:
`strategy-seeds/cards/approved/QM5_13044_xti-padd3-draw_card.md`.

This EA trades `XTIUSD.DWX` D1 only. It expresses official EIA Gulf Coast
PADD 3 crude-stock draw pressure as a price-only monthly-capped April-October
WPSR-window pullback-reclaim long setup. It uses no external runtime feed, no
ML, no grid, no martingale, one position per magic, V5 news/Friday close, and
Q02 `RISK_FIXED=1000`.
*** Add File: framework/EAs/QM5_13044_xti-padd3-draw/SPEC.md
# QM5_13044_xti-padd3-draw - Strategy Spec

**EA ID:** QM5_13044
**Slug:** `xti-padd3-draw`
**Source:** `EIA-XTI-PADD3-DRAW-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-07

## 1. Strategy Logic

This EA implements a low-frequency WTI Gulf Coast PADD 3 crude-stock draw
pressure setup on `XTIUSD.DWX`. On each new D1 bar it inspects the previous
completed D1 bar, requiring that bar to be Wednesday or Thursday in broker time
and inside the April-October Gulf Coast stockdraw pressure window. It consumes
at most one signal per broker-calendar month.

Entries require a short pre-signal pullback, a bullish ATR-sized WPSR proxy
reaction, upper-range close location, local high reclaim, close above a rising
`SMA(70)`, and fixed single-symbol WTI scope. Positions use ATR hard stop, ATR
target, SMA trend-failure exit, seasonal invalidation, max-hold exit, standard
V5 news and Friday close handling, and no runtime external data.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_season_start_month` | 4 | fixed | First Gulf Coast stockdraw pressure month |
| `strategy_season_end_month` | 10 | fixed | Last Gulf Coast stockdraw pressure month |
| `strategy_report_start_dow` | 3 | fixed | First broker day-of-week for WPSR proxy window |
| `strategy_report_end_dow` | 4 | fixed | Last broker day-of-week for WPSR holiday drift |
| `strategy_pullback_lookback` | 6 | 4-8 | Completed D1 bars used for pre-signal pullback check |
| `strategy_reclaim_lookback` | 3 | 2-5 | Local high window reclaimed by signal close |
| `strategy_min_pullback_atr` | 0.35 | 0.20-0.60 | Minimum pullback before signal in ATR units |
| `strategy_sma_period` | 70 | 50-90 | D1 trend filter period |
| `strategy_sma_slope_shift` | 8 | 4-12 | Completed D1 bars used for SMA slope confirmation |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal sizing and stop/target |
| `strategy_min_range_atr` | 0.65 | 0.45-0.90 | Minimum signal-bar range in ATR units |
| `strategy_min_body_atr` | 0.20 | 0.12-0.35 | Minimum bullish signal-bar body in ATR units |
| `strategy_min_close_location` | 0.68 | 0.58-0.80 | Minimum close location within signal-bar range |
| `strategy_atr_sl_mult` | 2.85 | 2.0-3.6 | ATR stop distance |
| `strategy_atr_tp_mult` | 2.70 | 2.0-4.0 | ATR target distance |
| `strategy_max_hold_days` | 8 | 5-12 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 3-7.
- Direction: long only.
- Typical hold: several D1 bars, capped by ATR target/stop, SMA trend-failure,
  stale-position, and seasonal invalidation guards.
- Regime preference: April-October Gulf Coast/PADD 3 stockdraw pressure windows.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

U.S. Energy Information Administration Gulf Coast PADD 3 crude stocks and WPSR:

- https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCESTP31
- https://www.eia.gov/dnav/pet/pet_stoc_wstk_dcu_r30_w.htm
- https://www.eia.gov/petroleum/supply/weekly/

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
*** Add File: framework/EAs/QM5_13044_xti-padd3-draw/sets/QM5_13044_xti-padd3-draw_XTIUSD.DWX_D1_backtest.set
;==========================================================
; QM5 Set File
; ea_id:        13044
; ea_slug:      xti-padd3-draw
; ea_version:   v5.0
; set_version:  s20260707-001
; symbol:       XTIUSD.DWX
; timeframe:    D1
; environment:  backtest
; magic_slot:   0
; risk_mode:    FIXED
; portfolio_weight: 1
; build_hash:   PENDING
; author:       Development
; date:         2026-07-07
;==========================================================
qm_ea_id=13044
qm_magic_slot_offset=0
RISK_FIXED=1000
RISK_PERCENT=0
PORTFOLIO_WEIGHT=1
; strategy-specific params from card/input defaults must be appended below this line
; card_defaults_source=C:\QM\repo\artifacts\cards_approved\QM5_13044_xti-padd3-draw.md
strategy_season_start_month=4
strategy_season_end_month=10
strategy_report_start_dow=3
strategy_report_end_dow=4
strategy_pullback_lookback=6
strategy_reclaim_lookback=3
strategy_min_pullback_atr=0.35
strategy_sma_period=70
strategy_sma_slope_shift=8
strategy_atr_period=20
strategy_min_range_atr=0.65
strategy_min_body_atr=0.20
strategy_min_close_location=0.68
strategy_atr_sl_mult=2.85
strategy_atr_tp_mult=2.70
strategy_max_hold_days=8
strategy_max_spread_points=1000

*** Add File: framework/EAs/QM5_13044_xti-padd3-draw/QM5_13044_xti-padd3-draw.mq5
#property strict
#property version   "5.0"
#property description "QM5_13044 XTI Gulf Coast PADD3 stockdraw momentum"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13044 - XTI Gulf Coast PADD 3 Stockdraw Momentum
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - uses Wednesday/Thursday as the weekly EIA PADD 3 crude-stock WPSR proxy
//   - requires April-October season, monthly cap, pullback, local reclaim,
//     bullish ATR-sized reaction, and rising SMA
//   - ATR stop/target, SMA/season/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13044;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_season_start_month   = 4;
input int    strategy_season_end_month     = 10;
input int    strategy_report_start_dow     = 3;
input int    strategy_report_end_dow       = 4;
input int    strategy_pullback_lookback    = 6;
input int    strategy_reclaim_lookback     = 3;
input double strategy_min_pullback_atr     = 0.35;
input int    strategy_sma_period           = 70;
input int    strategy_sma_slope_shift      = 8;
input int    strategy_atr_period           = 20;
input double strategy_min_range_atr        = 0.65;
input double strategy_min_body_atr         = 0.20;
input double strategy_min_close_location   = 0.68;
input double strategy_atr_sl_mult          = 2.85;
input double strategy_atr_tp_mult          = 2.70;
input int    strategy_max_hold_days        = 8;
input int    strategy_max_spread_points    = 1000;

int g_last_signal_month_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_MonthInWindow(const int month, const int start_month, const int end_month)
  {
   if(month < 1 || month > 12 || start_month < 1 || start_month > 12 || end_month < 1 || end_month > 12)
      return false;
   if(start_month <= end_month)
      return (month >= start_month && month <= end_month);
   return (month >= start_month || month <= end_month);
  }

bool Strategy_IsPadd3DrawSeason(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return Strategy_MonthInWindow(dt.mon, strategy_season_start_month, strategy_season_end_month);
  }

bool Strategy_DowInWindow(const int dow, const int start_dow, const int end_dow)
  {
   if(dow < 0 || dow > 6 || start_dow < 0 || start_dow > 6 || end_dow < 0 || end_dow > 6)
      return false;
   if(start_dow <= end_dow)
      return (dow >= start_dow && dow <= end_dow);
   return (dow >= start_dow || dow <= end_dow);
  }

bool Strategy_IsReportProxyDay(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return Strategy_DowInWindow(dt.day_of_week, strategy_report_start_dow, strategy_report_end_dow);
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool Strategy_HighestHighExcludingSignal(const int lookback, double &highest_high)
  {
   highest_high = -DBL_MAX;
   const int bars = MathMax(1, lookback);
   for(int shift = 2; shift < bars + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: compact D1 reclaim state behind new-bar gate.
      if(high <= 0.0)
         return false;
      highest_high = MathMax(highest_high, high);
     }
   return (highest_high > 0.0);
  }

bool Strategy_LoadPadd3DrawState(double &atr_last,
                                 int &signal_day_key,
                                 int &signal_month_key)
  {
   atr_last = 0.0;
   signal_day_key = 0;
   signal_month_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 calendar state behind new-bar gate.
   if(signal_time <= 0 || !Strategy_IsReportProxyDay(signal_time))
      return false;
   if(!Strategy_IsPadd3DrawSeason(signal_time) || !Strategy_IsPadd3DrawSeason(TimeCurrent()))
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low || signal_close <= signal_open)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);
   const double sma_past = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_past <= 0.0)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = MathAbs(signal_close - signal_open);
   const double close_location = (signal_close - signal_low) / signal_range;
   if(signal_range < strategy_min_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_atr * atr_last)
      return false;
   if(close_location < strategy_min_close_location)
      return false;
   if(signal_close <= sma_last || sma_last <= sma_past)
      return false;

   const int pre_start_shift = 1 + MathMax(2, strategy_pullback_lookback);
   const double pre_start_close = iClose(_Symbol, PERIOD_D1, pre_start_shift); // perf-allowed: compact D1 pullback state.
   const double pre_end_close = iClose(_Symbol, PERIOD_D1, 2);                 // perf-allowed: compact D1 pullback state.
   if(pre_start_close <= 0.0 || pre_end_close <= 0.0)
      return false;
   const double pullback = pre_start_close - pre_end_close;
   if(pullback < strategy_min_pullback_atr * atr_last)
      return false;

   double reclaim_high = 0.0;
   if(!Strategy_HighestHighExcludingSignal(strategy_reclaim_lookback, reclaim_high))
      return false;
   if(signal_close <= reclaim_high)
      return false;

   signal_day_key = Strategy_DayKey(signal_time);
   signal_month_key = Strategy_MonthKey(signal_time);
   return (signal_day_key > 0 && signal_month_key > 0);
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 SMA exit behind new-bar gate.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_sma_period, 1, PRICE_CLOSE);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      bool should_close = false;
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type != POSITION_TYPE_BUY)
         should_close = true;
      if(!Strategy_IsPadd3DrawSeason(now))
         should_close = true;
      if(close_last > 0.0 && sma_last > 0.0 && close_last < sma_last)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_season_start_month < 1 || strategy_season_start_month > 12 || strategy_season_end_month < 1 || strategy_season_end_month > 12)
      return true;
   if(strategy_report_start_dow < 0 || strategy_report_start_dow > 6 || strategy_report_end_dow < 0 || strategy_report_end_dow > 6)
      return true;
   if(strategy_pullback_lookback < 2 || strategy_reclaim_lookback < 1)
      return true;
   if(strategy_sma_period <= 1 || strategy_sma_slope_shift <= 0 || strategy_atr_period <= 1)
      return true;
   if(strategy_min_pullback_atr <= 0.0 || strategy_min_range_atr <= 0.0 || strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_min_close_location <= 0.0 || strategy_min_close_location >= 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_13044_XTI_PADD3_DRAW";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double atr_last = 0.0;
   int signal_day_key = 0;
   int signal_month_key = 0;
   if(!Strategy_LoadPadd3DrawState(atr_last, signal_day_key, signal_month_key))
      return false;
   if(signal_day_key <= 0 || signal_month_key <= 0 || signal_month_key == g_last_signal_month_key)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0 || req.tp <= entry_price)
      return false;

   req.reason = "XTI_PADD3_DRAW_LONG";
   g_last_signal_month_key = signal_month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13044\",\"ea\":\"xti-padd3-draw\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
