#property strict
#property version   "5.0"
#property description "QM5_1141 De Bondt-Thaler 3Y Index Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1141;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_recent_offset_d1_bars = 21;
input int    strategy_lookback_d1_bars      = 756;
input int    strategy_min_d1_bars           = 790;
input int    strategy_bottom_bucket_size    = 2;
input int    strategy_top_bucket_size       = 2;
input bool   strategy_enable_short_top      = false;
input int    strategy_atr_period_d1         = 14;
input double strategy_atr_sl_mult           = 4.0;
input bool   strategy_spread_filter_enabled = true;
input int    strategy_spread_days           = 20;
input double strategy_spread_median_mult    = 3.0;

#define QM5_1141_SYMBOL_COUNT 5

string g_symbols[QM5_1141_SYMBOL_COUNT] =
  {
   "GDAXI.DWX",
   "NDX.DWX",
   "UK100.DWX",
   "WS30.DWX",
   "SP500.DWX"
  };

int g_slots[QM5_1141_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1141_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CurrentSymbolSlot()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
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
   if(_Period != PERIOD_D1)
      return false;

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
   return (iBars(symbol, PERIOD_D1) >= strategy_min_d1_bars);
  }

void Strategy_SortDoubleAscending(double &scores[], int &indexes[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double score_tmp = scores[i];
            scores[i] = scores[j];
            scores[j] = score_tmp;

            const int index_tmp = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = index_tmp;
           }
  }

void Strategy_SortDoubleForMedian(double &values[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }
  }

bool Strategy_SpreadAllowed(const string symbol)
  {
   if(!strategy_spread_filter_enabled)
      return true;
   if(strategy_spread_days <= 0 || strategy_spread_days > 64)
      return true;
   if(strategy_spread_median_mult <= 0.0)
      return false;

   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;

   double spreads[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_days; ++shift)
     {
      const long spread = iSpread(symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }

   if(count < MathMin(10, strategy_spread_days))
      return true;

   Strategy_SortDoubleForMedian(spreads, count);
   double median = 0.0;
   if((count % 2) == 1)
      median = spreads[count / 2];
   else
      median = 0.5 * (spreads[(count / 2) - 1] + spreads[count / 2]);

   return ((double)current_spread <= median * strategy_spread_median_mult);
  }

bool Strategy_Return36M(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_recent_offset_d1_bars <= 0)
      return false;
   if(strategy_lookback_d1_bars <= strategy_recent_offset_d1_bars)
      return false;
   if(!Strategy_HasSufficientBars(symbol))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, strategy_recent_offset_d1_bars);
   const double lookback_close = iClose(symbol, PERIOD_D1, strategy_lookback_d1_bars + strategy_recent_offset_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

int Strategy_RankDirectionForCurrentSymbol()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[QM5_1141_SYMBOL_COUNT];
   int indexes[QM5_1141_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_1141_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_Return36M(g_symbols[i], score))
         continue;

      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count <= 0)
      return 0;

   Strategy_SortDoubleAscending(scores, indexes, count);

   const int long_bucket = MathMin(MathMax(1, strategy_bottom_bucket_size), count);
   for(int i = 0; i < long_bucket; ++i)
      if(indexes[i] == current_index)
         return 1;

   if(strategy_enable_short_top)
     {
      const int short_bucket = MathMin(MathMax(1, strategy_top_bucket_size), count);
      for(int i = count - short_bucket; i < count; ++i)
         if(i >= 0 && indexes[i] == current_index)
            return -1;
     }

   return 0;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at, int &direction)
  {
   ticket = 0;
   opened_at = 0;
   direction = 0;

   const int magic = QM_Magic(qm_ea_id, Strategy_CurrentSymbolSlot());
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
      const long type = PositionGetInteger(POSITION_TYPE);
      direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
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
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
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
   int open_direction = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at, open_direction))
      return false;

   const int desired_direction = Strategy_RankDirectionForCurrentSymbol();
   if(desired_direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const QM_OrderType order_type = (desired_direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (desired_direction > 0) ? ask : bid;
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, order_type, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(order_type == QM_BUY && sl >= entry)
      return false;
   if(order_type == QM_SELL && sl <= entry)
      return false;

   req.type = order_type;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (desired_direction > 0) ? "QM5_1141_3Y_REVERSAL_BOTTOM_BUCKET" : "QM5_1141_3Y_REVERSAL_TOP_SHORT";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
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
   int open_direction = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at, open_direction))
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

   const int desired_direction = Strategy_RankDirectionForCurrentSymbol();
   g_last_exit_rebalance_key = rebalance_key;
   return (desired_direction != open_direction);
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_min_d1_bars + strategy_recent_offset_d1_bars + 30);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1141_debondt-thaler-3y-reversal-idx\"}");
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
      const int magic = QM_Magic(qm_ea_id, Strategy_CurrentSymbolSlot());
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
