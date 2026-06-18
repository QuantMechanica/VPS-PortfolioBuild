#property strict
#property version   "5.0"
#property description "QM5_1309 bressert-dss-slope-h1 — Bressert DSS slope-change second-derivative trigger (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1309 bressert-dss-slope-h1
// -----------------------------------------------------------------------------
// Source: FF Trading-Systems "Bressert DSS" cluster / Walter Bressert 1991
//   "The Power of Oscillator/Cycle Combinations" + S&C articles.
// Card: artifacts/cards_approved/QM5_1309_bressert-dss-slope-h1.md (g0 APPROVED).
//
// Indicator — Bressert Double-Smoothed Stochastic (DSS), computed IN-EA from
// bounded closed-bar OHLC (perf-allowed, cached once per new H1 bar):
//   stage 1  RawK = stochastic(close,high,low, dss_stoch1) over a window
//   stage 2  K1   = EMA(RawK, dss_ema1)
//   stage 3  RawK2= stochastic(K1 series, dss_stoch2)
//   stage 4  DSS  = EMA(RawK2, dss_ema2)              (0..100 bounded)
//
// We retain the last (dss_stoch2 + window) DSS values so the second stochastic
// + final EMA see a real series. From that we cache DSS at the current closed
// bar (idx 1) and the two prior bars (idx 2, idx 3) to form the slope and the
// slope-of-slope (second-derivative sign change).
//
// Trigger EVENT (the ONLY event — avoids the two-cross zero-trade trap):
//   dDSS = DSS[t] - DSS[t-1]
//   UP   sign-change:  dDSS[prev] <= 0  AND  dDSS[now] > 0   (turning up)
//   DOWN sign-change:  dDSS[prev] >= 0  AND  dDSS[now] < 0   (turning down)
//
// STATES (not events): EMA(200) trend bias, DSS extreme zone, price-agree bar,
// and a re-arm latch (DSS must cross back through 50 before a same-direction
// flip re-fires).
//
// Entry BUY : close>EMA200  AND  DSS[prev]<os_zone  AND  UP sign-change
//             AND close[now]>close[prev]  AND long re-armed.
// Entry SELL: mirror with EMA200, ob_zone, DOWN sign-change, close[now]<close[prev].
// Exit      : opposite slope-flip; OR cycle-top/bottom zone roll-over; OR ATR TP;
//             OR EMA-bias flip. (Hard ATR SL set at entry, no widening.)
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1309;
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
input int    strategy_dss_stoch1        = 13;     // stage-1 raw stochastic window (P3 10-18)
input int    strategy_dss_ema1          = 5;      // stage-2 EMA smoothing (P3 3-8)
input int    strategy_dss_stoch2        = 8;      // stage-3 second stochastic window (P3 6-13)
input int    strategy_dss_ema2          = 3;      // stage-4 final EMA smoothing
input int    strategy_ema_bias_period   = 200;    // H1 trend-bias EMA
input double strategy_dss_os_zone       = 25.0;   // oversold zone gate for BUY (P3 20-35)
input double strategy_dss_ob_zone       = 75.0;   // overbought zone gate for SELL (P3 65-80)
input double strategy_dss_top_zone      = 80.0;   // cycle-top roll-over exit for BUY
input double strategy_dss_bottom_zone   = 20.0;   // cycle-bottom roll-over exit for SELL
input double strategy_dss_rearm_level   = 50.0;   // DSS must re-cross this to re-arm
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR (P3 1.0-2.5)
input double strategy_tp_atr_mult       = 2.5;    // target distance = mult * ATR (P3 1.5-4.0)
input int    strategy_session_start_h   = 6;      // session start, broker hour inclusive
input int    strategy_session_end_h     = 21;     // session end, broker hour exclusive
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached DSS state (advanced once per closed H1 bar)
// -----------------------------------------------------------------------------
// DSS at the three most recent CLOSED bars: idx1 = shift 1 (current closed),
// idx2 = shift 2, idx3 = shift 3. Slope/2nd-derivative derive from these.
double g_dss1 = 0.0;   // DSS at shift 1
double g_dss2 = 0.0;   // DSS at shift 2
double g_dss3 = 0.0;   // DSS at shift 3
bool   g_dss_ready = false;

// Re-arm latches: a same-direction flip may only fire once until DSS re-crosses
// the re-arm level. Armed at init; consumed on entry; re-armed by the 50-cross.
bool   g_long_armed  = true;
bool   g_short_armed = true;

// -----------------------------------------------------------------------------
// DSS computation helpers (closed-bar, bounded — perf-allowed raw OHLC reads)
// -----------------------------------------------------------------------------

// Stochastic %K over [high,low] of `period` bars ending at bar `end_shift`,
// using close[end_shift]. Returns 0..100; 50.0 on a degenerate flat range.
double DSS_RawStochAtShift(const int period, const int end_shift)
  {
   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   for(int s = end_shift; s < end_shift + period; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar
      const double l = iLow(_Symbol, _Period, s);
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   const double c = iClose(_Symbol, _Period, end_shift);
   const double rng = hh - ll;
   if(rng <= 0.0)
      return 50.0;
   return 100.0 * (c - ll) / rng;
  }

// EMA of an explicit value series (newest-first arr[0]) over `period`.
double DSS_EMAofSeries(const double &arr[], const int count, const int period)
  {
   if(count <= 0)
      return 0.0;
   const double k = 2.0 / (period + 1.0);
   // Seed with the oldest sample, walk forward to the newest (arr[0]).
   double ema = arr[count - 1];
   for(int i = count - 2; i >= 0; --i)
      ema = arr[i] * k + ema * (1.0 - k);
   return ema;
  }

// Compute the fully-smoothed DSS value for the bar at `end_shift`.
// stage1 RawK series -> stage2 EMA(K1) series -> stage3 stochastic of K1 ->
// stage4 EMA -> DSS. All series are bounded by the configured windows.
double DSS_ComputeAtShift(const int end_shift)
  {
   const int p1 = strategy_dss_stoch1;
   const int p2 = strategy_dss_ema1;
   const int p3 = strategy_dss_stoch2;
   const int p4 = strategy_dss_ema2;

   // We need K1 (EMA-smoothed RawK) over a window long enough for stage-3
   // stochastic (p3 bars) plus stage-4 EMA settle (p4 extra). Build that many
   // K1 samples, newest-first.
   const int k1_count = p3 + p4 + 4;            // small settle margin

   double k1[];
   ArrayResize(k1, k1_count);

   // For each K1 sample we EMA-smooth a RawK series of length (p2 + settle).
   const int rawk_len = p2 + 6;                 // EMA(p2) settle margin
   double rawk[];
   ArrayResize(rawk, rawk_len);

   for(int j = 0; j < k1_count; ++j)
     {
      // K1[j] corresponds to closed-bar shift (end_shift + j).
      const int base = end_shift + j;
      for(int r = 0; r < rawk_len; ++r)
         rawk[r] = DSS_RawStochAtShift(p1, base + r);   // newest-first
      k1[j] = DSS_EMAofSeries(rawk, rawk_len, p2);
     }

   // stage-3: stochastic of the K1 series over p3 (its own high/low/close).
   double rawk2[];
   const int rawk2_len = p4 + 6;                 // EMA(p4) settle margin
   ArrayResize(rawk2, rawk2_len);

   for(int m = 0; m < rawk2_len; ++m)
     {
      // stochastic of K1 ending at K1 index m over p3 samples.
      double hh = -DBL_MAX;
      double ll =  DBL_MAX;
      for(int s = m; s < m + p3; ++s)
        {
         const double v = k1[s];
         if(v > hh) hh = v;
         if(v < ll) ll = v;
        }
      const double cc = k1[m];
      const double rng = hh - ll;
      rawk2[m] = (rng <= 0.0) ? 50.0 : 100.0 * (cc - ll) / rng;
     }

   // stage-4: final EMA -> DSS.
   return DSS_EMAofSeries(rawk2, rawk2_len, p4);
  }

// Advance cached DSS for the three most recent closed bars. Called ONCE per new
// closed H1 bar from OnTick (after the QM_IsNewBar gate). No internal timestamp
// gate. Bounded work: O((p3+p4)*(p2)*(p1)) raw reads, all on closed bars.
void AdvanceState_OnNewBar()
  {
   g_dss1 = DSS_ComputeAtShift(1);
   g_dss2 = DSS_ComputeAtShift(2);
   g_dss3 = DSS_ComputeAtShift(3);
   g_dss_ready = true;

   // Re-arm logic: once DSS has crossed back through the re-arm level we permit
   // the next same-direction flip. Long re-arms when DSS climbs back above the
   // level from below; short re-arms when DSS falls back below from above.
   if(g_dss2 < strategy_dss_rearm_level && g_dss1 >= strategy_dss_rearm_level)
      g_long_armed = true;
   if(g_dss2 > strategy_dss_rearm_level && g_dss1 <= strategy_dss_rearm_level)
      g_short_armed = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + spread guard.
// Fail-OPEN on .DWX zero modeled spread; only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   // Session window in broker time (card: 06:00-21:00 broker).
   const datetime broker_now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   if(strategy_session_start_h <= strategy_session_end_h)
     {
      if(dt.hour < strategy_session_start_h || dt.hour >= strategy_session_end_h)
         return true;
     }
   else
     {
      // wrap-around window (not used by default, kept robust)
      if(dt.hour < strategy_session_start_h && dt.hour >= strategy_session_end_h)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate) and that
// AdvanceState_OnNewBar() already ran this bar (DSS cached).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_dss_ready)
      return false;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   if(ema_bias <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Slope at the current closed bar and the prior bar.
   const double dDSS_now  = g_dss1 - g_dss2;   // slope into the current closed bar
   const double dDSS_prev = g_dss2 - g_dss3;   // slope into the prior bar

   // --- BUY: bullish bias + oversold zone + UP slope sign-change + price agrees ---
   const bool up_flip = (dDSS_prev <= 0.0 && dDSS_now > 0.0);   // single EVENT
   if(close1 > ema_bias &&            // STATE: trend bias
      g_dss2 < strategy_dss_os_zone &&// STATE: extreme oversold zone (prior bar)
      up_flip &&                      // EVENT: the only trigger
      close1 > close2 &&              // STATE: price agrees with the flip
      g_long_armed)                   // STATE: re-arm latch
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bressert_dss_slope_up";
      g_long_armed = false;          // consume the arm until DSS re-crosses 50
      return true;
     }

   // --- SELL: bearish bias + overbought zone + DOWN slope sign-change + price agrees ---
   const bool down_flip = (dDSS_prev >= 0.0 && dDSS_now < 0.0);  // single EVENT
   if(close1 < ema_bias &&
      g_dss2 > strategy_dss_ob_zone &&
      down_flip &&
      close1 < close2 &&
      g_short_armed)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bressert_dss_slope_down";
      g_short_armed = false;
      return true;
     }

   return false;
  }

// No active trailing — the fixed ATR stop/target plus the rule-based exits in
// Strategy_ExitSignal manage the position.
void Strategy_ManageOpenPosition()
  {
  }

// Rule exits (closed-bar): opposite slope-flip, cycle roll-over in the extreme
// zone, or EMA-bias flip against the open position.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(!g_dss_ready)
      return false;

   // Determine the side of the open position for this magic.
   const int magic = QM_FrameworkMagic();
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }
   if(!have_long && !have_short)
      return false;

   const double ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed single read

   const double dDSS_now  = g_dss1 - g_dss2;
   const double dDSS_prev = g_dss2 - g_dss3;
   const bool up_flip   = (dDSS_prev <= 0.0 && dDSS_now > 0.0);
   const bool down_flip = (dDSS_prev >= 0.0 && dDSS_now < 0.0);

   if(have_long)
     {
      // Opposite slope-flip.
      if(down_flip)
         return true;
      // Cycle-top roll-over: DSS reached the top zone then turned down.
      if(g_dss2 >= strategy_dss_top_zone && dDSS_now < 0.0)
         return true;
      // EMA-bias flip against the long.
      if(ema_bias > 0.0 && close1 > 0.0 && close1 < ema_bias)
         return true;
     }

   if(have_short)
     {
      if(up_flip)
         return true;
      if(g_dss2 <= strategy_dss_bottom_zone && dDSS_now > 0.0)
         return true;
      if(ema_bias > 0.0 && close1 > 0.0 && close1 > ema_bias)
         return true;
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

   g_dss_ready  = false;
   g_long_armed = true;
   g_short_armed = true;

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

   // Advance cached DSS state ONCE per closed bar, then run the entry gate.
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
