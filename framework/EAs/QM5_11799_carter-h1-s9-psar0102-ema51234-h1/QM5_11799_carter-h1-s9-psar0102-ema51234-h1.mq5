#property strict
#property version   "5.0"
#property description "QM5_11799 carter-h1-s9-psar0102-ema51234-h1 — Triple-EMA stack + fast PSAR(0.1,0.2) flip (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11799 carter-h1-s9-psar0102-ema51234-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy S9, Scribd ~2014.
// Card: artifacts/cards_approved/QM5_11799_carter-h1-s9-psar0102-ema51234-h1.md
//       (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1/2):
//   Trend STATE  : triple-EMA stack alignment.
//                  LONG  -> EMA(5) > EMA(12) > EMA(34)
//                  SHORT -> EMA(5) < EMA(12) < EMA(34)
//   Trigger EVENT: a FRESH fast PSAR(0.1,0.2) flip in the trend direction.
//                  Per card Implementation Notes:
//                  LONG  -> psar[2] > Close[2] AND psar[1] < Close[1]
//                           (dot was above the bar, now below it)
//                  SHORT -> psar[2] < Close[2] AND psar[1] > Close[1]
//                           (dot was below the bar, now above it)
//   The PSAR flip is the SINGLE entry event; the EMA stack is a persistent
//   STATE, so the two-cross-same-bar zero-trade trap is avoided — only the PSAR
//   flip must be fresh on the trigger bar; the EMA stack only has to currently
//   hold.
//   Stop  : factory SL = max(2*ATR(14), |entry - psar_value|).
//   Take  : factory TP = 4*ATR(14).
//   Spread guard: blocks only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11799;
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
input int    strategy_ema_fast_period   = 5;      // fast EMA (stack top)
input int    strategy_ema_mid_period    = 12;     // mid EMA
input int    strategy_ema_slow_period   = 34;     // slow EMA (stack bottom)
input double strategy_sar_step          = 0.1;    // PSAR acceleration step (fast)
input double strategy_sar_max           = 0.2;    // PSAR acceleration maximum
input int    strategy_atr_period        = 14;     // ATR period for factory SL/TP
input double strategy_sl_atr_mult       = 2.0;    // SL = max(this*ATR, |entry-psar|)
input double strategy_tp_atr_mult       = 4.0;    // TP = this*ATR
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance
input bool   strategy_block_friday      = true;   // no new entries on Friday (card filter)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance for the spread cap: 1*ATR(14) proxy via SL mult.
   double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — do not block
   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// STATE = triple-EMA stack; EVENT = fresh fast-PSAR flip in trend direction.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Optional card filter: no new entries on Friday (broker time).
   if(strategy_block_friday)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Triple-EMA stack STATE (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool stack_long  = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool stack_short = (ema_fast < ema_mid && ema_mid < ema_slow);
   if(!stack_long && !stack_short)
      return false;

   // --- Fast PSAR flip EVENT (one fresh event/bar, card Close-based test) ---
   // sar1 = last closed bar, sar2 = bar before it. A flip is the SAR crossing
   // the bar Close between bar 2 and bar 1: it was on one side at shift 2 and
   // is on the opposite side at shift 1.
   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   // Closed-bar Close references for the flip test (single shift reads).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // LONG flip: SAR above Close at shift 2, below Close at shift 1.
   const bool flip_long  = (sar2 > close2 && sar1 < close1);
   // SHORT flip: SAR below Close at shift 2, above Close at shift 1.
   const bool flip_short = (sar2 < close2 && sar1 > close1);

   bool go_long  = false;
   bool go_short = false;
   if(stack_long && flip_long)
      go_long = true;
   else if(stack_short && flip_short)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   // --- Factory SL/TP from ATR(14), with PSAR-value SL floor. ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL distance = max(2*ATR, |entry - psar_value|). sar1 is the current
      // (flipped) PSAR dot sitting below price for a long.
      const double atr_dist  = strategy_sl_atr_mult * atr_value;
      const double psar_dist = MathAbs(entry - sar1);
      const double sl_dist   = MathMax(atr_dist, psar_dist);
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, sl_dist, 1.0);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "carter_s9_psar_ema_long";
      return true;
     }

   // go_short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double atr_dist  = strategy_sl_atr_mult * atr_value;
   const double psar_dist = MathAbs(entry - sar1);
   const double sl_dist   = MathMax(atr_dist, psar_dist);
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, sl_dist, 1.0);
   const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "carter_s9_psar_ema_short";
   return true;
  }

// Fixed ATR SL/TP brackets; plus card exit on PSAR flip against the position.
void Strategy_ManageOpenPosition()
  {
  }

// Card exit: close on a PSAR flip against the open position. SL/TP brackets are
// handled by the framework once attached at entry. Evaluated on the closed-bar
// path (OnTick gates Strategy_ExitSignal before the new-bar entry gate, but the
// PSAR reads here are single closed-bar shift reads — O(1)).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine direction of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && sar1 > close1)
         return true;  // PSAR flipped above price against a long
      if(pos_type == POSITION_TYPE_SELL && sar1 < close1)
         return true;  // PSAR flipped below price against a short
     }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
