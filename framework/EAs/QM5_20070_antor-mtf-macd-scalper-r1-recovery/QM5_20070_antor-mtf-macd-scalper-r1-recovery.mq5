#property strict
#property version   "5.0"
#property description "QM5_20070 AntoR / Davit MTF MACD Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20070
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20070;
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
input int    strategy_start_hour         = 7;
input int    strategy_end_hour           = 17;
input int    strategy_max_spread_points  = 15;
input double strategy_sl_atr_mult        = 2.0;
input double strategy_sl_min_pips        = 8.0;
input double strategy_tp_rr_mult         = 1.5;
input bool   strategy_use_m15_flip_exit  = true;

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   // 1. Time of day filter (London/NY session: 07:00 - 17:00 broker time)
   MqlDateTime dt_struct;
   TimeToStruct(TimeCurrent(), dt_struct);
   if(dt_struct.hour < strategy_start_hour || dt_struct.hour >= strategy_end_hour)
      return true;

   // 2. Spread filter
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

   // M5 MACD values
   const double m5_main1 = QM_MACD_Main(_Symbol, PERIOD_M5, 12, 26, 9, 1);
   const double m5_sig1  = QM_MACD_Signal(_Symbol, PERIOD_M5, 12, 26, 9, 1);
   const double m5_main2 = QM_MACD_Main(_Symbol, PERIOD_M5, 12, 26, 9, 2);
   const double m5_sig2  = QM_MACD_Signal(_Symbol, PERIOD_M5, 12, 26, 9, 2);

   // M15 MACD values (current bar, shift 0)
   const double m15_main0 = QM_MACD_Main(_Symbol, PERIOD_M15, 12, 26, 9, 0);
   const double m15_sig0  = QM_MACD_Signal(_Symbol, PERIOD_M15, 12, 26, 9, 0);
   const double m15_hist0 = m15_main0 - m15_sig0;

   // H1 EMA 200 value (closed bar, shift 1)
   const double ema200_h1 = QM_EMA(_Symbol, PERIOD_H1, 200, 1);

   // M5 Close [1]
   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed

   if(close1 == 0.0 || ema200_h1 <= 0.0)
      return false;

   // Stop Loss distance calculation
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const double pips_to_points = point * pip_factor;

   const double atr5 = QM_ATR(_Symbol, PERIOD_M5, 14, 1);
   if(atr5 <= 0.0)
      return false;

   const double sl_dist = MathMax(atr5 * strategy_sl_atr_mult, strategy_sl_min_pips * pips_to_points);
   const double tp_dist = sl_dist * strategy_tp_rr_mult;

   // Long Entry condition
   // M5 crossing UP: main[1] > sig[1] && main[2] <= sig[2]
   // M15 hist > 0
   // Close[1] > EMA200
   if(m5_main1 > m5_sig1 && m5_main2 <= m5_sig2 && m15_hist0 > 0.0 && close1 > ema200_h1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;
      req.type = QM_BUY;
      req.sl = NormalizeDouble(entry - sl_dist, _Digits);
      req.tp = NormalizeDouble(entry + tp_dist, _Digits);
      req.reason = "ANTOR_MACD_LONG";
      return true;
     }

   // Short Entry condition
   // M5 crossing DOWN: main[1] < sig[1] && main[2] >= sig[2]
   // M15 hist < 0
   // Close[1] < EMA200
   if(m5_main1 < m5_sig1 && m5_main2 >= m5_sig2 && m15_hist0 < 0.0 && close1 < ema200_h1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;
      req.type = QM_SELL;
      req.sl = NormalizeDouble(entry + sl_dist, _Digits);
      req.tp = NormalizeDouble(entry - tp_dist, _Digits);
      req.reason = "ANTOR_MACD_SHORT";
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

      // M5 MACD values
      const double m5_main1 = QM_MACD_Main(_Symbol, PERIOD_M5, 12, 26, 9, 1);
      const double m5_sig1  = QM_MACD_Signal(_Symbol, PERIOD_M5, 12, 26, 9, 1);
      const double m5_main2 = QM_MACD_Main(_Symbol, PERIOD_M5, 12, 26, 9, 2);
      const double m5_sig2  = QM_MACD_Signal(_Symbol, PERIOD_M5, 12, 26, 9, 2);

      // 1. Opposite cross exit
      if(ptype == POSITION_TYPE_BUY)
        {
         if(m5_main1 < m5_sig1 && m5_main2 >= m5_sig2)
            return true;
        }
      if(ptype == POSITION_TYPE_SELL)
        {
         if(m5_main1 > m5_sig1 && m5_main2 <= m5_sig2)
            return true;
        }

      // 2. M15 MACD histogram flip exit
      if(strategy_use_m15_flip_exit)
        {
         const double m15_main1 = QM_MACD_Main(_Symbol, PERIOD_M15, 12, 26, 9, 1);
         const double m15_sig1  = QM_MACD_Signal(_Symbol, PERIOD_M15, 12, 26, 9, 1);
         const double m15_hist1 = m15_main1 - m15_sig1;

         if(ptype == POSITION_TYPE_BUY && m15_hist1 < 0.0)
            return true;
         if(ptype == POSITION_TYPE_SELL && m15_hist1 > 0.0)
            return true;
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
