#property strict
#property version   "5.0"
#property description "QM5_10727 TradingView D.Y Volume Push Reversal v2"

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
input int    qm_ea_id                   = 10727;
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
input int    strategy_session_open_hour      = 16;
input int    strategy_session_open_minute    = 30;
input int    strategy_session_close_hour     = 22;
input int    strategy_session_close_minute   = 55;
input int    strategy_sample_minutes         = 5;
input double strategy_entry_window_hours     = 2.0;
input double strategy_volume_threshold_pct   = 75.0;
input int    strategy_max_trades_per_day     = 2;
input int    strategy_atr_period             = 14;
input double strategy_min_stop_atr           = 0.3;
input double strategy_max_stop_atr           = 3.0;
input double strategy_rr                     = 2.0;
input int    strategy_stop_buffer_points     = 1;
input int    strategy_max_spread_points      = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }

   if(has_position)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(strategy_max_spread_points > 0 && point > 0.0 && ask > bid)
     {
      const double spread_points = (ask - bid) / point;
      if(spread_points > strategy_max_spread_points)
         return true;
     }

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_s = now_dt.hour * 3600 + now_dt.min * 60 + now_dt.sec;
   const int open_s = strategy_session_open_hour * 3600 + strategy_session_open_minute * 60;
   const int sample_minutes_filter = (strategy_sample_minutes > 1) ? strategy_sample_minutes : 1;
   const double entry_hours_filter = (strategy_entry_window_hours > 0.1) ? strategy_entry_window_hours : 0.1;
   const int sample_end_s = open_s + sample_minutes_filter * 60;
   const int entry_end_s = sample_end_s + (int)MathRound(entry_hours_filter * 3600.0);

   if(now_s < open_s || now_s >= entry_end_s)
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

   static int    state_day_key = 0;
   static double state_or_high = 0.0;
   static double state_or_low = 0.0;
   static double state_opening_volume_peak = 0.0;
   static double state_post_sample_low = 0.0;
   static double state_post_sample_high = 0.0;
   static bool   state_sample_started = false;
   static bool   state_sample_complete = false;
   static int    state_first_break_dir = 0;
   static int    state_trades_today = 0;

   MqlRates bar[1];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, bar) != 1) // perf-allowed: EntrySignal is called only after QM_IsNewBar; ORB needs one closed OHLCV bar.
      return false;

   MqlDateTime bar_dt;
   TimeToStruct(bar[0].time, bar_dt);
   const int day_key = bar_dt.year * 10000 + bar_dt.mon * 100 + bar_dt.day;
   if(day_key != state_day_key)
     {
      state_day_key = day_key;
      state_or_high = 0.0;
      state_or_low = 0.0;
      state_opening_volume_peak = 0.0;
      state_post_sample_low = 0.0;
      state_post_sample_high = 0.0;
      state_sample_started = false;
      state_sample_complete = false;
      state_first_break_dir = 0;
      state_trades_today = 0;
     }

   const int bar_s = bar_dt.hour * 3600 + bar_dt.min * 60 + bar_dt.sec;
   const int open_s = strategy_session_open_hour * 3600 + strategy_session_open_minute * 60;
   const int close_s = strategy_session_close_hour * 3600 + strategy_session_close_minute * 60;
   const int sample_minutes = (strategy_sample_minutes > 1) ? strategy_sample_minutes : 1;
   const double entry_hours = (strategy_entry_window_hours > 0.1) ? strategy_entry_window_hours : 0.1;
   const int sample_end_s = open_s + sample_minutes * 60;
   const int entry_end_s = sample_end_s + (int)MathRound(entry_hours * 3600.0);

   if(bar_s < open_s || bar_s >= close_s)
      return false;

   if(bar_s >= open_s && bar_s < sample_end_s)
     {
      if(!state_sample_started)
        {
         state_or_high = bar[0].high;
         state_or_low = bar[0].low;
         state_opening_volume_peak = (double)bar[0].tick_volume;
         state_sample_started = true;
        }
      else
        {
         state_or_high = MathMax(state_or_high, bar[0].high);
         state_or_low = MathMin(state_or_low, bar[0].low);
         state_opening_volume_peak = MathMax(state_opening_volume_peak, (double)bar[0].tick_volume);
        }
      return false;
     }

   if(!state_sample_started || state_or_high <= 0.0 || state_or_low <= 0.0 || state_opening_volume_peak <= 0.0)
      return false;

   if(!state_sample_complete)
     {
      state_post_sample_low = bar[0].low;
      state_post_sample_high = bar[0].high;
      state_sample_complete = true;
     }
   else
     {
      state_post_sample_low = MathMin(state_post_sample_low, bar[0].low);
      state_post_sample_high = MathMax(state_post_sample_high, bar[0].high);
     }

   if(bar_s < sample_end_s || bar_s >= entry_end_s)
      return false;

   const int max_trades = (strategy_max_trades_per_day > 1) ? strategy_max_trades_per_day : 1;
   if(state_trades_today >= max_trades)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double volume_threshold_pct = (strategy_volume_threshold_pct > 1.0) ? strategy_volume_threshold_pct : 1.0;
   const double required_volume = state_opening_volume_peak * volume_threshold_pct / 100.0;
   if((double)bar[0].tick_volume < required_volume)
      return false;

   int signal_dir = 0;
   if(bar[0].close > state_or_high && state_first_break_dir <= 0)
      signal_dir = 1;
   else if(bar[0].close < state_or_low && state_first_break_dir >= 0)
      signal_dir = -1;

   if(signal_dir == 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (signal_dir > 0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int buffer_points = (strategy_stop_buffer_points > 0) ? strategy_stop_buffer_points : 0;
   const double buffer = (double)buffer_points * point;
   double sl = 0.0;
   if(signal_dir > 0)
      sl = MathMin(state_or_low, state_post_sample_low) - buffer;
   else
      sl = MathMax(state_or_high, state_post_sample_high) + buffer;

   const double stop_distance = MathAbs(entry - sl);
   if(stop_distance < strategy_min_stop_atr * atr || stop_distance > strategy_max_stop_atr * atr)
      return false;

   const double sl_points = stop_distance / point;
   if(QM_LotsForRisk(_Symbol, sl_points) <= 0.0)
      return false;

   req.type = (signal_dir > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   req.tp = NormalizeDouble(QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr),
                            (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
   if(req.tp <= 0.0)
      return false;

   req.reason = (state_first_break_dir == 0)
                ? ((signal_dir > 0) ? "DY_VOL_PUSH_LONG_INITIAL" : "DY_VOL_PUSH_SHORT_INITIAL")
                : ((signal_dir > 0) ? "DY_VOL_PUSH_LONG_REVERSAL" : "DY_VOL_PUSH_SHORT_REVERSAL");
   state_first_break_dir = signal_dir;
   state_trades_today++;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, partial close, trailing stop, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_s = now_dt.hour * 3600 + now_dt.min * 60 + now_dt.sec;
   const int close_s = strategy_session_close_hour * 3600 + strategy_session_close_minute * 60;
   if(now_s >= close_s)
      return true;

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
