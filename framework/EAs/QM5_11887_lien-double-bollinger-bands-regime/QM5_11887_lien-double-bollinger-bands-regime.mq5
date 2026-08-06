#property strict
#property version   "5.1"
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
input int    strategy_sl_pips_behind_zone  = 15;    // SL distance behind the 1SD zone boundary (pips)
input int    strategy_spread_cap_pips      = 20;    // skip a genuinely wide spread (pips)

// Closed-bar state. Indicator reads are performed once after QM_IsNewBar()
// rather than on every tick.
int    g_signal_direction   = 0; // +1 long, -1 short, 0 none
double g_signal_zone_edge   = 0.0;
bool   g_exit_requested     = false;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "EURUSD.DWX") return 0;
   if(_Symbol == "GBPUSD.DWX") return 1;
   if(_Symbol == "USDJPY.DWX") return 2;
   if(_Symbol == "USDCAD.DWX") return 3;
   if(_Symbol == "USDCHF.DWX") return 4;
   if(_Symbol == "AUDUSD.DWX") return 5;
   if(_Symbol == "NZDUSD.DWX") return 6;
   if(_Symbol == "EURJPY.DWX") return 7;
   if(_Symbol == "GBPJPY.DWX") return 8;
   if(_Symbol == "AUDJPY.DWX") return 9;
   return -1;
  }

bool Strategy_ConfigurationAuthorized()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   return (qm_ea_id == 11887 &&
           expected_slot >= 0 &&
           qm_magic_slot_offset == expected_slot &&
           (ENUM_TIMEFRAMES)_Period == PERIOD_H4 &&
           strategy_bb_period >= 2 && strategy_bb_period <= 250 &&
           strategy_bb_dev_inner > 0.0 &&
           strategy_bb_dev_outer > strategy_bb_dev_inner &&
           strategy_range_dwell_bars >= 1 && strategy_range_dwell_bars <= 100 &&
           strategy_sl_pips_behind_zone >= 1 && strategy_sl_pips_behind_zone <= 1000 &&
           strategy_spread_cap_pips >= 1 && strategy_spread_cap_pips <= 1000);
  }

bool Strategy_SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                              strategy_spread_cap_pips);
   return (spread > 0.0 && spread_cap > 0.0 && spread > spread_cap);
  }

// Consume the H4 regime transition and the rule-based exit once per completed
// bar. The six dwell bars are shifts 2..7; shift 1 is the fresh zone breakout.
void AdvanceState_OnNewBar()
  {
   g_signal_direction = 0;
   g_signal_zone_edge = 0.0;
   g_exit_requested = false;

   if(!Strategy_ConfigurationAuthorized())
      return;

   const double bb1_up_1 = QM_BB_Upper(_Symbol, PERIOD_H4,
                                       strategy_bb_period,
                                       strategy_bb_dev_inner, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, PERIOD_H4,
                                       strategy_bb_period,
                                       strategy_bb_dev_inner, 1);
   const double bb2_up_1 = QM_BB_Upper(_Symbol, PERIOD_H4,
                                       strategy_bb_period,
                                       strategy_bb_dev_outer, 1);
   const double bb2_lo_1 = QM_BB_Lower(_Symbol, PERIOD_H4,
                                       strategy_bb_period,
                                       strategy_bb_dev_outer, 1);
   const double close1 = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: fixed read behind QM_IsNewBar().
   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0 ||
      bb2_up_1 <= 0.0 || bb2_lo_1 <= 0.0 || close1 <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   int matching_positions = 0;
   long position_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ++matching_positions;
      position_type = PositionGetInteger(POSITION_TYPE);
     }

   if(matching_positions > 0)
     {
      if(matching_positions != 1)
         g_exit_requested = true;
      else if(position_type == POSITION_TYPE_BUY && close1 <= bb1_up_1)
         g_exit_requested = true;
      else if(position_type == POSITION_TYPE_SELL && close1 >= bb1_lo_1)
         g_exit_requested = true;
      return;
     }

   const bool enter_long = (close1 > bb1_up_1 && close1 < bb2_up_1);
   const bool enter_short = (close1 < bb1_lo_1 && close1 > bb2_lo_1);
   if(!enter_long && !enter_short)
      return;

   const int last_shift = strategy_range_dwell_bars + 1;
   for(int shift = 2; shift <= last_shift; ++shift)
     {
      const double range_up = QM_BB_Upper(_Symbol, PERIOD_H4,
                                          strategy_bb_period,
                                          strategy_bb_dev_inner, shift);
      const double range_lo = QM_BB_Lower(_Symbol, PERIOD_H4,
                                          strategy_bb_period,
                                          strategy_bb_dev_inner, shift);
      const double range_close = iClose(_Symbol, PERIOD_H4, shift); // perf-allowed: bounded dwell read behind QM_IsNewBar().
      if(range_up <= 0.0 || range_lo <= 0.0 || range_close <= 0.0)
         return;
      if(range_close < range_lo || range_close > range_up)
         return;
     }

   g_signal_direction = (enter_long ? +1 : -1);
   g_signal_zone_edge = (enter_long ? bb1_up_1 : bb1_lo_1);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Configuration is fail-closed. The spread guard is entry-only so management
// and rule-based exits continue through a temporary wide spread.
bool Strategy_NoTradeFilter()
  {
   return !Strategy_ConfigurationAuthorized();
  }

// Build the market order from the closed-bar state prepared above.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_signal_direction == 0 || g_signal_zone_edge <= 0.0)
      return false;
   if(Strategy_SpreadTooWide())
      return false;

   const double entry = (g_signal_direction > 0
                         ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                         : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol,
                                                           strategy_sl_pips_behind_zone);
   if(sl_dist <= 0.0)
      return false;

   const double raw_sl = (g_signal_direction > 0
                          ? g_signal_zone_edge - sl_dist
                          : g_signal_zone_edge + sl_dist);
   const double sl = QM_StopRulesNormalizePrice(_Symbol, raw_sl);
   if(sl <= 0.0)
      return false;
   if((g_signal_direction > 0 && sl >= entry) ||
      (g_signal_direction < 0 && sl <= entry))
      return false;

   req.type   = (g_signal_direction > 0 ? QM_BUY : QM_SELL);
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = (g_signal_direction > 0
                 ? "dbb_range_to_uptrend"
                 : "dbb_range_to_downtrend");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// No active trade management beyond the fixed band stop. Exit is the Range-Zone
// re-entry rule in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   return (g_exit_requested &&
           QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
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
   // Q08 evidence must sample floating P&L before any per-tick guard returns.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      AdvanceState_OnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool close_succeeded = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_succeeded = true;
        }
      if(close_succeeded)
         g_exit_requested = false;
     }

   // Custom and central news checks gate NEW entries only. Management and
   // Range-Zone exits above remain active throughout news windows.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req);
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
