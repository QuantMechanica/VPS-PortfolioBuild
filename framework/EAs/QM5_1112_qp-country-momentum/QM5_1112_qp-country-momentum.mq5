#property strict
#property version   "5.0"
#property description "QM5_1112 Quantpedia Country Index Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1112;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_return_lookback_months = 11;
input int    strategy_min_bars_d1            = 270;
input int    strategy_bucket_size_small      = 2;
input int    strategy_bucket_size_large      = 5;
input int    strategy_large_universe_min     = 10;
input int    strategy_atr_period_d1          = 20;
input double strategy_atr_sl_mult            = 4.0;
input bool   strategy_spread_filter_enabled  = true;
input double strategy_max_spread_median_mult = 3.0;

#define QM5_1112_SYMBOL_COUNT 7

string g_symbols[QM5_1112_SYMBOL_COUNT] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "JPN225.DWX",
   "AUS200.DWX",
   "SP500.DWX"
  };
int g_slots[QM5_1112_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1112_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_slots[idx];
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsMonthlyRebalanceBar()
  {
   const datetime last_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime prev_bar = iTime(_Symbol, PERIOD_D1, 2);
   if(last_bar <= 0 || prev_bar <= 0)
      return false;

   MqlDateTime last_dt;
   MqlDateTime prev_dt;
   TimeToStruct(last_bar, last_dt);
   TimeToStruct(prev_bar, prev_dt);
   return (last_dt.year != prev_dt.year || last_dt.mon != prev_dt.mon);
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;

   const long trade_mode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   return (trade_mode != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_HasSufficientBars(const string symbol)
  {
   if(!Strategy_TradingStatusValid(symbol))
      return false;
   return (iBars(symbol, PERIOD_D1) >= strategy_min_bars_d1);
  }

void Strategy_SortIntAscending(int &values[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const int tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   if(!strategy_spread_filter_enabled)
      return true;
   if(strategy_max_spread_median_mult <= 0.0)
      return false;

   const int current_spread = (int)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return false;

   int spreads[20];
   int count = 0;
   for(int shift = 1; shift <= 20; ++shift)
     {
      const int spread = (int)iSpread(symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = spread;
      ++count;
     }

   if(count < 10)
      return false;

   Strategy_SortIntAscending(spreads, count);
   double median = 0.0;
   if((count % 2) == 1)
      median = (double)spreads[count / 2];
   else
      median = ((double)spreads[(count / 2) - 1] + (double)spreads[count / 2]) * 0.5;

   return ((double)current_spread <= median * strategy_max_spread_median_mult);
  }

bool Strategy_ReturnLookback(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_return_lookback_months <= 0)
      return false;
   if(!Strategy_HasSufficientBars(symbol))
      return false;
   if(Bars(symbol, PERIOD_MN1) < strategy_return_lookback_months + 2)
      return false;

   const double recent_close = iClose(symbol, PERIOD_MN1, 1);
   const double lookback_close = iClose(symbol, PERIOD_MN1, strategy_return_lookback_months + 1);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

void Strategy_SortDescending(double &scores[], int &indexes[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] > scores[i])
           {
            const double score_tmp = scores[i];
            scores[i] = scores[j];
            scores[j] = score_tmp;

            const int index_tmp = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = index_tmp;
           }
  }

int Strategy_SelectedBucketSize(const int eligible_count)
  {
   if(eligible_count >= strategy_large_universe_min)
      return MathMax(1, strategy_bucket_size_large);
   return MathMax(1, strategy_bucket_size_small);
  }

bool Strategy_IsSelectedTopMomentum()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return false;

   double scores[QM5_1112_SYMBOL_COUNT];
   int indexes[QM5_1112_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_1112_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_ReturnLookback(g_symbols[i], score))
         continue;

      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   const int bucket = MathMin(Strategy_SelectedBucketSize(count), count);
   if(bucket <= 0)
      return false;

   Strategy_SortDescending(scores, indexes, count);
   for(int i = 0; i < bucket; ++i)
      if(indexes[i] == current_index)
         return true;

   return false;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(!Strategy_SpreadAllowed(_Symbol))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(Strategy_LastClosedD1Time());
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;
   if(!Strategy_IsSelectedTopMomentum())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1112_COUNTRY_MOMENTUM_TOP_BUCKET";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_rebalance_key = rebalance_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies monthly rebalance exits plus the entry-time hard ATR stop.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   if(!Strategy_IsMonthlyRebalanceBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey(Strategy_LastClosedD1Time());
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   if(opened_at >= Strategy_LastClosedD1Time())
      return false;

   g_last_exit_rebalance_key = rebalance_key;
   return !Strategy_IsSelectedTopMomentum();
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_min_bars_d1 + (strategy_return_lookback_months * 23) + 30);
   QM_BasketWarmupHistory(g_symbols, PERIOD_MN1, strategy_return_lookback_months + 3);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1112_qp-country-momentum\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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
