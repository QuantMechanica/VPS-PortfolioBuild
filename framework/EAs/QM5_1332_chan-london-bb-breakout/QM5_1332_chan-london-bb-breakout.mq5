#property strict
#property version   "5.0"
#property description "QM5_1332 Chan London Bollinger Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1332;
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
input int    strategy_bb_lookback        = 20;
input double strategy_bb_std             = 2.0;
input int    strategy_sample_hour        = 9;
input int    strategy_sample_min         = 0;
input int    strategy_session_hours      = 3;
input int    strategy_max_hold_seconds   = 10800;
input double strategy_tp_pips            = 20.0;
input double strategy_sl_pips            = 20.0;
input int    strategy_max_spread_points  = 0;

double g_bb_mid = 0.0, g_bb_upper = 0.0, g_bb_lower = 0.0;
int g_bb_bars = 0;
datetime g_entry_time = 0;
bool g_entered_today = false;

double PointValue()
{
   return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

void ComputeBB()
{
   double prices[];
   ArraySetAsSeries(prices, true);
   const int needed = strategy_bb_lookback + 1;
   if (CopyClose(_Symbol, PERIOD_D1, 2, needed, prices) != needed) return;

   g_bb_bars = needed;
   g_bb_mid = 0.0;
   for (int i = 1; i <= strategy_bb_lookback; ++i)
      g_bb_mid += prices[i];
   g_bb_mid /= (double)strategy_bb_lookback;

   double var = 0.0;
   for (int i = 1; i <= strategy_bb_lookback; ++i)
   {
      const double d = prices[i] - g_bb_mid;
      var += d * d;
   }
   const double sd = MathSqrt(var / (double)(strategy_bb_lookback - 1));
   g_bb_upper = g_bb_mid + strategy_bb_std * sd;
   g_bb_lower = g_bb_mid - strategy_bb_std * sd;
}

bool InSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int start_mins = strategy_sample_hour * 60 + strategy_sample_min;
   const int end_mins = start_mins + strategy_session_hours * 60;
   const int now_mins = dt.hour * 60 + dt.min;
   return (now_mins >= start_mins && now_mins < end_mins);
}

bool IsNewDay()
{
   static datetime last_day = 0;
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if (d0 <= 0) return false;
   if (d0 == last_day) return false;
   last_day = d0;
   g_entered_today = false;
   g_entry_time = 0;
   ComputeBB();
   return true;
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

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if (dt.day_of_week == 5) return true;
   if (!InSession()) return true;
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "LONDON_BB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   IsNewDay();

   if (g_entered_today || HasPosition()) return false;
   if (g_bb_bars < strategy_bb_lookback) return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (ask <= 0.0 || bid <= 0.0) return false;

   const double point = PointValue();
   if (point <= 0.0) return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   double entry = 0.0, sl = 0.0, tp = 0.0;

   if (ask >= g_bb_upper)
   {
      side = QM_BUY;
      entry = ask;
      sl = entry - strategy_sl_pips * point;
      tp = entry + strategy_tp_pips * point;
      reason = "LON_BB_BREAK_UP";
   }
   else if (bid <= g_bb_lower)
   {
      side = QM_SELL;
      entry = bid;
      sl = entry + strategy_sl_pips * point;
      tp = entry - strategy_tp_pips * point;
      reason = "LON_BB_BREAK_DN";
   }
   else
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entered_today = true;
   g_entry_time = TimeCurrent();
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   if (g_entry_time > 0 && TimeCurrent() - g_entry_time >= strategy_max_hold_seconds)
   {
      ClosePosition(QM_EXIT_TIME_STOP);
      return false;
   }

   if (!InSession())
   {
      ClosePosition(QM_EXIT_FRIDAY_CLOSE);
      return false;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

int OnInit()
{
   if (!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                         qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                         30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                         qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1332\",\"strategy\":\"chan-london-bb-breakout\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason)); QM_FrameworkShutdown(); }

void OnTick()
{
   if (!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if (Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if (qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if (!news_allows) return;
   if (QM_FrameworkHandleFridayClose()) return;
   if (Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   Strategy_ExitSignal();
   if (!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if (Strategy_EntrySignal(req)) { ulong t = 0; QM_TM_OpenPosition(req, t); }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
