#property strict
#property version   "5.0"
#property description "QM5_11391 d1-rsi3-stoch633-sma150-reversal — D1 RSI(3)+Stoch(6,3,3)+SMA(150) mean-reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11391 d1-rsi3-stoch633-sma150-reversal
// -----------------------------------------------------------------------------
// Source: "Advanced System #3 — Neat Entry: RSI + Full Stochastic"
//         (forex-strategies-revealed.com compilation, anonymous).
// Card: artifacts/cards_approved/QM5_11391_d1-rsi3-stoch633-sma150-reversal.md
//       (g0_status APPROVED). Source id dfd32799-2055-5ef8-b99b-dcbfa51daba0.
//
// Mechanics (D1, mean-reversion, closed-bar reads at shift 1):
//   Trend STATE  : close > SMA(150) => long bias ; close < SMA(150) => short bias.
//   RSI extreme  : RSI(3) reached the extreme (<rsi_lo for longs, >rsi_hi for
//                  STATE        shorts) on ANY of the prior rsi_lookback closed
//                  bars (shifts 1..rsi_lookback). State, not the trigger.
//   Stoch EVENT  : THE single trigger. Full Stoch(6,3,3) %K crosses the cross
//                  level in the reversal direction on the just-closed bar:
//                    LONG : %K[2] < stoch_lo  AND  %K[1] > stoch_lo   (up cross)
//                    SHORT: %K[2] > stoch_hi  AND  %K[1] < stoch_hi   (down cross)
//   TP           : SMA(150) level at entry (mean reversion to the macro MA).
//                  Skipped if the SMA target is < min_tp_pips from entry.
//   SL           : ATR(14) * sl_atr_mult from entry, capped at sl_cap_pips.
//   Spread guard : skip only a genuinely wide spread (> spread_pct_of_stop of the
//                  stop distance). Fail-OPEN on .DWX zero modeled spread.
//
// The RSI extreme is a STATE over a small lookback; the Stoch %K cross is the
// single fresh EVENT — this avoids the two-cross-same-bar zero-trade trap.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11391;
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
input int    strategy_sma_period         = 150;    // macro trend SMA period
input int    strategy_rsi_period         = 3;      // RSI period (fast)
input double strategy_rsi_lo             = 20.0;   // RSI oversold extreme (long bias)
input double strategy_rsi_hi             = 80.0;   // RSI overbought extreme (short bias)
input int    strategy_rsi_lookback       = 2;      // bars back to allow the RSI extreme (state)
input int    strategy_stoch_k            = 6;      // Full Stochastic %K period
input int    strategy_stoch_d            = 3;      // Full Stochastic %D period
input int    strategy_stoch_slowing      = 3;      // Full Stochastic slowing
input double strategy_stoch_lo           = 30.0;   // %K up-cross level (long trigger)
input double strategy_stoch_hi           = 70.0;   // %K down-cross level (short trigger)
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 1.5;    // stop distance = mult * ATR
input int    strategy_sl_cap_pips        = 80;     // hard cap on stop distance (pips)
input int    strategy_min_tp_pips        = 50;     // skip if SMA target < this many pips
input double strategy_spread_pct_of_stop = 30.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   double stop_distance = strategy_sl_atr_mult * atr_value;
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance > 0.0 && stop_distance > cap_distance)
      stop_distance = cap_distance;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: close vs SMA(150) on the just-closed bar ---
   const double sma = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool long_bias  = (close1 > sma);
   const bool short_bias = (close1 < sma);
   if(!long_bias && !short_bias)
      return false;

   // --- Stoch EVENT: the single trigger — %K cross on the just-closed bar ---
   const double stoch_k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slowing, 1);
   const double stoch_k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d,
                                      strategy_stoch_slowing, 2);
   if(stoch_k1 <= 0.0 || stoch_k2 <= 0.0)
      return false;

   const bool stoch_cross_up   = (stoch_k2 < strategy_stoch_lo && stoch_k1 > strategy_stoch_lo);
   const bool stoch_cross_down = (stoch_k2 > strategy_stoch_hi && stoch_k1 < strategy_stoch_hi);

   // --- RSI extreme STATE: reached the extreme on ANY of the prior N bars ---
   // (shifts 1..rsi_lookback). This is the regime state, NOT the trigger event.
   bool rsi_oversold   = false;
   bool rsi_overbought = false;
   const int last_shift = (strategy_rsi_lookback < 1) ? 1 : strategy_rsi_lookback;
   for(int s = 1; s <= last_shift; ++s)
     {
      const double rsi_s = QM_RSI(_Symbol, _Period, strategy_rsi_period, s);
      if(rsi_s <= 0.0)
         continue;
      if(rsi_s < strategy_rsi_lo)
         rsi_oversold = true;
      if(rsi_s > strategy_rsi_hi)
         rsi_overbought = true;
     }

   // Combine STATE + EVENT into a single direction decision.
   QM_OrderType side;
   if(long_bias && rsi_oversold && stoch_cross_up)
      side = QM_BUY;
   else if(short_bias && rsi_overbought && stoch_cross_down)
      side = QM_SELL;
   else
      return false;

   // --- Entry / stop / target ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Stop distance = mult * ATR, capped at sl_cap_pips.
   double stop_distance = strategy_sl_atr_mult * atr_value;
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap_distance > 0.0 && stop_distance > cap_distance)
      stop_distance = cap_distance;
   if(stop_distance <= 0.0)
      return false;

   double sl;
   if(side == QM_BUY)
      sl = entry - stop_distance;
   else
      sl = entry + stop_distance;

   // TP = SMA(150) level at entry (mean reversion). Enforce a minimum distance.
   const double tp = QM_StopRulesNormalizePrice(_Symbol, sma);
   const double min_tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_tp_pips);
   const double tp_distance = MathAbs(tp - entry);
   if(min_tp_distance > 0.0 && tp_distance < min_tp_distance)
      return false; // SMA target too close — skip per card min-TP rule

   // Target must be on the correct side of entry (reversion toward the SMA).
   if(side == QM_BUY && tp <= entry)
      return false;
   if(side == QM_SELL && tp >= entry)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "rsi3_stoch633_sma150_long"
                                 : "rsi3_stoch633_sma150_short";
   return true;
  }

// Fixed ATR stop / SMA target — no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP set at entry.
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
