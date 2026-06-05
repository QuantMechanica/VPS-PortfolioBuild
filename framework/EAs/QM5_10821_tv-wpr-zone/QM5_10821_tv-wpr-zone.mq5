#property strict
#property version   "5.0"
#property description "QM5_10821 TradingView Williams R Zone Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  - closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        - risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() - use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly -
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
input int    qm_ea_id                   = 10821;
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
input int    strategy_wpr_length        = 14;    // Card: Williams %R length 14, 21, 34.
input bool   strategy_use_ma_filter     = true;  // Card: selected MA trend filter, default EMA(20).
input int    strategy_ma_method         = 0;     // 0=EMA, 1=SMA.
input int    strategy_ma_length         = 20;    // Card: EMA20/SMA20/EMA50.
input bool   strategy_use_chop_filter   = true;  // Card: CI filter enabled by baseline.
input int    strategy_chop_length       = 12;    // Card: Choppiness Index(12).
input double strategy_chop_threshold    = 38.2;  // Card: 38.2, 42.0, disabled.
input bool   strategy_use_volume_filter = true;  // Card: volume filter on/off.
input int    strategy_volume_ma_length  = 50;    // Card: broker tick volume MA(50).
input double strategy_volume_ratio      = 1.0;   // Card: volume ratio 1.0, 1.2.
input bool   strategy_use_bbw_filter    = false; // Card: optional Bollinger Band Width filter.
input int    strategy_bbw_period        = 20;
input double strategy_bbw_deviation     = 2.0;
input int    strategy_bbw_ma_length     = 20;
input bool   strategy_use_supertrend    = false; // Card: optional SuperTrend ATR(10) factor 3.0.
input int    strategy_supertrend_atr    = 10;
input double strategy_supertrend_factor = 3.0;
input int    strategy_supertrend_bars   = 80;
input int    strategy_atr_period        = 14;    // Card: ATR(14) bracket.
input double strategy_atr_sl_mult       = 1.5;   // Card: stop = 1.5 * ATR.
input double strategy_atr_tp_mult       = 2.0;   // Card: target = 2.0 * ATR.

int strategy_cached_wpr_signal = 0;              // +1 long, -1 short, 0 none on last evaluated closed bar.

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only - runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_wpr_length <= 1)
      return true;
   if(strategy_ma_length <= 0 || strategy_ma_method < 0 || strategy_ma_method > 1)
      return true;
   if(strategy_chop_length <= 1 || strategy_chop_threshold <= 0.0)
      return true;
   if(strategy_volume_ma_length <= 0 || strategy_volume_ratio <= 0.0)
      return true;
   if(strategy_bbw_period <= 1 || strategy_bbw_deviation <= 0.0 || strategy_bbw_ma_length <= 0)
      return true;
   if(strategy_supertrend_atr <= 0 || strategy_supertrend_factor <= 0.0 || strategy_supertrend_bars <= strategy_supertrend_atr + 2)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
      return true;
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
   strategy_cached_wpr_signal = 0;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   double hh1 = -DBL_MAX;
   double ll1 = DBL_MAX;
   double hh2 = -DBL_MAX;
   double ll2 = DBL_MAX;
   for(int i = 1; i <= strategy_wpr_length; ++i)
     {
      const double h1 = iHigh(_Symbol, tf, i);      // perf-allowed: Williams %R range read on closed-bar path.
      const double l1 = iLow(_Symbol, tf, i);       // perf-allowed: Williams %R range read on closed-bar path.
      const double h2 = iHigh(_Symbol, tf, i + 1);  // perf-allowed: prior Williams %R range read.
      const double l2 = iLow(_Symbol, tf, i + 1);   // perf-allowed: prior Williams %R range read.
      if(h1 <= 0.0 || l1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
         return false;
      hh1 = MathMax(hh1, h1);
      ll1 = MathMin(ll1, l1);
      hh2 = MathMax(hh2, h2);
      ll2 = MathMin(ll2, l2);
     }

   const double close1 = iClose(_Symbol, tf, 1);    // perf-allowed: Williams %R close on closed-bar path.
   const double close2 = iClose(_Symbol, tf, 2);    // perf-allowed: prior Williams %R close.
   if(close1 <= 0.0 || close2 <= 0.0 || hh1 <= ll1 || hh2 <= ll2)
      return false;

   const double wpr1 = -100.0 * (hh1 - close1) / (hh1 - ll1);
   const double wpr2 = -100.0 * (hh2 - close2) / (hh2 - ll2);
   bool long_signal = (wpr2 <= -80.0 && wpr1 > -80.0);
   bool short_signal = (wpr2 >= -20.0 && wpr1 < -20.0);

   if(strategy_use_ma_filter)
     {
      const double ma = (strategy_ma_method == 1)
                        ? QM_SMA(_Symbol, tf, strategy_ma_length, 1)
                        : QM_EMA(_Symbol, tf, strategy_ma_length, 1);
      if(ma <= 0.0)
         return false;
      if(long_signal && close1 <= ma)
         long_signal = false;
      if(short_signal && close1 >= ma)
         short_signal = false;
     }

   if(strategy_use_chop_filter)
     {
      double chop_high = -DBL_MAX;
      double chop_low = DBL_MAX;
      double tr_sum = 0.0;
      for(int i = 1; i <= strategy_chop_length; ++i)
        {
         const double hi = iHigh(_Symbol, tf, i);       // perf-allowed: Choppiness Index bounded OHLC read.
         const double lo = iLow(_Symbol, tf, i);        // perf-allowed: Choppiness Index bounded OHLC read.
         const double pc = iClose(_Symbol, tf, i + 1);  // perf-allowed: Choppiness Index true-range read.
         if(hi <= 0.0 || lo <= 0.0 || pc <= 0.0)
            return false;
         chop_high = MathMax(chop_high, hi);
         chop_low = MathMin(chop_low, lo);
         tr_sum += MathMax(hi - lo, MathMax(MathAbs(hi - pc), MathAbs(lo - pc)));
        }
      const double range = chop_high - chop_low;
      if(range <= 0.0 || tr_sum <= 0.0)
         return false;
      const double ci = 100.0 * MathLog(tr_sum / range) / MathLog((double)strategy_chop_length);
      if(ci >= strategy_chop_threshold)
        {
         long_signal = false;
         short_signal = false;
        }
     }

   if(strategy_use_volume_filter)
     {
      const long vol1 = iVolume(_Symbol, tf, 1);       // perf-allowed: card requires broker tick-volume filter.
      double vol_sum = 0.0;
      for(int i = 1; i <= strategy_volume_ma_length; ++i)
        {
         const long v = iVolume(_Symbol, tf, i);       // perf-allowed: bounded tick-volume MA on closed-bar path.
         if(v < 0)
            return false;
         vol_sum += (double)v;
        }
      const double vol_ma = vol_sum / (double)strategy_volume_ma_length;
      if(vol1 <= 0 || vol_ma <= 0.0 || (double)vol1 <= vol_ma * strategy_volume_ratio)
        {
         long_signal = false;
         short_signal = false;
        }
     }

   if(strategy_use_bbw_filter)
     {
      double bbw_sum = 0.0;
      for(int i = 1; i <= strategy_bbw_ma_length; ++i)
        {
         const double up = QM_BB_Upper(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, i);
         const double mid = QM_BB_Middle(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, i);
         const double lo = QM_BB_Lower(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, i);
         if(up <= 0.0 || mid <= 0.0 || lo <= 0.0)
            return false;
         bbw_sum += (up - lo) / mid;
        }
      const double bbw_ma = bbw_sum / (double)strategy_bbw_ma_length;
      const double up1 = QM_BB_Upper(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, 1);
      const double mid1 = QM_BB_Middle(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, 1);
      const double lo1 = QM_BB_Lower(_Symbol, tf, strategy_bbw_period, strategy_bbw_deviation, 1);
      if(up1 <= 0.0 || mid1 <= 0.0 || lo1 <= 0.0)
         return false;
      const double bbw1 = (up1 - lo1) / mid1;
      if(bbw1 <= bbw_ma)
        {
         long_signal = false;
         short_signal = false;
        }
     }

   if(strategy_use_supertrend)
     {
      bool st_init = false;
      double st_upper = 0.0;
      double st_lower = 0.0;
      double st_prev_close = 0.0;
      int st_dir = 0;
      for(int shift = strategy_supertrend_bars; shift >= 1; --shift)
        {
         const double atr = QM_ATR(_Symbol, tf, strategy_supertrend_atr, shift);
         const double hi = iHigh(_Symbol, tf, shift);     // perf-allowed: optional SuperTrend bounded recursion.
         const double lo = iLow(_Symbol, tf, shift);      // perf-allowed: optional SuperTrend bounded recursion.
         const double cl = iClose(_Symbol, tf, shift);    // perf-allowed: optional SuperTrend bounded recursion.
         if(atr <= 0.0 || hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
            continue;
         const double hl2 = (hi + lo) * 0.5;
         const double basic_upper = hl2 + strategy_supertrend_factor * atr;
         const double basic_lower = hl2 - strategy_supertrend_factor * atr;
         if(!st_init)
           {
            st_upper = basic_upper;
            st_lower = basic_lower;
            st_dir = (cl >= hl2) ? 1 : -1;
            st_prev_close = cl;
            st_init = true;
            continue;
           }
         const double new_upper = (basic_upper < st_upper || st_prev_close > st_upper) ? basic_upper : st_upper;
         const double new_lower = (basic_lower > st_lower || st_prev_close < st_lower) ? basic_lower : st_lower;
         int new_dir = st_dir;
         if(st_dir == -1)
            new_dir = (cl > st_upper) ? 1 : -1;
         else
            new_dir = (cl < st_lower) ? -1 : 1;
         st_upper = new_upper;
         st_lower = new_lower;
         st_prev_close = cl;
         st_dir = new_dir;
        }
      if(!st_init)
         return false;
      if(long_signal && st_dir != 1)
         long_signal = false;
      if(short_signal && st_dir != -1)
         short_signal = false;
     }

   if(!long_signal && !short_signal)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_tp_mult);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;
   if(req.type == QM_BUY && (req.sl >= entry || req.tp <= entry))
      return false;
   if(req.type == QM_SELL && (req.sl <= entry || req.tp >= entry))
      return false;

   strategy_cached_wpr_signal = long_signal ? 1 : -1;
   req.reason = long_signal ? "WPR_ZONE_LONG" : "WPR_ZONE_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or add-on logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_cached_wpr_signal == 0)
      return false;

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && strategy_cached_wpr_signal < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && strategy_cached_wpr_signal > 0)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework two-axis news filter.
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10821_tv-wpr-zone\"}");
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
        }
     }

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }

