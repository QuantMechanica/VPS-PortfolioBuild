#property strict
#property version   "5.0"
#property description "QM5_11509 carter-t-ema5-10-stoch-rsi — EMA(5/10) cross + Stoch + RSI trend (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11509 carter-t-ema5-10-stoch-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems", System #4, self-published 2014.
// Card: artifacts/cards_approved/QM5_11509_carter-t-ema5-10-stoch-rsi.md
//       (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads at shift 1; H1 base TF):
//   Trigger EVENT : EMA(fast) crosses EMA(slow). LONG = fast crosses ABOVE slow
//                   within the last `cross_lookback` closed bars; SHORT = below.
//                   ONE cross event is the trigger — the rest are STATES, so we
//                   never require two fresh crosses on the same bar (zero-trade
//                   trap #4).
//   Stoch STATE   : Stochastic %K rising AND not overbought (< ob_level) for
//                   longs; falling AND not oversold (> os_level) for shorts.
//   RSI STATE     : RSI(period) > rsi_mid for longs; < rsi_mid for shorts.
//   Stop          : entry -/+ sl_pips fixed pips (card P2: 30-pip fixed SL).
//   Take profit   : none — card uses indicator-driven exit (req.tp = 0).
//   Exit          : EMA(fast) crosses the opposite side of EMA(slow), OR RSI
//                   crosses the rsi_mid level against the position.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread — zero-trade trap #1).
//   No-Friday-entry: card filter — block new entries on Friday (broker time).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11509;
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
input int    strategy_ema_fast_period   = 5;      // fast EMA period
input int    strategy_ema_slow_period   = 10;     // slow EMA period
input int    strategy_cross_lookback    = 3;      // bars to look back for the EMA cross event
input int    strategy_stoch_k           = 14;     // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slowing     = 3;      // Stochastic slowing
input double strategy_stoch_ob          = 80.0;   // Stochastic overbought ceiling (long filter)
input double strategy_stoch_os          = 20.0;   // Stochastic oversold floor (short filter)
input int    strategy_rsi_period        = 14;     // RSI period
input double strategy_rsi_mid           = 50.0;   // RSI regime / exit level
input double strategy_sl_pips           = 30.0;   // fixed stop-loss distance in pips
input bool   strategy_no_friday_entry   = true;   // block new entries on Friday (broker time)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Detect an EMA(fast)/EMA(slow) cross within the last `lookback` closed bars.
// dir = +1 looks for an UP cross (fast crosses above slow); dir = -1 for DOWN.
// A cross on bar s means: fast[s] > slow[s] (up) AND fast[s+1] <= slow[s+1].
bool EmaCrossedWithin(const int dir, const int lookback)
  {
   for(int s = 1; s <= lookback; ++s)
     {
      const double fast_s  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s);
      const double slow_s  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s);
      const double fast_p  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, s + 1);
      const double slow_p  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, s + 1);
      if(fast_s <= 0.0 || slow_s <= 0.0 || fast_p <= 0.0 || slow_p <= 0.0)
         continue;
      if(dir > 0)
        {
         if(fast_s > slow_s && fast_p <= slow_p)
            return true;
        }
      else
        {
         if(fast_s < slow_s && fast_p >= slow_p)
            return true;
        }
     }
   return false;
  }

// Cheap O(1) per-tick gate. Spread guard only (regime/signal work is on the
// closed-bar path in Strategy_EntrySignal). Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread cap referenced to the fixed stop distance. Convert pips→price.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   // Cap: spread must not exceed 50% of the stop distance.
   if(spread > 0.0 && spread > 0.50 * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card filter: no new entries on Friday (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Confirming STATES (closed bar, shift 1) ---
   const double stoch_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stoch_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   const double rsi_now    = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(stoch_now <= 0.0 || stoch_prev <= 0.0 || rsi_now <= 0.0)
      return false;

   const double entry_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_ask <= 0.0 || entry_bid <= 0.0)
      return false;

   // --- LONG: EMA up-cross EVENT + Stoch rising & not overbought + RSI bullish ---
   if(EmaCrossedWithin(+1, strategy_cross_lookback))
     {
      const bool stoch_rising = (stoch_now > stoch_prev);
      const bool stoch_ok     = (stoch_now < strategy_stoch_ob);
      const bool rsi_ok       = (rsi_now > strategy_rsi_mid);
      if(stoch_rising && stoch_ok && rsi_ok)
        {
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry_ask, (int)strategy_sl_pips);
         if(sl <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = 0.0;   // indicator-driven exit — no fixed TP
         req.reason = "carter_ema510_stoch_rsi_long";
         return true;
        }
     }

   // --- SHORT: EMA down-cross EVENT + Stoch falling & not oversold + RSI bearish ---
   if(EmaCrossedWithin(-1, strategy_cross_lookback))
     {
      const bool stoch_falling = (stoch_now < stoch_prev);
      const bool stoch_ok      = (stoch_now > strategy_stoch_os);
      const bool rsi_ok        = (rsi_now < strategy_rsi_mid);
      if(stoch_falling && stoch_ok && rsi_ok)
        {
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry_bid, (int)strategy_sl_pips);
         if(sl <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "carter_ema510_stoch_rsi_short";
         return true;
        }
     }

   return false;
  }

// No active management beyond the fixed stop. Indicator exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Indicator-driven exit. Close a long when EMA(fast) crosses below EMA(slow)
// OR RSI crosses below the mid level. Mirror for shorts. One cross event/bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open direction for this EA's magic.
   int dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(dir == 0)
      return false;

   const double fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   const double rsi_now   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_prev  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(fast_now <= 0.0 || slow_now <= 0.0 || fast_prev <= 0.0 || slow_prev <= 0.0)
      return false;
   if(rsi_now <= 0.0 || rsi_prev <= 0.0)
      return false;

   if(dir > 0)
     {
      const bool ema_cross_down = (fast_prev >= slow_prev && fast_now < slow_now);
      const bool rsi_cross_down = (rsi_prev >= strategy_rsi_mid && rsi_now < strategy_rsi_mid);
      return (ema_cross_down || rsi_cross_down);
     }
   else
     {
      const bool ema_cross_up = (fast_prev <= slow_prev && fast_now > slow_now);
      const bool rsi_cross_up = (rsi_prev <= strategy_rsi_mid && rsi_now > strategy_rsi_mid);
      return (ema_cross_up || rsi_cross_up);
     }
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
