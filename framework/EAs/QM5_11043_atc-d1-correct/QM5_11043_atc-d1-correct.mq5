#property strict
#property version   "5.0"
#property description "QM5_11043 atc-d1-correct — Prior-Day High/Low Correction (mean reversion, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11043 atc-d1-correct
// -----------------------------------------------------------------------------
// Source: Alexander Arashkevich, Interview (ATC 2011), MQL5 Articles, 2012-01-20
//         https://www.mql5.com/en/articles/556
// Card: artifacts/cards_approved/QM5_11043_atc-d1-correct.md (g0_status APPROVED).
//
// Mechanics (H1 closed-bar evaluation, prior-D1 levels):
//   At each new H1 bar, read previous D1 high / low / range (D1 shift 1).
//   Long correction : the LAST closed H1 bar's LOW pierced below prior-D1-low by
//                     at least level_buffer pips, AND that bar CLOSED back above
//                     prior-D1-low -> enter LONG at next bar open.
//   Short correction: the LAST closed H1 bar's HIGH pierced above prior-D1-high by
//                     at least level_buffer pips, AND that bar CLOSED back below
//                     prior-D1-high -> enter SHORT at next bar open.
//   Take profit     : midpoint of the previous D1 range (mean-reversion target).
//   Stop loss       : below the piercing H1 bar low (long) / above the piercing
//                     H1 bar high (short) by sl_buffer pips, capped to a stop
//                     DISTANCE of sl_atr_cap_mult * ATR(14,H1); emergency hard cap
//                     at sl_atr_emergency_mult * ATR(14,H1).
//   Early exit      : an opposite correction setup closes the open position
//                     (QM_EXIT_OPPOSITE_SIGNAL) — handled in Strategy_ExitSignal.
//   Time exit       : end-of-day — flat outside [session_start, session_end] broker
//                     hours (also the no-trade window).
//   One trade per SIDE per symbol per DAY (latched on broker calendar day).
//   Regime gate     : skip the day if prior-D1 range < ATR(20,D1) * range_floor_mult.
//   Spread guard    : fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                     wide spread > spread_pct_of_stop of the stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11043;
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
input int    strategy_level_buffer_pips    = 5;     // min pierce beyond prior-D1 level (pips)
input int    strategy_sl_buffer_pips       = 10;    // SL buffer beyond piercing-bar extreme (pips)
input int    strategy_atr_period_h1        = 14;    // ATR period on H1 for SL caps
input double strategy_sl_atr_cap_mult      = 1.5;   // stop distance capped to mult * ATR(14,H1)
input double strategy_sl_atr_emergency_mult= 2.0;   // hard emergency max stop distance = mult * ATR
input int    strategy_atr_period_d1        = 20;    // ATR period on D1 for the range-regime filter
input double strategy_range_floor_mult     = 0.5;   // skip day if prior-D1 range < ATR(20,D1)*mult
input int    strategy_session_start_hour   = 6;     // broker-hour: first hour trading allowed
input int    strategy_session_end_hour     = 20;    // broker-hour: trading/holding ends (flat after)
input double strategy_spread_pct_of_stop   = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope per-side daily latch — one trade per side per symbol per day.
// Stores the broker calendar day (yyyy*10000+mm*100+dd) of the last entry.
// -----------------------------------------------------------------------------
long g_last_long_day  = 0;
long g_last_short_day = 0;

long BrokerCalendarDay(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return (long)dt.year * 10000 + (long)dt.mon * 100 + (long)dt.day;
  }

bool InSession(const datetime broker_time)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_time, dt);
   return (dt.hour >= strategy_session_start_hour && dt.hour < strategy_session_end_hour);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: outside the broker session window OR genuinely wide
// spread. Fail-OPEN on .DWX zero modeled spread (never block on zero spread).
bool Strategy_NoTradeFilter()
  {
   if(!InSession(TimeCurrent()))
      return true; // outside [start,end) broker hours — no new trades, hold disallowed

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — defer

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period_h1, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate
   const double stop_distance = strategy_sl_atr_cap_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Detect a long correction setup on the LAST closed H1 bar (shift 1) against the
// prior-D1 low. Returns true and fills the piercing low used for the SL.
bool DetectLongSetup(const double prior_d1_low, double &pierce_low_out)
  {
   if(prior_d1_low <= 0.0)
      return false;
   const double h1_low_1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double h1_close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(h1_low_1 <= 0.0 || h1_close_1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_level_buffer_pips);
   // Pierced below prior-D1 low by >= buffer, then closed back above the level.
   if(h1_low_1 <= prior_d1_low - buffer && h1_close_1 > prior_d1_low)
     {
      pierce_low_out = h1_low_1;
      return true;
     }
   return false;
  }

// Detect a short correction setup on the LAST closed H1 bar against prior-D1 high.
bool DetectShortSetup(const double prior_d1_high, double &pierce_high_out)
  {
   if(prior_d1_high <= 0.0)
      return false;
   const double h1_high_1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double h1_close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(h1_high_1 <= 0.0 || h1_close_1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_level_buffer_pips);
   // Pierced above prior-D1 high by >= buffer, then closed back below the level.
   if(h1_high_1 >= prior_d1_high + buffer && h1_close_1 < prior_d1_high)
     {
      pierce_high_out = h1_high_1;
      return true;
     }
   return false;
  }

// Cap a raw stop DISTANCE to [<= cap_mult*ATR], with a hard emergency ceiling.
double CapStopDistance(const double raw_distance, const double atr_value)
  {
   double dist = raw_distance;
   const double cap = strategy_sl_atr_cap_mult * atr_value;
   const double emergency = strategy_sl_atr_emergency_mult * atr_value;
   if(cap > 0.0 && dist > cap)
      dist = cap;
   if(emergency > 0.0 && dist > emergency)
      dist = emergency;   // emergency >= cap by default, kept as an explicit hard ceiling
   return dist;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Previous D1 levels (closed daily bar, shift 1) ---
   const double prior_d1_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   const double prior_d1_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: single closed-bar read
   if(prior_d1_high <= 0.0 || prior_d1_low <= 0.0 || prior_d1_high <= prior_d1_low)
      return false;
   const double prior_d1_range = prior_d1_high - prior_d1_low;
   const double prior_d1_mid   = prior_d1_low + prior_d1_range * 0.5;

   // --- Regime gate: skip narrow-range days (prior range vs ATR(20,D1)) ---
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(atr_d1 <= 0.0)
      return false;
   if(prior_d1_range < atr_d1 * strategy_range_floor_mult)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period_h1, 1);
   if(atr_h1 <= 0.0)
      return false;

   const datetime broker_now = TimeCurrent();
   const long today = BrokerCalendarDay(broker_now);
   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);

   // --- LONG correction ---
   double pierce_low = 0.0;
   if(g_last_long_day != today && DetectLongSetup(prior_d1_low, pierce_low))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Raw SL = below piercing low by sl_buffer; cap the DISTANCE to ATR limits.
      double raw_sl_price = pierce_low - sl_buffer;
      double raw_distance = entry - raw_sl_price;
      if(raw_distance <= 0.0)
         return false;
      const double capped = CapStopDistance(raw_distance, atr_h1);
      const double sl = QM_TM_NormalizePrice(_Symbol, entry - capped);
      // TP = prior-day midpoint (mean-reversion target). Only valid if above entry.
      if(prior_d1_mid <= entry)
         return false;
      const double tp = QM_TM_NormalizePrice(_Symbol, prior_d1_mid);
      if(sl <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "atc_d1_long_correction";
      g_last_long_day = today;
      return true;
     }

   // --- SHORT correction ---
   double pierce_high = 0.0;
   if(g_last_short_day != today && DetectShortSetup(prior_d1_high, pierce_high))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double raw_sl_price = pierce_high + sl_buffer;
      double raw_distance = raw_sl_price - entry;
      if(raw_distance <= 0.0)
         return false;
      const double capped = CapStopDistance(raw_distance, atr_h1);
      const double sl = QM_TM_NormalizePrice(_Symbol, entry + capped);
      if(prior_d1_mid >= entry)
         return false;
      const double tp = QM_TM_NormalizePrice(_Symbol, prior_d1_mid);
      if(sl <= entry || tp >= entry || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "atc_d1_short_correction";
      g_last_short_day = today;
      return true;
     }

   return false;
  }

// Fixed SL/TP only; no trailing/break-even in this mean-reversion strategy.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: (a) end-of-day time exit (outside the session window);
// (b) opposite correction setup fires against the open position.
// `is_new_bar` is latched ONCE in OnTick (QM_IsNewBar is single-consume per tick).
bool Strategy_ExitSignal(const bool is_new_bar)
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // (a) Time exit — flat outside the broker session window.
   if(!InSession(TimeCurrent()))
      return true;

   // (b) Opposite-setup early exit — evaluate only on a fresh closed bar.
   if(!is_new_bar)
      return false;

   const double prior_d1_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   const double prior_d1_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: single closed-bar read
   if(prior_d1_high <= 0.0 || prior_d1_low <= 0.0)
      return false;

   // Determine current position direction for this magic.
   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   double tmp = 0.0;
   if(have_long && DetectShortSetup(prior_d1_high, tmp))
      return true;  // opposite (short) correction while long
   if(have_short && DetectLongSetup(prior_d1_low, tmp))
      return true;  // opposite (long) correction while short

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

   // QM_IsNewBar() is single-consume per tick — latch ONCE and reuse for both the
   // opposite-setup exit and the entry gate below.
   const bool nb = QM_IsNewBar();

   // Per-tick: discretionary exit (time stop / opposite setup). Separate from SL/TP.
   // Evaluated BEFORE the no-trade filter so an end-of-session exit always fires.
   if(Strategy_ExitSignal(nb))
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

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   // Per-closed-bar: entry-signal evaluation (reuse the latched new-bar flag).
   if(!nb)
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
