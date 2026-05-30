#property strict
#property version   "5.0"
#property description "QM5_10022 Robot Wealth Dual Momentum Rotation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10022;
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
input int    strategy_momentum_d1_bars   = 126;
input int    strategy_max_holdings       = 3;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 3.0;

const int STRATEGY_UNIVERSE_SIZE = 4;
string g_strategy_symbols[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "XAUUSD.DWX"};

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_MonthOf(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.mon;
  }

bool Strategy_IsMonthlyRebalance()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;
   return (Strategy_MonthOf(current_d1) != Strategy_MonthOf(prior_d1));
  }

double Strategy_TotalReturn(const string symbol)
  {
   if(strategy_momentum_d1_bars < 1)
      return -DBL_MAX;
   if(!SymbolSelect(symbol, true))
      return -DBL_MAX;
   if(Bars(symbol, PERIOD_D1) < strategy_momentum_d1_bars + 2)
      return -DBL_MAX;

   const double recent_close = QM_SMA(symbol, PERIOD_D1, 1, 1);
   const double lookback_close = QM_SMA(symbol, PERIOD_D1, 1, 1 + strategy_momentum_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return -DBL_MAX;

   return (recent_close / lookback_close) - 1.0;
  }

bool Strategy_SymbolSelected()
  {
   const int current_idx = Strategy_CurrentSymbolIndex();
   if(current_idx < 0)
      return false;

   double returns[4];
   int ranks[4] = {0, 1, 2, 3};
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      returns[i] = Strategy_TotalReturn(g_strategy_symbols[i]);

   for(int a = 0; a < STRATEGY_UNIVERSE_SIZE - 1; ++a)
     {
      for(int b = a + 1; b < STRATEGY_UNIVERSE_SIZE; ++b)
        {
         if(returns[ranks[b]] > returns[ranks[a]])
           {
            const int tmp = ranks[a];
            ranks[a] = ranks[b];
            ranks[b] = tmp;
           }
        }
     }

   const int hold_count = MathMax(0, MathMin(strategy_max_holdings, STRATEGY_UNIVERSE_SIZE));
   for(int rank = 0; rank < hold_count; ++rank)
     {
      const int idx = ranks[rank];
      if(idx == current_idx && returns[idx] > 0.0)
         return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
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
      return true;
     }
   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int symbol_index = Strategy_CurrentSymbolIndex();
   if(symbol_index < 0)
      return true;
   return (symbol_index != qm_magic_slot_offset);
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

   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SymbolSelected())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, QM_BUY, ask, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.sl = sl;
   req.reason = "RW_DUAL_MOM_MONTHLY_LONG";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline uses monthly rotation exits and catastrophic ATR SL only.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalance())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;
   return !Strategy_SymbolSelected();
  }

// News Filter Hook
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
