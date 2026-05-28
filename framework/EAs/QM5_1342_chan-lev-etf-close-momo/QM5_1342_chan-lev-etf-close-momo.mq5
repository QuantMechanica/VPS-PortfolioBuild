#property strict
#property version   "5.0"
#property description "QM5_1342 Chan Leveraged ETF Close Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1342;
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
input int    strategy_signal_hour       = 14;
input int    strategy_signal_min        = 15;
input double strategy_momo_threshold    = 0.02;
input double strategy_atr_sl_mult       = 1.0;
input int    strategy_atr_period        = 14;
input int    strategy_max_spread_points  = 0;

bool g_entered_today = false;

double SessionReturn()
{
   const double open0 = iOpen(_Symbol, PERIOD_D1, 0);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if (open0 <= 0.0 || ask <= 0.0) return 0.0;
   return (ask - open0) / open0;
}

bool SignalTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if (dt.hour < strategy_signal_hour) return false;
   if (dt.hour == strategy_signal_hour && dt.min < strategy_signal_min) return false;
   return true;
}

bool PastSessionClose()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= 21 && dt.min >= 0);
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

bool IsNewDay()
{
   static datetime last_day = 0;
   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if (d0 <= 0) return false;
   if (d0 == last_day) return false;
   last_day = d0;
   g_entered_today = false;
   return true;
}

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "MOMO_CLOSE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   IsNewDay();

   if (g_entered_today || HasPosition()) return false;
   if (!SignalTime()) return false;

   const double ret = SessionReturn();
   if (MathAbs(ret) < strategy_momo_threshold) return false;

   const double entry = (ret > 0.0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if (entry <= 0.0) return false;

   const QM_OrderType side = (ret > 0.0) ? QM_BUY : QM_SELL;
   const double atr = QM_ATR(_Symbol, PERIOD_M5, strategy_atr_period, 1);
   if (atr <= 0.0) return false;

   const double sl = (side == QM_BUY)
                     ? entry - strategy_atr_sl_mult * atr
                     : entry + strategy_atr_sl_mult * atr;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "LEV_MOMO_LONG" : "LEV_MOMO_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entered_today = true;
   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   if (!HasPosition()) return false;

   if (PastSessionClose())
   {
      ClosePosition(QM_EXIT_FRIDAY_CLOSE);
      return false;
   }

   const datetime d0 = iTime(_Symbol, PERIOD_D1, 0);
   if (d0 > 0)
   {
      MqlDateTime dt_now, dt_day;
      TimeToStruct(TimeCurrent(), dt_now);
      TimeToStruct(d0, dt_day);
      if (dt_now.day != dt_day.day)
      {
         ClosePosition(QM_EXIT_STRATEGY);
         return false;
      }
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1342\",\"strategy\":\"chan-lev-etf-close-momo\"}");
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
