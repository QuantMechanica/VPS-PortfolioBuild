#property strict
#property version   "5.0"
#property description "QM5_1271 hopwood-cup-of-coffee-h1 — Stochastic-Donchian-EMA confluence (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1271 hopwood-cup-of-coffee-h1
// -----------------------------------------------------------------------------
// Source: ForexFactory Steve Hopwood master thread (thread/282290) — the
//   "Cup-of-Coffee" hybrid. Card:
//   artifacts/cards_approved/QM5_1271_hopwood-cup-of-coffee-h1.md (g0 APPROVED).
//
// Mechanics (closed-bar reads at shift 1; Stoch cross is the EVENT, Donchian +
// EMA bias are STATES — avoids the two-cross-same-bar zero-trade trap):
//
//   Trigger EVENT (LONG): Stochastic(14,3,3) %K crosses ABOVE %D between bar [2]
//                         and bar [1], AND both %K[2] and %D[2] were below the
//                         oversold line (cross UP out of the oversold zone).
//   STATE 1 (LONG)      : Close[1] > Donchian.upper[2]  (closed bar took out the
//                         prior 20-bar high; channel measured over shifts 2..21).
//   STATE 2 (LONG)      : Close[1] > EMA(200, H1)        (directional bias).
//   SHORT = mirror (cross DOWN out of overbought; Close[1] < lower; Close[1] < EMA).
//
//   Initial SL  : opposite Donchian boundary at trigger time
//                 (long: Donchian.lower[2]; short: Donchian.upper[2]),
//                 floored so SL distance >= ATR(14) * atr_floor_mult.
//   Take profit : fixed RR multiple of the initial SL distance (default 2.0).
//   Exit (mgd in Strategy_ExitSignal):
//     - opposite-direction Stochastic cross out of the opposite extreme zone, OR
//     - Donchian-channel flip against the position (long: Close[1] < lower[2]).
//   One position per symbol per magic (HR14).
//
//   Spread guard: blocks only a genuinely wide spread (> spread_pct_of_stop of
//   the stop distance); fail-open on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1271;
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
input int    strategy_stoch_k           = 14;    // Stochastic %K period
input int    strategy_stoch_d           = 3;     // Stochastic %D period
input int    strategy_stoch_slow        = 3;     // Stochastic slowing
input double strategy_stoch_oversold    = 30.0;  // oversold zone ceiling
input double strategy_stoch_overbought  = 70.0;  // overbought zone floor
input int    strategy_donchian_period   = 20;    // Donchian channel lookback (bars)
input int    strategy_ema_bias_period   = 200;   // EMA directional-bias period
input int    strategy_atr_period        = 14;    // ATR period (SL floor)
input double strategy_atr_floor_mult    = 1.0;   // min SL distance = mult * ATR  (P3: 0.5/1.0/1.5)
input double strategy_take_rr           = 2.0;   // take-profit RR multiple        (P3: 1.5/2.0/2.5/3.0)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (closed-bar Donchian over the prior N bars, ending at shift `end`)
// -----------------------------------------------------------------------------

// Highest High over `period` closed bars starting at shift `end` (inclusive),
// i.e. shifts end .. end+period-1. perf-allowed: bounded N-bar loop, only ever
// reached on the closed-bar entry/exit path (QM_IsNewBar gate upstream).
double DonchianUpper(const int period, const int end)
  {
   double hi = 0.0;
   for(int s = end; s < end + period; ++s)            // perf-allowed: bounded loop, new-bar gated
     {
      const double h = iHigh(_Symbol, _Period, s);    // perf-allowed: closed-bar structural read
      if(h <= 0.0)
         continue;
      if(hi == 0.0 || h > hi)
         hi = h;
     }
   return hi;
  }

// Lowest Low over `period` closed bars starting at shift `end` (inclusive).
double DonchianLower(const int period, const int end)
  {
   double lo = 0.0;
   for(int s = end; s < end + period; ++s)            // perf-allowed: bounded loop, new-bar gated
     {
      const double l = iLow(_Symbol, _Period, s);     // perf-allowed: closed-bar structural read
      if(l <= 0.0)
         continue;
      if(lo == 0.0 || l < lo)
         lo = l;
     }
   return lo;
  }

// +1 = fresh %K-cross-up out of the oversold zone between bar [2] and bar [1].
// -1 = fresh %K-cross-down out of the overbought zone.  0 = neither.
// The cross between shift 2 and shift 1 is ONE event per closed bar.
int StochCrossEvent()
  {
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow);    // shift 1
   const double d1 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow);    // shift 1
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2); // shift 2
   const double d2 = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2); // shift 2
   if(k1 <= 0.0 || d1 <= 0.0 || k2 <= 0.0 || d2 <= 0.0)
      return 0;

   // LONG: %K was at/below %D on bar [2] and is above %D on bar [1], and the
   // cross originates from the oversold zone (both lines < oversold on bar [2]).
   const bool cross_up = (k2 <= d2 && k1 > d1 &&
                          k2 < strategy_stoch_oversold && d2 < strategy_stoch_oversold);
   if(cross_up)
      return +1;

   // SHORT mirror out of the overbought zone.
   const bool cross_dn = (k2 >= d2 && k1 < d1 &&
                          k2 > strategy_stoch_overbought && d2 > strategy_stoch_overbought);
   if(cross_dn)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — confluence work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_floor_mult * atr_value;
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

   // --- Trigger EVENT: Stochastic cross out of an extreme zone (one per bar) ---
   const int cross = StochCrossEvent();
   if(cross == 0)
      return false;

   // --- Donchian channel over the prior `period` bars, NOT including the
   //     trigger bar [1]: measured over shifts 2 .. period+1. ---
   const double don_upper = DonchianUpper(strategy_donchian_period, 2);
   const double don_lower = DonchianLower(strategy_donchian_period, 2);
   if(don_upper <= 0.0 || don_lower <= 0.0)
      return false;

   // --- Directional-bias STATE: EMA(200) on the closed bar. ---
   const double ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   if(ema_bias <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   const double atr_floor = strategy_atr_floor_mult * atr_value;

   const double entry = (cross > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(cross > 0)
     {
      // LONG: breakout STATE (Close[1] above prior 20-bar high) + bullish bias.
      if(!(close1 > don_upper))
         return false;
      if(!(close1 > ema_bias))
         return false;

      // Initial SL = opposite Donchian boundary, floored to ATR distance.
      double sl = don_lower;
      if(entry - sl < atr_floor)
         sl = entry - atr_floor;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "cup_of_coffee_long";
      return true;
     }
   else
     {
      // SHORT: breakout STATE (Close[1] below prior 20-bar low) + bearish bias.
      if(!(close1 < don_lower))
         return false;
      if(!(close1 < ema_bias))
         return false;

      double sl = don_upper;
      if(sl - entry < atr_floor)
         sl = entry + atr_floor;
      sl = QM_TM_NormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;

      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "cup_of_coffee_short";
      return true;
     }
  }

// No active trade management beyond the fixed Donchian/ATR stop and RR target.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite-direction Stochastic cross out of the opposite
// extreme zone, OR Donchian-channel flip against the open position. One event
// per closed bar. Direction is read from the open position's type.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open side for this magic.
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
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }
   if(!have_long && !have_short)
      return false;

   const int cross = StochCrossEvent();
   const double don_upper = DonchianUpper(strategy_donchian_period, 2);
   const double don_lower = DonchianLower(strategy_donchian_period, 2);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read

   if(have_long)
     {
      // Opposite Stoch cross (down out of overbought) OR channel flip below the
      // prior 20-bar low closes the long.
      if(cross < 0)
         return true;
      if(don_lower > 0.0 && close1 > 0.0 && close1 < don_lower)
         return true;
     }
   if(have_short)
     {
      if(cross > 0)
         return true;
      if(don_upper > 0.0 && close1 > 0.0 && close1 > don_upper)
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
