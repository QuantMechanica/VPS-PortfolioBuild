#property strict
#property version   "5.0"
#property description "QM5_1127 Menkhoff Carry FX Vol Filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1127;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_momentum_d1_bars    = 63;
input int    strategy_realized_vol_bars   = 21;
input int    strategy_vol_baseline_bars   = 252;
input double strategy_vol_threshold_mult  = 1.5;
input int    strategy_bucket_size         = 2;
input int    strategy_min_valid_symbols   = 6;
input int    strategy_atr_period_d1       = 14;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_spread_days         = 20;
input double strategy_spread_mult         = 3.0;

#define QM5_1127_SYMBOL_COUNT 7

string g_symbols[QM5_1127_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "NZDUSD.DWX", "USDCHF.DWX", "USDCAD.DWX"
  };

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day  = 0;
datetime g_last_vol_bar             = 0;
bool     g_last_vol_allows_risk     = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1127_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDJPY.DWX" || symbol == "USDCHF.DWX" || symbol == "USDCAD.DWX");
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsMonthEndClosedBar(const datetime closed_day)
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
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_days <= 0 || strategy_spread_days > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

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

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

bool Strategy_SymbolMomentumScore(const string symbol, double &out_score)
  {
   out_score = 0.0;
   if(strategy_momentum_d1_bars <= 0)
      return false;

   SymbolSelect(symbol, true);
   if(Bars(symbol, PERIOD_D1) < strategy_momentum_d1_bars + strategy_realized_vol_bars + 5)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, strategy_momentum_d1_bars + 1);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   if(Strategy_IsUsdBaseSymbol(symbol))
      out_score = (lookback_close / recent_close) - 1.0;
   else
      out_score = (recent_close / lookback_close) - 1.0;
   return true;
  }

bool Strategy_RealizedVol(const string symbol, const int end_shift, double &out_vol)
  {
   out_vol = 0.0;
   if(strategy_realized_vol_bars < 2 || end_shift < 1)
      return false;

   SymbolSelect(symbol, true);
   if(Bars(symbol, PERIOD_D1) < end_shift + strategy_realized_vol_bars + 2)
      return false;

   double returns[128];
   if(strategy_realized_vol_bars > 128)
      return false;

   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < strategy_realized_vol_bars; ++i)
     {
      const int shift = end_shift + i;
      const double close_now = iClose(symbol, PERIOD_D1, shift);
      const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;

      const double r = MathLog(close_now / close_prev);
      returns[count] = r;
      sum += r;
      ++count;
     }

   if(count < 2)
      return false;

   const double mean = sum / (double)count;
   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double diff = returns[i] - mean;
      var_sum += diff * diff;
     }

   out_vol = MathSqrt(var_sum / (double)(count - 1)) * MathSqrt(252.0);
   return (out_vol > 0.0);
  }

bool Strategy_GlobalVolAtShift(const int end_shift, double &out_vol, int &out_valid)
  {
   out_vol = 0.0;
   out_valid = 0;

   double sum = 0.0;
   for(int i = 0; i < QM5_1127_SYMBOL_COUNT; ++i)
     {
      double vol = 0.0;
      if(!Strategy_RealizedVol(g_symbols[i], end_shift, vol))
         continue;
      sum += vol;
      ++out_valid;
     }

   if(out_valid < strategy_min_valid_symbols)
      return false;

   out_vol = sum / (double)out_valid;
   return (out_vol > 0.0);
  }

bool Strategy_GlobalVolAllowsRisk()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar > 0 && current_bar == g_last_vol_bar)
      return g_last_vol_allows_risk;

   g_last_vol_bar = current_bar;
   g_last_vol_allows_risk = false;

   if(strategy_vol_baseline_bars <= 0 || strategy_vol_threshold_mult <= 0.0)
      return false;

   double current_vol = 0.0;
   int current_valid = 0;
   if(!Strategy_GlobalVolAtShift(1, current_vol, current_valid))
      return false;

   double baseline_sum = 0.0;
   int baseline_count = 0;
   for(int shift = 1; shift <= strategy_vol_baseline_bars; ++shift)
     {
      double vol = 0.0;
      int valid = 0;
      if(!Strategy_GlobalVolAtShift(shift, vol, valid))
         continue;
      baseline_sum += vol;
      ++baseline_count;
     }

   if(baseline_count < strategy_vol_baseline_bars / 2)
      return false;

   const double baseline = baseline_sum / (double)baseline_count;
   if(baseline <= 0.0)
      return false;

   g_last_vol_allows_risk = (current_vol <= strategy_vol_threshold_mult * baseline);
   return g_last_vol_allows_risk;
  }

void Strategy_SortScoresAscending(double &scores[], int &indexes[], const int count)
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

int Strategy_DirectionForSymbol()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double scores[QM5_1127_SYMBOL_COUNT];
   int indexes[QM5_1127_SYMBOL_COUNT];
   int count = 0;
   for(int i = 0; i < QM5_1127_SYMBOL_COUNT; ++i)
     {
      double score = 0.0;
      if(!Strategy_SymbolMomentumScore(g_symbols[i], score))
         continue;
      scores[count] = score;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_min_valid_symbols)
      return 0;

   int bucket = MathMin(MathMax(strategy_bucket_size, 1), count / 2);
   if(bucket <= 0)
      return 0;

   Strategy_SortScoresAscending(scores, indexes, count);

   int foreign_ccy_direction = 0;
   for(int i = 0; i < bucket; ++i)
      if(indexes[i] == current_index)
         foreign_ccy_direction = -1;
   for(int i = count - bucket; i < count; ++i)
      if(indexes[i] == current_index)
         foreign_ccy_direction = 1;

   if(foreign_ccy_direction == 0)
      return 0;

   return Strategy_IsUsdBaseSymbol(g_symbols[current_index]) ? -foreign_ccy_direction : foreign_ccy_direction;
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int slot = Strategy_CurrentSymbolIndex();
   if(slot < 0)
      return false;

   const int magic = QM_Magic(qm_ea_id, slot);
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
   if(strategy_bucket_size <= 0 || strategy_min_valid_symbols < 2)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
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

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthEndClosedBar(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;
   if(!Strategy_GlobalVolAllowsRisk())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_DirectionForSymbol();
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (direction > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol,
                                         (direction > 0) ? QM_BUY : QM_SELL,
                                         entry,
                                         atr,
                                         strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(direction > 0 && sl >= entry)
      return false;
   if(direction < 0 && sl <= entry)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.symbol_slot = Strategy_CurrentSymbolIndex();
   req.reason = (direction > 0) ? "MENKHOFF_CARRY_TOP2_LONG" : "MENKHOFF_CARRY_BOTTOM2_SHORT";
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or pyramiding beyond ATR hard stop.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsMonthEndClosedBar(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;

   if(!Strategy_GlobalVolAllowsRisk())
     {
      g_last_exit_rebalance_day = rebalance_day;
      return true;
     }

   const int desired_direction = Strategy_DirectionForSymbol();
   if(desired_direction == 0)
     {
      g_last_exit_rebalance_day = rebalance_day;
      return true;
     }

   if(!PositionSelectByTicket(ticket))
      return false;

   const long pos_type = PositionGetInteger(POSITION_TYPE);
   const int current_direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
   if(desired_direction != current_direction)
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
   QM_BasketWarmupHistory(g_symbols,
                          PERIOD_D1,
                          strategy_vol_baseline_bars + strategy_realized_vol_bars + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1127_menkhoff-carry-fxvol-filter\"}");
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
      const int slot = Strategy_CurrentSymbolIndex();
      const int magic = QM_Magic(qm_ea_id, slot);
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
