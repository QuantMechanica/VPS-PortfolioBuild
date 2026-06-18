#property strict
#property version   "5.0"
#property description "QM5_11527 ciurea-engulfing-m30 — M30 2-bar engulfing reversal, 3-bar SL + 2R TP"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11527 ciurea-engulfing-m30
// -----------------------------------------------------------------------------
// Source: Cristina Ciurea, "The Truth Behind Commonly Used Indicators",
//         ScientificForex.com, ~2012. Surefire Trading Challenge 2011 winner.
//         Card: artifacts/cards_approved/QM5_11527_ciurea-engulfing-m30.md
//         (g0_status: APPROVED).
//
// Mechanics (M30, closed-bar reads; the engulfing bar is shift 1, the prior
// bar shift 2; entry is a MARKET order at the open of the new bar shift 0):
//   Trigger EVENT: a completed 2-bar engulfing pattern at shift 1 —
//     bar[1] engulfs bar[2] in range (high[1] > high[2] AND low[1] < low[2])
//     AND the two bars are opposite in direction.
//       Bullish engulf : bar[1] closes up (c1 > o1), bar[2] closes down
//                        (c2 < o2)  -> BUY at next bar open.
//       Bearish engulf : bar[1] closes down (c1 < o1), bar[2] closes up
//                        (c2 > o2)  -> SELL at next bar open.
//     There is NO trend-MA state filter in this card — the engulfing bar is
//     the single trigger event, so the two-cross-same-bar zero-trade trap
//     cannot occur (only one event is ever required).
//   Gapless CFD  : .DWX FX CFDs are gapless (open[0] == close[1]). The range
//                  engulf uses >=/<= comparisons on prior high/low rather than
//                  a strict gap, so the pattern still fires (DWX invariant 6).
//   Stop         : 3-bar extreme of the bars at shift 1..3, padded by
//                  strategy_sl_pad_pips. LONG  -> lowest low  - pad.
//                  SHORT -> highest high + pad. Capped at strategy_sl_cap_pips
//                  (P2 cap = 30 pips).
//   Take profit  : strategy_tp_rr (= 2.0) times the stop distance.
//   No-Friday    : suppress NEW entries on Friday (card filter).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread — DWX invariant 1).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11527;
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
input int    strategy_sl_lookback_bars   = 3;     // bars (shift 1..N) for the SL extreme
input double strategy_sl_pad_pips        = 3.0;   // pad beyond the 3-bar extreme (pips)
input double strategy_sl_cap_pips        = 30.0;  // P2 stop-loss cap (pips)
input double strategy_tp_rr              = 2.0;   // take-profit at this R-multiple
input double strategy_min_body_pips      = 0.0;   // optional min engulfing-bar body (0 = off)
input double strategy_spread_cap_pips    = 12.0;  // skip only a genuinely wide spread (pips)
input bool   strategy_no_friday_entry    = true;  // suppress NEW entries on Friday

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// pip size for the active symbol (5-digit / JPY aware). Uses the framework
// pips->price-distance converter so a 1-pip distance is scale-correct.
double PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread);
// the no-Friday-entry rule is applied in Strategy_EntrySignal so it suppresses
// only NEW entries, not position management.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = strategy_spread_cap_pips * PipSize();
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap > 0.0 && spread > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate) and runs
// once per new M30 bar. Detects a completed 2-bar engulfing pattern at shift 1
// and enters a MARKET order at the new bar's open in the engulf direction.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (card filter). TimeCurrent() == broker time;
   // the new M30 bar opens on the broker clock, so day-of-week is exact.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Closed-bar OHLC of the engulfing bar (shift 1) and prior bar (shift 2).
   // perf-allowed: bespoke candle-pattern math, single closed-bar reads only.
   const double o1 = iOpen(_Symbol,  PERIOD_M30, 1);
   const double h1 = iHigh(_Symbol,  PERIOD_M30, 1);
   const double l1 = iLow(_Symbol,   PERIOD_M30, 1);
   const double c1 = iClose(_Symbol, PERIOD_M30, 1);
   const double o2 = iOpen(_Symbol,  PERIOD_M30, 2);
   const double h2 = iHigh(_Symbol,  PERIOD_M30, 2);
   const double l2 = iLow(_Symbol,   PERIOD_M30, 2);
   const double c2 = iClose(_Symbol, PERIOD_M30, 2);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 ||
      o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || c2 <= 0.0)
      return false;

   const double pip = PipSize();
   if(pip <= 0.0)
      return false;

   // --- Optional minimum engulfing-bar body filter (P3 sweep hook; off at 0) ---
   if(strategy_min_body_pips > 0.0)
     {
      const double body = MathAbs(c1 - o1);
      if(body < strategy_min_body_pips * pip)
         return false;
     }

   // --- 2-bar engulfing pattern at shift 1 (card mechanic) ---
   //   Range engulf: bar[1] high>prior high AND bar[1] low<prior low.
   //   Bars opposite in direction; bar[1] direction sets trade side.
   const bool range_engulf = (h1 > h2) && (l1 < l2);
   const bool bull_engulf  = range_engulf && (c1 > o1) && (c2 < o2);
   const bool bear_engulf  = range_engulf && (c1 < o1) && (c2 > o2);

   if(bull_engulf)
     {
      // SL = lowest low over shift 1..N, minus pad. Market BUY at new bar open.
      const int idx = iLowest(_Symbol, PERIOD_M30, MODE_LOW, strategy_sl_lookback_bars, 1);
      if(idx < 0)
         return false;
      const double swing_low = iLow(_Symbol, PERIOD_M30, idx);
      if(swing_low <= 0.0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      double sl = swing_low - strategy_sl_pad_pips * pip;
      // Enforce the P2 stop-loss cap (distance entry->sl).
      const double cap_dist = strategy_sl_cap_pips * pip;
      if((entry - sl) > cap_dist)
         sl = entry - cap_dist;
      if(sl <= 0.0 || entry <= sl)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);

      req.type        = QM_BUY;
      req.price       = 0.0; // framework fills market price at send
      req.sl          = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp          = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
      req.reason      = "ciurea_engulf_long";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   if(bear_engulf)
     {
      // SL = highest high over shift 1..N, plus pad. Market SELL at new bar open.
      const int idx = iHighest(_Symbol, PERIOD_M30, MODE_HIGH, strategy_sl_lookback_bars, 1);
      if(idx < 0)
         return false;
      const double swing_high = iHigh(_Symbol, PERIOD_M30, idx);
      if(swing_high <= 0.0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      double sl = swing_high + strategy_sl_pad_pips * pip;
      const double cap_dist = strategy_sl_cap_pips * pip;
      if((sl - entry) > cap_dist)
         sl = entry + cap_dist;
      if(sl <= 0.0 || sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);

      req.type        = QM_SELL;
      req.price       = 0.0; // framework fills market price at send
      req.sl          = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp          = (tp > 0.0) ? QM_TM_NormalizePrice(_Symbol, tp) : 0.0;
      req.reason      = "ciurea_engulf_short";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   return false;
  }

// Fixed SL/TP only; no active management beyond the bracket set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — the position runs to its SL or 2R TP.
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
