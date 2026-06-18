#property strict
#property version   "5.0"
#property description "QM5_11413 wilder-directional-movement-di14-cross-d1 — Wilder DMI +DI/-DI(14) cross, Extreme Point Rule (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11413 wilder-directional-movement-di14-cross-d1
// -----------------------------------------------------------------------------
// Source: J. Welles Wilder Jr., "New Concepts in Technical Trading Systems"
// (1978), Section IV: Directional Movement System.
// Card: artifacts/cards_approved/QM5_11413_wilder-directional-movement-di14-cross-d1.md
// (g0_status APPROVED). source_id 0ab0a479-4a09-5ecc-bb90-6a37148fa78b.
//
// Mechanics (D1, closed-bar reads at shift 1; the just-closed bar is the
// "crossing day"):
//   Trigger EVENT (one event/bar): the +DI/-DI(14) cross on the just-closed bar.
//     LONG  cross : +DI[2] <= -DI[2]  AND  +DI[1] > -DI[1]
//     SHORT cross : -DI[2] <= +DI[2]  AND  -DI[1] > +DI[1]
//   Confirming STATE: ADXR[1] > adxr_threshold, where
//     ADXR = (ADX[shift=1] + ADX[shift=1+adx_period]) / 2  (Wilder ADXR).
//     STATE not EVENT — this is the "two-cross-same-bar zero-trade trap"
//     avoidance: only the DI cross is the trigger; ADX is the regime gate.
//   Extreme Point Rule (entry confirmation): place a STOP order at the crossing
//     day's extreme; price must trade through it to confirm the new direction.
//     LONG  : BUY_STOP  at  High[1] + 1 pip ; SL = Low[1]  (crossing-day low)
//     SHORT : SELL_STOP at  Low[1]  - 1 pip ; SL = High[1] (crossing-day high)
//     SL distance is capped at sl_cap_pips (Wilder/P2 100-pip cap).
//   Cancel-on-recross : if the DI lines re-cross opposite before the pending
//     stop fills, the pending order is removed (Strategy_ManageOpenPosition).
//   Pending expiration: order is GTC-bounded to entry_expire_bars D1 bars; if it
//     has not filled by then it is stale and removed by expiration.
//   Exit (open position): DI lines re-cross opposite -> close manually
//     (Strategy_ExitSignal). Hard TP = ATR(14) * tp_atr_mult at entry.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of the
//     stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11413;
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
input int    strategy_adx_period        = 14;     // Wilder DMI / ADX / DI period
input double strategy_adxr_threshold    = 25.0;   // ADXR must exceed this (trend STATE)
input int    strategy_extreme_buf_pips  = 1;      // pips beyond crossing-day extreme for the stop entry
input int    strategy_sl_cap_pips       = 100;    // P2 cap on the extreme-point SL distance
input int    strategy_atr_period        = 14;     // ATR period for the take-profit
input double strategy_tp_atr_mult       = 3.0;    // take-profit distance = mult * ATR
input int    strategy_entry_expire_bars = 5;      // remove an unfilled pending stop after N D1 bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — DI/ADX work is on the closed-bar
// entry path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance: the capped extreme-point SL is ~sl_cap_pips wide
   // in the worst case; use it as the scale for the spread cap.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Detect a fresh DI cross on the just-closed bars. Returns +1 long cross,
// -1 short cross, 0 none. shift 1 = just-closed bar, shift 2 = bar before it.
int DICrossDirection()
  {
   const double dip1 = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double dim1 = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double dip2 = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 2);
   const double dim2 = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 2);
   if(dip1 <= 0.0 && dim1 <= 0.0)
      return 0; // indicator not warmed up
   if(dip2 <= 0.0 && dim2 <= 0.0)
      return 0;

   const bool long_cross  = (dip2 <= dim2 && dip1 > dim1);
   const bool short_cross = (dim2 <= dip2 && dim1 > dip1);
   if(long_cross)
      return +1;
   if(short_cross)
      return -1;
   return 0;
  }

// Wilder ADXR at the just-closed bar (shift 1):
//   ADXR = (ADX[1] + ADX[1 + adx_period]) / 2.
double CurrentADXR()
  {
   const double adx_now  = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double adx_past = QM_ADX(_Symbol, _Period, strategy_adx_period, 1 + strategy_adx_period);
   if(adx_now <= 0.0 || adx_past <= 0.0)
      return 0.0;
   return (adx_now + adx_past) / 2.0;
  }

// Entry: place a STOP order at the crossing-day extreme (Extreme Point Rule).
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();

   // One position per magic: no new entry while a position is open.
   if(QM_TM_OpenPositionCount(magic) > 0)
      return false;

   // Only one live pending stop at a time (the framework duplicate-guard only
   // covers OPEN positions, not pendings — guard pendings here).
   if(PendingCountForMagic(magic) > 0)
      return false;

   // --- Trigger EVENT: fresh DI cross on the just-closed bar ---
   const int dir = DICrossDirection();
   if(dir == 0)
      return false;

   // --- Confirming STATE: ADXR above threshold (strong trend) ---
   const double adxr = CurrentADXR();
   if(adxr <= 0.0 || adxr <= strategy_adxr_threshold)
      return false;

   // --- Extreme Point Rule: stop order at the crossing-day extreme ---
   const double hi1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double lo1 = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(hi1 <= 0.0 || lo1 <= 0.0)
      return false;

   const double buf      = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_extreme_buf_pips);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   double entry = 0.0;
   double sl    = 0.0;
   if(dir > 0)
     {
      // LONG: BUY_STOP at crossing-day high + buffer; SL at crossing-day low.
      entry = hi1 + buf;
      sl    = lo1;
      // P2 cap on the SL distance.
      if((entry - sl) > cap_dist)
         sl = entry - cap_dist;
      req.type = QM_BUY_STOP;
     }
   else
     {
      // SHORT: SELL_STOP at crossing-day low - buffer; SL at crossing-day high.
      entry = lo1 - buf;
      sl    = hi1;
      if((sl - entry) > cap_dist)
         sl = entry + cap_dist;
      req.type = QM_SELL_STOP;
     }

   if(entry <= 0.0 || sl <= 0.0)
      return false;

   // Take profit: ATR(14) * mult from the (pending) entry price.
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   double tp = 0.0;
   if(atr_value > 0.0)
     {
      const QM_OrderType pos_type = (dir > 0) ? QM_BUY : QM_SELL;
      tp = QM_TakeATRFromValue(_Symbol, pos_type, entry, atr_value, strategy_tp_atr_mult);
     }

   req.price  = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp     = (tp > 0.0) ? QM_StopRulesNormalizePrice(_Symbol, tp) : 0.0;
   req.reason = (dir > 0) ? "wilder_dmi_long_extreme" : "wilder_dmi_short_extreme";
   req.expiration_seconds = strategy_entry_expire_bars * 86400; // D1 bars -> seconds
   return true;
  }

// Cancel-on-recross: if a pending stop order for this magic is still live but
// the DI lines have re-crossed in the OPPOSITE direction, remove the pending
// order (Wilder: a re-cross before the stop fills invalidates the signal).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(PendingCountForMagic(magic) <= 0)
      return;

   // Re-evaluate DI relationship on the just-closed bar (current STATE, not an
   // event): +DI above -DI = bullish state, below = bearish state.
   const double dip1 = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double dim1 = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(dip1 <= 0.0 && dim1 <= 0.0)
      return;

   const int total = OrdersTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;

      const long otype = OrderGetInteger(ORDER_TYPE);
      // A pending BUY_STOP is invalidated if -DI is now above +DI (bearish state).
      if(otype == ORDER_TYPE_BUY_STOP && dim1 > dip1)
         QM_TM_RemovePendingOrder(ticket, "wilder_dmi_recross_cancel_long");
      // A pending SELL_STOP is invalidated if +DI is now above -DI (bullish state).
      else if(otype == ORDER_TYPE_SELL_STOP && dip1 > dim1)
         QM_TM_RemovePendingOrder(ticket, "wilder_dmi_recross_cancel_short");
     }
  }

// Exit: DI lines re-cross opposite to the open position's direction -> close.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double dip1 = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double dim1 = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(dip1 <= 0.0 && dim1 <= 0.0)
      return false;

   // Determine the open position's direction for this magic + symbol.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Long open: exit when -DI is now above +DI (bearish re-cross/state).
      if(ptype == POSITION_TYPE_BUY && dim1 > dip1)
         return true;
      // Short open: exit when +DI is now above -DI (bullish re-cross/state).
      if(ptype == POSITION_TYPE_SELL && dip1 > dim1)
         return true;
     }
   return false;
  }

// Count live pending orders for this EA's magic on the current symbol.
int PendingCountForMagic(const int magic)
  {
   int count = 0;
   const int total = OrdersTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      count++;
     }
   return count;
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
