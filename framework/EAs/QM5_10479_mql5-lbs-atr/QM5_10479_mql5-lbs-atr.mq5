#property strict
#property version   "5.0"
#property description "QM5_10479 MQL5 LBS ATR Scheduled Stop Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10479 mql5-lbs-atr
// -----------------------------------------------------------------------------
// Source: MQL5 CodeBase "LBS - expert for MetaTrader 5" (idea Scriptor, code
//         Vladimir Karputov / barabashkakvn, https://www.mql5.com/en/code/22884).
//
// Mechanic (per APPROVED card QM5_10479):
//   Schedule : at a NEW signal bar (H1 baseline), allow a setup only when the
//              current broker hour equals one of three configured source hours.
//   Range    : ATR(14) on the last closed bar; recent max/min from the two most
//              recent CLOSED bars (shifts 1 and 2 — shift 0 is the forming bar).
//   Entry    : straddle pending pair —
//                Buy  Stop at max(high[1],high[2]) + ATR(14)
//                Sell Stop at min(low[1],low[2])  - ATR(14)
//   Stop     : SL = ATR(14) from the pending entry price, fixed at placement.
//   Take     : TP = 2R (2 * stop distance), fixed at placement.
//   Sibling  : when one pending fills, cancel the remaining sibling pending(s).
//   Cancel   : unfilled pendings are cancelled at the next configured setup hour
//              or at broker day-end; they also carry an expiration to day-end.
//   Time stop: close an open position after 12 signal-TF bars OR at broker
//              day-end, whichever comes first.
//   Sizing   : framework risk model (RISK_FIXED $1,000 backtest); one position
//              per magic number; no trailing, grid, martingale or averaging.
//
// Only the five Strategy_* hooks (plus pure helpers) are implemented; all
// framework wiring below the marker is the canonical skeleton and stays intact.
//
// .DWX invariants honoured: spread guard fails OPEN on zero/equal spread (#1);
// QM_IsNewBar consumed ONCE per tick by the framework OnTick (#3); schedule is
// in BROKER time keyed off the bar-open clock, not an exact tick minute (#5,
// #12); ATR offset is a single-bar ATR against single-bar extremes (no
// multi-bar range compression — #7 N/A); SL/TP are price levels, not raw points.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10479;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf      = PERIOD_H1;  // baseline H1 (M15 testable variant)
input int             strategy_atr_period     = 14;         // ATR period for breakout offset + SL
input int             strategy_setup_hour_1   = 8;          // first scheduled setup hour (broker time)
input int             strategy_setup_hour_2   = 12;         // second scheduled setup hour (broker time)
input int             strategy_setup_hour_3   = 16;         // third scheduled setup hour (broker time)
input double          strategy_tp_rr          = 2.0;        // take-profit in R multiples (2R baseline)
input int             strategy_hold_bars      = 12;         // time-stop: close after N signal-TF bars
input double          strategy_max_spread_stop_frac = 0.15; // skip entry if spread > frac * stop distance

// -----------------------------------------------------------------------------
// Helpers (pure / O(1) per call — no per-EA new-bar gate; OnTick drives the
// single QM_IsNewBar consume).
// -----------------------------------------------------------------------------

ENUM_TIMEFRAMES Strategy_SignalTF()
  {
   if(strategy_signal_tf == PERIOD_CURRENT)
      return (ENUM_TIMEFRAMES)_Period;
   return strategy_signal_tf;
  }

// Broker hour of the current (forming) signal-TF bar, keyed off bar-open time
// (.DWX invariant #12 — never gate on an exact tick minute).
int Strategy_CurrentBarHour()
  {
   const datetime bar_open = iTime(_Symbol, Strategy_SignalTF(), 0);
   if(bar_open <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   return dt.hour;
  }

// True when the current bar-open hour matches one of the three setup hours.
bool Strategy_IsSetupHour()
  {
   const int h = Strategy_CurrentBarHour();
   if(h < 0)
      return false;
   return (h == strategy_setup_hour_1 ||
           h == strategy_setup_hour_2 ||
           h == strategy_setup_hour_3);
  }

// Seconds remaining until broker day-end (00:00) measured from the current
// bar-open clock. Used to expire unfilled pendings at day-end.
int Strategy_SecondsToBrokerDayEnd()
  {
   const datetime bar_open = iTime(_Symbol, Strategy_SignalTF(), 0);
   if(bar_open <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(bar_open, dt);
   const int seconds_today = dt.hour * 3600 + dt.min * 60 + dt.sec;
   const int left = 86400 - seconds_today;
   return (left > 0) ? left : 0;
  }

// Genuine-wide-spread guard ONLY. .DWX quotes ask==bid (0 modeled spread) in the
// tester, so this fails OPEN on zero/equal spread (invariant #1) and blocks only
// a real positive spread wider than frac * stop distance.
bool Strategy_SpreadTooWideForStop(const double stop_distance)
  {
   if(stop_distance <= 0.0 || strategy_max_spread_stop_frac < 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)   // zero/equal spread -> fail open
      return false;

   const double spread = ask - bid;
   return (spread > stop_distance * strategy_max_spread_stop_frac);
  }

// Locate this EA's single open position (by magic + symbol).
bool Strategy_GetOurPosition(ENUM_POSITION_TYPE &ptype,
                             datetime &time_open,
                             ulong &ticket)
  {
   ptype     = POSITION_TYPE_BUY;
   time_open = 0;
   ticket    = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype     = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      time_open = (datetime)PositionGetInteger(POSITION_TIME);
      ticket    = t;
      return true;
     }
   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime time_open;
   ulong ticket;
   return Strategy_GetOurPosition(ptype, time_open, ticket);
  }

// Count this EA's resting pending orders on this symbol.
int Strategy_PendingCount()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return 0;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
  }

// Cancel all of this EA's resting pending orders on this symbol.
void Strategy_CancelOurPendings(const string reason)
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      QM_TM_RemovePendingOrder(ticket, reason);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick. Cheap O(1) checks only. Management and
// exits stay live for an open position; only NEW entries are gated here.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_IsSetupHour())
      return true;
   return false;
  }

// Populate `req` and return TRUE if a NEW entry should fire on this closed bar.
// Caller guarantees QM_IsNewBar() == true. This places the straddle pending
// pair: the framework opens the BUY_STOP from the returned `req`; the sibling
// SELL_STOP is sent here directly via QM_TM_OpenPosition. Lots come from the
// framework risk model (req.sl set) — never sized inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type               = QM_BUY_STOP;
   req.price              = 0.0;
   req.sl                 = 0.0;
   req.tp                 = 0.0;
   req.reason             = "";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic; do not stack a new straddle while in a trade or
   // while sibling pendings are still resting.
   if(Strategy_HasOpenPosition())
      return false;
   if(Strategy_PendingCount() > 0)
      return false;
   if(!Strategy_IsSetupHour())
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();

   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   // Recent max/min from the two most recent CLOSED bars (shifts 1 and 2).
   const double high_1 = iHigh(_Symbol, tf, 1);
   const double high_2 = iHigh(_Symbol, tf, 2);
   const double low_1  = iLow(_Symbol, tf, 1);
   const double low_2  = iLow(_Symbol, tf, 2);
   if(high_1 <= 0.0 || high_2 <= 0.0 || low_1 <= 0.0 || low_2 <= 0.0)
      return false;

   const double recent_max = MathMax(high_1, high_2);
   const double recent_min = MathMin(low_1, low_2);

   const double buy_stop_price  = QM_StopRulesNormalizePrice(_Symbol, recent_max + atr);
   const double sell_stop_price = QM_StopRulesNormalizePrice(_Symbol, recent_min - atr);
   if(buy_stop_price <= 0.0 || sell_stop_price <= 0.0 || buy_stop_price <= sell_stop_price)
      return false;

   if(strategy_tp_rr <= 0.0 || strategy_atr_period <= 0)
      return false;

   // Pendings expire at broker day-end (belt-and-suspenders with the explicit
   // day-end / next-setup cancellation in management).
   const int exp_secs = Strategy_SecondsToBrokerDayEnd();

   // --- Buy Stop leg: SL = ATR below entry, TP = strategy_tp_rr * R. ---
   const double buy_sl = QM_StopATRFromValue(_Symbol, QM_BUY_STOP, buy_stop_price, atr, 1.0);
   if(buy_sl <= 0.0)
      return false;
   const double buy_tp = QM_TakeRR(_Symbol, QM_BUY_STOP, buy_stop_price, buy_sl, strategy_tp_rr);
   if(buy_tp <= 0.0)
      return false;

   const double buy_stop_distance = MathAbs(buy_stop_price - buy_sl);
   if(buy_stop_distance <= 0.0)
      return false;
   if(Strategy_SpreadTooWideForStop(buy_stop_distance))
      return false;

   // --- Sell Stop leg: SL = ATR above entry, TP = strategy_tp_rr * R. ---
   const double sell_sl = QM_StopATRFromValue(_Symbol, QM_SELL_STOP, sell_stop_price, atr, 1.0);
   const double sell_tp = (sell_sl > 0.0)
                          ? QM_TakeRR(_Symbol, QM_SELL_STOP, sell_stop_price, sell_sl, strategy_tp_rr)
                          : 0.0;

   // Send the sibling SELL_STOP directly (the framework opens the BUY_STOP from
   // the returned req). Only send when its own SL/TP/spread checks pass.
   if(sell_sl > 0.0 && sell_tp > 0.0)
     {
      const double sell_stop_distance = MathAbs(sell_stop_price - sell_sl);
      if(sell_stop_distance > 0.0 && !Strategy_SpreadTooWideForStop(sell_stop_distance))
        {
         QM_EntryRequest sell_req;
         sell_req.type               = QM_SELL_STOP;
         sell_req.price              = sell_stop_price;
         sell_req.sl                 = sell_sl;
         sell_req.tp                 = sell_tp;
         sell_req.reason             = "LBS_ATR_SELL_STOP";
         sell_req.symbol_slot        = qm_magic_slot_offset;
         sell_req.expiration_seconds = exp_secs;

         ulong sell_ticket = 0;
         QM_TM_OpenPosition(sell_req, sell_ticket);
        }
     }

   // Return the BUY_STOP leg for the framework to send.
   req.type               = QM_BUY_STOP;
   req.price              = buy_stop_price;
   req.sl                 = buy_sl;
   req.tp                 = buy_tp;
   req.reason             = "LBS_ATR_BUY_STOP";
   req.symbol_slot        = qm_magic_slot_offset;
   req.expiration_seconds = exp_secs;
   return true;
  }

// Called every tick. Sibling-cancellation + day-end pending cleanup. No
// trailing / break-even / partial close per card.
void Strategy_ManageOpenPosition()
  {
   // Sibling cancel: once a pending has filled into a position, drop any
   // remaining resting pendings (no simultaneous opposing exposure).
   if(Strategy_HasOpenPosition())
     {
      if(Strategy_PendingCount() > 0)
         Strategy_CancelOurPendings("LBS_ATR_SIBLING_CANCEL");
      return;
     }

   // No open position: cancel unfilled pendings at broker day-end (00:00 hour)
   // or whenever a fresh setup hour arrives without a fill (the next straddle
   // is only placed after these are cleared — see Strategy_EntrySignal guard).
   if(Strategy_PendingCount() > 0)
     {
      const int h = Strategy_CurrentBarHour();
      if(h == 0)
         Strategy_CancelOurPendings("LBS_ATR_DAY_END_CANCEL");
      else if(Strategy_IsSetupHour())
         Strategy_CancelOurPendings("LBS_ATR_NEXT_SETUP_CANCEL");
     }
  }

// Return TRUE to close the open position now: time stop after N signal-TF bars
// OR at broker day-end (hour rolled to 0), whichever comes first.
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime time_open;
   ulong ticket;
   if(!Strategy_GetOurPosition(ptype, time_open, ticket))
      return false;

   const ENUM_TIMEFRAMES tf = Strategy_SignalTF();

   // End of trading day: close once the broker day has rolled (hour 0).
   if(Strategy_CurrentBarHour() == 0)
      return true;

   // Fixed holding period: close once N closed signal-TF bars elapsed.
   if(strategy_hold_bars > 0 && time_open > 0)
     {
      const int bars_since_entry = iBarShift(_Symbol, tf, time_open, false);
      if(bars_since_entry >= strategy_hold_bars)
         return true;
     }

   return false;
  }

// Optional news-filter override. Defer to the central framework filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Single QM_IsNewBar consume per
   // tick (invariant #3) — exit/management above use position/order state, not
   // the new-bar event.
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
