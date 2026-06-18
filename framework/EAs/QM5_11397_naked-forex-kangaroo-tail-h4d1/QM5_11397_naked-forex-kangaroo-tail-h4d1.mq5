#property strict
#property version   "5.0"
#property description "QM5_11397 naked-forex-kangaroo-tail-h4d1 — Kangaroo Tail pin-bar reversal (H4/D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11397 naked-forex-kangaroo-tail-h4d1
// -----------------------------------------------------------------------------
// Source: Alex Nekritin & Walter Peters, "Naked Forex" (Wiley 2012), Ch.8
//         Kangaroo Tails. Card: artifacts/cards_approved/
//         QM5_11397_naked-forex-kangaroo-tail-h4d1.md (g0_status APPROVED).
//
// A Kangaroo Tail is a single-bar pin-bar reversal. The EVENT is the COMPLETION
// of that pin bar on the just-CLOSED bar (closed-bar reads at shift 1; the
// card's "[0]" pattern candle == shift 1, its "[1]" prior candle == shift 2).
// All geometry is a bounded deterministic OHLC computation:
//
//   range = high1 - low1.
//   LONG  (bullish, long LOWER tail):
//     1. lower-tail ratio  (min(open1,close1) - low1)/range  >= tail_min_ratio
//     2. body in TOP third: min(open1,close1) >= high1 - range/3
//     3. body within prior candle range [low2, high2]
//     4. context: low1 < lowest(low, ctx_lookback) over shifts 2..ctx+1
//                 (pin pierces an N-bar low extreme — replaces visual S/R)
//   SHORT (bearish, long UPPER tail): mirror of the above.
//
//   Stop  : tail extreme +/- sl_buffer_pips (LONG: low1 - buf; SHORT: high1 + buf),
//           capped to sl_cap_pips of stop distance.
//   Take  : entry +/- tp_atr_mult * ATR(atr_period) (same closed-bar ATR).
//   Manage: move to break-even once price has advanced be_trigger_atr * ATR.
//   Spread: skip only a genuinely WIDE spread (fail-open on .DWX zero spread).
//
// .DWX note: index/FX CFDs are gapless (open[0]==close[1]); the card's
// "BUYSTOP at high+5pips on next bar" reduces to a market entry on the bar
// AFTER the completed pin (the bar has already closed in the reversal
// direction). We enter market on the new closed bar — most literal
// deterministic realization, avoids the .DWX gap-entry zero-trade pitfall.
// See open_questions / SPEC.md.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11397;
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
input double strategy_tail_min_ratio     = 0.60;  // tail length >= 60% of range
input int    strategy_ctx_lookback       = 20;    // N-bar extreme context window
input int    strategy_sl_buffer_pips     = 5;     // SL beyond tail extreme (pips)
input int    strategy_sl_cap_pips        = 60;    // P2 cap on SL distance (pips)
input int    strategy_atr_period         = 14;    // ATR period for take-profit
input double strategy_tp_atr_mult        = 2.0;   // TP distance = mult * ATR
input double strategy_be_trigger_atr     = 1.0;   // move to BE at +mult * ATR
input double strategy_spread_cap_pips    = 20.0;  // skip if spread wider than this (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// a genuinely wide spread blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero/negative modeled spread (.DWX) — fail open

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap > 0.0 && spread > cap)
      return true;  // genuinely wide spread — block

   return false;
  }

// Kangaroo-tail completion on the just-closed bar (shift 1). Caller guarantees
// QM_IsNewBar() == true. Long and short are mirror images.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Pattern bar = shift 1 ("[0]" in the card); prior bar = shift 2 ("[1]").
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: closed-bar OHLC geometry
   const double low1  = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double open1 = iOpen(_Symbol, _Period, 1);  // perf-allowed
   const double close1= iClose(_Symbol, _Period, 1); // perf-allowed
   const double high2 = iHigh(_Symbol, _Period, 2);  // perf-allowed
   const double low2  = iLow(_Symbol, _Period, 2);   // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || open1 <= 0.0 || close1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   const double range = high1 - low1;
   if(range <= 0.0)
      return false;

   const double body_lo = MathMin(open1, close1);
   const double body_hi = MathMax(open1, close1);

   // Body fully contained within the prior candle's range (both directions).
   const bool body_in_prior = (body_lo >= low2 && body_hi <= high2);
   if(!body_in_prior)
      return false;

   const double third = range / 3.0;

   // ATR for the take-profit (closed-bar value).
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double sl_buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double sl_cap    = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);

   // --- LONG: bullish kangaroo tail (long LOWER tail) ---
   const double lower_tail_ratio = (body_lo - low1) / range;
   const bool long_tail   = (lower_tail_ratio >= strategy_tail_min_ratio);
   const bool long_third  = (body_lo >= high1 - third); // both O & C in top third
   if(long_tail && long_third)
     {
      // Context: pattern low pierces the lowest low over the lookback window
      // that PRECEDES the pattern bar (shifts 2 .. ctx_lookback+1).
      double lowest = 0.0;
      bool have = false;
      const int first_shift = 2;
      const int last_shift  = strategy_ctx_lookback + 1;
      for(int s = first_shift; s <= last_shift; ++s)
        {
         const double l = iLow(_Symbol, _Period, s); // perf-allowed: bounded ctx loop
         if(l <= 0.0)
            continue;
         if(!have || l < lowest)
           {
            lowest = l;
            have = true;
           }
        }
      if(have && low1 < lowest)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;

         double sl = low1 - sl_buffer;                 // 5 pips beyond tail low
         // Cap the stop distance to sl_cap_pips.
         if(sl_cap > 0.0 && (entry - sl) > sl_cap)
            sl = entry - sl_cap;
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
         if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
            return false;

         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "kangaroo_tail_long";
         return true;
        }
     }

   // --- SHORT: bearish kangaroo tail (long UPPER tail) ---
   const double upper_tail_ratio = (high1 - body_hi) / range;
   const bool short_tail  = (upper_tail_ratio >= strategy_tail_min_ratio);
   const bool short_third = (body_hi <= low1 + third); // both O & C in bottom third
   if(short_tail && short_third)
     {
      double highest = 0.0;
      bool have = false;
      const int first_shift = 2;
      const int last_shift  = strategy_ctx_lookback + 1;
      for(int s = first_shift; s <= last_shift; ++s)
        {
         const double h = iHigh(_Symbol, _Period, s); // perf-allowed: bounded ctx loop
         if(h <= 0.0)
            continue;
         if(!have || h > highest)
           {
            highest = h;
            have = true;
           }
        }
      if(have && high1 > highest)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;

         double sl = high1 + sl_buffer;                // 5 pips beyond tail high
         if(sl_cap > 0.0 && (sl - entry) > sl_cap)
            sl = entry + sl_cap;
         sl = QM_StopRulesNormalizePrice(_Symbol, sl);

         const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
         if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
            return false;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "kangaroo_tail_short";
         return true;
        }
     }

   return false;
  }

// Break-even shift once price has moved be_trigger_atr * ATR in our favour.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   const double trigger_dist = strategy_be_trigger_atr * atr_value;
   if(trigger_dist <= 0.0)
      return;

   // Convert the ATR trigger distance to pips for the framework BE helper.
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;
   const int trigger_pips = (int)MathRound(trigger_dist / pip);
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, strategy_sl_buffer_pips);
     }
  }

// No discretionary exit beyond the ATR take-profit and the structural stop.
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
