#property strict
#property version   "5.0"
#property description "QM5_11141 bt-ema-stop — EMA(10/20) cross long + protective stop (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11141 bt-ema-stop
// -----------------------------------------------------------------------------
// Source: Daniel Rodriguez / backtrader, samples/stop-trading/stop-loss-approaches.py
// Card: artifacts/cards_approved/QM5_11141_bt-ema-stop.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1):
//   Entry  EVENT : fast EMA crosses ABOVE slow EMA (fast@2<=slow@2 AND
//                  fast@1>slow@1). One fresh cross event per bar.
//   Stop         : protective stop below entry. The backtrader baseline is a
//                  fixed 2%-below-entry stop. Card P2 CFD-port note: normalise
//                  to max(2% price distance, sl_atr_mult * ATR) so percent stops
//                  stay sane where point values make a flat 2% unsuitable.
//   Take profit  : entry + tp_rr * (stop distance)  (RR-multiple target; the
//                  source has no fixed target, so a bounded RR exit replaces the
//                  open-ended trail for the deterministic V5 backtest baseline).
//   Defensive exit (optional, card "robustness branch"): close the long when the
//                  fast EMA crosses BACK below the slow EMA before the stop/target
//                  is hit. Enabled by default; can be disabled in the setfile.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread passes),
// no swap gate, single QM_IsNewBar consume on the entry path, exactly one cross
// EVENT as the trigger (EMA stack is the only condition), prior CLOSE / EMA reads
// only (no gap rule), D1-native (no MN1). Long-only, one position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11141;
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
input int    strategy_ema_fast_period    = 10;     // fast EMA (backtrader fast_ma)
input int    strategy_ema_slow_period    = 20;     // slow EMA (backtrader slow_ma)
input double strategy_stop_pct           = 2.0;    // baseline protective stop, % below entry
input int    strategy_atr_period         = 14;     // ATR period for the CFD-port stop floor
input double strategy_sl_atr_mult        = 2.0;    // ATR-normalised stop floor: mult * ATR
input double strategy_tp_rr              = 2.0;    // take profit = tp_rr * stop distance
input bool   strategy_exit_on_cross_down = true;   // close long on fast<slow EMA cross-down
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Protective stop distance in PRICE units: max(stop_pct% of entry, sl_atr_mult*ATR).
// Returns 0.0 if neither input is usable.
double Strategy_StopDistance(const double entry, const double atr_value)
  {
   double pct_distance = 0.0;
   if(strategy_stop_pct > 0.0 && entry > 0.0)
      pct_distance = entry * (strategy_stop_pct / 100.0);

   double atr_distance = 0.0;
   if(strategy_sl_atr_mult > 0.0 && atr_value > 0.0)
      atr_distance = strategy_sl_atr_mult * atr_value;

   return (pct_distance > atr_distance) ? pct_distance : atr_distance;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stop_distance = Strategy_StopDistance(ask, atr_value);
   if(stop_distance <= 0.0)
      return false; // no usable stop reference yet — defer to entry gate

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Entry EVENT: fast EMA crosses ABOVE slow EMA (one fresh cross/bar) ---
   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_up = (fast_prev <= slow_prev && fast_now > slow_now);
   if(!crossed_up)
      return false;

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stop_distance = Strategy_StopDistance(entry, atr_value);
   if(stop_distance <= 0.0)
      return false;

   // Stop as a PRICE: reuse the ATR-from-value helper with the resolved distance
   // (atr_value := stop_distance, mult := 1.0 → stop = entry - stop_distance).
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, stop_distance, 1.0);
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ema_cross_stop_long";
   return true;
  }

// No active trade management beyond the fixed protective stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Optional defensive exit: fast EMA crosses BACK below slow EMA. One event/bar.
bool Strategy_ExitSignal()
  {
   if(!strategy_exit_on_cross_down)
      return false;
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;

   const bool crossed_down = (fast_prev >= slow_prev && fast_now < slow_now);
   return crossed_down;
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
