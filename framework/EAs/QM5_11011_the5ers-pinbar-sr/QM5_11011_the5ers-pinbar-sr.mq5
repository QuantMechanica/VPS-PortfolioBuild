#property strict
#property version   "5.0"
#property description "QM5_11011 the5ers-pinbar-sr — Pin Bar at Support/Resistance, stop-entry reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11011 the5ers-pinbar-sr
// -----------------------------------------------------------------------------
// Source: The5ers blog "Follow The Money With The Forex Pin Bar Pattern"
//   https://the5ers.com/forex-pin-bar/ (source_id 1d445184-7c47-57da-9856-a123682a932d).
// Card: artifacts/cards_approved/QM5_11011_the5ers-pinbar-sr.md (g0_status APPROVED).
//
// Mechanics (closed-bar, H4). All geometry/level work runs ONCE per new closed
// bar and is cached; OnTick path is O(1).
//
//   Pin bar (evaluated on the just-closed bar = shift 1):
//     range  = high1 - low1
//     valid  : range >= pin_min_atr_mult * ATR  AND  range <= pin_max_atr_mult * ATR
//     bullish: lower_wick >= wick_frac * range  AND  body <= body_frac * range
//              AND low1 within level_tol_atr*ATR of a confirmed SUPPORT level
//     bearish: symmetric with upper wick and a RESISTANCE level
//
//   Support / Resistance (deterministic swing detection over the lookback window):
//     A confirmed swing low at shift k = local minimum with `swing_strength`
//     strictly-lower bars on BOTH sides. Among all swing lows in
//     [swing_strength+1 .. sr_lookback], a level is VALID if at least
//     `sr_min_touches` swing lows cluster within level_tol_atr*ATR of it, AND
//     the level is at least sr_min_age_bars old. Resistance is symmetric from
//     swing highs.
//
//   Entry (framework pending stop order):
//     bullish: buy stop  at pin_high1 + trigger_atr_mult*ATR
//     bearish: sell stop at pin_low1  - trigger_atr_mult*ATR
//     The pending order expires after `pending_valid_bars` H4 bars.
//
//   Stop loss:
//     long : pin_low1  - sl_buffer_atr_mult * ATR
//     short: pin_high1 + sl_buffer_atr_mult * ATR
//   Take profit: TP at tp_rr R (risk = |entry - SL|).
//
//   Managed exits:
//     - Signal exit: close if a bar closes back through the pin-bar midpoint.
//     - Time stop  : close after time_stop_bars H4 bars.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11011;
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
input int    strategy_atr_period         = 14;     // ATR(H4) period for all geometry/levels
input double strategy_pin_min_atr_mult   = 0.75;   // min candle range as fraction of ATR
input double strategy_pin_max_atr_mult   = 3.0;    // reject ranges above this (news spikes)
input double strategy_wick_frac          = 0.70;   // dominant wick >= this fraction of range
input double strategy_body_frac          = 0.25;   // body <= this fraction of range
input double strategy_level_tol_atr      = 0.50;   // S/R touch / cluster tolerance in ATR
input double strategy_trigger_atr_mult   = 0.10;   // stop-entry buffer beyond the pin extreme
input double strategy_sl_buffer_atr_mult = 0.10;   // SL buffer beyond the pin extreme
input double strategy_tp_rr              = 2.0;    // take-profit at this R multiple
input int    strategy_sr_lookback        = 120;    // bars scanned for swing-based S/R levels
input int    strategy_swing_strength     = 3;      // bars strictly higher/lower each side of a swing
input int    strategy_sr_min_touches     = 2;      // swing points clustering to confirm a level
input int    strategy_sr_min_age_bars    = 10;     // confirmed level must be at least this old
input int    strategy_pending_valid_bars = 3;      // pin bar stays armed for this many H4 bars
input int    strategy_time_stop_bars     = 20;     // close after this many H4 bars in trade

// -----------------------------------------------------------------------------
// File-scope cached state (advanced once per new closed bar).
// -----------------------------------------------------------------------------
// Armed pin-bar setup awaiting the stop-entry trigger.
int      g_armed_dir        = 0;       // +1 bullish (buy), -1 bearish (sell), 0 none
double   g_armed_pin_high   = 0.0;
double   g_armed_pin_low    = 0.0;
double   g_armed_pin_mid    = 0.0;
double   g_armed_atr        = 0.0;     // ATR at the time the pin was detected
datetime g_armed_pin_time   = 0;       // open time of the pin bar
int      g_armed_bars_left  = 0;       // remaining H4 bars the setup is valid

// Open-position bookkeeping for managed exits.
double   g_pos_pin_mid      = 0.0;     // pin midpoint of the trade that opened
int      g_pos_dir          = 0;       // +1 long / -1 short of the open trade

// -----------------------------------------------------------------------------
// Helpers (only called inside the QM_IsNewBar gate — perf-allowed bar reads).
// -----------------------------------------------------------------------------

// Is bar at shift k a confirmed swing low? (strictly-lower neighbours each side)
bool IsSwingLow(const int k, const int strength)
  {
   const double lk = iLow(_Symbol, _Period, k); // perf-allowed: bounded new-bar scan
   if(lk <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iLow(_Symbol, _Period, k - j) <= lk) return false; // perf-allowed: bounded structural scan
      if(iLow(_Symbol, _Period, k + j) <= lk) return false; // perf-allowed: bounded structural scan
     }
   return true;
  }

// Is bar at shift k a confirmed swing high?
bool IsSwingHigh(const int k, const int strength)
  {
   const double hk = iHigh(_Symbol, _Period, k); // perf-allowed: bounded new-bar scan
   if(hk <= 0.0)
      return false;
   for(int j = 1; j <= strength; ++j)
     {
      if(iHigh(_Symbol, _Period, k - j) >= hk) return false; // perf-allowed: bounded structural scan
      if(iHigh(_Symbol, _Period, k + j) >= hk) return false; // perf-allowed: bounded structural scan
     }
   return true;
  }

// Find a confirmed SUPPORT level near `price` (within tol). Returns true and
// sets out_age (bars since the level's anchor swing) when a level with at least
// `sr_min_touches` clustered swing lows, at least sr_min_age_bars old, exists.
bool FindSupportNear(const double price, const double tol,
                     const int strength, const int lookback,
                     const int min_touches, const int min_age,
                     int &out_age)
  {
   const int last = lookback;
   for(int k = strength + 1; k <= last; ++k)
     {
      if(!IsSwingLow(k, strength))
         continue;
      const double level = iLow(_Symbol, _Period, k); // perf-allowed: bounded structural scan
      if(level <= 0.0)
         continue;
      if(MathAbs(price - level) > tol)
         continue;                          // candle low must approach THIS level
      if(k < min_age)
         continue;                          // level must be old enough
      // Count clustered swing lows within tol of this level.
      int touches = 0;
      for(int m = strength + 1; m <= last; ++m)
        {
         if(!IsSwingLow(m, strength))
            continue;
         const double lm = iLow(_Symbol, _Period, m); // perf-allowed: bounded structural scan
         if(lm > 0.0 && MathAbs(lm - level) <= tol)
            ++touches;
        }
      if(touches >= min_touches)
        {
         out_age = k;
         return true;
        }
     }
   return false;
  }

// Find a confirmed RESISTANCE level near `price` (symmetric to FindSupportNear).
bool FindResistanceNear(const double price, const double tol,
                        const int strength, const int lookback,
                        const int min_touches, const int min_age,
                        int &out_age)
  {
   const int last = lookback;
   for(int k = strength + 1; k <= last; ++k)
     {
      if(!IsSwingHigh(k, strength))
         continue;
      const double level = iHigh(_Symbol, _Period, k); // perf-allowed: bounded structural scan
      if(level <= 0.0)
         continue;
      if(MathAbs(price - level) > tol)
         continue;
      if(k < min_age)
         continue;
      int touches = 0;
      for(int m = strength + 1; m <= last; ++m)
        {
         if(!IsSwingHigh(m, strength))
            continue;
         const double hm = iHigh(_Symbol, _Period, m); // perf-allowed: bounded structural scan
         if(hm > 0.0 && MathAbs(hm - level) <= tol)
            ++touches;
        }
      if(touches >= min_touches)
        {
         out_age = k;
         return true;
        }
     }
   return false;
  }

bool HasOurPendingStopOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }

   return false;
  }

// Re-scan the just-closed bar (shift 1) for a fresh pin-bar setup, advance any
// existing armed setup's validity counter. Called ONCE per new closed bar.
void AdvanceState_OnNewBar()
  {
   // Decay the validity window of an already-armed setup; expire if exhausted.
   if(g_armed_dir != 0)
     {
      --g_armed_bars_left;
      if(g_armed_bars_left <= 0)
         g_armed_dir = 0;
     }

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double o1 = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed bar
   const double h1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed bar
   const double l1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed bar
   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed bar
   if(o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || c1 <= 0.0)
      return;

   const double range = h1 - l1;
   if(range <= 0.0)
      return;
   // Range band: big enough to be a pin, not a news-spike outlier.
   if(range < strategy_pin_min_atr_mult * atr)
      return;
   if(range > strategy_pin_max_atr_mult * atr)
      return;

   const double body  = MathAbs(c1 - o1);
   const double upper_wick = h1 - MathMax(o1, c1);
   const double lower_wick = MathMin(o1, c1) - l1;
   if(body > strategy_body_frac * range)
      return;                                     // body too large for a pin

   const double tol = strategy_level_tol_atr * atr;
   const double mid = 0.5 * (h1 + l1);

   // Bullish pin: long lower wick, low at support.
   if(lower_wick >= strategy_wick_frac * range)
     {
      int age = 0;
      if(FindSupportNear(l1, tol, strategy_swing_strength, strategy_sr_lookback,
                         strategy_sr_min_touches, strategy_sr_min_age_bars, age))
        {
         g_armed_dir       = +1;
         g_armed_pin_high  = h1;
         g_armed_pin_low   = l1;
         g_armed_pin_mid   = mid;
         g_armed_atr       = atr;
         g_armed_pin_time  = iTime(_Symbol, _Period, 1); // perf-allowed: pin-bar timestamp
         g_armed_bars_left = strategy_pending_valid_bars;
         return;
        }
     }

   // Bearish pin: long upper wick, high at resistance.
   if(upper_wick >= strategy_wick_frac * range)
     {
      int age = 0;
      if(FindResistanceNear(h1, tol, strategy_swing_strength, strategy_sr_lookback,
                           strategy_sr_min_touches, strategy_sr_min_age_bars, age))
        {
         g_armed_dir       = -1;
         g_armed_pin_high  = h1;
         g_armed_pin_low   = l1;
         g_armed_pin_mid   = mid;
         g_armed_atr       = atr;
         g_armed_pin_time  = iTime(_Symbol, _Period, 1); // perf-allowed: pin-bar timestamp
         g_armed_bars_left = strategy_pending_valid_bars;
         return;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate — no spread guard needed beyond fail-open quote check.
// Pin-bar / S/R work is on the closed-bar path (AdvanceState_OnNewBar).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Place the card's pending stop entry from the armed setup. The framework sizes
// risk from SL distance and expires the pending order through expiration_seconds.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(HasOurPendingStopOrder())
      return false;
   if(g_armed_dir == 0 || g_armed_atr <= 0.0)
      return false;

   const double buf = strategy_trigger_atr_mult * g_armed_atr;
   const int expiration = PeriodSeconds(_Period) * strategy_pending_valid_bars;
   if(expiration <= 0)
      return false;

   if(g_armed_dir > 0)
     {
      // Bullish: buy-stop above the pin high.
      const double entry = QM_StopRulesNormalizePrice(_Symbol, g_armed_pin_high + buf);
      const double sl = g_armed_pin_low - strategy_sl_buffer_atr_mult * g_armed_atr;
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY_STOP, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type               = QM_BUY_STOP;
      req.price              = entry;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = tp;
      req.reason             = "pinbar_sr_long";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = expiration;
      g_pos_dir              = +1;
      g_pos_pin_mid          = g_armed_pin_mid;
      g_armed_dir            = 0;   // consume the setup
      return true;
     }
   else
     {
      // Bearish: sell-stop below the pin low.
      const double entry = QM_StopRulesNormalizePrice(_Symbol, g_armed_pin_low - buf);
      const double sl = g_armed_pin_high + strategy_sl_buffer_atr_mult * g_armed_atr;
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL_STOP, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type               = QM_SELL_STOP;
      req.price              = entry;
      req.sl                 = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp                 = tp;
      req.reason             = "pinbar_sr_short";
      req.symbol_slot        = qm_magic_slot_offset;
      req.expiration_seconds = expiration;
      g_pos_dir              = -1;
      g_pos_pin_mid          = g_armed_pin_mid;
      g_armed_dir            = 0;
      return true;
     }
  }

// No active SL/TP trailing; managed exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Managed exits: midpoint re-cross OR time stop. Evaluated on the closed-bar
// cadence via the framework new-bar gate (OnTick calls this each tick, but the
// decisions reference the just-closed bar only, so they are stable per bar).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(g_pos_dir == 0)
      return false;

   const double c1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed bar
   if(c1 <= 0.0)
      return false;

   // Signal exit: a bar closes back through the pin-bar midpoint against us.
   if(g_pos_dir > 0 && c1 < g_pos_pin_mid)
     {
      g_pos_dir = 0;
      return true;
     }
   if(g_pos_dir < 0 && c1 > g_pos_pin_mid)
     {
      g_pos_dir = 0;
      return true;
     }

   // Time stop: close after strategy_time_stop_bars H4 bars in the trade.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != QM_FrameworkMagic())
         continue;

      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      const long bars_held = (long)((TimeCurrent() - position_time) / PeriodSeconds(_Period));
      if(bars_held >= strategy_time_stop_bars)
        {
         g_pos_dir = 0;
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

   // Advance closed-bar state (pin-bar scan + S/R levels) ONCE per new bar.
   AdvanceState_OnNewBar();

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
