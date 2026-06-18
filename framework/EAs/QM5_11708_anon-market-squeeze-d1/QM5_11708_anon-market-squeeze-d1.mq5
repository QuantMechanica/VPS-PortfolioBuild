#property strict
#property version   "5.0"
#property description "QM5_11708 anon-market-squeeze-d1 — TTM-style squeeze release breakout (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11708 anon-market-squeeze-d1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Scalping Forex Strategies — Forex Market Squeeze",
//   self-published PDF (93933996), ~2014.
// Card: artifacts/cards_approved/QM5_11708_anon-market-squeeze-d1.md (g0_status APPROVED).
//
// Realization (per build directive — TTM-squeeze-style, framework-native):
//   The card's "market squeeze" concept is built as a volatility-compression
//   regime + release breakout. The raw 2-day OHLC pending-sell-stop wording in
//   the card body cannot be expressed cleanly with the .DWX-gapless tester and
//   QM_* helpers, so the squeeze is realized the canonical TTM way:
//
//   Bollinger Bands : QM_BB_Upper/Lower(bb_period, bb_dev)  (deviation MANDATORY).
//   Keltner Channel : EMA(kc_period) +/- kc_atr_mult * ATR(atr_period).
//
//   Squeeze STATE   : BB strictly INSIDE KC
//                       (BB_Upper < KC_Upper) AND (BB_Lower > KC_Lower).
//                     = low-volatility compression regime.
//   Release EVENT   : squeeze was ON one bar ago (shift 2) and is OFF on the
//                     last closed bar (shift 1). This single on->off transition
//                     is the ONE trigger event (no two-cross-same-bar trap).
//   Direction STATE : close[1] vs BB_Middle[1] — break up => long, down => short.
//   Stop            : QM_StopATR(atr_period, sl_atr_mult) from entry.
//   Take profit     : QM_TakeRR(rr) off entry/SL (R-multiple).
//
//   All reads are closed-bar (shift 1 latest, shift 2 prior). One position per
//   magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no external feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11708;
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
input int    strategy_bb_period          = 20;    // Bollinger period
input double strategy_bb_dev             = 2.0;    // Bollinger deviation (MANDATORY arg)
input int    strategy_kc_period          = 20;    // Keltner EMA midline period
input int    strategy_atr_period         = 20;    // ATR period (Keltner width + stop)
input double strategy_kc_atr_mult        = 1.5;   // Keltner channel = EMA +/- mult*ATR
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_rr                 = 2.0;   // take-profit R-multiple
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Squeeze-ON STATE at the given closed-bar shift: Bollinger Bands strictly
// inside the Keltner Channel (low-volatility compression). Returns false on any
// unavailable buffer read (warmup) so the gate fails closed safely.
bool SqueezeOnAt(const int shift)
  {
   const double bb_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   const double bb_lo = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   if(bb_up <= 0.0 || bb_lo <= 0.0)
      return false;

   const double mid = QM_EMA(_Symbol, _Period, strategy_kc_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return false;

   const double kc_up = mid + strategy_kc_atr_mult * atr;
   const double kc_lo = mid - strategy_kc_atr_mult * atr;

   // BB inside KC => compression.
   return (bb_up < kc_up && bb_lo > kc_lo);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Squeeze-release breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Release EVENT: squeeze ON at shift 2, OFF at shift 1 (single transition) ---
   const bool sq_prev = SqueezeOnAt(2);
   const bool sq_now  = SqueezeOnAt(1);
   if(!(sq_prev && !sq_now))
      return false; // not a fresh release this bar

   // --- Direction STATE: last closed bar vs the BB midline ---
   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(mid1 <= 0.0 || close1 <= 0.0)
      return false;

   QM_OrderType dir;
   double entry;
   if(close1 > mid1)
     {
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(close1 < mid1)
     {
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false; // exactly on the midline — no directional break

   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, dir, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "squeeze_release_breakout";
   return true;
  }

// Fixed ATR stop + RR target manage the trade; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond SL/TP.
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
