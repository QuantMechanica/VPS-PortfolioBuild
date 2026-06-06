#property strict
#property version   "5.0"
#property description "QM5_10917 Grimes Free Bar Pullback Continuation"

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
input int    qm_ea_id                   = 10917;
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
input int    strategy_keltner_period          = 20;
input double strategy_keltner_atr_mult        = 2.25;
input int    strategy_freebar_lookback_bars   = 10;
input int    strategy_pullback_min_bars       = 2;
input int    strategy_pullback_max_bars       = 8;
input int    strategy_climax_window_bars      = 12;
input int    strategy_max_freebars_same_dir   = 3;
input double strategy_stop_buffer_atr_mult    = 0.25;
input double strategy_max_stop_atr_mult       = 3.00;
input double strategy_target_r_mult           = 1.50;
input double strategy_trail_start_r_mult      = 1.00;
input double strategy_trail_atr_mult          = 2.00;
input double strategy_spread_stop_frac        = 0.10;
input int    strategy_max_hold_bars           = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_keltner_period < 2 ||
      strategy_freebar_lookback_bars < 1 ||
      strategy_pullback_min_bars < 1 ||
      strategy_pullback_max_bars < strategy_pullback_min_bars ||
      strategy_keltner_atr_mult <= 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_target_r_mult <= 0.0 ||
      strategy_trail_start_r_mult <= 0.0 ||
      strategy_trail_atr_mult <= 0.0 ||
      strategy_spread_stop_frac <= 0.0)
      return true;

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

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const int need_by_climax = strategy_climax_window_bars + 2;
   const int need_by_freebar = strategy_freebar_lookback_bars + 4;
   const int need_bars = (need_by_climax > need_by_freebar) ? need_by_climax : need_by_freebar;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for free-bar and consolidation sequence.
   if(copied < need_bars)
      return false;

   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, 1);
   if(atr1 <= 0.0)
      return false;

   int freebar_up_count = 0;
   int freebar_down_count = 0;
   for(int s = 1; s <= strategy_climax_window_bars && s < copied; ++s)
     {
      const double ema_s = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, s);
      const double atr_s = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, s);
      if(ema_s <= 0.0 || atr_s <= 0.0)
         continue;
      const double upper_s = ema_s + strategy_keltner_atr_mult * atr_s;
      const double lower_s = ema_s - strategy_keltner_atr_mult * atr_s;
      if(rates[s].low > upper_s)
         ++freebar_up_count;
      if(rates[s].high < lower_s)
         ++freebar_down_count;
     }

   const bool allow_long = (freebar_up_count <= strategy_max_freebars_same_dir);
   const bool allow_short = (freebar_down_count <= strategy_max_freebars_same_dir);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   if(allow_long)
     {
      const int first_shift = strategy_pullback_min_bars + 2;
      const int max_pullback_shift = strategy_pullback_max_bars + 2;
      const int last_shift = (strategy_freebar_lookback_bars < max_pullback_shift)
                             ? strategy_freebar_lookback_bars : max_pullback_shift;
      for(int free_shift = first_shift; free_shift <= last_shift && free_shift < copied; ++free_shift)
        {
         const int pullback_bars = free_shift - 2;
         if(pullback_bars < strategy_pullback_min_bars ||
            pullback_bars > strategy_pullback_max_bars)
            continue;

         const double ema_free = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, free_shift);
         const double atr_free = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, free_shift);
         if(ema_free <= 0.0 || atr_free <= 0.0)
            continue;
         if(rates[free_shift].low <= ema_free + strategy_keltner_atr_mult * atr_free)
            continue;

         bool holds_above_ema = true;
         double cons_high = -DBL_MAX;
         double cons_low = DBL_MAX;
         for(int c = free_shift - 1; c >= 2; --c)
           {
            const double ema_c = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, c);
            if(ema_c <= 0.0 || rates[c].close < ema_c)
              {
               holds_above_ema = false;
               break;
              }
            cons_high = MathMax(cons_high, rates[c].high);
            cons_low = MathMin(cons_low, rates[c].low);
           }
         if(!holds_above_ema || cons_high <= -DBL_MAX || cons_low >= DBL_MAX)
            continue;
         if(rates[1].close <= cons_high)
            continue;

         const double sl = QM_StopRulesNormalizePrice(_Symbol, cons_low - strategy_stop_buffer_atr_mult * atr1);
         const double stop_distance = ask - sl;
         if(sl <= 0.0 || stop_distance <= 0.0)
            continue;
         if(stop_distance > strategy_max_stop_atr_mult * atr1)
            continue;
         if((ask - bid) > strategy_spread_stop_frac * stop_distance)
            continue;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = QM_TakeRR(_Symbol, QM_BUY, ask, sl, strategy_target_r_mult);
         req.reason = "GRIMES_FREEBAR_LONG";
         return (req.tp > 0.0);
        }
     }

   if(allow_short)
     {
      const int first_shift = strategy_pullback_min_bars + 2;
      const int max_pullback_shift = strategy_pullback_max_bars + 2;
      const int last_shift = (strategy_freebar_lookback_bars < max_pullback_shift)
                             ? strategy_freebar_lookback_bars : max_pullback_shift;
      for(int free_shift = first_shift; free_shift <= last_shift && free_shift < copied; ++free_shift)
        {
         const int pullback_bars = free_shift - 2;
         if(pullback_bars < strategy_pullback_min_bars ||
            pullback_bars > strategy_pullback_max_bars)
            continue;

         const double ema_free = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, free_shift);
         const double atr_free = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, free_shift);
         if(ema_free <= 0.0 || atr_free <= 0.0)
            continue;
         if(rates[free_shift].high >= ema_free - strategy_keltner_atr_mult * atr_free)
            continue;

         bool holds_below_ema = true;
         double cons_high = -DBL_MAX;
         double cons_low = DBL_MAX;
         for(int c = free_shift - 1; c >= 2; --c)
           {
            const double ema_c = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_keltner_period, c);
            if(ema_c <= 0.0 || rates[c].close > ema_c)
              {
               holds_below_ema = false;
               break;
              }
            cons_high = MathMax(cons_high, rates[c].high);
            cons_low = MathMin(cons_low, rates[c].low);
           }
         if(!holds_below_ema || cons_high <= -DBL_MAX || cons_low >= DBL_MAX)
            continue;
         if(rates[1].close >= cons_low)
            continue;

         const double sl = QM_StopRulesNormalizePrice(_Symbol, cons_high + strategy_stop_buffer_atr_mult * atr1);
         const double stop_distance = sl - bid;
         if(sl <= 0.0 || stop_distance <= 0.0)
            continue;
         if(stop_distance > strategy_max_stop_atr_mult * atr1)
            continue;
         if((ask - bid) > strategy_spread_stop_frac * stop_distance)
            continue;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = QM_TakeRR(_Symbol, QM_SELL, bid, sl, strategy_target_r_mult);
         req.reason = "GRIMES_FREEBAR_SHORT";
         return (req.tp > 0.0);
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || current_tp <= 0.0 || market <= 0.0)
         continue;

      const double initial_r = MathAbs(current_tp - open_price) / strategy_target_r_mult;
      if(initial_r <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved >= strategy_trail_start_r_mult * initial_r)
         QM_TM_TrailATR(ticket, strategy_keltner_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_max_hold_bars <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(magic <= 0 || period_seconds <= 0)
      return false;

   for(int pos = PositionsTotal() - 1; pos >= 0; --pos)
     {
      const ulong ticket = PositionGetTicket(pos);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_max_hold_bars * period_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
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
