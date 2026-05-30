#property strict
#property version   "5.0"
#property description "QM5_10424 Elite Trader EMA Stack Cross"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10424;
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
input int    strategy_fast_ema_period   = 20;
input int    strategy_mid_ema_period    = 50;
input int    strategy_slow_ema_period   = 100;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.0;
input double strategy_atr_tp_mult       = 3.0;
input bool   strategy_use_atr_target    = true;

bool g_skip_entry_after_exit = false;

bool HasOurOpenPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool EmaInputsValid()
  {
   return (strategy_fast_ema_period > 0 &&
           strategy_mid_ema_period > 0 &&
           strategy_slow_ema_period > 0 &&
           strategy_atr_period > 0 &&
           strategy_atr_sl_mult > 0.0 &&
           strategy_atr_tp_mult >= 0.0);
  }

int EmaCrossSignal()
  {
   if(!EmaInputsValid())
      return 0;

   const double fast_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 2);
   const double mid_1  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_mid_ema_period, 1);
   const double mid_2  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_mid_ema_period, 2);
   const double slow_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_slow_ema_period, 1);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || mid_1 <= 0.0 || mid_2 <= 0.0 || slow_1 <= 0.0)
      return 0;

   if(fast_2 <= mid_2 && fast_1 > mid_1 && mid_1 > slow_1)
      return 1;
   if(fast_2 >= mid_2 && fast_1 < mid_1 && mid_1 < slow_1)
      return -1;

   return 0;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
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

   if(g_skip_entry_after_exit)
     {
      g_skip_entry_after_exit = false;
      return false;
     }

   ENUM_POSITION_TYPE existing_type = POSITION_TYPE_BUY;
   if(HasOurOpenPosition(existing_type))
      return false;

   const int signal = EmaCrossSignal();
   if(signal == 0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopRulesStopFromDistance(_Symbol, req.type, req.price, atr * strategy_atr_sl_mult);
   if(strategy_use_atr_target && strategy_atr_tp_mult > 0.0)
      req.tp = QM_StopRulesTakeFromDistance(_Symbol, req.type, req.price, atr * strategy_atr_tp_mult);
   req.reason = (signal > 0) ? "ET_EMA_STACK_LONG" : "ET_EMA_STACK_SHORT";

   return (req.sl > 0.0 && (!strategy_use_atr_target || req.tp > 0.0));
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card defines no trailing, break-even, partial close, or add-on logic.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!HasOurOpenPosition(position_type))
      return false;

   const double fast_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 1);
   const double fast_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_fast_ema_period, 2);
   const double mid_1  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_mid_ema_period, 1);
   const double mid_2  = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_mid_ema_period, 2);
   if(fast_1 <= 0.0 || fast_2 <= 0.0 || mid_1 <= 0.0 || mid_2 <= 0.0)
      return false;

   const bool exit_long = (position_type == POSITION_TYPE_BUY && fast_2 >= mid_2 && fast_1 < mid_1);
   const bool exit_short = (position_type == POSITION_TYPE_SELL && fast_2 <= mid_2 && fast_1 > mid_1);
   if(exit_long || exit_short)
     {
      g_skip_entry_after_exit = true;
      return true;
     }

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
