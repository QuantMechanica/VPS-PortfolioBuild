#property strict
#property version   "5.0"
#property description "QM5_41220 Grimes Contextual Pullback — Q09 REQUAL-8"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_41220 grimes-context-pb-requal8
// -----------------------------------------------------------------------------
// New-identity requalification port of QM5_10939_grimes-context-pb under
// OWNER-DEC-Q09HOLD-REQUAL-8-20260829. Strategy mechanics are unchanged:
// H4 continuation entries require aligned D1 trend/ADX context, a quantified
// surprise leg, and a controlled pullback before the three-bar trigger breaks.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41220;
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
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period             = 20;
input int    strategy_d1_fast_ema            = 20;
input int    strategy_d1_slow_ema            = 50;
input int    strategy_d1_adx_period          = 14;
input double strategy_d1_adx_min             = 16.0;
input int    strategy_surprise_lookback      = 12;
input int    strategy_breakout_lookback      = 30;
input double strategy_surprise_atr_mult      = 2.5;
input double strategy_climax_bar_atr_mult    = 3.0;
input int    strategy_pullback_min_bars      = 3;
input int    strategy_pullback_max_bars      = 10;
input double strategy_pullback_min_pct       = 25.0;
input double strategy_pullback_max_pct       = 55.0;
input int    strategy_trigger_lookback       = 3;
input double strategy_pullback_bar_atr_mult  = 1.5;
input double strategy_stop_atr_buffer        = 0.25;
input double strategy_max_stop_atr_mult      = 2.25;
input double strategy_target_r_mult          = 2.0;
input double strategy_breakeven_r_mult       = 1.0;
input int    strategy_time_exit_h4_bars      = 18;
input double strategy_spread_stop_max_pct    = 8.0;

double g_qm41220_retrace_exit = 0.0;
int    g_qm41220_direction = 0;

// -----------------------------------------------------------------------------
// No Trade Filter
// -----------------------------------------------------------------------------
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Trade Entry
// -----------------------------------------------------------------------------
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 ||
      strategy_d1_fast_ema <= 0 ||
      strategy_d1_slow_ema <= 0 ||
      strategy_d1_adx_period <= 0 ||
      strategy_d1_adx_min < 0.0 ||
      strategy_surprise_lookback <= 0 ||
      strategy_breakout_lookback <= 0 ||
      strategy_surprise_atr_mult <= 0.0 ||
      strategy_climax_bar_atr_mult <= 0.0 ||
      strategy_pullback_min_bars < 1 ||
      strategy_pullback_max_bars < strategy_pullback_min_bars ||
      strategy_pullback_min_pct < 0.0 ||
      strategy_pullback_max_pct < strategy_pullback_min_pct ||
      strategy_pullback_max_pct > 100.0 ||
      strategy_trigger_lookback < 1 ||
      strategy_pullback_bar_atr_mult <= 0.0 ||
      strategy_stop_atr_buffer < 0.0 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_breakeven_r_mult <= 0.0 ||
      strategy_time_exit_h4_bars <= 0 ||
      strategy_spread_stop_max_pct < 0.0)
      return false;

   const double d1_fast = QM_EMA(_Symbol, PERIOD_D1,
                                 strategy_d1_fast_ema, 1);
   const double d1_slow = QM_EMA(_Symbol, PERIOD_D1,
                                 strategy_d1_slow_ema, 1);
   const double d1_adx = QM_ADX(_Symbol, PERIOD_D1,
                                strategy_d1_adx_period, 1);
   const double h4_atr = QM_ATR(_Symbol, PERIOD_H4,
                                strategy_atr_period, 1);
   if(d1_fast <= 0.0 || d1_slow <= 0.0 ||
      d1_adx < strategy_d1_adx_min || h4_atr <= 0.0)
      return false;

   // Current framework series-access pattern: use the pooled single-bar reader
   // rather than a raw one-element CopyRates call.
   MqlRates d1_bar;
   ZeroMemory(d1_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1_bar))
      return false;
   const double d1_close = d1_bar.close;
   const bool long_context = (d1_close > d1_slow && d1_fast > d1_slow);
   const bool short_context = (d1_close < d1_slow && d1_fast < d1_slow);
   if(!long_context && !short_context)
      return false;

   const int history_bars = strategy_pullback_max_bars +
                            strategy_surprise_lookback +
                            strategy_breakout_lookback + 8;
   if(history_bars <= 0 || history_bars > 512)
      return false;

   MqlRates rates[];
   ArrayResize(rates, history_bars);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H4, 1, history_bars, rates); // perf-allowed: bounded H4 structural scan after the framework new-bar gate.
   const int rates_size = ArraySize(rates);
   if(copied < history_bars || rates_size < history_bars || copied > rates_size)
      return false;
   if(rates_size <= 0)
      return false;

   const double close_trigger = rates[0].close;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_trigger <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   for(int pullback_bars = strategy_pullback_min_bars;
       pullback_bars <= strategy_pullback_max_bars;
       ++pullback_bars)
     {
      const int leg_end_shift = pullback_bars + 2;
      double pullback_high = -DBL_MAX;
      double pullback_low = DBL_MAX;
      double trigger_high = -DBL_MAX;
      double trigger_low = DBL_MAX;
      bool pullback_long_quality = true;
      bool pullback_short_quality = true;

      for(int shift = 2; shift <= pullback_bars + 1; ++shift)
        {
         const int idx = shift - 1;
         if(idx < 0 || idx >= rates_size)
            return false;
         const MqlRates bar = rates[idx];
         pullback_high = MathMax(pullback_high, bar.high);
         pullback_low = MathMin(pullback_low, bar.low);
         if(shift <= strategy_trigger_lookback + 1)
           {
            trigger_high = MathMax(trigger_high, bar.high);
            trigger_low = MathMin(trigger_low, bar.low);
           }
         if(bar.high - bar.low > strategy_pullback_bar_atr_mult * h4_atr)
           {
            pullback_long_quality = false;
            pullback_short_quality = false;
           }

         const double ema20_h4 = QM_EMA(_Symbol, PERIOD_H4,
                                        strategy_d1_fast_ema, shift);
         if(ema20_h4 <= 0.0)
           {
            pullback_long_quality = false;
            pullback_short_quality = false;
           }
         else
           {
            if(bar.close < ema20_h4)
               pullback_long_quality = false;
            if(bar.close > ema20_h4)
               pullback_short_quality = false;
           }
        }

      if(trigger_high <= 0.0 || trigger_low <= 0.0 ||
         pullback_high <= 0.0 || pullback_low <= 0.0)
         continue;

      for(int leg_start_shift = leg_end_shift + 1;
          leg_start_shift <= leg_end_shift + strategy_surprise_lookback;
          ++leg_start_shift)
        {
         double leg_high = -DBL_MAX;
         double leg_low = DBL_MAX;
         double largest_leg_bar = 0.0;
         for(int shift = leg_end_shift; shift <= leg_start_shift; ++shift)
           {
            const int idx = shift - 1;
            if(idx < 0 || idx >= rates_size)
               return false;
            const MqlRates leg_bar = rates[idx];
            leg_high = MathMax(leg_high, leg_bar.high);
            leg_low = MathMin(leg_low, leg_bar.low);
            largest_leg_bar = MathMax(largest_leg_bar,
                                      leg_bar.high - leg_bar.low);
           }
         if(leg_high <= 0.0 || leg_low <= 0.0 || leg_high <= leg_low)
            continue;
         if(largest_leg_bar > strategy_climax_bar_atr_mult * h4_atr)
            continue;

         double prior_high = -DBL_MAX;
         double prior_low = DBL_MAX;
         for(int shift = leg_start_shift + 1;
             shift <= leg_start_shift + strategy_breakout_lookback;
             ++shift)
           {
            const int idx = shift - 1;
            if(idx < 0 || idx >= rates_size)
               return false;
            prior_high = MathMax(prior_high, rates[idx].high);
            prior_low = MathMin(prior_low, rates[idx].low);
           }

         const double leg_size = leg_high - leg_low;
         const int leg_end_idx = leg_end_shift - 1;
         if(leg_end_idx < 0 || leg_end_idx >= rates_size)
            return false;
         const MqlRates leg_end = rates[leg_end_idx];

         if(long_context && pullback_long_quality)
           {
            if(leg_end.close <= prior_high)
               continue;
            if(leg_end.close - leg_low < strategy_surprise_atr_mult * h4_atr)
               continue;
            const double retrace_pct =
               100.0 * (leg_high - pullback_low) / leg_size;
            if(retrace_pct < strategy_pullback_min_pct ||
               retrace_pct > strategy_pullback_max_pct)
               continue;
            if(close_trigger <= trigger_high)
               continue;

            const double entry = ask;
            const double stop = pullback_low -
                                strategy_stop_atr_buffer * h4_atr;
            const double risk = entry - stop;
            if(risk <= 0.0 ||
               risk > strategy_max_stop_atr_mult * h4_atr)
               continue;
            const double spread = ask - bid;
            if(spread > strategy_spread_stop_max_pct * 0.01 * risk)
               continue;

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = NormalizeDouble(stop, _Digits);
            req.tp = NormalizeDouble(entry +
                                     strategy_target_r_mult * risk, _Digits);
            req.reason = "GRIMES_CONTEXT_PB_LONG";
            g_qm41220_retrace_exit = NormalizeDouble(
               leg_high - 0.618 * leg_size, _Digits);
            g_qm41220_direction = 1;
            return true;
           }

         if(short_context && pullback_short_quality)
           {
            if(leg_end.close >= prior_low)
               continue;
            if(leg_high - leg_end.close < strategy_surprise_atr_mult * h4_atr)
               continue;
            const double retrace_pct =
               100.0 * (pullback_high - leg_low) / leg_size;
            if(retrace_pct < strategy_pullback_min_pct ||
               retrace_pct > strategy_pullback_max_pct)
               continue;
            if(close_trigger >= trigger_low)
               continue;

            const double entry = bid;
            const double stop = pullback_high +
                                strategy_stop_atr_buffer * h4_atr;
            const double risk = stop - entry;
            if(risk <= 0.0 ||
               risk > strategy_max_stop_atr_mult * h4_atr)
               continue;
            const double spread = ask - bid;
            if(spread > strategy_spread_stop_max_pct * 0.01 * risk)
               continue;

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = NormalizeDouble(stop, _Digits);
            req.tp = NormalizeDouble(entry -
                                     strategy_target_r_mult * risk, _Digits);
            req.reason = "GRIMES_CONTEXT_PB_SHORT";
            g_qm41220_retrace_exit = NormalizeDouble(
               leg_low + 0.618 * leg_size, _Digits);
            g_qm41220_direction = -1;
            return true;
           }
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Trade Management
// -----------------------------------------------------------------------------
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy
                                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price)
                                  : (open_price - market_price);
      if(risk <= 0.0 || moved < strategy_breakeven_r_mult * risk)
         continue;

      const double be_sl = NormalizeDouble(open_price, _Digits);
      const bool improves = is_buy
                            ? (be_sl > current_sl + point * 0.5)
                            : (be_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "GRIMES_CONTEXT_PB_BE_1R");
     }
  }

// -----------------------------------------------------------------------------
// Trade Close
// -----------------------------------------------------------------------------
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool has_position = false;
   datetime open_time = 0;
   int direction = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      has_position = true;
      break;
     }

   if(!has_position)
      return false;

   const int bar_seconds = PeriodSeconds(PERIOD_H4);
   if(bar_seconds > 0 && open_time > 0 &&
      TimeCurrent() - open_time >= strategy_time_exit_h4_bars * bar_seconds)
      return true;

   if(g_qm41220_retrace_exit <= 0.0)
      return false;

   MqlRates last_bar;
   ZeroMemory(last_bar);
   if(!QM_ReadBar(_Symbol, PERIOD_H4, 1, last_bar))
      return false;

   const int active_direction = (g_qm41220_direction != 0)
                                ? g_qm41220_direction : direction;
   if(active_direction > 0 &&
      last_bar.close < g_qm41220_retrace_exit)
      return true;
   if(active_direction < 0 &&
      last_bar.close > g_qm41220_retrace_exit)
      return true;

   return false;
  }

// -----------------------------------------------------------------------------
// News Filter Hook
// -----------------------------------------------------------------------------
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Current V5 framework wiring
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

   if(!QM_FrameworkDeclareExecutionContract(
         PERIOD_H4,
         QM_FRIDAY_CLOSE_FRAMEWORK_OVERRIDE,
         "DXZ_LEGACY_BOOK_POLICY_REQUAL_REQUIRED"))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT",
               StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   // Q08 evidence lifecycle: no guard may skip open-position MAE sampling.
   QM_FrameworkTrackOpenPositionMae();

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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Mandatory news blackout gates new entries only. Management and exits
   // above remain reachable throughout restricted windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar(_Symbol, PERIOD_H4))
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
