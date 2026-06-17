#property strict
#property version   "5.0"
#property description "QM5_11014 the5ers-mprof-va — Market Profile Value-Area Rejection (M30, intraday MR)"

#include <QM/QM_Common.mqh>
#include <QM/QM_DSTAware.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11014 the5ers-mprof-va
// -----------------------------------------------------------------------------
// Source: The5ers blog "Market Profile Indicator for MT5"
//         (artifacts/cards_approved/QM5_11014_the5ers-mprof-va.md, g0_status APPROVED).
//
// Mechanic (M30, prior-session value-area rejection, intraday mean-reversion):
//   Market Profile is built from the symbol's OWN intraday M30 bars over the
//   PRIOR completed broker-time trading day. Tick volume is the volume proxy
//   (true exchange volume is not required; this is a documented porting limit).
//   The price-histogram is bounded + deterministic, recomputed ONCE per new
//   broker-day on the closed-bar gate, and cached in file scope.
//
//   Prior-session levels:  POC (highest-volume bucket), VAH / VAL (70% value
//   area expanded symmetrically around the POC bucket).
//
//   Long rejection (closed M30 bar, during London/NY sessions):
//     - current session traded BELOW prior VAL,
//     - latest closed M30 bar CLOSES back above prior VAL,
//     - bar low at least rejection_depth_atr*ATR below VAL (failed downside probe),
//     - close below prior POC (room to target value).
//   Short rejection: mirror around VAH.
//   Entry at next M30 open (framework fills market at send), one position/magic.
//
//   Exit:
//     - Primary TP: prior-session POC (capped at tp_cap_r * R from entry).
//     - Failure exit: long closes if M30 closes below prior VAL; short closes if
//       M30 closes above prior VAH.
//     - End-of-day exit: flatten eod_flatten_min before NY close.
//   Stop:
//     - Long: rejection-bar low - sl_atr_mult*ATR.  Short: high + sl_atr_mult*ATR.
//
//   Filters: skip if prior value-area width < va_min_atr*ATR or > va_max_atr*ATR;
//   skip if price gapped through VAH/VAL by > gap_max_atr*ATR; news blackout via
//   the framework; one position per magic, no pyramiding.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// .DWX invariants honoured: fail-OPEN spread (never block on zero modeled
// spread); no swap gate; sessions expressed in BROKER time via QM_BrokerToUTC /
// QM_UTCToBroker; gapless-CFD logic references prior CLOSE-derived levels, not a
// real overnight gap; no external macro/profile feed — the profile is computed
// from the symbol's own bars only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11014;
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
// --- Market-profile / value-area construction ---
input double strategy_value_area_pct     = 70.0;   // value-area coverage percent (P3 sweep: 68/70/75)
input int    strategy_va_bucket_ticks    = 5;      // price-bucket size, in symbol ticks (point granularity)
input int    strategy_va_max_buckets     = 2000;   // hard cap on histogram buckets (bounded loop guard)
// --- ATR (filter / stop / probe depth) ---
input int    strategy_atr_period         = 14;     // M30 ATR period
input double strategy_rejection_depth_atr = 0.25;  // min probe depth beyond VAL/VAH (P3: 0.15/0.25/0.40)
input double strategy_sl_atr_mult        = 0.5;    // SL buffer beyond rejection-bar low/high, in ATR
input double strategy_tp_cap_r           = 2.0;    // cap POC target at this R-multiple (P3: 1.5/2.0)
// --- Value-area width gating (in ATR units) ---
input double strategy_va_min_atr         = 1.0;    // skip if VA width < this * ATR
input double strategy_va_max_atr         = 6.0;    // skip if VA width > this * ATR
input double strategy_gap_max_atr        = 2.0;    // skip if price gapped through VAH/VAL by > this * ATR
// --- Sessions (BROKER time hours; London/NY trading window + EOD flatten) ---
input int    strategy_session_start_hour = 9;      // London open ~09:00 broker (08:00 UTC)
input int    strategy_session_end_hour   = 22;     // through NY into broker EOD
input int    strategy_ny_close_hour_broker = 23;   // broker-time NY close hour (~23:00)
input int    strategy_eod_flatten_min    = 30;     // flatten this many minutes before NY close
input double strategy_spread_pct_of_stop = 25.0;   // skip only a genuinely wide spread (% of stop dist)

// -----------------------------------------------------------------------------
// File-scope cached state — advanced once per new broker-day.
// -----------------------------------------------------------------------------
double   g_prior_vah   = 0.0;   // prior-session value-area high
double   g_prior_val   = 0.0;   // prior-session value-area low
double   g_prior_poc   = 0.0;   // prior-session point of control
double   g_prior_va_width = 0.0;
bool     g_profile_valid  = false;
datetime g_profile_day    = 0;  // broker-time midnight of the day the cache is FOR (today)

// Current-session traded extremes since today's session start (broker time).
double   g_sess_high   = 0.0;
double   g_sess_low    = 0.0;
datetime g_sess_day    = 0;     // broker-time midnight of the active session

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

   // First pass over prior-day M30 bars: find price range + total volume.
   // perf-allowed: bespoke market-profile build, gated to once per broker-day.
   const int total_bars = Bars(_Symbol, PERIOD_M30);
   if(total_bars <= 0)
      return false;

   double day_low  = 0.0;
   double day_high = 0.0;
   bool   have_range = false;
   int    bars_scanned = 0;

   // Scan a bounded window of recent M30 bars (a broker-day has <=48 M30 bars;
   // 200 covers weekends/holidays gaps comfortably). Stop once older than prior.
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

   // Second pass: distribute each M30 bar's tick volume evenly across the price
   // buckets it spans (TPO/price-histogram proxy). Bounded by bars*buckets-span.
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
   // Bounded: at most n_buckets iterations.
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

// Advance cached state once per closed bar. Rebuilds profile on a new broker-day
// and resets the current-session traded extremes.
void AdvanceState_OnNewBar()
  {
   const datetime broker_now = TimeCurrent();
   const datetime day_start  = BrokerDayStart(broker_now);

   // New broker-day → rebuild the prior-session profile + reset session extremes.
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
      g_sess_day = day_start;
      g_sess_high = 0.0;
      g_sess_low  = 0.0;
     }

   // Track current-session traded extremes from the last closed M30 bar.
   const double hi = iHigh(_Symbol, PERIOD_M30, 1); // perf-allowed: single closed bar
   const double lo = iLow(_Symbol, PERIOD_M30, 1);  // perf-allowed
   if(hi > 0.0 && lo > 0.0)
     {
      if(g_sess_high <= 0.0 || hi > g_sess_high) g_sess_high = hi;
      if(g_sess_low  <= 0.0 || lo < g_sess_low)  g_sess_low  = lo;
     }
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

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Closed-bar entry (caller guarantees QM_IsNewBar() == true).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_profile_valid)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Value-area width filter (in ATR units) ---
   if(g_prior_va_width < strategy_va_min_atr * atr_value)
      return false;
   if(g_prior_va_width > strategy_va_max_atr * atr_value)
      return false;

   // Last closed M30 bar OHLC (perf-allowed single-bar reads).
   const double c1 = iClose(_Symbol, PERIOD_M30, 1);
   const double h1 = iHigh(_Symbol, PERIOD_M30, 1);
   const double l1 = iLow(_Symbol, PERIOD_M30, 1);
   if(c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return false;

   const double probe = strategy_rejection_depth_atr * atr_value;
   const double gap_cap = strategy_gap_max_atr * atr_value;

   // --- LONG rejection setup ---
   //   session traded below prior VAL, bar closes back above VAL, failed downside
   //   probe of >= probe below VAL, close below prior POC, gap through VAL bounded.
   const bool sess_below_val = (g_sess_low > 0.0 && g_sess_low < g_prior_val);
   if(sess_below_val &&
      c1 > g_prior_val &&
      l1 <= (g_prior_val - probe) &&
      c1 < g_prior_poc &&
      (g_prior_val - l1) <= gap_cap)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop below the rejection-bar low by sl_atr_mult*ATR.
      double sl = QM_StopRulesNormalizePrice(_Symbol, l1 - strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl >= entry)
         return false;
      // TP at prior POC, capped at tp_cap_r * R.
      const double r_dist = entry - sl;
      double tp = g_prior_poc;
      const double cap_tp = entry + strategy_tp_cap_r * r_dist;
      if(tp > cap_tp)
         tp = cap_tp;
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "mprof_va_long_reject";
      return true;
     }

   // --- SHORT rejection setup (mirror around VAH) ---
   const bool sess_above_vah = (g_sess_high > 0.0 && g_sess_high > g_prior_vah);
   if(sess_above_vah &&
      c1 < g_prior_vah &&
      h1 >= (g_prior_vah + probe) &&
      c1 > g_prior_poc &&
      (h1 - g_prior_vah) <= gap_cap)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = QM_StopRulesNormalizePrice(_Symbol, h1 + strategy_sl_atr_mult * atr_value);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double r_dist = sl - entry;
      double tp = g_prior_poc;
      const double cap_tp = entry - strategy_tp_cap_r * r_dist;
      if(tp < cap_tp)
         tp = cap_tp;
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(tp >= entry || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "mprof_va_short_reject";
      return true;
     }

   return false;
  }

// Fixed SL/TP from entry; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: value-area failure exit + end-of-day flatten.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();

   // End-of-day flatten: within eod_flatten_min minutes before NY close.
   const int h = BrokerHour(broker_now);
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   const int mins_to_close = (strategy_ny_close_hour_broker - h) * 60 - dt.min;
   if(mins_to_close <= strategy_eod_flatten_min && mins_to_close >= 0)
      return true;

   if(!g_profile_valid)
      return false;

   // Value-area failure exit: close direction depends on the open position.
   const double c1 = iClose(_Symbol, PERIOD_M30, 1); // perf-allowed single-bar read
   if(c1 <= 0.0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && c1 < g_prior_val)
         return true;   // long failure: M30 closed below prior VAL
      if(ptype == POSITION_TYPE_SELL && c1 > g_prior_vah)
         return true;   // short failure: M30 closed above prior VAH
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
