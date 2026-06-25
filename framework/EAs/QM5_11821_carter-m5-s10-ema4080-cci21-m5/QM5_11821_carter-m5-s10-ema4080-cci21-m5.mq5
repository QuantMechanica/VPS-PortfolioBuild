#property strict
#property version   "5.0"
#property description "QM5_11821 carter-m5-s10-ema4080-cci21-m5 - 40/80 EMA trend + CCI(21) zero-cross (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11821 carter-m5-s10-ema4080-cci21-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         Strategy 10 (2014). Card:
//         artifacts/cards_approved/QM5_11821_carter-m5-s10-ema4080-cci21-m5.md
//         (g0_status APPROVED, source_id f4430cee-7efb-592e-bf0f-e469ef156b2d).
//         Sibling of QM5_11551 (same Carter S10 mechanic).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : EMA(40) vs EMA(80) — fast>slow = up bias, fast<slow = down.
//   Trigger EVENT: CCI(21) crosses its zero line in the trend direction.
//                  LONG  : cci@1 >= 0  AND  cci@2 < 0  (single fresh up-cross).
//                  SHORT : cci@1 <= 0  AND  cci@2 > 0  (single fresh down-cross).
//   The EMA relationship is a STATE filter; the CCI zero-cross is the ONE event.
//   This avoids the two-cross-same-bar zero-trade trap (build prompt rule #4):
//   only the CCI zero-cross is a fresh EVENT, the EMA stack is a persistent STATE.
//   Stop / Take : fixed symmetric pips (SL = TP = 12 pips default, 1:1 RR;
//                 card range 10-15, factory uses 12; P3 may sweep 10/12/15).
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11821;
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
input int    strategy_ema_fast_period   = 40;     // trend-state fast EMA
input int    strategy_ema_slow_period   = 80;     // trend-state slow EMA
input int    strategy_cci_period        = 21;     // CCI lookback (zero-cross trigger)
input int    strategy_sl_pips           = 12;     // fixed stop-loss in pips (card 10-15; P3 sweep)
input int    strategy_tp_pips           = 12;     // fixed take-profit in pips (1:1 RR; P3 sweep)
input double strategy_spread_cap_pips   = 5.0;    // skip if spread exceeds this many pips

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/trigger work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread cap expressed in pips → price distance (scale-correct on 5-digit/JPY).
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol,
                                  (int)MathRound(strategy_spread_cap_pips));
   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(cap_distance > 0.0 && spread > 0.0 && spread > cap_distance)
      return true;

   return false;
  }

// Entry: EMA(40)/EMA(80) trend state + CCI(21) zero-line cross in the trend
// direction. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: EMA(fast) vs EMA(slow) on the closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Trigger EVENT: CCI zero-line cross (one fresh event/bar) ---
   // cci@1 = last closed bar, cci@2 = prior closed bar. The CCI oscillates
   // around 0, so guard with >= / < to capture a fresh sign change.
   const double cci_cur  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool trend_up   = (ema_fast > ema_slow);
   const bool trend_down = (ema_fast < ema_slow);

   // Fresh upward zero-cross confirming an up-trend (card: cci1>=0 AND cci2<0).
   const bool long_trigger  = (trend_up   && cci_cur >= 0.0 && cci_prev < 0.0);
   // Fresh downward zero-cross confirming a down-trend (card: cci1<=0 AND cci2>0).
   const bool short_trigger = (trend_down && cci_cur <= 0.0 && cci_prev > 0.0);

   if(!long_trigger && !short_trigger)
      return false;

   const QM_OrderType side = long_trigger ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Fixed symmetric pip stop / target (1:1 RR per card) ---
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_trigger ? "ema4080_cci21_zero_long" : "ema4080_cci21_zero_short";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Fixed SL/TP only — no active management.
void Strategy_ManageOpenPosition()
  {
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
