#property strict
#property version   "5.0"
#property description "QM5_11525 Ciurea Stoch(14,3,5) bounce H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 11525;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_stoch_k_period      = 14;
input int    strategy_stoch_d_period      = 3;
input int    strategy_stoch_slowing       = 5;
input double strategy_oversold_level      = 20.0;
input double strategy_overbought_level    = 80.0;
input int    strategy_structure_bars      = 3;
input int    strategy_sl_buffer_pips      = 3;
input int    strategy_max_sl_pips         = 80;
input double strategy_tp_rr               = 2.0;
input int    strategy_spread_cap_pips     = 15;
input bool   strategy_skip_friday_entry   = true;

bool IsFridayBrokerTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5);
  }

double EntryPriceForSide(const QM_OrderType side)
  {
   if(side == QM_BUY)
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(side == QM_SELL)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return 0.0;
  }

bool BuildStructureStopAndTarget(const QM_OrderType side,
                                 const double entry,
                                 double &out_sl,
                                 double &out_tp)
  {
   out_sl = 0.0;
   out_tp = 0.0;

   double lowest = 0.0;
   double highest = 0.0;
   if(!QM_StopRulesReadStructureExtremes(_Symbol, strategy_structure_bars, lowest, highest))
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   if(buffer <= 0.0)
      return false;

   double sl = 0.0;
   if(side == QM_BUY)
      sl = lowest - buffer;
   else
      sl = highest + buffer;

   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_sl_pips);
   if(max_dist > 0.0 && MathAbs(entry - sl) > max_dist)
     {
      if(side == QM_BUY)
         sl = entry - max_dist;
      else
         sl = entry + max_dist;
     }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   out_sl = sl;
   out_tp = tp;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
      return true;

   if(strategy_skip_friday_entry && IsFridayBrokerTime(TimeCurrent()))
      return true;

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_stoch_k_period <= 0 || strategy_stoch_d_period <= 0 || strategy_stoch_slowing <= 0)
      return false;
   if(strategy_structure_bars <= 0 || strategy_sl_buffer_pips <= 0 || strategy_tp_rr <= 0.0)
      return false;

   const double stoch_1 = QM_Stoch_K(_Symbol, PERIOD_H4,
                                     strategy_stoch_k_period,
                                     strategy_stoch_d_period,
                                     strategy_stoch_slowing,
                                     1);
   const double stoch_2 = QM_Stoch_K(_Symbol, PERIOD_H4,
                                     strategy_stoch_k_period,
                                     strategy_stoch_d_period,
                                     strategy_stoch_slowing,
                                     2);
   if(stoch_1 <= 0.0 || stoch_2 <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(stoch_1 > strategy_oversold_level && stoch_2 <= strategy_oversold_level)
     {
      side = QM_BUY;
      reason = "STOCH1435_CROSS_UP_20";
     }
   else if(stoch_1 < strategy_overbought_level && stoch_2 >= strategy_overbought_level)
     {
      side = QM_SELL;
      reason = "STOCH1435_CROSS_DOWN_80";
     }
   else
      return false;

   const double entry = EntryPriceForSide(side);
   if(entry <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(!BuildStructureStopAndTarget(side, entry, sl, tp))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or scale-in logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   // Card exits only through initial SL, 2R TP, and framework Friday close.
   return false;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11525\",\"source_id\":\"0192e348-5570-531c-9110-7954a36caca2\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
