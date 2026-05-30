#property strict
#property version   "5.0"
#property description "QM5_1105 Quantpedia Country Index 36 Month Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1105;
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
input int    strategy_return_lookback_d1  = 756;
input int    strategy_min_bars_d1         = 800;
input int    strategy_rebalance_month     = 1;
input int    strategy_rebalance_cadence_m = 36;
input int    strategy_bucket_size         = 2;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 4.0;

#define QM5_1105_SYMBOL_COUNT 5

string g_symbols[QM5_1105_SYMBOL_COUNT] = {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "SP500.DWX"
};
int g_slots[QM5_1105_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1105_SYMBOL_COUNT; ++i)
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

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsFirstClosedD1OfMonth(const datetime day)
  {
   if(day <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(day, dt);

   const datetime previous_day = day - 86400;
   MqlDateTime pdt;
   TimeToStruct(previous_day, pdt);
   return (pdt.mon != dt.mon);
  }

bool Strategy_IsRebalanceDay(const datetime day)
  {
   if(day <= 0 || strategy_rebalance_cadence_m <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(day, dt);
   if(dt.mon != strategy_rebalance_month)
      return false;
   if(!Strategy_IsFirstClosedD1OfMonth(day))
      return false;

   const int months_from_year_zero = dt.year * 12 + (dt.mon - 1);
   const int anchor_months = 2026 * 12 + (strategy_rebalance_month - 1);
   int delta = months_from_year_zero - anchor_months;
   while(delta < 0)
      delta += strategy_rebalance_cadence_m;
   return ((delta % strategy_rebalance_cadence_m) == 0);
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

bool Strategy_Return36M(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_return_lookback_d1 <= 0)
      return false;
   if(!Strategy_HasSufficientBars(symbol))
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, strategy_return_lookback_d1 + 1);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_return = (recent_close / lookback_close) - 1.0;
   return true;
  }

void Strategy_SortAscending(double &scores[], int &indexes[], const int count)
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

int Strategy_ReversalDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[QM5_1105_SYMBOL_COUNT];
   int indexes[QM5_1105_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_1105_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_Return36M(g_symbols[i], score))
         continue;

      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_bucket_size * 2)
      return 0;

   Strategy_SortAscending(scores, indexes, count);
   const int bucket = MathMin(strategy_bucket_size, count / 2);

   for(int i = 0; i < bucket; ++i)
     {
      if(indexes[i] == current_index)
         return 1;
      if(indexes[count - 1 - i] == current_index)
         return -1;
     }

   return 0;
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
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsRebalanceDay(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const int direction = Strategy_ReversalDirection();
   if(direction == 0)
      return false;

   const QM_OrderType order_type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

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
   req.reason = (direction > 0) ? "QM5_1105_36M_REVERSAL_BOTTOM_LONG"
                                : "QM5_1105_36M_REVERSAL_TOP_SHORT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies scheduled rebalance exits plus the entry-time hard ATR stop.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   if(!Strategy_TradingStatusValid(_Symbol))
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsRebalanceDay(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;

   g_last_exit_rebalance_day = rebalance_day;
   return true;
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_min_bars_d1 + strategy_return_lookback_d1 + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1105_qp-country-reversal\"}");
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
