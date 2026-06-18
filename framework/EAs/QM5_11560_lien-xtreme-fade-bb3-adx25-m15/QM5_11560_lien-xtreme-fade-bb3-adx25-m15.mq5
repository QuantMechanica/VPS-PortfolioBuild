#property strict
#property version   "5.0"
#property description "QM5_11560 lien-xtreme-fade-bb3-adx25-m15 — Kathy Lien X-Treme Fade (BB 3SD/2SD + ADX<25, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11560 lien-xtreme-fade-bb3-adx25-m15
// -----------------------------------------------------------------------------
// Source: Kathy Lien, "Battle Tested Forex Trading Strategies" (BKForex, ~2012),
//   X-Treme Fade. Card: artifacts/cards_approved/
//   QM5_11560_lien-xtreme-fade-bb3-adx25-m15.md (g0_status APPROVED).
//
// Mechanics (mean-reversion fade, closed-bar reads, M15):
//   Concept : a 3-standard-deviation Bollinger Band excursion is a statistical
//             extreme (over-extension). Price then retraces back inside the 2SD
//             band -> the fade is confirmed and we trade the reversion. Gated by
//             a LOW-ADX regime STATE (range, not a trending breakout) so we never
//             fight a market that is "walking the band".
//
//   Trigger EVENT (one per bar, two DIFFERENT bars -> no same-bar-two-cross trap):
//     LONG (fade a LOW extreme, BUY the reversion up):
//       bar[2] closed at/below 3SD lower  : Close[2] <= BB3SD_lower[2]  (extreme)
//       bar[1] closed back inside 2SD lower: Close[1] >  BB2SD_lower[1]  (retraced)
//     SHORT (fade a HIGH extreme, SELL the reversion down):
//       bar[2] closed at/above 3SD upper  : Close[2] >= BB3SD_upper[2]  (extreme)
//       bar[1] closed back inside 2SD upper: Close[1] <  BB2SD_upper[1]  (retraced)
//     Entry is taken at the OPEN of the freshly-closed new bar (next-bar open),
//     which is exactly when this hook fires under the QM_IsNewBar() gate.
//
//   Regime STATE filter : ADX(adx_period)[1] < adx_max  (ranging market).
//
//   Stop   : structural swing extreme over swing_lookback bars + buffer, capped
//            at sl_cap_pips (card: iHighest/iLowest 5 bars + 2 pips, cap 20p).
//   Target : RR-multiple of the realized stop distance (tp_rr, card: 2.0).
//
//   No-Friday-entry : the card forbids opening new entries on Friday (weekend
//                     gap risk on a held mean-reversion fade).
//
//   Spread guard : block ONLY a genuinely wide spread (fail-open on the .DWX
//                  zero modeled spread, per the .DWX backtest invariants).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11560;
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
input int    strategy_bb_period          = 20;    // Bollinger period (both bands)
input double strategy_bb_dev_outer       = 3.0;   // outer/extreme band deviation (SD)
input double strategy_bb_dev_inner       = 2.0;   // inner/normal band deviation (SD)
input int    strategy_adx_period         = 14;    // ADX period for the regime filter
input double strategy_adx_max            = 25.0;  // ranging regime: ADX must be < this
input int    strategy_swing_lookback     = 5;     // bars for the structural swing stop
input double strategy_sl_buffer_pips     = 2.0;   // buffer added beyond the swing extreme
input double strategy_sl_cap_pips        = 20.0;  // hard cap on the stop distance (pips)
input double strategy_tp_rr              = 2.0;   // take-profit as RR-multiple of stop
input double strategy_spread_cap_pips    = 5.0;   // skip if spread wider than this (pips)
input bool   strategy_no_friday_entry    = true;  // do not open new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path. Fail-open on the .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Absolute spread cap in price (card: 5 pips). Only a genuinely wide spread
   // blocks; zero/negative modeled spread on .DWX passes (fail-open).
   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Mean-reversion fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- No-Friday-entry: block new entries on Friday (broker time). ---
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Regime STATE: low ADX (ranging market) at the closed bar ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx < strategy_adx_max))
      return false;

   // --- Band reads. Outer = extreme (shift 2), inner = normal (shift 1). ---
   // The deviation arg is MANDATORY for QM_BB_*.
   const double bb3_upper_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2);
   const double bb3_lower_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2);
   const double bb2_upper_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb2_lower_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   if(bb3_upper_2 <= 0.0 || bb3_lower_2 <= 0.0 || bb2_upper_1 <= 0.0 || bb2_lower_1 <= 0.0)
      return false;

   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close2 <= 0.0 || close1 <= 0.0)
      return false;

   // --- Trigger EVENT: extreme on bar[2], retrace-into-normal on bar[1]. ---
   // Two different bars -> one trigger event; no two-cross-same-bar zero-trade trap.
   const bool long_fade  = (close2 <= bb3_lower_2) && (close1 > bb2_lower_1);  // fade a low extreme
   const bool short_fade = (close2 >= bb3_upper_2) && (close1 < bb2_upper_1);  // fade a high extreme
   if(!long_fade && !short_fade)
      return false;

   const QM_OrderType dir = long_fade ? QM_BUY : QM_SELL;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: structural swing extreme over the lookback + a fixed buffer. ---
   // (card: iHighest/iLowest 5 bars + 2 pips). Then capped at sl_cap_pips.
   double sl = QM_StopStructure(_Symbol, dir, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   // Push the swing stop a fixed buffer further AWAY from entry (card: +2 pips).
   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_buffer_pips);
   if(buffer_dist > 0.0)
      sl = (dir == QM_BUY) ? (sl - buffer_dist) : (sl + buffer_dist);

   // Hard cap on the stop distance.
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(cap_dist > 0.0 && MathAbs(entry - sl) > cap_dist)
      sl = (dir == QM_BUY) ? (entry - cap_dist) : (entry + cap_dist);

   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Target: RR-multiple of the realized stop distance (card: 2.0). ---
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_fade ? "xtreme_fade_long" : "xtreme_fade_short";
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
