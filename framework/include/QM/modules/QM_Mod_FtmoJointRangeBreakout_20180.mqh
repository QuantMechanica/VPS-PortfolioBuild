#ifndef QM_MOD_FTMO_JOINT_RANGE_BREAKOUT_20180_MQH
#define QM_MOD_FTMO_JOINT_RANGE_BREAKOUT_20180_MQH

// =============================================================================
// QM5_20180 FTMO JOINT (backtest-only) — shared range-breakout signal module.
// -----------------------------------------------------------------------------
// This is a COPY of the QM5_9936 / QM5_13213 range-breakout algorithm, made
// per-sleeve reentrant so ONE module can host BOTH USDJPY sleeves of the joint
// FTMO backtest instrument (ea_id 20180) on ONE account in ONE tester run.
//
// WHY A COPY, NOT A RE-POINT (adversarial-review H2):
//   The design's §11 recommended re-pointing 9936/13213 at a shared include to
//   "prove" the module. The review refuted that: 9936 is the gated FTMO lead
//   sleeve and 13213 is gated; recompiling them against a new include risks
//   silently invalidating their gated Q08 streams and forcing a full re-gate.
//   So the logic is COPIED here and the gated EAs are left untouched. Fidelity
//   is proven instead by SINGLETON REPLAY (run this EA with a single sleeve on
//   USDJPY host and diff its Q08 stream against the gated sleeve's stream).
//
// FIDELITY — verified line-for-line against the two gated sources 2026-07-27:
//   framework/EAs/QM5_9936_ff-range-breakout-gmt3-h1/...mq5   (lines 197-416)
//   framework/EAs/QM5_13213_balke-gmt3-range-breakout/...mq5  (lines 198-420)
//   The two EAs are identical EXCEPT for window/cancel/close hours. 9936 uses
//   TWO evening hours (cancel=13, close=20); 13213 collapses them into ONE
//   evening flat (exit_hour=18 drives BOTH the pending-cancel AND the session
//   close). The design's binding recipe ("bind the rest to 9936's defaults")
//   was WRONG for 13213 — it would set 13213's cancel hour to 13 instead of 18
//   (adversarial-review M2). This module therefore takes cancel_hr and close_hr
//   as INDEPENDENT parameters and the joint EA binds 13213's sleeve to
//   cancel_hr=18, close_hr=18.
//
// HOST-SYMBOL ONLY: both sleeves trade _Symbol (USDJPY.DWX = host chart), so
// every data accessor stays _Symbol-bound exactly as in the gated sources —
// there is NO non-host per-tick cadence divergence (adversarial-review C1-C4,
// which killed the 3-sleeve XAUUSD variant, do not arise here).
// =============================================================================

#include <QM/QM_Common.mqh>

// Per-sleeve immutable parameters (bound once in OnInit from the gated sets).
struct QM_FJ_RB_Params
  {
   bool   enabled;
   int    slot;                // 0 (host) or 1
   int    magic;               // resolved via QM_MagicFor(ea_id, slot)
   int    explicit_magic;      // 0 for host slot (default QM_Entry path == 9936); else magic
   int    range_start_hr;      // GMT+3
   int    range_end_hr;        // GMT+3 (entry fires on the bar whose GMT+3 hour == this)
   int    cancel_hr;           // GMT+3 pending-cancel hour   (9936=13; 13213=18)
   int    close_hr;            // GMT+3 session-close hour     (9936=20; 13213=18)
   int    atr_period;
   double min_range_atr_mult;
   double max_range_atr_mult;
   double trail_trigger_r;
   int    range_scan_bars;
   string reason_prefix;       // "FF_RANGE" (9936) or "BALKE_RANGE" (13213)
  };

// Per-sleeve mutable daily state (was file-level globals in the gated sources).
struct QM_FJ_RB_State
  {
   double range_high;
   double range_low;
   int    range_day_key;
   int    orders_day_key;
   int    skip_day_key;
  };

void QM_FJ_RB_StateInit(QM_FJ_RB_State &st)
  {
   st.range_high     = 0.0;
   st.range_low      = 0.0;
   st.range_day_key  = -1;
   st.orders_day_key = -1;
   st.skip_day_key   = -1;
  }

// --- GMT+3-normalized time helpers (verbatim from the gated sources) ---------
int QM_FJ_RB_Gmt3DayKey(const datetime broker_time)
  {
   const datetime utc  = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int QM_FJ_RB_Gmt3Hour(const datetime broker_time)
  {
   const datetime utc  = QM_BrokerToUTC(broker_time);
   const datetime gmt3 = utc + 3 * 3600;
   MqlDateTime dt;
   TimeToStruct(gmt3, dt);
   return dt.hour;
  }

double QM_FJ_RB_NormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = 8;
   return NormalizeDouble(price, digits);
  }

bool QM_FJ_RB_IsOurPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP);
  }

// --- Order / position bookkeeping, filtered per sleeve magic ------------------
int QM_FJ_RB_RemoveOurPendingOrders(const QM_FJ_RB_Params &p, const string reason)
  {
   int removed = 0;
   const int magic = p.magic;
   if(magic <= 0)
      return 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!QM_FJ_RB_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      if(QM_TM_RemovePendingOrder(ticket, reason))
         removed++;
     }
   return removed;
  }

bool QM_FJ_RB_HasOurPendingOrders(const QM_FJ_RB_Params &p)
  {
   const int magic = p.magic;
   if(magic <= 0)
      return false;
   for(int i = 0; i < OrdersTotal(); ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(QM_FJ_RB_IsOurPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

bool QM_FJ_RB_HasOurOpenPosition(const QM_FJ_RB_Params &p)
  {
   const int magic = p.magic;
   if(magic <= 0)
      return false;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool QM_FJ_RB_BuildRangeForToday(const QM_FJ_RB_Params &p, const int day_key,
                                 double &range_high, double &range_low)
  {
   range_high = -DBL_MAX;
   range_low  = DBL_MAX;
   int bars_in_range = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, p.range_scan_bars, rates); // perf-allowed: closed-bar session range scan, bounded by input default 36.
   if(copied <= 0)
      return false;

   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_time = rates[i].time;
      if(QM_FJ_RB_Gmt3DayKey(bar_time) != day_key)
         continue;
      const int hour = QM_FJ_RB_Gmt3Hour(bar_time);
      if(hour < p.range_start_hr || hour >= p.range_end_hr)
         continue;
      range_high = MathMax(range_high, rates[i].high);
      range_low  = MathMin(range_low, rates[i].low);
      bars_in_range++;
     }

   return (bars_in_range >= (p.range_end_hr - p.range_start_hr) &&
           range_high > range_low && range_low > 0.0);
  }

void QM_FJ_RB_ResetDailyState(const QM_FJ_RB_Params &p, QM_FJ_RB_State &st, const int day_key)
  {
   if(st.range_day_key == day_key || st.orders_day_key == day_key || st.skip_day_key == day_key)
      return;
   st.range_high = 0.0;
   st.range_low  = 0.0;
  }

void QM_FJ_RB_PopulateEntry(const QM_FJ_RB_Params &p, QM_EntryRequest &req,
                            const QM_OrderType type, const double entry,
                            const double sl, const string reason)
  {
   req.type               = type;
   req.price              = QM_FJ_RB_NormalizePrice(entry);
   req.sl                 = QM_FJ_RB_NormalizePrice(sl);
   req.tp                 = 0.0;
   req.reason             = reason;
   req.symbol_slot        = p.slot;
   req.expiration_seconds = 0;
  }

// --- Per-tick "no-trade filter" (resets daily state; verbatim behaviour) ------
void QM_FJ_RB_NoTradeFilter(const QM_FJ_RB_Params &p, QM_FJ_RB_State &st)
  {
   const int day_key = QM_FJ_RB_Gmt3DayKey(TimeCurrent());
   QM_FJ_RB_ResetDailyState(p, st, day_key);
  }

// --- Entry: place BOTH breakout stop orders (was EntrySignal + caller open) ---
// Mirrors QM5_9936 Strategy_EntrySignal (opens the BUY_STOP internally, returns
// the SELL_STOP to the caller which opens it). Here both legs open through the
// SAME QM_Entry path the gated EAs use — sleeve 0 with explicit_magic=0 (the
// default resolver path 9936/13213 use), sleeve 1 with its registered magic.
void QM_FJ_RB_TryEntry(const QM_FJ_RB_Params &p, QM_FJ_RB_State &st)
  {
   const datetime now     = TimeCurrent();
   const int      day_key = QM_FJ_RB_Gmt3DayKey(now);
   const int      hour    = QM_FJ_RB_Gmt3Hour(now);
   if(hour != p.range_end_hr)
      return;
   if(st.orders_day_key == day_key || st.skip_day_key == day_key)
      return;
   if(QM_FJ_RB_HasOurOpenPosition(p) || QM_FJ_RB_HasOurPendingOrders(p))
      return;

   double range_high = 0.0;
   double range_low  = 0.0;
   if(!QM_FJ_RB_BuildRangeForToday(p, day_key, range_high, range_low))
      return;

   const double atr          = QM_ATR(_Symbol, PERIOD_H1, p.atr_period, 1);
   const double range_height = range_high - range_low;
   if(atr <= 0.0 || range_height <= 0.0)
      return;
   if(range_height < p.min_range_atr_mult * atr ||
      range_height > p.max_range_atr_mult * atr)
     {
      st.skip_day_key = day_key;
      return;
     }

   st.range_high    = range_high;
   st.range_low     = range_low;
   st.range_day_key = day_key;

   QM_EntryRequest buy_req;
   QM_FJ_RB_PopulateEntry(p, buy_req, QM_BUY_STOP, range_high, range_low, p.reason_prefix + "_BUY_STOP");
   ulong buy_ticket = 0;
   QM_TM_OpenPosition(buy_req, buy_ticket, p.explicit_magic);

   st.orders_day_key = day_key;

   QM_EntryRequest sell_req;
   QM_FJ_RB_PopulateEntry(p, sell_req, QM_SELL_STOP, range_low, range_high, p.reason_prefix + "_SELL_STOP");
   ulong sell_ticket = 0;
   QM_TM_OpenPosition(sell_req, sell_ticket, p.explicit_magic);
  }

// --- Per-tick management: cancel-at-hour, cancel-opposite, +1R 2-bar trail -----
void QM_FJ_RB_ManageOpenPosition(const QM_FJ_RB_Params &p, QM_FJ_RB_State &st)
  {
   const datetime now  = TimeCurrent();
   const int      hour = QM_FJ_RB_Gmt3Hour(now);
   if(hour >= p.cancel_hr)
      QM_FJ_RB_RemoveOurPendingOrders(p, p.reason_prefix + "_CANCEL_HOUR");

   const int magic = p.magic;
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_FJ_RB_RemoveOurPendingOrders(p, p.reason_prefix + "_OPPOSITE_TRIGGERED");

      const ENUM_POSITION_TYPE pos_type   = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double             open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double             current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_dist = MathAbs(open_price - current_sl);
      if(risk_dist <= 0.0)
         continue;

      const bool   is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < p.trail_trigger_r * risk_dist)
         continue;

      const double low1  = iLow(_Symbol, PERIOD_H1, 1);  // perf-allowed: constant two-bar structural trailing read.
      const double low2  = iLow(_Symbol, PERIOD_H1, 2);  // perf-allowed: constant two-bar structural trailing read.
      const double high1 = iHigh(_Symbol, PERIOD_H1, 1); // perf-allowed: constant two-bar structural trailing read.
      const double high2 = iHigh(_Symbol, PERIOD_H1, 2); // perf-allowed: constant two-bar structural trailing read.
      if(low1 <= 0.0 || low2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0)
         continue;

      const double target_sl     = is_buy ? MathMin(low1, low2) : MathMax(high1, high2);
      const double normalized_sl = QM_FJ_RB_NormalizePrice(target_sl);
      if(normalized_sl <= 0.0)
         continue;

      const double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const bool   improves = is_buy ? (normalized_sl > current_sl + point * 0.5)
                                     : (normalized_sl < current_sl - point * 0.5);
      if(improves)
         QM_TM_MoveSL(ticket, normalized_sl, p.reason_prefix + "_2BAR_SWING_TRAIL");
     }
  }

// --- Discretionary exit test: session-close hour OR range opposite-side touch --
bool QM_FJ_RB_ExitSignal(const QM_FJ_RB_Params &p, QM_FJ_RB_State &st)
  {
   const datetime now = TimeCurrent();
   if(QM_FJ_RB_Gmt3Hour(now) >= p.close_hr)
      return true;

   const int magic = p.magic;
   if(magic <= 0 || st.range_high <= 0.0 || st.range_low <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) <= st.range_low)
         return true;
      if(pos_type == POSITION_TYPE_SELL && SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= st.range_high)
         return true;
     }
   return false;
  }

// Close every open position for this sleeve's magic (was the OnTick close loop).
void QM_FJ_RB_CloseAll(const QM_FJ_RB_Params &p)
  {
   const int magic = p.magic;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

#endif // QM_MOD_FTMO_JOINT_RANGE_BREAKOUT_20180_MQH
