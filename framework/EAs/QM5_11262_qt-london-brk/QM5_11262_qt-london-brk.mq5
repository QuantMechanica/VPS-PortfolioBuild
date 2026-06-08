#property strict
#property version   "5.0"
#property description "QM5_11262 Quant-Trading London Breakout"

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
input int    qm_ea_id                   = 11262;
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
input int    strategy_preopen_start_hour    = 9;
input int    strategy_preopen_start_minute  = 0;
input int    strategy_preopen_minutes       = 60;
input int    strategy_entry_start_hour      = 10;
input int    strategy_entry_start_minute    = 0;
input int    strategy_entry_window_minutes  = 30;
input int    strategy_force_close_hour      = 19;
input int    strategy_force_close_minute    = 0;
input int    strategy_atr_period            = 14;
input double strategy_breakout_buffer_atr   = 0.0;
input double strategy_reject_atr_mult       = 1.0;
input double strategy_stop_tp_atr_mult      = 0.5;
input double strategy_max_spread_stop_frac  = 0.10;

int      g_session_key = 0;
bool     g_trade_attempted_session = false;
int      g_cached_range_key = 0;
double   g_cached_upper = 0.0;
double   g_cached_lower = 0.0;

int ClampMinuteOfDay(const int raw_minute)
  {
   int value = raw_minute % 1440;
   if(value < 0)
      value += 1440;
   return value;
  }

int MinuteOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool IsWeekday(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

bool TimeInWindow(const int minute, const int start_minute, const int length_minutes)
  {
   if(length_minutes <= 0)
      return false;

   const int start = ClampMinuteOfDay(start_minute);
   const int end = ClampMinuteOfDay(start + length_minutes);
   if(length_minutes >= 1440)
      return true;
   if(start < end)
      return (minute >= start && minute < end);
   return (minute >= start || minute < end);
  }

int PreopenStartMinute()
  {
   return ClampMinuteOfDay(strategy_preopen_start_hour * 60 + strategy_preopen_start_minute);
  }

int EntryStartMinute()
  {
   return ClampMinuteOfDay(strategy_entry_start_hour * 60 + strategy_entry_start_minute);
  }

int ForceCloseMinute()
  {
   return ClampMinuteOfDay(strategy_force_close_hour * 60 + strategy_force_close_minute);
  }

bool IsEntryWindow(const datetime broker_time)
  {
   return TimeInWindow(MinuteOfDay(broker_time), EntryStartMinute(), strategy_entry_window_minutes);
  }

bool IsForceCloseTime(const datetime broker_time)
  {
   const int minute = MinuteOfDay(broker_time);
   const int close_minute = ForceCloseMinute();
   return (minute >= close_minute);
  }

void RefreshSessionState(const datetime broker_time)
  {
   const int key = DateKey(broker_time);
   if(key != g_session_key)
     {
      g_session_key = key;
      g_trade_attempted_session = false;
      g_cached_range_key = 0;
      g_cached_upper = 0.0;
      g_cached_lower = 0.0;
     }
  }

bool HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool PlannedStopDistance(double &out_stop_distance)
  {
   out_stop_distance = 0.0;
   if(strategy_atr_period <= 0 || strategy_stop_tp_atr_mult <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   out_stop_distance = atr * strategy_stop_tp_atr_mult;
   return (out_stop_distance > 0.0);
  }

bool SpreadAllowed()
  {
   if(strategy_max_spread_stop_frac <= 0.0)
      return true;

   double stop_distance = 0.0;
   if(!PlannedStopDistance(stop_distance))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   return ((ask - bid) <= stop_distance * strategy_max_spread_stop_frac);
  }

bool BuildPreopenRange(const datetime broker_time, double &upper, double &lower)
  {
   upper = 0.0;
   lower = 0.0;

   RefreshSessionState(broker_time);
   if(g_cached_range_key == g_session_key && g_cached_upper > 0.0 && g_cached_lower > 0.0)
     {
      upper = g_cached_upper;
      lower = g_cached_lower;
      return true;
     }

   if(strategy_preopen_minutes <= 0)
      return false;

   const int date_key = DateKey(broker_time);
   const int preopen_start = PreopenStartMinute();
   int max_scan = strategy_preopen_minutes + strategy_entry_window_minutes + 30;
   if(max_scan < 90)
      max_scan = 90;
   if(max_scan > 300)
      max_scan = 300;
   int samples = 0;
   double hi = -DBL_MAX;
   double lo = DBL_MAX;

   for(int shift = 1; shift <= max_scan; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_M1, shift); // perf-allowed: bounded session-range scan inside QM_IsNewBar-gated entry hook.
      if(bar_time <= 0)
         continue;
      if(DateKey(bar_time) != date_key)
         continue;
      if(!TimeInWindow(MinuteOfDay(bar_time), preopen_start, strategy_preopen_minutes))
         continue;

      const double bar_high = iHigh(_Symbol, PERIOD_M1, shift); // perf-allowed: bespoke opening-range high.
      const double bar_low = iLow(_Symbol, PERIOD_M1, shift); // perf-allowed: bespoke opening-range low.
      if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high < bar_low)
         continue;

      hi = MathMax(hi, bar_high);
      lo = MathMin(lo, bar_low);
      samples++;
     }

   if(samples < strategy_preopen_minutes || hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   g_cached_range_key = g_session_key;
   g_cached_upper = hi;
   g_cached_lower = lo;
   upper = hi;
   lower = lo;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   RefreshSessionState(broker_now);

   if(HasOurPosition())
      return false;
   if(!IsWeekday(broker_now))
      return true;
   if(!IsEntryWindow(broker_now))
      return true;
   if(!SpreadAllowed())
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

   const datetime broker_now = TimeCurrent();
   RefreshSessionState(broker_now);

   if(g_trade_attempted_session || !IsWeekday(broker_now) || !IsEntryWindow(broker_now))
      return false;

   double upper = 0.0;
   double lower = 0.0;
   if(!BuildPreopenRange(broker_now, upper, lower))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M30, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_reject_atr_mult <= 0.0 || strategy_stop_tp_atr_mult <= 0.0)
      return false;

   const double breakout_buffer = atr * MathMax(0.0, strategy_breakout_buffer_atr);
   const double reject_distance = atr * strategy_reject_atr_mult;
   const double stop_distance = atr * strategy_stop_tp_atr_mult;
   if(reject_distance <= 0.0 || stop_distance <= 0.0)
      return false;

   const double last_close = iClose(_Symbol, PERIOD_M1, 1); // perf-allowed: closed M1 breakout test inside QM_IsNewBar-gated entry hook.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(last_close <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   if(last_close > upper + breakout_buffer)
     {
      const double entry = ask;
      if(MathAbs(entry - upper) > reject_distance)
         return false;
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_tp_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_tp_atr_mult);
      req.reason = "QT_LONDON_BRK_LONG";
      g_trade_attempted_session = true;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   if(last_close < lower - breakout_buffer)
     {
      const double entry = bid;
      if(MathAbs(entry - lower) > reject_distance)
         return false;
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_tp_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, entry, atr, strategy_stop_tp_atr_mult);
      req.reason = "QT_LONDON_BRK_SHORT";
      g_trade_attempted_session = true;
      return (req.sl > 0.0 && req.tp > 0.0);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even adjustment.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const datetime broker_now = TimeCurrent();
   RefreshSessionState(broker_now);
   return (HasOurPosition() && IsForceCloseTime(broker_now));
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!IsWeekday(broker_time))
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
