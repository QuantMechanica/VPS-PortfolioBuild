#property strict
#property version   "5.0"
#property description "QM5_9450 Brooks failed spike-and-channel H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9450;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE60_POST60;
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
input ENUM_TIMEFRAMES strategy_timeframe          = PERIOD_H4;
input int    strategy_atr_period                  = 14;
input double strategy_spike_atr_mult              = 2.0;
input double strategy_spike_body_ratio            = 0.70;
input int    strategy_channel_min_bars            = 4;
input int    strategy_channel_max_bars            = 10;
input double strategy_channel_range_ratio         = 0.70;
input int    strategy_breakout_window_bars        = 10;
input double strategy_breakout_atr_mult           = 0.30;
input int    strategy_trigger_window_bars         = 6;
input double strategy_trigger_atr_mult            = 0.40;
input double strategy_take_profit_atr_mult        = 0.80;
input double strategy_stop_atr_mult               = 0.30;
input int    strategy_time_stop_bars              = 20;
input double strategy_max_spread_atr_mult         = 0.20;
input int    strategy_scan_bars                   = 80;

datetime g_last_signal_bar_time = 0;

double StrategyTrueRange(const MqlRates &rates[], const int shift, const int copied)
  {
   if(shift < 0 || shift + 1 >= copied)
      return 0.0;

   const double high_close = MathAbs(rates[shift].high - rates[shift + 1].close);
   const double low_close = MathAbs(rates[shift].low - rates[shift + 1].close);
   return MathMax(rates[shift].high - rates[shift].low, MathMax(high_close, low_close));
  }

double StrategyATRBefore(const MqlRates &rates[],
                         const int copied,
                         const int shift,
                         const int period)
  {
   if(period <= 0 || shift + period + 1 >= copied)
      return 0.0;

   double sum = 0.0;
   for(int i = shift + 1; i <= shift + period; ++i)
     {
      const double tr = StrategyTrueRange(rates, i, copied);
      if(tr <= 0.0)
         return 0.0;
      sum += tr;
     }
   return sum / (double)period;
  }

bool StrategySpikeStraddlesGap(const MqlRates &rates[],
                               const int copied,
                               const int spike_shift)
  {
   const int bar_seconds = PeriodSeconds(strategy_timeframe);
   if(bar_seconds <= 0)
      return false;

   const int max_gap = bar_seconds * 2;
   if(spike_shift + 1 < copied && (rates[spike_shift].time - rates[spike_shift + 1].time) > max_gap)
      return true;
   if(spike_shift - 1 >= 1 && (rates[spike_shift - 1].time - rates[spike_shift].time) > max_gap)
      return true;
   return false;
  }

bool StrategyIsSpike(const MqlRates &rates[],
                     const int copied,
                     const int spike_shift,
                     int &direction,
                     double &spike_range,
                     double &channel_start)
  {
   direction = 0;
   spike_range = rates[spike_shift].high - rates[spike_shift].low;
   channel_start = rates[spike_shift].open;
   if(spike_range <= 0.0 || channel_start <= 0.0)
      return false;

   const double body = MathAbs(rates[spike_shift].close - rates[spike_shift].open);
   if(body < strategy_spike_body_ratio * spike_range)
      return false;

   const double atr_before = StrategyATRBefore(rates, copied, spike_shift, strategy_atr_period);
   if(atr_before <= 0.0 || spike_range < strategy_spike_atr_mult * atr_before)
      return false;

   if(StrategySpikeStraddlesGap(rates, copied, spike_shift))
      return false;

   if(rates[spike_shift].close > rates[spike_shift].open)
      direction = 1;
   else if(rates[spike_shift].close < rates[spike_shift].open)
      direction = -1;

   return (direction != 0);
  }

bool StrategyChannelWindow(const MqlRates &rates[],
                           const int spike_shift,
                           const int anchor_shift,
                           const int direction,
                           const double channel_start,
                           const double max_close_range,
                           double &channel_extreme)
  {
   double max_close = -DBL_MAX;
   double min_close = DBL_MAX;
   channel_extreme = (direction > 0) ? rates[spike_shift].high : rates[spike_shift].low;

   for(int i = spike_shift - 1; i >= anchor_shift; --i)
     {
      if(rates[i].high <= 0.0 || rates[i].low <= 0.0 || rates[i].close <= 0.0)
         return false;

      if(direction > 0)
        {
         if(rates[i].low < channel_start)
            return false;
         channel_extreme = MathMax(channel_extreme, rates[i].high);
        }
      else
        {
         if(rates[i].high > channel_start)
            return false;
         channel_extreme = MathMin(channel_extreme, rates[i].low);
        }

      max_close = MathMax(max_close, rates[i].close);
      min_close = MathMin(min_close, rates[i].close);
     }

   return ((max_close - min_close) <= max_close_range);
  }

bool StrategyChannelTerminates(const MqlRates &rates[],
                               const int spike_shift,
                               const int anchor_shift,
                               const int direction,
                               const double channel_start,
                               const double max_close_range)
  {
   const int next_shift = anchor_shift - 1;
   if(next_shift < 1)
      return false;

   if(direction > 0 && rates[next_shift].low < channel_start)
      return true;
   if(direction < 0 && rates[next_shift].high > channel_start)
      return true;

   double max_close = -DBL_MAX;
   double min_close = DBL_MAX;
   for(int i = spike_shift - 1; i >= next_shift; --i)
     {
      max_close = MathMax(max_close, rates[i].close);
      min_close = MathMin(min_close, rates[i].close);
     }
   return ((max_close - min_close) > max_close_range);
  }

double StrategyBreakoutExtremeToShift(const MqlRates &rates[],
                                      const int anchor_shift,
                                      const int shift,
                                      const int direction)
  {
   double extreme = (direction > 0) ? DBL_MAX : -DBL_MAX;
   for(int i = anchor_shift - 1; i >= shift; --i)
     {
      if(direction > 0)
         extreme = MathMin(extreme, rates[i].low);
      else
         extreme = MathMax(extreme, rates[i].high);
     }
   return extreme;
  }

bool StrategyFindBreakout(const MqlRates &rates[],
                          const int copied,
                          const int anchor_shift,
                          const int direction,
                          const double channel_start,
                          int &breakout_shift,
                          double &breakout_extreme)
  {
   breakout_shift = -1;
   breakout_extreme = 0.0;
   const int latest_shift = anchor_shift - 1;
   const int earliest_shift = MathMax(2, anchor_shift - strategy_breakout_window_bars);
   if(latest_shift < earliest_shift)
      return false;

   for(int b = latest_shift; b >= earliest_shift; --b)
     {
      if((b - 1) > strategy_trigger_window_bars)
         continue;

      const double atr = StrategyATRBefore(rates, copied, b, strategy_atr_period);
      if(atr <= 0.0)
         continue;

      const bool broke = (direction > 0)
                         ? (rates[b].close < channel_start - strategy_breakout_atr_mult * atr)
                         : (rates[b].close > channel_start + strategy_breakout_atr_mult * atr);
      if(!broke)
         continue;

      const double first_extreme = StrategyBreakoutExtremeToShift(rates, anchor_shift, b, direction);
      bool invalidated = false;
      for(int j = b - 1; j >= 2; --j)
        {
         if(direction > 0 && rates[j].low < first_extreme)
            invalidated = true;
         if(direction < 0 && rates[j].high > first_extreme)
            invalidated = true;
        }
      if(invalidated)
         continue;

      breakout_shift = b;
      breakout_extreme = StrategyBreakoutExtremeToShift(rates, anchor_shift, 1, direction);
      return true;
     }

   return false;
  }

bool StrategyTriggerConfirmed(const MqlRates &rates[],
                              const int copied,
                              const int direction,
                              const double channel_start)
  {
   const double atr = StrategyATRBefore(rates, copied, 1, strategy_atr_period);
   if(atr <= 0.0)
      return false;

   if(direction > 0)
      return (rates[1].close > channel_start &&
              rates[1].close > rates[1].open &&
              rates[1].high >= channel_start + strategy_trigger_atr_mult * atr);

   return (rates[1].close < channel_start &&
           rates[1].close < rates[1].open &&
           rates[1].low <= channel_start - strategy_trigger_atr_mult * atr);
  }

bool StrategyFindPattern(const MqlRates &rates[],
                         const int copied,
                         int &direction,
                         double &channel_extreme,
                         double &breakout_extreme,
                         double &entry_atr)
  {
   direction = 0;
   channel_extreme = 0.0;
   breakout_extreme = 0.0;
   entry_atr = StrategyATRBefore(rates, copied, 1, strategy_atr_period);
   if(entry_atr <= 0.0)
      return false;

   const int min_spike_shift = strategy_channel_min_bars + 3;
   const int max_spike_shift = MathMin(strategy_scan_bars - 1, copied - strategy_atr_period - 2);
   for(int spike_shift = min_spike_shift; spike_shift <= max_spike_shift; ++spike_shift)
     {
      int spike_dir = 0;
      double spike_range = 0.0;
      double channel_start = 0.0;
      if(!StrategyIsSpike(rates, copied, spike_shift, spike_dir, spike_range, channel_start))
         continue;

      const double max_close_range = strategy_channel_range_ratio * spike_range;
      for(int k = strategy_channel_min_bars; k <= strategy_channel_max_bars; ++k)
        {
         const int anchor_shift = spike_shift - k;
         if(anchor_shift < 3)
            continue;

         double candidate_extreme = 0.0;
         if(!StrategyChannelWindow(rates, spike_shift, anchor_shift, spike_dir,
                                   channel_start, max_close_range, candidate_extreme))
            continue;
         if(!StrategyChannelTerminates(rates, spike_shift, anchor_shift, spike_dir,
                                       channel_start, max_close_range))
            continue;

         int breakout_shift = -1;
         double candidate_breakout_extreme = 0.0;
         if(!StrategyFindBreakout(rates, copied, anchor_shift, spike_dir,
                                  channel_start, breakout_shift, candidate_breakout_extreme))
            continue;
         if(!StrategyTriggerConfirmed(rates, copied, spike_dir, channel_start))
            continue;

         direction = spike_dir;
         channel_extreme = candidate_extreme;
         breakout_extreme = candidate_breakout_extreme;
         return true;
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != strategy_timeframe)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return true;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if(ask > bid && strategy_max_spread_atr_mult > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
      if(atr <= 0.0)
         return true;
      if((ask - bid) > strategy_max_spread_atr_mult * atr)
         return true;
     }

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

   if(_Period != strategy_timeframe)
      return false;

   int bars_needed = strategy_scan_bars;
   const int minimum_needed = strategy_atr_period + strategy_channel_max_bars + strategy_breakout_window_bars + strategy_trigger_window_bars + 20;
   if(minimum_needed > bars_needed)
      bars_needed = minimum_needed;
   MqlRates rates[]; // perf-allowed: bounded Brooks spike-and-channel OHLC scan inside framework QM_IsNewBar-gated EntrySignal.
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, strategy_timeframe, 0, bars_needed, rates); // perf-allowed: structural price-action scan, once per closed H4 bar.
   if(copied < bars_needed)
      return false;

   if(rates[1].time <= 0 || rates[1].time == g_last_signal_bar_time)
      return false;

   int direction = 0;
   double channel_extreme = 0.0;
   double breakout_extreme = 0.0;
   double entry_atr = 0.0;
   if(!StrategyFindPattern(rates, copied, direction, channel_extreme, breakout_extreme, entry_atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const bool is_long = (direction > 0);
   const double entry_price = is_long ? ask : bid;
   if(entry_price <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;
   if(is_long)
     {
      sl = MathMin(entry_price, breakout_extreme) - strategy_stop_atr_mult * entry_atr;
      tp = channel_extreme + strategy_take_profit_atr_mult * entry_atr;
      if(sl <= 0.0 || tp <= entry_price || sl >= entry_price)
         return false;
      req.type = QM_BUY;
      req.reason = "brooks_up_spike_channel_failed_down_breakout";
     }
   else
     {
      sl = MathMax(entry_price, breakout_extreme) + strategy_stop_atr_mult * entry_atr;
      tp = channel_extreme - strategy_take_profit_atr_mult * entry_atr;
      if(tp <= 0.0 || tp >= entry_price || sl <= entry_price)
         return false;
      req.type = QM_SELL;
      req.reason = "brooks_down_spike_channel_failed_up_breakout";
     }

   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   g_last_signal_bar_time = rates[1].time;
   return (req.sl > 0.0 && req.tp > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const int bar_seconds = PeriodSeconds(strategy_timeframe);
   if(magic <= 0 || bar_seconds <= 0 || strategy_time_stop_bars <= 0)
      return;

   const datetime now = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && now >= open_time + (datetime)(strategy_time_stop_bars * bar_seconds))
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

bool Strategy_ExitSignal()
  {
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
                        60,
                        60,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_9450\",\"strategy\":\"brooks_failed_spike_channel\"}");
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
