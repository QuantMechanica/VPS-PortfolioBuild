#property strict
#property version   "5.0"
#property description "QM5_20071 Channel Trading System (CCI + Bollinger Mean-Reversion)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20071
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20071;
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
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_cci_period         = 20;
input int    strategy_atr_period         = 14;
input double strategy_atr_mult           = 1.5;
input int    strategy_atr_filter_period  = 20;
input double strategy_bandwidth_mult     = 0.5;
input int    strategy_max_holding_bars   = 24;
input int    strategy_max_spread_points  = 25;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // Spread filter
   const int spread_points = (int)MathRound((ask - bid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   if(spread_points > strategy_max_spread_points)
      return true;

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Get indicator values on closed bars
   const double cci1 = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
   const double cci2 = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 2);
   const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
   const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
   
   if(cci1 == 0.0 || cci2 == 0.0 || close1 == 0.0 || lower1 <= 0.0 || upper1 <= 0.0)
      return false;

   // Band-width filter
   const double atr20 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_filter_period, 1);
   if((upper1 - lower1) < strategy_bandwidth_mult * atr20)
      return false;

   const double atr14 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr14 <= 0.0)
      return false;

   // Long condition
   if(close1 < lower1 && cci1 < -100.0 && cci1 > cci2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(lower1 - atr14 * strategy_atr_mult, _Digits);
      req.tp = 0.0; // exit via strategy exit signal
      req.reason = "CCI_BB_MR_LONG";
      return true;
     }

   // Short condition
   if(close1 > upper1 && cci1 > 100.0 && cci1 < cci2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(upper1 + atr14 * strategy_atr_mult, _Digits);
      req.tp = 0.0; // exit via strategy exit signal
      req.reason = "CCI_BB_MR_SHORT";
      return true;
     }

   return false;
}

void Strategy_ManageOpenPosition() {}

bool Strategy_ExitSignal()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_passed = iBarShift(_Symbol, PERIOD_H1, open_time);

      // 1. Time stop
      if(strategy_max_holding_bars > 0 && bars_passed >= strategy_max_holding_bars)
         return true;

      // Get H1 close and mid-band on closed bar [1]
      const double close1 = iClose(_Symbol, PERIOD_H1, 1); // perf-allowed
      const double mid1 = QM_BB_Middle(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
      if(close1 <= 0.0 || mid1 <= 0.0)
         continue;

      // 2. Mid-band exit
      if(ptype == POSITION_TYPE_BUY && close1 >= mid1)
         return true;
      if(ptype == POSITION_TYPE_SELL && close1 <= mid1)
         return true;

      // 3. Opposite signal exit (reversal)
      const double cci1 = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 1);
      const double cci2 = QM_CCI(_Symbol, PERIOD_H1, strategy_cci_period, 2);
      const double lower1 = QM_BB_Lower(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);
      const double upper1 = QM_BB_Upper(_Symbol, PERIOD_H1, strategy_bb_period, strategy_bb_deviation, 1);

      if(cci1 != 0.0 && cci2 != 0.0 && lower1 > 0.0 && upper1 > 0.0)
        {
         // Opposite signal for BUY is a SHORT entry signal
         if(ptype == POSITION_TYPE_BUY)
           {
            if(close1 > upper1 && cci1 > 100.0 && cci1 < cci2)
               return true;
           }
         // Opposite signal for SELL is a LONG entry signal
         if(ptype == POSITION_TYPE_SELL)
           {
            if(close1 < lower1 && cci1 < -100.0 && cci1 > cci2)
               return true;
           }
        }
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
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
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
