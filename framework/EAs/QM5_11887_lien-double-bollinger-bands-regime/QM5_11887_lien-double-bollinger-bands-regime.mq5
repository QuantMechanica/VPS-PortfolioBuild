#property strict
#property version   "5.0"
#property description "QM5_11887 lien-double-bollinger-bands-regime — Kathy Lien Double-BB regime classifier + Range->Trend zone entry (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11887 lien-double-bollinger-bands-regime
// -----------------------------------------------------------------------------
// Source: Kathy Lien, "Battle Tested Forex Trading Strategies" (BKForex, 2011),
//         Double Bollinger Bands chapter (slides 20-33).
// Card: artifacts/cards_approved/QM5_11887_lien-double-bollinger-bands-regime.md
//       (g0_status APPROVED). Sister card of QM5_11476 (same DBB family) but this
//       card is the H4 *regime classifier + Range->Trend transition* realisation:
//       the 1SD band classifies three regimes and entry needs a multi-bar Range
//       dwell BEFORE the breakout into the trend zone.
//
// Mechanics (closed-bar reads at shift 1; H4):
//   Two BB sets, same period (20), inner deviation 1.0 and outer deviation 2.0.
//   The INNER (1SD) band classifies the regime of each closed bar:
//     Uptrend Zone   : Close > BB1_upper
//     Range Zone     : BB1_lower <= Close <= BB1_upper
//     Downtrend Zone : Close < BB1_lower
//
//   Entry EVENT (new-trend transition):
//     LONG  : the `dwell` consecutive closed bars PRECEDING the trigger bar were
//             ALL in the Range Zone (shifts 2 .. dwell+1), AND the latest closed
//             bar (shift 1) closes into the Uptrend Zone but NOT past the outer
//             extreme:  BB1_upper < Close[1] < BB2_upper.
//     SHORT : mirror — `dwell` prior Range-Zone closes, then Close[1] into the
//             Downtrend Zone but not past the extreme:  BB2_lower < Close[1] < BB1_lower.
//   The trigger is ONE transition event (the dwell is a prior STATE, the breakout
//   is the EVENT) — this is the two-cross-same-bar trap avoidance: a single fresh
//   close into the zone fires, never two coincident crosses. A pullback back into
//   Range re-arms the dwell naturally.
//
//   Exit (trend exhaustion) = the latest closed bar re-enters the Range Zone:
//     long  -> Close[1] <= BB1_upper[1]
//     short -> Close[1] >= BB1_lower[1]
//
//   Stop loss (card): 15 pips below BB1_upper at the signal bar for longs
//                     (just below the Uptrend-Zone boundary); 15 pips above
//                     BB1_lower for shorts. No fixed TP — the Range re-entry rule
//                     rides the trend.
//
//   Spread guard fails OPEN on .DWX zero modeled spread; blocks only a genuinely
//   wide spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11887;
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
input int    strategy_bb_period           = 20;    // Bollinger period (both bands)
input double strategy_bb_dev_inner         = 1.0;   // inner band deviation (1SD regime edge)
input double strategy_bb_dev_outer         = 2.0;   // outer band deviation (2SD extreme cap)
input int    strategy_range_dwell_bars     = 6;     // min consecutive Range-Zone closes before the breakout
input double strategy_sl_pips_behind_zone  = 15.0;  // SL distance behind the 1SD zone boundary (pips)
input double strategy_spread_cap_pips      = 20.0;  // skip a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// All regime/zone work is on the closed-bar entry path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   const double spread     = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(spread > 0.0 && spread_cap > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Double-BB regime entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Inner/outer band values at the trigger bar (shift 1). ---
   const double bb1_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb2_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);
   const double bb2_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);
   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0 || bb2_up_1 <= 0.0 || bb2_lo_1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Breakout EVENT at the trigger bar (into the trend zone, not past extreme) ---
   const bool enter_long  = (close1 >  bb1_up_1 && close1 <  bb2_up_1);
   const bool enter_short = (close1 <  bb1_lo_1 && close1 >  bb2_lo_1);
   if(!enter_long && !enter_short)
      return false;

   // --- Range-Zone dwell STATE: the `dwell` bars PRECEDING the trigger (shifts
   //     2 .. dwell+1) must ALL have closed inside the 1SD Range Zone. Each bar is
   //     classified against its OWN inner band (recomputed per shift).            ---
   const int dwell = (strategy_range_dwell_bars < 1) ? 1 : strategy_range_dwell_bars;
   const int first_shift = 2;
   const int last_shift  = dwell + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double bb1_up_s = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, s);
      const double bb1_lo_s = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, s);
      if(bb1_up_s <= 0.0 || bb1_lo_s <= 0.0)
         return false;

      const double close_s = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(close_s <= 0.0)
         return false;

      // Bar must be in the Range Zone: BB1_lower <= Close <= BB1_upper.
      if(close_s < bb1_lo_s || close_s > bb1_up_s)
         return false; // a non-Range bar in the window breaks the dwell -> no entry
     }

   // --- Build entry. Framework sizes lots (no lots field). SL = 15 pips behind the
   //     1SD zone boundary at the signal bar.                                      ---
   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips_behind_zone);
   if(sl_dist <= 0.0)
      return false;

   if(enter_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL = 15 pips below the inner upper band (Uptrend-Zone boundary).
      const double sl = QM_StopRulesNormalizePrice(_Symbol, bb1_up_1 - sl_dist);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — Range re-entry rule rides the trend
      req.reason = "dbb_regime_uptrend_zone";
      return true;
     }

   // enter_short
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;

   // SL = 15 pips above the inner lower band (Downtrend-Zone boundary).
   const double sl_s = QM_StopRulesNormalizePrice(_Symbol, bb1_lo_1 + sl_dist);
   if(sl_s <= 0.0 || sl_s <= entry_s)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;   // no fixed TP — Range re-entry rule rides the trend
   req.reason = "dbb_regime_downtrend_zone";
   return true;
  }

// No active trade management beyond the fixed band stop. Exit is the Range-Zone
// re-entry rule in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Trend-exhaustion exit: the latest closed bar re-enters the 1SD Range Zone.
//   long  -> Close[1] <= BB1_upper[1]   short -> Close[1] >= BB1_lower[1]
// Evaluated once per closed bar in OnTick; one position per magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double bb1_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine the direction of the open position for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      break;
     }

   if(is_long  && close1 <= bb1_up_1)
      return true; // long: dropped back into the Range Zone -> trend exhausted
   if(is_short && close1 >= bb1_lo_1)
      return true; // short: popped back into the Range Zone -> trend exhausted

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
