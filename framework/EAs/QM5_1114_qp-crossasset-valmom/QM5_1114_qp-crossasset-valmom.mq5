#property strict
#property version   "5.0"
#property description "QM5_1114 Quantpedia Cross-Asset Value Momentum Combo"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1114;
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
input string strategy_value_csv_path      = "QM5_1114_crossasset_value.csv";
input int    strategy_momentum_12m_bars   = 252;
input int    strategy_momentum_1m_bars    = 21;
input int    strategy_min_d1_bars         = 270;
input double strategy_weight_mom_12m      = 0.25;
input double strategy_weight_mom_1m       = 0.25;
input double strategy_weight_value        = 0.50;
input double strategy_bucket_pct          = 25.0;
input int    strategy_min_eligible        = 4;
input int    strategy_value_stale_days    = 45;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 5.0;
input int    strategy_max_spread_points   = 0;

#define QM5_1114_SYMBOL_COUNT 8

string g_symbols[QM5_1114_SYMBOL_COUNT] = {
   "SP500.DWX",
   "NDX.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "JPN225.DWX",
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX"
};

int g_slots[QM5_1114_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6, 7};

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1114_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsMonthEndRebalanceDay(const datetime closed_day)
  {
   if(closed_day <= 0)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_day, closed_dt);
   TimeToStruct(current_day, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
  }

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(StringSubstr(s, 0, 10) + " 00:00");
  }

bool Strategy_FieldMatchesSymbol(const string field, const int index)
  {
   string f = field;
   StringTrimLeft(f);
   StringTrimRight(f);
   StringToUpper(f);

   string symbol = g_symbols[index];
   StringToUpper(symbol);
   return (f == symbol);
  }

bool Strategy_ReadLatestValueScore(const int index,
                                   const datetime as_of,
                                   double &out_score,
                                   datetime &out_obs_date)
  {
   out_score = 0.0;
   out_obs_date = 0;
   if(index < 0 || index >= QM5_1114_SYMBOL_COUNT || strategy_value_csv_path == "")
      return false;

   int handle = FileOpen(strategy_value_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_value_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string symbol_field = FileReadString(handle);
      const string score_field = FileReadString(handle);
      if(date_field == "" && symbol_field == "" && score_field == "")
         continue;

      const datetime obs_date = Strategy_ParseDate(date_field);
      if(obs_date <= 0 || obs_date > as_of)
         continue;
      if(!Strategy_FieldMatchesSymbol(symbol_field, index))
         continue;

      const double score = StringToDouble(score_field);
      if(obs_date >= out_obs_date)
        {
         out_obs_date = obs_date;
         out_score = score;
        }
     }

   FileClose(handle);
   if(out_obs_date <= 0)
      return false;
   if(strategy_value_stale_days > 0 && (as_of - out_obs_date) > strategy_value_stale_days * 86400)
      return false;

   return true;
  }

bool Strategy_ReturnOverBars(const string symbol, const int lookback_bars, double &out_return)
  {
   out_return = 0.0;
   if(lookback_bars <= 0)
      return false;
   if(Bars(symbol, PERIOD_D1) < MathMax(strategy_min_d1_bars, lookback_bars + 5))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double past_close = iClose(symbol, PERIOD_D1, 1 + lookback_bars);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   out_return = (recent_close / past_close) - 1.0;
   return true;
  }

int Strategy_BuildScores(const datetime rebalance_day,
                         bool &eligible[],
                         double &composite[])
  {
   double ret12[QM5_1114_SYMBOL_COUNT];
   double ret1[QM5_1114_SYMBOL_COUNT];
   double value[QM5_1114_SYMBOL_COUNT];
   ArrayInitialize(ret12, 0.0);
   ArrayInitialize(ret1, 0.0);
   ArrayInitialize(value, 0.0);
   ArrayInitialize(composite, 0.0);

   int count = 0;
   for(int i = 0; i < QM5_1114_SYMBOL_COUNT; ++i)
     {
      eligible[i] = false;
      if(!SymbolSelect(g_symbols[i], true))
         continue;
      datetime value_date = 0;
      if(!Strategy_ReturnOverBars(g_symbols[i], strategy_momentum_12m_bars, ret12[i]))
         continue;
      if(!Strategy_ReturnOverBars(g_symbols[i], strategy_momentum_1m_bars, ret1[i]))
         continue;
      if(!Strategy_ReadLatestValueScore(i, rebalance_day, value[i], value_date))
         continue;
      eligible[i] = true;
      ++count;
     }

   if(count < strategy_min_eligible)
      return count;

   for(int i = 0; i < QM5_1114_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i])
         continue;

      int rank12 = 1;
      int rank1 = 1;
      int rank_value = 1;
      for(int j = 0; j < QM5_1114_SYMBOL_COUNT; ++j)
        {
         if(!eligible[j])
            continue;
         if(ret12[j] < ret12[i])
            ++rank12;
         if(ret1[j] < ret1[i])
            ++rank1;
         if(value[j] < value[i])
            ++rank_value;
        }

      composite[i] = strategy_weight_mom_12m * rank12
                   + strategy_weight_mom_1m * rank1
                   + strategy_weight_value * rank_value;
     }

   return count;
  }

bool Strategy_CurrentSelection(QM_OrderType &out_side)
  {
   out_side = QM_BUY;

   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0 || strategy_bucket_pct <= 0.0)
      return false;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(rebalance_day <= 0)
      return false;

   bool eligible[QM5_1114_SYMBOL_COUNT];
   double composite[QM5_1114_SYMBOL_COUNT];
   const int count = Strategy_BuildScores(rebalance_day, eligible, composite);
   if(count < strategy_min_eligible || !eligible[current_index])
      return false;

   int bucket = (int)MathCeil((double)count * strategy_bucket_pct / 100.0);
   bucket = MathMax(1, MathMin(bucket, count / 2));

   int better = 0;
   int worse = 0;
   for(int i = 0; i < QM5_1114_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i] || i == current_index)
         continue;
      if(composite[i] > composite[current_index])
         ++better;
      if(composite[i] < composite[current_index])
         ++worse;
     }

   if(better < bucket)
     {
      out_side = QM_BUY;
      return true;
     }
   if(worse < bucket)
     {
      out_side = QM_SELL;
      return true;
     }

   return false;
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, QM_OrderType &side)
  {
   ticket = 0;
   opened_at = 0;
   side = QM_BUY;

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
      side = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ? QM_SELL : QM_BUY;
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
   if(strategy_max_spread_points > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > strategy_max_spread_points)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthEndRebalanceDay(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;

   QM_OrderType selected_side = QM_BUY;
   if(!Strategy_CurrentSelection(selected_side))
      return false;

   const double entry = QM_OrderTypeIsBuy(selected_side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, selected_side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(selected_side) && sl >= entry)
      return false;
   if(!QM_OrderTypeIsBuy(selected_side) && sl <= entry)
      return false;

   req.type = selected_side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = QM_OrderTypeIsBuy(selected_side) ? "QM5_1114_CROSSASSET_VALMOM_LONG"
                                                 : "QM5_1114_CROSSASSET_VALMOM_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies only the hard ATR stop; no trailing, BE, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   QM_OrderType open_side = QM_BUY;
   if(!Strategy_HasOpenPosition(ticket, opened_at, open_side))
      return false;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthEndRebalanceDay(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;

   QM_OrderType selected_side = QM_BUY;
   if(!Strategy_CurrentSelection(selected_side))
     {
      g_last_exit_rebalance_day = rebalance_day;
      return true;
     }
   if(selected_side != open_side)
     {
      g_last_exit_rebalance_day = rebalance_day;
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_min_d1_bars, strategy_momentum_12m_bars + 5));

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1114_qp-crossasset-valmom\"}");
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
