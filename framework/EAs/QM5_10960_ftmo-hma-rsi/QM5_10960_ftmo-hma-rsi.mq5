#property strict
#property version   "5.0"
#property description "QM5_10960 FTMO HMA RSI volatility stop"
// rework v2 2026-06-16 — decoupled RSI cross-back from shift-1 to scan the full lookback window so RSI recovery and HMA cross need not coincide on one bar (was ~0 trades / Q02 MIN_TRADES)

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA
// Strategy Card: QM5_10960_ftmo-hma-rsi, G0 APPROVED 2026-05-22.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10960;
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
input int    strategy_rsi_period              = 14;
input double strategy_rsi_oversold            = 30.0;
input double strategy_rsi_overbought          = 70.0;
input int    strategy_rsi_lookback_bars       = 5;
input int    strategy_hma_fast_period         = 20;
input int    strategy_hma_slow_period         = 50;
input int    strategy_hma_cross_lookback_bars = 3;
input int    strategy_adr_days                = 60;
input double strategy_stop_adr_mult           = 1.2;
input double strategy_take_profit_r           = 2.0;
input int    strategy_time_exit_h4_bars       = 30;
input double strategy_max_spread_stop_pct     = 8.0;
input int    strategy_vol_percentile_years    = 3;
input double strategy_min_vol_percentile      = 20.0;

bool   g_vol_filter_ready = false;
bool   g_vol_filter_blocks = true;
double g_current_adr = 0.0;
double g_vol_threshold_adr = 0.0;

bool Strategy_RefreshVolatilityFilter()
  {
   g_vol_filter_ready = false;
   g_vol_filter_blocks = true;
   g_current_adr = 0.0;
   g_vol_threshold_adr = 0.0;

   if(strategy_adr_days <= 0 || strategy_vol_percentile_years <= 0)
      return false;

   const int windows = strategy_vol_percentile_years * 252;
   const int required_bars = strategy_adr_days + windows - 1;
   if(required_bars <= strategy_adr_days)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required_bars, rates); // perf-allowed: D1 volatility percentile cache, refreshed only on D1 new-bar cadence.
   if(copied < strategy_adr_days)
      return false;

   const int sample_count = MathMin(windows, copied - strategy_adr_days + 1);
   if(sample_count <= 0)
      return false;

   double adr_values[];
   ArrayResize(adr_values, sample_count);

   for(int start = 0; start < sample_count; ++start)
     {
      double range_sum = 0.0;
      int valid_days = 0;
      for(int offset = 0; offset < strategy_adr_days; ++offset)
        {
         const int idx = start + offset;
         if(idx >= copied)
            break;
         const double high = rates[idx].high;
         const double low = rates[idx].low;
         if(high <= low || high <= 0.0 || low <= 0.0)
            continue;
         range_sum += (high - low);
         valid_days++;
        }
      if(valid_days <= 0)
         adr_values[start] = 0.0;
      else
         adr_values[start] = range_sum / (double)valid_days;
     }

   g_current_adr = adr_values[0];
   ArraySort(adr_values);

   int positive_count = 0;
   for(int i = 0; i < sample_count; ++i)
     {
      if(adr_values[i] > 0.0)
         positive_count++;
     }
   if(positive_count <= 0 || g_current_adr <= 0.0)
      return false;

   double positives[];
   ArrayResize(positives, positive_count);
   int out = 0;
   for(int i = 0; i < sample_count; ++i)
     {
      if(adr_values[i] > 0.0)
        {
         positives[out] = adr_values[i];
         out++;
        }
     }

   const double pct = MathMax(0.0, MathMin(100.0, strategy_min_vol_percentile));
   int percentile_index = (int)MathFloor((pct / 100.0) * (double)(positive_count - 1));
   percentile_index = MathMax(0, MathMin(positive_count - 1, percentile_index));
   g_vol_threshold_adr = positives[percentile_index];
   g_vol_filter_blocks = (g_current_adr < g_vol_threshold_adr);
   g_vol_filter_ready = true;
   return true;
  }

bool Strategy_RsiWasBelow(const int lookback, const double threshold)
  {
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift);
      if(rsi > 0.0 && rsi < threshold)
         return true;
     }
   return false;
  }

bool Strategy_RsiWasAbove(const int lookback, const double threshold)
  {
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double rsi = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift);
      if(rsi > threshold)
         return true;
     }
   return false;
  }

// Card: "RSI has crossed back above 30" within the recovery window. The cross
// need not land on the single most-recent bar — scan shifts 1..lookback so the
// RSI recovery and the HMA confirmation cross can fall on different closed bars.
bool Strategy_RsiCrossedAbove(const int lookback, const double threshold)
  {
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double now  = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift);
      const double prev = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift + 1);
      if(now > threshold && prev <= threshold && prev > 0.0)
         return true;
     }
   return false;
  }

bool Strategy_RsiCrossedBelow(const int lookback, const double threshold)
  {
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double now  = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift);
      const double prev = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, shift + 1);
      if(now < threshold && now > 0.0 && prev >= threshold)
         return true;
     }
   return false;
  }

bool Strategy_HmaCrossUpAtShift(const int shift)
  {
   const double fast_now = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_fast_period, shift);
   const double slow_now = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_slow_period, shift);
   const double fast_prev = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_fast_period, shift + 1);
   const double slow_prev = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_slow_period, shift + 1);
   return (fast_now > slow_now && fast_prev <= slow_prev);
  }

bool Strategy_HmaCrossDownAtShift(const int shift)
  {
   const double fast_now = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_fast_period, shift);
   const double slow_now = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_slow_period, shift);
   const double fast_prev = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_fast_period, shift + 1);
   const double slow_prev = QM_HMA(_Symbol, PERIOD_H4, strategy_hma_slow_period, shift + 1);
   return (fast_now < slow_now && fast_prev >= slow_prev);
  }

bool Strategy_HmaCrossedUpRecently()
  {
   for(int shift = 1; shift <= strategy_hma_cross_lookback_bars; ++shift)
     {
      if(Strategy_HmaCrossUpAtShift(shift))
         return true;
     }
   return false;
  }

bool Strategy_HmaCrossedDownRecently()
  {
   for(int shift = 1; shift <= strategy_hma_cross_lookback_bars; ++shift)
     {
      if(Strategy_HmaCrossDownAtShift(shift))
         return true;
     }
   return false;
  }

bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype, datetime &open_time)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;

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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(!g_vol_filter_ready || QM_IsNewBar(_Symbol, PERIOD_D1))
      Strategy_RefreshVolatilityFilter();

   if(!g_vol_filter_ready || g_vol_filter_blocks)
      return true;

   const double planned_stop_distance = g_current_adr * strategy_stop_adr_mult;
   if(planned_stop_distance <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double spread_pct = ((ask - bid) / planned_stop_distance) * 100.0;
   if(spread_pct > strategy_max_spread_stop_pct)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_rsi_period <= 0 ||
      strategy_rsi_lookback_bars <= 0 ||
      strategy_hma_fast_period <= 0 ||
      strategy_hma_slow_period <= 0 ||
      strategy_hma_cross_lookback_bars <= 0 ||
      strategy_adr_days <= 0 ||
      strategy_stop_adr_mult <= 0.0 ||
      strategy_take_profit_r <= 0.0)
      return false;

   const bool long_signal = Strategy_RsiWasBelow(strategy_rsi_lookback_bars, strategy_rsi_oversold) &&
                            Strategy_RsiCrossedAbove(strategy_rsi_lookback_bars, strategy_rsi_oversold) &&
                            Strategy_HmaCrossedUpRecently();
   const bool short_signal = Strategy_RsiWasAbove(strategy_rsi_lookback_bars, strategy_rsi_overbought) &&
                             Strategy_RsiCrossedBelow(strategy_rsi_lookback_bars, strategy_rsi_overbought) &&
                             Strategy_HmaCrossedDownRecently();

   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopVolatility(_Symbol, side, entry, strategy_adr_days, strategy_stop_adr_mult);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_r);
   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = long_signal ? "FTMO_HMA_RSI_LONG" : "FTMO_HMA_RSI_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

// Return TRUE to close the open position now.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   if(!Strategy_GetOurPosition(ptype, open_time))
      return false;

   if(strategy_time_exit_h4_bars > 0 && open_time > 0)
     {
      const int hold_seconds = PeriodSeconds(PERIOD_H4) * strategy_time_exit_h4_bars;
      if(hold_seconds > 0 && (TimeCurrent() - open_time) >= hold_seconds)
         return true;
     }

   if(ptype == POSITION_TYPE_BUY && Strategy_HmaCrossDownAtShift(1))
      return true;
   if(ptype == POSITION_TYPE_SELL && Strategy_HmaCrossUpAtShift(1))
      return true;

   return false;
  }

// Optional news-filter override.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10960_ftmo-hma-rsi\"}");
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
