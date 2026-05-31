#property strict
#property version   "5.0"
#property description "QM5_10758 TradingView SMC Order Block Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10758;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
enum StrategyMode
  {
   STRATEGY_MODE_BREAKOUT = 0,
   STRATEGY_MODE_ORDER_BLOCK = 1,
   STRATEGY_MODE_COMBINED = 2
  };

input int          strategy_pivot_lookback       = 20;
input int          strategy_pivot_wing           = 2;
input StrategyMode strategy_mode                 = STRATEGY_MODE_COMBINED;
input int          strategy_atr_period           = 14;
input int          strategy_vol_lookback         = 50;
input double       strategy_vol_percentile_min   = 50.0;
input double       strategy_atr_sl_mult          = 2.0;
input double       strategy_trail_activation_r   = 1.5;
input double       strategy_trail_atr_mult       = 2.0;
input bool         strategy_use_fixed_2r_cap     = false;
input bool         strategy_use_structure_stop   = false;
input double       strategy_structure_atr_buffer = 0.25;
input double       strategy_max_stop_atr_mult    = 4.0;
input int          strategy_ob_min_candles       = 2;
input double       strategy_rejection_body_min   = 0.55;
input bool         strategy_supertrend_enabled   = false;
input int          strategy_supertrend_period    = 10;
input double       strategy_supertrend_mult      = 3.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

double BarOpen(const int shift)
  {
   return iOpen(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke order-block candle structure, closed-bar only.
  }

double BarHigh(const int shift)
  {
   return iHigh(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke pivot/order-block structure, closed-bar only.
  }

double BarLow(const int shift)
  {
   return iLow(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke pivot/order-block structure, closed-bar only.
  }

double BarClose(const int shift)
  {
   return iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift); // perf-allowed: bespoke breakout/order-block confirmation, closed-bar only.
  }

bool ReadBar(const int shift, double &open, double &high, double &low, double &close)
  {
   open = BarOpen(shift);
   high = BarHigh(shift);
   low = BarLow(shift);
   close = BarClose(shift);
   return (open > 0.0 && high > 0.0 && low > 0.0 && close > 0.0 && high >= low);
  }

bool IsPivotHigh(const int shift, const int wing)
  {
   const double h = BarHigh(shift);
   if(h <= 0.0 || wing < 1)
      return false;
   for(int k = 1; k <= wing; ++k)
     {
      if(BarHigh(shift - k) >= h || BarHigh(shift + k) >= h)
         return false;
     }
   return true;
  }

bool IsPivotLow(const int shift, const int wing)
  {
   const double l = BarLow(shift);
   if(l <= 0.0 || wing < 1)
      return false;
   for(int k = 1; k <= wing; ++k)
     {
      if(BarLow(shift - k) <= l || BarLow(shift + k) <= l)
         return false;
     }
   return true;
  }

double RecentResistance()
  {
   const int lookback = (int)MathMax(strategy_pivot_lookback, strategy_pivot_wing + 2);
   const int wing = (int)MathMax(strategy_pivot_wing, 1);
   for(int shift = wing + 1; shift <= lookback + wing; ++shift)
     {
      if(IsPivotHigh(shift, wing))
         return BarHigh(shift);
     }

   double highest = 0.0;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double h = BarHigh(shift);
      if(h > highest)
         highest = h;
     }
   return highest;
  }

double RecentSupport()
  {
   const int lookback = (int)MathMax(strategy_pivot_lookback, strategy_pivot_wing + 2);
   const int wing = (int)MathMax(strategy_pivot_wing, 1);
   for(int shift = wing + 1; shift <= lookback + wing; ++shift)
     {
      if(IsPivotLow(shift, wing))
         return BarLow(shift);
     }

   double lowest = DBL_MAX;
   for(int shift = 2; shift <= lookback + 1; ++shift)
     {
      const double l = BarLow(shift);
      if(l > 0.0 && l < lowest)
         lowest = l;
     }
   return (lowest == DBL_MAX) ? 0.0 : lowest;
  }

bool VolatilityPasses()
  {
   const int lookback = (int)MathMax(strategy_vol_lookback, 5);
   const double atr_now = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   int samples = 0;
   int below_or_equal = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
      if(atr <= 0.0)
         continue;
      samples++;
      if(atr <= atr_now)
         below_or_equal++;
     }

   if(samples < 5)
      return false;

   const double percentile = 100.0 * (double)below_or_equal / (double)samples;
   return (percentile >= strategy_vol_percentile_min);
  }

bool SupertrendAllows(const int direction)
  {
   if(!strategy_supertrend_enabled)
      return true;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_supertrend_period, 1);
   const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_supertrend_period, 1);
   const double close1 = BarClose(1);
   if(atr <= 0.0 || ema <= 0.0 || close1 <= 0.0)
      return false;

   const double band = strategy_supertrend_mult * atr;
   if(direction > 0)
      return (close1 > ema - band);
   return (close1 < ema + band);
  }

bool FindOrderBlock(const int direction, double &zone_low, double &zone_high)
  {
   zone_low = 0.0;
   zone_high = 0.0;
   const int min_candles = (int)MathMax(strategy_ob_min_candles, 1);
   const int lookback = (int)MathMax(strategy_pivot_lookback, min_candles + 3);

   for(int start = 2; start <= lookback; ++start)
     {
      int count = 0;
      double low = DBL_MAX;
      double high = 0.0;
      for(int shift = start; shift < start + min_candles; ++shift)
        {
         double o, h, l, c;
         if(!ReadBar(shift, o, h, l, c))
            break;

         const bool candle_matches = (direction > 0) ? (c < o) : (c > o);
         if(!candle_matches)
            break;

         count++;
         if(l < low)
            low = l;
         if(h > high)
            high = h;
        }

      if(count >= min_candles && low < DBL_MAX && high > 0.0)
        {
         zone_low = low;
         zone_high = high;
         return true;
        }
     }

   return false;
  }

bool StrongRejectionFromZone(const int direction, const double zone_low, const double zone_high)
  {
   double o, h, l, c;
   if(!ReadBar(1, o, h, l, c))
      return false;

   const double range = h - l;
   const double body = MathAbs(c - o);
   if(range <= 0.0 || body / range < strategy_rejection_body_min)
      return false;

   if(direction > 0)
     {
      const double lower_wick = MathMin(o, c) - l;
      return (c > o && l <= zone_high && c > zone_high && lower_wick >= body * 0.25);
     }

   const double upper_wick = h - MathMax(o, c);
   return (c < o && h >= zone_low && c < zone_low && upper_wick >= body * 0.25);
  }

double BuildStop(const QM_OrderType side,
                 const double entry,
                 const double structure_stop,
                 const double atr_value)
  {
   double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(strategy_use_structure_stop && structure_stop > 0.0)
      sl = structure_stop;

   if(sl <= 0.0 || atr_value <= 0.0)
      return 0.0;

   const double max_dist = atr_value * strategy_max_stop_atr_mult;
   if(max_dist > 0.0)
     {
      if(QM_OrderTypeIsBuy(side) && entry - sl > max_dist)
         sl = entry - max_dist;
      if(!QM_OrderTypeIsBuy(side) && sl - entry > max_dist)
         sl = entry + max_dist;
     }

   return NormalizeDouble(sl, _Digits);
  }

void FillRequest(QM_EntryRequest &req,
                 const QM_OrderType side,
                 const double entry,
                 const double sl,
                 const string reason)
  {
   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = strategy_use_fixed_2r_cap ? QM_TakeRR(_Symbol, side, entry, sl, 2.0) : 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card does not authorize a separate time/spread filter; framework news and Friday gates apply.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!VolatilityPasses())
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double close1 = BarClose(1);
   const double close2 = BarClose(2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(strategy_mode == STRATEGY_MODE_BREAKOUT || strategy_mode == STRATEGY_MODE_COMBINED)
     {
      const double resistance = RecentResistance();
      const double support = RecentSupport();

      if(resistance > 0.0 && close1 > resistance && close2 <= resistance && SupertrendAllows(1))
        {
         const double structure_sl = support - atr * strategy_structure_atr_buffer;
         const double sl = BuildStop(QM_BUY, ask, structure_sl, atr);
         if(sl > 0.0 && sl < ask)
           {
            FillRequest(req, QM_BUY, ask, sl, "tv_smc_breakout_long");
            return true;
           }
        }

      if(support > 0.0 && close1 < support && close2 >= support && SupertrendAllows(-1))
        {
         const double structure_sl = resistance + atr * strategy_structure_atr_buffer;
         const double sl = BuildStop(QM_SELL, bid, structure_sl, atr);
         if(sl > bid)
           {
            FillRequest(req, QM_SELL, bid, sl, "tv_smc_breakout_short");
            return true;
           }
        }
     }

   if(strategy_mode == STRATEGY_MODE_ORDER_BLOCK || strategy_mode == STRATEGY_MODE_COMBINED)
     {
      double zone_low = 0.0;
      double zone_high = 0.0;

      if(FindOrderBlock(1, zone_low, zone_high) &&
         StrongRejectionFromZone(1, zone_low, zone_high) &&
         SupertrendAllows(1))
        {
         const double structure_sl = zone_low - atr * strategy_structure_atr_buffer;
         const double sl = BuildStop(QM_BUY, ask, structure_sl, atr);
         if(sl > 0.0 && sl < ask)
           {
            FillRequest(req, QM_BUY, ask, sl, "tv_smc_order_block_long");
            return true;
           }
        }

      if(FindOrderBlock(-1, zone_low, zone_high) &&
         StrongRejectionFromZone(-1, zone_low, zone_high) &&
         SupertrendAllows(-1))
        {
         const double structure_sl = zone_high + atr * strategy_structure_atr_buffer;
         const double sl = BuildStop(QM_SELL, bid, structure_sl, atr);
         if(sl > bid)
           {
            FillRequest(req, QM_SELL, bid, sl, "tv_smc_order_block_short");
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || sl <= 0.0)
         continue;

      const double risk_dist = MathAbs(open_price - sl);
      if(risk_dist <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved >= risk_dist * strategy_trail_activation_r)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card exits through initial stop, optional fixed 2R cap, ATR trailing, and framework Friday close.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false; // defer to QM_NewsAllowsTrade(...)
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
