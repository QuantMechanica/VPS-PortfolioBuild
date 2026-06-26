#property strict
#property version   "5.0"
#property description "QM5_11512 carter-t-ema2-4-stoch-d1 - fast EMA(2/4) cross + Stoch(5,3,3) confirm (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11512 carter-t-ema2-4-stoch-d1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #7, self-published 2014.
// Card: artifacts/cards_approved/QM5_11512_carter-t-ema2-4-stoch-d1.md (APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; both long and short):
//   Trigger EVENT  : fast EMA(2) crosses EMA(4). One event per bar.
//                    LONG  -> EMA2 crosses ABOVE EMA4  (ema2_1>ema4_1 && ema2_2<=ema4_2)
//                    SHORT -> EMA2 crosses BELOW EMA4  (ema2_1<ema4_1 && ema2_2>=ema4_2)
//   Confirm STATE  : Stochastic(5,3,3) %K main line is the confirming STATE, not
//                    a second event (avoids the two-cross-same-bar zero-trade trap):
//                    LONG  -> %K < stoch_threshold (not yet overbought, default 50)
//                    SHORT -> %K > stoch_threshold (not yet oversold, default 50)
//   Stop loss      : entry-bar extreme (last closed D1 bar low for long / high
//                    for short), capped at both 3% of price and 100 pips.
//   Take profit    : tp_rr * (entry - sl) via QM_TakeRR (source: 2-3x SL distance).
//   No-trade filter: card forbids Friday entries; cheap O(1) per-tick spread guard
//                    that fails OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11512;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period   = 2;      // fast EMA (very responsive, ~2-day)
input int    strategy_ema_slow_period   = 4;      // slow EMA (~4-day)
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_threshold   = 50.0;   // confirm zone boundary (long<thr, short>thr)
input int    strategy_sl_cap_pips       = 100;    // cap on entry-bar-extreme stop distance
input double strategy_sl_cap_percent    = 3.0;    // source cap as percent of entry price
input double strategy_tp_rr             = 2.0;    // take profit as R multiple of SL distance
input bool   strategy_no_friday_entry   = true;   // card: no Friday entries
input int    strategy_spread_cap_pips   = 30;     // card: spread cap 30 pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No-Friday-entry + spread guard. Regime/signal work
// is in Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   // Card: no Friday entries. Block the whole Friday (broker time).
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

   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Build the entry order. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Fast EMA values: shift 1 (just-closed bar) and shift 2 (prior bar) ---
   const double ema2_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 1);
   const double ema4_1 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 1);
   const double ema2_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 2);
   const double ema4_2 = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 2);
   if(ema2_1 <= 0.0 || ema4_1 <= 0.0 || ema2_2 <= 0.0 || ema4_2 <= 0.0)
      return false;

   // Trigger EVENT: one fresh cross on the just-closed bar.
   const bool crossed_up   = (ema2_1 > ema4_1 && ema2_2 <= ema4_2);
   const bool crossed_down = (ema2_1 < ema4_1 && ema2_2 >= ema4_2);
   if(!crossed_up && !crossed_down)
      return false;

   // Confirm STATE: Stochastic %K main line relative to the threshold.
   const double stoch_k = QM_Stoch_K(_Symbol, PERIOD_D1,
                                     strategy_stoch_k, strategy_stoch_d,
                                     strategy_stoch_slowing, 1);
   if(stoch_k < 0.0 || stoch_k > 100.0)
      return false;

   QM_OrderType side;
   if(crossed_up)
     {
      // LONG confirmed only when not yet overbought.
      if(!(stoch_k < strategy_stoch_threshold))
         return false;
      side = QM_BUY;
     }
   else
     {
      // SHORT confirmed only when not yet oversold.
      if(!(stoch_k > strategy_stoch_threshold))
         return false;
      side = QM_SELL;
     }

   // --- Entry price (market at send is filled by the framework; price ref for stops) ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Card stop is the just-closed D1 bar extreme. EntrySignal is already gated
   // by QM_IsNewBar(), so these are fixed O(1) structural reads.
   const double d1_low  = iLow(_Symbol, PERIOD_D1, 1);  // perf-allowed: card-required D1 entry-bar low
   const double d1_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: card-required D1 entry-bar high
   if(d1_low <= 0.0 || d1_high <= 0.0)
      return false;

   double sl = (side == QM_BUY) ? d1_low : d1_high;
   if(sl <= 0.0)
      return false;

   if((side == QM_BUY && sl >= entry) || (side == QM_SELL && sl <= entry))
      return false;

   const double cap_pip_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double cap_pct_distance = (strategy_sl_cap_percent > 0.0) ? entry * strategy_sl_cap_percent / 100.0 : 0.0;
   double cap_distance = cap_pip_distance;
   if(cap_pct_distance > 0.0 && (cap_distance <= 0.0 || cap_pct_distance < cap_distance))
      cap_distance = cap_pct_distance;

   if(cap_distance > 0.0)
     {
      const double sl_distance = MathAbs(entry - sl);
      if(sl_distance > cap_distance)
        {
         // Clamp the stop to the cap distance from entry.
         sl = (side == QM_BUY) ? (entry - cap_distance) : (entry + cap_distance);
         sl = QM_TM_NormalizePrice(_Symbol, sl);
        }
     }
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_rr R multiple of the (possibly capped) stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema2_4_cross_stoch_long" : "ema2_4_cross_stoch_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP bracket.
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
