#property strict
#property version   "5.0"
#property description "QM5_11815 carter-m5-s2-ema102150-zone-pullback-m5 — Triple-EMA zone pullback (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11815 carter-m5-s2-ema102150-zone-pullback-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         2014, Strategy 2 (EMA 10/21/50 zone pullback).
// Card: artifacts/cards_approved/QM5_11815_carter-m5-s2-ema102150-zone-pullback-m5.md
//       (g0_status: APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; symmetric long/short):
//   Trend STATE  : EMA(10) > EMA(21) > EMA(50)   (bullish stack)  -> long bias
//                  EMA(10) < EMA(21) < EMA(50)   (bearish stack)  -> short bias
//   Pullback STATE: within the last pb_lookback closed bars PRECEDING the
//                  trigger bar, price reached into the EMA10/EMA21 zone — for a
//                  long, a bar Low touched/penetrated EMA21 (the far edge of the
//                  zone). For a short, a bar High touched/penetrated EMA21.
//   Resume EVENT : the prior closed bar (shift 1) is the FIRST bar to close back
//                  out of the zone in the trend direction — long: close[1] > EMA10[1]
//                  AND close[2] <= EMA10[2] (the cross-back-above-EMA10 candle).
//                  This single per-bar EVENT is the trigger; the stack and the
//                  pullback touch are STATES. Only one fresh event is required,
//                  so the two-cross-same-bar zero-trade trap is avoided.
//   Stop / Take  : fixed pips from the card (SL 5, TP 10 -> ~1:2 RR), scaled to
//                  the symbol via QM_StopFixedPips / QM_StopRulesPipsToPriceDistance.
//   Defensive exit: opposite EMA10/EMA21 zone break (close crosses the EMA10 in
//                  the adverse direction) -> close manually (card "Exit").
//   Spread guard : skip only a genuinely wide spread (> cap % of the stop
//                  distance). Fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11815;
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
input int    strategy_ema_fast_period    = 10;    // inner edge of the zone / fast EMA
input int    strategy_ema_mid_period     = 21;    // far edge of the zone / mid EMA
input int    strategy_ema_slow_period    = 50;    // trend EMA
input int    strategy_pullback_bars      = 6;     // bars to look back for the zone touch
input double strategy_sl_pips            = 5.0;   // fixed stop, card-specified
input double strategy_tp_pips            = 10.0;  // fixed target, card-specified (1:2)
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — all regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Symmetric long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: triple-EMA stack on the last closed bar (shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool bull_stack = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool bear_stack = (ema_fast < ema_mid && ema_mid < ema_slow);
   if(!bull_stack && !bear_stack)
      return false;

   // --- Resume EVENT: the prior bar is the FIRST to close back out of the
   //     zone in the trend direction (single cross-back-of-EMA10 event). ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   if(ema_fast_2 <= 0.0)
      return false;

   bool is_long  = false;
   bool is_short = false;

   if(bull_stack)
     {
      // Long resume: close[1] back above EMA10, having been at/below it on bar 2.
      const bool resume_up = (close1 > ema_fast && close2 <= ema_fast_2);
      if(resume_up)
         is_long = true;
     }
   else // bear_stack
     {
      // Short resume: close[1] back below EMA10, having been at/above it on bar 2.
      const bool resume_dn = (close1 < ema_fast && close2 >= ema_fast_2);
      if(resume_dn)
         is_short = true;
     }

   if(!is_long && !is_short)
      return false;

   // --- Pullback STATE: within the lookback window PRECEDING the trigger bar
   //     (shifts 2 .. pb_lookback+1), price reached into the zone — touched the
   //     far edge (EMA21). The touch is a prior state; the resume bar is the
   //     event, so the two are never the same bar. ---
   bool touched_zone = false;
   const int first_shift = 2;
   const int last_shift  = strategy_pullback_bars + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double ema_mid_s = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, s);
      if(ema_mid_s <= 0.0)
         continue;
      if(is_long)
        {
         const double low_s = iLow(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(low_s > 0.0 && low_s <= ema_mid_s) // pullback Low dipped into/below EMA21
           {
            touched_zone = true;
            break;
           }
        }
      else // is_short
        {
         const double high_s = iHigh(_Symbol, _Period, s); // perf-allowed: single closed-bar read
         if(high_s > 0.0 && high_s >= ema_mid_s) // pullback High poked into/above EMA21
           {
            touched_zone = true;
            break;
           }
        }
     }
   if(!touched_zone)
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const QM_OrderType otype = is_long ? QM_BUY : QM_SELL;
   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, otype, entry, strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, otype, entry, sl, strategy_tp_pips / strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = is_long ? "ema_zone_pb_long" : "ema_zone_pb_short";
   return true;
  }

// No active management beyond the fixed pip stop/target. Defensive zone-break
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite EMA10/EMA21 zone break. A long is closed when price
// closes back below the EMA10 (one event at shift 1); a short when it closes
// back above the EMA10. SL/TP otherwise handle the exit.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast   = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   if(ema_fast <= 0.0 || ema_fast_2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Determine the side of the open position for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Long: fresh close back BELOW EMA10. Short: fresh close back ABOVE EMA10.
   if(have_long && close1 < ema_fast && close2 >= ema_fast_2)
      return true;
   if(have_short && close1 > ema_fast && close2 <= ema_fast_2)
      return true;

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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
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
