#property strict
#property version   "5.0"
#property description "QM5_11389 munzer-d1-ema34-sma150-double-cci — D1 EMA34/SMA150 trend + double-CCI + Stoch (FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11389 munzer-d1-ema34-sma150-double-cci
// -----------------------------------------------------------------------------
// Source: Mohammed Munzer "Complex Trading System #7", forex-strategies-revealed.com
//   compilation. Card: artifacts/cards_approved/QM5_11389_munzer-d1-ema34-sma150-
//   double-cci.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1):
//   Trend STATE      : EMA(34) vs SMA(150) position fixes direction.
//   No-trade zone    : price (close[1]) BETWEEN EMA34 and SMA150 -> skip.
//   Trend-side STATE : close[1] above EMA34 (long) / below EMA34 (short).
//   CCI STATE        : slow CCI(50) sign agrees with direction.
//   Trigger EVENT    : fast CCI(14) crosses zero in the trend direction on the
//                      last closed bar (shift 2 -> shift 1). This is the SINGLE
//                      event; CCI(50) sign, EMA/SMA stack, Stoch level are all
//                      STATES (never require two fresh crosses on one bar).
//   Stoch STATE      : Stoch %K(5,3,3) not overbought (<80) for long / not
//                      oversold (>20) for short.
//   Entry            : market order on the confirming closed bar (see OQ#1).
//   Stop             : signal candle opposite extreme +/- sl_buffer_pips,
//                      distance capped at sl_max_pips (D1 candles can be large).
//   Take profit      : entry +/- tp_atr_mult * ATR(14).
//   Breakeven        : move SL to BE once price has advanced +1 * ATR(14).
//   Spread guard     : fail-OPEN on .DWX zero modeled spread; block only a
//                      genuinely wide spread > spread_pct_of_stop of stop dist.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11389;
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
input int    strategy_ema_period         = 34;     // fast trend EMA
input int    strategy_sma_period         = 150;    // slow trend SMA
input int    strategy_cci_slow_period    = 50;     // slow CCI (state filter)
input int    strategy_cci_fast_period    = 14;     // fast CCI (zero-cross trigger event)
input int    strategy_stoch_k            = 5;      // Stochastic %K period
input int    strategy_stoch_d            = 3;      // Stochastic %D period
input int    strategy_stoch_slow         = 3;      // Stochastic slowing
input double strategy_stoch_ob           = 80.0;   // overbought ceiling (block longs above)
input double strategy_stoch_os           = 20.0;   // oversold floor (block shorts below)
input int    strategy_atr_period         = 14;     // ATR period (TP + breakeven)
input double strategy_tp_atr_mult        = 2.0;    // take-profit distance = mult * ATR
input int    strategy_sl_buffer_pips     = 10;     // stop placed this many pips beyond candle extreme
input int    strategy_sl_max_pips        = 60;     // hard cap on stop distance (D1)
input double strategy_be_atr_mult        = 1.0;    // move SL to breakeven once +mult*ATR in profit
input double strategy_spread_pct_of_stop = 25.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance for the spread cap: the sl_max_pips ceiling.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
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

   // --- Trend STATE: EMA(34) vs SMA(150) on the last closed bar ---
   const double ema  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double sma  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   if(ema <= 0.0 || sma <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: signal-candle extreme
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: signal-candle extreme
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const bool uptrend   = (ema > sma);
   const bool downtrend = (ema < sma);
   if(!uptrend && !downtrend)
      return false; // EMA == SMA: no defined trend

   // --- No-trade zone: price BETWEEN the two MAs ---
   // Long structure but price below SMA, or short structure but price above SMA.
   if(uptrend && close1 < sma)
      return false;
   if(downtrend && close1 > sma)
      return false;

   // --- CCI fast (14) zero-cross trigger EVENT (shift 2 -> shift 1) ---
   const double cci_fast_now  = QM_CCI(_Symbol, _Period, strategy_cci_fast_period, 1);
   const double cci_fast_prev = QM_CCI(_Symbol, _Period, strategy_cci_fast_period, 2);
   // --- CCI slow (50) sign STATE ---
   const double cci_slow_now  = QM_CCI(_Symbol, _Period, strategy_cci_slow_period, 1);
   // --- Stoch %K level STATE ---
   const double stoch_k = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k,
                                     strategy_stoch_d, strategy_stoch_slow, 1);

   const bool fast_crossed_up   = (cci_fast_prev <= 0.0 && cci_fast_now > 0.0);
   const bool fast_crossed_down = (cci_fast_prev >= 0.0 && cci_fast_now < 0.0);

   bool go_long  = false;
   bool go_short = false;

   if(uptrend &&
      close1 > ema &&                 // price confirms trend side
      fast_crossed_up &&              // single EVENT: fast CCI crosses zero up
      cci_slow_now > 0.0 &&           // slow CCI agrees (STATE)
      stoch_k < strategy_stoch_ob)    // not overbought (STATE)
      go_long = true;

   if(downtrend &&
      close1 < ema &&
      fast_crossed_down &&
      cci_slow_now < 0.0 &&
      stoch_k > strategy_stoch_os)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   // --- Entry price (market) ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   // --- ATR for the take-profit distance ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double max_sl = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(buffer <= 0.0 || max_sl <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = ask;
      // SL = signal candle low - buffer; cap distance at sl_max_pips.
      double sl = low1 - buffer;
      if(entry - sl > max_sl)
         sl = entry - max_sl;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "munzer_cci_long";
      return true;
     }

   // go_short
   const double entry = bid;
   // SL = signal candle high + buffer; cap distance at sl_max_pips.
   double sl = high1 + buffer;
   if(sl - entry > max_sl)
      sl = entry + max_sl;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   if(sl <= entry)
      return false;

   const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
   if(tp <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "munzer_cci_short";
   return true;
  }

// Trade management: move SL to breakeven once price has advanced +be_atr_mult*ATR.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Convert the +be_atr_mult*ATR trigger distance into PIPS — QM_TM_MoveToBreakEven
   // takes a pip count and converts to price internally (pip-factor aware).
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   const int trigger_pips = (int)MathRound((strategy_be_atr_mult * atr_value) /
                                           (point * pip_factor));
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      // trigger_pips: advance to BE after +be_atr_mult*ATR; buffer 0 pips.
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 0);
     }
  }

// No discretionary exit beyond SL/TP and the breakeven shift.
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
