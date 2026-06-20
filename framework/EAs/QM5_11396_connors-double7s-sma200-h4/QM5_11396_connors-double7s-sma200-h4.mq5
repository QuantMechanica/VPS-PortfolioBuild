#property strict
#property version   "5.0"
#property description "QM5_11396 connors-double7s-sma200-h4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11396;
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
input int    strategy_sma_period         = 200;
input int    strategy_extreme_lookback   = 7;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_mult        = 2.0;
input int    strategy_sl_max_pips        = 50;
input int    strategy_spread_cap_pips    = 20;

// Return TRUE to BLOCK trading this tick. Spread guard fails open on DWX zero
// modeled spread and blocks only genuinely wide positive spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   return ((ask - bid) > cap);
  }

// Caller guarantees QM_IsNewBar() == true. The signal is evaluated from the
// just-closed bar (shift 1), so the market order is sent at the next bar open.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_sma_period <= 0 || strategy_extreme_lookback <= 1 ||
      strategy_atr_period <= 0 || strategy_sl_atr_mult <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: bounded closed-bar close read
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(close1 <= 0.0 || sma <= 0.0 || atr <= 0.0)
      return false;

   bool is_lowest = true;
   bool is_highest = true;
   for(int shift = 2; shift <= strategy_extreme_lookback; ++shift)
     {
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar close read
      if(c <= 0.0)
         return false;
      if(close1 > c)
         is_lowest = false;
      if(close1 < c)
         is_highest = false;
     }

   double stop_distance = atr * strategy_sl_atr_mult;
   const double stop_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(stop_cap > 0.0 && stop_distance > stop_cap)
      stop_distance = stop_cap;
   if(stop_distance <= 0.0)
      return false;

   if(close1 > sma && is_lowest)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_BUY, entry, stop_distance);
      req.reason = "connors_double7s_long";
      return (req.sl > 0.0);
     }

   if(close1 < sma && is_highest)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopRulesStopFromDistance(_Symbol, QM_SELL, entry, stop_distance);
      req.reason = "connors_double7s_short";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

// Exit on the opposite 7-bar close extreme, using the just-closed bar.
bool Strategy_ExitSignal()
  {
   if(strategy_extreme_lookback <= 1)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   bool is_long = false;
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: bounded closed-bar close read
   if(close1 <= 0.0)
      return false;

   bool is_lowest = true;
   bool is_highest = true;
   for(int shift = 2; shift <= strategy_extreme_lookback; ++shift)
     {
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: bounded closed-bar close read
      if(c <= 0.0)
         return false;
      if(close1 > c)
         is_lowest = false;
      if(close1 < c)
         is_highest = false;
     }

   if(is_long)
      return is_highest;
   return is_lowest;
  }

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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
