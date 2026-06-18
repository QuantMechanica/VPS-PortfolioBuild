#property strict
#property version   "5.0"
#property description "QM5_12499 dual-thrust — Dual Thrust opening-range breakout (intraday, M1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12499 dual-thrust
// -----------------------------------------------------------------------------
// Source: je-suis-tm/quant-trading, "Dual Thrust backtest.py" (public GitHub).
// Card: artifacts/cards_approved/QM5_12499_dual-thrust.md (g0_status APPROVED).
//
// Classic intraday Dual Thrust opening-range breakout.
//
// Mechanics (entry TF = M1; daily Range from PERIOD_D1 closed bars):
//   Range STATE (recomputed once per broker-day, prior rg days, shifts 1..rg):
//     HH = highest D1 high,  LL = lowest D1 low,
//     HC = highest D1 close, LC = lowest D1 close
//     range1 = HH - LC ; range2 = HC - LL ; range = max(range1, range2).
//   Lines STATE (set when the session opens each broker-day):
//     open_today = price at session start (first in-session M1 bar of the day).
//     upper = open_today + K1 * range  (K1 = param).
//     lower = open_today - K2 * range  (K2 = 1 - param).
//   Trigger EVENT (per tick, inside session window only):
//     live break above `upper`  -> go LONG  (once per day).
//     live break below `lower`  -> go SHORT (once per day).
//   Two independent per-side latches (g_long_done / g_short_done) reset each
//   broker-day. Each line is a single price LEVEL, so the two-cross-same-bar
//   zero-trade trap does not apply (long and short are separate triggers).
//   Stop : V5 ATR hard stop (source has none before session flatten).
//   Exit : flatten all positions at/after session end (source's session close).
//
// .DWX invariants honoured: session in BROKER time (DST-aware via QM_BrokerToUTC),
// spread guard fail-open on zero modeled spread, single QM_IsNewBar consume,
// no swap gate, no per-EA IsNewBar, closed-bar-cached state (intraday discipline).
//
// Symbols (all present in dwx_symbol_matrix.csv — no porting needed):
//   EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, NDX.DWX, WS30.DWX.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12499;
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
// Dual Thrust core.
input int    strategy_range_days        = 5;     // rg: prior days used to build the range
input double strategy_param             = 0.5;   // K1 = param (upper); K2 = 1-param (lower)
// Session window in BROKER-time hours (DXZ NY-Close GMT+2/+3, DST-aware).
// Card reference = 03:00->12:00 EST London window. 03:00 EST ~= 08:00 UTC ~=
// broker 10:00 (US-std) / 11:00 (US-DST); 12:00 EST ~= 17:00 UTC ~= broker
// 19:00 / 20:00. Defaults capture the band on both DST sides; the P3 sweep and
// per-symbol setfiles tune these. All comparisons go through QM_Sig_Session.
input int    strategy_session_start_hr  = 10;    // broker hour: open / first arm
input int    strategy_session_end_hr    = 19;    // broker hour: flatten / no new entries
// ATR hard stop (platform-risk only; source has no stop before session close).
input int    strategy_atr_period        = 14;    // ATR period (D1) for the stop
input double strategy_atr_stop_mult     = 2.5;   // stop distance = mult * ATR(D1)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached state — advanced ONCE per closed entry-TF bar / per day.
// -----------------------------------------------------------------------------
double   g_range          = 0.0;   // Dual Thrust range for the current day
double   g_upper          = 0.0;   // break-above line (long trigger)
double   g_lower          = 0.0;   // break-below line (short trigger)
bool     g_lines_ready    = false; // upper/lower computed for the current day
datetime g_day_key        = 0;     // broker-date (00:00) of the current trading day
bool     g_long_done      = false; // long already taken this day
bool     g_short_done     = false; // short already taken this day

// Broker-time midnight key for "which day are we in".
datetime BrokerDayKey(const datetime broker_now)
  {
   MqlDateTime t;
   TimeToStruct(broker_now, t);
   t.hour = 0;
   t.min  = 0;
   t.sec  = 0;
   return StructToTime(t);
  }

// Recompute the Dual Thrust range from prior `range_days` D1 closed bars
// (shifts 1..range_days). Single closed-bar reads — perf-allowed, cached.
double ComputeRange()
  {
   const int rg = strategy_range_days;
   if(rg < 1)
      return 0.0;

   double hh = -DBL_MAX;   // highest high
   double ll =  DBL_MAX;   // lowest low
   double hc = -DBL_MAX;   // highest close
   double lc =  DBL_MAX;   // lowest close

   for(int s = 1; s <= rg; ++s)
     {
      const double dh = iHigh(_Symbol,  PERIOD_D1, s); // perf-allowed: bounded closed-bar read
      const double dl = iLow(_Symbol,   PERIOD_D1, s); // perf-allowed
      const double dc = iClose(_Symbol, PERIOD_D1, s); // perf-allowed
      if(dh <= 0.0 || dl <= 0.0 || dc <= 0.0)
         return 0.0; // history not ready — defer
      if(dh > hh) hh = dh;
      if(dl < ll) ll = dl;
      if(dc > hc) hc = dc;
      if(dc < lc) lc = dc;
     }

   const double range1 = hh - lc;
   const double range2 = hc - ll;
   const double range  = (range1 > range2) ? range1 : range2;
   return (range > 0.0) ? range : 0.0;
  }

// Advance cached daily state. Called once per closed entry-TF bar inside the
// new-bar gate. Resets per-day latches on a fresh broker-day and arms the
// upper/lower lines once the session has opened (using the in-session open).
void AdvanceState_OnNewBar()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_key    = BrokerDayKey(broker_now);

   // New broker-day: reset everything.
   if(day_key != g_day_key)
     {
      g_day_key      = day_key;
      g_lines_ready  = false;
      g_long_done    = false;
      g_short_done   = false;
      g_range        = 0.0;
      g_upper        = 0.0;
      g_lower        = 0.0;
     }

   // Arm the lines once, on the first in-session closed bar of the day.
   if(!g_lines_ready && QM_Sig_Session(broker_now, strategy_session_start_hr, strategy_session_end_hr) == 1)
     {
      const double range = ComputeRange();
      if(range <= 0.0)
         return; // history not ready yet — retry next bar (still in session)

      // open_today = open of the current (session-start) entry-TF bar.
      const double open_today = iOpen(_Symbol, _Period, 0); // perf-allowed: single current-bar open
      if(open_today <= 0.0)
         return;

      const double k1 = strategy_param;          // upper coefficient
      const double k2 = 1.0 - strategy_param;    // lower coefficient
      g_range       = range;
      g_upper       = open_today + k1 * range;
      g_lower       = open_today - k2 * range;
      g_lines_ready = true;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Block outside the session window; otherwise apply a
// spread guard that fails OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(QM_Sig_Session(broker_now, strategy_session_start_hr, strategy_session_end_hr) != 1)
      return true; // outside the trading session — block new entries

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Dual Thrust breakout entry. Caller guarantees QM_IsNewBar() == true.
// Per-tick cheap: reads cached lines + live bid/ask only. NoTradeFilter has
// already confirmed we are inside the session window.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_lines_ready)
      return false; // lines not armed for today yet

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // LONG: live ask breaks above the upper line (once per day).
   if(!g_long_done && ask > g_upper)
     {
      const double entry = ask;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_stop_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — exit by session flatten / ATR stop
      req.reason = "dual_thrust_long";
      g_long_done = true;
      return true;
     }

   // SHORT: live bid breaks below the lower line (once per day).
   if(!g_short_done && bid < g_lower)
     {
      const double entry = bid;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_stop_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "dual_thrust_short";
      g_short_done = true;
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. Session flatten lives
// in Strategy_ExitSignal (checked every tick).
void Strategy_ManageOpenPosition()
  {
  }

// Session flatten: close the open position once we are at/after session end
// (outside the session window). Cheap O(1) per-tick check on broker time.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();
   // Outside the session window -> flatten (source clears all at session close).
   return (QM_Sig_Session(broker_now, strategy_session_start_hr, strategy_session_end_hr) != 1);
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

   // Per-tick exit check FIRST (session flatten is time-based, must fire even
   // when NoTradeFilter would block new entries outside the session).
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

   Strategy_ManageOpenPosition();

   // Advance cached daily state once per closed entry-TF bar (single consume).
   if(QM_IsNewBar())
     {
      QM_EquityStreamOnNewBar();
      AdvanceState_OnNewBar();
     }

   // Per-tick entry: NoTradeFilter gates the session window; EntrySignal does
   // the O(1) live-price-vs-cached-line break check.
   if(Strategy_NoTradeFilter())
      return;

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
