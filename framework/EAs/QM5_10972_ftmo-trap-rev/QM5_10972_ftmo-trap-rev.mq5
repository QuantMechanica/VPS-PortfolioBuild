#property strict
#property version   "5.0"
#property description "QM5_10972 ftmo-trap-rev — Bull/Bear Trap Reversal (false-break reclaim, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10972 ftmo-trap-rev
// -----------------------------------------------------------------------------
// Source: FTMO "Don't get caught in the trap" (2023-09-08).
// Card: artifacts/cards_approved/QM5_10972_ftmo-trap-rev.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads; the just-closed bar at shift 1 is the RECLAIM
// candle that triggers the entry):
//
//   Resistance R = highest high over the swing window [shift 2 .. lookback+1].
//   Support    S = lowest  low  over the same window.
//   Range height = R - S (must be >= range_min_atr_mult * ATR, else skip).
//
//   Bull-trap SHORT:
//     * R was tested >= min_level_tests times in the last test_lookback bars
//       (a bar high within touch_tol_atr_mult*ATR of R counts as a test).
//     * A bar within the last (pierce_window+1) closed bars pierced ABOVE R by
//       >= pierce_atr_mult*ATR  ->  that bar's high is the trap high.
//     * The reclaim candle (shift 1) closes back BELOW R.
//     * Reclaim candle closes in its LOWER reclaim_close_pct of its own range.
//     * RSI(1) > rsi_short_floor  OR  RSI falling from above rsi_overbought.
//     * Trap candle range <= trap_range_atr_mult*ATR (skip violent bars).
//     -> SELL at market on the reclaim close.
//     SL = trap_high + sl_atr_mult*ATR.
//
//   Bear-trap LONG: mirror of the above around support S.
//     SL = trap_low - sl_atr_mult*ATR.
//
//   Take profit = opposite side of the range OR risk_reward*R, whichever is
//                 CLOSER to entry.
//   Move SL to break-even after price has moved 1.0R in favour.
//   Early exit if a closed bar closes back BEYOND the trap extreme.
//   Time exit after time_exit_bars closed H1 bars in the trade.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. The structural
// OHLC reads (iHigh/iLow/iClose/iOpen) run ONLY on the closed-bar gate and over
// bounded windows, so they are perf-allowed for this bespoke level logic.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10972;
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
input int    strategy_swing_lookback     = 40;    // swing window for R/S levels
input int    strategy_test_lookback      = 80;    // bars to count level tests
input int    strategy_min_level_tests    = 2;     // min touches of the level
input int    strategy_pierce_window       = 3;    // reclaim must follow pierce within N bars
input double strategy_atr_period          = 14;   // ATR period (declared double for setfile uniformity)
input int    strategy_rsi_period          = 14;   // RSI period
input double strategy_pierce_atr_mult     = 0.25; // min pierce beyond level, in ATR
input double strategy_touch_tol_atr_mult  = 0.20; // proximity band that counts as a level test
input double strategy_reclaim_close_pct   = 40.0; // reclaim close must be in this % of its range
input double strategy_rsi_short_floor     = 55.0; // short: RSI must exceed this (or be falling from OB)
input double strategy_rsi_long_ceiling    = 45.0; // long: RSI must be below this (or rising from OS)
input double strategy_rsi_overbought      = 70.0; // "falling from above" reference (short)
input double strategy_rsi_oversold        = 30.0; // "rising from below" reference (long)
input double strategy_range_min_atr_mult  = 1.5;  // skip if range height < this * ATR
input double strategy_trap_range_atr_mult = 2.5;  // skip if trap candle range > this * ATR
input double strategy_sl_atr_mult         = 0.30; // SL buffer beyond the trap extreme, in ATR
input double strategy_risk_reward         = 2.0;  // R-multiple TP cap
input int    strategy_be_trigger_r_x10    = 10;   // move to BE after this/10 R (10 = 1.0R)
input int    strategy_time_exit_bars      = 24;   // close after this many closed H1 bars
input double strategy_spread_pct_of_stop  = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope per-trade context. Set when an entry is opened; consumed by the
// management / exit hooks. Single position per magic => one slot is enough.
// -----------------------------------------------------------------------------
double   g_trap_extreme   = 0.0;   // trap high (short) / trap low (long)
double   g_entry_price    = 0.0;   // recorded entry reference for R / BE logic
double   g_stop_distance  = 0.0;   // |entry - sl| at entry, for 1R break-even
bool     g_trade_is_short = false; // direction of the open trade
datetime g_entry_bar_time = 0;     // open time of the bar we entered on
bool     g_trade_active   = false; // whether g_* context is valid

// -----------------------------------------------------------------------------
// Helpers (structural OHLC reads — closed-bar gated, bounded windows).
// -----------------------------------------------------------------------------

// Highest high over [shift_from .. shift_from+count-1].
double SwingHigh(const int shift_from, const int count)
  {
   double hi = 0.0;
   for(int s = shift_from; s < shift_from + count; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed structural read
      if(h > hi)
         hi = h;
     }
   return hi;
  }

// Lowest low over [shift_from .. shift_from+count-1].
double SwingLow(const int shift_from, const int count)
  {
   double lo = 0.0;
   for(int s = shift_from; s < shift_from + count; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed structural read
      if(l <= 0.0)
         continue;
      if(lo <= 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// Count bars in [2 .. test_lookback+1] whose high is within tol of level.
int CountTestsHigh(const double level, const double tol)
  {
   int n = 0;
   const int last = strategy_test_lookback + 1;
   for(int s = 2; s <= last; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s);
      if(h <= 0.0)
         continue;
      if(MathAbs(h - level) <= tol)
         ++n;
     }
   return n;
  }

// Count bars in [2 .. test_lookback+1] whose low is within tol of level.
int CountTestsLow(const double level, const double tol)
  {
   int n = 0;
   const int last = strategy_test_lookback + 1;
   for(int s = 2; s <= last; ++s)
     {
      const double l = iLow(_Symbol, _Period, s);
      if(l <= 0.0)
         continue;
      if(MathAbs(l - level) <= tol)
         ++n;
     }
   return n;
  }

// RSI was above `ob` within the recent window and is now lower (falling from OB).
bool RsiFallingFromAbove(const double ob)
  {
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;
   for(int s = 2; s <= strategy_pierce_window + 2; ++s)
     {
      const double r = QM_RSI(_Symbol, _Period, strategy_rsi_period, s);
      if(r > ob && rsi_now < r)
         return true;
     }
   return false;
  }

// RSI was below `os` within the recent window and is now higher (rising from OS).
bool RsiRisingFromBelow(const double os)
  {
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;
   for(int s = 2; s <= strategy_pierce_window + 2; ++s)
     {
      const double r = QM_RSI(_Symbol, _Period, strategy_rsi_period, s);
      if(r > 0.0 && r < os && rsi_now > r)
         return true;
     }
   return false;
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

   const double atr_value = QM_ATR(_Symbol, _Period, (int)strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true. The just-closed bar (shift 1)
// is the candidate RECLAIM candle.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, (int)strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Swing levels over the window that PRECEDES the pierce/reclaim sequence.
   const int level_from = strategy_pierce_window + 2; // skip reclaim + pierce bars
   const double resistance = SwingHigh(level_from, strategy_swing_lookback);
   const double support    = SwingLow(level_from, strategy_swing_lookback);
   if(resistance <= 0.0 || support <= 0.0)
      return false;

   const double range_height = resistance - support;
   if(range_height < strategy_range_min_atr_mult * atr_value)
      return false; // range too compressed to be a meaningful level

   const double tol = strategy_touch_tol_atr_mult * atr_value;

   // Reclaim candle = shift 1.
   const double r_open  = iOpen(_Symbol, _Period, 1);
   const double r_high  = iHigh(_Symbol, _Period, 1);
   const double r_low   = iLow(_Symbol, _Period, 1);
   const double r_close = iClose(_Symbol, _Period, 1);
   if(r_open <= 0.0 || r_high <= 0.0 || r_low <= 0.0 || r_close <= 0.0)
      return false;
   const double r_range = r_high - r_low;
   if(r_range <= 0.0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // -------------------- Bull-trap SHORT --------------------
   if(CountTestsHigh(resistance, tol) >= strategy_min_level_tests)
     {
      // Find a piercing bar within the reclaim window (shifts 1..pierce_window).
      // The pierce bar's high must exceed R by >= pierce_atr_mult*ATR; the
      // reclaim candle (shift 1) must close back below R.
      const double pierce_min = resistance + strategy_pierce_atr_mult * atr_value;
      double trap_high = 0.0;
      double trap_range_at_extreme = 0.0;
      for(int s = 1; s <= strategy_pierce_window + 1; ++s)
        {
         const double h = iHigh(_Symbol, _Period, s);
         if(h >= pierce_min && h > trap_high)
           {
            trap_high = h;
            const double l = iLow(_Symbol, _Period, s);
            trap_range_at_extreme = (l > 0.0) ? (h - l) : 0.0;
           }
        }

      const bool reclaimed = (r_close < resistance);
      // Close in lower reclaim_close_pct of its own range.
      const double lower_band = r_low + (strategy_reclaim_close_pct / 100.0) * r_range;
      const bool weak_close = (r_close <= lower_band);
      const bool rsi_ok = (rsi_now > strategy_rsi_short_floor) ||
                          RsiFallingFromAbove(strategy_rsi_overbought);
      const bool trap_not_violent = (trap_range_at_extreme > 0.0) &&
                                    (trap_range_at_extreme <= strategy_trap_range_atr_mult * atr_value);

      if(trap_high > 0.0 && reclaimed && weak_close && rsi_ok && trap_not_violent)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID); // sell at market
         if(entry <= 0.0)
            return false;

         const double sl = QM_TM_NormalizePrice(_Symbol, trap_high + strategy_sl_atr_mult * atr_value);
         if(sl <= entry)
            return false;

         // TP = opposite side of range (support) OR risk_reward*R, whichever closer.
         const double risk = sl - entry;
         const double tp_rr    = entry - strategy_risk_reward * risk;
         const double tp_range = support;
         double tp = MathMax(tp_rr, tp_range); // closer to entry = higher price for a short
         tp = QM_TM_NormalizePrice(_Symbol, tp);
         if(tp <= 0.0 || tp >= entry)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "bull_trap_short";

         g_trap_extreme   = trap_high;
         g_entry_price    = entry;
         g_stop_distance  = risk;
         g_trade_is_short = true;
         g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (forming) bar open
         g_trade_active   = true;
         return true;
        }
     }

   // -------------------- Bear-trap LONG --------------------
   if(CountTestsLow(support, tol) >= strategy_min_level_tests)
     {
      const double pierce_max = support - strategy_pierce_atr_mult * atr_value;
      double trap_low = 0.0;
      double trap_range_at_extreme = 0.0;
      for(int s = 1; s <= strategy_pierce_window + 1; ++s)
        {
         const double l = iLow(_Symbol, _Period, s);
         if(l <= 0.0)
            continue;
         if(l <= pierce_max && (trap_low <= 0.0 || l < trap_low))
           {
            trap_low = l;
            const double h = iHigh(_Symbol, _Period, s);
            trap_range_at_extreme = (h > 0.0) ? (h - l) : 0.0;
           }
        }

      const bool reclaimed = (r_close > support);
      const double upper_band = r_high - (strategy_reclaim_close_pct / 100.0) * r_range;
      const bool strong_close = (r_close >= upper_band);
      const bool rsi_ok = (rsi_now < strategy_rsi_long_ceiling) ||
                          RsiRisingFromBelow(strategy_rsi_oversold);
      const bool trap_not_violent = (trap_range_at_extreme > 0.0) &&
                                    (trap_range_at_extreme <= strategy_trap_range_atr_mult * atr_value);

      if(trap_low > 0.0 && reclaimed && strong_close && rsi_ok && trap_not_violent)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK); // buy at market
         if(entry <= 0.0)
            return false;

         const double sl = QM_TM_NormalizePrice(_Symbol, trap_low - strategy_sl_atr_mult * atr_value);
         if(sl <= 0.0 || sl >= entry)
            return false;

         const double risk = entry - sl;
         const double tp_rr    = entry + strategy_risk_reward * risk;
         const double tp_range = resistance;
         double tp = MathMin(tp_rr, tp_range); // closer to entry = lower price for a long
         tp = QM_TM_NormalizePrice(_Symbol, tp);
         if(tp <= entry)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "bear_trap_long";

         g_trap_extreme   = trap_low;
         g_entry_price    = entry;
         g_stop_distance  = risk;
         g_trade_is_short = false;
         g_entry_bar_time = iTime(_Symbol, _Period, 0);
         g_trade_active   = true;
         return true;
        }
     }

   return false;
  }

// Break-even after 1.0R favourable move (configurable via be_trigger_r_x10).
void Strategy_ManageOpenPosition()
  {
   if(!g_trade_active || g_stop_distance <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   const double trigger_move = (strategy_be_trigger_r_x10 / 10.0) * g_stop_distance;
   if(trigger_move <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl     = PositionGetDouble(POSITION_SL);
      const bool   is_buy     = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double mkt = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(mkt <= 0.0 || open_price <= 0.0)
         continue;

      const double moved = is_buy ? (mkt - open_price) : (open_price - mkt);
      if(moved < trigger_move)
         continue;

      const double be = QM_TM_NormalizePrice(_Symbol, open_price);
      const bool already_be = is_buy ? (cur_sl >= be) : (cur_sl > 0.0 && cur_sl <= be);
      if(already_be)
         continue;

      QM_TM_MoveSL(ticket, be, "trap_breakeven_1R");
     }
  }

// Early exit if a closed bar closes back BEYOND the trap extreme, OR time exit
// after time_exit_bars closed H1 bars. Caller closes the position on TRUE.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_trade_active = false;
      return false;
     }
   if(!g_trade_active)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 > 0.0 && g_trap_extreme > 0.0)
     {
      // Beyond the trap extreme = the trap thesis is invalidated.
      if(g_trade_is_short && close1 > g_trap_extreme)
         return true;
      if(!g_trade_is_short && close1 < g_trap_extreme)
         return true;
     }

   // Time exit: count closed H1 bars since entry.
   if(g_entry_bar_time > 0)
     {
      int bars_held = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
      if(bars_held >= strategy_time_exit_bars)
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
      g_trade_active = false;
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
