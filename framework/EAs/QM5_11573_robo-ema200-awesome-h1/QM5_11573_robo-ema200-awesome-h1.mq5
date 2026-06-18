#property strict
#property version   "5.0"
#property description "QM5_11573 robo-ema200-awesome-h1 — EMA200 trend + Awesome Oscillator trigger (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11573 robo-ema200-awesome-h1
// -----------------------------------------------------------------------------
// Source: RoboForex strategy collection, "Strategy with the use of EMA and
//   Awesome Oscillator", pages 52-53 (local PDF archive).
// Card: artifacts/cards_approved/QM5_11573_robo-ema200-awesome-h1.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trend STATE  : close vs EMA200. LONG needs close > EMA200; SHORT close < EMA200.
//   AO definition: AO = SMA(fast=5, median price) - SMA(slow=34, median price),
//                  median price = (High+Low)/2 == PRICE_MEDIAN. Computed in-EA
//                  via QM_SMA(..., PRICE_MEDIAN) (no QM_AO helper exists).
//   Trigger EVENT: a fresh AO zero-line cross in the trend direction (one event
//                  per bar). LONG: AO crossed up through 0 (ao_prev<=0, ao_now>0).
//                  SHORT: AO crossed down through 0 (ao_prev>=0, ao_now<0). The
//                  zero-cross is the single EVENT; the EMA200 side is the STATE,
//                  so we never require two cross events on the same bar.
//   AO momentum  : confirm histogram colour (rising for long / falling for short)
//                  as an additional STATE, not a second event.
//   Stop         : structural swing — lowest low (long) / highest high (short)
//                  over the prior `swing_lookback` closed bars, minus/plus a
//                  small pip buffer (card: "5 points below the previous swing").
//   Take profit  : RR multiple of the stop distance (card P2 default 1R).
//   Defensive exit: close crosses EMA200 against the open trade -> close manually.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11573;
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
input int    strategy_ema_trend_period  = 200;    // EMA200 trend filter
input int    strategy_ao_fast_period    = 5;      // Awesome Oscillator fast SMA (median price)
input int    strategy_ao_slow_period    = 34;     // Awesome Oscillator slow SMA (median price)
input bool   strategy_ao_require_colour = true;   // require AO momentum (rising long / falling short)
input int    strategy_swing_lookback    = 5;      // swing low/high lookback (prior closed bars)
input double strategy_swing_buffer_pips  = 0.5;   // extra buffer beyond the swing (card "5 points")
input double strategy_tp_rr             = 1.0;    // take-profit as RR multiple of stop distance
input double strategy_spread_cap_pips    = 3.0;   // skip genuinely wide spread (card spread cap 3 pips)

// -----------------------------------------------------------------------------
// AO helper — Awesome Oscillator on the median price at a given closed-bar shift.
// AO = SMA(fast, median) - SMA(slow, median). PRICE_MEDIAN == (High+Low)/2.
// -----------------------------------------------------------------------------
double AO_Value(const int shift)
  {
   const double fast = QM_SMA(_Symbol, _Period, strategy_ao_fast_period, shift, PRICE_MEDIAN);
   const double slow = QM_SMA(_Symbol, _Period, strategy_ao_slow_period, shift, PRICE_MEDIAN);
   return fast - slow;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   const double cap    = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: close vs EMA200 (closed bar) ---
   const double ema_trend = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   if(ema_trend <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool uptrend   = (close1 > ema_trend);
   const bool downtrend = (close1 < ema_trend);
   if(!uptrend && !downtrend)
      return false;

   // --- Awesome Oscillator at the last two closed bars ---
   const double ao_now  = AO_Value(1);
   const double ao_prev = AO_Value(2);

   // --- Trigger EVENT: fresh AO zero-line cross in the trend direction.
   //     One event per bar; the EMA200 side is the STATE (no two-cross trap). ---
   const bool ao_cross_up   = (ao_prev <= 0.0 && ao_now > 0.0);
   const bool ao_cross_down = (ao_prev >= 0.0 && ao_now < 0.0);

   // --- AO momentum STATE (histogram colour): rising = green, falling = red. ---
   const bool ao_rising  = (ao_now > ao_prev);
   const bool ao_falling = (ao_now < ao_prev);

   QM_OrderType side;
   if(uptrend && ao_cross_up && (!strategy_ao_require_colour || ao_rising))
      side = QM_BUY;
   else if(downtrend && ao_cross_down && (!strategy_ao_require_colour || ao_falling))
      side = QM_SELL;
   else
      return false;

   // --- Entry price ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Structural swing stop over the prior swing_lookback closed bars,
   //     pushed out by a small pip buffer (card: "5 points beyond the swing"). ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;
   const double buffer = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_swing_buffer_pips);
   if(side == QM_BUY)
      sl -= buffer;
   else
      sl += buffer;
   sl = QM_StopRulesNormalizePrice(_Symbol, sl);

   // Stop must sit on the correct side of entry.
   if(side == QM_BUY && !(sl < entry))
      return false;
   if(side == QM_SELL && !(sl > entry))
      return false;

   // --- Take profit: RR multiple of the stop distance ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "ema200_ao_long" : "ema200_ao_short";
   return true;
  }

// No active trade management beyond the fixed structural stop / RR target.
// The defensive EMA200-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: close crosses EMA200 against the open trade. One event/bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_trend = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   if(ema_trend <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine the open position's direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && close1 < ema_trend)
         return true;   // long but close fell below EMA200
      if(ptype == POSITION_TYPE_SELL && close1 > ema_trend)
         return true;   // short but close rose above EMA200
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
