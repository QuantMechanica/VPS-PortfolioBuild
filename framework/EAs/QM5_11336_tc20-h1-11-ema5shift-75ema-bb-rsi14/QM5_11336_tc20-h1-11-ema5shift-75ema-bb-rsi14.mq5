#property strict
#property version   "5.0"
#property description "QM5_11336 tc20-h1-11-ema5shift-75ema-bb-rsi14 — EMA5(shift) x EMA75 cross + BB-mid + RSI14 (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11336 tc20-h1-11-ema5shift-75ema-bb-rsi14
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #11. Card: artifacts/cards_approved/
//         QM5_11336_tc20-h1-11-ema5shift-75ema-bb-rsi14.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; mirror long/short):
//   Trigger EVENT : the shifted EMA(5) [forward ma_shift = ema5_shift bars]
//                   crosses the EMA(75). A shifted MA is read by adding the
//                   ma_shift to the bar offset: shifted-EMA5 on the last closed
//                   bar == QM_EMA(period=5, shift = 1 + ema5_shift). Cross =
//                   shifted-EMA5 vs EMA75 changing side between bar 2 and bar 1.
//                   This is the ONE event (avoids the two-cross-same-bar
//                   zero-trade trap).
//   Trend STATE   : close[1] above EMA75 (long) / below EMA75 (short).
//   Band  STATE   : close[1] above BB(20,2) middle (long) / below (short).
//   Momentum STATE: RSI(14) above rsi_level (long) / below rsi_level (short).
//   Stop          : 2 pips beyond EMA75[1] (card P2 simplification), capped at
//                   atr_sl_cap_mult * ATR. Never tighter than a small ATR floor.
//   Take profit   : tp_rr * stop distance (card: 1x or 2x SL distance).
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_stop of
//                   the stop distance (fail-OPEN on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11336;
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
input int    strategy_ema_fast_period    = 5;      // fast EMA period
input int    strategy_ema_fast_shift     = 5;      // forward ma_shift of the fast EMA (the "5EMA shift=5")
input int    strategy_ema_slow_period    = 75;     // slow EMA period (trend level)
input int    strategy_bb_period          = 20;     // Bollinger period (middle = SMA20)
input double strategy_bb_deviation       = 2.0;    // Bollinger deviation (band state filter)
input int    strategy_rsi_period         = 14;     // RSI period
input double strategy_rsi_level          = 50.0;   // momentum threshold
input double strategy_sl_buffer_pips     = 2.0;    // SL = this many pips beyond EMA75
input int    strategy_atr_period         = 14;     // ATR period for the SL cap
input double strategy_atr_sl_cap_mult    = 1.5;    // SL distance capped at this * ATR
input double strategy_tp_rr              = 2.0;    // TP = this * SL distance (1x or 2x per card)
input double strategy_spread_pct_of_stop = 20.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, (int)strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_sl_cap_mult * atr_value;
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

   // A shifted EMA(period, ma_shift) read at bar offset b equals the un-shifted
   // EMA read at bar offset b + ma_shift. So the shifted fast EMA on the last
   // two closed bars is read at shift 1+ema_shift and 2+ema_shift.
   const int s_fast_now  = 1 + strategy_ema_fast_shift;
   const int s_fast_prev = 2 + strategy_ema_fast_shift;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s_fast_now);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s_fast_prev);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(fast_now <= 0.0 || fast_prev <= 0.0 || slow_now <= 0.0 || slow_prev <= 0.0)
      return false;

   // --- Trigger EVENT: shifted-EMA5 crosses EMA75 (one event per bar) ---
   const bool cross_up   = (fast_prev <= slow_prev && fast_now >  slow_now);
   const bool cross_down = (fast_prev >= slow_prev && fast_now <  slow_now);
   if(!cross_up && !cross_down)
      return false;

   // --- STATES (read once on the last closed bar) ---
   const double close1  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;
   const double bb_mid  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double rsi1    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double ema75_1 = slow_now; // EMA75 on the last closed bar
   if(bb_mid <= 0.0 || rsi1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, (int)strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1); // price distance of 1 pip
   const double sl_buffer = strategy_sl_buffer_pips * pip;
   const double atr_cap   = strategy_atr_sl_cap_mult * atr_value;

   QM_OrderType type = QM_BUY;
   double entry = 0.0;
   double sl    = 0.0;

   if(cross_up)
     {
      // LONG state confirmation
      if(!(close1 > ema75_1))   return false;
      if(!(close1 > bb_mid))    return false;
      if(!(rsi1   > strategy_rsi_level)) return false;

      type  = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0) return false;

      // SL = 2 pips below EMA75, but never wider than ATR cap, never above entry.
      double sl_raw  = ema75_1 - sl_buffer;
      double sl_floor = entry - atr_cap; // cap the distance at atr_cap
      if(sl_raw < sl_floor)
         sl_raw = sl_floor;
      if(sl_raw >= entry)                // degenerate (price already through EMA75)
         sl_raw = entry - atr_cap;
      sl = sl_raw;
     }
   else // cross_down -> SHORT
     {
      if(!(close1 < ema75_1))   return false;
      if(!(close1 < bb_mid))    return false;
      if(!(rsi1   < strategy_rsi_level)) return false;

      type  = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return false;

      double sl_raw   = ema75_1 + sl_buffer;
      double sl_floor = entry + atr_cap;
      if(sl_raw > sl_floor)
         sl_raw = sl_floor;
      if(sl_raw <= entry)
         sl_raw = entry + atr_cap;
      sl = sl_raw;
     }

   sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   const double sl_distance = MathAbs(entry - sl);
   if(sl_distance <= 0.0)
      return false;

   // TP = tp_rr * SL distance from entry.
   const double tp = QM_TakeRR(_Symbol, type, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = type;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (type == QM_BUY ? "ema5shift_x_ema75_long" : "ema5shift_x_ema75_short");
   return true;
  }

// No active trade management beyond the fixed SL/TP set at entry.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — positions exit on SL or TP only (card exit rule).
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
