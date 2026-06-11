#property strict
#property version   "5.0"
#property description "QM5_11661 PatternPy double top/bottom reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11661;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_window            = 3;
input double strategy_threshold         = 0.05;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.0;
input int    strategy_max_hold_bars     = 12;

double g_active_pattern_high = 0.0;
double g_active_pattern_low  = 0.0;

bool PatternPySignal(int &direction, double &pattern_high, double &pattern_low)
  {
   direction = 0;
   pattern_high = 0.0;
   pattern_low = 0.0;

   if(strategy_window != 3 || strategy_threshold <= 0.0)
      return false;

   if(Bars(_Symbol, _Period) < 6) // perf-allowed: bounded PatternPy warmup guard; no QM_Bars helper exists.
      return false;

   const double h_roll_prev2 = iHigh(_Symbol, _Period, 4); // perf-allowed: PatternPy rolling-window source rule.
   const double h_left       = iHigh(_Symbol, _Period, 3); // perf-allowed: PatternPy source High.shift(1).
   const double h_mid        = iHigh(_Symbol, _Period, 2); // perf-allowed: PatternPy labelled bar High.
   const double h_right      = iHigh(_Symbol, _Period, 1); // perf-allowed: PatternPy source High.shift(-1), now closed.
   const double l_roll_prev2 = iLow(_Symbol, _Period, 4);  // perf-allowed: PatternPy rolling-window source rule.
   const double l_left       = iLow(_Symbol, _Period, 3);  // perf-allowed: PatternPy source Low.shift(1).
   const double l_mid        = iLow(_Symbol, _Period, 2);  // perf-allowed: PatternPy labelled bar Low.
   const double l_right      = iLow(_Symbol, _Period, 1);  // perf-allowed: PatternPy source Low.shift(-1), now closed.

   if(h_roll_prev2 <= 0.0 || h_left <= 0.0 || h_mid <= 0.0 || h_right <= 0.0 ||
      l_roll_prev2 <= 0.0 || l_left <= 0.0 || l_mid <= 0.0 || l_right <= 0.0)
      return false;

   const double high_roll_max = MathMax(h_roll_prev2, MathMax(h_left, h_mid));
   const double low_roll_min = MathMin(l_roll_prev2, MathMin(l_left, l_mid));

   const double left_avg = (h_left + l_left) * 0.5;
   const double right_avg = (h_right + l_right) * 0.5;
   if(left_avg <= 0.0 || right_avg <= 0.0)
      return false;

   const bool left_range_ok = (h_left - l_left) <= strategy_threshold * left_avg;
   const bool right_range_ok = (h_right - l_right) <= strategy_threshold * right_avg;

   const bool double_top =
      (high_roll_max >= h_left) &&
      (high_roll_max >= h_right) &&
      (h_mid < h_left) &&
      (h_mid < h_right) &&
      left_range_ok &&
      right_range_ok;

   const bool double_bottom =
      (low_roll_min <= l_left) &&
      (low_roll_min <= l_right) &&
      (l_mid > l_left) &&
      (l_mid > l_right) &&
      left_range_ok &&
      right_range_ok;

   if(double_top == double_bottom)
      return false;

   pattern_high = MathMax(h_left, h_right);
   pattern_low = MathMin(l_left, l_right);

   direction = double_bottom ? 1 : -1;
   return true;
  }

bool HasOpenPositionForThisEA()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasOpenPositionForThisEA())
      return false;

   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return false;

   int direction = 0;
   double pattern_high = 0.0;
   double pattern_low = 0.0;
   if(!PatternPySignal(direction, pattern_high, pattern_low))
      return false;

   const QM_OrderType side = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.sl = sl;
   req.reason = (side == QM_BUY) ? "PP_DOUBLE_BOTTOM" : "PP_DOUBLE_TOP";

   g_active_pattern_high = pattern_high;
   g_active_pattern_low = pattern_low;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   int direction = 0;
   double pattern_high = 0.0;
   double pattern_low = 0.0;
   const bool have_pattern = PatternPySignal(direction, pattern_high, pattern_low);

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
      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      const int hold_seconds = strategy_max_hold_bars * PeriodSeconds((ENUM_TIMEFRAMES)_Period);
      if(opened_at > 0 && hold_seconds > 0 && TimeCurrent() - opened_at >= hold_seconds)
         return true;

      const double close_last = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar pattern-break exit.
      if(close_last > 0.0)
        {
         if(ptype == POSITION_TYPE_BUY && g_active_pattern_low > 0.0 && close_last < g_active_pattern_low)
            return true;
         if(ptype == POSITION_TYPE_SELL && g_active_pattern_high > 0.0 && close_last > g_active_pattern_high)
            return true;
        }

      if(have_pattern)
        {
         if(ptype == POSITION_TYPE_BUY && direction < 0)
            return true;
         if(ptype == POSITION_TYPE_SELL && direction > 0)
            return true;
        }
     }

   return false;
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11661\",\"slug\":\"pp-double-tb\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
