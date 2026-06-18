#property strict
#property version   "5.0"
#property description "QM5_11318 tc-m5-10-ema40-80-cci — EMA40/80 trend + CCI(21) zero-cross (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11318 tc-m5-10-ema40-80-cci
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #10 (PDF). Card:
//         artifacts/cards_approved/QM5_11318_tc-m5-10-ema40-80-cci.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M5):
//   Direction STATE : EMA(fast) vs EMA(slow). Long allowed when fast > slow,
//                     short allowed when fast < slow. This is a STATE, not an
//                     event — the EMA stack is the directional filter.
//   Trigger  EVENT  : CCI(period) zero-line cross. LONG = cci[2] <= 0 and
//                     cci[1] > 0; SHORT = cci[2] >= 0 and cci[1] < 0. ONE event
//                     per bar; the EMA stack is the confirming state (avoids the
//                     two-cross-same-bar zero-trade trap).
//   Stop / Take     : symmetric fixed pips (baseline 12/12 → RR ~1.0), scale-
//                     correct via QM_StopFixedPips / QM_TakeRR.
//   Spread guard    : skip only a genuinely wide spread (fail-open on .DWX zero
//                     modeled spread).
//
// One open position per symbol/magic. Only the 5 Strategy_* hooks + Strategy
// inputs are EA-specific; the rest is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11318;
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
input int    strategy_ema_fast_period    = 40;    // trend-direction fast EMA
input int    strategy_ema_slow_period    = 80;    // trend-direction slow EMA
input int    strategy_cci_period         = 21;    // CCI zero-cross trigger period
input double strategy_cci_zero_level     = 0.0;   // CCI cross level (zero line)
input int    strategy_sl_pips            = 12;    // stop-loss distance (pips)
input double strategy_tp_rr              = 1.0;   // take-profit as R-multiple (12/12 = 1.0)
input double strategy_spread_pct_of_stop = 20.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — direction/trigger work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap (fixed-pips → price distance).
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Direction STATE: EMA(fast) vs EMA(slow) on the last closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;
   const bool trend_up   = (ema_fast > ema_slow);
   const bool trend_down = (ema_fast < ema_slow);
   if(!trend_up && !trend_down)
      return false; // exactly equal — no direction

   // --- Trigger EVENT: CCI zero-line cross on the just-closed bar ---
   // cci[1] = just-closed bar, cci[2] = the bar before it. One event/bar.
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool cross_up   = (cci_prev <= strategy_cci_zero_level &&
                            cci_now  >  strategy_cci_zero_level);
   const bool cross_down = (cci_prev >= strategy_cci_zero_level &&
                            cci_now  <  strategy_cci_zero_level);

   // LONG: bullish EMA stack + CCI crosses up through zero.
   // SHORT: bearish EMA stack + CCI crosses down through zero.
   QM_OrderType side;
   if(trend_up && cross_up)
      side = QM_BUY;
   else if(trend_down && cross_down)
      side = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema40_80_cci_long" : "ema40_80_cci_short";
   return true;
  }

// Fixed SL/TP only — no active trade management in the source.
void Strategy_ManageOpenPosition()
  {
  }

// No separate indicator exit in the source; SL/TP handle the close.
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
