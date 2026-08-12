#property strict
#property version   "5.0"
#property description "QM5_11689 Stratestic Bollinger Band Mean Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_11689
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11689;
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
input int    strategy_ma_period         = 20;
input double strategy_bb_deviation      = 2.0;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 3.0;


// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter() { return false; }

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   double bb_lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_ma_period, strategy_bb_deviation, 1);
   double bb_upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_ma_period, strategy_bb_deviation, 1);
   
   if(close1 < bb_lower1)
   {
      req.type = QM_BUY;
      req.price = 0.0;
      double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      double sl_dist = strategy_atr_sl_mult * atr;
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = entry_price - sl_dist;
      req.tp = 0.0;
      req.reason = "BB_MR_LONG_ENTRY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }
   
   if(close1 > bb_upper1)
   {
      req.type = QM_SELL;
      req.price = 0.0;
      double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
      double sl_dist = strategy_atr_sl_mult * atr;
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = entry_price + sl_dist;
      req.tp = 0.0;
      req.reason = "BB_MR_SHORT_ENTRY";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
   }
   
   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   double close2 = iClose(_Symbol, PERIOD_H1, 2);
   
   double sma1 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_ma_period, strategy_bb_deviation, 1);
   double sma2 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_ma_period, strategy_bb_deviation, 2);
   
   double dist1 = close1 - sma1;
   double dist2 = close2 - sma2;
   
   if(dist1 * dist2 < 0.0)
   {
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
