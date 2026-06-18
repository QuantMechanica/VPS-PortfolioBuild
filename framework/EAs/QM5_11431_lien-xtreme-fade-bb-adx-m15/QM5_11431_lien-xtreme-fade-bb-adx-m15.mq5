#property strict
#property version   "5.0"
#property description "QM5_11431 lien-xtreme-fade-bb-adx-m15 — Lien X-Treme Fade: BB(3sigma)+ADX (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11431 lien-xtreme-fade-bb-adx-m15
// -----------------------------------------------------------------------------
// Source: Kathy Lien & Boris Schlossberg, "Battle-Tested Forex Strategies".
// Card: artifacts/cards_approved/QM5_11431_lien-xtreme-fade-bb-adx-m15.md
//       (g0_status APPROVED, source_id df524d6c-e7a3-5ab9-a4f5-212ac0f1134b).
//
// Concept (mean-reversion fade in a non-trending range, closed-bar reads):
//   Two Bollinger Bands on the same SMA(period): outer at outer_stddev (3sigma)
//   and inner at inner_stddev (2sigma). A statistically extreme close beyond the
//   3sigma band, followed by a close back inside the 2sigma band, signals that
//   reversion has begun. ADX(period) < adx_max confirms a non-trending regime —
//   fading a strong trend is the primary failure mode for this family.
//
//   ADX < adx_max is a STATE (regime filter).
//   The single triggering EVENT is the two-bar sequence on the freshly closed bars:
//     bar[2] closed beyond the outer (3sigma) band AND
//     bar[1] closed back inside the inner (2sigma) band.
//
//   SHORT (fade overbought extreme):
//     Close[2] > BB_upper(outer)[2]  AND  Close[1] < BB_upper(inner)[1]  AND ADX[1] < adx_max
//     -> SELL at market on bar[0] open.
//     SL = BB_upper(outer)[1] + 1 pip (just above the extreme band), capped at sl_cap_pips.
//   LONG (fade oversold extreme):
//     Close[2] < BB_lower(outer)[2]  AND  Close[1] > BB_lower(inner)[1]  AND ADX[1] < adx_max
//     -> BUY at market on bar[0] open.
//     SL = BB_lower(outer)[1] - 1 pip, capped at sl_cap_pips.
//   TP = rr_target x risk (SL distance). No time-based exit; hold to TP or SL.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; block only a genuinely
//                  wide spread > spread_cap_pips.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11431;
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
input int    strategy_bb_period         = 20;     // Bollinger SMA period (shared by both bands)
input double strategy_bb_outer_stddev   = 3.0;    // outer "extreme" band deviation (sigma)
input double strategy_bb_inner_stddev   = 2.0;    // inner "standard" band deviation (sigma)
input int    strategy_adx_period        = 14;     // ADX period for the range filter
input double strategy_adx_max           = 25.0;   // trade only while ADX < this (non-trending)
input double strategy_sl_buffer_pips    = 1.0;    // SL placed this many pips beyond the outer band
input double strategy_sl_cap_pips       = 25.0;   // hard cap on SL distance (card P2 cap)
input double strategy_rr_target         = 2.0;    // take-profit at this multiple of SL distance
input double strategy_spread_cap_pips   = 12.0;   // block only if spread exceeds this (fail-open)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Wrong-timeframe guard + spread guard only. Signal
// work lives on the closed-bar path in Strategy_EntrySignal. Fail-OPEN on the
// .DWX zero modeled spread: only a genuinely wide spread blocks.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_spread_cap_pips));
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true. One position/magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Parameter sanity (avoid degenerate configs).
   if(strategy_bb_period < 2 ||
      strategy_bb_inner_stddev <= 0.0 ||
      strategy_bb_outer_stddev <= strategy_bb_inner_stddev ||
      strategy_adx_period < 2 ||
      strategy_sl_cap_pips <= 0.0 ||
      strategy_rr_target <= 0.0)
      return false;

   // Closed-bar closes: bar[2] = extreme bar, bar[1] = re-entry bar.
   const double close_step1 = iClose(_Symbol, PERIOD_CURRENT, 2); // perf-allowed: fixed closed-bar extreme close (card Step-1).
   const double close_step2 = iClose(_Symbol, PERIOD_CURRENT, 1); // perf-allowed: fixed closed-bar re-entry close (card Step-2).
   if(close_step1 <= 0.0 || close_step2 <= 0.0)
      return false;

   // Bands: outer (3sigma) at bar[2] for the extreme test and at bar[1] for SL;
   // inner (2sigma) at bar[1] for the re-entry test. ADX at bar[1].
   const double outer_upper_step1 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 2);
   const double outer_lower_step1 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 2);
   const double outer_upper_step2 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 1);
   const double outer_lower_step2 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_outer_stddev, 1);
   const double inner_upper_step2 = QM_BB_Upper(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_inner_stddev, 1);
   const double inner_lower_step2 = QM_BB_Lower(_Symbol, PERIOD_CURRENT, strategy_bb_period, strategy_bb_inner_stddev, 1);
   const double adx_step2 = QM_ADX(_Symbol, PERIOD_CURRENT, strategy_adx_period, 1);
   if(outer_upper_step1 <= 0.0 || outer_lower_step1 <= 0.0 ||
      outer_upper_step2 <= 0.0 || outer_lower_step2 <= 0.0 ||
      inner_upper_step2 <= 0.0 || inner_lower_step2 <= 0.0 ||
      adx_step2 <= 0.0)
      return false;

   // Regime STATE: trade only in a non-trending range.
   if(adx_step2 >= strategy_adx_max)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   const double sl_cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_cap_pips));
   if(sl_cap <= 0.0)
      return false;

   // SHORT: fade an overbought extreme that has begun to revert.
   if(close_step1 > outer_upper_step1 && close_step2 < inner_upper_step2)
     {
      const double entry = bid;
      double sl = QM_StopRulesNormalizePrice(_Symbol, outer_upper_step2 + buffer);
      // Cap SL distance at the card's P2 cap.
      if((sl - entry) > sl_cap)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_cap);
      if(sl <= entry)
         return false;
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "LIEN_XTREME_FADE_SHORT";
      return (req.tp > 0.0);
     }

   // LONG: fade an oversold extreme that has begun to revert.
   if(close_step1 < outer_lower_step1 && close_step2 > inner_lower_step2)
     {
      const double entry = ask;
      double sl = QM_StopRulesNormalizePrice(_Symbol, outer_lower_step2 - buffer);
      if((entry - sl) > sl_cap)
         sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_cap);
      if(sl >= entry)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_rr_target);
      req.reason = "LIEN_XTREME_FADE_LONG";
      return (req.tp > 0.0);
     }

   return false;
  }

// Fixed SL/TP only — no active management beyond the bracket the card defines.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit: the card holds to TP or SL.
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
