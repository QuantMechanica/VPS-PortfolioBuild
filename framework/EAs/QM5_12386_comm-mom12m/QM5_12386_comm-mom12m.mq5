#property strict
#property version   "5.0"
#property description "QM5_12386 Commodity Twelve-Month Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12386;
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
input bool   qm_friday_close_enabled    = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1 = 252;
input int    strategy_atr_period           = 20;
input double strategy_atr_stop_mult        = 3.0;
input int    strategy_min_symbols          = 4;
input int    strategy_spread_lookback_d1   = 60;
input double strategy_spread_median_mult   = 2.0;

#define STRATEGY_SYMBOL_COUNT 4

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX"
  };

int g_last_entry_rebalance_key = -1;
int g_last_exit_rebalance_key = -1;

int MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool OurPosition(ENUM_POSITION_TYPE &ptype)
  {
   ptype = POSITION_TYPE_BUY;
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

int BasketRank(string &best_symbol, string &worst_symbol)
  {
   best_symbol = "";
   worst_symbol = "";
   double best_mom = -DBL_MAX;
   double worst_mom = DBL_MAX;
   int tradable = 0;

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      const string sym = g_strategy_symbols[i];
      const double mom = QM_Momentum(sym, PERIOD_D1, strategy_momentum_lookback_d1, 1, PRICE_CLOSE);
      const double atr = QM_ATR(sym, PERIOD_D1, strategy_atr_period, 1);
      if(mom <= 0.0 || atr <= 0.0)
         continue;

      tradable++;
      if(mom > best_mom)
        {
         best_mom = mom;
         best_symbol = sym;
        }
      if(mom < worst_mom)
        {
         worst_mom = mom;
         worst_symbol = sym;
        }
     }

   return tradable;
  }

// perf-allowed: EntrySignal is framework new-bar gated; this reads D1 spread
// history only to implement the card's MedianSpread(60D) filter.
int MedianSpreadD1(const string sym, const int lookback)
  {
   if(lookback <= 0)
      return 0;

   MqlRates rates[];
   const int copied = CopyRates(sym, PERIOD_D1, 1, lookback, rates);
   if(copied <= 0)
      return 0;

   int spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread < 0)
         continue;
      spreads[n] = rates[i].spread;
      n++;
     }
   if(n <= 0)
      return 0;

   for(int i = 0; i < n - 1; ++i)
      for(int j = i + 1; j < n; ++j)
         if(spreads[j] < spreads[i])
           {
            const int tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }

   return spreads[n / 2];
  }

bool SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(!(ask > bid))
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const int current_spread = (int)MathRound((ask - bid) / point);
   if(current_spread <= 0)
      return true;

   const int median_spread = MedianSpreadD1(_Symbol, strategy_spread_lookback_d1);
   if(median_spread <= 0)
      return false;

   const int cap = (int)MathMax(1.0, MathRound(strategy_spread_median_mult * median_spread));
   return (current_spread <= cap);
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
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

   const int month_key = MonthKey(TimeCurrent());
   if(month_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = month_key;

   if(strategy_momentum_lookback_d1 < 1 ||
      strategy_atr_period < 1 ||
      strategy_min_symbols < STRATEGY_SYMBOL_COUNT)
      return false;

   ENUM_POSITION_TYPE ptype;
   if(OurPosition(ptype))
      return false;

   if(!SpreadAllowsEntry())
      return false;

   string best_symbol;
   string worst_symbol;
   const int tradable = BasketRank(best_symbol, worst_symbol);
   if(tradable < strategy_min_symbols)
      return false;

   if(_Symbol != best_symbol && _Symbol != worst_symbol)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool go_long = (_Symbol == best_symbol);
   req.type = go_long ? QM_BUY : QM_SELL;

   double entry_estimate = go_long ? ask : bid;
   if(entry_estimate <= 0.0)
      entry_estimate = go_long ? bid : ask;
   if(entry_estimate <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_estimate, atr, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = go_long ? "COMM_MOM12M_LONG_STRONGEST" : "COMM_MOM12M_SHORT_WEAKEST";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   ENUM_POSITION_TYPE ptype;
   if(!OurPosition(ptype))
      return false;

   string best_symbol;
   string worst_symbol;
   const int tradable = BasketRank(best_symbol, worst_symbol);
   if(tradable < strategy_min_symbols)
      return true;

   const int month_key = MonthKey(TimeCurrent());
   if(month_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = month_key;

   if(ptype == POSITION_TYPE_BUY && _Symbol != best_symbol)
      return true;
   if(ptype == POSITION_TYPE_SELL && _Symbol != worst_symbol)
      return true;

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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, strategy_momentum_lookback_d1 + 10);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12386_comm_mom12m\"}");
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
