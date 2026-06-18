#property strict
#property version   "5.0"
#property description "QM5_11350 rbt-follow-trend-ema-adx-macd-h4 — RoboForex Follow the Trend (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11350 rbt-follow-trend-ema-adx-macd-h4
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Strategy Follow the Trend" (H4).
// Card: artifacts/cards_approved/QM5_11350_rbt-follow-trend-ema-adx-macd-h4.md
//       (g0_status APPROVED, source_id ed246754-1f4d-5bed-8dd3-3b5cbf1b420d).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   The card lists three aligned conditions. Per the .DWX zero-trade invariant
//   #4 (two fresh crossover EVENTS almost never coincide on one bar), exactly
//   ONE of the two crossovers is the firing EVENT; the rest are STATEs:
//
//     Trigger EVENT (either is sufficient, evaluated this bar):
//        a) EMA(fast) crosses above EMA(slow)   [bullish MA cross], OR
//        b) MACD main line crosses up through zero  [bullish MACD cross].
//     Direction STATE  : ADX(28) +DI > -DI  (bullish directional bias).
//     Confirm   STATE  : the OTHER, non-triggering indicator agrees long, i.e.
//                        EMA(fast) > EMA(slow)  AND  MACD main >= 0.
//        MACD main may be NEGATIVE on a bar where the EMA cross is the trigger
//        ONLY IF the MACD-confirm is relaxed; the card requires MACD>0 as the
//        confirming state, so we require MACD main >= 0 for the confirm. The
//        MACD can be (and frequently is) negative outside an entry — we do not
//        gate on its sign except as this confirm STATE. SHORT mirrors.
//
//   Exit:  TP = tp_pips (60 pips H4), SL = sl_pips (30 pips H4), fixed-distance,
//          scale-correct via QM_StopFixedPips (pip_factor-aware).
//   Defensive exit: reverse EMA(fast)/EMA(slow) cross -> close manually.
//   Spread guard: fail-OPEN; block only a genuinely wide spread > spread_cap_pips
//          (zero modeled spread on .DWX passes).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11350;
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
input int    strategy_ema_fast_period   = 4;     // fast EMA (cross trigger)
input int    strategy_ema_slow_period   = 10;    // slow EMA (cross trigger)
input int    strategy_adx_period        = 28;    // ADX period (directional STATE via +DI/-DI)
input int    strategy_macd_fast         = 5;     // MACD fast EMA
input int    strategy_macd_slow         = 10;    // MACD slow EMA
input int    strategy_macd_signal       = 4;     // MACD signal SMA
input double strategy_sl_pips           = 30.0;  // fixed stop, pips (H4)
input double strategy_tp_pips           = 60.0;  // fixed target, pips (H4)
input double strategy_spread_cap_pips   = 30.0;  // skip only a genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   // Convert the pip cap to a price distance (5-digit / JPY scale-correct).
   const double cap_price = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap_price > 0.0 && spread > cap_price)
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar indicator reads (shift 1 = last closed bar, 2 = prior) ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const double macd_1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   // MACD main can legitimately be negative; we do NOT reject on its sign here.

   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 && minus_di <= 0.0)
      return false; // ADX not warmed up yet

   // --- Trigger EVENTs (one suffices) ---
   const bool ema_cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool ema_cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   const bool macd_cross_up   = (macd_2 <= 0.0 && macd_1 >  0.0);
   const bool macd_cross_down = (macd_2 >= 0.0 && macd_1 <  0.0);

   // --- LONG: direction STATE + confirm STATE + (EMA-cross OR MACD-cross) EVENT ---
   const bool dir_long      = (plus_di > minus_di);
   const bool confirm_long  = (ema_fast_1 > ema_slow_1) && (macd_1 >= 0.0);
   const bool event_long    = (ema_cross_up || macd_cross_up);
   if(dir_long && confirm_long && event_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, (int)strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "follow_trend_long";
      return true;
     }

   // --- SHORT (mirror) ---
   const bool dir_short     = (minus_di > plus_di);
   const bool confirm_short = (ema_fast_1 < ema_slow_1) && (macd_1 <= 0.0);
   const bool event_short   = (ema_cross_down || macd_cross_down);
   if(dir_short && confirm_short && event_short)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
      const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, (int)strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "follow_trend_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed pip stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: reverse EMA(fast)/EMA(slow) cross relative to open direction.
// One event at shift 1. Framework's OnTick loop closes positions on TRUE.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_1 <= 0.0 || slow_1 <= 0.0 || fast_2 <= 0.0 || slow_2 <= 0.0)
      return false;

   const bool cross_up   = (fast_2 <= slow_2 && fast_1 >  slow_1);
   const bool cross_down = (fast_2 >= slow_2 && fast_1 <  slow_1);

   // Determine the open direction for this magic; exit on the opposite cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
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
