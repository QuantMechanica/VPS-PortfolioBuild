#ifndef QM_MOD_GRIMESNESTEDPBV2_MQH
#define QM_MOD_GRIMESNESTEDPBV2_MQH

#include "../QM_StrategyModule.mqh"

// Phase-3-REST — CQMStrategyModule port of the standalone QM5_12989
// grimes-nested-pb-v2 EA (XAUUSD.DWX, H4). Entry/Exit/Manage/NoTrade
// mechanics and strategy input defaults are taken 1:1 from
// framework/EAs/QM5_12989_grimes-nested-pb-v2/QM5_12989_grimes-nested-pb-v2.mq5
// (its XAUUSD backtest set's overrides all equal the .mq5 input defaults, so
// the .mq5 input defaults ARE the verified backtest config).
// Original identity preserved: Magic() = 129890003 (ea_id 12989, slot 3).
//
// Differences from the standalone are framework-lifecycle only:
//  - TF() is hard PERIOD_H4 (the standalone's own chart period per its
//    backtest set). Unlike the other three Phase-3 modules, this strategy
//    already reads every timeframe explicitly (PERIOD_D1 / PERIOD_H4 args
//    to every QM_* reader and CopyRates call, never `_Period` or a
//    chart-relative input) — there is no chart-TF dependency to convert.
//  - Entry sizes via the explicit Phase-2.5 dual-mode path
//    (QM_TM_OpenPosition(..., Magic(), RiskMode(), RiskValue())) instead of
//    the standalone's global risk context — no global risk state is read.
//  - CheckExit() collapses the standalone's two-pass "find trigger, then
//    close all own-magic positions" to one pass because this strategy only
//    ever opens plain market orders (TRADE_ACTION_DEAL via QM_BUY/QM_SELL),
//    so duplicate-entry protection in QM_EntryInternal guarantees at most
//    one open position per (magic, symbol) at a time.
class CQMModGrimesNestedPbV2 : public CQMStrategyModule
  {
private:
   bool        m_enabled;
   QM_RiskMode m_risk_mode;
   double      m_risk_value;

   // Strategy inputs — identical defaults to the standalone EA / its
   // verified backtest set
   // (QM5_12989_grimes-nested-pb-v2_XAUUSD.DWX_H4_backtest.set).
   int    m_d1_fast_ema;
   int    m_d1_slow_ema;
   int    m_d1_pullback_bars;
   int    m_d1_impulse_bars;
   double m_pullback_min_fraction;
   double m_pullback_max_fraction;
   int    m_h4_atr_period;
   int    m_h4_pause_min_bars;
   int    m_h4_pause_max_bars;
   double m_pause_range_atr_mult;
   double m_stop_atr_mult;
   double m_max_stop_atr_mult;
   double m_target_r;
   double m_breakeven_trigger_r;
   int    m_time_exit_bars;
   bool   m_use_atr_trail_after_be;
   double m_atr_trail_trigger_r;
   double m_atr_trail_mult;
   int    m_d1_atr_percentile_lookback;
   double m_d1_atr_min_percentile;
   double m_spread_stop_max_fraction;

public:
   CQMModGrimesNestedPbV2()
     {
      m_enabled                    = false;
      m_risk_mode                  = QM_RISK_MODE_UNSET;
      m_risk_value                 = 0.0;
      m_d1_fast_ema                = 20;
      m_d1_slow_ema                = 50;
      m_d1_pullback_bars           = 12;
      m_d1_impulse_bars            = 24;
      m_pullback_min_fraction      = 0.25;
      m_pullback_max_fraction      = 0.55;
      m_h4_atr_period              = 20;
      m_h4_pause_min_bars          = 3;
      m_h4_pause_max_bars          = 8;
      m_pause_range_atr_mult       = 1.25;
      m_stop_atr_mult              = 0.35;
      m_max_stop_atr_mult          = 2.5;
      m_target_r                   = 2.0;
      m_breakeven_trigger_r        = 1.5;
      m_time_exit_bars             = 40;
      m_use_atr_trail_after_be     = false;
      m_atr_trail_trigger_r        = 1.5;
      m_atr_trail_mult             = 2.0;
      m_d1_atr_percentile_lookback = 120;
      m_d1_atr_min_percentile      = 20.0;
      m_spread_stop_max_fraction   = 0.08;
     }

   void Configure(const bool enabled, const QM_RiskMode risk_mode, const double risk_value)
     {
      m_enabled    = enabled;
      m_risk_mode  = risk_mode;
      m_risk_value = risk_value;
     }

   virtual bool             Enabled()   const { return m_enabled; }
   virtual long              Magic()     const { return 129890003L; }
   virtual ENUM_TIMEFRAMES  TF()        const { return PERIOD_H4; }
   virtual QM_RiskMode      RiskMode()  const { return m_risk_mode; }
   virtual double           RiskValue() const { return m_risk_value; }

   // Ported 1:1 from Strategy_NoTradeFilter(). Card has no time-of-day
   // filter; news and Friday close are shared corset gates, spread <= 8% of
   // stop distance is enforced in CheckEntry().
   virtual bool NoTrade(datetime now)
     {
      if(m_h4_pause_min_bars < 3 || m_h4_pause_max_bars > 8 ||
         m_h4_pause_min_bars > m_h4_pause_max_bars)
         return true;

      if(m_d1_pullback_bars < 3 || m_d1_impulse_bars < 3 ||
         m_h4_atr_period < 1 || m_d1_atr_percentile_lookback < 20)
         return true;

      return false;
     }

   // Ported 1:1 from Strategy_ManageOpenPosition().
   virtual void ManageOpen()
     {
      const long magic = Magic();

      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double current_sl = PositionGetDouble(POSITION_SL);
         const double current_tp = PositionGetDouble(POSITION_TP);
         if(open_price <= 0.0 || current_sl <= 0.0 || current_tp <= 0.0)
            continue;

         const bool is_buy = (pos_type == POSITION_TYPE_BUY);
         const double original_r = MathAbs(current_tp - open_price) / m_target_r;
         if(original_r <= 0.0)
            continue;

         const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                            : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(market_price <= 0.0)
            continue;

         const double gained = is_buy ? (market_price - open_price) : (open_price - market_price);
         if(m_use_atr_trail_after_be)
           {
            if(gained >= m_atr_trail_trigger_r * original_r && m_atr_trail_mult > 0.0)
               QM_TM_TrailATR(ticket, m_h4_atr_period, m_atr_trail_mult);
            continue;
           }

         if(gained < m_breakeven_trigger_r * original_r)
            continue;

         const double target_sl = NormalizeDouble(open_price, _Digits);
         const bool improves = is_buy ? (current_sl < target_sl) : (current_sl > target_sl);
         if(improves)
            QM_TM_MoveSL(ticket, target_sl, "grimes_nested_pb_breakeven_1_5r");
        }
     }

   // Ported 1:1 from Strategy_ExitSignal() + its OnTick close loop, collapsed
   // to one pass — see class header.
   virtual void CheckExit()
     {
      const long magic = Magic();

      MqlRates last_h4[];
      ArrayResize(last_h4, 1);
      ArraySetAsSeries(last_h4, true);
      if(CopyRates(_Symbol, PERIOD_H4, 1, 1, last_h4) != 1) // perf-allowed: one closed H4 bar for the exit check while a position is open.
         return;

      const double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, m_d1_fast_ema, 1);
      if(h4_ema_fast <= 0.0)
         return;

      const int h4_seconds = PeriodSeconds(PERIOD_H4);
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(!QM_ModuleOwnsPosition(magic))
            continue;

         const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         const bool is_buy = (pos_type == POSITION_TYPE_BUY);

         bool should_exit = false;
         if(is_buy && last_h4[0].close < h4_ema_fast)
            should_exit = true;
         if(!is_buy && last_h4[0].close > h4_ema_fast)
            should_exit = true;

         if(!should_exit)
           {
            const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            if(h4_seconds > 0 && open_time > 0)
              {
               const int held_bars = (int)((TimeCurrent() - open_time) / h4_seconds);
               if(held_bars >= m_time_exit_bars)
                  should_exit = true;
              }
           }

         if(should_exit)
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   // Ported 1:1 from Strategy_EntrySignal(). Sizing is the Phase-3 dual-mode
   // requirement: explicit magic + explicit (RiskMode(), RiskValue()), never
   // the global risk context.
   virtual void CheckEntry()
     {
      const int d1_count = m_d1_pullback_bars + m_d1_impulse_bars + 4;
      const int h4_count = m_h4_pause_max_bars + 2;
      if(d1_count < 20 || h4_count < 5)
         return;

      MqlRates d1_rates[];
      MqlRates h4_rates[];
      ArrayResize(d1_rates, d1_count);
      ArrayResize(h4_rates, h4_count);
      ArraySetAsSeries(d1_rates, true);
      ArraySetAsSeries(h4_rates, true);

      // perf-allowed: bounded structural OHLC reads, called only by the
      // master dispatcher after this module's own H4 new-bar gate passes.
      if(CopyRates(_Symbol, PERIOD_D1, 1, d1_count, d1_rates) != d1_count)
         return;
      if(CopyRates(_Symbol, PERIOD_H4, 1, h4_count, h4_rates) != h4_count)
         return;

      double atr_values[];
      ArrayResize(atr_values, m_d1_atr_percentile_lookback);
      for(int i = 0; i < m_d1_atr_percentile_lookback; ++i)
        {
         atr_values[i] = QM_ATR(_Symbol, PERIOD_D1, m_h4_atr_period, i + 1);
         if(atr_values[i] <= 0.0)
            return;
        }
      ArraySort(atr_values);
      int percentile_index = (int)MathFloor((m_d1_atr_min_percentile / 100.0) *
                                            (m_d1_atr_percentile_lookback - 1));
      if(percentile_index < 0)
         percentile_index = 0;
      if(percentile_index >= m_d1_atr_percentile_lookback)
         percentile_index = m_d1_atr_percentile_lookback - 1;

      const double current_d1_atr = QM_ATR(_Symbol, PERIOD_D1, m_h4_atr_period, 1);
      if(current_d1_atr <= 0.0 || current_d1_atr < atr_values[percentile_index])
         return;

      const double d1_close_1 = d1_rates[0].close;
      const double d1_ema_fast_1 = QM_EMA(_Symbol, PERIOD_D1, m_d1_fast_ema, 1);
      const double d1_ema_slow_1 = QM_EMA(_Symbol, PERIOD_D1, m_d1_slow_ema, 1);
      if(d1_close_1 <= 0.0 || d1_ema_fast_1 <= 0.0 || d1_ema_slow_1 <= 0.0)
         return;

      bool long_trend = (d1_close_1 > d1_ema_slow_1 && d1_ema_fast_1 > d1_ema_slow_1);
      bool short_trend = (d1_close_1 < d1_ema_slow_1 && d1_ema_fast_1 < d1_ema_slow_1);
      if(!long_trend && !short_trend)
         return;

      double pullback_high = -DBL_MAX;
      double pullback_low = DBL_MAX;
      bool long_above_slow = true;
      bool short_below_slow = true;
      for(int shift = 1; shift <= m_d1_pullback_bars; ++shift)
        {
         const int idx = shift - 1;
         pullback_high = MathMax(pullback_high, d1_rates[idx].high);
         pullback_low = MathMin(pullback_low, d1_rates[idx].low);

         const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, m_d1_slow_ema, shift);
         if(ema_slow <= 0.0)
            return;
         if(d1_rates[idx].close < ema_slow)
            long_above_slow = false;
         if(d1_rates[idx].close > ema_slow)
            short_below_slow = false;
        }

      double impulse_high = -DBL_MAX;
      double impulse_low = DBL_MAX;
      const int impulse_start_shift = m_d1_pullback_bars + 1;
      const int impulse_end_shift = m_d1_pullback_bars + m_d1_impulse_bars;
      for(int shift = impulse_start_shift; shift <= impulse_end_shift; ++shift)
        {
         const int idx = shift - 1;
         impulse_high = MathMax(impulse_high, d1_rates[idx].high);
         impulse_low = MathMin(impulse_low, d1_rates[idx].low);
        }

      const double impulse_range = impulse_high - impulse_low;
      if(impulse_range <= 0.0)
         return;

      const double prior_2bar_high = MathMax(d1_rates[1].high, d1_rates[2].high);
      const double prior_2bar_low = MathMin(d1_rates[1].low, d1_rates[2].low);

      const double long_retrace = (impulse_high - pullback_low) / impulse_range;
      const double short_retrace = (pullback_high - impulse_low) / impulse_range;
      const bool long_d1_turn = (d1_close_1 > prior_2bar_high || d1_close_1 > d1_ema_fast_1);
      const bool short_d1_turn = (d1_close_1 < prior_2bar_low || d1_close_1 < d1_ema_fast_1);

      const bool long_context =
         long_trend &&
         long_above_slow &&
         long_retrace >= m_pullback_min_fraction &&
         long_retrace <= m_pullback_max_fraction &&
         long_d1_turn;

      const bool short_context =
         short_trend &&
         short_below_slow &&
         short_retrace >= m_pullback_min_fraction &&
         short_retrace <= m_pullback_max_fraction &&
         short_d1_turn;

      if(!long_context && !short_context)
         return;

      const double h4_atr = QM_ATR(_Symbol, PERIOD_H4, m_h4_atr_period, 1);
      if(h4_atr <= 0.0)
         return;

      const double trigger_close = h4_rates[0].close;
      if(trigger_close <= 0.0)
         return;

      double chosen_pause_high = 0.0;
      double chosen_pause_low = 0.0;
      bool long_breakout = false;
      bool short_breakout = false;

      for(int pause_bars = m_h4_pause_min_bars;
          pause_bars <= m_h4_pause_max_bars;
          ++pause_bars)
        {
         double pause_high = -DBL_MAX;
         double pause_low = DBL_MAX;
         bool closes_above_fast = true;
         bool closes_below_fast = true;

         for(int shift = 2; shift <= pause_bars + 1; ++shift)
           {
            const int idx = shift - 1;
            pause_high = MathMax(pause_high, h4_rates[idx].high);
            pause_low = MathMin(pause_low, h4_rates[idx].low);

            const double h4_ema_fast = QM_EMA(_Symbol, PERIOD_H4, m_d1_fast_ema, shift);
            if(h4_ema_fast <= 0.0)
               return;
            if(h4_rates[idx].close <= h4_ema_fast)
               closes_above_fast = false;
            if(h4_rates[idx].close >= h4_ema_fast)
               closes_below_fast = false;
           }

         if((pause_high - pause_low) > m_pause_range_atr_mult * h4_atr)
            continue;

         if(long_context && closes_above_fast && trigger_close > pause_high)
           {
            chosen_pause_high = pause_high;
            chosen_pause_low = pause_low;
            long_breakout = true;
            break;
           }

         if(short_context && closes_below_fast && trigger_close < pause_low)
           {
            chosen_pause_high = pause_high;
            chosen_pause_low = pause_low;
            short_breakout = true;
            break;
           }
        }

      if(!long_breakout && !short_breakout)
         return;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return;

      QM_EntryRequest req;
      req.symbol_slot = 0;
      req.expiration_seconds = 0;

      if(long_breakout)
        {
         const double entry = ask;
         const double sl = chosen_pause_low - m_stop_atr_mult * h4_atr;
         const double stop_distance = entry - sl;
         if(stop_distance <= 0.0 || stop_distance > m_max_stop_atr_mult * h4_atr)
            return;
         if((ask - bid) > m_spread_stop_max_fraction * stop_distance)
            return;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(entry + m_target_r * stop_distance, _Digits);
         req.reason = "GRIMES_NESTED_PB_LONG";
        }
      else
        {
         const double entry = bid;
         const double sl = chosen_pause_high + m_stop_atr_mult * h4_atr;
         const double stop_distance = sl - entry;
         if(stop_distance <= 0.0 || stop_distance > m_max_stop_atr_mult * h4_atr)
            return;
         if((ask - bid) > m_spread_stop_max_fraction * stop_distance)
            return;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = NormalizeDouble(sl, _Digits);
         req.tp = NormalizeDouble(entry - m_target_r * stop_distance, _Digits);
         req.reason = "GRIMES_NESTED_PB_SHORT";
        }

      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket, (int)Magic(), m_risk_mode, m_risk_value);
     }
  };

#endif // QM_MOD_GRIMESNESTEDPBV2_MQH
