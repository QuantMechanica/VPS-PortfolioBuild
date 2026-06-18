#property strict
#property version   "5.0"
#property description "QM5_11487 carter-t-50-100-ema-macd-breakout-m5 — 50/100 EMA breakout + MACD zero cross (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11487 carter-t-50-100-ema-macd-breakout-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #9 (2014). Card: artifacts/cards_approved/
//   QM5_11487_carter-t-50-100-ema-macd-breakout-m5.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : EMA(50) above/below EMA(100) sets the directional bias.
//   Location STATE (LONG): close > EMA50 AND close > EMA100, AND broken above
//                  EMA50 by >= buffer pips (close - EMA50 >= buffer), AND NOT
//                  trading between the two EMAs (full breakout only).
//   Trigger EVENT: MACD main line crosses the zero line in the trade direction
//                  (neg->pos for long, pos->neg for short) WITHIN the last
//                  macd_lookback closed bars. This is the single fresh event;
//                  the EMA stack + location are STATES (no two-cross-same-bar
//                  trap — only ONE genuine cross is required).
//   Stop         : 5-bar structural low (long) / high (short) prior to entry,
//                  capped at sl_max_pips (skip if structure stop is wider).
//   Take profit  : entry +/- tp_rr * risk (risk = |entry - stop|).
//   Trail exit   : close back through EMA50 by buffer pips (defensive exit).
//   No-Friday-entry filter on top of the framework Friday-close guard.
//
// Single-position-per-magic. Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11487;
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
input int    strategy_ema_fast_period   = 50;     // trend fast EMA (50 above/below 100 = bias)
input int    strategy_ema_slow_period   = 100;    // trend slow EMA
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_macd_lookback     = 5;      // bars to look back for the MACD zero cross
input int    strategy_breakout_pips     = 10;     // breakout buffer above/below EMA50 (pips)
input int    strategy_sl_lookback_bars  = 5;      // structural SL: N-bar low/high
input int    strategy_sl_max_pips       = 25;     // skip if structural stop is wider than this (pips)
input double strategy_tp_rr             = 2.0;    // take-profit as a multiple of risk
input bool   strategy_no_friday_entry   = true;   // suppress new entries on Friday
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Did MACD main cross the zero line in `dir` (+1 up / -1 down) within the last
// `lookback` closed bars? Scans shift pairs (k, k+1) for k in [1 .. lookback].
// ONE genuine cross event satisfies it; the EMA/location checks are states.
bool MacdZeroCrossedWithin(const int dir, const int lookback)
  {
   for(int k = 1; k <= lookback; ++k)
     {
      const double m_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, k);
      const double m_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, k + 1);
      if(dir > 0 && m_prev <= 0.0 && m_now > 0.0)
         return true;
      if(dir < 0 && m_prev >= 0.0 && m_now < 0.0)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread);
// the regime/signal work lives in Strategy_EntrySignal on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   // Reference the breakout-buffer pip distance as the spread-cap baseline so
   // the cap scales correctly per symbol (5-digit / JPY safe).
   const double ref_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(ref_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * ref_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // No new entries on Friday (avoid carrying weekend gap risk).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Closed-bar reads ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1); // EMA50
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1); // EMA100
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(buffer <= 0.0)
      return false;

   QM_OrderType side = QM_BUY;
   bool have_side = false;

   // --- LONG setup ---------------------------------------------------------
   // Trend STATE: EMA50 above EMA100. Location STATE: price above both EMAs,
   // broken above EMA50 by >= buffer, and NOT between the two EMAs.
   if(ema_fast > ema_slow &&
      close1 > ema_fast && close1 > ema_slow &&
      (close1 - ema_fast) >= buffer)
     {
      // "Between the EMAs" = close above the lower EMA but below the higher
      // EMA. Here ema_fast > ema_slow so close1 > ema_fast already excludes it,
      // but assert the full-breakout condition explicitly for clarity.
      const double upper_ema = MathMax(ema_fast, ema_slow);
      if(close1 > upper_ema)
        {
         // Trigger EVENT: MACD zero cross up within the lookback window.
         if(MacdZeroCrossedWithin(+1, strategy_macd_lookback))
           {
            side = QM_BUY;
            have_side = true;
           }
        }
     }

   // --- SHORT setup --------------------------------------------------------
   if(!have_side &&
      ema_fast < ema_slow &&
      close1 < ema_fast && close1 < ema_slow &&
      (ema_fast - close1) >= buffer)
     {
      const double lower_ema = MathMin(ema_fast, ema_slow);
      if(close1 < lower_ema)
        {
         if(MacdZeroCrossedWithin(-1, strategy_macd_lookback))
           {
            side = QM_SELL;
            have_side = true;
           }
        }
     }

   if(!have_side)
      return false;

   // --- Entry price + structural stop --------------------------------------
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // 5-bar structural low (long) / high (short) prior to entry.
   const double sl = QM_StopStructure(_Symbol, side, entry, strategy_sl_lookback_bars);
   if(sl <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;

   // P2 cap: skip if the structural stop is wider than sl_max_pips.
   const double max_stop = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(max_stop > 0.0 && risk > max_stop)
      return false;

   // Take profit at tp_rr * risk.
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema_macd_breakout_long" : "ema_macd_breakout_short";
   return true;
  }

// No active trade management beyond the fixed structural stop / RR target.
// The defensive EMA50 re-break exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: price closes back through EMA50 by the breakout buffer.
//   LONG  : close < EMA50 - buffer
//   SHORT : close > EMA50 + buffer
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_fast <= 0.0 || close1 <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_breakout_pips);
   if(buffer <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(close1 < (ema_fast - buffer))
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(close1 > (ema_fast + buffer))
            return true;
        }
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
