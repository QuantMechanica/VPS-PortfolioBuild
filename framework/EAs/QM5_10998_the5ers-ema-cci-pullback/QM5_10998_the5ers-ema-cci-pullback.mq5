#property strict
#property version   "5.0"
#property description "QM5_10998 the5ers-ema-cci-pullback — EMA20/50 + CCI pullback continuation (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10998 the5ers-ema-cci-pullback
// -----------------------------------------------------------------------------
// Source: The5ers "How to Take advantage of The Pullback Crossover System in
//         Forex" (https://the5ers.com/pullback-crossover/), GBP/USD H4 example.
// Card: artifacts/cards_approved/QM5_10998_the5ers-ema-cci-pullback.md
//       (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads at shift 1):
//   Trend STATE   : EMA(fast) vs EMA(slow) (long: fast>slow, short: fast<slow).
//   Separation    : |EMA(fast)-EMA(slow)| >= sep_atr_mult * ATR  (skip flat).
//   Vol floor     : ATR(14) >= 20th percentile of the last vol_pctile_lookback
//                   closed ATR values (skip dead-vol bars).
//   CCI EVENT     : long needs CCI <= -cci_threshold ; short CCI >= +cci_threshold.
//   Zone touch    : the just-closed bar touched the EMA20/50 zone
//                   (low<=zone_high && high>=zone_low).
//   Close-back    : long closes above EMA(fast); short closes below EMA(fast).
//   Stop          : long  = lowest_low(swing_lookback) - sl_atr_buffer*ATR
//                   short = highest_high(swing_lookback) + sl_atr_buffer*ATR.
//   Take profit   : the CLOSER (to entry) of tp_rr*R and the structure target
//                   (recent struct_lookback-bar high for longs / low for shorts).
//   Time stop     : close after time_stop_bars H4 bars if neither SL nor TP fired.
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_stop of the
//                   stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10998;
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
input int    strategy_ema_fast_period   = 20;     // pullback-zone fast EMA
input int    strategy_ema_slow_period   = 50;     // pullback-zone slow EMA
input int    strategy_cci_period        = 20;     // CCI lookback period
input double strategy_cci_threshold     = 100.0;  // |CCI| trigger level
input int    strategy_atr_period        = 14;     // ATR period (filter / stop buffer)
input double strategy_sep_atr_mult      = 0.25;   // min EMA separation in ATR units
input int    strategy_swing_lookback    = 5;      // swing low/high lookback for SL
input double strategy_sl_atr_buffer     = 0.25;   // SL extra buffer in ATR units
input double strategy_tp_rr             = 1.5;    // primary TP as R multiple
input int    strategy_struct_lookback   = 20;     // structure-target high/low lookback
input int    strategy_time_stop_bars    = 12;     // close after N H4 bars
input int    strategy_vol_pctile_lookback = 120;  // bars for ATR percentile floor
input double strategy_vol_pctile        = 20.0;   // skip if ATR below this percentile
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_buffer * atr_value + atr_value; // ~swing+buffer scale
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// ATR(14) percentile floor over the last `lookback` closed bars. Returns true if
// the current ATR is at/above the requested percentile (i.e. tradeable vol).
bool ATRAbovePercentileFloor(const double atr_now)
  {
   const int lookback = strategy_vol_pctile_lookback;
   if(lookback < 5)
      return true;
   int below = 0;
   int counted = 0;
   for(int s = 1; s <= lookback; ++s)
     {
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, s);
      if(a <= 0.0)
         continue;
      counted++;
      if(a < atr_now)
         below++;
     }
   if(counted <= 0)
      return true;
   const double pct = (double)below / (double)counted * 100.0;
   return (pct >= strategy_vol_pctile);
  }

// Entry: EMA20/50 trend + CCI pullback + EMA-zone touch + close-back through EMA20.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Filter: EMA separation must exceed sep_atr_mult * ATR (skip flat) ---
   if(MathAbs(ema_fast - ema_slow) < strategy_sep_atr_mult * atr_value)
      return false;

   // --- Filter: ATR vol-percentile floor ---
   if(!ATRAbovePercentileFloor(atr_value))
      return false;

   // Closed-bar OHLC reads (perf-allowed: single-shift reads on the closed-bar path).
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed
   const double low1  = iLow(_Symbol, _Period, 1);   // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1);// perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const double cci1 = QM_CCI(_Symbol, _Period, strategy_cci_period, 1, PRICE_TYPICAL);

   // EMA pullback zone from the closed bar's EMA values.
   const double zone_low  = MathMin(ema_fast, ema_slow);
   const double zone_high = MathMax(ema_fast, ema_slow);
   const bool touched_zone = (low1 <= zone_high && high1 >= zone_low);
   if(!touched_zone)
      return false;

   QM_OrderType side;
   bool is_long = false;
   if(ema_fast > ema_slow && cci1 <= -strategy_cci_threshold && close1 > ema_fast)
     {
      side = QM_BUY;
      is_long = true;
     }
   else if(ema_fast < ema_slow && cci1 >= strategy_cci_threshold && close1 < ema_fast)
     {
      side = QM_SELL;
      is_long = false;
     }
   else
      return false;

   // --- Entry / Stop / Target ---
   const double entry = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Structure swing extreme over swing_lookback closed bars (shifts 1..N).
   double swing_low  = low1;
   double swing_high = high1;
   for(int s = 1; s <= strategy_swing_lookback; ++s)
     {
      const double hh = iHigh(_Symbol, _Period, s); // perf-allowed
      const double ll = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hh > swing_high) swing_high = hh;
      if(ll > 0.0 && ll < swing_low) swing_low = ll;
     }

   double sl;
   if(is_long)
      sl = QM_StopRulesNormalizePrice(_Symbol, swing_low - strategy_sl_atr_buffer * atr_value);
   else
      sl = QM_StopRulesNormalizePrice(_Symbol, swing_high + strategy_sl_atr_buffer * atr_value);
   if(sl <= 0.0)
      return false;

   const double risk_distance = MathAbs(entry - sl);
   if(risk_distance <= 0.0)
      return false;

   // Primary TP = tp_rr * R.
   const double tp_rr_price = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp_rr_price <= 0.0)
      return false;

   // Structure target = recent struct_lookback high (long) / low (short).
   double struct_hi = high1;
   double struct_lo = low1;
   for(int s = 1; s <= strategy_struct_lookback; ++s)
     {
      const double hh = iHigh(_Symbol, _Period, s); // perf-allowed
      const double ll = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hh > struct_hi) struct_hi = hh;
      if(ll > 0.0 && ll < struct_lo) struct_lo = ll;
     }

   // Closer of (tp_rr, structure target) to the entry — conservative per card.
   double tp;
   if(is_long)
     {
      const double struct_tp = struct_hi;
      // both should be above entry; pick the nearer that is still beyond entry.
      double cand = tp_rr_price;
      if(struct_tp > entry && struct_tp < cand)
         cand = struct_tp;
      tp = cand;
     }
   else
     {
      const double struct_tp = struct_lo;
      double cand = tp_rr_price;
      if(struct_tp > 0.0 && struct_tp < entry && struct_tp > cand)
         cand = struct_tp;
      tp = cand;
     }
   tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = is_long ? "ema_cci_pullback_long" : "ema_cci_pullback_short";
   return true;
  }

// No active SL/TP modification — the fixed structural stop and TP do the work.
// Time stop lives in Strategy_ExitSignal (O(1) bar-count check).
void Strategy_ManageOpenPosition()
  {
  }

// Time stop: close after strategy_time_stop_bars H4 bars have elapsed since the
// position opened. O(1) — compares the open time to the current bar-open time
// in seconds, no history scan.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int tf_seconds = PeriodSeconds(_Period);
   if(tf_seconds <= 0)
      return false;
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed: current bar open

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0)
         continue;
      const long bars_held = (long)((bar_open - open_time) / tf_seconds);
      if(bars_held >= strategy_time_stop_bars)
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
