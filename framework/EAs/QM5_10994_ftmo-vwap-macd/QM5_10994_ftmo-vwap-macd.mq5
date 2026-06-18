#property strict
#property version   "5.0"
#property description "QM5_10994 ftmo-vwap-macd — Session VWAP bias + MACD confirmation (intraday, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10994 ftmo-vwap-macd
// -----------------------------------------------------------------------------
// Source: FTMO technical-indicator strategy article (source_id c11dc4d3-...).
// Card: artifacts/cards_approved/QM5_10994_ftmo-vwap-macd.md (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1; one position per symbol/magic):
//   Session VWAP : computed INTRADAY from THIS symbol's own bars, reset at the
//                  London session anchor. The anchor is derived in UTC via
//                  QM_BrokerToUTC(bar_open_broker_time) so the daily reset is
//                  DST-correct. Typical price (H+L+C)/3 weighted by tick volume
//                  accumulates from the anchor. NO external VWAP feed.
//   Long setup   : price > VWAP; last closed bar dipped to/below VWAP (low<=VWAP)
//                  but closed above it; MACD(12,26,9) bullish trigger within the
//                  last `macd_lookback` bars (line>signal having been <= , i.e.
//                  a fresh cross, OR histogram turned positive after >=3 negs).
//   Short setup  : mirror.
//   VWAP slope   : skip if |VWAP[1]-VWAP[8]| <= slope_atr_frac * ATR (flat).
//   Spread       : skip only spread > 1.5x 20-bar median spread (fail-open on .DWX 0 spread).
//   Session      : trade only inside the broker-time London+NY liquid window.
//   Stop         : long  = pullback swing low  - sl_atr_buffer * ATR(14)
//                  short = pullback swing high + sl_atr_buffer * ATR(14)
//   Take profit  : TP = tp_rr * R (R = |entry - stop|).
//   Exits        : (a) bar closes on the opposite side of VWAP after entry;
//                  (b) session end (outside trade window);
//                  (c) max-hold = exit after `max_hold_bars` M15 bars.
//
// Intraday discipline: VWAP/session state is advanced ONCE per closed bar inside
// Strategy_EntrySignal (the framework guarantees it is called once per new bar).
// The per-tick path (NoTradeFilter, ManageOpenPosition, ExitSignal) only reads
// cached file-scope state + current Bid/Ask + handle-pooled QM_* readers.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10994;
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
// --- MACD confirmation (12,26,9 default per card) ---
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_macd_lookback     = 3;      // bars to look back for the MACD trigger
// --- Session VWAP anchor (UTC hour of the London open; DST handled via UTC) ---
input int    strategy_vwap_anchor_utc_h = 7;      // London open ~07:00 UTC -> session reset anchor
// --- Trade window in BROKER time (London open ~09:00 broker to NY close ~23:00 broker) ---
input int    strategy_session_start_broker_h = 9;   // start hour (broker) inclusive
input int    strategy_session_end_broker_h   = 23;  // end hour (broker) exclusive
// --- Filters / stops / target ---
input int    strategy_atr_period        = 14;     // ATR period (slope filter + stop buffer)
input double strategy_slope_atr_frac    = 0.05;   // VWAP slope flat-zone (frac of ATR over 8 bars)
input int    strategy_swing_lookback    = 8;      // pullback swing extreme lookback (closed bars)
input double strategy_sl_atr_buffer     = 0.25;   // stop buffer beyond swing = mult * ATR
input double strategy_tp_rr             = 1.8;    // take-profit = tp_rr * R
input int    strategy_max_hold_bars     = 32;     // time-stop in M15 bars
input int    strategy_spread_lookback   = 20;     // median spread lookback (closed bars)
input double strategy_spread_median_mult = 1.5;   // skip if spread > mult * 20-bar median spread

// -----------------------------------------------------------------------------
// File-scope cached intraday state (advanced ONCE per closed bar).
// -----------------------------------------------------------------------------
datetime g_vwap_session_anchor = 0;     // UTC anchor of the current VWAP session
double   g_vwap_cum_pv         = 0.0;   // sum(typical_price * volume) since anchor
double   g_vwap_cum_v          = 0.0;   // sum(volume) since anchor
double   g_vwap_now            = 0.0;   // VWAP at the last closed bar (shift 1)
double   g_vwap_hist[];                 // ring of recent closed-bar VWAP values
int      g_vwap_hist_size      = 0;     // count of valid entries written
double   g_median_spread_points = 0.0;  // 20-bar closed-bar median spread in points
datetime g_entry_bar_time      = 0;     // bar-open time of the bar we entered on
int      g_entry_dir           = 0;     // +1 long / -1 short of the live position

// Return the UTC session anchor (start-of-London-session UTC) for a given UTC time.
datetime VWAP_AnchorForUTC(const datetime utc)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(utc, dt);
   datetime midnight_utc = utc - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   datetime anchor = midnight_utc + strategy_vwap_anchor_utc_h * 3600;
   // If the bar is before today's anchor, the session belongs to the prior day's
   // anchor (overnight pre-London bars roll into the previous session).
   if(utc < anchor)
      anchor -= 86400;
   return anchor;
  }

// Advance the session VWAP by ONE closed bar (shift 1). O(1). Resets accumulators
// when the closed bar crosses into a new session anchor.
void VWAP_AdvanceOnNewBar()
  {
   const datetime bar_broker = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_broker <= 0)
      return;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);
   const datetime anchor  = VWAP_AnchorForUTC(bar_utc);

   if(anchor != g_vwap_session_anchor)
     {
      // New session: explicit anchor reset.
      g_vwap_session_anchor = anchor;
      g_vwap_cum_pv = 0.0;
      g_vwap_cum_v  = 0.0;
     }

   const double h = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double l = iLow(_Symbol, _Period, 1);    // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   double v = (double)iTickVolume(_Symbol, _Period, 1); // tick volume proxy (no real-volume feed)
   if(v <= 0.0)
      v = 1.0; // never let a zero-volume bar drop its price contribution
   const double typical = (h + l + c) / 3.0;

   g_vwap_cum_pv += typical * v;
   g_vwap_cum_v  += v;
   if(g_vwap_cum_v > 0.0)
      g_vwap_now = g_vwap_cum_pv / g_vwap_cum_v;

   MqlRates spread_rates[];
   ArraySetAsSeries(spread_rates, true);
   const int spread_lookback = MathMax(1, strategy_spread_lookback);
   const int copied = CopyRates(_Symbol, _Period, 1, spread_lookback, spread_rates); // perf-allowed: closed-bar median spread cache, called only from framework new-bar entry path
   if(copied > 0)
     {
      int spreads[];
      ArrayResize(spreads, copied);
      int spread_count = 0;
      for(int i = 0; i < copied; ++i)
        {
         if(spread_rates[i].spread < 0)
            continue;
         spreads[spread_count] = spread_rates[i].spread;
         spread_count++;
        }
      if(spread_count > 0)
        {
         ArrayResize(spreads, spread_count);
         ArraySort(spreads);
         if((spread_count % 2) == 1)
            g_median_spread_points = (double)spreads[spread_count / 2];
         else
            g_median_spread_points = 0.5 * (double)(spreads[spread_count / 2 - 1] + spreads[spread_count / 2]);
        }
     }

   // Push into the slope ring (newest last).
   const int cap = MathMax(16, strategy_swing_lookback + 2);
   if(ArraySize(g_vwap_hist) != cap)
     {
      ArrayResize(g_vwap_hist, cap);
      ArrayInitialize(g_vwap_hist, 0.0);
      g_vwap_hist_size = 0;
     }
   for(int i = cap - 1; i > 0; --i)
      g_vwap_hist[i] = g_vwap_hist[i - 1];
   g_vwap_hist[0] = g_vwap_now; // index 0 = most recent closed bar (shift 1)
   if(g_vwap_hist_size < cap)
      g_vwap_hist_size++;
  }

// VWAP value as of N closed bars back (0 = last closed bar / shift 1).
double VWAP_At(const int bars_back)
  {
   if(bars_back < 0 || bars_back >= ArraySize(g_vwap_hist) || bars_back >= g_vwap_hist_size)
      return 0.0;
   return g_vwap_hist[bars_back];
  }

// True if the broker-time hour of `broker_now` is inside the liquid trade window.
bool InTradeWindow(const datetime broker_now)
  {
   MqlDateTime dt;
   ZeroMemory(dt);
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_broker_h <= strategy_session_end_broker_h)
      return (h >= strategy_session_start_broker_h && h < strategy_session_end_broker_h);
   // wrap-around (not expected here, but handle defensively)
   return (h >= strategy_session_start_broker_h || h < strategy_session_end_broker_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: outside-session block + wide-spread block.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   if(!InTradeWindow(TimeCurrent()))
      return true; // outside liquid hours -> block new entries

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   if(g_median_spread_points <= 0.0 || strategy_spread_median_mult <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double spread_cap = g_median_spread_points * point * strategy_spread_median_mult;
   if(point > 0.0 && spread_cap > 0.0 && spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate, single-consume).
// First advance the cached VWAP/session state by one bar, then evaluate.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // FIRST: advance closed-bar intraday state exactly once per new bar.
   VWAP_AdvanceOnNewBar();

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Session VWAP must be established.
   if(g_vwap_now <= 0.0 || g_vwap_hist_size < 9)
      return false;

   // Last closed bar OHLC (shift 1).
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double vwap = g_vwap_now;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask > 0.0 && bid > 0.0 && point > 0.0 &&
      g_median_spread_points > 0.0 && strategy_spread_median_mult > 0.0)
     {
      const double spread = ask - bid;
      const double spread_cap = g_median_spread_points * point * strategy_spread_median_mult;
      if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
         return false;
     }

   // VWAP slope filter: |VWAP[now] - VWAP[8 bars back]| must exceed slope_atr_frac*ATR.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double vwap_8 = VWAP_At(8);
   if(vwap_8 <= 0.0)
      return false;
   const double slope_abs = MathAbs(vwap - vwap_8);
   if(slope_abs <= strategy_slope_atr_frac * atr_value)
      return false; // flat VWAP -> skip

   // MACD(12,26,9) values. NOTE: MACD line/signal can be NEGATIVE — never guard
   // them with `<= 0.0`. Use the framework EMPTY sentinel for read failure.
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double sig_now   = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   if(macd_now == EMPTY_VALUE || sig_now == EMPTY_VALUE)
      return false;

   // MACD trigger within the last `macd_lookback` closed bars: ONE event (a fresh
   // line-over-signal cross). Histogram = macd - signal. We look for the most
   // recent bar where the histogram flipped sign in the desired direction.
   bool macd_bull = false;
   bool macd_bear = false;
   for(int s = 1; s <= strategy_macd_lookback; ++s)
     {
      const double m_s  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      const double sg_s = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s);
      const double m_p  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s + 1);
      const double sg_p = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_s == EMPTY_VALUE || sg_s == EMPTY_VALUE || m_p == EMPTY_VALUE || sg_p == EMPTY_VALUE)
         continue;
      const double hist_s = m_s - sg_s;
      const double hist_p = m_p - sg_p;
      if(hist_p <= 0.0 && hist_s > 0.0)
         macd_bull = true; // fresh bullish histogram flip
      if(hist_p >= 0.0 && hist_s < 0.0)
         macd_bear = true; // fresh bearish histogram flip
     }

   // --- LONG setup ---
   // price above VWAP, last bar dipped to/below VWAP but closed above it, MACD bull.
   const bool long_bias  = (close1 > vwap);
   const bool long_touch = (low1 <= vwap && close1 > vwap);
   if(long_bias && long_touch && macd_bull)
     {
      // Pullback swing low over the lookback window (closed bars 1..lookback).
      double swing_low = low1;
      for(int s = 1; s <= strategy_swing_lookback; ++s)
        {
         const double l_s = iLow(_Symbol, _Period, s); // perf-allowed: bounded closed-bar reads
         if(l_s > 0.0 && l_s < swing_low)
            swing_low = l_s;
        }
      const double entry = ask;
      if(entry <= 0.0)
         return false;
      const double sl = swing_low - strategy_sl_atr_buffer * atr_value;
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_macd_long";
      return true;
     }

   // --- SHORT setup ---
   const bool short_bias  = (close1 < vwap);
   const bool short_touch = (high1 >= vwap && close1 < vwap);
   if(short_bias && short_touch && macd_bear)
     {
      double swing_high = high1;
      for(int s = 1; s <= strategy_swing_lookback; ++s)
        {
         const double h_s = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar reads
         if(h_s > swing_high)
            swing_high = h_s;
        }
      const double entry = bid;
      if(entry <= 0.0)
         return false;
      const double sl = swing_high + strategy_sl_atr_buffer * atr_value;
      if(sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_macd_short";
      return true;
     }

   return false;
  }

// No active SL/TP modification; fixed stop/target + discretionary exits below.
// Latch the entry bar + direction once a position is live (for the time-stop).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   bool found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      found = true;
      if(g_entry_bar_time == 0)
        {
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (open) bar time
         g_entry_dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
        }
      break;
     }
   if(!found)
     {
      g_entry_bar_time = 0;
      g_entry_dir = 0;
     }
  }

// Discretionary exits (separate from SL/TP):
//   (a) closed bar on the opposite side of VWAP after entry,
//   (b) outside the liquid trade window (session end),
//   (c) max-hold time stop in M15 bars.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // (b) Session end — close when we leave the liquid window.
   if(!InTradeWindow(TimeCurrent()))
      return true;

   // (a) Opposite-side-of-VWAP close. Use cached VWAP + last closed bar's close.
   if(g_vwap_now > 0.0)
     {
      const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(close1 > 0.0)
        {
         if(g_entry_dir > 0 && close1 < g_vwap_now)
            return true; // long but bar closed below VWAP
         if(g_entry_dir < 0 && close1 > g_vwap_now)
            return true; // short but bar closed above VWAP
        }
     }

   // (c) Max-hold time stop: count M15 bars elapsed since entry.
   if(g_entry_bar_time > 0 && strategy_max_hold_bars > 0)
     {
      const int held = iBarShift(_Symbol, _Period, g_entry_bar_time, false); // perf-allowed: time->shift lookup
      if(held >= strategy_max_hold_bars)
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

   ArrayResize(g_vwap_hist, MathMax(16, strategy_swing_lookback + 2));
   ArrayInitialize(g_vwap_hist, 0.0);
   g_vwap_hist_size = 0;

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

   // Per-tick: trade management latches entry bar/direction for the time-stop.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (opposite-VWAP / session-end / time-stop).
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
      g_entry_bar_time = 0;
      g_entry_dir = 0;
     }

   // Per-tick session/spread gate (cheap O(1)).
   if(Strategy_NoTradeFilter())
      return;

   // Per-closed-bar: advance VWAP state + evaluate entry. Single-consume new-bar.
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
