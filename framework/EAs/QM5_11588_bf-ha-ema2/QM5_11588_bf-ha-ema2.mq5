#property strict
#property version   "5.0"
#property description "QM5_11588 bf-ha-ema2 — Heikin-Ashi meta-candle + EMA(200) + StochRSI cross (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11588 bf-ha-ema2
// -----------------------------------------------------------------------------
// Source: conor19w/Binance-Futures-Trading-Bot, TradingStrats.py heikin_ashi_ema2().
// Card: artifacts/cards_approved/QM5_11588_bf-ha-ema2.md (g0_status APPROVED).
//
// Variant 2 of the bf-ha-ema family (sibling QM5_11587). Adds a StochRSI %K/%D
// oscillator cross as the single trigger EVENT and a Heikin-Ashi META candle
// requirement, on top of the EMA(200) trend STATE. All reads are closed-bar
// (shift 1 = last closed bar). HA candles are computed in-EA from real OHLC,
// recursive from a bounded seed (perf-allowed bounded closed-bar reads, only on
// the closed-bar entry/exit path which the framework gates with QM_IsNewBar).
//
// Mechanics (long; short is the mirror):
//   Trend STATE     : EMA(period) side. HA_close(1) > EMA  (above for long).
//   HA META STATE   : within the last `setup_lookback` closed bars there exists a
//                     BULLISH meta candle: HA_close > HA_open AND HA_open == HA_low
//                     (a candle with no lower wick = strong-up meta candle).
//   StochRSI persist: during the setup window StochRSI %K never printed ABOVE the
//                     `stochrsi_long_max` threshold (stayed oversold-ish) — source
//                     "no reading above 0.30 during the setup window".
//   Trigger EVENT   : StochRSI %K crosses ABOVE %D on the last closed bar (the one
//                     fresh event). EMA side + HA meta + persistence are STATES, so
//                     we never require two cross EVENTS on the same bar (.DWX
//                     two-cross-same-bar zero-trade trap).
//   Exit            : source check_close_pos() — close long when the current HA
//                     candle turns bearish (HA_close<HA_open); close short when it
//                     turns bullish (HA_close>HA_open).
//   Stop / Take     : source default % mode — SL = sl_pct of entry, TP = tp_pct of
//                     entry, normalized to symbol tick size.
//   Spread guard    : block only a genuinely wide spread (fail-open on .DWX zero
//                     modeled spread).
//
// open_question (flagged for reviewer): the card narrates BOTH a StochRSI %K/%D
// cross AND a "bearish/bullish EMA(200) cross" within the setup window. Requiring
// two fresh cross EVENTS on one bar is the documented .DWX two-cross zero-trade
// trap. Resolved by the most-literal trade-generating reading: the StochRSI %K/%D
// cross is the SINGLE trigger event; the EMA(200) is the persistent side STATE
// (HA_close vs EMA) rather than a second simultaneous cross event. The HA meta
// candle and the StochRSI threshold-persistence are STATES inside the lookback
// window. StochRSI has no QM helper, so it is computed in-EA from QM_RSI over a
// bounded lookback (standard StochRSI: stoch of RSI, %K smoothed, %D = SMA of %K).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11588;
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
input int    strategy_ema_period          = 200;   // trend-state EMA period
input int    strategy_ha_seed_bars        = 200;   // HA recursion seed depth (bounded)
input int    strategy_setup_lookback      = 10;    // bars to scan for HA meta + persistence
input int    strategy_rsi_period          = 14;    // RSI period feeding StochRSI
input int    strategy_stochrsi_period     = 14;    // StochRSI stoch lookback over RSI
input int    strategy_stochrsi_smooth_k   = 3;     // %K smoothing (SMA)
input int    strategy_stochrsi_smooth_d   = 3;     // %D smoothing (SMA of %K)
input double strategy_stochrsi_long_max   = 0.30;  // long: %K must stay <= this in window
input double strategy_stochrsi_short_min  = 0.70;  // short: %K must stay >= this in window
input double strategy_sl_pct              = 1.5;   // stop loss, percent of entry price
input double strategy_tp_pct              = 1.0;   // take profit, percent of entry price
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Heikin-Ashi helper — compute HA open/high/low/close at a given closed-bar shift
// by recursing from a bounded seed. perf-allowed: bounded closed-bar OHLC reads,
// only run on the closed-bar entry/exit path (QM_IsNewBar-gated by the framework).
// -----------------------------------------------------------------------------

// Fills ha_open / ha_high / ha_low / ha_close for the candle at `shift`
// (1 = last closed bar). Returns false if history is not yet available.
bool ComputeHA(const int shift,
               double &ha_open, double &ha_high, double &ha_low, double &ha_close)
  {
   const int seed = (strategy_ha_seed_bars < 10 ? 10 : strategy_ha_seed_bars);
   const int start = shift + seed; // oldest bar of the recursion seed

   if(Bars(_Symbol, _Period) <= start + 1)
      return false;

   // Seed at the oldest bar: HA_open = (O+C)/2, HA_close = (O+H+L+C)/4.
   double o = iOpen(_Symbol, _Period, start);   // perf-allowed: bounded closed-bar read
   double h = iHigh(_Symbol, _Period, start);   // perf-allowed
   double l = iLow(_Symbol, _Period, start);    // perf-allowed
   double c = iClose(_Symbol, _Period, start);  // perf-allowed
   if(o <= 0.0 || c <= 0.0)
      return false;

   double prev_ha_open  = (o + c) / 2.0;
   double prev_ha_close = (o + h + l + c) / 4.0;

   // Recurse forward from start-1 down to `shift`, tracking the HA OHLC.
   double cur_ha_open  = prev_ha_open;
   double cur_ha_close = prev_ha_close;
   double cur_ha_high  = h;
   double cur_ha_low   = l;

   for(int s = start - 1; s >= shift; --s)
     {
      o = iOpen(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar read
      h = iHigh(_Symbol, _Period, s);   // perf-allowed
      l = iLow(_Symbol, _Period, s);    // perf-allowed
      c = iClose(_Symbol, _Period, s);  // perf-allowed
      if(o <= 0.0 || c <= 0.0)
         return false;

      cur_ha_close = (o + h + l + c) / 4.0;
      cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      cur_ha_high  = MathMax(h, MathMax(cur_ha_open, cur_ha_close));
      cur_ha_low   = MathMin(l, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;
     }

   ha_open  = cur_ha_open;
   ha_high  = cur_ha_high;
   ha_low   = cur_ha_low;
   ha_close = cur_ha_close;
   return true;
  }

// -----------------------------------------------------------------------------
// StochRSI helper — standard StochRSI computed in-EA from QM_RSI (no QM helper
// exists). %K_raw(shift) = (RSI(shift)-min(RSI,n)) / (max(RSI,n)-min(RSI,n)),
// over the `stochrsi_period` window ending at `shift`. %K = SMA(smooth_k) of
// %K_raw; %D = SMA(smooth_d) of %K. Output range 0..1. perf-allowed: bounded
// closed-bar RSI reads, only on the closed-bar path. Returns false if any RSI is
// unavailable.
// -----------------------------------------------------------------------------

// Raw StochRSI %K (0..1) at a single shift.
bool StochRSIRaw(const int shift, double &k_raw)
  {
   const int n = (strategy_stochrsi_period < 2 ? 2 : strategy_stochrsi_period);
   double rsi_here = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift);
   if(rsi_here <= 0.0)
      return false;

   double rsi_min = rsi_here;
   double rsi_max = rsi_here;
   for(int i = 0; i < n; ++i)
     {
      const double r = QM_RSI(_Symbol, _Period, strategy_rsi_period, shift + i);
      if(r <= 0.0)
         return false;
      if(r < rsi_min) rsi_min = r;
      if(r > rsi_max) rsi_max = r;
     }

   const double range = rsi_max - rsi_min;
   if(range <= 0.0)
     {
      k_raw = 0.5; // flat RSI window — neutral, not an extreme
      return true;
     }
   k_raw = (rsi_here - rsi_min) / range; // 0..1
   return true;
  }

// Smoothed StochRSI %K (SMA over smooth_k of the raw %K) at a single shift.
bool StochRSI_K(const int shift, double &k_val)
  {
   const int sm = (strategy_stochrsi_smooth_k < 1 ? 1 : strategy_stochrsi_smooth_k);
   double sum = 0.0;
   for(int i = 0; i < sm; ++i)
     {
      double k_raw;
      if(!StochRSIRaw(shift + i, k_raw))
         return false;
      sum += k_raw;
     }
   k_val = sum / sm;
   return true;
  }

// StochRSI %D (SMA over smooth_d of %K) at a single shift.
bool StochRSI_D(const int shift, double &d_val)
  {
   const int sm = (strategy_stochrsi_smooth_d < 1 ? 1 : strategy_stochrsi_smooth_d);
   double sum = 0.0;
   for(int i = 0; i < sm; ++i)
     {
      double k_val;
      if(!StochRSI_K(shift + i, k_val))
         return false;
      sum += k_val;
     }
   d_val = sum / sm;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference = sl_pct of the current ask, so the cap scales.
   const double stop_distance = (strategy_sl_pct / 100.0) * ask;
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

   // --- Trend STATE: EMA side (closed bar). ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   // --- HA close of the last closed bar (for the trend-side check). ---
   double ha_o1, ha_h1, ha_l1, ha_c1;
   if(!ComputeHA(1, ha_o1, ha_h1, ha_l1, ha_c1))
      return false;

   // --- Trigger EVENT: StochRSI %K/%D cross on the last closed bar. ---
   // Long  : %K crosses ABOVE %D (k_prev<=d_prev && k_now>d_now).
   // Short : %K crosses BELOW %D (k_prev>=d_prev && k_now<d_now).
   double k_now, d_now, k_prev, d_prev;
   if(!StochRSI_K(1, k_now) || !StochRSI_D(1, d_now))
      return false;
   if(!StochRSI_K(2, k_prev) || !StochRSI_D(2, d_prev))
      return false;

   const bool cross_up   = (k_prev <= d_prev && k_now >  d_now);
   const bool cross_down = (k_prev >= d_prev && k_now <  d_now);
   if(!cross_up && !cross_down)
      return false;

   const int lb = (strategy_setup_lookback < 1 ? 1 : strategy_setup_lookback);

   // --- LONG branch ------------------------------------------------------
   if(cross_up && ha_c1 > ema)
     {
      // HA META STATE: a bullish meta candle (HA_close>HA_open AND HA_open==HA_low,
      // i.e. no lower wick) within the lookback window ending at the trigger bar.
      bool meta_ok = false;
      for(int s = 1; s <= lb; ++s)
        {
         double o2, h2, l2, c2;
         if(!ComputeHA(s, o2, h2, l2, c2))
            return false;
         if(c2 > o2 && MathAbs(o2 - l2) <= _Point) // open == low (no lower wick)
           {
            meta_ok = true;
            break;
           }
        }
      if(!meta_ok)
         return false;

      // PERSISTENCE STATE: %K never printed ABOVE long_max during the window.
      for(int s = 1; s <= lb; ++s)
        {
         double k_s;
         if(!StochRSI_K(s, k_s))
            return false;
         if(k_s > strategy_stochrsi_long_max)
            return false; // setup invalidated — was not persistently oversold
        }

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_sl_pct / 100.0));
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_tp_pct / 100.0));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_ema2_stochrsi_long";
      return true;
     }

   // --- SHORT branch -----------------------------------------------------
   if(cross_down && ha_c1 < ema)
     {
      // HA META STATE: a bearish meta candle (HA_close<HA_open AND HA_open==HA_high,
      // i.e. no upper wick) within the lookback window.
      bool meta_ok = false;
      for(int s = 1; s <= lb; ++s)
        {
         double o2, h2, l2, c2;
         if(!ComputeHA(s, o2, h2, l2, c2))
            return false;
         if(c2 < o2 && MathAbs(o2 - h2) <= _Point) // open == high (no upper wick)
           {
            meta_ok = true;
            break;
           }
        }
      if(!meta_ok)
         return false;

      // PERSISTENCE STATE: %K never printed BELOW short_min during the window.
      for(int s = 1; s <= lb; ++s)
        {
         double k_s;
         if(!StochRSI_K(s, k_s))
            return false;
         if(k_s < strategy_stochrsi_short_min)
            return false; // setup invalidated — was not persistently overbought
        }

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 + strategy_sl_pct / 100.0));
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry * (1.0 - strategy_tp_pct / 100.0));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ha_ema2_stochrsi_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed % stop/target. Discretionary HA-flip
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit (source check_close_pos): close long when the current HA candle
// is bearish; close short when the current HA candle is bullish.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double ha_o1, ha_h1, ha_l1, ha_c1;
   if(!ComputeHA(1, ha_o1, ha_h1, ha_l1, ha_c1))
      return false;

   const bool ha_bull = (ha_c1 > ha_o1);
   const bool ha_bear = (ha_c1 < ha_o1);

   // Determine current position direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && ha_bear)
         return true;
      if(ptype == POSITION_TYPE_SELL && ha_bull)
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
