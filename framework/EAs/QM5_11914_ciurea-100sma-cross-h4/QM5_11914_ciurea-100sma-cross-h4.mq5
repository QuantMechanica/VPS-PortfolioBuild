#property strict
#property version   "5.0"
#property description "QM5_11914 Ciurea 100-Period SMA Close-Cross (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11914
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11914;
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
input int    strategy_sma_period        = 100;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 3.0;
input int    strategy_time_stop_bars    = 250;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   const double close2 = iClose(_Symbol, PERIOD_H4, 2);
   
   const double sma1 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 1);
   const double sma2 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 2);
   
   const double atr1 = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_period, 1);
   
   if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0 || atr1 <= 0.0)
      return false;

   bool signal_long  = (close1 > sma1 && close2 <= sma2);
   bool signal_short = (close1 < sma1 && close2 >= sma2);

   if(!signal_long && !signal_short)
      return false;

   QM_OrderType side = signal_long ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr1, strategy_atr_sl_mult);
   if(sl <= 0.0) return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "CIUREA_SMA100_CROSS_LONG" : "CIUREA_SMA100_CROSS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;

   return true;
}

void Strategy_ManageOpenPosition()
{
   // No dynamic management specified in card
}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      // Timeout exit
      if(strategy_time_stop_bars > 0)
      {
         datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         int bars = iBarShift(_Symbol, PERIOD_H4, opened);
         if(bars >= strategy_time_stop_bars) return true;
      }
      
      // Opposite signal exit (Flip is handled natively if Strategy_EntrySignal 
      // returns true and framework opens opposite, but the framework exit logic 
      // is useful to close the existing one cleanly first).
      const double close1 = iClose(_Symbol, PERIOD_H4, 1);
      const double close2 = iClose(_Symbol, PERIOD_H4, 2);
      const double sma1 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 1);
      const double sma2 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 2);
      
      if(close1 <= 0.0 || close2 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0) continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      if(ptype == POSITION_TYPE_BUY  && (close1 < sma1 && close2 >= sma2)) return true;
      if(ptype == POSITION_TYPE_SELL && (close1 > sma1 && close2 <= sma2)) return true;
   }

   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

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

void OnDeinit(const int reason)
{
   QM_FrameworkShutdown();
}

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
