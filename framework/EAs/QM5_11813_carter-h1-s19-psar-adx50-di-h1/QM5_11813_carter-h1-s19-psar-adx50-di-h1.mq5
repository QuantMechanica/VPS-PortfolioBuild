#property strict
#property version   "5.0"
#property description "QM5_11813 carter-h1-s19-psar-adx50-di-h1 — ADX(50) DI cross + PSAR(0.02,0.2) side (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11813 carter-h1-s19-psar-adx50-di-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Strategy #19", in "20 Forex Trading Strategies
//         (1 Hour Time Frame)", 2014. Card:
//         artifacts/cards_approved/QM5_11813_carter-h1-s19-psar-adx50-di-h1.md
//         (g0_status APPROVED). source_id 529382f8-fbd1-5c17-ba62-fbe56990ebcd.
//
// Sibling of QM5_11685 (same #19 strategy) but THIS card's mechanic differs:
// here the PSAR FLIP is NOT the entry trigger. The card's mechanical entry is
// the ADX(50) +DI/-DI directional CROSS (the "macro direction" event that
// "fires rarely, only on well-established sustained trends") confirmed by the
// PSAR SIDE state. PSAR side is a STATE (psar < close = bullish), the DI cross
// is the single trigger EVENT. Making both pure states would re-fire every bar;
// making both flip-events almost never coincide (two-cross trap). So:
//   Trigger EVENT  : ADX(50) +DI/-DI directional cross (shift 2 -> shift 1).
//                    LONG  = +DI crosses ABOVE -DI.  SHORT = -DI crosses above +DI.
//   PSAR  STATE    : Parabolic SAR(0.02,0.2) on the bullish side for LONG
//                    (psar < close, closed bar), bearish side for SHORT
//                    (psar > close).  Card: "psar[0] < Close[0]" / "psar[0] > Close[0]".
//   Stop           : fixed sl_pips (card: 50 pips).
//   Take profit    : fixed tp_pips (card: 50 pips, 1:1) via QM_TakeRR.
//   Defensive exit : card "Exit = close when PSAR flips to the opposite side of
//                    price, OR when the DI lines cross (-DI crosses above +DI
//                    for a long exit)". Both are single-event closed-bar checks
//                    in Strategy_ExitSignal.
//   No-Friday-entry: card-spirit filter — skip new entries on Fridays (broker).
//   Spread guard   : block only a genuinely wide spread (fail-open on .DWX
//                    zero modeled spread).
//
// Note: this card specifies DI DIRECTION only (no ADX magnitude threshold),
// unlike sibling 11685 which adds an ADX>=threshold filter. We follow THIS
// card and do not add an ADX-magnitude gate.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11813;
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
input int    strategy_adx_period        = 50;     // ADX/DI period (card: very long, smooth)
input double strategy_sl_pips           = 50.0;   // stop distance in pips (card: 50 pips)
input double strategy_tp_pips           = 50.0;   // take-profit distance in pips (1:1)
input bool   strategy_no_friday_entry   = true;   // card-spirit: no new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — DI/PSAR work is on the
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

   // No new entries on Friday (broker time), card-spirit filter.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Trigger EVENT: ADX(50) +DI/-DI directional CROSS (shift 2 -> shift 1) ---
   const double plus_now   = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_now  = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double plus_prev  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 2);
   const double minus_prev = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 2);
   if(plus_now <= 0.0 || minus_now <= 0.0 || plus_prev <= 0.0 || minus_prev <= 0.0)
      return false;

   // Bullish DI cross (+DI crosses above -DI) = LONG macro-direction event.
   const bool di_cross_up   = (plus_prev <= minus_prev && plus_now > minus_now);
   // Bearish DI cross (-DI crosses above +DI) = SHORT macro-direction event.
   const bool di_cross_down = (minus_prev <= plus_prev && minus_now > plus_now);
   if(!di_cross_up && !di_cross_down)
      return false; // no DI cross this bar — the single trigger did not fire

   // --- PSAR SIDE state (closed bar): bullish dot below price / bearish above ---
   const double sar  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close1 <= 0.0)
      return false;
   const bool sar_bullish = (sar < close1); // card: psar[0] < Close[0]
   const bool sar_bearish = (sar > close1); // card: psar[0] > Close[0]

   QM_OrderType order_type;
   if(di_cross_up && sar_bullish)
      order_type = QM_BUY;
   else if(di_cross_down && sar_bearish)
      order_type = QM_SELL;
   else
      return false; // DI cross and PSAR side disagree — skip

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
   req.reason = (order_type == QM_BUY) ? "psar_adxdi_long" : "psar_adxdi_short";
   return true;
  }

// No active management beyond the fixed stop/target. Indicator-driven exits
// (PSAR flip OR DI cross) live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit per card: close when the PSAR flips to the opposite side of
// price OR when the ADX +DI/-DI directional lines cross against the open
// position. Each is a single event (shift 2 -> shift 1), so the exit fires once.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
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
   if(!have_long && !have_short)
      return false;

   // --- PSAR-flip exit (card: "close when PSAR flips to the opposite side") ---
   // PSAR side crosses price between the prior closed bar (shift 2) and the
   // latest closed bar (shift 1): a single flip event.
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2   = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_now > 0.0 && sar_prev > 0.0 && close1 > 0.0 && close2 > 0.0)
     {
      // SAR flips ABOVE price (bullish->bearish) closes a long.
      const bool flip_to_above = (sar_prev < close2 && sar_now > close1);
      // SAR flips BELOW price (bearish->bullish) closes a short.
      const bool flip_to_below = (sar_prev > close2 && sar_now < close1);
      if(have_long && flip_to_above)
         return true;
      if(have_short && flip_to_below)
         return true;
     }

   // --- DI-cross exit (card: "OR when DI lines cross") ---
   const double plus_now  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_now = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double plus_prev = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 2);
   const double minus_prev= QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 2);
   if(plus_now <= 0.0 || minus_now <= 0.0 || plus_prev <= 0.0 || minus_prev <= 0.0)
      return false;

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
