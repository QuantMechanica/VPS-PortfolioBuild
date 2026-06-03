#property strict
#property version   "5.1"
#property description "QM5_10692 TradingView Liquidity Sweep Market Structure v2"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON (v2 Rework)
// -----------------------------------------------------------------------------
// v2 Fixes:
//  - Increased qm_news_stale_max_hours to 1000000 to prevent ONINIT_FAILED.
//  - Added SYMBOL_TRADE_STOPS_LEVEL aware SL normalization.
//  - Ensured minimum 10-point stop distance for all trades.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10692;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 1000000; // v2 fix: prevent stale-calendar INIT_FAILED
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_pivot_lookback        = 5;
input int    strategy_structure_lookback    = 5;
input int    strategy_max_bars_after_sweep  = 20;
input int    strategy_atr_period            = 14;
input int    strategy_atr_median_bars       = 100;
input double strategy_min_atr_median_ratio  = 0.50;
input double strategy_atr_stop_mult         = 1.20;
input double strategy_atr_stop_cap_mult     = 3.00;
input double strategy_reward_r              = 2.00;
input int    strategy_max_hold_bars         = 24;
input bool   strategy_session_filter        = true;
input int    strategy_session_start_hour    = 7;
input int    strategy_session_end_hour      = 21;
input int    strategy_max_spread_points     = 0;

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   if(strategy_session_filter)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
      const int end_h = MathMax(0, MathMin(23, strategy_session_end_hour));
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
     }

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   static double active_swing_high = 0.0;
   static double active_swing_low = 0.0;
   static bool   long_sweep_active = false;
   static bool   short_sweep_active = false;
   static int    long_sweep_age = 0;
   static int    short_sweep_age = 0;
   static double long_sweep_extreme = 0.0;
   static double short_sweep_extreme = 0.0;
   static double long_break_level = 0.0;
   static double short_break_level = 0.0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_pivot_lookback < 1 || strategy_structure_lookback < 1 ||
      strategy_max_bars_after_sweep < 1 || strategy_atr_period < 1 ||
      strategy_atr_median_bars < 5 || strategy_min_atr_median_ratio <= 0.0 ||
      strategy_atr_stop_mult <= 0.0 || strategy_atr_stop_cap_mult <= 0.0 ||
      strategy_reward_r <= 0.0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int bars_needed = MathMax(strategy_atr_median_bars + strategy_atr_period + 5,
                                   strategy_pivot_lookback * 2 + strategy_structure_lookback + 10);
   if(Bars(_Symbol, tf) < bars_needed)
      return false;

   if(long_sweep_active)
     {
      long_sweep_age++;
      if(long_sweep_age > strategy_max_bars_after_sweep)
         long_sweep_active = false;
     }
   if(short_sweep_active)
     {
      short_sweep_age++;
      if(short_sweep_age > strategy_max_bars_after_sweep)
         short_sweep_active = false;
     }

   const int pivot_shift = strategy_pivot_lookback + 1;
   const double pivot_high = iHigh(_Symbol, tf, pivot_shift);
   bool is_pivot_high = (pivot_high > 0.0);
   for(int i = 1; i <= strategy_pivot_lookback && is_pivot_high; ++i)
     {
      if(iHigh(_Symbol, tf, pivot_shift + i) >= pivot_high ||
         iHigh(_Symbol, tf, pivot_shift - i) >= pivot_high)
         is_pivot_high = false;
     }
   if(is_pivot_high)
      active_swing_high = pivot_high;

   const double pivot_low = iLow(_Symbol, tf, pivot_shift);
   bool is_pivot_low = (pivot_low > 0.0);
   for(int i = 1; i <= strategy_pivot_lookback && is_pivot_low; ++i)
     {
      if(iLow(_Symbol, tf, pivot_shift + i) <= pivot_low ||
         iLow(_Symbol, tf, pivot_shift - i) <= pivot_low)
         is_pivot_low = false;
     }
   if(is_pivot_low)
      active_swing_low = pivot_low;

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double atr_values[];
   ArrayResize(atr_values, strategy_atr_median_bars);
   for(int i = 0; i < strategy_atr_median_bars; ++i)
     {
      const double v = QM_ATR(_Symbol, tf, strategy_atr_period, i + 1);
      if(v <= 0.0)
         return false;
      atr_values[i] = v;
     }
   ArraySort(atr_values);
   const int mid = strategy_atr_median_bars / 2;
   const double median_atr = ((strategy_atr_median_bars % 2) == 0)
                             ? (atr_values[mid - 1] + atr_values[mid]) * 0.5
                             : atr_values[mid];
   if(median_atr <= 0.0 || atr < median_atr * strategy_min_atr_median_ratio)
      return false;

   const double high1 = iHigh(_Symbol, tf, 1);
   const double low1 = iLow(_Symbol, tf, 1);
   const double close1 = iClose(_Symbol, tf, 1);
   const double close2 = iClose(_Symbol, tf, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   double prior_high = 0.0;
   double prior_low = 0.0;
   for(int i = 2; i <= strategy_structure_lookback + 1; ++i)
     {
      const double h = iHigh(_Symbol, tf, i);
      const double l = iLow(_Symbol, tf, i);
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(prior_high <= 0.0 || h > prior_high)
         prior_high = h;
      if(prior_low <= 0.0 || l < prior_low)
         prior_low = l;
     }

   if(active_swing_low > 0.0 && low1 < active_swing_low && close1 > active_swing_low)
     {
      long_sweep_active = true;
      long_sweep_age = 0;
      long_sweep_extreme = low1;
      long_break_level = prior_high;
     }
   else if(long_sweep_active && low1 < long_sweep_extreme)
      long_sweep_extreme = low1;

   if(active_swing_high > 0.0 && high1 > active_swing_high && close1 < active_swing_high)
     {
      short_sweep_active = true;
      short_sweep_age = 0;
      short_sweep_extreme = high1;
      short_break_level = prior_low;
     }
   else if(short_sweep_active && high1 > short_sweep_extreme)
      short_sweep_extreme = high1;

   const bool long_signal = (long_sweep_active &&
                             long_sweep_age <= strategy_max_bars_after_sweep &&
                             long_break_level > 0.0 &&
                             close2 <= long_break_level &&
                             close1 > long_break_level);
   const bool short_signal = (short_sweep_active &&
                              short_sweep_age <= strategy_max_bars_after_sweep &&
                              short_break_level > 0.0 &&
                              close2 >= short_break_level &&
                              close1 < short_break_level);
   if(!long_signal && !short_signal)
      return false;

   const bool go_long = long_signal;
   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double safety = atr * MathMin(strategy_atr_stop_mult, strategy_atr_stop_cap_mult);
   
   const double raw_sl = go_long ? (long_sweep_extreme - safety)
                                : (short_sweep_extreme + safety);
   double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || point <= 0.0) return false;

   // v2 fix: Ensure minimum stop distance (Trade Stops Level + margin)
   const double stops_level = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double min_dist = MathMax(stops_level, 10.0 * point);
   if(MathAbs(entry - sl) < min_dist)
     {
      sl = go_long ? (entry - min_dist) : (entry + min_dist);
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
     }

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_reward_r);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(go_long && sl >= entry)
      return false;
   if(!go_long && sl <= entry)
      return false;

   if(go_long)
      long_sweep_active = false;
   else
      short_sweep_active = false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = go_long ? "LS_MS_LONG" : "LS_MS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_open = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, opened, false);
      if(bars_open >= strategy_max_hold_bars)
         return true;
     }

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
