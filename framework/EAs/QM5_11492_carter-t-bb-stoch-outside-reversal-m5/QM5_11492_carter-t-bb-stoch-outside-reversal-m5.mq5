#property strict
#property version   "5.0"
#property description "QM5_11492 carter-t-bb-stoch-outside-reversal-m5 — BB+Stochastic outside-band reversal (M5, fade)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11492 carter-t-bb-stoch-outside-reversal-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #3 (self-published 2014).
// Card: artifacts/cards_approved/QM5_11492_carter-t-bb-stoch-outside-reversal-m5.md
//       (g0_status APPROVED).
//
// Concept: price closes OUTSIDE the 2SD Bollinger Band = over-extension STATE.
// A Stochastic cross back OUT of the overbought / oversold zone = exhaustion
// TRIGGER. A reversal candle (bar closing against the breach) = direction STATE.
// We FADE the extension back toward the mean.
//
// Two-cross trap avoidance (.DWX invariant #4): exactly ONE fresh cross EVENT is
// required — the Stochastic %K crossing out of the OB/OS band. The BB-outside
// close and the reversal candle are STATES read on the same closed bar, never a
// second simultaneous cross.
//
//   Closed-bar reads at shift 1 (signal bar), shift 2 (prior bar).
//
//   SHORT (fade an UPPER-band extension):
//     STATE   : close[1] > BB upper(period, dev)         (closed outside above)
//     STATE   : reversal candle bearish  -> close[1] < open[1]
//     TRIGGER : Stoch %K crosses DOWN out of OB:  K[2] > OB  AND  K[1] <= OB
//     -> SELL at next bar open (market).
//
//   LONG (fade a LOWER-band extension):
//     STATE   : close[1] < BB lower(period, dev)         (closed outside below)
//     STATE   : reversal candle bullish  -> close[1] > open[1]
//     TRIGGER : Stoch %K crosses UP out of OS:    K[2] < OS  AND  K[1] >= OS
//     -> BUY at next bar open (market).
//
//   Stop / Take : fixed pips, QM-inverted R/R from source (SL 10 / TP 20 pips),
//                 scale-correct via QM_StopFixedPips / QM_TakeRR.
//   Filters     : spread cap (fail-open on .DWX zero spread), no Friday entry.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11492;
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
input int    strategy_bb_period          = 20;     // Bollinger Band period
input double strategy_bb_deviation       = 2.0;    // Bollinger Band deviation (SD)
input int    strategy_stoch_k_period     = 5;      // Stochastic %K period
input int    strategy_stoch_d_period     = 3;      // Stochastic %D period
input int    strategy_stoch_slowing      = 3;      // Stochastic slowing
input double strategy_stoch_overbought   = 80.0;   // %K overbought threshold
input double strategy_stoch_oversold     = 20.0;   // %K oversold threshold
input double strategy_sl_pips            = 10.0;   // fixed stop, in pips
input double strategy_tp_pips            = 20.0;   // fixed target, in pips (2R, QM-inverted)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance
input bool   strategy_no_friday_entry    = true;   // suppress new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread)
// plus an optional no-Friday-entry filter. Regime/signal work is in
// Strategy_EntrySignal on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   // No new entries on Friday (card filter). Position management / exits still run.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread cap referenced to the fixed pip stop distance, scale-correct.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar candle (signal bar = shift 1) ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || open1 <= 0.0)
      return false;

   // --- Bollinger bands on the signal bar (deviation arg MANDATORY) ---
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0)
      return false;

   // --- Stochastic %K: prior bar (shift 2) and signal bar (shift 1) ---
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                    strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(k_prev <= 0.0 || k_now <= 0.0)
      return false;

   // ---------------- SHORT: fade an upper-band extension ----------------
   const bool short_outside  = (close1 > bb_upper);                 // STATE
   const bool short_reversal = (close1 < open1);                    // STATE (bearish bar)
   const bool short_trigger  = (k_prev > strategy_stoch_overbought &&
                                k_now  <= strategy_stoch_overbought); // EVENT (cross down out of OB)

   if(short_outside && short_reversal && short_trigger)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_stoch_outside_reversal_short";
      return true;
     }

   // ---------------- LONG: fade a lower-band extension ----------------
   const bool long_outside  = (close1 < bb_lower);                  // STATE
   const bool long_reversal = (close1 > open1);                     // STATE (bullish bar)
   const bool long_trigger  = (k_prev < strategy_stoch_oversold &&
                               k_now  >= strategy_stoch_oversold);   // EVENT (cross up out of OS)

   if(long_outside && long_reversal && long_trigger)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_pips / strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "bb_stoch_outside_reversal_long";
      return true;
     }

   return false;
  }

// Fixed pip SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit; positions resolve on the fixed SL/TP.
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
