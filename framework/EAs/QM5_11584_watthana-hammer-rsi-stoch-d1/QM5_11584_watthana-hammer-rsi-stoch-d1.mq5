#property strict
#property version   "5.0"
#property description "QM5_11584 watthana-hammer-rsi-stoch-d1 — Hammer candlestick + RSI + Stochastic confluence (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11584 watthana-hammer-rsi-stoch-d1
// -----------------------------------------------------------------------------
// Source: Watthana Pongsena et al., "Developing A Forex Expert Advisor Based on
//   Japanese Candlestick Patterns and Technical Trading Strategies", IJTEF
//   Vol.9 No.6 (2018), DOI:10.18178/ijtef.2018.9.6.622.
// Card: artifacts/cards_approved/QM5_11584_watthana-hammer-rsi-stoch-d1.md
//   (g0_status APPROVED).
//
// Mechanics (bidirectional reversal, closed-bar reads at shift 1, D1):
//   Trigger EVENT : a completed long-shadow candlestick on the last closed D1
//                   bar (shift 1) — a single discrete event per bar.
//                     body  = |close - open|
//                     range = high - low
//                     US    = high - max(open, close)   (upper shadow)
//                     LS    = min(open, close) - low     (lower shadow)
//                     Hammer  (long lower) : LS >= shadow_mult*body AND
//                                            US < 0.1*range AND body < body_ratio*range
//                     Inv.Hammer (long upper): US >= shadow_mult*body AND
//                                            LS < 0.1*range AND body < body_ratio*range
//                   Per the card, EITHER long-shadow shape is a valid reversal
//                   candle; the OSCILLATOR zone (not the shadow direction) sets
//                   the trade direction.
//   RSI  STATE    : RSI(period) at shift 1 in the OB/OS zone (confirm level, no
//                   cross). LONG : RSI < oversold ; SHORT : RSI > overbought.
//   Stoch STATE   : Stochastic %K (Main) at shift 1 in the OB/OS zone (confirm).
//                   LONG : K < stoch_os ; SHORT : K > stoch_ob.
//   Entry         : LONG  = pattern AND rsi<oversold AND stoch<stoch_os
//                   SHORT = pattern AND rsi>overbought AND stoch>stoch_ob
//   Stop / Target : SL = sl_atr_mult * ATR(14) ; TP = sl_atr_mult * ATR * tp_rr.
//   Exit          : fixed ATR SL/TP carries the trade. In addition, the card's
//                   "always-in-market" opposite-extreme exit closes the open
//                   position when the opposite oscillator extreme confirms
//                   (optionally requiring an opposite-extreme pattern bar too).
//                   Controlled by strategy_always_in_market.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//   Friday        : framework Friday-close handles "no Friday entry".
//
// Two-cross trap avoided: the candlestick pattern bar is the ONLY trigger EVENT;
// RSI and Stochastic are read as STATES (current level in zone), never as
// same-bar cross events. One discrete event per closed bar.
//
// Symbol porting: card target_symbols are all FX majors present in
// dwx_symbol_matrix.csv (EURUSD/GBPUSD/USDJPY/USDCHF/AUDUSD .DWX) — no porting
// required.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11584;
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
input double strategy_shadow_mult       = 2.0;    // long shadow >= mult * body
input double strategy_body_ratio        = 0.30;   // body < ratio * range (small body)
input int    strategy_rsi_period        = 14;     // RSI period
input double strategy_rsi_os            = 30.0;   // RSI oversold (long confirm)
input double strategy_rsi_ob            = 70.0;   // RSI overbought (short confirm)
input int    strategy_stoch_k           = 14;     // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // Stochastic oversold (long confirm)
input double strategy_stoch_ob          = 80.0;   // Stochastic overbought (short confirm)
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 1.5;    // take-profit R-multiple of the stop
input bool   strategy_always_in_market  = true;   // close on opposite oscillator extreme
input bool   strategy_exit_needs_pattern = false; // require opposite pattern for the exit too
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal: detect a completed long-shadow candlestick on the last closed bar
// (shift 1). Returns true if EITHER a Hammer (long lower shadow) OR an Inverted
// Hammer (long upper shadow) formed, per the card geometry. Pure closed-bar
// OHLC arithmetic (single reads = perf-allowed).
// -----------------------------------------------------------------------------
bool LongShadowPattern()
  {
   const double o = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double h = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double l = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;

   const double range = h - l;
   if(range <= 0.0)
      return false;

   const double body = MathAbs(c - o);
   if(body <= 0.0)
      return false; // doji / no body — card requires a defined small body

   if(body >= strategy_body_ratio * range)
      return false; // body too large — not a long-shadow rejection candle

   const double upper_shadow = h - MathMax(o, c);
   const double lower_shadow = MathMin(o, c) - l;
   const double need         = strategy_shadow_mult * body;

   // Hammer / Hanging Man: long lower shadow, negligible upper shadow.
   const bool hammer = (lower_shadow >= need) && (upper_shadow < 0.1 * range);
   // Inverted Hammer / Shooting Star: long upper shadow, negligible lower shadow.
   const bool inverted = (upper_shadow >= need) && (lower_shadow < 0.1 * range);

   return (hammer || inverted);
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
   if(!LongShadowPattern())
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
   if(rsi < strategy_rsi_os && stoch_k < strategy_stoch_os)
     {
      side   = QM_BUY;   // oversold extreme + rejection candle → long reversal
      reason = "hammer_rsi_stoch_long";
     }
   else if(rsi > strategy_rsi_ob && stoch_k > strategy_stoch_ob)
     {
      side   = QM_SELL;  // overbought extreme + rejection candle → short reversal
      reason = "hammer_rsi_stoch_short";
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

// Card "always-in-market" exit: close the open position when the OPPOSITE
// oscillator extreme confirms. Optionally require an opposite-extreme pattern
// bar too (strategy_exit_needs_pattern). Disabled when always_in_market=false
// (the fixed ATR SL/TP then carries the trade alone).
bool Strategy_ExitSignal()
  {
   if(!strategy_always_in_market)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   if(strategy_exit_needs_pattern && !LongShadowPattern())
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;
   const double stoch_k = QM_Stoch_K(_Symbol, _Period,
                                     strategy_stoch_k, strategy_stoch_d,
                                     strategy_stoch_slow, 1);
   if(stoch_k <= 0.0)
      return false;

   // Exit a long when overbought extreme confirms; exit a short when oversold.
   const bool overbought = (rsi > strategy_rsi_ob && stoch_k > strategy_stoch_ob);
   const bool oversold   = (rsi < strategy_rsi_os && stoch_k < strategy_stoch_os);
   if(!overbought && !oversold)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && overbought)
         return true;
      if(pos_type == POSITION_TYPE_SELL && oversold)
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
