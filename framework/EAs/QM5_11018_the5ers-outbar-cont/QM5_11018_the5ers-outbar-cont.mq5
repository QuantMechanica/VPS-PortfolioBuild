#property strict
#property version   "5.0"
#property description "QM5_11018 the5ers-outbar-cont — Outside-Bar Pullback Continuation (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11018 the5ers-outbar-cont
// -----------------------------------------------------------------------------
// Source: The5ers blog "Outside Bar Trading" (continuation variant).
// Card: artifacts/cards_approved/QM5_11018_the5ers-outbar-cont.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2; H4):
//   Outside bar (shift 1) : high[1] > high[2] AND low[1] < low[2].
//   Uptrend STATE         : EMA(fast) > EMA(slow), both slopes positive
//                           (EMA[1] > EMA[2]), and close[1] above EMA(slow).
//   Downtrend STATE       : mirror.
//   Pullback STATE        : within the prior 5 bars (shifts 2..6) at least one
//                           bar touched/closed beyond EMA(fast) toward the mean
//                           WITHOUT closing past EMA(slow) (uptrend: low<=EMA20
//                           or close<EMA20, and close>=EMA50; downtrend mirror).
//   Range filter          : 1.0*ATR <= (high[1]-low[1]) <= 3.0*ATR.
//   Long  entry  EVENT     : outside bar closes bullish (close[1] > open[1]) →
//                            BUY STOP one tick above high[1].
//   Short entry  EVENT     : outside bar closes bearish (close[1] < open[1]) →
//                            SELL STOP one tick below low[1].
//   Pending expiry         : order_expiry_bars H4 bars (default 2).
//   Initial SL             : sl_atr_mult * ATR from the stop-entry price.
//   Risk-cap filter        : skip if initial risk distance > risk_cap_pct of the
//                            20-day ATR converted to H4 units (D1 ATR / 6).
//   First target           : partial-close tp1_partial_pct at tp1_atr_mult * ATR.
//   Break-even             : move SL to entry once price reaches be_trigger_pct of
//                            the first-target distance.
//   Trail                  : remaining size trailed by trail_atr_mult * ATR.
//   Final target (TP)      : final_rr R, set as the order TP at placement.
//   Signal exit            : H4 closes on the wrong side of EMA(slow).
//   Time stop              : close after time_stop_bars H4 bars.
//   Spread guard           : skip only a genuinely wide spread (fail-open on .DWX
//                            zero modeled spread).
//
// One position per magic; pending order is also single-instance per magic.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11018;
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
input int    strategy_ema_fast_period   = 20;     // trend fast EMA
input int    strategy_ema_slow_period   = 50;     // trend slow EMA / signal-exit reference
input int    strategy_pullback_bars     = 5;      // bars before outside bar to scan for pullback
input int    strategy_atr_period        = 14;     // ATR period (filter / stop / target)
input double strategy_range_min_atr     = 1.0;    // outside-bar range must be >= this * ATR
input double strategy_range_max_atr     = 3.0;    // outside-bar range must be <= this * ATR
input int    strategy_order_expiry_bars = 2;      // pending-order expiry in H4 bars
input double strategy_sl_atr_mult       = 2.0;    // initial SL distance = mult * ATR
input double strategy_tp1_atr_mult      = 2.0;    // first-target distance = mult * ATR
input double strategy_tp1_partial_pct   = 50.0;   // % of position closed at first target
input double strategy_be_trigger_pct    = 80.0;   // % of first-target reached -> SL to BE
input double strategy_trail_atr_mult    = 2.0;    // trail distance = mult * ATR
input double strategy_final_rr          = 7.0;    // final TP in R multiples
input int    strategy_time_stop_bars    = 24;     // close after this many H4 bars
input double strategy_risk_cap_d1_pct   = 75.0;   // skip if SL dist > pct of (D1 ATR / 6)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope per-position management state. One position per magic, so a single
// latch set is sufficient. Advanced on the per-tick management path.
// -----------------------------------------------------------------------------
ulong  g_pos_ticket        = 0;       // ticket currently being managed
double g_pos_entry_price   = 0.0;     // fill price
double g_pos_atr_at_entry  = 0.0;     // ATR sampled at first observation of the fill
double g_pos_tp1_distance  = 0.0;     // first-target distance (tp1_atr_mult * ATR)
bool   g_pos_is_buy        = false;
bool   g_pos_partial_done  = false;
bool   g_pos_be_done       = false;
datetime g_pos_open_bar    = 0;       // H4 bar-open time at which the position opened

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Count pending orders carrying this EA's magic on the current symbol.
int CountPendingOrders(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
  }

// Select the live position for this magic on this symbol; return its ticket or 0.
ulong SelectMagicPosition(const int magic)
  {
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      return ticket;
     }
   return 0;
  }

void ResetPositionState()
  {
   g_pos_ticket       = 0;
   g_pos_entry_price  = 0.0;
   g_pos_atr_at_entry = 0.0;
   g_pos_tp1_distance = 0.0;
   g_pos_is_buy       = false;
   g_pos_partial_done = false;
   g_pos_be_done      = false;
   g_pos_open_bar     = 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the closed outside bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic; and only one live pending order at a time.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(CountPendingOrders(magic) > 0)
      return false;

   // --- Closed-bar OHLC (perf-allowed single-shift structural reads) ---
   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1  = iLow(_Symbol, _Period, 1);
   const double open1 = iOpen(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2  = iLow(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || open1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0)
      return false;

   // --- Outside bar (shift 1 engulfs shift 2) ---
   const bool outside_bar = (high1 > high2 && low1 < low2);
   if(!outside_bar)
      return false;

   // --- Range filter: 1.0*ATR <= range <= 3.0*ATR ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double bar_range = high1 - low1;
   if(bar_range < strategy_range_min_atr * atr_value)
      return false;
   if(bar_range > strategy_range_max_atr * atr_value)
      return false;

   // --- Trend STATE (closed bar): EMA stack + slope + close vs slow EMA ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_1 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool slopes_up   = (ema_fast_1 > ema_fast_2 && ema_slow_1 > ema_slow_2);
   const bool slopes_down = (ema_fast_1 < ema_fast_2 && ema_slow_1 < ema_slow_2);

   const bool uptrend   = (ema_fast_1 > ema_slow_1) && slopes_up   && (close1 > ema_slow_1);
   const bool downtrend = (ema_fast_1 < ema_slow_1) && slopes_down && (close1 < ema_slow_1);
   if(!uptrend && !downtrend)
      return false;

   // --- Pullback STATE within the 5 bars preceding the outside bar (shifts 2..6).
   //     Uptrend: at least one bar touched/closed below EMA(fast) WITHOUT closing
   //     below EMA(slow). Downtrend mirror. ---
   bool pullback = false;
   const int first_shift = 2;
   const int last_shift  = strategy_pullback_bars + 1; // 5 bars -> shifts 2..6
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double low_s   = iLow(_Symbol, _Period, s);
      const double high_s  = iHigh(_Symbol, _Period, s);
      const double close_s = iClose(_Symbol, _Period, s);
      if(low_s <= 0.0 || high_s <= 0.0 || close_s <= 0.0)
         continue;

      const double ema_fast_s = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s);
      const double ema_slow_s = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
      if(ema_fast_s <= 0.0 || ema_slow_s <= 0.0)
         continue;

      if(uptrend)
        {
         const bool touched = (low_s <= ema_fast_s || close_s < ema_fast_s);
         const bool not_broken = (close_s >= ema_slow_s);
         if(touched && not_broken)
           {
            pullback = true;
            break;
           }
        }
      else // downtrend
        {
         const bool touched = (high_s >= ema_fast_s || close_s > ema_fast_s);
         const bool not_broken = (close_s <= ema_slow_s);
         if(touched && not_broken)
           {
            pullback = true;
            break;
           }
        }
     }
   if(!pullback)
      return false;

   // --- Direction EVENT: outside bar must close in the trend direction ---
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double one_tick  = (tick_size > 0.0) ? tick_size
                                              : SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(one_tick <= 0.0)
      return false;

   QM_OrderType side;
   double stop_entry;
   if(uptrend)
     {
      if(!(close1 > open1))      // outside bar must close bullish
         return false;
      side = QM_BUY_STOP;
      stop_entry = high1 + one_tick;
     }
   else
     {
      if(!(close1 < open1))      // outside bar must close bearish
         return false;
      side = QM_SELL_STOP;
      stop_entry = low1 - one_tick;
     }
   stop_entry = QM_TM_NormalizePrice(_Symbol, stop_entry);
   if(stop_entry <= 0.0)
      return false;

   // --- SL from the stop-entry price ---
   const QM_OrderType pos_side = uptrend ? QM_BUY : QM_SELL;
   const double sl = QM_StopATRFromValue(_Symbol, pos_side, stop_entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double sl_distance = MathAbs(stop_entry - sl);
   if(sl_distance <= 0.0)
      return false;

   // --- Risk-cap filter: SL distance must not exceed pct of (20-day ATR in H4
   //     units). 20-day ATR ~= ATR(20) on D1; H4 has 6 bars/day so divide by 6. ---
   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, 20, 1);
   if(d1_atr > 0.0)
     {
      const double d1_atr_h4_units = d1_atr / 6.0;
      const double cap = (strategy_risk_cap_d1_pct / 100.0) * d1_atr_h4_units;
      if(cap > 0.0 && sl_distance > cap)
         return false;
     }

   // --- Final target TP = final_rr R from the stop-entry price ---
   const double tp = QM_TakeRR(_Symbol, pos_side, stop_entry, sl, strategy_final_rr);
   if(tp <= 0.0)
      return false;

   // --- Build the pending stop order. Framework sizes lots from req.price/req.sl. ---
   req.type   = side;
   req.price  = stop_entry;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = uptrend ? "outbar_cont_long" : "outbar_cont_short";
   req.expiration_seconds = strategy_order_expiry_bars * PeriodSeconds(_Period);
   return true;
  }

// Per-tick management of the open position: latch state on fill, partial at
// first target, SL to break-even, ATR trail of the remainder.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const ulong ticket = SelectMagicPosition(magic);
   if(ticket == 0)
     {
      if(g_pos_ticket != 0)
         ResetPositionState();
      return;
     }

   // New fill -> latch entry state.
   if(ticket != g_pos_ticket)
     {
      ResetPositionState();
      g_pos_ticket      = ticket;
      g_pos_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      g_pos_is_buy      = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      g_pos_open_bar    = iTime(_Symbol, _Period, 0); // bar-open of current bar
      double atr_now = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      if(atr_now <= 0.0)
         atr_now = 0.0;
      g_pos_atr_at_entry = atr_now;
      g_pos_tp1_distance = strategy_tp1_atr_mult * atr_now;
     }

   if(g_pos_entry_price <= 0.0 || g_pos_tp1_distance <= 0.0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mkt = g_pos_is_buy ? bid : ask;
   if(mkt <= 0.0)
      return;

   const double favorable = g_pos_is_buy ? (mkt - g_pos_entry_price)
                                         : (g_pos_entry_price - mkt);

   // --- First target: partial close once price reaches tp1 distance. ---
   if(!g_pos_partial_done && favorable >= g_pos_tp1_distance)
     {
      const double vol = PositionGetDouble(POSITION_VOLUME);
      const double part = QM_TM_NormalizeVolume(_Symbol, vol * (strategy_tp1_partial_pct / 100.0));
      if(part > 0.0 && part < vol)
        {
         if(QM_TM_PartialClose(ticket, part, QM_EXIT_STRATEGY))
            g_pos_partial_done = true;
        }
      else
        {
         // Cannot split (min-lot floor) — treat first target as reached without
         // partial so BE/trail logic still progresses.
         g_pos_partial_done = true;
        }
     }

   // --- Break-even: move SL to entry once price reaches be_trigger_pct of tp1. ---
   if(!g_pos_be_done && favorable >= (strategy_be_trigger_pct / 100.0) * g_pos_tp1_distance)
     {
      if(QM_TM_MoveSL(ticket, QM_TM_NormalizePrice(_Symbol, g_pos_entry_price), "outbar_cont_be"))
         g_pos_be_done = true;
     }

   // --- Trail the remainder by trail_atr_mult * ATR once the partial is done. ---
   if(g_pos_partial_done)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Discretionary exit: H4 closes on the wrong side of EMA(slow), or the time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_pos_ticket == 0)
      return false;

   // --- Time stop: close after time_stop_bars H4 bars. ---
   if(g_pos_open_bar > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0);
      if(cur_bar > 0)
        {
         const int bars_held = (int)((cur_bar - g_pos_open_bar) / PeriodSeconds(_Period));
         if(bars_held >= strategy_time_stop_bars)
            return true;
        }
     }

   // --- Signal exit: closed H4 bar on the wrong side of EMA(slow). ---
   const double close1   = iClose(_Symbol, _Period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(close1 <= 0.0 || ema_slow <= 0.0)
      return false;

   if(g_pos_is_buy)
      return (close1 < ema_slow);
   return (close1 > ema_slow);
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
