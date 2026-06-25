#property strict
#property version   "5.0"
#property description "QM5_2079 Williams Ultimate Oscillator Divergence H4"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 2079;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_H4;
input int    strategy_uo_fast_period           = 7;
input int    strategy_uo_mid_period            = 14;
input int    strategy_uo_slow_period           = 28;
input int    strategy_divergence_window        = 14;
input int    strategy_min_low_separation       = 7;
input double strategy_oversold_level           = 30.0;
input double strategy_overbought_level         = 70.0;
input int    strategy_atr_period               = 20;
input double strategy_initial_stop_atr_mult    = 0.5;
input double strategy_meaningful_extreme_atr   = 0.5;
input double strategy_trail_start_atr_mult     = 1.5;
input double strategy_trail_atr_mult           = 2.5;
input int    strategy_d1_sma_period            = 100;
input bool   strategy_use_d1_sma_filter        = true;
input int    strategy_uo_range_lookback        = 50;
input double strategy_min_uo_range             = 30.0;
input int    strategy_target_breakout_lookback = 20;
input int    strategy_max_hold_bars            = 50;
input int    strategy_warmup_bars              = 120;
input double strategy_spread_atr_mult          = 0.30;

bool     g_close_long_signal = false;
bool     g_close_short_signal = false;
double   g_active_trigger_line = 0.0;
int      g_active_trigger_dir = 0;
datetime g_long_event_anchor_time = 0;
datetime g_short_event_anchor_time = 0;

struct StrategySignalState
  {
   bool     long_signal;
   bool     short_signal;
   double   long_trigger;
   double   short_trigger;
   datetime long_anchor_time;
   datetime short_anchor_time;
   double   uo_now;
   double   atr_now;
   double   signal_low;
   double   signal_high;
   double   close_now;
  };

void Strategy_ResetRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_LoadRates(MqlRates &rates[])
  {
   int bars_needed = strategy_warmup_bars;
   const int min_needed = MathMax(strategy_uo_range_lookback,
                                  (2 * strategy_divergence_window)) + strategy_uo_slow_period + 5;
   if(bars_needed < min_needed)
      bars_needed = min_needed;

   ArrayResize(rates, bars_needed);
   const int copied = CopyRates(_Symbol, strategy_signal_tf, 1, bars_needed, rates); // perf-allowed: bespoke Williams UO divergence window, called only from framework QM_IsNewBar-gated EntrySignal.
   if(copied < min_needed)
      return false;
   ArraySetAsSeries(rates, true);
   return true;
  }

double Strategy_UOAt(const MqlRates &rates[], const int shift)
  {
   if(shift < 0)
      return EMPTY_VALUE;

   const int periods[3] = {strategy_uo_fast_period, strategy_uo_mid_period, strategy_uo_slow_period};
   const double weights[3] = {4.0, 2.0, 1.0};
   double weighted = 0.0;
   double weight_sum = 0.0;

   for(int p = 0; p < 3; ++p)
     {
      const int period = periods[p];
      if(period <= 0)
         return EMPTY_VALUE;

      double bp_sum = 0.0;
      double tr_sum = 0.0;
      for(int i = shift; i < shift + period; ++i)
        {
         const double prev_close = rates[i + 1].close;
         const double true_low = MathMin(rates[i].low, prev_close);
         const double true_high = MathMax(rates[i].high, prev_close);
         const double tr = true_high - true_low;
         const double bp = rates[i].close - true_low;
         bp_sum += bp;
         tr_sum += tr;
        }

      if(tr_sum <= 0.0)
         return EMPTY_VALUE;

      weighted += weights[p] * (bp_sum / tr_sum);
      weight_sum += weights[p];
     }

   if(weight_sum <= 0.0)
      return EMPTY_VALUE;
   return 100.0 * weighted / weight_sum;
  }

bool Strategy_BuildUO(const MqlRates &rates[], double &uo[], const int count)
  {
   if(count <= 0)
      return false;
   ArrayResize(uo, count);
   ArraySetAsSeries(uo, true);
   for(int i = 0; i < count; ++i)
     {
      uo[i] = Strategy_UOAt(rates, i);
      if(uo[i] == EMPTY_VALUE)
         return false;
     }
   return true;
  }

int Strategy_MinLowIndex(const MqlRates &rates[], const int start, const int count)
  {
   int idx = start;
   double best = DBL_MAX;
   for(int i = start; i < start + count; ++i)
     {
      if(rates[i].low < best)
        {
         best = rates[i].low;
         idx = i;
        }
     }
   return idx;
  }

int Strategy_MaxHighIndex(const MqlRates &rates[], const int start, const int count)
  {
   int idx = start;
   double best = -DBL_MAX;
   for(int i = start; i < start + count; ++i)
     {
      if(rates[i].high > best)
        {
         best = rates[i].high;
         idx = i;
        }
     }
   return idx;
  }

int Strategy_MinUOIndex(const double &uo[], const int start, const int count)
  {
   int idx = start;
   double best = DBL_MAX;
   for(int i = start; i < start + count; ++i)
     {
      if(uo[i] < best)
        {
         best = uo[i];
         idx = i;
        }
     }
   return idx;
  }

int Strategy_MaxUOIndex(const double &uo[], const int start, const int count)
  {
   int idx = start;
   double best = -DBL_MAX;
   for(int i = start; i < start + count; ++i)
     {
      if(uo[i] > best)
        {
         best = uo[i];
         idx = i;
        }
     }
   return idx;
  }

bool Strategy_UOAnyBelow(const double &uo[], const int start, const int count, const double level)
  {
   for(int i = start; i < start + count; ++i)
      if(uo[i] < level)
         return true;
   return false;
  }

bool Strategy_UOAnyAbove(const double &uo[], const int start, const int count, const double level)
  {
   for(int i = start; i < start + count; ++i)
      if(uo[i] > level)
         return true;
   return false;
  }

double Strategy_MaxUOBetween(const double &uo[], const int a, const int b)
  {
   const int lo = MathMin(a, b);
   const int hi = MathMax(a, b);
   double best = -DBL_MAX;
   for(int i = lo; i <= hi; ++i)
      best = MathMax(best, uo[i]);
   return best;
  }

double Strategy_MinUOBetween(const double &uo[], const int a, const int b)
  {
   const int lo = MathMin(a, b);
   const int hi = MathMax(a, b);
   double best = DBL_MAX;
   for(int i = lo; i <= hi; ++i)
      best = MathMin(best, uo[i]);
   return best;
  }

double Strategy_HighestHigh(const MqlRates &rates[], const int start, const int count)
  {
   double best = -DBL_MAX;
   for(int i = start; i < start + count; ++i)
      best = MathMax(best, rates[i].high);
   return best;
  }

double Strategy_LowestLow(const MqlRates &rates[], const int start, const int count)
  {
   double best = DBL_MAX;
   for(int i = start; i < start + count; ++i)
      best = MathMin(best, rates[i].low);
   return best;
  }

bool Strategy_HasOurPosition()
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

void Strategy_EvaluateSignals(StrategySignalState &state)
  {
   state.long_signal = false;
   state.short_signal = false;
   state.long_trigger = 0.0;
   state.short_trigger = 0.0;
   state.long_anchor_time = 0;
   state.short_anchor_time = 0;
   state.uo_now = EMPTY_VALUE;
   state.atr_now = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   state.signal_low = 0.0;
   state.signal_high = 0.0;
   state.close_now = 0.0;
   g_close_long_signal = false;
   g_close_short_signal = false;

   if(strategy_divergence_window < 2 ||
      strategy_uo_fast_period <= 0 ||
      strategy_uo_mid_period <= 0 ||
      strategy_uo_slow_period <= 0 ||
      strategy_atr_period <= 0 ||
      state.atr_now <= 0.0)
      return;

   MqlRates rates[];
   if(!Strategy_LoadRates(rates))
      return;

   const int uo_count = MathMax(strategy_uo_range_lookback, 2 * strategy_divergence_window) + 2;
   double uo[];
   if(!Strategy_BuildUO(rates, uo, uo_count))
      return;

   state.uo_now = uo[0];
   state.signal_low = rates[0].low;
   state.signal_high = rates[0].high;
   state.close_now = rates[0].close;

   double uo_min = DBL_MAX;
   double uo_max = -DBL_MAX;
   for(int i = 0; i < strategy_uo_range_lookback; ++i)
     {
      uo_min = MathMin(uo_min, uo[i]);
      uo_max = MathMax(uo_max, uo[i]);
     }
   if((uo_max - uo_min) < strategy_min_uo_range)
      return;

   const int w = strategy_divergence_window;
   const int current_low_idx = Strategy_MinLowIndex(rates, 0, w);
   const int prior_low_idx = Strategy_MinLowIndex(rates, w, w);
   const int current_uo_low_idx = Strategy_MinUOIndex(uo, 0, w);
   const int prior_uo_low_idx = Strategy_MinUOIndex(uo, w, w);
   const int current_high_idx = Strategy_MaxHighIndex(rates, 0, w);
   const int prior_high_idx = Strategy_MaxHighIndex(rates, w, w);
   const int current_uo_high_idx = Strategy_MaxUOIndex(uo, 0, w);
   const int prior_uo_high_idx = Strategy_MaxUOIndex(uo, w, w);

   const bool long_price_break = rates[current_low_idx].low < (rates[prior_low_idx].low - strategy_meaningful_extreme_atr * state.atr_now);
   const bool long_uo_div = uo[current_uo_low_idx] > uo[prior_uo_low_idx];
   const bool long_oversold = Strategy_UOAnyBelow(uo, w, w, strategy_oversold_level);
   const bool long_sep = MathAbs(prior_low_idx - current_low_idx) >= strategy_min_low_separation;
   const double long_trigger = Strategy_MaxUOBetween(uo, prior_low_idx, current_low_idx);
   const bool long_cross = uo[1] <= long_trigger && uo[0] > long_trigger;
   bool long_regime = true;
   if(strategy_use_d1_sma_filter)
     {
      const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
      long_regime = d1_sma > 0.0 && rates[0].close > d1_sma;
     }

   if(long_price_break && long_uo_div && long_oversold && long_sep && long_cross && long_regime)
     {
      state.long_signal = true;
      state.long_trigger = long_trigger;
      state.long_anchor_time = rates[current_low_idx].time;
     }

   const bool short_price_break = rates[current_high_idx].high > (rates[prior_high_idx].high + strategy_meaningful_extreme_atr * state.atr_now);
   const bool short_uo_div = uo[current_uo_high_idx] < uo[prior_uo_high_idx];
   const bool short_overbought = Strategy_UOAnyAbove(uo, w, w, strategy_overbought_level);
   const bool short_sep = MathAbs(prior_high_idx - current_high_idx) >= strategy_min_low_separation;
   const double short_trigger = Strategy_MinUOBetween(uo, prior_high_idx, current_high_idx);
   const bool short_cross = uo[1] >= short_trigger && uo[0] < short_trigger;
   bool short_regime = true;
   if(strategy_use_d1_sma_filter)
     {
      const double d1_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_d1_sma_period, 1, PRICE_CLOSE);
      short_regime = d1_sma > 0.0 && rates[0].close < d1_sma;
     }

   if(short_price_break && short_uo_div && short_overbought && short_sep && short_cross && short_regime)
     {
      state.short_signal = true;
      state.short_trigger = short_trigger;
      state.short_anchor_time = rates[current_high_idx].time;
     }

   const double recent_high = Strategy_HighestHigh(rates, 1, strategy_target_breakout_lookback);
   const double recent_low = Strategy_LowestLow(rates, 1, strategy_target_breakout_lookback);
   g_close_long_signal = state.short_signal ||
                         (uo[0] > strategy_overbought_level && rates[0].close > recent_high) ||
                         (g_active_trigger_dir > 0 && g_active_trigger_line > 0.0 && uo[0] < g_active_trigger_line);
   g_close_short_signal = state.long_signal ||
                          (uo[0] < strategy_oversold_level && rates[0].close < recent_low) ||
                          (g_active_trigger_dir < 0 && g_active_trigger_line > 0.0 && uo[0] > g_active_trigger_line);
  }

bool Strategy_NoTradeFilter()
  {
   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr > 0.0 && ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double spread = ask - bid;
      if(spread > strategy_spread_atr_mult * atr)
         return true;
     }
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetRequest(req);

   StrategySignalState state;
   Strategy_EvaluateSignals(state);

   if(Strategy_HasOurPosition())
      return false;

   if(state.long_signal && state.long_anchor_time != g_long_event_anchor_time)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.signal_low - strategy_initial_stop_atr_mult * state.atr_now);
      req.tp = 0.0;
      req.reason = "UO_BULL_DIV_TRIGGER";
      g_active_trigger_line = state.long_trigger;
      g_active_trigger_dir = 1;
      g_long_event_anchor_time = state.long_anchor_time;
      return true;
     }

   if(state.short_signal && state.short_anchor_time != g_short_event_anchor_time)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, state.signal_high + strategy_initial_stop_atr_mult * state.atr_now);
      req.tp = 0.0;
      req.reason = "UO_BEAR_DIV_TRIGGER";
      g_active_trigger_line = state.short_trigger;
      g_active_trigger_dir = -1;
      g_short_event_anchor_time = state.short_anchor_time;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr = QM_ATR(_Symbol, strategy_signal_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      if(ptype == POSITION_TYPE_BUY && bid > 0.0 && (bid - open_price) >= strategy_trail_start_atr_mult * atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
      if(ptype == POSITION_TYPE_SELL && ask > 0.0 && (open_price - ask) >= strategy_trail_start_atr_mult * atr)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int max_hold_seconds = strategy_max_hold_bars * PeriodSeconds(strategy_signal_tf);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_close_long_signal)
        {
         g_active_trigger_line = 0.0;
         g_active_trigger_dir = 0;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && g_close_short_signal)
        {
         g_active_trigger_line = 0.0;
         g_active_trigger_dir = 0;
         return true;
        }

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(max_hold_seconds > 0 && opened > 0 && (TimeCurrent() - opened) >= max_hold_seconds)
        {
         g_active_trigger_line = 0.0;
         g_active_trigger_dir = 0;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_2079\",\"ea\":\"williams_ultimate_oscillator_h4\"}");
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
