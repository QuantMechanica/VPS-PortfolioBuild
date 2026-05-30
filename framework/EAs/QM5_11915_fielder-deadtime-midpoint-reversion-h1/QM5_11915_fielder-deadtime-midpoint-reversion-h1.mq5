#property strict
#property version   "5.0"
#property description "QM5_11915 Fielder Dead-Time-Range Midpoint Reversion H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11915
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11915;
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
input int    strategy_entry_hour_broker = 0;     // 17:00 EST
input int    strategy_exit_hour_broker  = 2;     // 19:00 EST
input double strategy_sl_pips           = 12.0;
input double strategy_tp_pips           = 12.0;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Trigger only on the H1 bar starting at 00:00 broker (17:00 EST)
   if(dt.hour != strategy_entry_hour_broker)
      return false;

   // dead_time starts at 15:00 EST (22:00 broker) and ends at 17:00 EST (00:00 broker)
   // We use the closes of the bars that just finished.
   // close_15est = close of bar that opened at 14:00 and ended at 15:00 EST
   // close_17est = close of bar that opened at 16:00 and ended at 17:00 EST (this bar's open)
   
   // In broker time:
   // close_15est = close of 21:00 bar (3 bars ago from 00:00 open) -> wait, 15:00 EST is 22:00 broker.
   // Let's re-verify:
   // 17:00 EST = 00:00 broker
   // 16:00 EST = 23:00 broker
   // 15:00 EST = 22:00 broker
   
   // So:
   // close_15est is the close of the H1 bar that ENDED at 22:00 broker (i.e. the 21:00 bar).
   // close_17est is the close of the H1 bar that ENDED at 00:00 broker (i.e. the 23:00 bar).
   
   const double close_15est = iClose(_Symbol, PERIOD_H1, 3); // 21:00 bar close
   const double close_17est = iClose(_Symbol, PERIOD_H1, 1); // 23:00 bar close
   
   if(close_15est <= 0.0 || close_17est <= 0.0) return false;
   
   const double midpoint = (close_15est + close_17est) / 2.0;
   const double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // or Bid, but Ask is safe for open
   
   QM_OrderType side = QM_BUY;
   bool has_signal = false;
   
   if(current_price < midpoint) {
      side = QM_BUY;
      has_signal = true;
   } else if(current_price > midpoint) {
      side = QM_SELL;
      has_signal = true;
   }
   
   if(!has_signal) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = strategy_sl_pips;
   req.tp = strategy_tp_pips;
   req.reason = (side == QM_BUY) ? "FIELDER_DEADTIME_LONG" : "FIELDER_DEADTIME_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Time stop: close at 19:00 EST (02:00 broker)
      if(dt.hour >= strategy_exit_hour_broker && dt.hour < 21) // avoid Friday close interference
         return true;
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
