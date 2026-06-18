#property strict
#property version   "5.0"
#property description "QM5_11378 big-ben-london-fade-m5 — Asia body-range pre-London spike fade (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11378 big-ben-london-fade-m5
// -----------------------------------------------------------------------------
// Source: "Big Ben Breakout Strategy" (anonymous, TradingStrategy.net team) —
//   local PDF archive. Card: artifacts/cards_approved/QM5_11378_big-ben-london-fade-m5.md
//   (g0_status APPROVED). source_id e803fe2b-2ca3-50af-a4b5-3cafbebac42d.
//
// Mechanics (M5, closed-bar reads; "Big Ben" London-open FADE):
//   Asia body range : over UTC bars [00:00 .. 06:55], range_high = MAX(max(O,C)),
//                     range_low = MIN(min(O,C)). Body high/low — wicks ignored.
//   Spike window    : UTC [07:00 .. 08:00). A bar that CLOSES beyond the range
//                     marks the fade setup (the single EVENT precursor):
//                       close < range_low  -> arm LONG  (fade a bearish spike)
//                       close > range_high -> arm SHORT (fade a bullish spike)
//   Entry EVENT     : the first subsequent closed bar (still within the entry
//                     window, UTC < 08:30) that closes back INSIDE the range
//                     with a confirming body:
//                       LONG : close > range_low  AND close > open  -> BUY
//                       SHORT: close < range_high AND close < open  -> SELL
//   Stop loss       : LONG  = spike-bar Low  - 1 pip ; SHORT = spike-bar High + 1 pip.
//                     Capped to sl_max_pips (25).
//   Take profit     : range width in pips, clipped to [tp_min_pips, tp_max_pips]
//                     (20..60), projected from entry.
//   Time stop       : forcibly close any open position at/after UTC 09:00.
//   Filters         : skip day if Asia body range < min_range_pips (15);
//                     one trade per UTC day per symbol; spread cap fail-OPEN.
//
//   SESSION TIME is derived from the BAR TIMESTAMP in broker time, converted to
//   UTC via QM_BrokerToUTC (DXZ NY-Close GMT+2/+3, DST-aware) — never a fixed
//   wall-clock. Range/levels come from PRIOR CLOSED bars only.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11378;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Session windows are in UTC/GMT (the card's reference frame). Each bar's broker
// open-time is converted to UTC via QM_BrokerToUTC before comparison, so these
// hold across US-DST transitions.
input int    strategy_asia_start_hour    = 0;     // Asia body-range window start (UTC hour)
input int    strategy_asia_end_hour      = 7;     // Asia window end (UTC, exclusive) -> last bar 06:55
input int    strategy_spike_start_hour   = 7;     // spike-detection window start (UTC hour)
input int    strategy_spike_end_hour     = 8;     // spike window end (UTC hour, exclusive)
input int    strategy_entry_end_hour     = 8;     // entry allowed until this UTC hour ...
input int    strategy_entry_end_min      = 30;    // ... and this UTC minute (08:30)
input int    strategy_timestop_hour      = 9;     // force-close at/after this UTC hour
input int    strategy_min_range_pips     = 15;    // skip day if Asia body range < this
input int    strategy_tp_min_pips        = 20;    // TP clip lower bound (pips)
input int    strategy_tp_max_pips        = 60;    // TP clip upper bound (pips)
input int    strategy_sl_max_pips        = 25;    // SL cap (pips)
input int    strategy_sl_buffer_pips     = 1;     // SL buffer beyond the spike candle (pips)
input double strategy_spread_cap_pips    = 20.0;  // skip only a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// File-scope per-day session state. Advanced ONCE per closed bar in
// AdvanceState_OnNewBar(); the per-tick hooks only read it. All session timing
// is in UTC (bar open-time converted from broker time via QM_BrokerToUTC).
// -----------------------------------------------------------------------------
int      g_session_day      = -1;     // UTC day-of-year of the current session
int      g_session_year     = -1;     // UTC year (guards against day-of-year wrap)
bool     g_range_ready      = false;  // Asia body range computed & passes min width
double   g_range_high       = 0.0;    // Asia body-range high (max of O/C)
double   g_range_low        = 0.0;    // Asia body-range low  (min of O/C)
double   g_range_width      = 0.0;    // range width (price)
bool     g_spike_armed      = false;  // a qualifying spike close occurred this session
int      g_spike_dir        = 0;      // +1 = LONG setup (spike below), -1 = SHORT (spike above)
double   g_spike_extreme    = 0.0;    // spike-bar Low (LONG) / High (SHORT) for the SL
bool     g_traded_today     = false;  // one trade per UTC day per symbol

// Pending entry latched on the closed-bar path, consumed by Strategy_EntrySignal.
bool     g_entry_pending    = false;
int      g_entry_dir        = 0;      // +1 BUY / -1 SELL
double   g_entry_sl_price   = 0.0;
double   g_entry_tp_price   = 0.0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// UTC open-time of bar `shift` for the current symbol/timeframe.
datetime UTCBarOpenTime(const int shift)
  {
   const datetime broker_open = iTime(_Symbol, _Period, shift); // perf-allowed: bespoke session timing
   if(broker_open <= 0)
      return 0;
   return QM_BrokerToUTC(broker_open);
  }

double PipsToPrice(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Build the Asia body range for the session that the just-closed bar (shift 1)
// belongs to. Scans backwards from shift 1 collecting every closed bar whose UTC
// hour is within [asia_start, asia_end). Returns false if the window is empty or
// the body range is below the minimum width.
bool ComputeAsiaRange(const int utc_year, const int utc_yday)
  {
   double hi = -DBL_MAX;
   double lo =  DBL_MAX;
   bool   any = false;

   // Bound the scan generously: an M5 day is 288 bars; the Asia window is ~84
   // bars. 600 closed-bar reads covers it with slack and is gated to one new bar.
   for(int s = 1; s <= 600; ++s)
     {
      const datetime utc_open = UTCBarOpenTime(s);
      if(utc_open <= 0)
         break;

      MqlDateTime dt;
      ZeroMemory(dt);
      TimeToStruct(utc_open, dt);

      // Stop once we walk past the session's own calendar day (UTC).
      if(dt.year != utc_year || dt.day_of_year != utc_yday)
         break;

      if(dt.hour < strategy_asia_start_hour || dt.hour >= strategy_asia_end_hour)
         continue;

      const double o = iOpen(_Symbol, _Period, s);  // perf-allowed: bespoke body-range math
      const double c = iClose(_Symbol, _Period, s); // perf-allowed
      if(o <= 0.0 || c <= 0.0)
         continue;

      const double body_hi = (o > c) ? o : c;
      const double body_lo = (o < c) ? o : c;
      if(body_hi > hi) hi = body_hi;
      if(body_lo < lo) lo = body_lo;
      any = true;
     }

   if(!any)
      return false;

   const double width = hi - lo;
   const double min_width = PipsToPrice(strategy_min_range_pips);
   if(width < min_width)
      return false;

   g_range_high  = hi;
   g_range_low   = lo;
   g_range_width = width;
   return true;
  }

// Advance per-session state by ONE closed bar (shift 1). Called once per new bar.
void AdvanceState_OnNewBar()
  {
   const datetime utc_open1 = UTCBarOpenTime(1);
   if(utc_open1 <= 0)
      return;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_open1, dt);

   // New UTC day -> reset the whole session.
   if(dt.day_of_year != g_session_day || dt.year != g_session_year)
     {
      g_session_day   = dt.day_of_year;
      g_session_year  = dt.year;
      g_range_ready   = false;
      g_spike_armed   = false;
      g_spike_dir     = 0;
      g_spike_extreme = 0.0;
      g_traded_today  = false;
      g_entry_pending = false;
      g_entry_dir     = 0;
     }

   // Once the Asia window has closed (we are at/after asia_end), compute the
   // range a single time for this session.
   if(!g_range_ready && dt.hour >= strategy_asia_end_hour)
      g_range_ready = ComputeAsiaRange(dt.year, dt.day_of_year);

   if(!g_range_ready || g_traded_today)
      return;

   const double o1 = iOpen(_Symbol, _Period, 1);  // perf-allowed: bespoke fade math
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return;

   const int hh = dt.hour;
   const int mm = dt.min;
   const bool in_spike_window = (hh >= strategy_spike_start_hour && hh < strategy_spike_end_hour);
   const bool before_entry_cutoff =
      (hh < strategy_entry_end_hour) ||
      (hh == strategy_entry_end_hour && mm < strategy_entry_end_min);

   // --- Spike detection (the single EVENT precursor). Re-arm on the most recent
   //     qualifying spike close while still in the spike window and not yet
   //     entered, so the freshest extreme drives the fade SL. ---
   if(in_spike_window)
     {
      if(c1 < g_range_low)
        {
         g_spike_armed   = true;
         g_spike_dir     = +1;          // fade DOWN spike -> LONG
         g_spike_extreme = l1;          // spike-bar Low for the SL
        }
      else if(c1 > g_range_high)
        {
         g_spike_armed   = true;
         g_spike_dir     = -1;          // fade UP spike -> SHORT
         g_spike_extreme = h1;          // spike-bar High for the SL
        }
     }

   // --- Entry: first re-entry candle back inside the range with a confirming
   //     body. Allowed within the spike window and up to the entry cutoff. ---
   if(g_spike_armed && before_entry_cutoff && !g_entry_pending)
     {
      if(g_spike_dir > 0)
        {
         // LONG: close back above range_low with a bullish body.
         if(c1 > g_range_low && c1 > o1)
            LatchEntry(+1);
        }
      else if(g_spike_dir < 0)
        {
         // SHORT: close back below range_high with a bearish body.
         if(c1 < g_range_high && c1 < o1)
            LatchEntry(-1);
        }
     }
  }

// Compute SL/TP prices for the armed fade and latch a pending entry.
void LatchEntry(const int dir)
  {
   const double buffer   = PipsToPrice(strategy_sl_buffer_pips);
   const double sl_cap   = PipsToPrice(strategy_sl_max_pips);

   // TP distance = range width clipped to [tp_min, tp_max] pips.
   double tp_dist = g_range_width;
   const double tp_min = PipsToPrice(strategy_tp_min_pips);
   const double tp_max = PipsToPrice(strategy_tp_max_pips);
   if(tp_dist < tp_min) tp_dist = tp_min;
   if(tp_dist > tp_max) tp_dist = tp_max;

   // Reference entry = the re-entry bar close (closed-bar level the rule fires on);
   // the framework fills the actual market price at send (req.price = 0).
   const double ref_entry = iClose(_Symbol, _Period, 1); // perf-allowed
   if(ref_entry <= 0.0)
      return;

   double sl_price = 0.0;
   double tp_price = 0.0;

   if(dir > 0) // LONG
     {
      double sl = g_spike_extreme - buffer;       // 1 pip below spike Low
      double sl_dist = ref_entry - sl;
      if(sl_dist > sl_cap)                         // cap SL distance at sl_max_pips
         sl = ref_entry - sl_cap;
      sl_price = QM_StopRulesNormalizePrice(_Symbol, sl);
      tp_price = QM_StopRulesNormalizePrice(_Symbol, ref_entry + tp_dist);
     }
   else        // SHORT
     {
      double sl = g_spike_extreme + buffer;       // 1 pip above spike High
      double sl_dist = sl - ref_entry;
      if(sl_dist > sl_cap)
         sl = ref_entry + sl_cap;
      sl_price = QM_StopRulesNormalizePrice(_Symbol, sl);
      tp_price = QM_StopRulesNormalizePrice(_Symbol, ref_entry - tp_dist);
     }

   if(sl_price <= 0.0 || tp_price <= 0.0)
      return;

   g_entry_pending  = true;
   g_entry_dir      = dir;
   g_entry_sl_price = sl_price;
   g_entry_tp_price = tp_price;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double spread     = ask - bid;
   const double spread_cap = PipsToPrice((int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;
   return false;
  }

// Entry: consume a pending fade latched on the closed-bar path. Caller
// guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_traded_today || !g_entry_pending || g_entry_dir == 0)
      return false;

   req.type   = (g_entry_dir > 0) ? QM_BUY : QM_SELL;
   req.price  = 0.0;                  // framework fills market price at send
   req.sl     = g_entry_sl_price;
   req.tp     = g_entry_tp_price;
   req.reason = (g_entry_dir > 0) ? "big_ben_fade_long" : "big_ben_fade_short";

   // Consume the latch and lock the one-trade-per-day rule.
   g_entry_pending = false;
   g_entry_dir     = 0;
   g_traded_today  = true;
   return true;
  }

// No active trade management — fixed SL/TP plus the UTC 09:00 time stop in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: force-close any open position at/after UTC 09:00 (current bar's
// broker open-time converted to UTC). Returns TRUE so the framework closes the
// position for this EA's magic.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(utc_now <= 0)
      return false;

   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc_now, dt);

   return (dt.hour >= strategy_timestop_hour);
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance per-session state ONCE per closed bar before evaluating entry.
   AdvanceState_OnNewBar();

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
