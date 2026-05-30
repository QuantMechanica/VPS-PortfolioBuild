#property strict
#property version   "5.0"
#property description "QM5_1277 Chan Buy-On-Gap Close Exit"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1277;
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
input int    strategy_sd_lookback        = 90;
input double strategy_entry_sd_mult      = 1.0;
input double strategy_stop_sd_mult       = 2.0;
input int    strategy_max_spread_points  = 0;

datetime g_last_d1_bar = 0;
datetime g_entry_day = 0;
bool     g_entered_today = false;

bool Strategy_NoTradeFilter()
{
   if (strategy_max_spread_points > 0)
   {
      const int sp = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if (sp > strategy_max_spread_points) return true;
   }
   return false;
}

double SD90()
{
   double closes[];
   ArraySetAsSeries(closes, true);
   const int bars = MathMax(2, strategy_sd_lookback + 1);
   if (CopyClose(_Symbol, PERIOD_D1, 1, bars, closes) != bars)
      return 0.0;

   double returns[];
   ArrayResize(returns, bars - 1);
   double sum = 0.0;
   for (int i = 0; i < bars - 1; ++i)
   {
      if (closes[i + 1] <= 0.0) return 0.0;
      returns[i] = (closes[i] - closes[i + 1]) / closes[i + 1];
      sum += returns[i];
   }
   const double mean = sum / (double)(bars - 1);
   double var = 0.0;
   for (int i = 0; i < bars - 1; ++i)
   {
      const double d = returns[i] - mean;
      var += d * d;
   }
   return MathSqrt(var / (double)(bars - 2));
}

bool GapConditionTriggered()
{
   const double open0 = iOpen(_Symbol, PERIOD_D1, 0);
   const double low1 = iLow(_Symbol, PERIOD_D1, 1);
   if (open0 <= 0.0 || low1 <= 0.0) return false;
   const double gap_return = (open0 - low1) / low1;
   const double sd = SD90();
   if (sd <= 0.0) return false;
   return (gap_return < -strategy_entry_sd_mult * sd);
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for (int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
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
      const ulong ticket = PositionGetTicket(i);
      if (ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if ((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(ticket, reason);
   }
}

bool IsNewDay()
{
   const datetime d1 = iTime(_Symbol, PERIOD_D1, 0);
   if (d1 <= 0) return false;
   if (d1 == g_last_d1_bar) return false;
   g_last_d1_bar = d1;
   return true;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "BUY_GAP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if (!IsNewDay())
   {
      if (HasPosition() && g_entered_today)
      {
         const datetime day_start = iTime(_Symbol, PERIOD_D1, 0);
         if (day_start > g_entry_day)
         {
            ClosePosition(QM_EXIT_STRATEGY);
            g_entered_today = false;
         }
      }
      return false;
   }

   g_entered_today = false;

   if (HasPosition())
   {
      ClosePosition(QM_EXIT_STRATEGY);
   }

   if (!GapConditionTriggered()) return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if (entry <= 0.0) return false;

   const double open0 = iOpen(_Symbol, PERIOD_D1, 0);
   const double sd = SD90();
   if (sd <= 0.0) return false;

   const double sl = entry - strategy_stop_sd_mult * sd * entry;
   double tp = 0.0;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "BUY_GAP_FADE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_entered_today = true;
   g_entry_day = iTime(_Symbol, PERIOD_D1, 0);
   return true;
}

void Strategy_ManageOpenPosition()
{
}

bool Strategy_ExitSignal()
{
   const datetime day_start = iTime(_Symbol, PERIOD_D1, 0);
   if (HasPosition() && g_entered_today && day_start > g_entry_day)
   {
      ClosePosition(QM_EXIT_STRATEGY);
      g_entered_today = false;
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1277\",\"strategy\":\"chan-buy-on-gap-close\"}");
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
