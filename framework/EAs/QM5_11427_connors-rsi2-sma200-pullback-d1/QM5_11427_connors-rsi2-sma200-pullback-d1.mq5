#property strict
#property version   "5.0"
#property description "QM5_11427 Connors RSI2 SMA200 Pullback D1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11427;
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
input int    strategy_rsi_period          = 2;
input double strategy_rsi_long_entry      = 5.0;
input double strategy_rsi_short_entry     = 90.0;
input double strategy_rsi_long_exit       = 65.0;
input double strategy_rsi_short_exit      = 35.0;
input int    strategy_trend_sma_period    = 200;
input int    strategy_exit_sma_period     = 5;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_take_profit_rr      = 2.0;
input int    strategy_stop_cap_pips       = 80;
input int    strategy_spread_cap_pips     = 25;
input bool   strategy_shorts_enabled      = true;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_period <= 0 ||
      strategy_trend_sma_period <= 0 ||
      strategy_exit_sma_period <= 0 ||
      strategy_atr_period <= 0 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close_1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double sma_200 = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_sma_period, 1, PRICE_CLOSE);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double stop_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_cap_pips);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || rsi_1 <= 0.0 || atr <= 0.0 || stop_cap <= 0.0)
      return false;

   double stop_distance = atr * strategy_atr_sl_mult;
   if(stop_distance > stop_cap)
      stop_distance = stop_cap;

   if(close_1 > sma_200 && rsi_1 < strategy_rsi_long_entry)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry - stop_distance);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_profit_rr);
      if(tp <= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "connors_rsi2_sma200_long";
      return true;
     }

   if(strategy_shorts_enabled && close_1 < sma_200 && rsi_1 > strategy_rsi_short_entry)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry + stop_distance);
      if(sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_profit_rr);
      if(tp <= 0.0 || tp >= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "connors_rsi2_sma200_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing stop, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close_1 = QM_SMA(_Symbol, PERIOD_D1, 1, 1, PRICE_CLOSE);
   const double sma_5 = QM_SMA(_Symbol, PERIOD_D1, strategy_exit_sma_period, 1, PRICE_CLOSE);
   const double rsi_1 = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1, PRICE_CLOSE);
   if(close_1 <= 0.0 || sma_5 <= 0.0 || rsi_1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(rsi_1 > strategy_rsi_long_exit || close_1 > sma_5)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(rsi_1 < strategy_rsi_short_exit || close_1 < sma_5)
            return true;
        }
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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
