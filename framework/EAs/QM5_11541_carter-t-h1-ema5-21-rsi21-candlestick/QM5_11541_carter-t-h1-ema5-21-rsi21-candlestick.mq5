#property strict
#property version   "5.0"
#property description "QM5_11541 carter-t-h1-ema5-21-rsi21-candlestick — EMA(5/21)+RSI(21)+candlestick confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11541 carter-t-h1-ema5-21-rsi21-candlestick
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//   System #15, self-published 2014.
// Card: artifacts/cards_approved/QM5_11541_carter-t-h1-ema5-21-rsi21-candlestick.md
//   (g0_status APPROVED). Source ID 3001a121-97a0-5db0-b6ff-69b89a0fc07d.
//
// Mechanics (H1, closed-bar reads at shift 1; one position per magic):
//   TRIGGER EVENT : a completed candlestick reversal pattern on bar[1].
//                     LONG  -> Bullish Engulfing OR Hammer.
//                     SHORT -> Bearish Engulfing OR Inverted Hammer.
//   STATE (trend) : EMA(5) vs EMA(21) stack side at shift 1.
//                     LONG  -> ema5 > ema21.   SHORT -> ema5 < ema21.
//   STATE (mom.)  : RSI(21) at shift 1.
//                     LONG  -> rsi > rsi_mid.  SHORT -> rsi < rsi_mid.
//
//   The candlestick pattern is the single fresh EVENT; the EMA stack side and
//   RSI side are confirming STATES. This deliberately avoids the .DWX
//   two-cross-same-bar zero-trade trap (requiring a fresh EMA cross AND a
//   fresh RSI cross on the same bar almost never fires).
//
//   STOP   : 5-bar swing low (long) / swing high (short), capped at sl_cap_pips.
//   TARGET : SL distance * tp_rr (2R default).
//   EXIT   : EMA(5) crosses back through EMA(21) against the trade, OR RSI
//            crosses back through rsi_mid against the trade.
//   FILTERS: no-Friday-entry (card), spread cap (fail-open on .DWX zero spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11541;
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
input int    strategy_ema_fast_period   = 5;      // fast EMA (trend stack)
input int    strategy_ema_slow_period   = 21;     // slow EMA (trend stack)
input int    strategy_rsi_period        = 21;     // RSI lookback
input double strategy_rsi_mid           = 50.0;   // RSI midline (confirm + exit)
input int    strategy_sl_lookback       = 5;      // swing-low/high lookback for SL
input double strategy_sl_cap_pips       = 40.0;   // SL cap in pips (card P2)
input double strategy_tp_rr             = 2.0;    // TP = tp_rr * SL distance
input double strategy_hammer_body_pips  = 3.0;    // min hammer/inv-hammer body (pips)
input bool   strategy_block_friday      = true;   // card: no Friday entries
input double strategy_spread_cap_pips   = 15.0;   // skip genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Candlestick helpers (closed-bar OHLC; perf-allowed single-bar reads).
// bar1 = last closed bar (the pattern bar). bar2 = the bar before it.
// -----------------------------------------------------------------------------

// Bullish Engulfing: prior bar bearish, pattern bar bullish and engulfs the
// prior bar's range (high above prior high, low below prior low).
bool Cdl_BullishEngulfing(const double o1, const double h1, const double l1, const double c1,
                          const double o2, const double h2, const double l2, const double c2)
  {
   if(!(c1 > o1))   return false;   // pattern bar bullish
   if(!(c2 < o2))   return false;   // prior bar bearish
   if(!(h1 > h2))   return false;   // engulf high
   if(!(l1 < l2))   return false;   // engulf low
   return true;
  }

// Bearish Engulfing: prior bar bullish, pattern bar bearish and engulfs it.
bool Cdl_BearishEngulfing(const double o1, const double h1, const double l1, const double c1,
                          const double o2, const double h2, const double l2, const double c2)
  {
   if(!(c1 < o1))   return false;   // pattern bar bearish
   if(!(c2 > o2))   return false;   // prior bar bullish
   if(!(h1 > h2))   return false;   // engulf high
   if(!(l1 < l2))   return false;   // engulf low
   return true;
  }

// Hammer (bullish reversal): long lower wick, small upper wick, real body.
//   lower >= 2*body  AND  upper <= 0.5*body  AND  body > min_body
bool Cdl_Hammer(const double o1, const double h1, const double l1, const double c1,
                const double min_body)
  {
   const double body  = MathAbs(c1 - o1);
   const double lower = MathMin(o1, c1) - l1;
   const double upper = h1 - MathMax(o1, c1);
   if(body <= min_body)        return false;
   if(lower < 2.0 * body)      return false;
   if(upper > 0.5 * body)      return false;
   return true;
  }

// Inverted Hammer (used here as the bearish-side trigger per card): long upper
// wick, small lower wick, real body. Mirror of Hammer.
bool Cdl_InvertedHammer(const double o1, const double h1, const double l1, const double c1,
                        const double min_body)
  {
   const double body  = MathAbs(c1 - o1);
   const double upper = h1 - MathMax(o1, c1);
   const double lower = MathMin(o1, c1) - l1;
   if(body <= min_body)        return false;
   if(upper < 2.0 * body)      return false;
   if(lower > 0.5 * body)      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (regime/signal work runs on the
// closed-bar path in Strategy_EntrySignal). Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > cap_dist)
      return true;

   return false;
  }

// Confluence entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Card filter: no Friday entries (use bar-open time of the new bar) ---
   if(strategy_block_friday)
     {
      const datetime bar_open = iTime(_Symbol, _Period, 1); // perf-allowed: bar timestamp
      MqlDateTime dt;
      TimeToStruct(bar_open, dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Trend STATE: EMA(5)/EMA(21) stack side at the closed bar ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Momentum STATE: RSI(21) side at the closed bar ---
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // --- Closed-bar OHLC for the pattern bar (shift 1) and prior bar (shift 2) ---
   const double o1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed-bar reads
   const double h1 = iHigh(_Symbol, _Period, 1);
   const double l1 = iLow(_Symbol, _Period, 1);
   const double c1 = iClose(_Symbol, _Period, 1);
   const double o2 = iOpen(_Symbol, _Period, 2);
   const double h2 = iHigh(_Symbol, _Period, 2);
   const double l2 = iLow(_Symbol, _Period, 2);
   const double c2 = iClose(_Symbol, _Period, 2);
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0 ||
      o2 <= 0.0 || h2 <= 0.0 || l2 <= 0.0 || c2 <= 0.0)
      return false;

   const double min_body = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_hammer_body_pips);

   // --- LONG: EMA stack up + RSI > mid + (Bullish Engulfing OR Hammer) ---
   const bool trend_up   = (ema_fast > ema_slow);
   const bool rsi_up     = (rsi > strategy_rsi_mid);
   const bool cdl_long   = Cdl_BullishEngulfing(o1, h1, l1, c1, o2, h2, l2, c2) ||
                           Cdl_Hammer(o1, h1, l1, c1, min_body);

   // --- SHORT: EMA stack down + RSI < mid + (Bearish Engulfing OR Inv Hammer) ---
   const bool trend_down = (ema_fast < ema_slow);
   const bool rsi_down   = (rsi < strategy_rsi_mid);
   const bool cdl_short  = Cdl_BearishEngulfing(o1, h1, l1, c1, o2, h2, l2, c2) ||
                           Cdl_InvertedHammer(o1, h1, l1, c1, min_body);

   QM_OrderType dir;
   if(trend_up && rsi_up && cdl_long)
      dir = QM_BUY;
   else if(trend_down && rsi_down && cdl_short)
      dir = QM_SELL;
   else
      return false;

   // --- Stop: swing low (long) / swing high (short) over the lookback window,
   //     capped at sl_cap_pips. Take profit at tp_rr * stop distance. ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_cap_pips);
   if(cap_dist <= 0.0)
      return false;

   double swing = 0.0;
   if(dir == QM_BUY)
     {
      const int idx = iLowest(_Symbol, _Period, MODE_LOW, strategy_sl_lookback, 1);
      if(idx < 0)
         return false;
      swing = iLow(_Symbol, _Period, idx); // perf-allowed: structural swing read
      if(swing <= 0.0 || swing >= entry)
         return false;
      double sl = swing;
      if(entry - sl > cap_dist)            // cap the stop distance
         sl = entry - cap_dist;
      const double stop_dist = entry - sl;
      if(stop_dist <= 0.0)
         return false;
      const double tp = entry + strategy_tp_rr * stop_dist;

      req.type   = QM_BUY;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "carter_h1_long";
      return true;
     }
   else
     {
      const int idx = iHighest(_Symbol, _Period, MODE_HIGH, strategy_sl_lookback, 1);
      if(idx < 0)
         return false;
      swing = iHigh(_Symbol, _Period, idx); // perf-allowed: structural swing read
      if(swing <= 0.0 || swing <= entry)
         return false;
      double sl = swing;
      if(sl - entry > cap_dist)             // cap the stop distance
         sl = entry + cap_dist;
      const double stop_dist = sl - entry;
      if(stop_dist <= 0.0)
         return false;
      const double tp = entry - strategy_tp_rr * stop_dist;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "carter_h1_short";
      return true;
     }
  }

// No active trade management beyond the fixed swing stop / RR target. The
// defensive indicator exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(5) crosses back through EMA(21) against the open trade,
// OR RSI crosses back through the midline against it. Direction-aware.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
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
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }
   if(!have_long && !have_short)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double rsi_now   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0 ||
      rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   if(have_long)
     {
      const bool ema_cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
      const bool rsi_cross_down = (rsi_prev >= strategy_rsi_mid && rsi_now < strategy_rsi_mid);
      return (ema_cross_down || rsi_cross_down);
     }

   // have_short
   const bool ema_cross_up = (fast_prev <= slow_prev && fast_now > slow_now);
   const bool rsi_cross_up = (rsi_prev <= strategy_rsi_mid && rsi_now > strategy_rsi_mid);
   return (ema_cross_up || rsi_cross_up);
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
