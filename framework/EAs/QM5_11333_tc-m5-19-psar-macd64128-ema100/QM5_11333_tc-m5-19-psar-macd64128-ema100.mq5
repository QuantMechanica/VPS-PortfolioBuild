#property strict
#property version   "5.0"
#property description "QM5_11333 tc-m5-19-psar-macd64128-ema100 — TC M5 System #19 (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11333 tc-m5-19-psar-macd64128-ema100
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   5 Min Trading System #19. Card: artifacts/cards_approved/
//   QM5_11333_tc-m5-19-psar-macd64128-ema100.md (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; LONG shown, SHORT mirrored):
//   Trend STATE  : close(1) > EMA(100)            [macro trend filter]
//   MACD  STATE  : MACD(64,128,9) main > 0        [very slow MACD = trend filter,
//                  can be negative -> sign is a STATE, not a magnitude gate]
//   PSAR  STATE  : SAR(0.01,0.01) below the bar   [SAR(1) < close(1)]
//   Trigger EVENT: ONE fresh event, EITHER --
//                  (a) PSAR flips to bullish this bar
//                      (SAR(2) >= close(2) AND SAR(1) < close(1)), OR
//                  (b) MACD main crosses up through 0 this bar
//                      (MACD(2) <= 0 AND MACD(1) > 0).
//                  Requiring a fresh event on BOTH the SAR and the MACD on the
//                  same bar almost never coincides (the .DWX two-cross-same-bar
//                  zero-trade trap) -> EITHER event triggers, the rest are STATES.
//   Stop (LONG)  : SAR(1) - sl_buffer_pips, scale-correct (pips->price distance).
//   Take profit  : entry + tp_pips (fixed pip target).
//   One position per magic. RISK_FIXED in tester / RISK_PERCENT live.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//                  spread > spread_cap_pips blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11333;
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
input int    strategy_ema_period        = 100;    // macro-trend EMA
input double strategy_sar_step          = 0.01;   // PSAR acceleration step
input double strategy_sar_max           = 0.01;   // PSAR acceleration max (card: tight 0.01)
input int    strategy_macd_fast         = 64;     // very-slow MACD fast EMA
input int    strategy_macd_slow         = 128;    // very-slow MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal period (unused for zero-cross)
input int    strategy_sl_buffer_pips    = 3;      // SL buffer beyond the PSAR dot (pips)
input int    strategy_tp_pips           = 10;     // fixed take-profit (pips); card 7-12, P2=10
input double strategy_spread_cap_pips   = 8.0;    // skip only a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// a genuinely wide spread (> cap) blocks; zero/negative modeled spread passes.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false; // cannot scale a cap — defer to entry gate, do not block

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar reads (shift 1 = last closed bar, shift 2 = prior) ---
   const double ema1   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema1 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return false;

   // MACD main can be negative — its SIGN is a state, its zero-cross an event.
   const double macd1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);

   // PSAR side as a STATE on the trigger bar.
   const bool sar_below_long  = (sar1 < close1);   // bullish PSAR
   const bool sar_above_short = (sar1 > close1);   // bearish PSAR

   // Fresh PSAR flip EVENTS (side changed between bar 2 and bar 1).
   const bool sar_flip_bull = (sar2 >= close2 && sar1 < close1);
   const bool sar_flip_bear = (sar2 <= close2 && sar1 > close1);

   // Fresh MACD zero-cross EVENTS.
   const bool macd_cross_up   = (macd2 <= 0.0 && macd1 > 0.0);
   const bool macd_cross_down = (macd2 >= 0.0 && macd1 < 0.0);

   // ----------------------------- LONG -----------------------------
   // STATES: price > EMA100, MACD > 0, PSAR below price.
   // EVENT : a fresh PSAR bullish flip OR a fresh MACD up-cross of zero.
   if(close1 > ema1 && macd1 > 0.0 && sar_below_long &&
      (sar_flip_bull || macd_cross_up))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;

      // SL: 3 pips below the PSAR dot. PSAR is already below price for a long.
      const double buffer  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
      const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
      double sl = QM_StopRulesNormalizePrice(_Symbol, sar1 - buffer);
      double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist); // TP above entry for a long
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry || tp <= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "tc_m5_19_psar_macd_ema_long";
      return true;
     }

   // ----------------------------- SHORT ----------------------------
   // STATES: price < EMA100, MACD < 0, PSAR above price.
   // EVENT : a fresh PSAR bearish flip OR a fresh MACD down-cross of zero.
   if(close1 < ema1 && macd1 < 0.0 && sar_above_short &&
      (sar_flip_bear || macd_cross_down))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;

      // SL: 3 pips above the PSAR dot. PSAR is already above price for a short.
      const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
      double sl = QM_StopRulesNormalizePrice(_Symbol, sar1 + buffer);
      double tp = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "tc_m5_19_psar_macd_ema_short";
      return true;
     }

   return false;
  }

// Fixed PSAR-buffer stop + fixed pip target handle the exit. No active trail.
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
