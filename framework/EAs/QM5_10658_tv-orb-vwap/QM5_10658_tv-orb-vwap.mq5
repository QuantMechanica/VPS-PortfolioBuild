#property strict
#property version   "5.0"
#property description "QM5_10658 tv-orb-vwap — ORB breakout with session VWAP, tick-volume and candle-strength filters"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10658_tv-orb-vwap
// -----------------------------------------------------------------------------
// Source: luiscaballero, "ORB Breakout Strategy with VWAP and Volume Filters",
//   TradingView open-source (d11962d5). Card: cards_approved/QM5_10658_tv-orb-vwap.md
//
// Mechanic (M5 baseline):
//   - Build the opening range (OR) from the first N M5 bars after session open.
//   - Session window is BROKER time, DST-aware (US cash open 09:30 ET = broker
//     ~16:30; configurable as ET minutes-of-day, converted per-bar via UTC->broker).
//   - Session VWAP is accumulated from M5 typical-price * tick-volume, RESET at
//     session start each day (in broker time). Cached per closed bar.
//   - Long: closed-bar close > OR high, close above VWAP, VWAP slope > 0 over
//     lookback, breakout-bar tick-volume > rolling-avg * mult, candle close in
//     upper portion of bar range (>= strength). Short mirrors below OR low.
//   - Stop = opposite OR side. TP = tp_mult * OR range. Force flat at session end.
//   - One entry per side per session; max trades/day cap. Framework sizes lots.
//
// Intraday: ALL session state (OR, VWAP, volume baseline) is cached per closed
// bar in AdvanceState_OnNewBar(). The per-tick path is O(1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10658;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Session is expressed in EXCHANGE-LOCAL (ET) minutes-of-day; converted to
// broker time per bar so it stays correct across US DST. For a London-open
// variant on GER40, set these to the broker-equivalent ET-clock values via the
// setfile (the conversion below assumes the session reference clock is US ET).
input int    InpSessionOpenMinutesET    = 570;    // 09:30 ET (9*60+30)
input int    InpSessionEndMinutesET     = 720;    // 12:00 ET — force flat after this
input int    InpOpeningRangeBars        = 3;      // first N M5 bars => 15 min OR
input int    InpVwapSlopeLookback       = 5;      // bars for VWAP slope sign
input int    InpVolAvgLookback          = 20;     // rolling tick-volume baseline window
input double InpVolMult                 = 1.0;    // breakout-bar vol > baseline*mult
input double InpCandleStrength          = 0.70;   // close position in bar range [0..1]
input double InpTpRangeMult             = 1.0;    // TP = mult * OR range
input int    InpMaxTradesPerDay         = 2;      // cap entries per session/day

// -----------------------------------------------------------------------------
// File-scope cached session state (advanced once per closed bar)
// -----------------------------------------------------------------------------
int      g_session_day        = -1;       // broker calendar day-of-year currently tracked
double   g_or_high            = 0.0;
double   g_or_low             = 0.0;
bool     g_or_ready          = false;    // OR fully built for this session
int      g_or_bars_counted   = 0;        // M5 bars accumulated into OR
double   g_vwap_cum_pv        = 0.0;      // cumulative typical*volume
double   g_vwap_cum_vol       = 0.0;      // cumulative volume
double   g_vwap_now           = 0.0;      // current session VWAP
double   g_vwap_hist[];                   // recent VWAP values for slope (circular not needed; small)
int      g_vwap_hist_count    = 0;
int      g_trades_today       = 0;
bool     g_long_taken        = false;
bool     g_short_taken       = false;
datetime g_last_bar_session_open = 0;     // broker time of session open for current day

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Broker minute-of-day for the session open on the broker-calendar day of `bar_open_broker`.
// We convert an ET minutes-of-day reference to broker minutes-of-day using the
// DST state at that bar. ET = UTC-5 (standard) / UTC-4 (DST); broker = UTC+2/+3.
// Net broker-minus-ET offset is +7h whether or not US DST is active (both clocks
// shift together), so broker_minutes = et_minutes + 7*60, normalized to [0,1440).
int SessionMinutesBroker(const int et_minutes)
  {
   int m = et_minutes + 7 * 60;
   while(m >= 1440)
      m -= 1440;
   while(m < 0)
      m += 1440;
   return m;
  }

int BrokerMinutesOfDay(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.hour * 60 + dt.min;
  }

int BrokerDayOfYear(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   return dt.day_of_year;
  }

void ResetSessionState(const datetime bar_open_broker)
  {
   g_session_day      = BrokerDayOfYear(bar_open_broker);
   g_or_high          = 0.0;
   g_or_low           = 0.0;
   g_or_ready         = false;
   g_or_bars_counted  = 0;
   g_vwap_cum_pv      = 0.0;
   g_vwap_cum_vol     = 0.0;
   g_vwap_now         = 0.0;
   g_vwap_hist_count  = 0;
   ArrayResize(g_vwap_hist, 0);
   g_trades_today     = 0;
   g_long_taken       = false;
   g_short_taken      = false;
  }

void PushVwap(const double v)
  {
   const int keep = MathMax(InpVwapSlopeLookback + 2, 8);
   int n = ArraySize(g_vwap_hist);
   if(n < keep)
     {
      ArrayResize(g_vwap_hist, n + 1);
      g_vwap_hist[n] = v;
     }
   else
     {
      for(int i = 0; i < keep - 1; ++i)
         g_vwap_hist[i] = g_vwap_hist[i + 1];
      g_vwap_hist[keep - 1] = v;
     }
   g_vwap_hist_count++;
  }

// VWAP slope sign over the configured lookback: +1 rising, -1 falling, 0 flat/insufficient.
int VwapSlopeSign()
  {
   int n = ArraySize(g_vwap_hist);
   if(n < 2 || g_vwap_hist_count <= InpVwapSlopeLookback)
      return 0;
   int back = MathMin(InpVwapSlopeLookback, n - 1);
   double now  = g_vwap_hist[n - 1];
   double prev = g_vwap_hist[n - 1 - back];
   if(now > prev)
      return +1;
   if(now < prev)
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// AdvanceState_OnNewBar — called ONCE per new closed bar (after QM_IsNewBar gate)
// Reads the LAST closed bar (shift 1) and advances OR / VWAP / volume state.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   const datetime bar_open_broker = iTime(_Symbol, _Period, 1);
   if(bar_open_broker <= 0)
      return;

   const int day_now      = BrokerDayOfYear(bar_open_broker);
   const int mod          = BrokerMinutesOfDay(bar_open_broker);
   const int sess_open_b  = SessionMinutesBroker(InpSessionOpenMinutesET);
   const int sess_end_b   = SessionMinutesBroker(InpSessionEndMinutesET);

   // New broker day OR first bar at/after session open of a fresh session -> reset.
   const bool in_session = (sess_open_b <= sess_end_b)
                           ? (mod >= sess_open_b && mod < sess_end_b)
                           : (mod >= sess_open_b || mod < sess_end_b);

   if(day_now != g_session_day)
      ResetSessionState(bar_open_broker);

   if(!in_session)
     {
      // Outside session: keep state but nothing to accumulate.
      return;
     }

   // --- session VWAP accumulation (typical price * tick volume) ---
   const double h = iHigh(_Symbol, _Period, 1);
   const double l = iLow(_Symbol, _Period, 1);
   const double c = iClose(_Symbol, _Period, 1);
   const double typ = (h + l + c) / 3.0;
   const double vol = (double)iVolume(_Symbol, _Period, 1);
   g_vwap_cum_pv  += typ * vol;
   g_vwap_cum_vol += vol;
   if(g_vwap_cum_vol > 0.0)
      g_vwap_now = g_vwap_cum_pv / g_vwap_cum_vol;
   PushVwap(g_vwap_now);

   // --- opening range build (first N in-session bars) ---
   if(!g_or_ready)
     {
      if(g_or_bars_counted == 0)
        {
         g_or_high = h;
         g_or_low  = l;
        }
      else
        {
         if(h > g_or_high) g_or_high = h;
         if(l < g_or_low)  g_or_low  = l;
        }
      g_or_bars_counted++;
      if(g_or_bars_counted >= InpOpeningRangeBars)
         g_or_ready = true;
     }
  }

// Rolling average tick-volume baseline over the prior InpVolAvgLookback closed bars
// (shifts 2..N+1; excludes the breakout bar at shift 1). O(N) once per new bar.
double VolBaseline()
  {
   int n = InpVolAvgLookback;
   if(n < 1) n = 1;
   double sum = 0.0;
   int cnt = 0;
   for(int s = 2; s <= n + 1; ++s)
     {
      double v = (double)iVolume(_Symbol, _Period, s);
      if(v <= 0.0)
         continue;
      sum += v;
      cnt++;
     }
   if(cnt == 0)
      return 0.0;
   return sum / (double)cnt;
  }

// Candle strength: fraction of range the close sits in.
//   long-strength  = (close - low) / (high - low)  -> 1 = strong bull close
//   short-strength = (high - close) / (high - low) -> 1 = strong bear close
double CandleClosePosition()
  {
   const double h = iHigh(_Symbol, _Period, 1);
   const double l = iLow(_Symbol, _Period, 1);
   const double c = iClose(_Symbol, _Period, 1);
   const double rng = h - l;
   if(rng <= 0.0)
      return 0.5;
   return (c - l) / rng; // 0..1
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading outside the session window (broker time, DST-aware). O(1).
bool Strategy_NoTradeFilter()
  {
   const datetime now_broker = TimeCurrent();
   const int mod = BrokerMinutesOfDay(now_broker);
   const int sess_open_b = SessionMinutesBroker(InpSessionOpenMinutesET);
   const int sess_end_b  = SessionMinutesBroker(InpSessionEndMinutesET);
   const bool in_session = (sess_open_b <= sess_end_b)
                           ? (mod >= sess_open_b && mod < sess_end_b)
                           : (mod >= sess_open_b || mod < sess_end_b);
   return !in_session;
  }

// New entry on the just-closed bar. Caller guarantees QM_IsNewBar()==true and
// AdvanceState_OnNewBar() has already run this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_or_ready)
      return false;
   if(g_trades_today >= InpMaxTradesPerDay)
      return false;
   if(g_vwap_now <= 0.0)
      return false;

   const double or_range = g_or_high - g_or_low;
   if(or_range <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   const double vol1   = (double)iVolume(_Symbol, _Period, 1);
   const double vol_base = VolBaseline();
   const bool vol_ok = (vol_base <= 0.0) ? true : (vol1 > vol_base * InpVolMult);
   const int slope = VwapSlopeSign();
   const double pos = CandleClosePosition(); // 0..1, close in range

   // LONG breakout
   if(!g_long_taken &&
      close1 > g_or_high &&
      close1 > g_vwap_now &&
      slope > 0 &&
      vol_ok &&
      pos >= InpCandleStrength)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = QM_StopRulesNormalizePrice(_Symbol, g_or_low);
      double tp = QM_StopRulesNormalizePrice(_Symbol, entry + InpTpRangeMult * or_range);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;       // market
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "orb_vwap_long";
      g_long_taken = true;
      g_trades_today++;
      return true;
     }

   // SHORT breakout
   if(!g_short_taken &&
      close1 < g_or_low &&
      close1 < g_vwap_now &&
      slope < 0 &&
      vol_ok &&
      (1.0 - pos) >= InpCandleStrength)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = QM_StopRulesNormalizePrice(_Symbol, g_or_high);
      double tp = QM_StopRulesNormalizePrice(_Symbol, entry - InpTpRangeMult * or_range);
      if(sl <= entry)
         return false;
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "orb_vwap_short";
      g_short_taken = true;
      g_trades_today++;
      return true;
     }

   return false;
  }

// No active trade management beyond SL/TP for this baseline (breakeven is P3).
void Strategy_ManageOpenPosition()
  {
  }

// Force flat at/after session end (broker time, DST-aware).
bool Strategy_ExitSignal()
  {
   const datetime now_broker = TimeCurrent();
   const int mod = BrokerMinutesOfDay(now_broker);
   const int sess_end_b = SessionMinutesBroker(InpSessionEndMinutesET);
   const int sess_open_b = SessionMinutesBroker(InpSessionOpenMinutesET);
   // Flat when outside the [open,end) session window.
   const bool in_session = (sess_open_b <= sess_end_b)
                           ? (mod >= sess_open_b && mod < sess_end_b)
                           : (mod >= sess_open_b || mod < sess_end_b);
   return !in_session;
  }

// Defer to central news filter.
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   ArrayResize(g_vwap_hist, 0);
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

   // Per-tick: discretionary exit (session-end force-flat). Runs before the
   // single-consume new-bar gate so it is O(1) and not starved.
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

   // Per-tick management (no-op for this baseline).
   Strategy_ManageOpenPosition();

   // Closed-bar gate — consume ONCE.
   if(!QM_IsNewBar())
      return;

   // Advance cached session state for the just-closed bar.
   AdvanceState_OnNewBar();

   QM_EquityStreamOnNewBar();

   // No-trade (session) filter after state advance.
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
