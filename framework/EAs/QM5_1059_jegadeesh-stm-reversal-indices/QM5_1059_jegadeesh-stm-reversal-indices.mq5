#property strict
#property version   "5.0"
#property description "QM5_1059 Jegadeesh Short-Term Reversal Index Basket"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1059_jegadeesh-stm-reversal-indices
// Card: Jegadeesh Short-Term Reversal — Index Basket (STMR-1W)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1059;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
// Card holds Friday-to-Friday and rebalances at Friday 22:00 broker time.
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 22;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_signal_hour_broker  = 22;
input int    strategy_return_d1_bars      = 5;
input int    strategy_atr_stop_period     = 14;
input double strategy_atr_stop_mult       = 3.0;
input int    strategy_vol_atr_period      = 20;
input double strategy_vol_max_atr_close   = 0.03;
input int    strategy_spread_median_bars  = 20;
input double strategy_spread_mult         = 5.0;
input int    strategy_min_rank_symbols    = 4;

#define STRATEGY_UNIVERSE_SIZE 4
string g_strategy_symbols[STRATEGY_UNIVERSE_SIZE] =
  {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX"
  };

int g_entry_week_done = -1;
int g_exit_week_done = -1;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_strategy_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   return (idx >= 0) ? idx : qm_magic_slot_offset;
  }

int Strategy_WeekKey(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_IsFridayRebalanceTime(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return (dt.day_of_week == 5 && dt.hour >= strategy_signal_hour_broker);
  }

bool Strategy_CurrentPrice(const string symbol, double &price)
  {
   price = 0.0;
   if(!QM_SymbolAssertOrLog(symbol))
      return false;
   SymbolSelect(symbol, true);

   const double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid > 0.0 && ask > 0.0)
     {
      price = 0.5 * (bid + ask);
      return true;
     }
   if(bid > 0.0)
     {
      price = bid;
      return true;
     }
   if(ask > 0.0)
     {
      price = ask;
      return true;
     }
   return false;
  }

bool Strategy_ReadD1Close(const string symbol, const int shift, double &close_price)
  {
   close_price = 0.0;
   if(shift < 1 || !QM_SymbolAssertOrLog(symbol))
      return false;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(symbol, PERIOD_D1, shift, 1, closes); // perf-allowed: one closed-bar basket read for weekly ranking.
   if(copied != 1 || closes[0] <= 0.0)
      return false;

   close_price = closes[0];
   return true;
  }

bool Strategy_Return5D(const string symbol, double &out_return)
  {
   out_return = 0.0;
   if(strategy_return_d1_bars <= 0)
      return false;

   double current_close = 0.0;
   double prior_close = 0.0;
   if(!Strategy_CurrentPrice(symbol, current_close))
      return false;
   if(!Strategy_ReadD1Close(symbol, strategy_return_d1_bars, prior_close))
      return false;
   if(current_close <= 0.0 || prior_close <= 0.0)
      return false;

   out_return = (current_close / prior_close) - 1.0;
   return true;
  }

bool Strategy_MedianSpreadPoints(const string symbol, double &median_spread)
  {
   median_spread = 0.0;
   if(strategy_spread_median_bars <= 0 || !QM_SymbolAssertOrLog(symbol))
      return false;

   int spreads[];
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(symbol, PERIOD_H1, 1, strategy_spread_median_bars, spreads); // perf-allowed: bounded weekly spread gate.
   if(copied <= 0)
      return false;

   double values[];
   ArrayResize(values, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(spreads[i] <= 0)
         continue;
      values[count] = (double)spreads[i];
      ++count;
     }
   if(count <= 0)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   median_spread = ((count % 2) == 1)
                   ? values[count / 2]
                   : 0.5 * (values[(count / 2) - 1] + values[count / 2]);
   return (median_spread > 0.0);
  }

bool Strategy_SpreadAllowsEntry(const string symbol)
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   double median_spread = 0.0;
   if(!Strategy_MedianSpreadPoints(symbol, median_spread))
      return true;

   const long current_spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_VolatilityAllowsEntry(const string symbol)
  {
   double current_close = 0.0;
   if(!Strategy_CurrentPrice(symbol, current_close))
      return false;

   const double atr = QM_ATR(symbol, PERIOD_D1, strategy_vol_atr_period, 1);
   if(current_close <= 0.0 || atr <= 0.0)
      return false;
   return ((atr / current_close) <= strategy_vol_max_atr_close);
  }

bool Strategy_HasOpenPosition()
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

int Strategy_ReversalDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[STRATEGY_UNIVERSE_SIZE];
   int indexes[STRATEGY_UNIVERSE_SIZE];
   int count = 0;

   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      const string symbol = g_strategy_symbols[i];
      if(!Strategy_SpreadAllowsEntry(symbol))
         continue;
      if(!Strategy_VolatilityAllowsEntry(symbol))
         continue;

      double score = 0.0;
      if(!Strategy_Return5D(symbol, score))
         continue;

      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_min_rank_symbols)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double tmp_score = scores[i];
            scores[i] = scores[j];
            scores[j] = tmp_score;

            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   if(indexes[0] == current_index)
      return 1;
   if(indexes[count - 1] == current_index)
      return -1;
   return 0;
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1059_STMR_WEEKLY";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridayRebalanceTime(broker_now))
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_entry_week_done)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int direction = Strategy_ReversalDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_stop_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1059_STMR_LONG_BOTTOM1" : "QM5_1059_STMR_SHORT_TOP1";
   g_entry_week_done = week_key;
   g_exit_week_done = week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies weekly hold with a hard 3x ATR stop only.
  }

bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   if(!Strategy_IsFridayRebalanceTime(broker_now))
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int week_key = Strategy_WeekKey(broker_now);
   if(week_key <= 0 || week_key == g_exit_week_done)
      return false;

   g_exit_week_done = week_key;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — unchanged except for basket symbol-guard registration.
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
   QM_BasketWarmupHistory(g_strategy_symbols, PERIOD_D1, 80);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1059\",\"ea\":\"jegadeesh-stm-reversal-indices\"}");
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
