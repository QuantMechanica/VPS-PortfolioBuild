#property strict
#property version   "5.0"
#property description "QM5_11001 the5ers-bollinger-squeeze — Bollinger BandWidth squeeze breakout (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11001 the5ers-bollinger-squeeze
// -----------------------------------------------------------------------------
// Source: The5ers blog "Picking Tops and Bottoms in Bollinger Bands"
//   (https://the5ers.com/bollinger-bands/).
// Card: artifacts/cards_approved/QM5_11001_the5ers-bollinger-squeeze.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H4):
//   BandWidth     : bw[1] = (BB_Upper[1] - BB_Lower[1]) / BB_Middle[1]
//                   on Bollinger(period, deviation, PRICE_CLOSE).
//   Squeeze STATE : bw[1] is the lowest bw over the last `squeeze_lookback`
//                   closed H4 bars (~6 months ~= 756 H4 bars).
//   Breakout EVENT: while a squeeze is/was active (signal latched, expires after
//                   `signal_expiry_bars`), the close of bar[1] breaks above the
//                   upper band (long) or below the lower band (short).
//   Ambiguity     : if both bands break on the same bar, skip the bar.
//   Stop (long)   : nearer of structure low(lowest_low(10)) / lower band, but at
//                   least 1.0*ATR(14) away from entry. Symmetric for shorts.
//   Take profit   : tp_rr * R from the initial stop distance.
//   Trailing exit : after +1R favorable, trail SL by trail_atr_mult*ATR(14).
//   Vol-fail exit : close back inside the bands AND bw[1] below its 20-bar median.
//   Time stop     : close after `time_stop_bars` H4 bars in trade.
//
// Squeeze detection caches the bandwidth series in a file-scope ring buffer that
// the new-bar gate advances ONE step per closed bar (cold-start backfill once).
// No per-tick history scans.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11001;
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
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_deviation       = 2.0;    // Bollinger deviations
input int    strategy_squeeze_lookback   = 756;    // bars for the squeeze low (~6mo H4)
input int    strategy_signal_expiry_bars = 12;     // squeeze signal expires after N bars
input int    strategy_struct_lookback    = 10;     // lowest_low/highest_high lookback for SL
input int    strategy_atr_period         = 14;     // ATR period (stop floor / trail)
input double strategy_atr_min_mult       = 1.0;    // SL at least this * ATR from entry
input double strategy_tp_rr              = 2.0;    // take profit in R multiples
input double strategy_trail_atr_mult     = 2.0;    // trailing stop distance = mult * ATR
input double strategy_trail_trigger_rr   = 1.0;    // start trailing after this R favorable
input int    strategy_bw_median_bars     = 20;     // median window for vol-fail exit
input int    strategy_time_stop_bars     = 30;     // close after N bars in trade
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached squeeze state (advanced ONE step per closed bar).
// -----------------------------------------------------------------------------
#define QM_BW_MAX 4096
double   g_bw_ring[QM_BW_MAX];   // ring buffer of bandwidth values, newest at head
int      g_bw_count        = 0;  // how many valid samples currently stored
int      g_bw_capacity     = 0;  // effective capacity = max(lookback, median) + guard
datetime g_last_bw_bar     = 0;  // bar-open time of the last bandwidth we ingested
bool     g_squeeze_active  = false; // a fresh squeeze low was seen
int      g_squeeze_age     = 0;  // bars since the squeeze signal latched

// Per-trade tracking for trailing / time-stop.
ulong    g_trade_ticket    = 0;
datetime g_trade_open_bar  = 0;
double   g_trade_entry     = 0.0;
double   g_trade_init_sl   = 0.0;
bool     g_trade_is_long   = false;
double   g_trade_best_px   = 0.0; // best favorable close seen since entry

// Compute bandwidth for a given closed-bar shift. Returns -1.0 on bad data.
double QM_BWAtShift(const int shift)
  {
   const double up  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lo  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(mid <= 0.0 || up <= 0.0 || lo <= 0.0 || up < lo)
      return -1.0;
   return (up - lo) / mid;
  }

// Push the newest bandwidth (shift 1) to the head of the ring; shift older down.
void QM_BWPush(const double bw)
  {
   if(g_bw_capacity <= 0)
     {
      int want = MathMax(strategy_squeeze_lookback, strategy_bw_median_bars) + 4;
      if(want > QM_BW_MAX) want = QM_BW_MAX;
      if(want < 2)         want = 2;
      g_bw_capacity = want;
     }
   const int n = (g_bw_count < g_bw_capacity) ? g_bw_count : g_bw_capacity - 1;
   for(int i = n; i > 0; --i)
      g_bw_ring[i] = g_bw_ring[i - 1];
   g_bw_ring[0] = bw;
   if(g_bw_count < g_bw_capacity)
      g_bw_count++;
  }

// Cold-start: backfill the ring from history once (oldest -> newest) so the
// squeeze low has a full window without per-bar rescans afterwards.
void QM_BWBackfill()
  {
   if(g_bw_capacity <= 0)
     {
      int want = MathMax(strategy_squeeze_lookback, strategy_bw_median_bars) + 4;
      if(want > QM_BW_MAX) want = QM_BW_MAX;
      if(want < 2)         want = 2;
      g_bw_capacity = want;
     }
   // Fill from the oldest available shift down to shift 1 so newest ends at head.
   for(int s = g_bw_capacity; s >= 1; --s)
     {
      const double bw = QM_BWAtShift(s);
      if(bw < 0.0)
         continue;
      QM_BWPush(bw);
     }
  }

// Advance squeeze state by exactly one closed bar. Called once per new bar.
void QM_AdvanceSqueeze_OnNewBar()
  {
   const datetime bar1 = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar stamp
   if(bar1 == 0)
      return;
   if(bar1 == g_last_bw_bar)
      return; // already ingested this closed bar

   if(g_bw_count == 0)
      QM_BWBackfill();
   else
     {
      const double bw1 = QM_BWAtShift(1);
      if(bw1 >= 0.0)
         QM_BWPush(bw1);
     }
   g_last_bw_bar = bar1;

   // Determine whether the latest bandwidth (head) is the lowest over the lookback.
   if(g_bw_count >= 2)
     {
      const double bw_head = g_bw_ring[0];
      const int win = (g_bw_count < strategy_squeeze_lookback) ? g_bw_count : strategy_squeeze_lookback;
      bool is_low = true;
      for(int i = 1; i < win; ++i)
        {
         if(g_bw_ring[i] < bw_head)
           {
            is_low = false;
            break;
           }
        }
      if(is_low)
        {
         g_squeeze_active = true;
         g_squeeze_age    = 0;
        }
      else if(g_squeeze_active)
        {
         g_squeeze_age++;
         if(g_squeeze_age > strategy_signal_expiry_bars)
            g_squeeze_active = false;
        }
     }
  }

// Median bandwidth over the most recent `bars` ring samples (for vol-fail exit).
double QM_BWMedian(const int bars)
  {
   int n = (g_bw_count < bars) ? g_bw_count : bars;
   if(n <= 0)
      return -1.0;
   double tmp[QM_BW_MAX];
   for(int i = 0; i < n; ++i)
      tmp[i] = g_bw_ring[i];
   // Simple insertion sort (n <= median window, small).
   for(int i = 1; i < n; ++i)
     {
      const double key = tmp[i];
      int j = i - 1;
      while(j >= 0 && tmp[j] > key)
        {
         tmp[j + 1] = tmp[j];
         --j;
        }
      tmp[j + 1] = key;
     }
   if((n % 2) == 1)
      return tmp[n / 2];
   return 0.5 * (tmp[n / 2 - 1] + tmp[n / 2]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_min_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The squeeze
// ring is advanced from OnTick before this fires (see AdvanceState below).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_squeeze_active)
      return false;

   // Bands and prior close at the closed bar (shift 1).
   const double up   = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lo   = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(up <= 0.0 || lo <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool break_up   = (close1 > up);
   const bool break_down = (close1 < lo);
   if(break_up && break_down)
      return false;       // ambiguous — skip
   if(!break_up && !break_down)
      return false;       // no breakout this bar

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const QM_OrderType side = break_up ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: nearer of structure / band, but >= atr_min_mult * ATR away. ---
   // Structure stop (lowest_low/highest_high over struct_lookback).
   const double struct_sl = QM_StopStructure(_Symbol, side, entry, strategy_struct_lookback);
   // Band-based stop: opposite band as a price.
   const double band_sl = (side == QM_BUY) ? lo : up;
   // ATR-floor stop (minimum distance).
   const double atr_floor_sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_atr_min_mult);
   if(atr_floor_sl <= 0.0)
      return false;

   double sl;
   if(side == QM_BUY)
     {
      // Candidates below entry; "closer to entry" = higher price. Pick the max
      // of structure & band, then cap so it's at least the ATR floor away.
      double closer = MathMax(struct_sl > 0.0 ? struct_sl : -DBL_MAX,
                              band_sl   > 0.0 ? band_sl   : -DBL_MAX);
      if(closer <= 0.0 || closer >= entry)
         closer = atr_floor_sl;
      // Enforce minimum ATR distance: SL must be <= atr_floor_sl (further from entry).
      sl = MathMin(closer, atr_floor_sl);
     }
   else
     {
      // Candidates above entry; "closer to entry" = lower price. Pick the min.
      double closer = MathMin(struct_sl > 0.0 ? struct_sl : DBL_MAX,
                              band_sl   > 0.0 ? band_sl   : DBL_MAX);
      if(closer >= DBL_MAX || closer <= entry)
         closer = atr_floor_sl;
      // Enforce minimum ATR distance: SL must be >= atr_floor_sl (further from entry).
      sl = MathMax(closer, atr_floor_sl);
     }
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = break_up ? "bb_squeeze_break_long" : "bb_squeeze_break_short";

   // Consume the squeeze signal once it fires an entry.
   g_squeeze_active = false;
   g_squeeze_age    = 0;
   return true;
  }

// Trailing stop once +trail_trigger_rr R favorable; tracks best favorable close.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_trade_ticket = 0;
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // Latch trade metadata on first sight of a new ticket.
      if(g_trade_ticket != ticket)
        {
         g_trade_ticket   = ticket;
         g_trade_open_bar = (datetime)PositionGetInteger(POSITION_TIME);
         g_trade_entry    = PositionGetDouble(POSITION_PRICE_OPEN);
         g_trade_init_sl  = PositionGetDouble(POSITION_SL);
         g_trade_is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
         g_trade_best_px  = g_trade_entry;
        }

      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double r_dist = MathAbs(g_trade_entry - g_trade_init_sl);
      if(r_dist <= 0.0)
         return;

      // Track best favorable price.
      if(g_trade_is_long)
        {
         if(bid > g_trade_best_px) g_trade_best_px = bid;
        }
      else
        {
         if(ask > 0.0 && (g_trade_best_px <= 0.0 || ask < g_trade_best_px))
            g_trade_best_px = ask;
        }

      const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_value <= 0.0)
         return;

      // Only trail after +trigger R favorable.
      const double favorable = g_trade_is_long ? (bid - g_trade_entry)
                                               : (g_trade_entry - ask);
      if(favorable < strategy_trail_trigger_rr * r_dist)
         return;

      const double trail_dist = strategy_trail_atr_mult * atr_value;
      if(trail_dist <= 0.0)
         return;

      const double cur_sl = PositionGetDouble(POSITION_SL);
      if(g_trade_is_long)
        {
         double new_sl = QM_StopRulesNormalizePrice(_Symbol, g_trade_best_px - trail_dist);
         if(new_sl > cur_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "bb_squeeze_trail");
        }
      else
        {
         double new_sl = QM_StopRulesNormalizePrice(_Symbol, g_trade_best_px + trail_dist);
         if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "bb_squeeze_trail");
        }
     }
  }

// Discretionary exits: time stop + volatility-failure (close back inside the
// bands while bandwidth is still below its 20-bar median).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Time stop: bars elapsed since open >= time_stop_bars.
   if(g_trade_open_bar > 0)
     {
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const datetime bar1 = iTime(_Symbol, _Period, 1); // perf-allowed: single stamp
         const long bars_held = (long)((bar1 - g_trade_open_bar) / secs_per_bar);
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   // Volatility-failure: prior close back inside the bands AND bw below median.
   const double up    = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lo    = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(up > 0.0 && lo > 0.0 && close1 > 0.0)
     {
      const bool inside = (close1 < up && close1 > lo);
      if(inside)
        {
         const double bw_now = (g_bw_count > 0) ? g_bw_ring[0] : -1.0;
         const double bw_med = QM_BWMedian(strategy_bw_median_bars);
         if(bw_now >= 0.0 && bw_med >= 0.0 && bw_now < bw_med)
            return true;
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

   g_bw_count       = 0;
   g_bw_capacity    = 0;
   g_last_bw_bar    = 0;
   g_squeeze_active = false;
   g_squeeze_age    = 0;
   g_trade_ticket   = 0;

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

   // Advance the cached squeeze state ONCE per closed bar (after the new-bar gate).
   QM_AdvanceSqueeze_OnNewBar();

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
