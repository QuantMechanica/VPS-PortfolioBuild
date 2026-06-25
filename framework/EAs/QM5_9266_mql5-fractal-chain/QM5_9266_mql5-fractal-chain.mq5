#property strict
#property version   "5.0"
#property description "QM5_9266 MQL5 Consecutive Fractal Chain"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9266;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period        = 14;
input int    strategy_ema_period        = 50;
input double strategy_chain_atr_mult    = 0.75;
input double strategy_stop_atr_mult     = 0.50;
input double strategy_take_rr           = 2.20;
input int    strategy_max_hold_bars     = 24;
input int    strategy_fractal_lookback  = 80;

double g_long_chain_level = 0.0;
double g_short_chain_level = 0.0;

bool Strategy_IsValidPrice(const double price)
  {
   return (price > 0.0 && price < EMPTY_VALUE / 2.0);
  }

double Strategy_LastClosedClose()
  {
   return iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: one closed-bar close read for bespoke fractal-chain structural exits.
  }

bool Strategy_FindFractalChain(const bool want_lower,
                               double &recent_level,
                               double &older_level)
  {
   recent_level = 0.0;
   older_level = 0.0;

   const int max_shift = MathMax(3, strategy_fractal_lookback);
   for(int shift = 2; shift <= max_shift; ++shift)
     {
      const double lower = QM_FractalLower(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
      const double upper = QM_FractalUpper(_Symbol, (ENUM_TIMEFRAMES)_Period, shift);
      const bool has_lower = Strategy_IsValidPrice(lower);
      const bool has_upper = Strategy_IsValidPrice(upper);

      if(has_lower && has_upper)
         return false;

      if(want_lower)
        {
         if(has_upper)
            return false;
         if(has_lower)
           {
            if(!Strategy_IsValidPrice(recent_level))
              {
               recent_level = lower;
               continue;
              }
            older_level = lower;
            return true;
           }
        }
      else
        {
         if(has_lower)
            return false;
         if(has_upper)
           {
            if(!Strategy_IsValidPrice(recent_level))
              {
               recent_level = upper;
               continue;
              }
            older_level = upper;
            return true;
           }
        }
     }

   return false;
  }

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type,
                              ulong &ticket,
                              datetime &opened_at)
  {
   position_type = POSITION_TYPE_BUY;
   ticket = 0;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
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

   if(strategy_atr_period <= 0 ||
      strategy_ema_period <= 0 ||
      strategy_chain_atr_mult <= 0.0 ||
      strategy_stop_atr_mult <= 0.0 ||
      strategy_take_rr <= 0.0)
      return false;

   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(position_type, ticket, opened_at))
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double recent = 0.0;
   double older = 0.0;
   const int ema_state = QM_Sig_Price_Above_MA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 0.0, 1);

   if(ema_state > 0 && Strategy_FindFractalChain(true, recent, older))
     {
      if(MathAbs(recent - older) > strategy_chain_atr_mult * atr)
         return false;

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double entry = (ask > 0.0) ? ask : bid;
      if(entry <= 0.0)
         return false;

      const double chain_level = MathMin(recent, older);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, chain_level - strategy_stop_atr_mult * atr);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_rr);
      req.reason = "FRACTAL_CHAIN_LONG";
      g_long_chain_level = chain_level;
      return (req.tp > entry);
     }

   if(ema_state < 0 && Strategy_FindFractalChain(false, recent, older))
     {
      if(MathAbs(recent - older) > strategy_chain_atr_mult * atr)
         return false;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double entry = (bid > 0.0) ? bid : ask;
      if(entry <= 0.0)
         return false;

      const double chain_level = MathMax(recent, older);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, chain_level + strategy_stop_atr_mult * atr);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_rr);
      req.reason = "FRACTAL_CHAIN_SHORT";
      g_short_chain_level = chain_level;
      return (req.tp > 0.0 && req.tp < entry);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(position_type, ticket, opened_at))
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(strategy_max_hold_bars > 0 && seconds_per_bar > 0 && opened_at > 0)
     {
      if(TimeCurrent() - opened_at >= strategy_max_hold_bars * seconds_per_bar)
         return true;
     }

   const double close_last = Strategy_LastClosedClose();
   if(close_last <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      if(g_long_chain_level > 0.0 && close_last < g_long_chain_level)
         return true;

      const double upper = QM_FractalUpper(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
      if(Strategy_IsValidPrice(upper) &&
         QM_Sig_Price_Above_MA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 0.0, 1) < 0)
         return true;
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      if(g_short_chain_level > 0.0 && close_last > g_short_chain_level)
         return true;

      const double lower = QM_FractalLower(_Symbol, (ENUM_TIMEFRAMES)_Period, 2);
      if(Strategy_IsValidPrice(lower) &&
         QM_Sig_Price_Above_MA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 0.0, 1) > 0)
         return true;
     }

   return false;
  }

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
