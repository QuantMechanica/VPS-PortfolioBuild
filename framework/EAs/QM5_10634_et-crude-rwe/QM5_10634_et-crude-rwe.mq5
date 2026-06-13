#property strict
#property version   "5.0"
#property description "QM5_10634 Elite Trader crude rally-wait-enter momentum"

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
input int    qm_ea_id                   = 10634;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input double strategy_momentum_threshold_pct = 0.35;
input int    strategy_event_window_minutes   = 20;
input int    strategy_wait_minutes           = 10;
input int    strategy_rebreak_deadline_min   = 60;
input int    strategy_atr_period             = 14;
input double strategy_sl_atr_buffer          = 0.20;
input double strategy_spike_atr_mult         = 3.00;
input double strategy_tp_rr                  = 1.20;
input int    strategy_max_hold_bars          = 12;
input int    strategy_session_start_hour     = 1;
input int    strategy_session_end_hour       = 21;
input int    strategy_friday_no_entry_hour   = 19;

int      g_setup_direction  = 0;
double   g_setup_low        = 0.0;
double   g_setup_high       = 0.0;
datetime g_setup_event_time = 0;

void ClearSetupCache()
  {
   g_setup_direction = 0;
   g_setup_low = 0.0;
   g_setup_high = 0.0;
   g_setup_event_time = 0;
  }

bool HasOurPosition(ulong &ticket,
                    ENUM_POSITION_TYPE &position_type,
                    datetime &position_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      position_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool IsInsideSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);

   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_no_entry_hour)
      return false;

   if(strategy_session_start_hour == strategy_session_end_hour)
      return true;
   if(strategy_session_start_hour < strategy_session_end_hour)
      return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
   return (dt.hour >= strategy_session_start_hour || dt.hour < strategy_session_end_hour);
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

int CeilBars(const int minutes, const int period_seconds)
  {
   if(minutes <= 0 || period_seconds <= 0)
      return 1;
   const double seconds = (double)minutes * 60.0;
   return (int)MathMax(1.0, MathCeil(seconds / (double)period_seconds));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M5)
      return true;
   return !IsInsideSession(TimeCurrent());
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   ulong pos_ticket;
   ENUM_POSITION_TYPE pos_type;
   datetime pos_time;
   if(HasOurPosition(pos_ticket, pos_type, pos_time))
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
      return false;

   const int event_bars = CeilBars(strategy_event_window_minutes, period_seconds);
   const int wait_bars = CeilBars(strategy_wait_minutes, period_seconds);
   const int deadline_bars = CeilBars(strategy_rebreak_deadline_min, period_seconds);
   if(event_bars <= 0 || wait_bars <= 0 || deadline_bars <= wait_bars)
      return false;

   const int bars_needed = deadline_bars + event_bars + 3;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, bars_needed, rates); // perf-allowed: bounded closed-bar event window inside framework QM_IsNewBar gate
   if(copied < bars_needed)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double threshold = strategy_momentum_threshold_pct / 100.0;
   const int min_event_shift = wait_bars + 1;
   const int max_event_shift = (int)MathMin((double)deadline_bars, (double)(copied - event_bars - 1));

   for(int shift = min_event_shift; shift <= max_event_shift; ++shift)
     {
      double window_low = DBL_MAX;
      double window_high = -DBL_MAX;
      for(int j = shift; j < shift + event_bars; ++j)
        {
         window_low = MathMin(window_low, rates[j].low);
         window_high = MathMax(window_high, rates[j].high);
        }

      if(window_low <= 0.0 || window_high <= 0.0 || window_high <= window_low)
         continue;

      const double event_range = window_high - window_low;
      if(event_range > strategy_spike_atr_mult * atr)
         continue;

      bool later_long_rebreak = false;
      bool later_short_rebreak = false;
      for(int newer = 2; newer < shift; ++newer)
        {
         if(rates[newer].high > window_high)
            later_long_rebreak = true;
         if(rates[newer].low < window_low)
            later_short_rebreak = true;
        }

      const bool long_event = (rates[shift].high >= window_high &&
                               ((window_high - window_low) / window_low) >= threshold &&
                               !later_long_rebreak &&
                               rates[1].high > window_high);
      const bool short_event = (rates[shift].low <= window_low &&
                                ((window_high - window_low) / window_high) >= threshold &&
                                !later_short_rebreak &&
                                rates[1].low < window_low);

      if(!long_event && !short_event)
         continue;

      const double entry = long_event ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      req.type = long_event ? QM_BUY : QM_SELL;
      req.price = 0.0;
      req.sl = long_event ? (window_low - strategy_sl_atr_buffer * atr)
                          : (window_high + strategy_sl_atr_buffer * atr);
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
      req.reason = long_event ? "ET_RWE_LONG_REBREAK" : "ET_RWE_SHORT_REBREAK";

      if(req.sl <= 0.0 || req.tp <= 0.0)
         return false;
      if(long_event && req.sl >= entry)
         return false;
      if(short_event && req.sl <= entry)
         return false;

      g_setup_direction = long_event ? 1 : -1;
      g_setup_low = window_low;
      g_setup_high = window_high;
      g_setup_event_time = rates[shift].time;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus discretionary range/time exits only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket;
   ENUM_POSITION_TYPE pos_type;
   datetime pos_time;
   if(!HasOurPosition(ticket, pos_type, pos_time))
     {
      ClearSetupCache();
      return false;
     }

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds > 0 && pos_time > 0)
     {
      const int max_hold_seconds = strategy_max_hold_bars * period_seconds;
      if(max_hold_seconds > 0 && TimeCurrent() - pos_time >= max_hold_seconds)
         return true;
     }

   if(g_setup_direction == 0 || g_setup_low <= 0.0 || g_setup_high <= g_setup_low)
      return false;

   const double last_close = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: closed-bar range-return exit from card
   if(last_close <= 0.0)
      return false;

   if(pos_type == POSITION_TYPE_BUY && g_setup_direction == 1)
      return (last_close >= g_setup_low && last_close <= g_setup_high);
   if(pos_type == POSITION_TYPE_SELL && g_setup_direction == -1)
      return (last_close >= g_setup_low && last_close <= g_setup_high);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10634_et-crude-rwe\"}");
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
