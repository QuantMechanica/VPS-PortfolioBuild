#property strict
#property version   "5.0"
#property description "QM5_11445 burke-low-hanging-fruit-m5 — session HOD/LOD break + pullback + EMA20 close-back continuation (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11445 burke-low-hanging-fruit-m5
// -----------------------------------------------------------------------------
// Source: Stacey Burke Trading Playbook — "Low Hanging Fruit" session HOD/LOD
//   retest. Card: artifacts/cards_approved/QM5_11445_burke-low-hanging-fruit-m5.md
//   (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; intraday cached state):
//   Session windows (UTC, converted from each closed bar's BROKER timestamp via
//   QM_BrokerToUTC — DXZ broker = NY-Close GMT+2/+3, DST-aware):
//     London 07:00-12:00 UTC, NY 13:00-17:00 UTC.
//   Within a session we track the rolling session_high / session_low from the
//   CLOSED-bar closes (gapless-safe: .DWX CFDs have open[0]==close[1], so we
//   reference prior closes, never an intrabar range or a gap).
//   LONG:
//     1. A "HOD break" latches when a closed M5 makes a new session high
//        (close > prior session_high). Store hod_break_level.
//     2. Price then retraces 25-50 pips down from the break level
//        (hod_break_level - close BETWEEN pb_lo_pips AND pb_hi_pips).
//     3. Trigger EVENT: a closed M5 closes back above EMA20 -> BUY.
//     4. One long re-entry attempt per session.
//   SHORT mirrors with session LOD break + retrace up + close below EMA20.
//   Stop : entry -/+ sl_pips. Take : entry +/- tp_pips (scale-correct pips).
//   Spread guard : fail-open on .DWX zero modeled spread; block only a genuinely
//                  wide spread > spread_cap_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs + the cached-state advance are
// EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11445;
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
// Session windows in UTC (converted from broker time per closed bar).
input int    strategy_london_start_utc  = 7;    // London session start hour (UTC)
input int    strategy_london_end_utc    = 12;   // London session end hour (UTC, exclusive)
input int    strategy_ny_start_utc      = 13;   // NY session start hour (UTC)
input int    strategy_ny_end_utc        = 17;   // NY session end hour (UTC, exclusive)
input int    strategy_ema_period        = 20;   // EMA close-back trigger period
input int    strategy_pb_lo_pips        = 25;   // min pullback from break level (pips)
input int    strategy_pb_hi_pips        = 50;   // max pullback from break level (pips)
input int    strategy_sl_pips           = 20;   // stop distance (pips)
input int    strategy_tp_pips           = 50;   // take-profit distance (pips)
input int    strategy_spread_cap_pips   = 15;   // skip only spreads wider than this

// -----------------------------------------------------------------------------
// File-scope cached intraday state. Advanced ONCE per closed bar after the
// framework new-bar gate. No second timestamp gate inside the advance.
// -----------------------------------------------------------------------------
int      g_session_id        = -1;     // 0 = London, 1 = NY, -1 = no session
int      g_session_key       = -1;     // (utc_day * 2 + session_id); change => new session
double   g_session_high      = 0.0;    // rolling session high (from closed closes)
double   g_session_low       = 0.0;    // rolling session low
bool     g_session_seeded    = false;  // has the session received at least one bar
double   g_hod_break_level   = 0.0;    // latched level of the HOD break (long setup)
double   g_lod_break_level   = 0.0;    // latched level of the LOD break (short setup)
bool     g_hod_break_active  = false;  // a long setup is armed
bool     g_lod_break_active  = false;  // a short setup is armed
bool     g_long_reentry_done = false;  // one long attempt per session
bool     g_short_reentry_done= false;  // one short attempt per session
bool     g_long_signal       = false;  // entry EVENT latched this closed bar
bool     g_short_signal      = false;

// Resolve which UTC session a UTC timestamp belongs to (-1 if none).
int SessionForUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   const int h = dt.hour;
   if(h >= strategy_london_start_utc && h < strategy_london_end_utc)
      return 0;
   if(h >= strategy_ny_start_utc && h < strategy_ny_end_utc)
      return 1;
   return -1;
  }

// UTC calendar day index (days since epoch) — stable per-day key.
int UTCDayIndex(const datetime utc)
  {
   return (int)(utc / 86400);
  }

// -----------------------------------------------------------------------------
// Cached-state advance — called ONCE per new closed bar from OnTick.
// Reads the last CLOSED bar (shift 1). Pure arithmetic, no history scans.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_long_signal  = false;
   g_short_signal = false;

   // Use the LAST CLOSED bar's broker open time, mapped to UTC for the session.
   const datetime bar_broker = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar time
   if(bar_broker <= 0)
      return;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);

   const int sess = SessionForUTC(bar_utc);
   if(sess < 0)
     {
      // Outside any session — disarm. Setups do not carry across the dead gap.
      g_session_id       = -1;
      g_session_key      = -1;
      g_session_seeded   = false;
      g_hod_break_active = false;
      g_lod_break_active = false;
      return;
     }

   const int session_key = UTCDayIndex(bar_utc) * 2 + sess;
   if(session_key != g_session_key)
     {
      // New session — reset all per-session state.
      g_session_key        = session_key;
      g_session_id         = sess;
      g_session_seeded     = false;
      g_session_high       = 0.0;
      g_session_low        = 0.0;
      g_hod_break_level    = 0.0;
      g_lod_break_level    = 0.0;
      g_hod_break_active   = false;
      g_lod_break_active   = false;
      g_long_reentry_done  = false;
      g_short_reentry_done = false;
     }

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return;

   const double pb_lo = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pb_lo_pips);
   const double pb_hi = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_pb_hi_pips);

   if(!g_session_seeded)
     {
      // First bar of the session establishes the initial extremes.
      g_session_high   = close1;
      g_session_low    = close1;
      g_session_seeded = true;
      return; // need at least one prior reference before a break can register
     }

   // --- LONG setup: detect a new HOD break, then pullback, then EMA close-back ---
   if(close1 > g_session_high)
     {
      // New session high on this closed bar = HOD break event. Latch the level.
      g_hod_break_level  = close1;
      g_hod_break_active = true;
      // A fresh upside break invalidates any pending short retrace setup.
      g_lod_break_active = false;
     }
   else if(g_hod_break_active && !g_long_reentry_done)
     {
      const double pullback = g_hod_break_level - close1; // distance below the break
      if(pullback >= pb_lo && pullback <= pb_hi && close1 > ema)
        {
         // Retracement in band AND closed back above EMA20 -> long continuation.
         g_long_signal       = true;
         g_long_reentry_done = true;
         g_hod_break_active  = false;
        }
     }

   // --- SHORT setup: detect a new LOD break, then pullback up, then EMA close-back ---
   if(close1 < g_session_low)
     {
      g_lod_break_level  = close1;
      g_lod_break_active = true;
      g_hod_break_active = false;
     }
   else if(g_lod_break_active && !g_short_reentry_done)
     {
      const double pullback = close1 - g_lod_break_level; // distance above the break
      if(pullback >= pb_lo && pullback <= pb_hi && close1 < ema)
        {
         g_short_signal       = true;
         g_short_reentry_done = true;
         g_lod_break_active   = false;
        }
     }

   // Update rolling extremes AFTER break detection (so a break compares against
   // the prior high/low, not itself).
   if(close1 > g_session_high)
      g_session_high = close1;
   if(close1 < g_session_low)
      g_session_low = close1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > cap)
      return true;

   return false;
  }

// Entry. Reads cached per-bar signal latched in AdvanceState_OnNewBar. O(1).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_long_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "burke_lhf_long";
      return true;
     }

   if(g_short_signal)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "burke_lhf_short";
      return true;
     }

   return false;
  }

// Fixed pip stop/target manage the position; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed pip SL/TP.
bool Strategy_ExitSignal()
  {
   return false;
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
