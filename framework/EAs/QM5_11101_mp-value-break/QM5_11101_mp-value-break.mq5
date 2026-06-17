#property strict
#property version   "5.0"
#property description "QM5_11101 mp-value-break — Market Profile Value-Area Breakout (M30, continuation)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11101 mp-value-break
// -----------------------------------------------------------------------------
// Source: EarnForex "MarketProfile" GitHub repository
//         (artifacts/cards_approved/QM5_11101_mp-value-break.md, g0_status APPROVED).
//         Citation: https://github.com/EarnForex/MarketProfile
//
// Mechanic (M30, prior-session value-area BREAKOUT, continuation):
//   The Market Profile is built from the symbol's OWN intraday M30 bars over the
//   PRIOR completed broker-time trading day — NOT an external profile feed. Tick
//   volume is the volume proxy (true exchange volume is not required on these DWX
//   CFDs; this is a documented porting limit). The price-histogram is bounded +
//   deterministic, recomputed ONCE per new broker-day on the closed-bar gate, and
//   cached in file scope (same proven builder as the sibling QM5_11014).
//
//   Prior-session levels:  POC (highest-volume bucket), VAH / VAL (value-area
//   high/low, expanded symmetrically around the POC bucket to value_area_pct of
//   total volume — EarnForex default 70%).
//
//   LONG breakout (evaluated on completed M30 bars):
//     - current M30 close breaks ABOVE prior VAH by >= breakout_buffer_atr * ATR,
//     - not before the first `min_session_bars` completed M30 bars of the session,
//     - not more than once on the LONG side this session.
//   SHORT breakout: current M30 close breaks BELOW prior VAL by the same buffer.
//
//   Exit (whichever first):
//     - POC / median failure: long closes if M30 closes back inside the VA
//       (below prior VAH); short closes if M30 closes back inside (above VAL).
//     - Time stop: after `max_hold_bars` M30 bars (8 by default).
//     - Opposite value-area break: long closes immediately if price breaks the
//       VAL side; short closes if price breaks the VAH side.
//
//   Stop loss: opposite side of the prior value area (long → prior VAL; short →
//   prior VAH), capped at `sl_cap_atr` * ATR from entry. TP not used directly —
//   the strategy is structure/time-exit driven — but a generous structural TP at
//   sl_cap_atr * tp_rr * R is set so the framework always has a bounded TP.
//
//   Filters: skip session if prior value-area width < va_min_atr*ATR or
//   > va_max_atr*ATR; news blackout via the framework; one position per magic, no
//   pyramiding, no grid, no martingale.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// .DWX invariants honoured: fail-OPEN spread (never block on zero modeled
// spread); no swap gate; sessions/hold-time expressed in BROKER time via
// TimeCurrent on the broker-time chart; breakout references the prior-session
// CLOSE-derived VAH/VAL levels (not a real overnight gap, which gapless CFDs do
// not produce); no external macro/profile feed — the profile is computed from the
// symbol's own bars only; ATR/SL distances scale-correct via QM_StopRules.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11101;
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
// --- Market-profile / value-area construction (own M30 bars, prior broker-day) ---
input double strategy_value_area_pct      = 70.0;  // EarnForex ValueAreaPercentage default
input int    strategy_va_bucket_ticks     = 5;     // price-bucket size, in symbol ticks (point granularity)
input int    strategy_va_max_buckets      = 2000;  // hard cap on histogram buckets (bounded loop guard)
// --- ATR (filter / stop / breakout buffer) ---
input int    strategy_atr_period          = 14;    // M30 ATR period
input double strategy_breakout_buffer_atr = 0.10;  // min break beyond VAH/VAL, in ATR (card: 0.10)
input double strategy_sl_cap_atr          = 2.5;   // SL cap from entry, in ATR (card P2: 2.5)
input double strategy_tp_rr               = 3.0;   // structural TP as R-multiple of capped SL distance
// --- Value-area width gating (in ATR units) ---
input double strategy_va_min_atr          = 0.75;  // skip session if VA width < this * ATR (card: 0.75)
input double strategy_va_max_atr          = 4.0;   // skip session if VA width > this * ATR (card: 4.0)
// --- Session / hold gating ---
input int    strategy_min_session_bars    = 2;     // no entry before first N completed M30 bars of session
input int    strategy_max_hold_bars       = 8;     // time-stop after N completed M30 bars (card: 8)
input int    strategy_session_start_hour  = 9;     // session start, BROKER time (~London open 08:00 UTC)
input int    strategy_session_end_hour    = 22;    // session end, BROKER time (through NY)
input double strategy_spread_pct_of_stop  = 25.0;  // skip only a genuinely wide spread (% of stop dist)

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per closed M30 bar.
// -----------------------------------------------------------------------------
double   g_prior_vah   = 0.0;   // prior-session value-area high
double   g_prior_val   = 0.0;   // prior-session value-area low
double   g_prior_poc   = 0.0;   // prior-session point of control
double   g_prior_va_width = 0.0;
bool     g_profile_valid  = false;
datetime g_profile_day    = 0;  // broker-time midnight of the day the cache is FOR (today)

// Per-session entry/bar bookkeeping (reset each new broker-day).
int      g_sess_bars   = 0;     // count of completed M30 bars seen this session
bool     g_long_taken  = false; // long side already entered this session
bool     g_short_taken = false; // short side already entered this session

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Broker-time midnight (00:00) of the calendar day containing broker_t.
datetime BrokerDayStart(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Build the prior broker-day market profile from this symbol's own M30 bars.
// Returns true and fills out_* on success. Bounded, deterministic, closed-bar.
// (Same approach as sibling QM5_11014; tick-volume TPO proxy.)
bool BuildPriorProfile(const datetime today_start,
                       double &out_vah, double &out_val,
                       double &out_poc, double &out_width)
  {
   out_vah = out_val = out_poc = out_width = 0.0;

   // Prior broker-day window: [today_start - 1 day, today_start).
   const datetime prior_start = today_start - 86400;
   const datetime prior_end   = today_start; // exclusive

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double bucket = point * (double)strategy_va_bucket_ticks;
   if(bucket <= 0.0)
      return false;

   // perf-allowed: bespoke market-profile build, gated to once per broker-day.
   const int total_bars = Bars(_Symbol, PERIOD_M30);
   if(total_bars <= 0)
      return false;

   double day_low  = 0.0;
   double day_high = 0.0;
   bool   have_range = false;
   int    bars_scanned = 0;

   // A broker-day has <=48 M30 bars; 200 covers weekend/holiday gaps comfortably.
   const int scan_cap = 200;
   for(int s = 1; s <= scan_cap && s < total_bars; ++s)
     {
      const datetime bt = iTime(_Symbol, PERIOD_M30, s); // perf-allowed
      if(bt == 0)
         break;
      if(bt >= prior_end)
         continue;        // still inside today — skip
      if(bt < prior_start)
         break;           // older than the prior day — done

      const double hi = iHigh(_Symbol, PERIOD_M30, s); // perf-allowed
      const double lo = iLow(_Symbol, PERIOD_M30, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         continue;
      if(!have_range)
        {
         day_high = hi;
         day_low  = lo;
         have_range = true;
        }
      else
        {
         if(hi > day_high) day_high = hi;
         if(lo < day_low)  day_low  = lo;
        }
      bars_scanned++;
     }

   if(!have_range || bars_scanned <= 0 || day_high <= day_low)
      return false;

   // Bucket count, bounded.
   int n_buckets = (int)((day_high - day_low) / bucket) + 1;
   if(n_buckets <= 0)
      return false;
   if(n_buckets > strategy_va_max_buckets)
      return false; // VA too wide for the configured granularity — skip this day

   double vol[];
   if(ArrayResize(vol, n_buckets) != n_buckets)
      return false;
   ArrayInitialize(vol, 0.0);

   double total_vol = 0.0;

   // Distribute each M30 bar's tick volume evenly across the price buckets it
   // spans (TPO/price-histogram proxy). Bounded by bars * buckets-span.
   for(int s = 1; s <= scan_cap && s < total_bars; ++s)
     {
      const datetime bt = iTime(_Symbol, PERIOD_M30, s); // perf-allowed
      if(bt == 0)
         break;
      if(bt >= prior_end)
         continue;
      if(bt < prior_start)
         break;

      const double hi = iHigh(_Symbol, PERIOD_M30, s); // perf-allowed
      const double lo = iLow(_Symbol, PERIOD_M30, s);  // perf-allowed
      const double tv = (double)iVolume(_Symbol, PERIOD_M30, s); // perf-allowed
      if(hi <= 0.0 || lo <= 0.0 || tv <= 0.0)
         continue;

      int b_lo = (int)((lo - day_low) / bucket);
      int b_hi = (int)((hi - day_low) / bucket);
      if(b_lo < 0) b_lo = 0;
      if(b_hi > n_buckets - 1) b_hi = n_buckets - 1;
      if(b_hi < b_lo) b_hi = b_lo;

      const int span = (b_hi - b_lo) + 1;
      const double share = tv / (double)span;
      for(int b = b_lo; b <= b_hi; ++b)
        {
         vol[b] += share;
         total_vol += share;
        }
     }

   if(total_vol <= 0.0)
      return false;

   // POC = highest-volume bucket.
   int poc_idx = 0;
   double poc_vol = vol[0];
   for(int b = 1; b < n_buckets; ++b)
     {
      if(vol[b] > poc_vol)
        {
         poc_vol = vol[b];
         poc_idx = b;
        }
     }

   // Expand symmetrically around the POC until value_area_pct of volume captured.
   const double target_vol = total_vol * (strategy_value_area_pct / 100.0);
   double captured = vol[poc_idx];
   int lo_idx = poc_idx;
   int hi_idx = poc_idx;
   for(int iter = 0; iter < n_buckets && captured < target_vol; ++iter)
     {
      const bool can_down = (lo_idx > 0);
      const bool can_up   = (hi_idx < n_buckets - 1);
      if(!can_down && !can_up)
         break;
      const double vol_down = can_down ? vol[lo_idx - 1] : -1.0;
      const double vol_up   = can_up   ? vol[hi_idx + 1] : -1.0;
      // Take the larger-volume adjacent bucket; ties expand upward.
      if(vol_up >= vol_down && can_up)
        {
         hi_idx++;
         captured += vol[hi_idx];
        }
      else if(can_down)
        {
         lo_idx--;
         captured += vol[lo_idx];
        }
      else if(can_up)
        {
         hi_idx++;
         captured += vol[hi_idx];
        }
     }

   // Bucket index -> price (bucket lower edge for VAL, upper edge for VAH).
   out_poc = day_low + (poc_idx + 0.5) * bucket;
   out_val = day_low + lo_idx * bucket;
   out_vah = day_low + (hi_idx + 1) * bucket;
   if(out_vah <= out_val)
      return false;
   out_width = out_vah - out_val;
   return true;
  }

// Advance cached state once per closed bar. Rebuilds the profile on a new
// broker-day, resets session bar-count + per-side entry latches.
void AdvanceState_OnNewBar()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_start  = BrokerDayStart(broker_now);

   if(day_start != g_profile_day)
     {
      double vah, val, poc, width;
      g_profile_valid = BuildPriorProfile(day_start, vah, val, poc, width);
      if(g_profile_valid)
        {
         g_prior_vah = vah;
         g_prior_val = val;
         g_prior_poc = poc;
         g_prior_va_width = width;
        }
      g_profile_day = day_start;
      // New session: reset bar-count and per-side entry latches.
      g_sess_bars   = 0;
      g_long_taken  = false;
      g_short_taken = false;
     }

   // Count completed M30 bars seen this session (one per closed-bar advance).
   g_sess_bars++;
  }

// Broker-time hour helper.
int BrokerHour(const datetime broker_t)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_t, dt);
   return dt.hour;
  }

bool InTradingSession(const datetime broker_now)
  {
   const int h = BrokerHour(broker_now);
   return (h >= strategy_session_start_hour && h < strategy_session_end_hour);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: outside session OR genuinely wide spread.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!InTradingSession(broker_now))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = strategy_sl_cap_atr * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Closed-bar entry (caller guarantees QM_IsNewBar() == true).
// Value-area BREAKOUT (continuation): close breaks beyond prior VAH/VAL by buffer.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_profile_valid)
      return false;

   // Do not enter before the first N completed M30 bars of the new session.
   if(g_sess_bars < strategy_min_session_bars)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Value-area width filter (in ATR units).
   if(g_prior_va_width < strategy_va_min_atr * atr_value)
      return false;
   if(g_prior_va_width > strategy_va_max_atr * atr_value)
      return false;

   // Last closed M30 bar close (perf-allowed single-bar read).
   const double c1 = iClose(_Symbol, PERIOD_M30, 1);
   if(c1 <= 0.0)
      return false;

   const double buffer = strategy_breakout_buffer_atr * atr_value;

   // --- LONG breakout: close breaks above prior VAH by >= buffer ---
   if(!g_long_taken && c1 >= (g_prior_vah + buffer))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL at opposite VA side (prior VAL), capped at sl_cap_atr * ATR from entry.
      double sl = g_prior_val;
      const double sl_floor = entry - strategy_sl_cap_atr * atr_value;
      if(sl < sl_floor)
         sl = sl_floor;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;
      // Bounded structural TP so the framework always has a TP (exits are
      // primarily structure/time driven in ManageOpenPosition/ExitSignal).
      const double r_dist = entry - sl;
      double tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * r_dist);
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "mp_va_break_long";
      g_long_taken = true;
      return true;
     }

   // --- SHORT breakout: close breaks below prior VAL by >= buffer ---
   if(!g_short_taken && c1 <= (g_prior_val - buffer))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = g_prior_vah;
      const double sl_ceil = entry + strategy_sl_cap_atr * atr_value;
      if(sl > sl_ceil)
         sl = sl_ceil;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double r_dist = sl - entry;
      double tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * r_dist);
      if(tp >= entry || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "mp_va_break_short";
      g_short_taken = true;
      return true;
     }

   return false;
  }

// Fixed SL/TP from entry; no active trailing. Structure/time exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (checked per tick, decided on closed-bar values):
//   - POC/median failure: close back inside the value area.
//   - Opposite value-area break.
//   - Time stop: position older than max_hold_bars M30 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double c1 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed single-bar read
   if(c1 <= 0.0)
      return false;

   const datetime broker_now = TimeCurrent();
   const long max_hold_secs = (long)strategy_max_hold_bars * 1800; // 1800s = M30

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Time stop: held for >= max_hold_bars M30 bars.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (long)(broker_now - open_time) >= max_hold_secs)
         return true;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(g_profile_valid)
        {
         if(ptype == POSITION_TYPE_BUY)
           {
            // Failure: close back inside VA (below prior VAH).
            if(c1 < g_prior_vah)
               return true;
            // Opposite VA break: price breaks the VAL side.
            if(c1 <= g_prior_val)
               return true;
           }
         else if(ptype == POSITION_TYPE_SELL)
           {
            // Failure: close back inside VA (above prior VAL).
            if(c1 > g_prior_val)
               return true;
            // Opposite VA break: price breaks the VAH side.
            if(c1 >= g_prior_vah)
               return true;
           }
        }
     }
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

   // FIRST on the closed-bar path: advance cached market-profile + session state.
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
