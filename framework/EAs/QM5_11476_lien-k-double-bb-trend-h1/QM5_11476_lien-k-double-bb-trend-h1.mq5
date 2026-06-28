#property strict
#property version   "5.0"
#property description "QM5_11476 lien-k-double-bb-trend-h1 — Kathy Lien Double Bollinger Band trend zone (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11476 lien-k-double-bb-trend-h1
// -----------------------------------------------------------------------------
// Source: Kathy Lien, "Battle Tested Forex Trading Strategies" (BKForex, ~2013),
//         Double Bollinger Band system.
// Card: artifacts/cards_approved/QM5_11476_lien-k-double-bb-trend-h1.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Two BB sets, same period (20), deviations 1.0 and 2.0, divide the chart into
//   five zones. The trade lives in the "buy/sell zone" between the inner (1SD) and
//   outer (2SD) band.
//
//   Buy zone STATE  : BB1_upper <= Close <= BB2_upper   (above the inner upper
//                     band but not past the extreme outer band).
//   Sell zone STATE : BB2_lower <= Close <= BB1_lower.
//   Trend filter STATE (optional): middle band sloping up/down over slope_bars.
//
//   Entry EVENT = price CLOSING INTO the zone: the previous closed bar (shift 2)
//                 was NOT in the buy zone and the latest closed bar (shift 1) IS.
//                 This is ONE transition event — not two coincident crosses — so
//                 it avoids the two-cross-same-bar zero-trade trap. A pullback that
//                 drops out of the zone and re-enters re-arms the event naturally.
//
//   Exit (trend ending) = price closes back into the neutral channel:
//                 long  -> Close[1] <  BB1_upper[1]
//                 short -> Close[1] >  BB1_lower[1]
//
//   Stop loss = opposite inner (1SD) band at the signal bar, expressed in pips;
//               if that distance exceeds sl_cap_pips the setup is SKIPPED (card
//               P2 cap 60 pips). If the dynamic band stop is invalid, fall back to
//               sl_fixed_pips (40). No fixed TP — the zone-exit rule rides the trend.
//
//   Spread guard fails OPEN on .DWX zero modeled spread; blocks only a genuinely
//   wide spread.  No Friday entries (card filter), handled in Strategy_NoTradeFilter.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11476;
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
input double strategy_bb_dev_inner        = 1.0;   // inner band deviation (1SD zone edge)
input double strategy_bb_dev_outer        = 2.0;   // outer band deviation (2SD zone edge)
input bool   strategy_use_slope_filter    = true;  // require middle-band slope in trade direction
input int    strategy_slope_bars          = 5;     // middle-band slope comparison window
input double strategy_sl_fixed_pips        = 40.0; // fallback fixed stop (pips)
input double strategy_sl_cap_pips          = 60.0; // skip setup if dynamic band stop > this (pips)
input double strategy_spread_cap_pips      = 20.0; // skip a genuinely wide spread (pips)
input bool   strategy_no_friday_entry      = true; // card: no Friday entry
input int    strategy_direction_mode       = 0;     // 0 both; 1 long only; -1 short only
input int    strategy_min_exit_bars        = 0;     // minimum bars before neutral-channel exit; 0 = card default

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard fails open on .DWX zero modeled spread.
// The card's no-Friday-entry rule lives in Strategy_EntrySignal so exits still run.
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

// Double-BB zone entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // No Friday entries (broker time). Open positions still manage/exit normally.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Band values at the latest closed bar (shift 1) and the prior bar (shift 2).
   const double bb1_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb1_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
   const double bb2_up_1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);
   const double bb2_lo_1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 1);

   const double bb1_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2);
   const double bb1_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 2);
   const double bb2_up_2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2);
   const double bb2_lo_2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_outer, 2);

   if(bb1_up_1 <= 0.0 || bb1_lo_1 <= 0.0 || bb2_up_1 <= 0.0 || bb2_lo_1 <= 0.0 ||
      bb1_up_2 <= 0.0 || bb1_lo_2 <= 0.0 || bb2_up_2 <= 0.0 || bb2_lo_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Zone membership (STATE) at shift 1 and shift 2 ---
   const bool buy_zone_1  = (close1 >= bb1_up_1 && close1 <= bb2_up_1);
   const bool buy_zone_2  = (close2 >= bb1_up_2 && close2 <= bb2_up_2);
   const bool sell_zone_1 = (close1 <= bb1_lo_1 && close1 >= bb2_lo_1);
   const bool sell_zone_2 = (close2 <= bb1_lo_2 && close2 >= bb2_lo_2);

   // --- Entry EVENT: close TRANSITIONS into the zone (was out, now in) ---
   const bool enter_long  = (buy_zone_1  && !buy_zone_2);
   const bool enter_short = (sell_zone_1 && !sell_zone_2);
   if(!enter_long && !enter_short)
      return false;
   if(strategy_direction_mode > 0 && enter_short)
      return false;
   if(strategy_direction_mode < 0 && enter_long)
      return false;

   // --- Optional middle-band slope filter in the trade direction ---
   if(strategy_use_slope_filter)
     {
      const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
      const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner,
                                           1 + strategy_slope_bars);
      if(mid_now <= 0.0 || mid_prev <= 0.0)
         return false;
      if(enter_long && !(mid_now > mid_prev))
         return false;
      if(enter_short && !(mid_now < mid_prev))
         return false;
     }

   // --- Build entry. Framework sizes lots (no lots field). Dynamic stop = opposite
   //     inner (1SD) band; capped at sl_cap_pips, else fallback to fixed pips.    ---
   if(enter_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // Dynamic SL = lower inner band at the signal bar.
      double sl = bb1_lo_1;
      const double sl_dist  = entry - sl;
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
      if(sl <= 0.0 || sl_dist <= 0.0)
         sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_fixed_pips); // band invalid -> fixed
      else if(cap_dist > 0.0 && sl_dist > cap_dist)
         return false; // dynamic band stop too wide -> skip the setup (card rule)

      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = 0.0;   // no fixed TP — zone-exit rule rides the trend
      req.reason = "double_bb_buy_zone";
      req.symbol_slot = qm_magic_slot_offset;
      return true;
     }

   // enter_short
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;

   double sl_s = bb1_up_1; // upper inner band at the signal bar
   const double sl_dist_s  = sl_s - entry_s;
   const double cap_dist_s = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(sl_s <= 0.0 || sl_dist_s <= 0.0)
      sl_s = QM_StopFixedPips(_Symbol, QM_SELL, entry_s, (int)strategy_sl_fixed_pips);
   else if(cap_dist_s > 0.0 && sl_dist_s > cap_dist_s)
      return false;

   if(sl_s <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl_s);
   req.tp     = 0.0;
   req.reason = "double_bb_sell_zone";
   req.symbol_slot = qm_magic_slot_offset;
   return true;
  }

// No active trade management beyond the band stop. Exit is the zone-leave rule.
void Strategy_ManageOpenPosition()
  {
  }

// Trend-ending exit: price closes back inside the neutral channel.
//   long  -> Close[1] < BB1_upper[1]   short -> Close[1] > BB1_lower[1]
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
   datetime opened_at = 0;
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
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(strategy_min_exit_bars > 0 && opened_at > 0)
     {
      const int period_seconds = PeriodSeconds(_Period);
      if(period_seconds > 0 && (TimeCurrent() - opened_at) < strategy_min_exit_bars * period_seconds)
         return false;
     }

   if(is_long  && close1 < bb1_up_1)
      return true; // long: dropped back below the inner upper band -> trend ending
   if(is_short && close1 > bb1_lo_1)
      return true; // short: popped back above the inner lower band -> trend ending

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
