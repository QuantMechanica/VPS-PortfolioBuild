#property strict
#property version   "5.0"
#property description "QM5_11064 atc-zigzag-break — ZigZag confirmed-swing pending breakout, large-stop/small-TP (FX, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11064 atc-zigzag-break
// -----------------------------------------------------------------------------
// Source: Tim Fass, Interview (ATC 2011), MQL5 Articles 546.
// Card: artifacts/cards_approved/QM5_11064_atc-zigzag-break.md (g0_status APPROVED).
//
// Mechanics (closed-bar evaluation only — NON-REPAINTING ZigZag, M15):
//   ZigZag pivots are CONFIRMED fractal swings: a bar at series index s is a
//   swing HIGH iff its high is the strict maximum over [s-depth, s+depth] (and
//   beats the prior opposite pivot by >= deviation points, alternating high/low
//   with backstep spacing). Because the right wing (s+depth newer bars) is fully
//   CLOSED before the bar is accepted, a confirmed pivot can NEVER change on
//   later bars — no repaint, no forming leg. We only read the last two CONFIRMED
//   pivots. All structural math is gated by QM_IsNewBar() and cached at file
//   scope; the per-tick path is O(1).
//
//   Entry  : BUY STOP at (last confirmed swing HIGH + entry_buffer_atr*ATR).
//            SELL STOP at (last confirmed swing LOW  - entry_buffer_atr*ATR).
//            Placed/refreshed when a NEW confirmed pivot pair appears. When one
//            side fills, the opposite pending order is cancelled. One active
//            position per symbol/magic.
//   Exit   : Fixed TP = tp_atr_mult * ATR (baseline 1.0 — small reliable profit).
//            Fixed SL = sl_atr_mult * ATR (baseline 3.0 — source's large-stop
//            profile). Plus a TIME STOP: close after time_stop_bars M15 bars
//            (baseline 32) if neither TP nor SL fired.
//   Filter : (a) swing range (lastHigh-lastLow) >= min_range_atr * ATR (flat
//            market filter); (b) ADX(adx_period) >= adx_min (skip non-trending);
//            (c) spread fail-OPEN — block only a genuinely wide spread.
//
//   Direction-specific buffers/SL/TP are permitted by the card (long/short modes
//   differed in the source). Baseline ships symmetric; P3 may sweep per-side.
//
// This is a structural pending-order strategy, so OnTick below is bespoke (it
// manages two pending orders + a cached confirmed-pivot state + a fill-time stop)
// rather than the single-market-entry skeleton path.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11064;
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
input int    strategy_zz_depth          = 12;    // ZigZag depth: half-window for a confirmed swing
input int    strategy_zz_deviation      = 5;     // ZigZag deviation in points (min move vs prior pivot)
input int    strategy_zz_backstep       = 3;     // ZigZag backstep: min bar spacing between pivots
input double strategy_entry_buffer_atr  = 0.10;  // stop-entry buffer beyond the swing, in ATR
input double strategy_min_range_atr     = 1.5;   // require swing range >= this * ATR (0 disables)
input int    strategy_atr_period        = 14;    // ATR period (filter / stop / target)
input double strategy_sl_atr_mult       = 3.0;   // stop distance = mult * ATR (large stop)
input double strategy_tp_atr_mult       = 1.0;   // target distance = mult * ATR (small reliable profit)
input int    strategy_adx_period        = 14;    // ADX period for the trend filter
input double strategy_adx_min           = 18.0;  // skip new pendings if ADX < this (0 disables)
input int    strategy_time_stop_bars    = 32;    // close after this many M15 bars in trade (0 disables)
input int    strategy_pending_expiry_h  = 24;    // pending-order GTC expiry, in hours (0 = GTC)
input double strategy_spread_pct_of_stop = 15.0; // skip new pendings if spread > this % of stop dist

// -----------------------------------------------------------------------------
// File-scope cached confirmed-pivot state (advanced once per closed bar).
// -----------------------------------------------------------------------------
double   g_last_swing_high   = 0.0;   // price of most recent CONFIRMED swing high
double   g_last_swing_low    = 0.0;   // price of most recent CONFIRMED swing low
datetime g_last_high_time    = 0;     // bar-open time of that swing high (pivot identity)
datetime g_last_low_time     = 0;     // bar-open time of that swing low
datetime g_pending_anchor    = 0;     // pivot-signature we last placed pendings against
ulong    g_buy_stop_ticket   = 0;     // tracked buy-stop pending ticket (0 = none)
ulong    g_sell_stop_ticket  = 0;     // tracked sell-stop pending ticket (0 = none)
ulong    g_timed_position    = 0;     // position ticket the time-stop clock is tracking
datetime g_position_open_time = 0;    // broker time the tracked position opened

// -----------------------------------------------------------------------------
// Confirmed ZigZag reconstruction over a bounded closed-bar window.
// Returns true if both a swing high and a swing low were found. Pivots are
// fractal-confirmed (strict extreme over [s-depth, s+depth]); the right wing is
// fully closed so they never repaint. Alternation + deviation + backstep mimic
// the conventional MetaTrader ZigZag without forming legs.
// -----------------------------------------------------------------------------
bool ComputeConfirmedPivots(double &out_high, datetime &out_high_t,
                            double &out_low,  datetime &out_low_t)
  {
   const int depth = (strategy_zz_depth < 1) ? 1 : strategy_zz_depth;
   const int backstep = (strategy_zz_backstep < 0) ? 0 : strategy_zz_backstep;

   // Window: enough bars to find a couple of alternating pivots. Bounded.
   const int max_pivots_back = 6;                 // how many confirmed pivots to scan for
   const int window = depth * (max_pivots_back + 4) + backstep + 8;

   const int avail = Bars(_Symbol, _Period); // perf-allowed: bounds check for bespoke ZigZag window; caller is QM_IsNewBar-gated
   if(avail < window + depth + 2)
      return false;

   // perf-allowed: ONE CopyRates per closed bar (gated by QM_IsNewBar in OnTick),
   // cached into file-scope state. Bounded window, never per-tick.
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, _Period, 1, window + depth + 2, rates); // perf-allowed: see QM_IsNewBar gate in OnTick
   if(copied < window + depth + 2)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double dev_price = (point > 0.0) ? (strategy_zz_deviation * point) : 0.0;

   // Collect confirmed pivots from most-recent backwards. A bar at index s (in
   // series order, s>=depth) is a confirmed swing HIGH iff its high is the strict
   // maximum over [s-depth .. s+depth]; symmetric for LOW. s+depth must be a
   // closed bar (it always is — index 0 here is closed bar shift 1).
   double   piv_price[];
   datetime piv_time[];
   int      piv_ishigh[];   // 1 = high, 0 = low
   ArrayResize(piv_price, max_pivots_back * 2 + 4);
   ArrayResize(piv_time,  max_pivots_back * 2 + 4);
   ArrayResize(piv_ishigh,max_pivots_back * 2 + 4);
   int piv_n = 0;

   int last_pivot_index = -10000;   // series index of last accepted pivot (for backstep)
   int last_pivot_kind  = -1;       // 1 high, 0 low, -1 none (for alternation)
   double last_pivot_price = 0.0;

   for(int s = depth; s <= window && piv_n < max_pivots_back * 2; ++s)
     {
      const double hi = rates[s].high;
      const double lo = rates[s].low;

      bool is_high = true;
      bool is_low  = true;
      for(int k = 1; k <= depth; ++k)
        {
         // left wing (older bars: larger index) and right wing (newer: smaller index)
         if(rates[s + k].high >= hi || rates[s - k].high >= hi) is_high = false;
         if(rates[s + k].low  <= lo || rates[s - k].low  <= lo) is_low  = false;
         if(!is_high && !is_low) break;
        }
      if(!is_high && !is_low)
         continue;

      // A bar could satisfy both in flat data; prefer the one alternating with
      // the previous pivot to keep a proper high/low/high sequence.
      int kind = -1;
      double price = 0.0;
      if(is_high && is_low)
        {
         kind  = (last_pivot_kind == 1) ? 0 : 1;
         price = (kind == 1) ? hi : lo;
        }
      else if(is_high)
        { kind = 1; price = hi; }
      else
        { kind = 0; price = lo; }

      // Alternation: skip same-kind-as-previous (the most recent extreme wins).
      if(kind == last_pivot_kind && last_pivot_kind != -1)
         continue;

      // Backstep spacing vs the last accepted pivot.
      if(last_pivot_index != -10000 && (s - last_pivot_index) < backstep + 1)
         continue;

      // Deviation: move from the previous pivot must exceed the threshold.
      if(last_pivot_kind != -1 && dev_price > 0.0)
         if(MathAbs(price - last_pivot_price) < dev_price)
            continue;

      piv_price[piv_n]  = price;
      piv_time[piv_n]   = rates[s].time;
      piv_ishigh[piv_n] = kind;
      ++piv_n;

      last_pivot_index = s;
      last_pivot_kind  = kind;
      last_pivot_price = price;
     }

   // Extract the most recent confirmed high and most recent confirmed low.
   bool got_high = false, got_low = false;
   out_high = 0.0; out_low = 0.0; out_high_t = 0; out_low_t = 0;
   for(int i = 0; i < piv_n; ++i)
     {
      if(!got_high && piv_ishigh[i] == 1)
        { out_high = piv_price[i]; out_high_t = piv_time[i]; got_high = true; }
      if(!got_low && piv_ishigh[i] == 0)
        { out_low = piv_price[i]; out_low_t = piv_time[i]; got_low = true; }
      if(got_high && got_low) break;
     }
   return (got_high && got_low);
  }

// Refresh cached confirmed pivots once per closed bar.
void AdvanceState_OnNewBar()
  {
   double hi = 0.0, lo = 0.0;
   datetime ht = 0, lt = 0;
   if(ComputeConfirmedPivots(hi, ht, lo, lt))
     {
      g_last_swing_high = hi;
      g_last_high_time  = ht;
      g_last_swing_low  = lo;
      g_last_low_time   = lt;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Not used as the single-entry path — pending placement is in OnTick below.
// Kept framework-shaped (returns false) so the standard skeleton wiring is
// satisfied; the bespoke pending lifecycle drives actual order placement.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   return false;
  }

// Fixed-target / fixed-stop strategy: SL and TP are set on the pending order at
// placement time, so no per-tick SL/TP modification is needed here. The time
// stop is handled by Strategy_ExitSignal below.
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close the tracked position once it has been open for at least
// time_stop_bars M15 bars. SL/TP are enforced by the broker on the order itself.
bool Strategy_ExitSignal()
  {
   if(strategy_time_stop_bars <= 0)
      return false;
   if(g_timed_position == 0 || g_position_open_time == 0)
      return false;

   const int bar_seconds = PeriodSeconds(_Period);
   if(bar_seconds <= 0)
      return false;

   const datetime now = TimeCurrent();
   const long elapsed = (long)(now - g_position_open_time);
   if(elapsed >= (long)strategy_time_stop_bars * bar_seconds)
      return true;

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Pending-order lifecycle (bespoke structural logic, closed-bar gated).
// -----------------------------------------------------------------------------

// True if a pending order with this ticket still exists in the order book.
bool PendingAlive(const ulong ticket)
  {
   if(ticket == 0)
      return false;
   return OrderSelect(ticket);
  }

// Cancel any tracked pending orders (e.g. on fill or refresh).
void CancelTrackedPendings(const string reason)
  {
   if(PendingAlive(g_buy_stop_ticket))
      QM_TM_RemovePendingOrder(g_buy_stop_ticket, reason);
   g_buy_stop_ticket = 0;
   if(PendingAlive(g_sell_stop_ticket))
      QM_TM_RemovePendingOrder(g_sell_stop_ticket, reason);
   g_sell_stop_ticket = 0;
  }

// Place buy-stop above the confirmed swing high and sell-stop below the
// confirmed swing low, with ATR-derived SL/TP off each stop entry price.
void PlacePendingBreakouts()
  {
   if(g_last_swing_high <= 0.0 || g_last_swing_low <= 0.0)
      return;
   if(g_last_swing_high <= g_last_swing_low)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Flat-market filter: confirmed swing range must be wide enough.
   if(strategy_min_range_atr > 0.0)
     {
      const double range = g_last_swing_high - g_last_swing_low;
      if(range < strategy_min_range_atr * atr_value)
         return;
     }

   // Trend filter: require a minimum ADX (skip non-trending / flat markets).
   if(strategy_adx_min > 0.0)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx > 0.0 && adx < strategy_adx_min)
         return;
     }

   const double buffer = strategy_entry_buffer_atr * atr_value;
   const int expiry_sec = (strategy_pending_expiry_h > 0) ? strategy_pending_expiry_h * 3600 : 0;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const long   stop_level_pts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double min_dist = (stop_level_pts > 0 && point > 0.0) ? (stop_level_pts * point) : 0.0;

   // --- BUY STOP above the swing high ---
   double buy_price = QM_TM_NormalizePrice(_Symbol, g_last_swing_high + buffer);
   // Stop orders must sit strictly above current ask (+ broker stop level).
   if(ask > 0.0 && buy_price <= ask + min_dist)
      buy_price = QM_TM_NormalizePrice(_Symbol, ask + min_dist + buffer);
   if(buy_price > 0.0)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY_STOP, buy_price, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY_STOP, buy_price, atr_value, strategy_tp_atr_mult);
      if(sl > 0.0 && tp > 0.0)
        {
         QM_EntryRequest req;
         req.type   = QM_BUY_STOP;
         req.price  = buy_price;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "zz_buystop";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = expiry_sec;
         ulong t = 0;
         if(QM_TM_OpenPosition(req, t))
            g_buy_stop_ticket = t;
        }
     }

   // --- SELL STOP below the swing low ---
   double sell_price = QM_TM_NormalizePrice(_Symbol, g_last_swing_low - buffer);
   if(bid > 0.0 && sell_price >= bid - min_dist)
      sell_price = QM_TM_NormalizePrice(_Symbol, bid - min_dist - buffer);
   if(sell_price > 0.0)
     {
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL_STOP, sell_price, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL_STOP, sell_price, atr_value, strategy_tp_atr_mult);
      if(sl > 0.0 && tp > 0.0)
        {
         QM_EntryRequest req;
         req.type   = QM_SELL_STOP;
         req.price  = sell_price;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "zz_sellstop";
         req.symbol_slot = qm_magic_slot_offset;
         req.expiration_seconds = expiry_sec;
         ulong t = 0;
         if(QM_TM_OpenPosition(req, t))
            g_sell_stop_ticket = t;
        }
     }
  }

// Identify the currently open position for this magic and latch its open time so
// the time-stop clock counts from the FILL, not from pending placement.
void TrackOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(ticket != g_timed_position)
        {
         g_timed_position     = ticket;
         g_position_open_time = (datetime)PositionGetInteger(POSITION_TIME);
        }
      return;
     }
   // No open position for this magic/symbol — reset the clock.
   g_timed_position     = 0;
   g_position_open_time = 0;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   g_last_swing_high   = 0.0;
   g_last_swing_low    = 0.0;
   g_last_high_time    = 0;
   g_last_low_time     = 0;
   g_pending_anchor    = 0;
   g_buy_stop_ticket   = 0;
   g_sell_stop_ticket  = 0;
   g_timed_position    = 0;
   g_position_open_time = 0;

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

   const int magic = QM_FrameworkMagic();
   const bool have_position = (QM_TM_OpenPositionCount(magic) > 0);

   // Per-tick O(1): once a side has filled, cancel the opposite pending order,
   // latch the fill time, and honour the time stop. One active position/magic.
   if(have_position)
     {
      CancelTrackedPendings("opposite_filled");
      TrackOpenPosition();
      Strategy_ManageOpenPosition();

      if(Strategy_ExitSignal())
        {
         for(int i = PositionsTotal() - 1; i >= 0; --i)
           {
            const ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket))
               continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic)
               continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol)
               continue;
            QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
           }
         g_timed_position     = 0;
         g_position_open_time = 0;
        }
     }
   else
     {
      // No live position — clear any stale time-stop tracking.
      g_timed_position     = 0;
      g_position_open_time = 0;
     }

   // Closed-bar structural work only.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Refresh confirmed (non-repainting) ZigZag pivots from the closed bars.
   AdvanceState_OnNewBar();

   // With a live position we never stack pendings; wait for it to close.
   if(have_position)
      return;

   // Spread fail-open guard for new placement.
   if(Strategy_NoTradeFilter())
      return;

   // Build a signature of the current confirmed swing pair. Re-place pendings
   // only when a NEW confirmed pivot has appeared (cancel/replace per the card).
   const datetime anchor = (datetime)(g_last_high_time + g_last_low_time);

   const bool pendings_present = (PendingAlive(g_buy_stop_ticket) || PendingAlive(g_sell_stop_ticket));

   if(anchor != g_pending_anchor || !pendings_present)
     {
      CancelTrackedPendings("zz_new_pivot_refresh");
      PlacePendingBreakouts();
      g_pending_anchor = anchor;
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
