#property strict
#property version   "5.0"
#property description "QM5_10094 GitHub H4 Zone Breakout Retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10094;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M5;
input ENUM_TIMEFRAMES strategy_ema_tf          = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_atr_tf          = PERIOD_H1;
input int    strategy_zone_mode                = 0;       // 0 previous D1 high/low; 1 first H4 bars.
input int    strategy_h4_zone_bars             = 1;
input double strategy_min_body_pct             = 50.0;
input double strategy_min_body_points          = 0.0;
input int    strategy_max_wait_seconds         = 86400;
input bool   strategy_use_ema_filter           = true;
input int    strategy_ema_fast_period          = 50;
input int    strategy_ema_slow_period          = 200;
input bool   strategy_use_atr_sizing           = true;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 1.5;
input double strategy_atr_tp_mult              = 3.0;
input double strategy_fixed_rr                 = 1.5;
input int    strategy_session_start_hour       = 7;
input int    strategy_session_end_hour         = 22;
input int    strategy_spread_cap_points        = 50;
input bool   strategy_enable_break_even        = false;
input int    strategy_be_trigger_pips          = 30;
input int    strategy_be_buffer_pips           = 2;
input bool   strategy_enable_atr_trailing      = false;
input double strategy_trail_atr_mult           = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news): session + spread; framework handles news.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   bool in_session = true;
   if(start_h != end_h)
     {
      if(start_h < end_h)
         in_session = (dt.hour >= start_h && dt.hour < end_h);
      else
         in_session = (dt.hour >= start_h || dt.hour < end_h);
     }
   if(!in_session)
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
      return true;

   return false;
  }

// Trade Entry: long-only daily-zone breakout followed by retest.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static bool waiting_retest = false;
   static double breakout_level = 0.0;
   static double breakout_candle_low = 0.0;
   static datetime wait_started = 0;
   static datetime wait_day_start = 0;

   // perf-allowed: structural zone math needs raw D1/H4/M5 OHLC; this hook is
   // called only after the framework QM_IsNewBar() gate in OnTick.
   const datetime day_start = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed
   if(waiting_retest)
     {
      if((strategy_max_wait_seconds > 0 && TimeCurrent() - wait_started > strategy_max_wait_seconds) ||
         (wait_day_start > 0 && day_start > 0 && wait_day_start != day_start))
        {
         waiting_retest = false;
         breakout_level = 0.0;
         breakout_candle_low = 0.0;
         wait_started = 0;
         wait_day_start = 0;
        }
     }

   double zone_high = 0.0;
   double zone_low = 0.0;
   if(strategy_zone_mode == 0)
     {
      zone_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed
      zone_low = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed
     }
   else if(day_start > 0)
     {
      const int need = MathMax(1, strategy_h4_zone_bars);
      int found = 0;
      for(int shift = 12; shift >= 1 && found < need; --shift)
        {
         const datetime h4_time = iTime(_Symbol, PERIOD_H4, shift); // perf-allowed
         if(h4_time <= 0 || h4_time < day_start)
            continue;

         const double h4_high = iHigh(_Symbol, PERIOD_H4, shift); // perf-allowed
         const double h4_low = iLow(_Symbol, PERIOD_H4, shift); // perf-allowed
         if(h4_high <= 0.0 || h4_low <= 0.0 || h4_high <= h4_low)
            continue;

         zone_high = (found == 0) ? h4_high : MathMax(zone_high, h4_high);
         zone_low = (found == 0) ? h4_low : MathMin(zone_low, h4_low);
         found++;
        }
     }

   if(zone_high > zone_low && zone_low > 0.0)
     {
      const double open_1 = iOpen(_Symbol, strategy_signal_tf, 1); // perf-allowed
      const double close_1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed
      const double high_1 = iHigh(_Symbol, strategy_signal_tf, 1); // perf-allowed
      const double low_1 = iLow(_Symbol, strategy_signal_tf, 1); // perf-allowed
      if(open_1 > 0.0 && close_1 > 0.0 && high_1 > low_1 && low_1 > 0.0 &&
         close_1 > zone_high && open_1 <= zone_high)
        {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         const double body = MathAbs(close_1 - open_1);
         const double range = high_1 - low_1;
         const bool body_pct_ok = (strategy_min_body_pct <= 0.0) ||
                                  (range > 0.0 && (body / range * 100.0) >= strategy_min_body_pct);
         const bool body_points_ok = (point > 0.0 && strategy_min_body_points > 0.0 &&
                                      body / point >= strategy_min_body_points);
         if(body_pct_ok || body_points_ok)
           {
            waiting_retest = true;
            breakout_level = zone_high;
            breakout_candle_low = low_1;
            wait_started = TimeCurrent();
            wait_day_start = day_start;
           }
        }
     }

   if(!waiting_retest || breakout_level <= 0.0)
      return false;

   if(strategy_use_ema_filter)
     {
      const double close_ema_tf = iClose(_Symbol, strategy_ema_tf, 1); // perf-allowed
      const double ema_fast = QM_EMA(_Symbol, strategy_ema_tf, strategy_ema_fast_period, 1);
      const double ema_slow = QM_EMA(_Symbol, strategy_ema_tf, strategy_ema_slow_period, 1);
      if(close_ema_tf <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 ||
         close_ema_tf <= ema_fast || close_ema_tf <= ema_slow)
         return false;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || bid > breakout_level)
      return false;

   const double entry = ask;
   double sl = 0.0;
   double tp = 0.0;
   if(strategy_use_atr_sizing)
     {
      const double atr = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
      if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
         return false;
      sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
      tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_tp_mult);
     }
   else
     {
      sl = QM_StopStructureFromExtremes(_Symbol, QM_BUY, breakout_candle_low, breakout_level);
      tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_fixed_rr);
     }

   if(sl <= 0.0 || sl >= entry || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "GH_H4_ZONE_LONG_RETEST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   waiting_retest = false;
   breakout_level = 0.0;
   breakout_candle_low = 0.0;
   wait_started = 0;
   wait_day_start = 0;
   return true;
  }

// Trade Management: optional source-style break-even and ATR trailing.
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

      if(strategy_enable_break_even)
         QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
      if(strategy_enable_atr_trailing)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Trade Close: no discretionary exit beyond SL/TP, management, and framework close.
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook: callable P8 hook; defer to the central framework news gate.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
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
