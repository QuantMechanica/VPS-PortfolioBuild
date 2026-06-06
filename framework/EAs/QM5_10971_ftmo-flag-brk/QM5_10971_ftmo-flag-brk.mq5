#property strict
#property version   "5.0"
#property description "QM5_10971 FTMO Flag/Pennant Breakout"

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
input int    qm_ea_id                   = 10971;
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
input int    strategy_atr_period              = 14;
input int    strategy_ema_period              = 100;
input int    strategy_min_pole_bars           = 3;
input int    strategy_max_pole_bars           = 10;
input int    strategy_min_consolidation_bars  = 4;
input int    strategy_max_consolidation_bars  = 16;
input double strategy_min_pole_atr_mult       = 2.0;
input double strategy_min_retrace_pct         = 20.0;
input double strategy_max_retrace_pct         = 60.0;
input double strategy_max_cons_range_pole_pct = 75.0;
input double strategy_sl_atr_buffer           = 0.25;
input double strategy_breakout_max_atr_mult   = 2.0;
input double strategy_tp_rr_fallback          = 2.2;
input double strategy_tp_rr_cap               = 3.0;
input int    strategy_time_exit_bars          = 24;

double Strategy_AverageRange(const MqlRates &bars[], const int first, const int count)
  {
   if(first < 0 || count <= 0 || first + count > ArraySize(bars))
      return 0.0;

   double sum = 0.0;
   int samples = 0;
   for(int i = first; i < first + count; ++i)
     {
      const double range = bars[i].high - bars[i].low;
      if(range <= 0.0)
         continue;
      sum += range;
      samples++;
     }

   return (samples > 0) ? (sum / samples) : 0.0;
  }

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

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

bool Strategy_ConsolidationShapeOK(const MqlRates &bars[],
                                   const int first,
                                   const int count,
                                   const bool bullish)
  {
   if(count < 4 || first < 0 || first + count > ArraySize(bars))
      return false;

   const int half = count / 2;
   const double recent_avg_range = Strategy_AverageRange(bars, first, half);
   const double older_avg_range = Strategy_AverageRange(bars, first + count - half, half);
   const bool narrows = (recent_avg_range > 0.0 && older_avg_range > 0.0 &&
                         recent_avg_range <= older_avg_range);

   const double recent_mid = (bars[first].high + bars[first].low) * 0.5;
   const double older_mid = (bars[first + count - 1].high + bars[first + count - 1].low) * 0.5;
   const bool mild_counter_slope = bullish ? (recent_mid <= older_mid)
                                           : (recent_mid >= older_mid);

   return (narrows || mild_counter_slope);
  }

bool Strategy_BuildFlagRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_atr_period <= 0 || strategy_ema_period <= 0 ||
      strategy_min_pole_bars < 1 || strategy_max_pole_bars < strategy_min_pole_bars ||
      strategy_min_consolidation_bars < 1 ||
      strategy_max_consolidation_bars < strategy_min_consolidation_bars)
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   const int max_needed = 1 + strategy_max_consolidation_bars + strategy_max_pole_bars + 1;
   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   // perf-allowed: bounded flag/pennant OHLC structure; called only after the skeleton QM_IsNewBar gate.
   if(CopyRates(_Symbol, PERIOD_H1, 1, max_needed, bars) < max_needed) // perf-allowed
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double ema = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   if(atr <= 0.0 || ema <= 0.0)
      return false;

   const double breakout_close = bars[0].close;
   const double breakout_range = bars[0].high - bars[0].low;
   if(breakout_close <= 0.0 || breakout_range <= 0.0 ||
      breakout_range > strategy_breakout_max_atr_mult * atr)
      return false;

   for(int cons_len = strategy_min_consolidation_bars;
       cons_len <= strategy_max_consolidation_bars;
       ++cons_len)
     {
      double cons_high = -DBL_MAX;
      double cons_low = DBL_MAX;
      for(int i = 1; i <= cons_len; ++i)
        {
         cons_high = MathMax(cons_high, bars[i].high);
         cons_low = MathMin(cons_low, bars[i].low);
        }
      if(cons_high <= cons_low)
         continue;

      const double cons_range = cons_high - cons_low;
      for(int pole_len = strategy_min_pole_bars;
          pole_len <= strategy_max_pole_bars;
          ++pole_len)
        {
         const int pole_recent = cons_len + 1;
         const int pole_old = cons_len + pole_len;
         if(pole_old >= ArraySize(bars))
            continue;

         const double pole_start = bars[pole_old].close;
         const double pole_end = bars[pole_recent].close;
         if(pole_start <= 0.0 || pole_end <= 0.0)
            continue;

         const double bull_pole = pole_end - pole_start;
         if(bull_pole >= strategy_min_pole_atr_mult * atr && breakout_close > ema)
           {
            const double retrace_pct = 100.0 * (pole_end - cons_low) / bull_pole;
            if(retrace_pct < strategy_min_retrace_pct || retrace_pct > strategy_max_retrace_pct)
               continue;
            if(cons_range > (strategy_max_cons_range_pole_pct / 100.0) * bull_pole)
               continue;
            if(!Strategy_ConsolidationShapeOK(bars, 1, cons_len, true))
               continue;
            if(breakout_close <= cons_high)
               continue;

            req.type = QM_BUY;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, cons_low - strategy_sl_atr_buffer * atr);
            const double entry_ref = breakout_close;
            const double risk = entry_ref - req.sl;
            if(req.sl <= 0.0 || risk <= 0.0)
               continue;

            double target_distance = bull_pole;
            if(target_distance <= 0.0)
               target_distance = strategy_tp_rr_fallback * risk;
            target_distance = MathMin(target_distance, strategy_tp_rr_cap * risk);
            req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_ref + target_distance);
            req.reason = "FTMO_FLAG_BRK_LONG";
            return (req.tp > entry_ref);
           }

         const double bear_pole = pole_start - pole_end;
         if(bear_pole >= strategy_min_pole_atr_mult * atr && breakout_close < ema)
           {
            const double retrace_pct = 100.0 * (cons_high - pole_end) / bear_pole;
            if(retrace_pct < strategy_min_retrace_pct || retrace_pct > strategy_max_retrace_pct)
               continue;
            if(cons_range > (strategy_max_cons_range_pole_pct / 100.0) * bear_pole)
               continue;
            if(!Strategy_ConsolidationShapeOK(bars, 1, cons_len, false))
               continue;
            if(breakout_close >= cons_low)
               continue;

            req.type = QM_SELL;
            req.sl = QM_StopRulesNormalizePrice(_Symbol, cons_high + strategy_sl_atr_buffer * atr);
            const double entry_ref = breakout_close;
            const double risk = req.sl - entry_ref;
            if(req.sl <= 0.0 || risk <= 0.0)
               continue;

            double target_distance = bear_pole;
            if(target_distance <= 0.0)
               target_distance = strategy_tp_rr_fallback * risk;
            target_distance = MathMin(target_distance, strategy_tp_rr_cap * risk);
            req.tp = QM_StopRulesNormalizePrice(_Symbol, entry_ref - target_distance);
            req.reason = "FTMO_FLAG_BRK_SHORT";
            return (req.tp > 0.0 && req.tp < entry_ref);
           }
        }
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card no-trade filters are enforced by framework news/Friday gates and by
   // the entry hook's one-position-per-symbol/magic guard.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return Strategy_BuildFlagRequest(req);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double initial_r = MathAbs(open_price - current_sl);
      const double favorable = is_buy ? (market - open_price)
                                      : (open_price - market);
      if(initial_r <= 0.0 || favorable < initial_r)
         continue;

      const bool improves = is_buy ? (open_price > current_sl + point * 0.5)
                                   : (open_price < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, open_price, "ftmo_flag_break_even_1r");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int hold_seconds = MathMax(1, strategy_time_exit_bars) * PeriodSeconds(PERIOD_H1);
   if(hold_seconds <= 0)
      return false;

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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened > 0 && now - opened >= hold_seconds)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // High-impact news avoidance is handled by the framework news inputs.
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
