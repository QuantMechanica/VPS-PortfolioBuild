#property strict
#property version   "5.0"
#property description "QM5_11423 williams-naked-close-stop-entry-d1 — Larry Williams naked-close reversal, D1 stop-entry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11423 williams-naked-close-stop-entry-d1
// -----------------------------------------------------------------------------
// Source: Larry Williams, "Inner Circle Workshop Trading Method".
// Card: artifacts/cards_approved/QM5_11423_williams-naked-close-stop-entry-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads; bar[1] = signal bar, bar[2] = prior bar):
//   A "naked close" is a D1 bar whose CLOSE penetrates entirely past the prior
//   bar's whole range (a trap for late sellers/buyers). The reversal entry is a
//   STOP order placed beyond the signal bar, expecting price to recover back
//   through the prior day's range.
//
//   Bullish naked close (buy setup):
//     Close[1] < Low[2]                  -> close nakedly below prior bar's range
//     Entry  : BUYSTOP  at  High[1] + 1 pip
//     Stop   :               Low[1]  - 1 pip
//   Bearish naked close (sell setup):
//     Close[1] > High[2]                 -> close nakedly above prior bar's range
//     Entry  : SELLSTOP at  Low[1]  - 1 pip
//     Stop   :               High[1] + 1 pip
//
//   Take profit : 2R from entry (entry + 2*(entry-sl) long; mirror for short).
//   Stop cap    : raw signal-bar stop distance clamped to <= 70 pips (card P2).
//   Day-only    : pending order expires at the end of the signal day (bar[0]);
//                 no carry-over. Stale pendings are also actively cancelled in
//                 Strategy_ManageOpenPosition so an un-filled order never rolls
//                 into the next trading day.
//   One position per magic. Spread guard fails OPEN on .DWX zero modeled spread.
//
//   .DWX gapless-safe: the trigger compares prior CLOSE vs prior RANGE
//   (Close[1] vs Low[2]/High[2]) — a real penetration test, NOT a gap test
//   (open[0]==close[1] on gapless CFDs), so it fires correctly in the tester.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11423;
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
input int    strategy_buffer_pips         = 1;     // pip buffer beyond signal bar for entry/stop
input int    strategy_max_stop_pips       = 70;    // P2 stop-distance cap (pips)
input double strategy_tp_rr               = 2.0;   // take-profit as a risk-multiple
input int    strategy_spread_cap_pips     = 25;    // skip only a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Helpers (pip scale derived from symbol digits, like QM_StopRules).
// -----------------------------------------------------------------------------

double NakedClose_PipSize(const string sym)
  {
   const double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

// Cancel any resting pending order for this EA's magic+symbol. Used to enforce
// "no carry-over": an un-filled signal-day stop order must not roll forward.
void NakedClose_CancelPendings(const int magic, const string sym)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != sym)
         continue;
      QM_TM_RemovePendingOrder(ticket, "naked_close_no_carryover");
     }
  }

bool NakedClose_HasPending(const int magic, const string sym)
  {
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) == sym)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero quote

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide positive spread blocks; zero modeled spread passes.
   if(spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Closed-bar naked-close detection. Caller guarantees QM_IsNewBar() == true.
// Places a day-only STOP order beyond the signal bar (bar[1]).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One trade per magic: block if a position is open OR a pending order is
   // already resting for this magic+symbol (we re-arm fresh each signal day).
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;
   if(NakedClose_HasPending(magic, _Symbol))
      return false;

   // Closed-bar OHLC reads (perf-allowed: bounded single-shift reads, D1).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double high2  = iHigh(_Symbol, _Period, 2);  // perf-allowed
   const double low2   = iLow(_Symbol, _Period, 2);   // perf-allowed
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const double pip = NakedClose_PipSize(_Symbol);
   if(pip <= 0.0)
      return false;
   const double buf = strategy_buffer_pips * pip;

   const double max_stop_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_stop_pips);

   QM_OrderType side;
   double entry = 0.0;
   double sl    = 0.0;

   if(close1 < low2)
     {
      // Bullish naked close -> BUYSTOP above the signal bar high.
      side  = QM_BUY_STOP;
      entry = high1 + buf;
      sl    = low1  - buf;
     }
   else if(close1 > high2)
     {
      // Bearish naked close -> SELLSTOP below the signal bar low.
      side  = QM_SELL_STOP;
      entry = low1  - buf;
      sl    = high1 + buf;
     }
   else
     {
      return false; // no naked close
     }

   if(entry <= 0.0 || sl <= 0.0)
      return false;

   // Stop distance, clamped to the P2 cap (70 pips). Recompute SL from the
   // capped distance so risk-per-trade stays bounded.
   double stop_dist = MathAbs(entry - sl);
   if(stop_dist <= 0.0)
      return false;
   if(max_stop_dist > 0.0 && stop_dist > max_stop_dist)
     {
      stop_dist = max_stop_dist;
      sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_dist);
     }

   // Take profit = tp_rr * risk from the entry (2R per card).
   const double tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, strategy_tp_rr * stop_dist);
   if(tp <= 0.0)
      return false;

   entry = QM_StopRulesNormalizePrice(_Symbol, entry);

   req.type    = side;
   req.price   = entry;     // pending STOP trigger price
   req.sl      = sl;
   req.tp      = tp;
   req.reason  = (side == QM_BUY_STOP) ? "naked_close_buystop" : "naked_close_sellstop";
   // Day-only: cancel if not filled during the signal day (one D1 bar).
   req.expiration_seconds = 24 * 60 * 60;
   return true;
  }

// Per-tick management. Enforce "no carry-over": once a NEW closed bar appears
// (a new trading day), drop any pending order still resting from a prior day's
// signal so it cannot roll forward. The expiration set at send is the primary
// guard; this is a deterministic backstop. Runs on the per-tick path but is
// O(1) outside the once-per-bar new-bar event.
void Strategy_ManageOpenPosition()
  {
   static datetime last_bar = 0;
   const datetime cur_bar = iTime(_Symbol, _Period, 0); // perf-allowed: bar-open ts
   if(cur_bar == last_bar)
      return;
   last_bar = cur_bar;

   const int magic = QM_FrameworkMagic();
   // If a position is open the pending (if any) was the one that filled; leave
   // it. Only cancel resting pendings when no position is open for this magic.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return;
   NakedClose_CancelPendings(magic, _Symbol);
  }

// No discretionary close — exits are the fixed SL / 2R TP attached at entry.
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
