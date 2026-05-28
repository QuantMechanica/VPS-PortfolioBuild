#property strict
#property version   "5.0"
#property description "QM5_11909 Singh Good Morning Asia (USDJPY D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11909
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11909;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.5;
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
input double strategy_min_stop_pips     = 30.0;
input double strategy_target_ratio      = 0.5; // TP is 0.5x SL distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(StringFind(_Symbol, "USDJPY") < 0) return true; // USDJPY only as per card
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   if(PositionsTotal() > 0) return false;

   const double open1  = iOpen(_Symbol, PERIOD_D1, 1);
   const double close1 = iClose(_Symbol, PERIOD_D1, 1);
   const double high1  = iHigh(_Symbol, PERIOD_D1, 1);
   const double low1   = iLow(_Symbol, PERIOD_D1, 1);
   
   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0) return false;

   bool signal_long  = (close1 > open1);
   bool signal_short = (close1 < open1);

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double min_stop_dist = strategy_min_stop_pips * 10 * point;
   
   double sl = 0.0;
   if(side == QM_BUY)
   {
      sl = low1;
      if(entry - sl < min_stop_dist) sl = entry - min_stop_dist;
   }
   else
   {
      sl = high1;
      if(sl - entry < min_stop_dist) sl = entry + min_stop_dist;
   }

   double risk_dist = MathAbs(entry - sl);
   double tp = (side == QM_BUY) ? entry + (risk_dist * strategy_target_ratio) : entry - (risk_dist * strategy_target_ratio);

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "SINGH_GMA_LONG" : "SINGH_GMA_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop: Close at end of D1 bar t+1 (1 full day hold)
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      int bars = iBarShift(_Symbol, PERIOD_D1, opened);
      
      // If we are evaluating on a new bar, and open shift is >= 1, it means the bar we held through has closed.
      // Wait, if we entered at the open of bar 0 (which becomes bar 1 on the next day), 
      // the exit should happen at the close of that same day (i.e. open of the next day).
      // So if bars >= 1, we exit.
      if(bars >= 1) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { QM_FrameworkShutdown(); }

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;
   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   
   if(QM_FrameworkHandleFridayClose()) return;
   if(Strategy_NoTradeFilter()) return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &t, const MqlTradeRequest &r, const MqlTradeResult &res)
{
   QM_FrameworkOnTradeTransaction(t, r, res);
}

double OnTester()
{
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
}
