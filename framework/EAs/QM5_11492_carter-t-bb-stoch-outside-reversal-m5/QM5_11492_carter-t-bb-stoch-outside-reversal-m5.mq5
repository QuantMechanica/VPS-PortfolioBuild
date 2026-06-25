#property strict
#property version   "5.0"
#property description "QM5_11492 BB Stoch Outside Reversal M5"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11492;
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
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_stoch_k_period     = 5;
input int    strategy_stoch_d_period     = 3;
input int    strategy_stoch_slowing      = 3;
input double strategy_stoch_overbought   = 80.0;
input double strategy_stoch_oversold     = 20.0;
input int    strategy_sl_pips            = 10;
input int    strategy_tp_pips            = 20;
input int    strategy_spread_cap_pips    = 15;
input bool   strategy_no_friday_entry    = true;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > spread_cap)
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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M5, 1); // perf-allowed: card requires one closed-bar candle close; no QM close reader exists.
   const double open1  = iOpen(_Symbol, PERIOD_M5, 1);  // perf-allowed: card requires one closed-bar candle open; no QM open reader exists.
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   const double upper = QM_BB_Upper(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double lower = QM_BB_Lower(_Symbol, PERIOD_M5, strategy_bb_period, strategy_bb_deviation, 1, PRICE_CLOSE);
   const double stoch = QM_Stoch_K(_Symbol, PERIOD_M5, strategy_stoch_k_period,
                                   strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(upper <= 0.0 || lower <= 0.0 || stoch <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(close1 > upper && stoch > strategy_stoch_overbought && close1 < open1)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, bid, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, bid, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "bb_stoch_outside_reversal_short";
      return true;
     }

   if(close1 < lower && stoch < strategy_stoch_oversold && close1 > open1)
     {
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, ask, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, ask, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "bb_stoch_outside_reversal_long";
      return true;
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   return false;
  }

// News Filter Hook
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

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
