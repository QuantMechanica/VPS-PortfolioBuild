#property strict
#property version   "5.0"
#property description "QM5_11475 lien-k-xtreme-fade-bb3sd-adx-m15 — Kathy Lien X-Treme Fade (BB 3SD/2SD + low ADX, M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11475 lien-k-xtreme-fade-bb3sd-adx-m15
// -----------------------------------------------------------------------------
// Source: Kathy Lien, "Battle Tested Forex Trading Strategies" (BKForex, ~2013),
//   X-Treme Fade. Card: artifacts/cards_approved/
//   QM5_11475_lien-k-xtreme-fade-bb3sd-adx-m15.md (g0_status APPROVED).
//
// Mechanics (mean-reversion fade, closed-bar reads, M15):
//   Concept : a 3-standard-deviation Bollinger Band excursion is a statistical
//             extreme. The crossback from the 3SD (outer/extreme) zone into the
//             2SD (inner/normal) zone confirms reversion -> fade it. Gated by a
//             LOW-ADX regime STATE (range, not trend) so we never fight a market
//             that is "walking the band".
//
//   Trigger EVENT (one per bar, two different bars -> no same-bar-two-cross trap):
//     LONG (fade a high extreme, BUY the reversion down):
//       bar[2] closed at/above 3SD upper  : Close[2] >= BB3SD_upper[2]   (extreme)
//       bar[1] closed back inside 2SD upper: Close[1] <  BB2SD_upper[1]   (reverted)
//     SHORT (fade a low extreme, SELL the reversion up):
//       bar[2] closed at/below 3SD lower  : Close[2] <= BB3SD_lower[2]    (extreme)
//       bar[1] closed back inside 2SD lower: Close[1] >  BB2SD_lower[1]   (reverted)
//
//   Regime STATE filter : ADX(adx_period)[1] < adx_max  (ranging market).
//
//   Stop   : swing structure (swing_lookback bars) OR fixed sl_fixed_pips,
//            whichever is the CLOSER (smaller) distance, capped at sl_cap_pips.
//   Target : RR-multiple of the realized stop distance (tp_rr).
//
//   Spread guard : block ONLY a genuinely wide spread (fail-open on the .DWX
//                  zero modeled spread, per the .DWX backtest invariants).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11475;
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
input double strategy_sl_fixed_pips      = 20.0;  // fixed-pip stop alternative
input double strategy_sl_cap_pips        = 25.0;  // hard cap on the stop distance (pips)
input double strategy_tp_rr              = 1.0;   // take-profit as RR-multiple of stop
input double strategy_spread_cap_pips    = 15.0;  // skip if spread exceeds this many pips
input double strategy_fast_adx_max       = 25.0;  // M1/M5 strong-against filter threshold

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

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap_distance)
      return true;

   return false;
  }

bool Strategy_FastTrendAgainst(const QM_OrderType dir, const ENUM_TIMEFRAMES tf)
  {
   const double adx = QM_ADX(_Symbol, tf, strategy_adx_period, 1);
   if(adx < strategy_fast_adx_max)
      return false;

   const double plus_di = QM_ADX_PlusDI(_Symbol, tf, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, tf, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   if(dir == QM_BUY)
      return (minus_di > plus_di);
   return (plus_di > minus_di);
  }

// Mean-reversion fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

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

   // --- Trigger EVENT: extreme on bar[2], crossback-into-normal on bar[1]. ---
   // Two different bars -> one trigger event; no two-cross-same-bar zero-trade trap.
   const bool long_fade  = (close2 >= bb3_upper_2) && (close1 < bb2_upper_1);
   const bool short_fade = (close2 <= bb3_lower_2) && (close1 > bb2_lower_1);
   if(!long_fade && !short_fade)
      return false;

   const QM_OrderType dir = long_fade ? QM_BUY : QM_SELL;

   if(Strategy_FastTrendAgainst(dir, PERIOD_M1) || Strategy_FastTrendAgainst(dir, PERIOD_M5))
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: structural swing OR fixed pips, whichever is CLOSER, capped. ---
   const double sl_struct = QM_StopStructure(_Symbol, dir, entry, strategy_swing_lookback);
   const double sl_fixed  = QM_StopFixedPips(_Symbol, dir, entry, (int)strategy_sl_fixed_pips);
   if(sl_struct <= 0.0 || sl_fixed <= 0.0)
      return false;

   // "Whichever is closer" = the stop with the smaller distance to entry.
   const double dist_struct = MathAbs(entry - sl_struct);
   const double dist_fixed  = MathAbs(entry - sl_fixed);
   double sl = (dist_struct <= dist_fixed) ? sl_struct : sl_fixed;

   // Hard cap on the stop distance.
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(cap_dist > 0.0 && MathAbs(entry - sl) > cap_dist)
      sl = (dir == QM_BUY) ? (entry - cap_dist) : (entry + cap_dist);

   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Target: RR-multiple of the realized stop distance. ---
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_fade ? "xtreme_fade_long" : "xtreme_fade_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Once 1R is reached, trail the stop toward the opposite 2SD band if it improves.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
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
      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const double risk_distance = MathAbs(open_price - current_sl);
      if(risk_distance <= 0.0)
         continue;

      const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market_price <= 0.0)
         continue;

      const double moved = is_buy ? (market_price - open_price) : (open_price - market_price);
      if(moved < risk_distance)
         continue;

      const double band_sl = is_buy
                             ? QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1)
                             : QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev_inner, 1);
      if(band_sl <= 0.0)
         continue;

      const double normalized = QM_TM_NormalizePrice(_Symbol, band_sl);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(normalized <= 0.0 || point <= 0.0)
         continue;

      const bool improves = is_buy ? (normalized > current_sl + point * 0.5 && normalized < market_price)
                                   : (normalized < current_sl - point * 0.5 && normalized > market_price);
      if(improves)
         QM_TM_MoveSL(ticket, normalized, "trail_to_2sd_opposite_band_after_1r");
     }
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
