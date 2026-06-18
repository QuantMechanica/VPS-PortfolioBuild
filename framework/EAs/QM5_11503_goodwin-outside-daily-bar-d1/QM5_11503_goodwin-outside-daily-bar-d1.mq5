#property strict
#property version   "5.0"
#property description "QM5_11503 goodwin-outside-daily-bar-d1 — Outside Daily Bar Reversal (counter-trend, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11503 goodwin-outside-daily-bar-d1
// -----------------------------------------------------------------------------
// Source: Jarrod Goodwin, "Beat the Markets — Strategy Guidebook" (~2014),
//         attributing the Outside Bar pattern to Larry Williams (1999).
// Card: artifacts/cards_approved/QM5_11503_goodwin-outside-daily-bar-d1.md
//       (g0_status APPROVED).
//
// Mechanics (counter-trend, closed D1 bars at shift 1 vs shift 2):
//   Outside-bar STATE : H[1] > H[2] AND L[1] < L[2] (yesterday's D1 range
//                       fully engulfs the day before).
//   LONG  trigger EVENT : close[1] < L[2]  — the engulfing bar closes BELOW the
//                       prior low (looks like a continuation down). Goodwin /
//                       Williams read this as exhausted selling -> contrarian
//                       long on the next open.
//   SHORT trigger EVENT : close[1] > H[2]  — the engulfing bar closes ABOVE the
//                       prior high -> contrarian short on the next open.
//   The outside-bar is a STATE; the directional close is the SINGLE trigger
//   EVENT. LONG and SHORT are mutually exclusive (close cannot be below L[2]
//   and above H[2] simultaneously), so there is no two-cross zero-trade trap.
//   Entry  : market order at the open of the new (current) D1 bar.
//   Stop   : 200 pips fixed (scale-correct via QM_StopRulesPipsToPriceDistance).
//   Target : 2 x SL distance (2:1 R/R) via QM_TakeRR.
//   Max hold: close after strategy_max_hold_bars closed D1 bars.
//   Filters: no Friday entry; spread cap (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11503;
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
input int    strategy_sl_pips            = 200;    // fixed stop distance, pips
input double strategy_tp_rr              = 2.0;    // take-profit as R-multiple of the stop (2:1)
input int    strategy_max_hold_bars      = 5;      // close after N closed D1 bars if no TP/SL
input bool   strategy_no_friday_entry    = true;   // skip new entries on Friday
input double strategy_spread_cap_pips    = 30.0;   // skip entry if spread > this many pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread cap only — fail-open on .DWX zero modeled
// spread (ask == bid in the tester). Pattern logic lives on the closed-bar path
// in Strategy_EntrySignal.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero/negative modeled spread (.DWX) — never block

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   // Only a genuinely wide spread blocks entry.
   if(spread > cap_distance)
      return true;

   return false;
  }

// Counter-trend entry on the directional close of a D1 outside bar.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (per card).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // Prior two CLOSED D1 bars (bounded, perf-allowed: structural OHLC reads).
   const double h1 = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: closed-bar OHLC
   const double l1 = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed
   const double c1 = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed
   const double h2 = iHigh(_Symbol, PERIOD_D1, 2);  // perf-allowed
   const double l2 = iLow(_Symbol, PERIOD_D1, 2);   // perf-allowed
   if(h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 || h2 <= 0.0 || l2 <= 0.0)
      return false;

   // --- Outside-bar STATE: yesterday's range engulfs the day before. ---
   const bool outside_bar = (h1 > h2 && l1 < l2);
   if(!outside_bar)
      return false;

   // --- Directional close = SINGLE trigger EVENT (mutually exclusive). ---
   const bool long_signal  = (c1 < l2); // engulfing close below prior low -> contrarian long
   const bool short_signal = (c1 > h2); // engulfing close above prior high -> contrarian short
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType dir = long_signal ? QM_BUY : QM_SELL;

   // Entry at the current market price (open of the new D1 bar).
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Fixed-pip stop (scale-correct), 2:1 take-profit as R-multiple of the stop.
   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;  // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_signal ? "goodwin_outside_long" : "goodwin_outside_short";
   return true;
  }

// No active trade management beyond the fixed SL/TP. Max-hold exit lives in
// Strategy_ExitSignal (evaluated once per closed bar via the OnTick new-bar gate
// is NOT used for exits, so the bar-count check below uses position open time).
void Strategy_ManageOpenPosition()
  {
  }

// Max-hold exit: close the position after strategy_max_hold_bars closed D1 bars
// have elapsed since the entry bar's open. SL/TP handle the rest.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(strategy_max_hold_bars <= 0)
      return false;

   // Open time of THIS EA's position.
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(open_time <= 0)
      return false;

   // Current closed-bar open time (shift 1) vs the entry bar's open. The number
   // of fully-closed D1 bars since entry is measured in whole D1 spans.
   const datetime bar1_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar time
   if(bar1_time <= 0)
      return false;

   const long elapsed_bars = (long)((bar1_time - open_time) / (long)PeriodSeconds(PERIOD_D1));
   if(elapsed_bars >= (long)strategy_max_hold_bars)
      return true;

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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
