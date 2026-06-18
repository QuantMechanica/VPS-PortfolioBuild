#property strict
#property version   "5.0"
#property description "QM5_11491 watthana-candlestick-rsi-stochastic-h4 — Candlestick reversal + RSI + Stochastic confluence (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11491 watthana-candlestick-rsi-stochastic-h4
// -----------------------------------------------------------------------------
// Source: Panichkul, Kerdprasop, et al., "Developing A Forex Expert Advisor
//   Based on Japanese Candlestick Patterns and Technical Trading Strategies",
//   IJTEF Vol.9 No.6 (2018), DOI:10.18178/ijtef.2018.9.6.622.
// Card: artifacts/cards_approved/QM5_11491_watthana-candlestick-rsi-stochastic-h4.md
//   (g0_status APPROVED).
//
// Mechanics (bidirectional reversal, closed-bar reads at shift 1):
//   Trigger EVENT : a completed long-shadow candlestick pattern on the last
//                   closed H4 bar (shift 1).
//                     LONG  pattern: Hammer OR Inverted Hammer
//                       body = |close - open|
//                       US   = high - max(open, close)
//                       LS   = min(open, close) - low
//                       Hammer       : LS >= shadow_mult * body  AND body > 0
//                       Inv. Hammer  : US >= shadow_mult * body  AND body > 0
//                     SHORT pattern: Hanging Man OR Shooting Star
//                       Hanging Man  : LS >= shadow_mult * body  AND body > 0
//                       Shooting Star: US >= shadow_mult * body  AND body > 0
//   Trend STATE   : EMA(ema_period) slope over `ema_slope_bars` closed bars.
//                     LONG  requires a declining EMA (down-trend exhaustion).
//                     SHORT requires a rising  EMA (up-trend   exhaustion).
//   RSI STATE     : RSI(period) at shift 1 in the OB/OS zone (confirm, no cross).
//                     LONG : RSI < rsi_os ; SHORT : RSI > rsi_ob.
//   Stoch STATE   : Stochastic %K (Main) at shift 1 in the OB/OS zone (confirm).
//                     LONG : K < stoch_os ; SHORT : K > stoch_ob.
//   Stop / Target : SL = sl_atr_mult * ATR ; TP = sl_atr_mult * ATR * tp_rr.
//   Exit          : fixed ATR SL/TP; an opposite-direction pattern+confluence
//                   closes the open position (paper's "opposite signal" exit).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX
//                   zero modeled spread).
//   Friday        : framework Friday-close handles "no Friday entry".
//
// Two-cross trap avoided: the candlestick pattern bar is the ONLY trigger EVENT;
// RSI and Stochastic are read as STATES (current level in zone), never as
// same-bar cross events. One discrete event per closed bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11491;
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
input int    strategy_ema_period        = 50;     // trend EMA period
input int    strategy_ema_slope_bars    = 5;      // bars back for EMA slope state
input double strategy_shadow_mult       = 2.0;    // long shadow >= mult * body
input int    strategy_rsi_period        = 14;     // RSI period
input double strategy_rsi_os            = 30.0;   // RSI oversold (long confirm)
input double strategy_rsi_ob            = 70.0;   // RSI overbought (short confirm)
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // Stochastic oversold (long confirm)
input double strategy_stoch_ob          = 80.0;   // Stochastic overbought (short confirm)
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 1.5;    // take-profit R-multiple of the stop
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: classify the completed pattern on the last closed bar (shift 1).
// Returns +1 = bullish reversal pattern, -1 = bearish reversal pattern, 0 = none.
// Pure closed-bar OHLC arithmetic (single reads = perf-allowed).
// -----------------------------------------------------------------------------
int PatternDirection()
  {
   const double o = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double h = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double l = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return 0;

   const double body = MathAbs(c - o);
   if(body <= 0.0)
      return 0; // doji / no body — card requires body > 0

   const double upper_shadow = h - MathMax(o, c);
   const double lower_shadow = MathMin(o, c) - l;
   const double need         = strategy_shadow_mult * body;

   // Bullish reversal: long lower shadow (Hammer) OR long upper shadow (Inverted Hammer).
   const bool bullish = (lower_shadow >= need) || (upper_shadow >= need);
   // Bearish reversal: Hanging Man (long lower) OR Shooting Star (long upper).
   const bool bearish = (lower_shadow >= need) || (upper_shadow >= need);

   // The pattern geometry is shared; direction is resolved by the trend STATE in
   // Strategy_EntrySignal. Here we only confirm a long-shadow rejection candle
   // exists. Return +1 if a qualifying single-shadow pattern formed, else 0.
   if(bullish || bearish)
      return 1;
   return 0;
  }

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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Bidirectional entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: a completed long-shadow candlestick on the closed bar ---
   if(PatternDirection() == 0)
      return false;

   // --- Trend STATE: EMA slope over the lookback window (closed bars) ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_back = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_back <= 0.0)
      return false;
   const bool trend_down = (ema_now < ema_back); // exhaustion → look for LONG reversal
   const bool trend_up   = (ema_now > ema_back); // exhaustion → look for SHORT reversal
   if(!trend_down && !trend_up)
      return false;

   // --- Confirming STATES: RSI + Stochastic %K levels at shift 1 (no cross) ---
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;
   const double stoch_k = QM_Stoch_K(_Symbol, _Period,
                                     strategy_stoch_k, strategy_stoch_d,
                                     strategy_stoch_slow, 1);
   if(stoch_k <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType side;
   string reason;
   if(trend_down && rsi < strategy_rsi_os && stoch_k < strategy_stoch_os)
     {
      side   = QM_BUY;
      reason = "candle_rsi_stoch_long";
     }
   else if(trend_up && rsi > strategy_rsi_ob && stoch_k > strategy_stoch_ob)
     {
      side   = QM_SELL;
      reason = "candle_rsi_stoch_short";
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = reason;
   return true;
  }

// No active trade management; the fixed ATR SL/TP carries the trade.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite-signal exit (paper's "exit when opposite signal fires"): close the
// open position if a confluent reversal forms against the current direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(PatternDirection() == 0)
      return false;

   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_back = QM_EMA(_Symbol, _Period, strategy_ema_period,
                                  1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_back <= 0.0)
      return false;
   const bool trend_down = (ema_now < ema_back);
   const bool trend_up   = (ema_now > ema_back);

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;
   const double stoch_k = QM_Stoch_K(_Symbol, _Period,
                                     strategy_stoch_k, strategy_stoch_d,
                                     strategy_stoch_slow, 1);
   if(stoch_k <= 0.0)
      return false;

   const bool long_signal  = (trend_down && rsi < strategy_rsi_os && stoch_k < strategy_stoch_os);
   const bool short_signal = (trend_up   && rsi > strategy_rsi_ob && stoch_k > strategy_stoch_ob);
   if(!long_signal && !short_signal)
      return false;

   // Determine the open side; close only on a genuinely opposite confluent signal.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && short_signal)
         return true;
      if(pos_type == POSITION_TYPE_SELL && long_signal)
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
