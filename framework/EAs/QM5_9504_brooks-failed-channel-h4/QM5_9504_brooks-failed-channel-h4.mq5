#property strict
#property version   "5.0"
#property description "QM5_9504 Brooks Failed Pure-Channel Reversal H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 9504;
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
input ENUM_TIMEFRAMES strategy_tf             = PERIOD_H4;
input int    strategy_atr_period              = 14;
input int    strategy_channel_min_bars        = 6;
input int    strategy_channel_max_bars        = 14;
input int    strategy_stage2_max_bars         = 12;
input int    strategy_stage3_max_bars         = 8;
input double strategy_no_spike_atr_mult       = 1.5;
input int    strategy_drift_edge_min          = 4;
input double strategy_progress_atr_min        = 1.0;
input double strategy_range_atr_max           = 2.5;
input double strategy_break_atr               = 0.3;
input double strategy_reversal_range_atr      = 0.8;
input double strategy_reversal_tail_frac      = 0.3;
input double strategy_reversal_extreme_atr    = 0.5;
input double strategy_stop_buffer_atr         = 0.3;
input double strategy_target_projection_frac  = 0.5;
input int    strategy_time_stop_bars          = 24;
input double strategy_spread_atr_max          = 0.20;
input int    strategy_cooldown_bars           = 24;

struct FC_Pattern
  {
   bool     valid;
   int      direction;
   int      channel_bars;
   int      anchor_shift;
   int      break_shift;
   double   origin;
   double   extreme;
   double   break_extreme;
   double   stop_ref;
   double   atr;
   datetime key_time;
  };

datetime g_cooldown_until = 0;
datetime g_last_pattern_key = 0;
int      g_last_pattern_dir = 0;
bool     g_had_position = false;

void FC_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool FC_ParamsOk()
  {
   if(strategy_atr_period <= 0 ||
      strategy_channel_min_bars < 2 ||
      strategy_channel_max_bars < strategy_channel_min_bars ||
      strategy_stage2_max_bars <= 0 ||
      strategy_stage3_max_bars <= 0 ||
      strategy_no_spike_atr_mult <= 0.0 ||
      strategy_drift_edge_min < 1 ||
      strategy_progress_atr_min <= 0.0 ||
      strategy_range_atr_max <= 0.0 ||
      strategy_break_atr <= 0.0 ||
      strategy_reversal_range_atr <= 0.0 ||
      strategy_reversal_tail_frac < 0.0 ||
      strategy_reversal_tail_frac > 1.0 ||
      strategy_reversal_extreme_atr < 0.0 ||
      strategy_stop_buffer_atr < 0.0 ||
      strategy_target_projection_frac <= 0.0 ||
      strategy_time_stop_bars <= 0 ||
      strategy_spread_atr_max < 0.0 ||
      strategy_cooldown_bars < 0)
      return false;

   return PeriodSeconds(strategy_tf) > 0;
  }

bool FC_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool FC_LoadRates(MqlRates &rates[], const int needed)
  {
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke pure-channel OHLC geometry, called only from the framework new-bar entry hook.
   return CopyRates(_Symbol, strategy_tf, 1, needed, rates) >= needed;
  }

double FC_ChannelAtr(const int shift)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, shift);
   if(atr > 0.0)
      return atr;
   return QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
  }

bool FC_NoSpikeWindow(MqlRates &rates[], const int anchor_shift, const int channel_bars, const double atr)
  {
   const int oldest_channel_shift = anchor_shift + channel_bars - 1;
   for(int shift = anchor_shift; shift <= oldest_channel_shift + 2; ++shift)
     {
      const double range = rates[shift].high - rates[shift].low;
      if(range <= 0.0)
         return false;
      if(range >= strategy_no_spike_atr_mult * atr)
         return false;
     }
   return true;
  }

bool FC_ChannelStats(MqlRates &rates[],
                     const int anchor_shift,
                     const int channel_bars,
                     const int direction,
                     const double atr,
                     double &origin,
                     double &extreme,
                     double &range_width)
  {
   const int oldest_shift = anchor_shift + channel_bars - 1;
   origin = rates[oldest_shift + 1].close;
   if(origin <= 0.0)
      return false;

   int up_bars = 0;
   int down_bars = 0;
   double high_max = -DBL_MAX;
   double low_min = DBL_MAX;

   for(int shift = oldest_shift; shift >= anchor_shift; --shift)
     {
      const double close_now = rates[shift].close;
      const double close_prev = rates[shift + 1].close;
      if(close_now > close_prev)
         up_bars++;
      else if(close_now < close_prev)
         down_bars++;

      if(rates[shift].high > high_max)
         high_max = rates[shift].high;
      if(rates[shift].low < low_min)
         low_min = rates[shift].low;
     }

   if(high_max <= 0.0 || low_min <= 0.0 || high_max <= low_min)
      return false;

   const double newest_close = rates[anchor_shift].close;
   if(direction > 0)
     {
      if(up_bars - down_bars < strategy_drift_edge_min)
         return false;
      if(newest_close <= origin + strategy_progress_atr_min * atr)
         return false;
      extreme = high_max;
     }
   else
     {
      if(down_bars - up_bars < strategy_drift_edge_min)
         return false;
      if(newest_close >= origin - strategy_progress_atr_min * atr)
         return false;
      extreme = low_min;
     }

   range_width = high_max - low_min;
   if(range_width > strategy_range_atr_max * atr)
      return false;

   return true;
  }

bool FC_BreakAndTrigger(MqlRates &rates[],
                        const int anchor_shift,
                        const int break_shift,
                        const int direction,
                        const double origin,
                        const double atr,
                        double &break_extreme,
                        double &stop_ref)
  {
   if(anchor_shift - break_shift > strategy_stage2_max_bars)
      return false;
   if(break_shift > strategy_stage3_max_bars)
      return false;

   if(direction > 0)
     {
      if(rates[break_shift].close >= origin - strategy_break_atr * atr)
         return false;

      break_extreme = DBL_MAX;
      stop_ref = -DBL_MAX;
      for(int shift = anchor_shift; shift >= break_shift; --shift)
        {
         if(rates[shift].low < break_extreme)
            break_extreme = rates[shift].low;
        }
      for(int shift = break_shift; shift >= 0; --shift)
        {
         if(rates[shift].high > stop_ref)
            stop_ref = rates[shift].high;
        }

      const double range = rates[0].high - rates[0].low;
      if(range < strategy_reversal_range_atr * atr)
         return false;
      if(rates[0].close >= rates[0].open)
         return false;
      const double upper_tail = rates[0].high - MathMax(rates[0].open, rates[0].close);
      if(upper_tail > strategy_reversal_tail_frac * range)
         return false;
      if(rates[0].close >= break_extreme + strategy_reversal_extreme_atr * atr)
         return false;
     }
   else
     {
      if(rates[break_shift].close <= origin + strategy_break_atr * atr)
         return false;

      break_extreme = -DBL_MAX;
      stop_ref = DBL_MAX;
      for(int shift = anchor_shift; shift >= break_shift; --shift)
        {
         if(rates[shift].high > break_extreme)
            break_extreme = rates[shift].high;
        }
      for(int shift = break_shift; shift >= 0; --shift)
        {
         if(rates[shift].low < stop_ref)
            stop_ref = rates[shift].low;
        }

      const double range = rates[0].high - rates[0].low;
      if(range < strategy_reversal_range_atr * atr)
         return false;
      if(rates[0].close <= rates[0].open)
         return false;
      const double lower_tail = MathMin(rates[0].open, rates[0].close) - rates[0].low;
      if(lower_tail > strategy_reversal_tail_frac * range)
         return false;
      if(rates[0].close <= break_extreme - strategy_reversal_extreme_atr * atr)
         return false;
     }

   return break_extreme > 0.0 && stop_ref > 0.0;
  }

bool FC_FindPattern(FC_Pattern &pattern)
  {
   pattern.valid = false;

   const int needed = strategy_channel_max_bars + strategy_stage2_max_bars + strategy_stage3_max_bars + 6;
   MqlRates rates[];
   if(!FC_LoadRates(rates, needed))
      return false;

   for(int break_shift = 1; break_shift <= strategy_stage3_max_bars; ++break_shift)
     {
      for(int anchor_shift = break_shift + 1; anchor_shift <= break_shift + strategy_stage2_max_bars; ++anchor_shift)
        {
         for(int bars = strategy_channel_min_bars; bars <= strategy_channel_max_bars; ++bars)
           {
            const int oldest_shift = anchor_shift + bars - 1;
            if(oldest_shift + 2 >= needed)
               continue;

            const double atr = FC_ChannelAtr(oldest_shift + 1);
            if(atr <= 0.0)
               continue;
            if(!FC_NoSpikeWindow(rates, anchor_shift, bars, atr))
               continue;

            for(int direction = 1; direction >= -1; direction -= 2)
              {
               double origin = 0.0;
               double extreme = 0.0;
               double range_width = 0.0;
               if(!FC_ChannelStats(rates, anchor_shift, bars, direction, atr, origin, extreme, range_width))
                  continue;

               double break_extreme = 0.0;
               double stop_ref = 0.0;
               if(!FC_BreakAndTrigger(rates, anchor_shift, break_shift, direction, origin, atr, break_extreme, stop_ref))
                  continue;

               pattern.valid = true;
               pattern.direction = direction;
               pattern.channel_bars = bars;
               pattern.anchor_shift = anchor_shift;
               pattern.break_shift = break_shift;
               pattern.origin = origin;
               pattern.extreme = extreme;
               pattern.break_extreme = break_extreme;
               pattern.stop_ref = stop_ref;
               pattern.atr = atr;
               pattern.key_time = rates[anchor_shift].time;
               return true;
              }
           }
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!FC_ParamsOk())
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double spread = ask - bid;
   if(ask > bid && spread > strategy_spread_atr_max * atr)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   FC_ResetRequest(req);

   if(TimeCurrent() < g_cooldown_until)
      return false;
   if(FC_HasOpenPosition())
      return false;

   FC_Pattern pattern;
   if(!FC_FindPattern(pattern))
      return false;
   if(pattern.key_time == g_last_pattern_key && pattern.direction == g_last_pattern_dir)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(pattern.direction > 0)
     {
      const double entry = bid;
      const double move = MathAbs(pattern.extreme - pattern.origin);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, pattern.stop_ref + strategy_stop_buffer_atr * pattern.atr);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, pattern.origin - strategy_target_projection_frac * move);
      if(sl <= entry || tp >= entry)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = StringFormat("failed_up_channel_h4_b%d_a%d", pattern.channel_bars, pattern.anchor_shift);
     }
   else
     {
      const double entry = ask;
      const double move = MathAbs(pattern.origin - pattern.extreme);
      const double sl = QM_StopRulesNormalizePrice(_Symbol, pattern.stop_ref - strategy_stop_buffer_atr * pattern.atr);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, pattern.origin + strategy_target_projection_frac * move);
      if(sl >= entry || tp <= entry)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = StringFormat("failed_down_channel_h4_b%d_a%d", pattern.channel_bars, pattern.anchor_shift);
     }

   req.price = 0.0;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   g_last_pattern_key = pattern.key_time;
   g_last_pattern_dir = pattern.direction;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const bool has_position = FC_HasOpenPosition();
   if(g_had_position && !has_position && strategy_cooldown_bars > 0)
     {
      const int seconds = PeriodSeconds(strategy_tf) * strategy_cooldown_bars;
      if(seconds > 0)
         g_cooldown_until = (datetime)(TimeCurrent() + seconds);
     }
   g_had_position = has_position;
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_tf);
   if(seconds_per_bar <= 0)
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && TimeCurrent() - opened >= strategy_time_stop_bars * seconds_per_bar)
        {
         if(strategy_cooldown_bars > 0)
            g_cooldown_until = (datetime)(TimeCurrent() + strategy_cooldown_bars * seconds_per_bar);
         return true;
        }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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

   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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

