#property strict
#property version   "5.0"
#property description "QM5_11532 Unknown Strategy"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11532
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11532;
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
input int    strategy_ema_fast          = 5;
input int    strategy_ema_mid           = 15;
input int    strategy_ema_slow          = 60;
input int    strategy_sl_pips           = 30;
input int    strategy_tp_pips           = 50;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   // Only 1 position open at a time for this EA and symbol
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) return false;
   }

   const double ema5_1  = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast, 1);
   const double ema15_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_mid, 1);
   const double ema60_1 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 1);
   const double ema60_3 = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow, 3);

   if(ema5_1 <= 0.0 || ema15_1 <= 0.0 || ema60_1 <= 0.0 || ema60_3 <= 0.0) return false;

   const double low1  = iLow(_Symbol, PERIOD_H1, 1);
   const double high1 = iHigh(_Symbol, PERIOD_H1, 1);

   bool signal_long  = (ema5_1 > ema15_1 && ema15_1 > ema60_1 && ema60_1 > ema60_3 && low1 <= ema60_1);
   bool signal_short = (ema5_1 < ema15_1 && ema15_1 < ema60_1 && ema60_1 < ema60_3 && high1 >= ema60_1);

   if(!signal_long && !signal_short) return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   req.tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   req.reason = (side == QM_BUY) ? "CARTER_PULLBACK_LONG" : "CARTER_PULLBACK_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
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
