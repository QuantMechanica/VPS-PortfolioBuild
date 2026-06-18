#property strict
#property version   "5.0"
#property description "QM5_11306 bf-golden-x — Golden-Cross EMA20/50 + EMA100 regime + RSI50 filter (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11306 bf-golden-x
// -----------------------------------------------------------------------------
// Source: conor19w/Binance-Futures-Trading-Bot, TradingStrats.py goldenCross().
// Card: artifacts/cards_approved/QM5_11306_bf-golden-x.md (g0_status APPROVED).
//
// Mechanics (long + short, closed-bar reads at shift 1):
//   Trigger EVENT (the ONE event): EMA(fast) crosses EMA(slow) — a "golden
//       cross" for longs / "death cross" for shorts. Detected within a small
//       lookback window (current or prior `cross_lookback` closed bars) so a
//       single-bar coincidence with the state filters is not required. This is
//       the anti-zero-trade design: one fresh cross event, states are separate.
//   Regime STATE : close vs EMA(regime) — above for long, below for short.
//   Momentum STATE: RSI vs `rsi_level` — RSI>level for long, RSI<level short.
//   Stop  : fixed percent of entry price (sl_pct), normalized to symbol point.
//   Take  : fixed percent of entry price (tp_pct), normalized to symbol point.
//   Defensive exit: opposite cross EVENT (fast crosses back) -> close manually.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of
//                  the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11306;
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
input int    strategy_ema_fast_period   = 20;     // golden-cross fast EMA
input int    strategy_ema_slow_period   = 50;     // golden-cross slow EMA
input int    strategy_ema_regime_period = 100;    // regime trend filter EMA
input int    strategy_cross_lookback    = 3;      // bars back to accept a fresh cross EVENT (current+prior)
input int    strategy_rsi_period        = 14;     // RSI lookback period
input double strategy_rsi_level         = 50.0;   // RSI momentum gate (>level long, <level short)
input double strategy_sl_pct            = 1.5;    // stop  = this % of entry price
input double strategy_tp_pct            = 1.0;    // take  = this % of entry price
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helper: did fast EMA cross slow EMA on the closed bar at `shift`?
//   +1 bullish (golden) cross, -1 bearish (death) cross, 0 otherwise.
// Uses only QM_EMA closed-bar reads; cross detected between shift+1 and shift.
// -----------------------------------------------------------------------------
int GoldenCrossAt(const int shift)
  {
   const double f_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
   const double s_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
   const double f_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1);
   const double s_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1);
   if(f_now <= 0.0 || s_now <= 0.0 || f_prev <= 0.0 || s_prev <= 0.0)
      return 0;
   if(f_prev <= s_prev && f_now > s_now) return +1;
   if(f_prev >= s_prev && f_now < s_now) return -1;
   return 0;
  }

// Returns +1 / -1 if a fresh cross of the corresponding direction occurred on
// any closed bar in shifts 1..cross_lookback (the EVENT window), else 0. If
// both directions appear in the window, the most recent (smallest shift) wins.
int RecentCrossDirection()
  {
   int lookback = strategy_cross_lookback;
   if(lookback < 1) lookback = 1;
   for(int s = 1; s <= lookback; ++s)
     {
      const int dir = GoldenCrossAt(s);
      if(dir != 0)
         return dir;
     }
   return 0;
  }

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

   // Stop distance reference for the spread cap = sl_pct of the current ask.
   const double stop_distance = (strategy_sl_pct / 100.0) * ask;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long + short golden/death-cross entry. Caller guarantees QM_IsNewBar()==true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: a fresh EMA fast/slow cross within the lookback window.
   const int cross_dir = RecentCrossDirection();
   if(cross_dir == 0)
      return false;

   // --- Regime STATE: close vs regime EMA (closed bar at shift 1). ---
   const double ema_regime = QM_EMA(_Symbol, _Period, strategy_ema_regime_period, 1);
   if(ema_regime <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Momentum STATE: RSI vs level (closed bar at shift 1). ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi1 <= 0.0)
      return false;

   bool go_long  = false;
   bool go_short = false;
   if(cross_dir > 0)
      go_long  = (close1 > ema_regime) && (rsi1 > strategy_rsi_level);
   else
      go_short = (close1 < ema_regime) && (rsi1 < strategy_rsi_level);

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;

   // --- Entry / stop / take. Fixed-percent SL & TP of entry price. ---
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_dist = (strategy_sl_pct / 100.0) * entry;
   const double tp_dist = (strategy_tp_pct / 100.0) * entry;
   if(sl_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   double sl_price = go_long ? (entry - sl_dist) : (entry + sl_dist);
   double tp_price = go_long ? (entry + tp_dist) : (entry - tp_dist);
   sl_price = QM_TM_NormalizePrice(_Symbol, sl_price);
   tp_price = QM_TM_NormalizePrice(_Symbol, tp_price);
   if(sl_price <= 0.0 || tp_price <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl_price;
   req.tp     = tp_price;
   req.reason = go_long ? "golden_cross_long" : "death_cross_short";
   return true;
  }

// No active trade management beyond the fixed percent stop/target. The
// opposite-cross defensive exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit on the opposite cross EVENT: close a long on a death cross and
// a short on a golden cross. One event at shift 1.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int dir = GoldenCrossAt(1);
   if(dir == 0)
      return false;

   // Determine current position direction for this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Close long on a bearish (death) cross; close short on a bullish cross.
   if(have_long  && dir < 0) return true;
   if(have_short && dir > 0) return true;
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
