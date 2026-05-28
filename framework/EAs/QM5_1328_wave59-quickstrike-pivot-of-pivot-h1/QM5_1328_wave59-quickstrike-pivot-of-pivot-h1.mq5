#property strict
#property version   "5.0"
#property description "QM5_1328 Wave59 QuickStrike Pivot-of-Pivot H1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1328;
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
input int    strategy_ema_period         = 50;
input int    strategy_atr_period         = 14;
input int    strategy_atr_d1_period      = 14;
input double strategy_pop_band_atr_mult  = 0.5;
input double strategy_sl_cushion_atr     = 0.3;
input double strategy_sl_max_atr         = 1.5;
input int    strategy_time_stop_bars     = 8;
input int    strategy_day_close_hour     = 21;
input int    strategy_session_start_hour = 13;
input int    strategy_session_start_min  = 30;
input int    strategy_session_end_hour   = 20;
input int    strategy_session_end_min    = 0;
input int    strategy_max_spread_points  = 0;

datetime g_last_d1_date = 0;
double g_p = 0.0, g_r1 = 0.0, g_s1 = 0.0, g_r2 = 0.0, g_s2 = 0.0;
double g_pop_p = 0.0, g_pop_r1 = 0.0, g_pop_s1 = 0.0;
double g_pop_band = 0.0;
double g_daily_high = 0.0, g_daily_low = 0.0;
int g_entry_bar = -1;

void ComputePivots()
{
   const double h = iHigh(_Symbol, PERIOD_D1, 1);
   const double l = iLow(_Symbol, PERIOD_D1, 1);
   const double c = iClose(_Symbol, PERIOD_D1, 1);
   if (h <= 0.0 || l <= 0.0 || c <= 0.0) return;

   g_p = (h + l + c) / 3.0;
   g_r1 = 2.0 * g_p - l;
   g_s1 = 2.0 * g_p - h;
   g_r2 = g_p + (h - l);
   g_s2 = g_p - (h - l);

   g_pop_p = (g_r1 + g_s1 + g_p) / 3.0;
   g_pop_r1 = 2.0 * g_pop_p - g_s1;
   g_pop_s1 = 2.0 * g_pop_p - g_r1;
   g_pop_band = g_pop_r1 - g_pop_s1;
}

void UpdateDailyHL()
{
   const double high = iHigh(_Symbol, PERIOD_D1, 0);
   const double low = iLow(_Symbol, PERIOD_D1, 0);
   if (high > g_daily_high) g_daily_high = high;
   if (low < g_daily_low || g_daily_low <= 0.0) g_daily_low = low;
}

bool IsNewDay()
{
   const datetime d1 = iTime(_Symbol, PERIOD_D1, 0);
   if (d1 <= 0) return false;
   if (d1 == g_last_d1_date) return false;
   g_last_d1_date = d1;
   g_daily_high = 0.0;
   g_daily_low = 0.0;
   g_entry_bar = -1;
   ComputePivots();
   return true;
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int total_mins = dt.hour * 60 + dt.min;
   const int start_mins = strategy_session_start_hour * 60 + strategy_session_start_min;
   const int end_mins = strategy_session_end_hour * 60 + strategy_session_end_min;
   return (total_mins >= start_mins && total_mins <= end_mins);
}

bool PastDayClose()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_day_close_hour);
}

double ATR_D1()
{
   return QM_ATR(_Symbol, PERIOD_D1, strategy_atr_d1_period, 1);
}

double ATR_H1()
{
   return QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

bool PositionIsLong()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   }
   return false;
}

void ClosePosition(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if (t == 0 || !PositionSelectByTicket(t)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(t, reason);
   }
}

bool CanEnterToday()
{
   return (g_entry_bar < 0);
}

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   if (!InSession()) return true;
   if (PastDayClose()) return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "POP_BREAK";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if (!CanEnterToday() || HasPosition()) return false;
   if (g_pop_band <= 0.0) return false;

   const double close0 = iClose(_Symbol, PERIOD_H1, 1);
   const double close1 = iClose(_Symbol, PERIOD_H1, 2);
   if (close0 <= 0.0 || close1 <= 0.0) return false;

   const double ema50 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   if (ema50 <= 0.0) return false;

   const double atr_d1 = ATR_D1();
   if (atr_d1 <= 0.0 || g_pop_band < strategy_pop_band_atr_mult * atr_d1) return false;

   UpdateDailyHL();

   QM_OrderType side = QM_BUY;
   string reason = "";
   double tp_target = 0.0;

   if (close0 > g_pop_r1 && close1 <= g_pop_r1 && g_daily_high > g_r1 && close0 > ema50)
   {
      side = QM_BUY;
      reason = "POP_BUY";
      tp_target = g_r1;
   }
   else if (close0 < g_pop_s1 && close1 >= g_pop_s1 && g_daily_low < g_s1 && close0 < ema50)
   {
      side = QM_SELL;
      reason = "POP_SELL";
      tp_target = g_s1;
   }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (entry <= 0.0) return false;

   double sl = 0.0;
   if (side == QM_BUY)
   {
      const double lo = MathMin(iLow(_Symbol, PERIOD_H1, 1), iLow(_Symbol, PERIOD_H1, 2));
      sl = lo - strategy_sl_cushion_atr * ATR_H1();
   }
   else
   {
      const double hi = MathMax(iHigh(_Symbol, PERIOD_H1, 1), iHigh(_Symbol, PERIOD_H1, 2));
      sl = hi + strategy_sl_cushion_atr * ATR_H1();
   }

   const double atr_h1 = ATR_H1();
   if (atr_h1 <= 0.0) return false;
   const double max_sl_dist = strategy_sl_max_atr * atr_h1;
   const double sl_dist = MathAbs(entry - sl);
   if (sl_dist > max_sl_dist)
   {
      sl = (side == QM_BUY) ? entry - max_sl_dist : entry + max_sl_dist;
   }

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp_target > 0.0 ? tp_target : 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entry_bar = (int)iTime(_Symbol, PERIOD_H1, 0);
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   UpdateDailyHL();

   if (PastDayClose())
   {
      ClosePosition(QM_EXIT_FRIDAY_CLOSE);
      return false;
   }

   const bool is_long = PositionIsLong();
   const double close0 = iClose(_Symbol, PERIOD_H1, 1);
   if (close0 <= 0.0) return false;

   if ((is_long && close0 < g_p) || (!is_long && close0 > g_p))
   {
      ClosePosition(QM_EXIT_STRATEGY);
      return false;
   }

   if (g_entry_bar > 0)
   {
      const int bars_since = iBarShift(_Symbol, PERIOD_H1, g_entry_bar, false);
      if (bars_since >= strategy_time_stop_bars)
      {
         ClosePosition(QM_EXIT_TIME_STOP);
         return false;
      }
   }

   if (is_long && g_r2 > 0.0)
   {
      const double high0 = iHigh(_Symbol, PERIOD_H1, 0);
      if (high0 >= g_r2)
      {
         ClosePosition(QM_EXIT_STRATEGY);
         return false;
      }
   }
   if (!is_long && g_s2 > 0.0)
   {
      const double low0 = iLow(_Symbol, PERIOD_H1, 0);
      if (low0 <= g_s2)
      {
         ClosePosition(QM_EXIT_STRATEGY);
         return false;
      }
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

int OnInit()
{
   if (!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   g_last_d1_date = 0;
   g_entry_bar = -1;
   ComputePivots();
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1328\",\"strategy\":\"wave59-quickstrike-pivot-of-pivot-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   if (!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows) return;
   if (QM_FrameworkHandleFridayClose()) return;
   if (Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();

   if (!QM_IsNewBar()) return;

   IsNewDay();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if (Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
