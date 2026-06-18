#property strict
#property version   "5.0"
#property description "QM5_11340 tc-m5-18-ema20-macd — EMA20 reclaim + recent MACD zero-cross (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11340 tc-m5-18-ema20-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #18, pp.44-45.
// Card: artifacts/cards_approved/QM5_11340_tc-m5-18-ema20-macd.md (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1/2):
//   The EMA20 reclaim is the single fresh TRIGGER EVENT; the MACD zero-cross is a
//   STATE (recent or current). This split avoids the "two crosses on one bar"
//   zero-trade trap. MACD main may be negative — only its sign / zero-cross matters.
//
//   LONG:
//     Prior setup STATE : within the lookback window before the trigger, price
//                         traded below EMA20 (close < EMA20) on >=1 bar.
//     Trigger EVENT     : close crosses up through EMA20 on the signal bar
//                         (close[2] <= EMA20[2] AND close[1] > EMA20[1]).
//     MACD STATE        : MACD main crossed up through zero within the last
//                         macd_recency_bars closed bars (or is crossing now).
//     Entry             : BUY STOP at EMA20(shift1) + entry_offset_pips,
//                         expiring after pending_expiry_bars M5 bars.
//     Stop              : entry - sl_pips (card: EMA20 - 20p; applied from entry).
//   SHORT is the mirror image.
//
//   Management (post-fill):
//     Partial            : close partial_close_pct at +1R (RR=1), once.
//     Break-even         : after the partial, shift SL to entry + be_buffer_pips.
//     Trail              : trail remainder by trail_pips behind price.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes);
// no swap gate; QM_IsNewBar consumed once (entry path only); reclaim is ONE event
// with MACD as a STATE window; pip-scaled offsets via QM_StopRulesPipsToPriceDistance;
// no external feed; closed-bar reads only.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11340;
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
input int    strategy_ema_period         = 20;    // reclaim EMA period
input int    strategy_macd_fast          = 12;    // MACD fast EMA
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal SMA
input int    strategy_macd_recency_bars  = 5;     // MACD zero-cross recency window (P3: 3/5/8)
input int    strategy_setup_lookback_bars = 20;   // prior "below/above EMA20" context window
input int    strategy_entry_offset_pips  = 10;    // pending STOP offset from EMA20
input int    strategy_sl_pips            = 20;    // stop distance from entry (card: EMA20 +/-20p)
input int    strategy_pending_expiry_bars = 3;    // cancel unfilled pending after N M5 bars (P3: 1/3/5)
input double strategy_partial_rr         = 1.0;   // take partial at this R multiple
input double strategy_partial_close_pct  = 50.0;  // % of position closed at the partial
input int    strategy_be_buffer_pips     = 1;     // break-even buffer after partial
input int    strategy_trail_pips         = 15;    // trail distance on the remainder
input double strategy_spread_pct_of_stop = 25.0;  // skip only if spread > this % of stop distance

// File-scope: track whether we've already taken the partial for the current
// position (latched per fill; cleared when flat). Not a new-bar gate.
ulong  g_partial_done_ticket = 0;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip-distance in price terms for the active symbol.
double PipsToPrice(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// MACD main crossed UP through zero within [shift1 .. recency] closed bars.
// "Recent or current" => state window. MACD can be negative; we only check sign.
bool MacdCrossedUpRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      // A zero-cross from <=0 to >0 between consecutive closed bars.
      if(m_prev <= 0.0 && m_now > 0.0)
         return true;
     }
   return false;
  }

bool MacdCrossedDownRecently(const int recency)
  {
   for(int s = 1; s <= recency; ++s)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s);
      const double m_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, s + 1);
      if(m_prev >= 0.0 && m_now < 0.0)
         return true;
     }
   return false;
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
      return false; // no valid quote yet — do not block on it

   const double stop_distance = PipsToPrice(strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && ask > bid && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the closed-bar path (QM_IsNewBar() == true guaranteed by caller).
// One pending/open per symbol/magic. EMA20 reclaim = trigger; MACD zero-cross
// recency = state. Pending STOP at EMA20 +/- offset, expiring after N bars.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   // One position per magic; also do not stack pending orders on top of a pending.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(OrdersTotal() > 0)
     {
      for(int oi = OrdersTotal() - 1; oi >= 0; --oi)
        {
         const ulong oticket = OrderGetTicket(oi);
         if(oticket == 0 || !OrderSelect(oticket))
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) == magic &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
            return false; // a pending for this EA/symbol already lives
        }
     }

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double offset = PipsToPrice(strategy_entry_offset_pips);
   const double sl_dist = PipsToPrice(strategy_sl_pips);
   if(offset <= 0.0 || sl_dist <= 0.0)
      return false;
   const int expiry_seconds = strategy_pending_expiry_bars *
                              PeriodSeconds(_Period); // N M5 bars in seconds

   // ---- LONG: close crosses UP through EMA20 (single event) ----
   const bool cross_up = (close2 <= ema2 && close1 > ema1);
   if(cross_up && MacdCrossedUpRecently(strategy_macd_recency_bars))
     {
      // Prior setup STATE: price traded BELOW EMA20 in the lookback window
      // before the trigger bar (shifts 2 .. lookback+1).
      bool was_below = false;
      const int last_shift = strategy_setup_lookback_bars + 1;
      for(int s = 2; s <= last_shift; ++s)
        {
         const double c_s = iClose(_Symbol, _Period, s);   // perf-allowed
         const double e_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
         if(c_s <= 0.0 || e_s <= 0.0)
            continue;
         if(c_s < e_s)
           { was_below = true; break; }
        }
      if(!was_below)
         return false;

      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 + offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price - sl_dist);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price >= entry_price)
         return false;

      req.type               = QM_BUY_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = 0.0;   // managed by partial+trail, no fixed TP
      req.reason             = "ema20_reclaim_macd_up";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   // ---- SHORT: close crosses DOWN through EMA20 (single event) ----
   const bool cross_down = (close2 >= ema2 && close1 < ema1);
   if(cross_down && MacdCrossedDownRecently(strategy_macd_recency_bars))
     {
      bool was_above = false;
      const int last_shift = strategy_setup_lookback_bars + 1;
      for(int s = 2; s <= last_shift; ++s)
        {
         const double c_s = iClose(_Symbol, _Period, s);   // perf-allowed
         const double e_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
         if(c_s <= 0.0 || e_s <= 0.0)
            continue;
         if(c_s > e_s)
           { was_above = true; break; }
        }
      if(!was_above)
         return false;

      const double entry_price = QM_TM_NormalizePrice(_Symbol, ema1 - offset);
      const double sl_price    = QM_TM_NormalizePrice(_Symbol, entry_price + sl_dist);
      if(entry_price <= 0.0 || sl_price <= 0.0 || sl_price <= entry_price)
         return false;

      req.type               = QM_SELL_STOP;
      req.price              = entry_price;
      req.sl                 = sl_price;
      req.tp                 = 0.0;
      req.reason             = "ema20_reclaim_macd_down";
      req.expiration_seconds = expiry_seconds;
      return true;
     }

   return false;
  }

// Per-tick management on the open position: partial at +1R, break-even after,
// then trail the remainder. O(1) helpers only.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_partial_done_ticket = 0; // flat — reset the partial latch
      return;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double sl_price   = PositionGetDouble(POSITION_SL);
      const double volume     = PositionGetDouble(POSITION_VOLUME);
      if(open_price <= 0.0)
         continue;

      // 1R in price terms = |entry - initial SL|. After BE shift the SL moves,
      // so derive R from the configured stop distance, not the live SL.
      const double r_dist = PipsToPrice(strategy_sl_pips);
      if(r_dist <= 0.0)
         continue;

      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;
      const double moved = is_buy ? (market - open_price) : (open_price - market);

      // --- Partial at +partial_rr * R (once per fill) ---
      if(g_partial_done_ticket != ticket && moved >= strategy_partial_rr * r_dist)
        {
         double part_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_partial_close_pct / 100.0);
         const double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         // Only partial if both legs remain tradeable; else skip to BE+trail.
         if(part_lots >= min_lot && (volume - part_lots) >= min_lot)
            QM_TM_PartialClose(ticket, part_lots, QM_EXIT_STRATEGY);
         // Latch regardless: at +1R we move to break-even on the remainder.
         g_partial_done_ticket = ticket;

         // Break-even: SL to entry +/- buffer (only if it improves).
         const double be_buf = PipsToPrice(strategy_be_buffer_pips);
         const double be_sl  = QM_TM_NormalizePrice(_Symbol,
                                  is_buy ? (open_price + be_buf) : (open_price - be_buf));
         const bool be_improves = (sl_price <= 0.0) ||
                                  (is_buy ? (be_sl > sl_price) : (be_sl < sl_price));
         if(be_sl > 0.0 && be_improves)
            QM_TM_MoveSL(ticket, be_sl, "breakeven_after_partial");
        }

      // --- Trail the remainder by trail_pips behind market (after partial) ---
      if(g_partial_done_ticket == ticket)
        {
         const double trail_dist = PipsToPrice(strategy_trail_pips);
         if(trail_dist > 0.0)
           {
            const double trail_sl = QM_TM_NormalizePrice(_Symbol,
                                       is_buy ? (market - trail_dist) : (market + trail_dist));
            const double cur_sl = PositionGetDouble(POSITION_SL);
            const bool improves = (cur_sl <= 0.0) ||
                                  (is_buy ? (trail_sl > cur_sl) : (trail_sl < cur_sl));
            // Never trail past entry into a loss on a buy/sell beyond breakeven.
            const bool valid_side = is_buy ? (trail_sl < market) : (trail_sl > market);
            if(trail_sl > 0.0 && improves && valid_side)
               QM_TM_MoveSL(ticket, trail_sl, "trail_remainder");
           }
        }
     }
  }

// No discretionary close beyond SL / partial / trail.
bool Strategy_ExitSignal()
  {
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
