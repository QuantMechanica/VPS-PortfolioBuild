#property strict
#property version   "5.0"
#property description "QM5_11614 robo-sma11-21-momentum30-rsi14-m15 — SMA cross + Momentum + RSI (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11614 robo-sma11-21-momentum30-rsi14-m15
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         "Momentum Forex Trading", page 36 (source_id ed246754).
// Card: artifacts/cards_approved/QM5_11614_robo-sma11-21-momentum30-rsi14-m15.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M15):
//   Trigger EVENT : SMA(fast=11) crosses SMA(slow=21).
//                   Long  = fast crosses ABOVE slow (one event/bar).
//                   Short = fast crosses BELOW slow (one event/bar).
//   Momentum STATE: Momentum(30) > 100 (bullish) for long / < 100 for short.
//   Price STATE   : close above BOTH SMAs (long) / below BOTH SMAs (short).
//   Stop          : 2 * ATR(14)  (card factory default).
//   Take profit   : 4 * ATR(14)  (card factory default).
//   Exit          : RSI(14) overbought (>= rsi_exit_hi) closes a long;
//                   RSI(14) oversold   (<= rsi_exit_lo) closes a short.
//   Spread guard  : skip only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// DESIGN NOTE (two-cross trap): the card narrates Momentum(30) crossing 100 as
// the trigger with the SMA stack as a filter. Two fresh cross EVENTS (SMA cross
// + Momentum-100 cross) almost never coincide on the same closed bar, which is a
// known zero-trade trap. Per the build contract we make the SMA(11)/SMA(21)
// cross the single trigger EVENT and use Momentum side (>100/<100) and the
// price/SMA relationship as confirming STATES. Same indicators, same intent,
// trade-generating.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11614;
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
input int    strategy_sma_fast_period    = 11;     // fast SMA (cross trigger)
input int    strategy_sma_slow_period    = 21;     // slow SMA (cross trigger)
input int    strategy_mom_period         = 30;     // Momentum period (state filter)
input double strategy_mom_neutral        = 100.0;  // Momentum equilibrium level
input int    strategy_rsi_period         = 14;     // RSI period (exit signal)
input double strategy_rsi_exit_hi        = 70.0;   // long exit: RSI overbought
input double strategy_rsi_exit_lo        = 30.0;   // short exit: RSI oversold
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance  = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

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

   // --- SMA values: now (shift 1) and prev (shift 2) for the cross EVENT ---
   const double sma_fast_now  = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 1);
   const double sma_slow_now  = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 1);
   const double sma_fast_prev = QM_SMA(_Symbol, _Period, strategy_sma_fast_period, 2);
   const double sma_slow_prev = QM_SMA(_Symbol, _Period, strategy_sma_slow_period, 2);
   if(sma_fast_now <= 0.0 || sma_slow_now <= 0.0 ||
      sma_fast_prev <= 0.0 || sma_slow_prev <= 0.0)
      return false;

   const bool cross_up   = (sma_fast_prev <= sma_slow_prev && sma_fast_now > sma_slow_now);
   const bool cross_down = (sma_fast_prev >= sma_slow_prev && sma_fast_now < sma_slow_now);
   if(!cross_up && !cross_down)
      return false; // no trigger event this bar

   // --- Confirming STATES: Momentum side + price-vs-SMA relationship ---
   const double mom = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   if(mom <= 0.0)
      return false;

   const double close1 = QM_SMA(_Symbol, _Period, 1, 1); // SMA(1)=close[1]; QM reader, no raw iClose
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0)
      return false;

   QM_OrderType side;
   double sl = 0.0;
   double tp = 0.0;

   if(cross_up)
     {
      // Long: bullish momentum + price above BOTH SMAs.
      if(!(mom > strategy_mom_neutral))
         return false;
      if(!(close1 > sma_fast_now && close1 > sma_slow_now))
         return false;
      side = QM_BUY;
      sl   = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      tp   = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      req.reason = "sma_cross_up_mom_long";
     }
   else // cross_down
     {
      // Short: bearish momentum + price below BOTH SMAs.
      if(!(mom < strategy_mom_neutral))
         return false;
      if(!(close1 < sma_fast_now && close1 < sma_slow_now))
         return false;
      side = QM_SELL;
      sl   = QM_StopATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_sl_atr_mult);
      tp   = QM_TakeATRFromValue(_Symbol, QM_SELL, bid, atr_value, strategy_tp_atr_mult);
      req.reason = "sma_cross_down_mom_short";
     }

   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type  = side;
   req.price = 0.0;   // framework fills market price at send
   req.sl    = sl;
   req.tp    = tp;
   return true;
  }

// No active trade management beyond the fixed ATR stop/target.
// The RSI-based discretionary exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: RSI(14) overbought closes longs, oversold closes shorts.
// State-based (not a fresh cross) — once RSI reaches the zone the position closes.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // Determine the direction of the open position for this magic.
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

   if(have_long && rsi >= strategy_rsi_exit_hi)
      return true;
   if(have_short && rsi <= strategy_rsi_exit_lo)
      return true;

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
