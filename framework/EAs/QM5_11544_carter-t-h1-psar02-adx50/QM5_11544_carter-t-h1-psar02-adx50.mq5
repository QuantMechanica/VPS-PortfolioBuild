#property strict
#property version   "5.0"
#property description "QM5_11544 carter-t-h1-psar02-adx50 — PSAR(0.02,0.2) flip + ADX(50) directional (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11544 carter-t-h1-psar02-adx50
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #19, self-published 2014.
// Card: artifacts/cards_approved/QM5_11544_carter-t-h1-psar02-adx50.md
//       (g0_status APPROVED). source_id 3001a121-97a0-5db0-b6ff-69b89a0fc07d.
//
// Mechanics (closed-bar reads at shift 1/2, H1):
//   Trigger EVENT  : Parabolic SAR(0.02, 0.2) FLIPS sides relative to price.
//                    LONG  = SAR was ABOVE the candle on the prior closed bar
//                            (shift 2) and is now BELOW it (shift 1).
//                    SHORT = mirror (SAR flips from below to above price).
//                    The flip is a single event per bar — never two crosses
//                    on the same bar.
//   Trend STATE    : ADX(50) >= adx_threshold (a very long, smooth ADX — slow
//                    to turn, fewer whipsaws). State filter, not an event.
//   Direction STATE: +DI > -DI for LONG, -DI > +DI for SHORT (closed bar).
//   Stop           : fixed sl_pips (50p default, card P2 cap 55).
//   Take profit    : fixed tp_pips (50p default, 1:1) via QM_TakeRR.
//   Defensive exit : +DI / -DI cross back the other way -> close manually
//                    (the card's "DI cross again" indicator-driven exit).
//   No-Friday-entry: card filter — skip new entries on Fridays (broker time).
//   Spread guard   : block only a genuinely wide spread (fail-open on .DWX
//                    zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11544;
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
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_max           = 0.2;    // Parabolic SAR acceleration maximum
input int    strategy_adx_period        = 50;     // ADX period (card: very long, smooth)
input double strategy_adx_threshold     = 20.0;   // ADX trend-strength floor (state filter)
input double strategy_sl_pips           = 50.0;   // stop distance in pips
input double strategy_tp_pips           = 50.0;   // take-profit distance in pips (1:1)
input bool   strategy_no_friday_entry   = true;   // card filter: no new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — flip/ADX work is on the
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (broker time), per card filter.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Parabolic SAR flip EVENT (closed bars: prior side @ shift 2, new @ 1) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return false;

   // Bar geometry: SAR below the candle = bullish dot, SAR above = bearish dot.
   // perf-allowed: single closed-bar OHLC reads for the flip geometry.
   const double low1   = iLow(_Symbol, _Period, 1);
   const double high1  = iHigh(_Symbol, _Period, 1);
   const double low2   = iLow(_Symbol, _Period, 2);
   const double high2  = iHigh(_Symbol, _Period, 2);
   if(low1 <= 0.0 || high1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0)
      return false;

   // LONG flip : SAR was above the prior candle and is now below the latest.
   const bool flip_long  = (sar_prev > high2 && sar_now < low1);
   // SHORT flip: SAR was below the prior candle and is now above the latest.
   const bool flip_short = (sar_prev < low2  && sar_now > high1);
   if(!flip_long && !flip_short)
      return false; // no flip event this bar — the single trigger did not fire

   // --- Trend-strength STATE: ADX(50) above the threshold ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(adx < strategy_adx_threshold)
      return false; // not enough trend strength to take the flip

   // --- Direction STATE: +DI vs -DI on the closed bar ---
   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   QM_OrderType order_type;
   if(flip_long && plus_di > minus_di)
      order_type = QM_BUY;
   else if(flip_short && minus_di > plus_di)
      order_type = QM_SELL;
   else
      return false; // flip and DI direction disagree — skip

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (order_type == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, order_type, entry, (int)strategy_sl_pips);
   const double tp = QM_TakeRR(_Symbol, order_type, entry, sl, strategy_tp_pips / strategy_sl_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = order_type;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (order_type == QM_BUY) ? "psar_adx_long" : "psar_adx_short";
   return true;
  }

// No active management beyond the fixed stop/target. DI-cross defensive exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: +DI / -DI cross back against the open position (one event,
// shift 2 -> shift 1). Long exits on -DI crossing above +DI; short the mirror.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double plus_now  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_now = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double plus_prev = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 2);
   const double minus_prev= QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 2);
   if(plus_now <= 0.0 || minus_now <= 0.0 || plus_prev <= 0.0 || minus_prev <= 0.0)
      return false;

   // Determine open-position direction for this magic.
   bool have_long = false, have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Bearish DI cross (-DI crosses above +DI) closes a long.
   const bool di_cross_down = (plus_prev >= minus_prev && plus_now < minus_now);
   // Bullish DI cross (+DI crosses above -DI) closes a short.
   const bool di_cross_up   = (minus_prev >= plus_prev && minus_now < plus_now);

   if(have_long && di_cross_down)
      return true;
   if(have_short && di_cross_up)
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
