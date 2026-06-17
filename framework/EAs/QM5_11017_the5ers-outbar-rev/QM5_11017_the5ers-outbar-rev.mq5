#property strict
#property version   "5.0"
#property description "QM5_11017 the5ers-outbar-rev — Outside-Bar Reversal stop-entry (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11017 the5ers-outbar-rev
// -----------------------------------------------------------------------------
// Source: The5ers blog "Outside Bar Trading" (1d445184-...). Card:
//   artifacts/cards_approved/QM5_11017_the5ers-outbar-rev.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads; the "outside bar" is the just-closed bar at
// shift 1, its reference bar is shift 2):
//   Outside bar   : high[1] > high[2]  AND  low[1] < low[2].
//   Range filter  : (high[1]-low[1]) >= range_atr_mult * ATR(14).
//   Bullish setup : close was BELOW EMA(50) for >= trend_min of the prior
//                   trend_window closed bars (shifts 2..trend_window+1) AND the
//                   outside bar closes ABOVE its own midpoint -> place a BUY STOP
//                   one tick above high[1].
//   Bearish setup : close was ABOVE EMA(50) for >= trend_min of that window AND
//                   the outside bar closes BELOW its midpoint -> SELL STOP one
//                   tick below low[1].
//   Pending order expires after expiry_bars D1 bars; only one live order or
//   position per magic at a time.
//   Initial SL    : sl_atr_mult * ATR(14) from the stop-entry price, capped to
//                   the far side of the outside bar if that is farther.
//   Skip          : if the sl_atr_mult*ATR stop exceeds max_stop_pct of price.
//   First target  : tp1_atr_mult * ATR -> close tp1_fraction of the position.
//   Break-even    : move SL to entry once price reaches be_trigger_frac of the
//                   first-target distance.
//   Trail         : remainder trailed by trail_atr_mult * ATR(14).
//   Final target  : close any remainder at final_rr * initial risk (7R).
//   Time stop     : close after max_hold_bars D1 bars.
//
// .DWX invariants honoured: gapless CFDs -> the outside bar uses the prior BAR
// high/low (not a price gap); spread guard fails OPEN on zero modeled spread;
// no swap gate; QM_IsNewBar consumed once on the entry path; sessions n/a (D1);
// stop/target distances scale via ATR, not raw points.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11017;
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
input int    strategy_ema_period         = 50;     // prior-trend EMA
input int    strategy_atr_period         = 14;     // ATR (range / stop / target / trail)
input int    strategy_trend_window       = 15;     // prior-trend lookback bars
input int    strategy_trend_min          = 10;     // min bars on the trend side within the window
input double strategy_range_atr_mult     = 1.2;    // min outside-bar range as a multiple of ATR
input int    strategy_expiry_bars        = 3;      // pending stop-order lifetime, in D1 bars
input double strategy_sl_atr_mult        = 2.0;    // initial stop distance = mult * ATR
input double strategy_max_stop_pct       = 4.0;    // skip if the ATR stop exceeds this % of price
input double strategy_tp1_atr_mult       = 2.0;    // first-target distance = mult * ATR
input double strategy_tp1_fraction        = 0.5;   // fraction closed at the first target
input double strategy_be_trigger_frac    = 0.8;    // move to BE at this fraction of the first target
input double strategy_trail_atr_mult     = 2.0;    // trail distance for the remainder = mult * ATR
input double strategy_final_rr           = 7.0;    // final-target R-multiple for the remainder
input int    strategy_max_hold_bars      = 30;     // time stop, in D1 bars
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Per-position management state (reset whenever a new position ticket appears).
// -----------------------------------------------------------------------------
ulong    g_pos_ticket        = 0;       // ticket currently being managed
double   g_pos_entry         = 0.0;     // actual fill price
double   g_pos_init_sl       = 0.0;     // initial stop price (for R / risk)
double   g_pos_risk_dist     = 0.0;     // |entry - init_sl| (1R distance)
bool     g_pos_is_buy        = false;
bool     g_pos_tp1_done      = false;   // first-target partial taken
bool     g_pos_be_done       = false;   // moved to break-even
datetime g_pos_open_bar      = 0;       // bar-open time at which the position opened

// -----------------------------------------------------------------------------
// Helpers (order/position management — not strategy iX math).
// -----------------------------------------------------------------------------

// Count this EA's live pending orders on the current symbol.
int OutbarPendingCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
  }

// Select this EA's open position on the current symbol; return its ticket or 0.
ulong OutbarSelectOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
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

// Reset cached per-position state for a freshly observed ticket.
void OutbarResetPosState(const ulong ticket)
  {
   if(!PositionSelectByTicket(ticket))
      return;
   g_pos_ticket    = ticket;
   g_pos_entry     = PositionGetDouble(POSITION_PRICE_OPEN);
   g_pos_init_sl   = PositionGetDouble(POSITION_SL);
   g_pos_is_buy    = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   g_pos_risk_dist = (g_pos_init_sl > 0.0) ? MathAbs(g_pos_entry - g_pos_init_sl) : 0.0;
   g_pos_tp1_done  = false;
   g_pos_be_done   = false;
   g_pos_open_bar  = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open stamp
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
      return false; // defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread only

   return false;
  }

// Outside-bar reversal stop-entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One live order OR position per magic/symbol.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(OutbarPendingCount() > 0)
      return false;

   // --- Closed-bar OHLC of the outside bar (shift 1) and its reference (2). ---
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar reads
   const double low1  = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2  = iLow(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   // --- Outside-bar pattern (gapless CFD: prior bar high/low, not a gap). ---
   if(!(high1 > high2 && low1 < low2))
      return false;

   // --- Range filter: meaningful engulfing bar. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double bar_range = high1 - low1;
   if(bar_range < strategy_range_atr_mult * atr_value)
      return false;

   // --- Prior-trend exhaustion vs EMA across shifts 2..trend_window+1. ---
   int below = 0;
   int above = 0;
   const int first_shift = 2;
   const int last_shift  = strategy_trend_window + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: closed-bar read, D1 bounded loop
      if(c <= 0.0)
         continue;
      const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(ema_s <= 0.0)
         continue;
      if(c < ema_s)
         below++;
      else if(c > ema_s)
         above++;
     }

   const double midpoint = (high1 + low1) * 0.5;
   const double tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tick <= 0.0)
      return false;

   // Stop-order lifetime in seconds (D1 bars -> calendar days is the closest the
   // tester honours; pending dedup + new-bar cadence enforce the bar count too).
   const int expiry_seconds = strategy_expiry_bars * 24 * 60 * 60;

   bool is_buy = false;
   double stop_price = 0.0;

   const bool bullish = (below >= strategy_trend_min) && (close1 > midpoint);
   const bool bearish = (above >= strategy_trend_min) && (close1 < midpoint);

   if(bullish && !bearish)
     {
      is_buy = true;
      stop_price = high1 + tick;     // buy stop one tick above the outside-bar high
     }
   else if(bearish && !bullish)
     {
      is_buy = false;
      stop_price = low1 - tick;      // sell stop one tick below the outside-bar low
     }
   else
      return false;

   stop_price = QM_TM_NormalizePrice(_Symbol, stop_price);
   if(stop_price <= 0.0)
      return false;

   // --- Skip if the ATR stop would exceed max_stop_pct of price. ---
   const double atr_stop_dist = strategy_sl_atr_mult * atr_value;
   if((atr_stop_dist / stop_price) * 100.0 > strategy_max_stop_pct)
      return false;

   // --- Initial SL: ATR stop from the stop-entry price, capped to the far side
   //     of the outside bar if that is farther. ---
   double sl_price = 0.0;
   if(is_buy)
     {
      const double atr_sl = stop_price - atr_stop_dist;
      sl_price = MathMin(atr_sl, low1);   // farther = lower for a long
     }
   else
     {
      const double atr_sl = stop_price + atr_stop_dist;
      sl_price = MathMax(atr_sl, high1);  // farther = higher for a short
     }
   sl_price = QM_TM_NormalizePrice(_Symbol, sl_price);
   if(sl_price <= 0.0)
      return false;
   if(is_buy  && !(sl_price < stop_price))
      return false;
   if(!is_buy && !(sl_price > stop_price))
      return false;

   // --- Build the pending stop order. Framework sizes lots from the SL distance.
   //     TP is managed manually (partial/BE/trail/7R/time-stop). ---
   req.type               = is_buy ? QM_BUY_STOP : QM_SELL_STOP;
   req.price              = stop_price;
   req.sl                 = sl_price;
   req.tp                 = 0.0;       // managed in Strategy_ManageOpenPosition
   req.reason             = is_buy ? "outbar_rev_buystop" : "outbar_rev_sellstop";
   req.expiration_seconds = expiry_seconds;
   return true;
  }

// Active management of the open position: first-target partial, break-even,
// ATR trail of the remainder. 7R / time-stop live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
   const ulong ticket = OutbarSelectOwnPosition();
   if(ticket == 0)
     {
      g_pos_ticket = 0;
      return;
     }

   // Newly opened (or re-opened) position -> (re)seed cached state.
   if(ticket != g_pos_ticket)
      OutbarResetPosState(ticket);
   if(g_pos_risk_dist <= 0.0)
      return;

   if(!PositionSelectByTicket(ticket))
      return;
   const double volume = PositionGetDouble(POSITION_VOLUME);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mkt = g_pos_is_buy ? bid : ask;
   if(mkt <= 0.0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double tp1_dist  = strategy_tp1_atr_mult * atr_value;
   const double favourable = g_pos_is_buy ? (mkt - g_pos_entry) : (g_pos_entry - mkt);

   // --- First target: partial close at tp1_dist. ---
   if(!g_pos_tp1_done && tp1_dist > 0.0 && favourable >= tp1_dist)
     {
      const double close_lots = QM_TM_NormalizeVolume(_Symbol, volume * strategy_tp1_fraction);
      if(close_lots > 0.0 && close_lots < volume)
        {
         if(QM_TM_PartialClose(ticket, close_lots, QM_EXIT_PARTIAL))
            g_pos_tp1_done = true;
        }
      else
         g_pos_tp1_done = true; // too small to split — manage as a whole
     }

   // --- Break-even: move SL to entry once price reaches be_trigger_frac of tp1. ---
   if(!g_pos_be_done && tp1_dist > 0.0 &&
      favourable >= strategy_be_trigger_frac * tp1_dist)
     {
      const double be_sl = QM_TM_NormalizePrice(_Symbol, g_pos_entry);
      if(be_sl > 0.0 && QM_TM_MoveSL(ticket, be_sl, "outbar_breakeven"))
         g_pos_be_done = true;
     }

   // --- ATR trail of the remainder (only after the first target is taken). ---
   if(g_pos_tp1_done)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Discretionary closes: final 7R target and the D1 time stop.
bool Strategy_ExitSignal()
  {
   const ulong ticket = OutbarSelectOwnPosition();
   if(ticket == 0)
     {
      g_pos_ticket = 0;
      return false;
     }
   if(ticket != g_pos_ticket)
      OutbarResetPosState(ticket);
   if(g_pos_risk_dist <= 0.0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double mkt = g_pos_is_buy ? bid : ask;
   if(mkt <= 0.0)
      return false;

   // --- Final target: remainder at final_rr * initial risk. ---
   const double favourable = g_pos_is_buy ? (mkt - g_pos_entry) : (g_pos_entry - mkt);
   if(favourable >= strategy_final_rr * g_pos_risk_dist)
      return true;

   // --- Time stop: close after max_hold_bars D1 bars. ---
   if(g_pos_open_bar > 0)
     {
      const int bars_held = iBarShift(_Symbol, _Period, g_pos_open_bar, false);
      if(bars_held >= strategy_max_hold_bars)
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
