#property strict
#property version   "5.0"
#property description "QM5_10688 TradingView ICT Session Breakout Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10688;
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
input int    strategy_session_start_hour_broker = 0;
input int    strategy_session_start_minute      = 0;
input int    strategy_reentry_depth_pips        = 5;
input int    strategy_retest_tolerance_pips     = 5;
input int    strategy_min_bars_after_break      = 3;
input int    strategy_sl_pips                   = 10;
input int    strategy_tp_pips                   = 20;
input int    strategy_max_trades_per_day        = 2;
input int    strategy_max_spread_points         = 35;
input bool   strategy_day_end_flat_enabled      = true;
input int    strategy_day_end_hour_broker       = 23;
input int    strategy_day_end_minute            = 0;
input int    strategy_session_scan_bars         = 400;
input int    strategy_non_fx_atr_period         = 14;
input double strategy_non_fx_depth_atr_mult     = 0.25;
input double strategy_non_fx_tolerance_atr_mult = 0.25;
input double strategy_non_fx_sl_atr_mult        = 1.0;
input double strategy_non_fx_tp_atr_mult        = 2.0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;

      const double spread_points = (ask - bid) / point;
      if(spread_points > (double)strategy_max_spread_points)
         return true;
     }

   if(strategy_day_end_flat_enabled)
     {
      MqlDateTime now_dt;
      TimeToStruct(TimeCurrent(), now_dt);
      const int now_hhmm = now_dt.hour * 100 + now_dt.min;
      const int end_hhmm = strategy_day_end_hour_broker * 100 + strategy_day_end_minute;
      if(now_hhmm >= end_hhmm)
         return true;
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   static datetime active_session_start = 0;
   static int      trade_count_session = 0;
   static int      sequence_direction = 0;
   static int      bars_after_break = 0;
   static double   reentry_reference = 0.0;
   static bool     reentry_seen = false;

   if(strategy_reentry_depth_pips <= 0 ||
      strategy_retest_tolerance_pips <= 0 ||
      strategy_min_bars_after_break < 0 ||
      strategy_sl_pips <= 0 ||
      strategy_tp_pips <= 0 ||
      strategy_max_trades_per_day <= 0)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1);
   if(bar_time <= 0)
      return false;

   MqlDateTime session_dt;
   TimeToStruct(bar_time, session_dt);
   session_dt.hour = strategy_session_start_hour_broker;
   session_dt.min = strategy_session_start_minute;
   session_dt.sec = 0;
   datetime session_start = StructToTime(session_dt);
   if(bar_time < session_start)
      session_start -= 86400;

   if(session_start != active_session_start)
     {
      active_session_start = session_start;
      trade_count_session = 0;
      sequence_direction = 0;
      bars_after_break = 0;
      reentry_reference = 0.0;
      reentry_seen = false;
     }

   if(trade_count_session >= strategy_max_trades_per_day)
      return false;

   const datetime previous_start = session_start - 86400;
   double previous_high = -DBL_MAX;
   double previous_low = DBL_MAX;
   bool have_previous_range = false;

   int bars_to_scan = strategy_session_scan_bars;
   const int bars_available = Bars(_Symbol, _Period);
   if(bars_to_scan < 50)
      bars_to_scan = 50;
   if(bars_available > 0 && bars_available < bars_to_scan)
      bars_to_scan = bars_available - 1;

   for(int shift = 1; shift <= bars_to_scan; ++shift)
     {
      const datetime t = iTime(_Symbol, _Period, shift);
      if(t <= 0)
         break;
      if(t < previous_start)
         break;
      if(t >= session_start)
         continue;

      const double h = iHigh(_Symbol, _Period, shift);
      const double l = iLow(_Symbol, _Period, shift);
      if(h <= 0.0 || l <= 0.0 || h < l)
         continue;

      previous_high = MathMax(previous_high, h);
      previous_low = MathMin(previous_low, l);
      have_previous_range = true;
     }

   if(!have_previous_range || previous_high <= previous_low)
      return false;

   const string symbol_prefix = StringSubstr(_Symbol, 0, 6);
   const bool is_fx = (StringLen(symbol_prefix) == 6 &&
                       StringFind(symbol_prefix, "XAU") < 0 &&
                       StringFind(symbol_prefix, "XAG") < 0 &&
                       StringFind(symbol_prefix, "XTI") < 0 &&
                       StringFind(symbol_prefix, "XNG") < 0);

   double reentry_depth = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_reentry_depth_pips);
   double retest_tolerance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_retest_tolerance_pips);
   double atr_value = 0.0;
   if(!is_fx)
     {
      atr_value = QM_ATR(_Symbol, _Period, strategy_non_fx_atr_period, 1);
      if(atr_value > 0.0)
        {
         reentry_depth = atr_value * strategy_non_fx_depth_atr_mult;
         retest_tolerance = atr_value * strategy_non_fx_tolerance_atr_mult;
        }
     }

   if(reentry_depth <= 0.0 || retest_tolerance <= 0.0)
      return false;

   const double open1 = iOpen(_Symbol, _Period, 1);
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1 = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const bool long_break = (open1 < previous_high && close1 > previous_high);
   const bool short_break = (open1 > previous_low && close1 < previous_low);

   if(long_break)
     {
      sequence_direction = 1;
      bars_after_break = 0;
      reentry_reference = previous_high;
      reentry_seen = false;
      return false;
     }

   if(short_break)
     {
      sequence_direction = -1;
      bars_after_break = 0;
      reentry_reference = previous_low;
      reentry_seen = false;
      return false;
     }

   if(sequence_direction == 0)
      return false;

   bars_after_break++;

   if(sequence_direction > 0)
     {
      if(close1 <= reentry_reference - reentry_depth)
         reentry_seen = true;

      if(!reentry_seen || bars_after_break < strategy_min_bars_after_break)
         return false;

      const bool retest_touched = (low1 <= reentry_reference + retest_tolerance &&
                                   high1 >= reentry_reference - retest_tolerance);
      if(!retest_touched)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      if(is_fx)
        {
         req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_sl_pips);
         req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_tp_pips);
        }
      else
        {
         if(atr_value <= 0.0)
            atr_value = QM_ATR(_Symbol, _Period, strategy_non_fx_atr_period, 1);
         if(atr_value <= 0.0)
            return false;
         req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_non_fx_sl_atr_mult);
         req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr_value, strategy_non_fx_tp_atr_mult);
        }
      req.reason = "ICT_SESSION_LONG_RETEST";
      sequence_direction = 0;
      reentry_seen = false;
      trade_count_session++;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(sequence_direction < 0)
     {
      if(close1 >= reentry_reference + reentry_depth)
         reentry_seen = true;

      if(!reentry_seen || bars_after_break < strategy_min_bars_after_break)
         return false;

      const bool retest_touched = (high1 >= reentry_reference - retest_tolerance &&
                                   low1 <= reentry_reference + retest_tolerance);
      if(!retest_touched)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      if(is_fx)
        {
         req.sl = QM_StopFixedPips(_Symbol, req.type, entry, strategy_sl_pips);
         req.tp = QM_TakeFixedPips(_Symbol, req.type, entry, strategy_tp_pips);
        }
      else
        {
         if(atr_value <= 0.0)
            atr_value = QM_ATR(_Symbol, _Period, strategy_non_fx_atr_period, 1);
         if(atr_value <= 0.0)
            return false;
         req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr_value, strategy_non_fx_sl_atr_mult);
         req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr_value, strategy_non_fx_tp_atr_mult);
        }
      req.reason = "ICT_SESSION_SHORT_RETEST";
      sequence_direction = 0;
      reentry_seen = false;
      trade_count_session++;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!strategy_day_end_flat_enabled)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_hhmm = now_dt.hour * 100 + now_dt.min;
   const int end_hhmm = strategy_day_end_hour_broker * 100 + strategy_day_end_minute;
   return (now_hhmm >= end_hhmm);
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
