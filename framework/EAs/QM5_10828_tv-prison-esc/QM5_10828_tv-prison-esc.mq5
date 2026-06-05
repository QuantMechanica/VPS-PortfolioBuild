#property strict
#property version   "5.0"
#property description "QM5_10828 TradingView Prison Escape Breakout (tv-prison-esc)"
// Strategy Card: QM5_10828_tv-prison-esc, G0 APPROVED 2026-05-22.
// Source: TraderHayz, Prison Escape Breakout Strategy (TradingView open-source).

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10828 — Prison Escape Breakout (opening-range pivot breakout)
// -----------------------------------------------------------------------------
// Mechanik (card §Mechanik):
//   * Morning range-definition window opens 08:30 America/Chicago. Confirmed
//     swing pivots inside the window define a price range.
//   * rangeHigh = max of the recent pivot highs, rangeLow = min of the recent
//     pivot lows (the "widest range among selected pivots A-D" reading).
//   * LONG when price closes above rangeHigh for `breakout_closes` consecutive
//     confirmed bars inside the 08:30-10:30 entry window. SHORT mirrors below
//     rangeLow.
//   * Range filter: skip if width < range_min_atr_mult*ATR(14) or
//     width > range_max_atr_mult*ATR(14).
//   * Stop = opposite side of the range. Target = `target_rr` * risk (1R base).
//   * Hard flat at 12:30 America/Chicago. One position per symbol/magic, one
//     entry per session day (midline second-trade rule disabled in V5 base).
//
// TIME MODEL (deterministic, no broker-clock dependency):
//   The DarwinexZero NY-close broker clock and America/Chicago BOTH follow the
//   US DST calendar (see QM_DSTAware.mqh). During US DST broker=UTC+3 /
//   Chicago=UTC-5; outside it broker=UTC+2 / Chicago=UTC-6. In both regimes
//   broker = Chicago + 8h, a constant offset across the whole year. So all
//   session gating is done on broker-time HHMM with a fixed +8h Chicago->broker
//   shift — exact and O(1), no per-tick DST recomputation.
//
// PERF: all pivot/structure reads run inside Strategy_EntrySignal, which the
// framework calls once per closed bar (QM_IsNewBar gate in OnTick). The pivot
// scan is bounded to 2*pivot_depth+1 closed bars. Per-tick paths (NoTradeFilter,
// ManageOpenPosition, ExitSignal) are O(1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10828;
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
input int    pivot_depth                    = 5;     // swing-pivot left/right bars (card: depth 3/5/8)
input int    pivot_lookback_n               = 2;     // recent pivot highs & lows spanning the range (A-D ~= 2+2)
input int    breakout_closes                = 2;     // consecutive closes beyond range to confirm (card: 1 or 2)
input double range_min_atr_mult             = 0.5;   // skip if range width < this * ATR(range_atr_period)
input double range_max_atr_mult             = 3.0;   // skip if range width > this * ATR(range_atr_period)
input int    range_atr_period               = 14;    // ATR period for width / FVG filters
input double target_rr                      = 1.0;   // take-profit as multiple of risk (1R baseline)
input bool   use_fvg_filter                 = false; // optional 3-bar FVG confirmation (card: off baseline)
input double fvg_atr_mult                    = 0.5;   // min FVG width as * ATR(atr_period) when enabled
input int    session_start_chicago_hhmm     = 830;   // range-def + entry window open (America/Chicago)
input int    entry_end_chicago_hhmm         = 1030;  // entry window close (America/Chicago)
input int    hard_flat_chicago_hhmm         = 1230;  // hard flat all positions (America/Chicago)
input int    chicago_to_broker_offset_hours = 8;     // broker(NY-close) = Chicago + 8h (constant; both follow US DST)
input int    max_spread_points              = 0;     // 0 = disabled; else block NEW entries above this spread (points)

// -----------------------------------------------------------------------------
// Cached closed-bar state (advanced once per new bar in Strategy_EntrySignal).
// -----------------------------------------------------------------------------
#define QM_PE_MAX_RING 32
double  g_ph_ring[QM_PE_MAX_RING];   // recent confirmed pivot-high prices (this session)
double  g_pl_ring[QM_PE_MAX_RING];   // recent confirmed pivot-low prices  (this session)
int     g_ph_count = 0;
int     g_pl_count = 0;
int     g_ph_idx   = 0;
int     g_pl_idx   = 0;
double  g_range_high = 0.0;
double  g_range_low  = 0.0;
bool    g_range_valid = false;
int     g_session_date = -1;         // broker yyyymmdd of the active session (reset key)
bool    g_traded_today = false;

// --- time helpers -----------------------------------------------------------
int PE_Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int PE_BrokerDate(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
  }

// Convert an America/Chicago HHMM into the equivalent broker-time HHMM using the
// constant +offset relationship documented in the header.
int PE_ChicagoToBrokerHhmm(const int chicago_hhmm)
  {
   const int hh = chicago_hhmm / 100;
   const int mm = chicago_hhmm % 100;
   const int bh = (hh + chicago_to_broker_offset_hours) % 24;
   return (bh * 100 + mm);
  }

bool PE_InEntryWindowBroker(const datetime broker_t)
  {
   const int hhmm  = PE_Hhmm(broker_t);
   const int start = PE_ChicagoToBrokerHhmm(session_start_chicago_hhmm);
   const int end   = PE_ChicagoToBrokerHhmm(entry_end_chicago_hhmm);
   return (hhmm >= start && hhmm < end);
  }

// --- ring helpers -----------------------------------------------------------
int PE_RingCap()
  {
   int cap = pivot_lookback_n;
   if(cap < 1)                cap = 1;
   if(cap > QM_PE_MAX_RING)   cap = QM_PE_MAX_RING;
   return cap;
  }

void PE_PushHigh(const double price)
  {
   const int cap = PE_RingCap();
   g_ph_ring[g_ph_idx] = price;
   g_ph_idx = (g_ph_idx + 1) % cap;
   if(g_ph_count < cap)
      g_ph_count++;
  }

void PE_PushLow(const double price)
  {
   const int cap = PE_RingCap();
   g_pl_ring[g_pl_idx] = price;
   g_pl_idx = (g_pl_idx + 1) % cap;
   if(g_pl_count < cap)
      g_pl_count++;
  }

void PE_ResetSession(const int broker_date)
  {
   g_session_date = broker_date;
   g_ph_count = 0;
   g_pl_count = 0;
   g_ph_idx   = 0;
   g_pl_idx   = 0;
   g_range_high = 0.0;
   g_range_low  = 0.0;
   g_range_valid = false;
   g_traded_today = false;
  }

// Recompute rangeHigh/rangeLow from the current pivot rings.
void PE_RefreshRange()
  {
   g_range_valid = false;
   if(g_ph_count <= 0 || g_pl_count <= 0)
      return;

   double hi = -DBL_MAX;
   for(int i = 0; i < g_ph_count; ++i)
      hi = MathMax(hi, g_ph_ring[i]);

   double lo = DBL_MAX;
   for(int i = 0; i < g_pl_count; ++i)
      lo = MathMin(lo, g_pl_ring[i]);

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return;

   g_range_high  = hi;
   g_range_low   = lo;
   g_range_valid = true;
  }

// Detect a swing pivot whose centre bar just became fully surrounded (centre at
// shift pivot_depth+1, with pivot_depth confirmed bars on each side) and, if it
// sits inside the range-definition window, push it into the rings. Runs once per
// closed bar.
void PE_AdvanceState()
  {
   const int d = (pivot_depth < 1) ? 1 : pivot_depth;
   const int centre = d + 1;                 // shift of the candidate pivot bar
   const int window = 2 * d + 1;             // shifts 1..window
   if(Bars(_Symbol, PERIOD_CURRENT) < window + 2)   // perf-allowed: bounded warmup guard
      return;
   // Key the active session off the just-closed bar's broker date.
   const datetime bar_t = iTime(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: bespoke session keying
   if(bar_t <= 0)
      return;

   // Session reset on broker-date change (broker midnight = Chicago 16:00, i.e.
   // safely after the 12:30 flat — no intra-session split).
   const int bdate = PE_BrokerDate(bar_t);
   if(bdate != g_session_date)
      PE_ResetSession(bdate);
   // Candidate pivot bar (centre of the just-completed left/right window).
   const datetime centre_t = iTime(_Symbol, PERIOD_CURRENT, centre);   // perf-allowed: bespoke pivot keying
   if(centre_t <= 0)
      return;

   // Only structural pivots formed inside the range-definition window count.
   if(!PE_InEntryWindowBroker(centre_t))
     {
      PE_RefreshRange();
      return;
     }
   // Centre-bar extremes for the swing-pivot test.
   const double centre_high = iHigh(_Symbol, PERIOD_CURRENT, centre);  // perf-allowed: bespoke pivot detection
   const double centre_low  = iLow(_Symbol, PERIOD_CURRENT, centre);   // perf-allowed: bespoke pivot detection
   bool is_pivot_high = (centre_high > 0.0);
   bool is_pivot_low  = (centre_low  > 0.0);

   for(int j = 1; j <= window; ++j)
     {
      if(j == centre)
         continue;
      const double hj = iHigh(_Symbol, PERIOD_CURRENT, j);   // perf-allowed: bespoke pivot detection, bounded 2*depth+1
      const double lj = iLow(_Symbol, PERIOD_CURRENT, j);    // perf-allowed: bespoke pivot detection, bounded 2*depth+1
      if(hj <= 0.0 || lj <= 0.0)
        {
         is_pivot_high = false;
         is_pivot_low  = false;
         break;
        }
      if(centre_high < hj)
         is_pivot_high = false;
      if(centre_low > lj)
         is_pivot_low = false;
     }

   if(is_pivot_high)
      PE_PushHigh(centre_high);
   if(is_pivot_low)
      PE_PushLow(centre_low);

   PE_RefreshRange();
  }

// True when the last `n` consecutive closed bars (shift 1..n) all close strictly
// beyond `level` on the requested side. above=true checks closes > level.
bool PE_ConsecutiveCloses(const int n, const double level, const bool above)
  {
   int need = n;
   if(need < 1)              need = 1;
   if(need > QM_PE_MAX_RING) need = QM_PE_MAX_RING;
   for(int i = 1; i <= need; ++i)
     {
      const double c = iClose(_Symbol, PERIOD_CURRENT, i);   // perf-allowed: bounded breakout-confirmation reads
      if(c <= 0.0)
         return false;
      if(above && c <= level)
         return false;
      if(!above && c >= level)
         return false;
     }
   return true;
  }

// Optional 3-bar fair-value-gap confirmation in the breakout direction.
bool PE_FvgConfirms(const bool is_long, const double atr)
  {
   if(!use_fvg_filter)
      return true;
   if(atr <= 0.0)
      return false;
   // Three-bar window for the fair-value-gap test.
   const double h1 = iHigh(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: bespoke FVG structure read
   const double l1 = iLow(_Symbol, PERIOD_CURRENT, 1);    // perf-allowed: bespoke FVG structure read
   const double h3 = iHigh(_Symbol, PERIOD_CURRENT, 3);   // perf-allowed: bespoke FVG structure read
   const double l3 = iLow(_Symbol, PERIOD_CURRENT, 3);    // perf-allowed: bespoke FVG structure read
   if(h1 <= 0.0 || l1 <= 0.0 || h3 <= 0.0 || l3 <= 0.0)
      return false;

   const double need = fvg_atr_mult * atr;
   if(is_long)
      return (l1 - h3) >= need;     // bullish gap: bar-1 low above bar-3 high
   return (l3 - h1) >= need;        // bearish gap: bar-3 low above bar-1 high
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-Trade Filter (time, spread, news). Per-tick O(1). Session/time gating for
// ENTRIES lives in Strategy_EntrySignal (the framework new-bar path) so it does
// not also suppress the hard-flat exit, which the skeleton evaluates after this
// filter. Here we only optionally veto on an abnormally wide spread; disabled by
// default (max_spread_points = 0).
bool Strategy_NoTradeFilter()
  {
   if(max_spread_points <= 0)
      return false;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > max_spread_points);
  }

// Entry — called once per closed bar (QM_IsNewBar gate in OnTick).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;                 // 0 => framework resolves the market price
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   PE_AdvanceState();

   if(g_traded_today || !g_range_valid)
      return false;
   // Gate entries to the just-closed bar's broker time inside the window.
   const datetime bar_t = iTime(_Symbol, PERIOD_CURRENT, 1);   // perf-allowed: bespoke session keying
   if(bar_t <= 0 || !PE_InEntryWindowBroker(bar_t))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, range_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double width = g_range_high - g_range_low;
   if(width < range_min_atr_mult * atr || width > range_max_atr_mult * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // LONG: consecutive closes above rangeHigh.
   if(PE_ConsecutiveCloses(breakout_closes, g_range_high, true) &&
      PE_FvgConfirms(true, atr))
     {
      const double entry = ask;
      const double sl    = g_range_low;
      const double risk  = entry - sl;
      if(risk <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.sl     = sl;
      req.tp     = entry + risk * target_rr;
      req.reason = "PRISON_ESC_LONG";
      g_traded_today = true;
      return true;
     }

   // SHORT: consecutive closes below rangeLow.
   if(PE_ConsecutiveCloses(breakout_closes, g_range_low, false) &&
      PE_FvgConfirms(false, atr))
     {
      const double entry = bid;
      const double sl    = g_range_high;
      const double risk  = sl - entry;
      if(risk <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.sl     = sl;
      req.tp     = entry - risk * target_rr;
      req.reason = "PRISON_ESC_SHORT";
      g_traded_today = true;
      return true;
     }

   return false;
  }

// Trade management — card specifies no trailing / break-even / partial logic.
void Strategy_ManageOpenPosition()
  {
  }

// Exit — hard flat at 12:30 America/Chicago. Runs every tick (O(1)).
bool Strategy_ExitSignal()
  {
   const int hhmm     = PE_Hhmm(TimeCurrent());
   const int flat_brk = PE_ChicagoToBrokerHhmm(hard_flat_chicago_hhmm);
   return (hhmm >= flat_brk);
  }

// News-filter override — defer to the central two-axis framework filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10828_tv-prison-esc\"}");
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
