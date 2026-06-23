#property strict
#property version   "5.0"
#property description "QM5_11552 carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd — H4 trend + M5 EMA5/10 cross + RSI/Stoch/MACD confluence (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11552 carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #11 (self-published 2014).
// Card: artifacts/cards_approved/QM5_11552_carter-t-m5-ema5-10-mtf4h-rsi-stoch-macd.md
//   (g0_status: APPROVED).
//
// Mechanics (entry on M5, all reads at the last CLOSED bar = shift 1):
//   H4 trend STATE  : EMA(fast) vs EMA(slow) on PERIOD_H4 (explicit-tf reads).
//                     up = ema5_h4 > ema10_h4 ; down = ema5_h4 < ema10_h4.
//   Trigger EVENT   : M5 EMA(fast)/EMA(slow) cross. LONG = fast crosses ABOVE
//                     slow (fast@2 <= slow@2  AND  fast@1 > slow@1). The single
//                     fresh EVENT on the bar; everything else is a STATE.
//   RSI STATE       : M5 RSI(period) > rsi_mid (LONG) / < rsi_mid (SHORT).
//   Stoch STATE     : M5 %K heading up (k@1 > k@2) AND not overbought
//                     (k@1 < stoch_ob) for LONG; heading down AND not oversold
//                     (k@1 > stoch_os) for SHORT.
//   MACD STATE      : M5 MACD main "just turned positive OR negative-and-rising"
//                     (main@1 > main@2 OR (main@1 < 0 AND main@1 > main@2)) for
//                     LONG — i.e. momentum increasing; mirror for SHORT.
//   Stop / Take     : fixed pips (sl_pips / tp_pips), scale-correct via the
//                     framework pip helpers.
//   No-Friday-entry : the card forbids fresh Friday entries (filter hook).
//
// .DWX invariants honoured:
//   - Only ONE fresh cross EVENT (the M5 EMA cross). RSI/Stoch/MACD/H4 are STATES,
//     never required to cross on the same bar (rule 4: two-cross trap avoided).
//   - Spread guard fails OPEN on zero modeled spread (rule 1).
//   - SL/TP in PIPS via QM_StopFixedPips / QM_TakeRR-on-pip-distance (rule 14).
//   - H4 reads use explicit-tf QM_* calls so the foreign-tf buffers warm up.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11552;
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
input ENUM_TIMEFRAMES strategy_trend_tf      = PERIOD_H4;  // multi-TF trend filter timeframe
input int    strategy_ema_fast_period        = 5;          // fast EMA (M5 entry + H4 trend)
input int    strategy_ema_slow_period        = 10;         // slow EMA (M5 entry + H4 trend)
input int    strategy_rsi_period             = 14;         // RSI period (M5)
input double strategy_rsi_mid                = 50.0;        // RSI midline: >mid long, <mid short
input int    strategy_stoch_k               = 5;           // Stochastic %K period
input int    strategy_stoch_d               = 3;           // Stochastic %D period
input int    strategy_stoch_slow            = 3;           // Stochastic slowing
input double strategy_stoch_ob              = 80.0;        // overbought ceiling (block long above)
input double strategy_stoch_os              = 20.0;        // oversold floor (block short below)
input int    strategy_macd_fast             = 12;          // MACD fast EMA
input int    strategy_macd_slow             = 26;          // MACD slow EMA
input int    strategy_macd_signal           = 9;           // MACD signal EMA
input double strategy_sl_pips               = 25.0;        // stop loss, pips
input double strategy_tp_pips               = 25.0;        // take profit, pips
input double strategy_spread_pct_of_stop    = 20.0;        // skip if spread > this % of stop distance
input bool   strategy_no_friday_entry       = true;        // card: no fresh Friday entries

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread)
// plus the card's no-Friday-entry rule. Regime/signal work is on the closed-bar
// entry path.
bool Strategy_NoTradeFilter()
  {
   // Card: no fresh Friday entries.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday (Sun=0..Sat=6)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap, scale-correct via pip helper.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (M5 closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- H4 trend STATE (explicit-tf reads on the multi-TF filter timeframe) ---
   const double ema_fast_htf = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_fast_period, 1);
   const double ema_slow_htf = QM_EMA(_Symbol, strategy_trend_tf, strategy_ema_slow_period, 1);
   if(ema_fast_htf <= 0.0 || ema_slow_htf <= 0.0)
      return false;
   const bool htf_up   = (ema_fast_htf > ema_slow_htf);
   const bool htf_down = (ema_fast_htf < ema_slow_htf);
   if(!htf_up && !htf_down)
      return false;

   // --- M5 EMA(fast)/EMA(slow) — the SINGLE fresh cross EVENT ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;
   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false; // no fresh trigger this bar

   // --- M5 RSI STATE (midline side) ---
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   // --- M5 Stochastic STATE (%K heading + not over-extended) ---
   const double k_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k_1 <= 0.0 || k_2 <= 0.0)
      return false;

   // --- M5 MACD STATE (main rising = momentum increasing) ---
   const double macd_1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   // MACD turning positive OR negative-but-increasing == main rising (main_1 > main_2).
   const bool macd_rising  = (macd_1 > macd_2);
   const bool macd_falling = (macd_1 < macd_2);

   // ----------------------------- LONG ------------------------------
   if(cross_up && htf_up)
     {
      const bool rsi_ok   = (rsi_1 > strategy_rsi_mid);
      const bool stoch_ok = (k_1 > k_2 && k_1 < strategy_stoch_ob);   // heading up, not overbought
      if(rsi_ok && stoch_ok && macd_rising)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
         const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "carter_mtf_ema_long";
         return true;
        }
      return false;
     }

   // ----------------------------- SHORT -----------------------------
   if(cross_down && htf_down)
     {
      const bool rsi_ok   = (rsi_1 < strategy_rsi_mid);
      const bool stoch_ok = (k_1 < k_2 && k_1 > strategy_stoch_os);   // heading down, not oversold
      if(rsi_ok && stoch_ok && macd_falling)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
         const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "carter_mtf_ema_short";
         return true;
        }
      return false;
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
