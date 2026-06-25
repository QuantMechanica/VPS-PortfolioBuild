#property strict
#property version   "5.0"
#property description "QM5_11819 Carter M5 S8 BB50 RSI3 Stoch reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11819;
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
input int    strategy_bb_period          = 50;
input double strategy_bb_deviation       = 2.0;
input int    strategy_rsi_period         = 3;
input double strategy_rsi_long_level     = 20.0;
input double strategy_rsi_short_level    = 80.0;
input int    strategy_stoch_k            = 6;
input int    strategy_stoch_d            = 3;
input int    strategy_stoch_slow         = 3;
input double strategy_stoch_long_level   = 20.0;
input double strategy_stoch_short_level  = 80.0;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 2.0;
input int    strategy_spread_cap_pips    = 5;

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0)
     {
      const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
      if(cap > 0.0 && spread > cap)
         return true;
     }
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi      = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double stoch_k  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);

   // perf-allowed: one closed-bar close is required by the card and no QM close reader exists.
   const double close_1 = iClose(_Symbol, _Period, 1);
   if(bb_lower <= 0.0 || bb_upper <= 0.0 || bb_mid <= 0.0 ||
      rsi <= 0.0 || stoch_k < 0.0 || close_1 <= 0.0)
      return false;

   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(close_1 < bb_lower &&
      rsi < strategy_rsi_long_level &&
      stoch_k < strategy_stoch_long_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || bb_mid <= entry)
         return false;

      const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, bb_mid);
      req.reason = "carter_s8_bb50_rsi3_stoch_long";
      return true;
     }

   if(close_1 > bb_upper &&
      rsi > strategy_rsi_short_level &&
      stoch_k > strategy_stoch_short_level)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || bb_mid >= entry)
         return false;

      const double sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_sl_atr_mult);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.sl = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp = QM_TM_NormalizePrice(_Symbol, bb_mid);
      req.reason = "carter_s8_bb50_rsi3_stoch_short";
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
// Framework wiring - do NOT edit below this line unless the framework changes.
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
