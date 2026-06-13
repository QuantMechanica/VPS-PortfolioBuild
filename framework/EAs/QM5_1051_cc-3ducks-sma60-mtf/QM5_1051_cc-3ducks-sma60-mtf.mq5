#property strict
#property version   "5.0"
#property description "QM5_1051 3 Ducks SMA60 MTF alignment"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1051;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_sma_period        = 60;
input int    strategy_sl_buffer_points  = 20;
input double strategy_rr                = 1.5;
input int    strategy_spread_cap_points = 20;
input bool   strategy_london_ny_only    = false;
input bool   strategy_use_atr_stop      = false;
input int    strategy_atr_period        = 14;
input double strategy_atr_mult          = 1.5;

double Strategy_NormalizePrice(const double price)
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double Strategy_LastClosedClose(const ENUM_TIMEFRAMES tf)
  {
   return QM_SMA(_Symbol, tf, 1, 1, PRICE_CLOSE);
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double spread_points = (ask - bid) / point;
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
      return true;

   if(strategy_london_ny_only)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.hour < 15 || dt.hour >= 19)
         return true;
     }

   return false;
  }

double Strategy_InitialStop(const QM_OrderType side, const double entry_price, const double h1_sma)
  {
   if(strategy_use_atr_stop)
      return QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_mult);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || h1_sma <= 0.0)
      return 0.0;

   const double buffer = strategy_sl_buffer_points * point;
   const double stop = QM_OrderTypeIsBuy(side) ? (h1_sma - buffer) : (h1_sma + buffer);
   return Strategy_NormalizePrice(stop);
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

   if(strategy_sma_period <= 0 || strategy_rr <= 0.0)
      return false;
   if(strategy_use_atr_stop && (strategy_atr_period <= 0 || strategy_atr_mult <= 0.0))
      return false;

   ENUM_POSITION_TYPE ignored_type;
   if(Strategy_HasOpenPosition(ignored_type))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double m5_close = Strategy_LastClosedClose(PERIOD_M5);
   const double sma_h4 = QM_SMA(_Symbol, PERIOD_H4, strategy_sma_period, 0, PRICE_CLOSE);
   const double sma_h1 = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 0, PRICE_CLOSE);
   const double sma_m5 = QM_SMA(_Symbol, PERIOD_M5, strategy_sma_period, 1, PRICE_CLOSE);
   if(m5_close <= 0.0 || sma_h4 <= 0.0 || sma_h1 <= 0.0 || sma_m5 <= 0.0)
      return false;

   if(bid > sma_h4 && bid > sma_h1 && m5_close > sma_m5)
     {
      req.type = QM_BUY;
      req.sl = Strategy_InitialStop(req.type, ask, sma_h1);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, ask, req.sl, strategy_rr);
      req.reason = "THREE_DUCKS_LONG";
      return (req.tp > ask);
     }

   if(bid < sma_h4 && bid < sma_h1 && m5_close < sma_m5)
     {
      req.type = QM_SELL;
      req.sl = Strategy_InitialStop(req.type, bid, sma_h1);
      if(req.sl <= bid)
         return false;
      req.tp = QM_TakeRR(_Symbol, req.type, bid, req.sl, strategy_rr);
      req.reason = "THREE_DUCKS_SHORT";
      return (req.tp > 0.0 && req.tp < bid);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(strategy_sma_period <= 0)
      return false;

   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   const double m5_close = Strategy_LastClosedClose(PERIOD_M5);
   const double sma_m5 = QM_SMA(_Symbol, PERIOD_M5, strategy_sma_period, 1, PRICE_CLOSE);
   if(m5_close <= 0.0 || sma_m5 <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY && m5_close < sma_m5)
      return true;
   if(position_type == POSITION_TYPE_SELL && m5_close > sma_m5)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1051\",\"ea\":\"cc-3ducks-sma60-mtf\"}");
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
