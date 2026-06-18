#property strict
#property version   "5.0"
#property description "QM5_11339 tc20-h1-15-ema5-21-rsi21-candle-pattern — EMA(5/21) cross OR candle pattern, RSI(21) state (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11339 tc20-h1-15-ema5-21-rsi21-candle-pattern
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #15 (source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
// Card: artifacts/cards_approved/QM5_11339_tc20-h1-15-ema5-21-rsi21-candle-pattern.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   TRIGGER EVENT (exactly ONE of two — never required together, avoids the
//   two-cross-same-bar zero-trade trap):
//     (A) EMA(5) freshly crosses EMA(21) at shift 1 (cross at shift 1 vs 2), OR
//     (B) a directional candlestick pattern closes at shift 1:
//         Bullish: Engulfing (curr body engulfs prior body, gapless-safe via
//                  prior OPEN/CLOSE not gap) OR Hammer (long lower wick).
//         Bearish: mirror — Bearish Engulfing OR Inverted Hammer (long upper wick).
//   STATE filters (must hold on the same closed bar, NOT events):
//     - RSI(21) above 50 for longs / below 50 for shorts.
//     - EMA(5) currently above EMA(21) for longs / below for shorts
//       (direction agreement so a candle-pattern trigger still aligns with trend).
//   STOP : recent swing low (long) / swing high (short) over swing_lookback bars
//          (card primary). TP : RR multiple of the structural stop distance.
//   EXIT : EMA(5) crosses EMA(21) in the opposite direction, OR
//          RSI(21) crosses back through 50 against the position.
//   Spread guard : fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//                  spread blocks (> spread_cap_pips).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11339;
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
input int    strategy_ema_fast_period   = 5;      // fast EMA (cross + direction state)
input int    strategy_ema_slow_period   = 21;     // slow EMA (cross + direction state)
input int    strategy_rsi_period        = 21;     // RSI period (STATE filter)
input double strategy_rsi_mid_level     = 50.0;   // RSI midline for state + exit
input bool   strategy_use_candle        = true;   // enable candle-pattern trigger (B)
input bool   strategy_use_ema_cross     = true;   // enable EMA-cross trigger (A)
input double strategy_engulf_min_ratio  = 1.0;    // curr body must be >= this * prior body to engulf
input double strategy_hammer_wick_mult  = 2.0;    // long wick >= mult * body for hammer/inv-hammer
input double strategy_hammer_oppwick_pct = 10.0;  // opposite wick <= this % of range for hammer
input int    strategy_swing_lookback    = 10;     // bars for structural swing SL
input double strategy_swing_buffer_pips = 2.0;    // extra buffer beyond the swing extreme (pips)
input double strategy_tp_rr             = 2.0;    // take-profit = RR * structural stop distance
input double strategy_spread_cap_pips   = 20.0;   // skip only a genuinely wide spread (card: 20 pips)

// -----------------------------------------------------------------------------
// Candle-pattern helpers — gapless-safe geometry on a single CLOSED bar (shift).
// On .DWX CFDs open[s] == close[s+1] (gapless), so engulfing references prior
// OPEN/CLOSE, never a gap. All reads are single closed-bar reads (perf-allowed).
// -----------------------------------------------------------------------------

bool IsBullishEngulfing(const int s)
  {
   const double o0 = iOpen(_Symbol, _Period, s);    // perf-allowed: single closed-bar read
   const double c0 = iClose(_Symbol, _Period, s);   // perf-allowed: single closed-bar read
   const double o1 = iOpen(_Symbol, _Period, s + 1);// perf-allowed: single closed-bar read
   const double c1 = iClose(_Symbol, _Period, s + 1);// perf-allowed: single closed-bar read
   if(o0 <= 0.0 || c0 <= 0.0 || o1 <= 0.0 || c1 <= 0.0)
      return false;
   const bool curr_bull = (c0 > o0);
   const bool prev_bear = (c1 < o1);
   const double curr_body = MathAbs(c0 - o0);
   const double prev_body = MathAbs(c1 - o1);
   // Curr bullish body engulfs prior bearish body (open below prior close,
   // close above prior open), sized at least min_ratio of prior body.
   return(curr_bull && prev_bear &&
          o0 <= c1 && c0 > o1 &&
          curr_body >= strategy_engulf_min_ratio * prev_body);
  }

bool IsBearishEngulfing(const int s)
  {
   const double o0 = iOpen(_Symbol, _Period, s);
   const double c0 = iClose(_Symbol, _Period, s);
   const double o1 = iOpen(_Symbol, _Period, s + 1);
   const double c1 = iClose(_Symbol, _Period, s + 1);
   if(o0 <= 0.0 || c0 <= 0.0 || o1 <= 0.0 || c1 <= 0.0)
      return false;
   const bool curr_bear = (c0 < o0);
   const bool prev_bull = (c1 > o1);
   const double curr_body = MathAbs(c0 - o0);
   const double prev_body = MathAbs(c1 - o1);
   return(curr_bear && prev_bull &&
          o0 >= c1 && c0 < o1 &&
          curr_body >= strategy_engulf_min_ratio * prev_body);
  }

bool IsHammer(const int s)
  {
   const double o0 = iOpen(_Symbol, _Period, s);
   const double h0 = iHigh(_Symbol, _Period, s);
   const double l0 = iLow(_Symbol, _Period, s);
   const double c0 = iClose(_Symbol, _Period, s);
   if(o0 <= 0.0 || h0 <= 0.0 || l0 <= 0.0 || c0 <= 0.0)
      return false;
   const double range = h0 - l0;
   if(range <= 0.0)
      return false;
   const double body  = MathAbs(c0 - o0);
   if(body <= 0.0)
      return false;
   const double lower_wick = MathMin(o0, c0) - l0;
   const double upper_wick = h0 - MathMax(o0, c0);
   // Bullish close, long lower wick, tiny upper wick.
   return(c0 > o0 &&
          lower_wick >= strategy_hammer_wick_mult * body &&
          upper_wick <= (strategy_hammer_oppwick_pct / 100.0) * range);
  }

bool IsInvertedHammer(const int s)
  {
   const double o0 = iOpen(_Symbol, _Period, s);
   const double h0 = iHigh(_Symbol, _Period, s);
   const double l0 = iLow(_Symbol, _Period, s);
   const double c0 = iClose(_Symbol, _Period, s);
   if(o0 <= 0.0 || h0 <= 0.0 || l0 <= 0.0 || c0 <= 0.0)
      return false;
   const double range = h0 - l0;
   if(range <= 0.0)
      return false;
   const double body  = MathAbs(c0 - o0);
   if(body <= 0.0)
      return false;
   const double lower_wick = MathMin(o0, c0) - l0;
   const double upper_wick = h0 - MathMax(o0, c0);
   // Bearish close, long upper wick, tiny lower wick (shooting-star geometry).
   return(c0 < o0 &&
          upper_wick >= strategy_hammer_wick_mult * body &&
          lower_wick <= (strategy_hammer_oppwick_pct / 100.0) * range);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (ask>bid AND wider than the cap) blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing quote
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap <= 0.0)
      return false;
   const double spread = ask - bid;
   // Zero/negative modeled spread (the .DWX tester norm) passes; only a real
   // wide spread blocks.
   if(ask > bid && spread > cap)
      return true;
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (single closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA values (closed bars) for cross EVENT + direction STATE ---
   const double ema_f1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_s1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_f2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_s2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_f1 <= 0.0 || ema_s1 <= 0.0 || ema_f2 <= 0.0 || ema_s2 <= 0.0)
      return false;

   // --- RSI STATE ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   // --- Direction STATE (EMA stack now) ---
   const bool stack_long  = (ema_f1 > ema_s1);
   const bool stack_short = (ema_f1 < ema_s1);

   // --- TRIGGER EVENT (A): fresh EMA cross at shift 1 ---
   const bool cross_up   = (ema_f2 <= ema_s2 && ema_f1 > ema_s1);
   const bool cross_down = (ema_f2 >= ema_s2 && ema_f1 < ema_s1);

   // --- TRIGGER EVENT (B): candle pattern at shift 1 ---
   const bool candle_long  = strategy_use_candle && (IsBullishEngulfing(1) || IsHammer(1));
   const bool candle_short = strategy_use_candle && (IsBearishEngulfing(1) || IsInvertedHammer(1));

   const bool trig_long  = (strategy_use_ema_cross && cross_up)   || candle_long;
   const bool trig_short = (strategy_use_ema_cross && cross_down) || candle_short;

   // --- Compose: ONE trigger EVENT + all STATE filters in agreement ---
   bool go_long  = trig_long  && stack_long  && (rsi1 > strategy_rsi_mid_level);
   bool go_short = trig_short && stack_short && (rsi1 < strategy_rsi_mid_level);

   if(!go_long && !go_short)
      return false;
   // If somehow both fire on the same bar (conflicting candles), stand aside.
   if(go_long && go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   // --- Entry price + structural stop (swing low/high) ---
   const double entry = SymbolInfoDouble(_Symbol, side == QM_BUY ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_swing_buffer_pips);
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;
   // Push the structural stop out by the pip buffer (below swing low / above high).
   if(side == QM_BUY)
      sl = QM_StopRulesNormalizePrice(_Symbol, sl - buffer);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, sl + buffer);

   // Stop must sit on the correct side of entry for a valid risk distance.
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "tc15_long" : "tc15_short";
   return true;
  }

// No active management beyond the fixed structural stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite EMA(5/21) cross OR RSI(21) crossing back through 50
// against the open position's direction.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open position's direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double ema_f1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_s1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_f2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_s2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_f1 <= 0.0 || ema_s1 <= 0.0 || ema_f2 <= 0.0 || ema_s2 <= 0.0)
      return false;

   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi1 <= 0.0 || rsi2 <= 0.0)
      return false;

   if(is_long)
     {
      const bool cross_down = (ema_f2 >= ema_s2 && ema_f1 < ema_s1);
      const bool rsi_fell   = (rsi2 >= strategy_rsi_mid_level && rsi1 < strategy_rsi_mid_level);
      return(cross_down || rsi_fell);
     }
   // is_short
   const bool cross_up   = (ema_f2 <= ema_s2 && ema_f1 > ema_s1);
   const bool rsi_rose   = (rsi2 <= strategy_rsi_mid_level && rsi1 > strategy_rsi_mid_level);
   return(cross_up || rsi_rose);
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
