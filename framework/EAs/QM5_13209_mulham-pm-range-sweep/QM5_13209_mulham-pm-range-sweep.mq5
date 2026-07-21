#property strict
#property version   "5.0"
#property description "QM5_13209 Mulham PM-Range NY-Morning Sweep Reversal"

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
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 13209;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
// Backtest: RISK_FIXED is active and RISK_PERCENT stays 0.0.
// Full-live packaging: RISK_PERCENT=0.5 and RISK_FIXED=0.0.
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

// Card QM5_13209 (Mulham PM-Range NY-Morning Sweep Reversal): tp_mode variant
// selects between the primary opposite-PM-extreme target and a fixed-RR
// alternative for Q03 parameter sweeps.
enum StrategyTpMode
  {
   STRATEGY_TP_OPPOSITE_EXTREME = 0,
   STRATEGY_TP_FIXED_RR         = 1
  };

input group "Strategy"
// PM (prior-day reference) session window, broker time. Card: 20:30-23:00
// broker (13:30-16:00 ET).
input int    pm_start_hour          = 20;
input int    pm_start_min           = 30;
input int    pm_end_hour            = 23;
input int    pm_end_min             = 0;
// Skip the day if PM net move exceeds this fraction of the PM high-low range
// (card codification: "PM range not trending" filter).
input double pm_trend_max_frac      = 0.75;
// D1 bias gate: EMA(fast) vs EMA(slow), evaluated once per day on the prior
// closed D1 bar.
input int    ema_fast_period        = 9;
input int    ema_slow_period        = 18;
// Sweep / entry window, broker time. Card: 16:30-18:00 broker (9:30-11:00 ET).
input int    sweep_start_hour       = 16;
input int    sweep_start_min        = 30;
input int    sweep_end_hour         = 18;
input int    sweep_end_min          = 0;
// Displacement confirmation: reversal bar range >= displacement_atr_mult * ATR.
input int    atr_period             = 14;
input double displacement_atr_mult  = 1.5;
// Stop loss: sweep extreme +/- sl_buffer_atr_mult * ATR (harder invalidation).
input double sl_buffer_atr_mult     = 0.1;
// Skip the setup if reward-to-risk to the opposite-extreme target < rr_floor.
input double rr_floor               = 1.5;
// Cancel the unfilled FVG limit order at this broker hour.
input int    entry_cancel_hour      = 19;
// Time-flatten any open position at this broker hour (morning-resolution
// trade; holding past NY lunch is outside the taught pattern).
input int    flatten_hour           = 20;
input StrategyTpMode strategy_tp_mode = STRATEGY_TP_OPPOSITE_EXTREME;
input double tp_rr_multiple         = 2.5;
// Spread guard: .DWX quotes ask==bid (0 modeled spread) in the tester, so this
// only ever fires on a genuinely wide live/other-venue spread (never on zero).
input int    spread_cap_pips        = 50;

// -----------------------------------------------------------------------------
// Strategy state (file-scope; PM range persists across the day boundary since
// the morning setup reads the PRIOR day's PM range).
// -----------------------------------------------------------------------------
enum StrategySetupState
  {
   STRATEGY_SETUP_IDLE  = 0,
   STRATEGY_SETUP_SWEPT = 1   // sweep bar seen; wait for a post-sweep displacement + three-bar FVG
  };

int                g_bias             = 0;      // +1 bullish (long/low-side sweep) / -1 bearish (short/high-side sweep) / 0 none
bool               g_setup_done_today = false;   // one FVG-confirmed setup evaluation per day
StrategySetupState g_setup_state      = STRATEGY_SETUP_IDLE;
double             g_sweep_low        = 0.0;     // sweep bar low
double             g_sweep_high       = 0.0;     // sweep bar high
datetime           g_sweep_time       = 0;       // closed-bar time of the accepted sweep

bool   g_pm_recording  = false;   // true while inside the PM window
bool   g_pm_ready      = false;   // true once a PM range has been finalized at least once
bool   g_pm_valid      = false;   // false if the PM session was trending (card codification filter)
double g_pm_open       = 0.0;
double g_pm_last_close = 0.0;
double g_pm_high       = 0.0;
double g_pm_low        = 0.0;

// D1 EMA(fast) vs EMA(slow) direction on the prior closed daily bar (card's
// mechanical bias proxy, deliberate codification per card frontmatter).
int ComputeBias()
  {
   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return 0;
   if(ema_fast > ema_slow)
      return 1;
   if(ema_fast < ema_slow)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true; // no valid quote

   // .DWX invariant: never fail-closed on zero modeled spread (ask==bid in the
   // tester); only block a genuinely wide spread.
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, spread_cap_pips);
   if(spread_cap > 0.0 && ask > bid && (ask - bid) > spread_cap)
      return true;

   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read behind QM_IsNewBar() gate.
   if(bar_time <= 0)
      return false;

   // ---- Daily reset (bias + one-setup-per-day cap); PM range is NOT reset
   //      here — it must survive the day boundary for the next morning's
   //      sweep window. QM_IsNewCalendarPeriod is the tester-robust, D1-bar-
   //      anchored day-rollover gate (framework corset: no hand-rolled iTime
   //      calendar keys). Its native ~00:00-broker rollover falls inside the
   //      dead window between PM close (23:00) and the next sweep window
   //      (16:30), so it is functionally equivalent to the card's 07:00-broker
   //      "trading day" framing for this state machine.
   if(QM_IsNewCalendarPeriod(PERIOD_D1))
     {
      g_bias             = ComputeBias();
      g_setup_done_today = false;
      g_setup_state      = STRATEGY_SETUP_IDLE;
      g_sweep_low        = 0.0;
      g_sweep_high       = 0.0;
      g_sweep_time       = 0;
     }

   const double bar_open  = iOpen(_Symbol, _Period, 1);  // perf-allowed: PM-range/sweep structural logic, one closed bar per call.
   const double bar_high  = iHigh(_Symbol, _Period, 1);  // perf-allowed: see above.
   const double bar_low   = iLow(_Symbol, _Period, 1);   // perf-allowed: see above.
   const double bar_close = iClose(_Symbol, _Period, 1); // perf-allowed: see above.
   if(bar_open <= 0.0 || bar_high <= 0.0 || bar_low <= 0.0 || bar_close <= 0.0)
      return false;

   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int minute_of_day = dt.hour * 60 + dt.min;

   const int pm_start = pm_start_hour * 60 + pm_start_min;
   const int pm_end    = pm_end_hour * 60 + pm_end_min;

   // ---- PM range object: record prior day's 20:30-23:00 broker high/low ----
   if(minute_of_day >= pm_start && minute_of_day < pm_end)
     {
      if(!g_pm_recording)
        {
         g_pm_recording = true;
         g_pm_open      = bar_open;
         g_pm_high      = bar_high;
         g_pm_low       = bar_low;
        }
      else
        {
         g_pm_high = MathMax(g_pm_high, bar_high);
         g_pm_low  = MathMin(g_pm_low, bar_low);
        }
      g_pm_last_close = bar_close;
      return false; // no entries during the PM recording window
     }
   else if(g_pm_recording)
     {
      // PM window just closed: finalize the range and the trending-day filter.
      g_pm_recording = false;
      g_pm_ready      = true;
      const double pm_range    = g_pm_high - g_pm_low;
      const double pm_net_move = MathAbs(g_pm_last_close - g_pm_open);
      g_pm_valid = (pm_range > 0.0) && (pm_net_move <= pm_trend_max_frac * pm_range);
     }

   if(g_setup_done_today || !g_pm_ready || !g_pm_valid || g_bias == 0)
      return false;

   const int sweep_start = sweep_start_hour * 60 + sweep_start_min;
   const int sweep_end    = sweep_end_hour * 60 + sweep_end_min;
   const int cancel_min   = entry_cancel_hour * 60;

   if(minute_of_day >= cancel_min)
      return false;

   // ---- WAIT_DISPLACEMENT: inspect the latest fully formed three-bar FVG.
   //      Bars a/b/c are shifts 3/2/1; b is the post-sweep displacement bar
   //      and c confirms the imbalance. This is the standard gapless-CFD-safe
   //      FVG definition: bullish low[c] > high[a], bearish high[c] < low[a].
   //      The state remains armed until a qualifying pattern forms or the
   //      card's 19:00 cancellation boundary is reached. ----
   if(g_setup_state == STRATEGY_SETUP_SWEPT)
     {
      const datetime displacement_time = iTime(_Symbol, _Period, 2); // perf-allowed: fixed three-bar FVG read behind QM_IsNewBar().
      if(displacement_time <= g_sweep_time)
         return false;

      const double first_high = iHigh(_Symbol, _Period, 3);  // perf-allowed: standard three-bar FVG anchor.
      const double first_low  = iLow(_Symbol, _Period, 3);   // perf-allowed: standard three-bar FVG anchor.
      const double disp_high  = iHigh(_Symbol, _Period, 2);  // perf-allowed: post-sweep displacement range.
      const double disp_low   = iLow(_Symbol, _Period, 2);   // perf-allowed: post-sweep displacement range.
      const double disp_close = iClose(_Symbol, _Period, 2); // perf-allowed: close-through-sweep confirmation.
      const double atr_value  = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 2);
      if(first_high <= 0.0 || first_low <= 0.0 || disp_high <= 0.0 ||
         disp_low <= 0.0 || disp_close <= 0.0 || atr_value <= 0.0)
         return false;

      const double displacement_range = disp_high - disp_low;
      bool   displaced = false;
      double fvg_lower = 0.0;
      double fvg_upper = 0.0;

      if(g_bias > 0)
        {
         // Long: b closes back through the sweep bar's high and c leaves a
         // bullish FVG above a.
         if(disp_close > g_sweep_high &&
            displacement_range >= displacement_atr_mult * atr_value &&
            bar_low > first_high)
           {
            fvg_lower = first_high;
            fvg_upper = bar_low;
            displaced = true;
           }
        }
      else
        {
         // Short: b closes back through the sweep bar's low and c leaves a
         // bearish FVG below a.
         if(disp_close < g_sweep_low &&
            displacement_range >= displacement_atr_mult * atr_value &&
            bar_high < first_low)
           {
            fvg_lower = bar_high;
            fvg_upper = first_low;
            displaced = true;
           }
        }

      if(!displaced)
         return false;

      g_setup_done_today = true; // consume the day's one FVG-confirmed setup, including RR/geometry skips
      g_setup_state       = STRATEGY_SETUP_IDLE;

      const double entry_price = (fvg_upper + fvg_lower) / 2.0; // limit at 50% of the FVG
      const double sl_buffer   = sl_buffer_atr_mult * atr_value;

      QM_OrderType order_type;
      double sl_price;
      double tp_price;

      if(g_bias > 0)
        {
         order_type = QM_BUY_LIMIT;
         sl_price   = g_sweep_low - sl_buffer;
         tp_price   = (strategy_tp_mode == STRATEGY_TP_OPPOSITE_EXTREME)
                      ? g_pm_high
                      : QM_TakeRR(_Symbol, order_type, entry_price, sl_price, tp_rr_multiple);
        }
      else
        {
         order_type = QM_SELL_LIMIT;
         sl_price   = g_sweep_high + sl_buffer;
         tp_price   = (strategy_tp_mode == STRATEGY_TP_OPPOSITE_EXTREME)
                      ? g_pm_low
                      : QM_TakeRR(_Symbol, order_type, entry_price, sl_price, tp_rr_multiple);
        }

      const double primary_target = (g_bias > 0) ? g_pm_high : g_pm_low;
      const bool geometry_valid = (g_bias > 0)
                                  ? (sl_price < entry_price && primary_target > entry_price)
                                  : (sl_price > entry_price && primary_target < entry_price);
      if(entry_price <= 0.0 || sl_price <= 0.0 || tp_price <= 0.0 || !geometry_valid)
         return false;

      // RR floor is judged against the primary opposite-extreme target
      // regardless of tp_mode (card step 6): skip if there is not enough room.
      const double risk_dist   = MathAbs(entry_price - sl_price);
      const double target_dist = MathAbs(primary_target - entry_price);
      if(risk_dist <= 0.0 || target_dist < rr_floor * risk_dist)
         return false;

      MqlDateTime now_dt;
      TimeToStruct(TimeCurrent(), now_dt);
      const int now_minute        = now_dt.hour * 60 + now_dt.min;
      const int seconds_to_cancel = (cancel_min - now_minute) * 60 - now_dt.sec;
      if(seconds_to_cancel <= 0)
         return false;

      req.type               = order_type;
      req.price              = QM_StopRulesNormalizePrice(_Symbol, entry_price);
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl_price);
      req.tp                 = QM_StopRulesNormalizePrice(_Symbol, tp_price);
      req.reason             = (g_bias > 0) ? "MULHAM_PM_SWEEP_LONG" : "MULHAM_PM_SWEEP_SHORT";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = seconds_to_cancel;
      return true;
     }

   // ---- WAIT_SWEEP: only within the 16:30-18:00 broker sweep window ----
   if(minute_of_day < sweep_start || minute_of_day >= sweep_end)
      return false;

   if(g_bias > 0)
     {
      // Bullish bias: only low-side sweeps (v-shape fakeout below PM low,
      // closing back inside the PM range).
      if(bar_low < g_pm_low && bar_close >= g_pm_low)
        {
         g_sweep_low   = bar_low;
         g_sweep_high  = bar_high;
         g_sweep_time  = bar_time;
         g_setup_state = STRATEGY_SETUP_SWEPT;
        }
     }
   else
     {
      // Bearish bias: only high-side sweeps.
      if(bar_high > g_pm_high && bar_close <= g_pm_high)
        {
         g_sweep_low   = bar_low;
         g_sweep_high  = bar_high;
         g_sweep_time  = bar_time;
         g_setup_state = STRATEGY_SETUP_SWEPT;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card: hard structural SL/TP only, no trailing/break-even/partial-close
   // management. Time-based exit is handled in Strategy_ExitSignal.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Card: time flatten at 20:00 broker (13:00 ET) — morning-resolution trade,
   // holding past NY lunch is outside the taught pattern.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int minute_of_day = dt.hour * 60 + dt.min;
   return (minute_of_day >= flatten_hour * 60);
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
