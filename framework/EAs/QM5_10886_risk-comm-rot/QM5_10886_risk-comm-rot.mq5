#property strict
#property version   "5.0"
#property description "QM5_10886 Risk.net Commodity Momentum Mean-Reversion Rotator"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10886;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.25;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_lookback_d1 = 126;
input int    strategy_percentile_bars      = 252;
input int    strategy_realized_vol_days    = 63;
input double strategy_meanrev_percentile   = 25.0;
input double strategy_high_vol_percentile  = 75.0;
input int    strategy_max_selected         = 4;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input double strategy_spread_max_points    = 0.0;

#define QM5_10886_SYMBOL_COUNT 4

string g_symbols[QM5_10886_SYMBOL_COUNT] =
  {
   "XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX", "XNGUSD.DWX"
  };

int g_slots[QM5_10886_SYMBOL_COUNT] = {0, 1, 2, 3};

int  g_last_selection_key = 0;
bool g_cached_symbol_selected = false;
bool g_cached_exit_due = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_10886_SYMBOL_COUNT; ++i)
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

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_CopyRates(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const int start_shift,
                        const int count,
                        MqlRates &rates[])
  {
   if(count <= 0)
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, tf, start_shift, count, rates); // perf-allowed: basket statistics are evaluated only from the framework closed-bar hook.
   return (copied >= count);
  }

bool Strategy_IsFirstTradableD1BarOfMonth(datetime &current_bar_time)
  {
   current_bar_time = 0;
   if(_Period != PERIOD_D1)
      return false;

   MqlRates bars[];
   if(!Strategy_CopyRates(_Symbol, PERIOD_D1, 0, 2, bars))
      return false;

   current_bar_time = bars[0].time;
   const int current_key = Strategy_MonthKey(bars[0].time);
   const int previous_key = Strategy_MonthKey(bars[1].time);
   return (current_key > 0 && previous_key > 0 && current_key != previous_key);
  }

double Strategy_PercentileSorted(double &values[], const int count, const double percentile)
  {
   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   const double p = MathMax(0.0, MathMin(100.0, percentile)) / 100.0;
   const double pos = p * (double)(count - 1);
   const int lower = (int)MathFloor(pos);
   const int upper = (int)MathCeil(pos);
   if(lower == upper)
      return values[lower];

   const double weight = pos - (double)lower;
   return values[lower] * (1.0 - weight) + values[upper] * weight;
  }

bool Strategy_DailyMetrics(const string symbol,
                           double &out_ret6m,
                           double &out_rank12m,
                           double &out_vol63)
  {
   out_ret6m = 0.0;
   out_rank12m = 0.0;
   out_vol63 = 0.0;

   const int need = MathMax(strategy_percentile_bars,
                            MathMax(strategy_momentum_lookback_d1 + 1,
                                    strategy_realized_vol_days + 1));
   if(need < 2)
      return false;

   SymbolSelect(symbol, true);
   MqlRates rates[];
   if(!Strategy_CopyRates(symbol, PERIOD_D1, 1, need, rates))
      return false;

   const double latest = rates[0].close;
   const double lookback = rates[strategy_momentum_lookback_d1].close;
   if(latest <= 0.0 || lookback <= 0.0)
      return false;
   out_ret6m = (latest / lookback) - 1.0;

   int below = 0;
   int rank_count = 0;
   for(int i = 0; i < strategy_percentile_bars; ++i)
     {
      if(rates[i].close <= 0.0)
         continue;
      if(rates[i].close < latest)
         ++below;
      ++rank_count;
     }
   if(rank_count <= 0)
      return false;
   out_rank12m = 100.0 * (double)below / (double)rank_count;

   double sum = 0.0;
   double sum_sq = 0.0;
   int vol_count = 0;
   for(int i = 0; i < strategy_realized_vol_days; ++i)
     {
      if(rates[i].close <= 0.0 || rates[i + 1].close <= 0.0)
         continue;
      const double r = MathLog(rates[i].close / rates[i + 1].close);
      sum += r;
      sum_sq += r * r;
      ++vol_count;
     }
   if(vol_count < MathMax(10, strategy_realized_vol_days / 2))
      return false;

   const double mean = sum / (double)vol_count;
   const double var = MathMax(0.0, (sum_sq / (double)vol_count) - mean * mean);
   out_vol63 = MathSqrt(var);
   return (out_vol63 >= 0.0);
  }

bool Strategy_MonthlyCloseRising(const string symbol)
  {
   MqlRates months[];
   if(!Strategy_CopyRates(symbol, PERIOD_MN1, 1, 2, months))
      return false;
   if(months[0].close <= 0.0 || months[1].close <= 0.0)
      return false;
   return (months[0].close > months[1].close);
  }

bool Strategy_SelectsSymbol(const string symbol)
  {
   double ret[QM5_10886_SYMBOL_COUNT];
   double rank[QM5_10886_SYMBOL_COUNT];
   double vol[QM5_10886_SYMBOL_COUNT];
   bool valid[QM5_10886_SYMBOL_COUNT];
   bool candidate[QM5_10886_SYMBOL_COUNT];
   int valid_count = 0;

   for(int i = 0; i < QM5_10886_SYMBOL_COUNT; ++i)
     {
      ret[i] = 0.0;
      rank[i] = 0.0;
      vol[i] = 0.0;
      valid[i] = Strategy_DailyMetrics(g_symbols[i], ret[i], rank[i], vol[i]);
      candidate[i] = false;
      if(valid[i])
         ++valid_count;
     }

   if(valid_count < 2)
      return false;

   double returns_for_median[QM5_10886_SYMBOL_COUNT];
   double vols_for_cutoff[QM5_10886_SYMBOL_COUNT];
   int metric_count = 0;
   for(int i = 0; i < QM5_10886_SYMBOL_COUNT; ++i)
     {
      if(!valid[i])
         continue;
      returns_for_median[metric_count] = ret[i];
      vols_for_cutoff[metric_count] = vol[i];
      ++metric_count;
     }

   const double universe_median_return = Strategy_PercentileSorted(returns_for_median, metric_count, 50.0);
   const double high_vol_cutoff = Strategy_PercentileSorted(vols_for_cutoff, metric_count, strategy_high_vol_percentile);

   for(int i = 0; i < QM5_10886_SYMBOL_COUNT; ++i)
     {
      if(!valid[i])
         continue;

      const bool momentum_ok = (ret[i] > 0.0 && ret[i] > universe_median_return);
      const bool meanrev_ok = (rank[i] < strategy_meanrev_percentile && Strategy_MonthlyCloseRising(g_symbols[i]));
      const bool high_vol = (vol[i] > high_vol_cutoff);
      candidate[i] = ((momentum_ok || meanrev_ok) && !high_vol);
     }

   int selected_order[QM5_10886_SYMBOL_COUNT];
   int selected_count = 0;
   for(int i = 0; i < QM5_10886_SYMBOL_COUNT; ++i)
     {
      if(!candidate[i])
         continue;
      selected_order[selected_count] = i;
      ++selected_count;
     }

   if(selected_count <= 0)
      return false;

   for(int i = 0; i < selected_count - 1; ++i)
      for(int j = i + 1; j < selected_count; ++j)
         if(ret[selected_order[j]] > ret[selected_order[i]])
           {
            const int tmp = selected_order[i];
            selected_order[i] = selected_order[j];
            selected_order[j] = tmp;
           }

   const int max_selected = MathMax(1, MathMin(strategy_max_selected, QM5_10886_SYMBOL_COUNT));
   const int take = MathMin(max_selected, selected_count);
   for(int rank_idx = 0; rank_idx < take; ++rank_idx)
      if(g_symbols[selected_order[rank_idx]] == symbol)
         return true;

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_momentum_lookback_d1 <= 0 || strategy_percentile_bars < 252)
      return true;
   if(strategy_realized_vol_days <= 0 || strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_meanrev_percentile <= 0.0 || strategy_meanrev_percentile >= 100.0)
      return true;
   if(strategy_high_vol_percentile <= 0.0 || strategy_high_vol_percentile >= 100.0)
      return true;
   if(strategy_spread_max_points > 0.0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > (long)strategy_spread_max_points)
         return true;
     }
   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10886_MONTHLY_COMM_ROT_LONG";
   req.symbol_slot = Strategy_CurrentSymbolSlot();
   req.expiration_seconds = 0;

   datetime current_bar_time = 0;
   if(!Strategy_IsFirstTradableD1BarOfMonth(current_bar_time))
      return false;

   const int rebalance_key = Strategy_MonthKey(current_bar_time);
   if(rebalance_key <= 0 || rebalance_key == g_last_selection_key)
      return false;

   g_cached_symbol_selected = Strategy_SelectsSymbol(_Symbol);
   g_cached_exit_due = (!g_cached_symbol_selected && Strategy_HasOpenPosition());
   g_last_selection_key = rebalance_key;

   if(!g_cached_symbol_selected || Strategy_HasOpenPosition())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr <= 0.0)
      return false;

   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   req.tp = 0.0;
   if(req.sl <= 0.0 || req.sl >= entry)
      return false;

   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, pyramiding, or averaging.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!g_cached_exit_due)
      return false;
   if(!Strategy_HasOpenPosition())
     {
      g_cached_exit_due = false;
      return false;
     }

   g_cached_exit_due = false;
   return true;
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, MathMax(strategy_percentile_bars + 10, strategy_momentum_lookback_d1 + 10));
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10886\",\"ea\":\"risk-comm-rot\"}");
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
