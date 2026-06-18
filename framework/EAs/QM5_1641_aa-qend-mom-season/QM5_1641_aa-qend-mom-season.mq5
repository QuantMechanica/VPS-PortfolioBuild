#property strict
#property version   "5.0"
#property description "QM5_1641 Alpha Architect Quarter-End Momentum Seasonality"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1641;
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
input int    strategy_roc_months             = 12;
input int    strategy_exclude_recent_months  = 1;
input int    strategy_min_completed_months   = 14;
input int    strategy_month_copy_bars        = 360;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 3.0;
input int    strategy_spread_lookback_d1     = 20;
input double strategy_spread_median_mult     = 2.5;

#define STRATEGY_SYMBOL_COUNT 5

string g_strategy_symbols[STRATEGY_SYMBOL_COUNT] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "SP500.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

bool   g_rebalance_bar = false;
bool   g_rank_ready = false;
bool   g_target_selected = false;
int    g_eval_month_key = 0;
double g_symbol_roc[STRATEGY_SYMBOL_COUNT];
bool   g_symbol_positive[STRATEGY_SYMBOL_COUNT];

int Strategy_MonthKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_CurrentMonth()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.mon;
  }

bool Strategy_IsQuarterEndHoldingMonth()
  {
   const int mon = Strategy_CurrentMonth();
   if(mon == 1)
      return false;
   return (mon == 3 || mon == 6 || mon == 9 || mon == 12);
  }

int Strategy_SlotForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
      if(g_strategy_symbols[i] == symbol)
         return i;
   return -1;
  }

bool Strategy_HasOurPosition()
  {
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
      return true;
     }

   return false;
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, rates) != 2) // perf-allowed: fixed two-bar month boundary read inside the framework D1 new-bar gate.
      return false;

   return (Strategy_MonthKey(rates[0].time) != Strategy_MonthKey(rates[1].time));
  }

bool Strategy_ReadMonthEndCloses(const string symbol, double &out_closes[], int &out_count)
  {
   out_count = 0;
   ArrayResize(out_closes, 0);

   const int min_needed = (strategy_min_completed_months > strategy_roc_months + 1)
                          ? strategy_min_completed_months
                          : strategy_roc_months + 1;
   if(min_needed <= 0 || strategy_month_copy_bars < 120)
      return false;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, strategy_month_copy_bars, rates); // perf-allowed: bounded D1 month-end extraction called only from the framework new-bar-gated monthly rebalance.
   if(copied <= 0)
      return false;

   int last_key = 0;
   for(int i = 0; i < copied; ++i)
     {
      const int key = Strategy_MonthKey(rates[i].time);
      if(key <= 0 || key == last_key)
         continue;

      last_key = key;
      if(rates[i].close <= 0.0)
         return false;

      ArrayResize(out_closes, out_count + 1);
      out_closes[out_count] = rates[i].close;
      ++out_count;

      if(out_count >= min_needed)
         break;
     }

   return (out_count >= min_needed);
  }

bool Strategy_ComputeRoc121(const string symbol, double &out_roc)
  {
   out_roc = 0.0;
   if(strategy_roc_months < 2 || strategy_exclude_recent_months < 1)
      return false;
   if(strategy_roc_months <= strategy_exclude_recent_months)
      return false;

   double closes[];
   int count = 0;
   if(!Strategy_ReadMonthEndCloses(symbol, closes, count))
      return false;

   const int recent_idx = strategy_exclude_recent_months;
   const int past_idx = strategy_roc_months;
   if(recent_idx < 0 || past_idx >= count)
      return false;

   const double recent = closes[recent_idx];
   const double past = closes[past_idx];
   if(recent <= 0.0 || past <= 0.0)
      return false;

   out_roc = (recent / past) - 1.0;
   return MathIsValidNumber(out_roc);
  }

void Strategy_AdvanceMonthlyRank()
  {
   g_rebalance_bar = true;
   g_rank_ready = false;
   g_target_selected = false;
   g_eval_month_key = Strategy_MonthKey(TimeCurrent());

   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      g_symbol_roc[i] = 0.0;
      g_symbol_positive[i] = false;
     }

   if(!Strategy_IsQuarterEndHoldingMonth())
      return;

   int eligible = 0;
   int eligible_slots[STRATEGY_SYMBOL_COUNT];
   for(int i = 0; i < STRATEGY_SYMBOL_COUNT; ++i)
     {
      double roc = 0.0;
      if(!Strategy_ComputeRoc121(g_strategy_symbols[i], roc))
         continue;

      g_symbol_roc[i] = roc;
      if(roc <= 0.0)
         continue;

      g_symbol_positive[i] = true;
      eligible_slots[eligible] = i;
      ++eligible;
     }

   if(eligible <= 0)
      return;

   for(int a = 0; a < eligible - 1; ++a)
     {
      for(int b = a + 1; b < eligible; ++b)
        {
         if(g_symbol_roc[eligible_slots[b]] > g_symbol_roc[eligible_slots[a]])
           {
            const int tmp = eligible_slots[a];
            eligible_slots[a] = eligible_slots[b];
            eligible_slots[b] = tmp;
           }
        }
     }

   int top_count = (eligible + 2) / 3;
   if(top_count < 1)
      top_count = 1;

   const int host_slot = Strategy_SlotForSymbol(_Symbol);
   for(int i = 0; i < top_count; ++i)
     {
      if(eligible_slots[i] == host_slot)
        {
         g_target_selected = true;
         break;
        }
     }

   g_rank_ready = true;
  }

double Strategy_MedianSpreadPoints(const string symbol)
  {
   if(strategy_spread_lookback_d1 <= 0)
      return 0.0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, strategy_spread_lookback_d1, rates); // perf-allowed: bounded D1 spread-median window called only on monthly entry evaluation.
   if(copied <= 0)
      return 0.0;

   double spreads[];
   ArrayResize(spreads, copied);
   int n = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[n] = (double)rates[i].spread;
         ++n;
        }
     }

   if(n <= 0)
      return 0.0;
   ArrayResize(spreads, n);

   for(int a = 0; a < n - 1; ++a)
     {
      for(int b = a + 1; b < n; ++b)
        {
         if(spreads[b] < spreads[a])
           {
            const double tmp = spreads[a];
            spreads[a] = spreads[b];
            spreads[b] = tmp;
           }
        }
     }

   if((n % 2) == 1)
      return spreads[n / 2];
   return 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask <= bid)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double median_spread = Strategy_MedianSpreadPoints(_Symbol);
   if(median_spread <= 0.0)
      return true;

   const double current_spread = (ask - bid) / point;
   return (current_spread <= strategy_spread_median_mult * median_spread);
  }

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;

   const int slot = Strategy_SlotForSymbol(_Symbol);
   if(slot < 0)
      return true;
   if(qm_magic_slot_offset != slot)
      return true;

   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_spread_median_mult <= 0.0)
      return true;

   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = Strategy_SlotForSymbol(_Symbol);
   req.expiration_seconds = 0;

   if(req.symbol_slot < 0)
      return false;
   if(!g_rebalance_bar || !g_rank_ready || !g_target_selected)
      return false;
   if(Strategy_HasOurPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "QM5_1641_QEND_MOM_TOP_THIRD_LONG";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Card specifies an initial ATR stop and monthly rebalance exits only.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_rebalance_bar)
      return false;
   if(!Strategy_HasOurPosition())
      return false;

   return true;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — unchanged except basket symbol guard, D1 warmup, and
// single-consume new-bar latching for monthly rank/close/open sequencing.
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

   QM_SymbolGuardInit(g_strategy_symbols);
   QM_BasketWarmupHistory(g_strategy_symbols,
                          PERIOD_D1,
                          strategy_month_copy_bars + strategy_atr_period_d1 + strategy_spread_lookback_d1 + 10);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1641\",\"ea\":\"QM5_1641_aa-qend-mom-season\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_rebalance_bar = false;

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

   const bool nb = QM_IsNewBar();
   if(!nb)
      return;

   QM_EquityStreamOnNewBar();

   if(Strategy_IsMonthlyRebalanceBar())
      Strategy_AdvanceMonthlyRank();

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
