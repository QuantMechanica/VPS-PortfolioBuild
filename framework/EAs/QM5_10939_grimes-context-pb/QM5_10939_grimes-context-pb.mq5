#property strict
#property version   "5.0"
#property description "QM5_10939 Grimes Contextual Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10939;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
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

double   g_qm10939_retrace_exit = 0.0;
int      g_qm10939_direction = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
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
      strategy_surprise_lookback <= 0 ||
      strategy_breakout_lookback <= 0 ||
      strategy_pullback_min_bars < 1 ||
      strategy_pullback_max_bars < strategy_pullback_min_bars ||
      strategy_trigger_lookback < 1)
      return false;

   const double d1_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_fast_ema, 1);
   const double d1_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_d1_slow_ema, 1);
   const double d1_adx = QM_ADX(_Symbol, PERIOD_D1, strategy_d1_adx_period, 1);
   const double h4_atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(d1_fast <= 0.0 || d1_slow <= 0.0 || d1_adx < strategy_d1_adx_min || h4_atr <= 0.0)
      return false;

   MqlRates d1_rates[];
   ArraySetAsSeries(d1_rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, d1_rates) != 1) // perf-allowed
      return false;
   const double d1_close = d1_rates[0].close;
   const bool long_context = (d1_close > d1_slow && d1_fast > d1_slow);
   const bool short_context = (d1_close < d1_slow && d1_fast < d1_slow);
   if(!long_context && !short_context)
      return false;

   const int history_bars = strategy_pullback_max_bars + strategy_surprise_lookback + strategy_breakout_lookback + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, history_bars, rates) < history_bars) // perf-allowed
      return false;

   const double close_trigger = rates[0].close;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_trigger <= 0.0 || ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   for(int pullback_bars = strategy_pullback_min_bars; pullback_bars <= strategy_pullback_max_bars; ++pullback_bars)
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
         const MqlRates bar = rates[shift - 1];
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
         const double ema20_h4 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_d1_fast_ema, shift);
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

      if(trigger_high <= 0.0 || trigger_low <= 0.0 || pullback_high <= 0.0 || pullback_low <= 0.0)
         continue;

      for(int leg_start_shift = leg_end_shift + 1; leg_start_shift <= leg_end_shift + strategy_surprise_lookback; ++leg_start_shift)
        {
         double leg_high = -DBL_MAX;
         double leg_low = DBL_MAX;
         double largest_leg_bar = 0.0;
         for(int shift = leg_end_shift; shift <= leg_start_shift; ++shift)
           {
            const MqlRates leg_bar = rates[shift - 1];
            leg_high = MathMax(leg_high, leg_bar.high);
            leg_low = MathMin(leg_low, leg_bar.low);
            largest_leg_bar = MathMax(largest_leg_bar, leg_bar.high - leg_bar.low);
           }
         if(leg_high <= 0.0 || leg_low <= 0.0 || leg_high <= leg_low)
            continue;
         if(largest_leg_bar > strategy_climax_bar_atr_mult * h4_atr)
            continue;

         double prior_high = -DBL_MAX;
         double prior_low = DBL_MAX;
         for(int shift = leg_end_shift + 1; shift <= leg_end_shift + strategy_breakout_lookback; ++shift)
           {
            prior_high = MathMax(prior_high, rates[shift - 1].high);
            prior_low = MathMin(prior_low, rates[shift - 1].low);
           }

         const double leg_size = leg_high - leg_low;
         const MqlRates leg_end = rates[leg_end_shift - 1];
         if(long_context && pullback_long_quality)
           {
            if(leg_end.close <= prior_high)
               continue;
            if(leg_end.close - leg_low < strategy_surprise_atr_mult * h4_atr)
               continue;
            const double retrace_pct = 100.0 * (leg_high - pullback_low) / leg_size;
            if(retrace_pct < strategy_pullback_min_pct || retrace_pct > strategy_pullback_max_pct)
               continue;
            if(close_trigger <= trigger_high)
               continue;

            const double entry = ask;
            const double stop = pullback_low - strategy_stop_atr_buffer * h4_atr;
            const double risk = entry - stop;
            if(risk <= 0.0 || risk > strategy_max_stop_atr_mult * h4_atr)
               continue;
            const double spread = ask - bid;
            if(spread > strategy_spread_stop_max_pct * 0.01 * risk)
               continue;

            req.type = QM_BUY;
            req.price = 0.0;
            req.sl = NormalizeDouble(stop, _Digits);
            req.tp = NormalizeDouble(entry + strategy_target_r_mult * risk, _Digits);
            req.reason = "GRIMES_CONTEXT_PB_LONG";
            g_qm10939_retrace_exit = NormalizeDouble(leg_high - 0.618 * leg_size, _Digits);
            g_qm10939_direction = 1;
            return true;
           }

         if(short_context && pullback_short_quality)
           {
            if(leg_end.close >= prior_low)
               continue;
            if(leg_high - leg_end.close < strategy_surprise_atr_mult * h4_atr)
               continue;
            const double retrace_pct = 100.0 * (pullback_high - leg_low) / leg_size;
            if(retrace_pct < strategy_pullback_min_pct || retrace_pct > strategy_pullback_max_pct)
               continue;
            if(close_trigger >= trigger_low)
               continue;

            const double entry = bid;
            const double stop = pullback_high + strategy_stop_atr_buffer * h4_atr;
            const double risk = stop - entry;
            if(risk <= 0.0 || risk > strategy_max_stop_atr_mult * h4_atr)
               continue;
            const double spread = ask - bid;
            if(spread > strategy_spread_stop_max_pct * 0.01 * risk)
               continue;

            req.type = QM_SELL;
            req.price = 0.0;
            req.sl = NormalizeDouble(stop, _Digits);
            req.tp = NormalizeDouble(entry - strategy_target_r_mult * risk, _Digits);
            req.reason = "GRIMES_CONTEXT_PB_SHORT";
            g_qm10939_retrace_exit = NormalizeDouble(leg_low + 0.618 * leg_size, _Digits);
            g_qm10939_direction = -1;
            return true;
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(open_price <= 0.0 || current_sl <= 0.0 || point <= 0.0)
         continue;

      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double risk = MathAbs(open_price - current_sl);
      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(risk <= 0.0 || moved < strategy_breakeven_r_mult * risk)
         continue;

      const double be_sl = NormalizeDouble(open_price, _Digits);
      const bool improves = is_buy ? (be_sl > current_sl + point * 0.5)
                                   : (be_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, be_sl, "GRIMES_CONTEXT_PB_BE_1R");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
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
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      has_position = true;
      break;
     }

   if(!has_position)
      return false;

   const int bar_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(bar_seconds > 0 && open_time > 0 && TimeCurrent() - open_time >= strategy_time_exit_h4_bars * bar_seconds)
      return true;

   if(!QM_IsNewBar())
      return false;

   if(g_qm10939_retrace_exit <= 0.0)
      return false;

   MqlRates last_bar[];
   ArraySetAsSeries(last_bar, true);
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, last_bar) != 1) // perf-allowed
      return false;

   const int active_direction = (g_qm10939_direction != 0) ? g_qm10939_direction : direction;
   if(active_direction > 0 && last_bar[0].close < g_qm10939_retrace_exit)
      return true;
   if(active_direction < 0 && last_bar[0].close > g_qm10939_retrace_exit)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
      return true;
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
