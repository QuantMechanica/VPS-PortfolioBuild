#property strict
#property version   "5.0"
#property description "QM5_11800 carter-h1-s10-ema14hl-psar-h1 — EMA(14,High/Low) channel + PSAR flip (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11800 carter-h1-s10-ema14hl-psar-h1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   Strategy #10, self-published 2014 (page 21).
// Card: artifacts/cards_approved/QM5_11800_carter-h1-s10-ema14hl-psar-h1.md
//   (g0_status: APPROVED).
//
// Mechanics (closed-bar reads at shift 1, H1):
//   Channel STATE : EMA(14) applied to PRICE_HIGH (upper) and PRICE_LOW (lower).
//                   Trend = UP  when close[1] > EMA14(High).
//                   Trend = DOWN when close[1] < EMA14(Low).
//   Trigger EVENT : Parabolic SAR(0.02, 0.2) flip — exactly ONE event per bar.
//                   Bullish flip = SAR was ABOVE price (shift 2) and is now
//                   BELOW price (shift 1). Bearish flip = inverse.
//
//   The channel break is a STATE; the PSAR flip is the single TRIGGER. Requiring
//   two fresh cross EVENTS on the same bar would almost never coincide (.DWX
//   zero-trade trap #4), so ONLY the PSAR flip is treated as an event here.
//
//   LONG  : PSAR flips bullish  AND close[1] > EMA14(High)  AND SAR[1] < Low[1].
//   SHORT : PSAR flips bearish  AND close[1] < EMA14(Low)   AND SAR[1] > High[1].
//
//   Stop  : fixed pips (55 default, card "Factory: 55 pips").
//   Take  : fixed pips (80 default, card "Factory: 80 pips").
//           Pips→price distance is scale-correct via QM_StopFixedPips /
//           QM_StopRulesPipsToPriceDistance (5-digit & JPY safe).
//   Filters: spread cap (fail-open on .DWX zero spread); optional no-Friday-entry.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11800;
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
input int    strategy_ema_period         = 14;    // EMA period for High/Low channel
input double strategy_sar_step           = 0.02;  // Parabolic SAR acceleration step
input double strategy_sar_max            = 0.2;   // Parabolic SAR acceleration maximum
input int    strategy_sl_pips            = 55;    // stop-loss distance in pips (card Factory)
input int    strategy_tp_pips            = 80;    // take-profit distance in pips (card Factory)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance
input bool   strategy_no_friday_entry    = true;  // suppress new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap (price distance of SL pips).
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

   // Optional no-Friday-entry filter.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // 5 = Friday
         return false;
     }

   // --- Channel STATE: EMA(14) on High and Low (closed bar shift 1) ---
   const double ema_high = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_HIGH);
   const double ema_low  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_LOW);
   if(ema_high <= 0.0 || ema_low <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   // --- Trigger EVENT: Parabolic SAR flip (one event per bar) ---
   // sar_prev at shift 2, sar_now at shift 1.
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return false;

   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close2 <= 0.0)
      return false;

   // Bullish flip: SAR was above price last bar, now below price this bar.
   const bool sar_flip_up   = (sar_prev > close2 && sar_now < close1);
   // Bearish flip: SAR was below price last bar, now above price this bar.
   const bool sar_flip_down = (sar_prev < close2 && sar_now > close1);

   // --- LONG: bullish PSAR flip + price above the high-EMA (up channel) ---
   if(sar_flip_up && close1 > ema_high && sar_now < low1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_BUY, entry, tp_dist);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema14hl_psar_long";
      return true;
     }

   // --- SHORT: bearish PSAR flip + price below the low-EMA (down channel) ---
   if(sar_flip_down && close1 < ema_low && sar_now > high1)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      const double tp = QM_StopRulesTakeFromDistance(_Symbol, QM_SELL, entry, tp_dist);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema14hl_psar_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — no active trade management.
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
