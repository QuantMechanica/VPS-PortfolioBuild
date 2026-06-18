#property strict
#property version   "5.0"
#property description "QM5_11641 robo-sma20l-ema34-adx13-d1 — SMA(20,Low) support + EMA34 trend + ADX13 (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11641 robo-sma20l-ema34-adx13-d1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         "SMA Low + EMA + ADX", page 117.
// Card: artifacts/cards_approved/QM5_11641_robo-sma20l-ema34-adx13-d1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; D1):
//   SMA(20) on PRICE_LOW forms a dynamic support/resistance level.
//   EMA(34) on PRICE_CLOSE gives trend direction.
//   ADX(13) confirms trend strength.
//
//   LONG:
//     Regime STATE : Close > EMA34   (bullish trend)
//     Strength STATE: ADX > adx_threshold
//     Pullback STATE: a Low within the lookback window PRECEDING the trigger
//                     bar touched/approached SMA20L (Low <= SMA20L * (1+tol)).
//     Trigger EVENT : on the trigger bar the close resumes ABOVE the SMA20L
//                     support (Close[2] <= SMA20L[2] AND Close[1] > SMA20L[1]).
//                     ONE event per bar — the touch is a prior STATE, never the
//                     same bar, so the two-cross-same-bar zero-trade trap is
//                     avoided.
//   SHORT (mirror): Close < EMA34, ADX > thr, a High in the prior window
//                   touched SMA20L from below (High >= SMA20L*(1-tol), i.e.
//                   SMA20L acts as resistance in the downtrend), and the close
//                   resumes BELOW the SMA20L level on the trigger bar
//                   (Close[2] >= SMA20L[2] AND Close[1] < SMA20L[1]).
//
//   Stop : entry -/+ sl_atr_mult * ATR(atr_period)   (factory 2*ATR).
//   Take : RR multiple of the stop distance (factory tp_atr/sl_atr = 4/2 = 2R).
//   Defensive exit: EMA34 crosses against the open position (price closes on
//                   the wrong side of EMA34).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11641;
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
input int    strategy_sma_low_period     = 20;    // SMA period applied to PRICE_LOW (dynamic support)
input int    strategy_ema_period         = 34;    // EMA period (PRICE_CLOSE) for trend direction
input int    strategy_adx_period         = 13;    // ADX period for trend strength
input double strategy_adx_threshold      = 25.0;  // min ADX for "sufficient trend" (source: 25)
input int    strategy_pullback_bars      = 5;     // lookback window for the support touch (bars before trigger)
input double strategy_touch_tol_pct      = 0.10;  // touch tolerance as % of price (Low within this % of SMA20L counts)
input int    strategy_atr_period         = 14;    // ATR period (stop distance)
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;   // take-profit at this R-multiple (4*ATR / 2*ATR = 2R)
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

   const double stop_distance = strategy_sl_atr_mult * atr_value;
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

   // --- Indicator STATES on the trigger bar (shift 1) and prior bar (shift 2) ---
   const double ema1    = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double adx1    = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   const double sma1    = QM_SMA(_Symbol, _Period, strategy_sma_low_period, 1, PRICE_LOW);
   const double sma2    = QM_SMA(_Symbol, _Period, strategy_sma_low_period, 2, PRICE_LOW);
   if(ema1 <= 0.0 || adx1 <= 0.0 || sma1 <= 0.0 || sma2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Strength STATE: ADX above the trend-strength floor ---
   if(adx1 <= strategy_adx_threshold)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double tol = strategy_touch_tol_pct / 100.0;

   // --- LONG path ---
   // Regime STATE: bullish trend (close above EMA34).
   if(close1 > ema1)
     {
      // Trigger EVENT: close resumes above SMA20L support on the trigger bar
      // (was at/below support on the prior bar, now back above). ONE event.
      const bool resumed_up = (close2 <= sma2 && close1 > sma1);
      if(resumed_up)
        {
         // Pullback STATE: a Low in the window PRECEDING the trigger bar
         // (shifts 2 .. pullback_bars+1) touched/approached the SMA20L support.
         bool touched = false;
         const int first_shift = 2;
         const int last_shift  = strategy_pullback_bars + 1;
         for(int s = first_shift; s <= last_shift; ++s)
           {
            const double low_s = iLow(_Symbol, _Period, s);    // perf-allowed: prior-bar low
            const double sma_s = QM_SMA(_Symbol, _Period, strategy_sma_low_period, s, PRICE_LOW);
            if(low_s <= 0.0 || sma_s <= 0.0)
               continue;
            if(low_s <= sma_s * (1.0 + tol))
              {
               touched = true;
               break;
              }
           }
         if(touched)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
            if(sl <= 0.0)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;
            req.type   = QM_BUY;
            req.price  = 0.0;   // framework fills market price at send
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "sma20l_ema34_adx_long";
            return true;
           }
        }
      return false;
     }

   // --- SHORT path ---
   // Regime STATE: bearish trend (close below EMA34).
   if(close1 < ema1)
     {
      // Trigger EVENT: close resumes below the SMA20L level on the trigger bar
      // (was at/above it on the prior bar, now back below). ONE event.
      const bool resumed_down = (close2 >= sma2 && close1 < sma1);
      if(resumed_down)
        {
         // Pullback STATE: a High in the window PRECEDING the trigger bar
         // touched/approached SMA20L from below (acting as resistance).
         bool touched = false;
         const int first_shift = 2;
         const int last_shift  = strategy_pullback_bars + 1;
         for(int s = first_shift; s <= last_shift; ++s)
           {
            const double high_s = iHigh(_Symbol, _Period, s);  // perf-allowed: prior-bar high
            const double sma_s  = QM_SMA(_Symbol, _Period, strategy_sma_low_period, s, PRICE_LOW);
            if(high_s <= 0.0 || sma_s <= 0.0)
               continue;
            if(high_s >= sma_s * (1.0 - tol))
              {
               touched = true;
               break;
              }
           }
         if(touched)
           {
            const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(entry <= 0.0)
               return false;
            const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
            if(sl <= 0.0)
               return false;
            const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
            if(tp <= 0.0)
               return false;
            req.type   = QM_SELL;
            req.price  = 0.0;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "sma20l_ema34_adx_short";
            return true;
           }
        }
      return false;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / RR target. The
// defensive EMA34-cross exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: close resumes on the wrong side of EMA34 relative to the
// open position direction. One state evaluated on the closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema1   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema1 <= 0.0 || close1 <= 0.0)
      return false;

   // Determine the open direction for this EA's magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   if(have_long && close1 < ema1)
      return true;   // bullish trend broke — exit long
   if(have_short && close1 > ema1)
      return true;   // bearish trend broke — exit short

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
