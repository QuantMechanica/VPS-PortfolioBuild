#property strict
#property version   "5.0"
#property description "QM5_10997 the5ers-ema-rsi-stoch — EMA(5/10) cross + RSI + Stochastic (two-sided, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10997 the5ers-ema-rsi-stoch
// -----------------------------------------------------------------------------
// Source: The5ers blog "Simple Trading Strategy: Cross Over Moving Average"
//         https://the5ers.com/simple-trading-strategy/  (Updated 2020-01-10).
// Card: artifacts/cards_approved/QM5_10997_the5ers-ema-rsi-stoch.md (g0 APPROVED).
//
// Mechanics (two-sided, closed-bar reads at shift 1/2):
//   EMA cross EVENT (trigger): EMA(fast) crosses EMA(slow) at the closed bar.
//   RSI STATE  : RSI(period)[1] above/below the rsi_level for long/short.
//   Stoch STATE: Stoch %K[1] rising/falling AND within the [oversold, overbought]
//                cap band ("moves up but not over 80" / "moves down but not below 20").
//   Long entry : EMA(fast) crosses ABOVE EMA(slow) + RSI[1] > rsi_level
//                + K[1] > K[2] + K[1] < overbought_cap.
//   Short entry: EMA(fast) crosses BELOW EMA(slow) + RSI[1] < rsi_level
//                + K[1] < K[2] + K[1] > oversold_cap.
//   Stop       : entry -/+ sl_atr_mult * ATR(period) (catastrophic SL, always on).
//   Signal exit: reverse EMA cross OR RSI crossing back over rsi_level.
//   Time stop  : close after time_stop_bars closed H1 bars.
//   Spread guard: skip only a genuinely wide spread > spread_pct_of_stop of the
//                 stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10997;
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
input int    strategy_ema_fast_period     = 5;      // fast EMA period
input int    strategy_ema_slow_period     = 10;     // slow EMA period
input int    strategy_rsi_period          = 14;     // RSI lookback period
input double strategy_rsi_level           = 50.0;   // RSI directional threshold
input int    strategy_stoch_k_period      = 14;     // Stochastic %K period
input int    strategy_stoch_d_period      = 3;      // Stochastic %D period
input int    strategy_stoch_slowing       = 3;      // Stochastic slowing
input double strategy_stoch_overbought    = 80.0;   // long cap: K must be below this
input double strategy_stoch_oversold      = 20.0;   // short cap: K must be above this
input int    strategy_atr_period          = 14;     // ATR period for the stop
input double strategy_sl_atr_mult         = 2.0;    // stop distance = mult * ATR
input int    strategy_time_stop_bars      = 48;     // close after N closed H1 bars
input double strategy_spread_pct_of_stop  = 15.0;   // skip if spread > this % of stop

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
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

// Two-sided entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA values at the two most recent closed bars ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   // --- RSI at the last closed bar ---
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   // --- Stochastic %K at the two most recent closed bars ---
   const double stoch_k_1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                       strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double stoch_k_2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period,
                                       strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(stoch_k_1 <= 0.0 || stoch_k_2 <= 0.0)
      return false;

   // --- Long: fresh upward EMA cross + RSI above level + Stoch rising under cap ---
   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);

   bool go_long  = false;
   bool go_short = false;

   if(cross_up &&
      rsi_1 > strategy_rsi_level &&
      stoch_k_1 > stoch_k_2 &&
      stoch_k_1 < strategy_stoch_overbought)
      go_long = true;
   else if(cross_down &&
           rsi_1 < strategy_rsi_level &&
           stoch_k_1 < stoch_k_2 &&
           stoch_k_1 > strategy_stoch_oversold)
      go_short = true;

   if(!go_long && !go_short)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(go_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — signal/time exits + catastrophic SL
      req.reason = "ema_rsi_stoch_long";
      return true;
     }

   // go_short
   const double entry_s = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_s <= 0.0)
      return false;
   const double sl_s = QM_StopATRFromValue(_Symbol, QM_SELL, entry_s, atr_value, strategy_sl_atr_mult);
   if(sl_s <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl_s;
   req.tp     = 0.0;
   req.reason = "ema_rsi_stoch_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exits in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Signal exit (direction-aware) + time stop:
//   Long  : reverse EMA cross down  OR  RSI back below level.
//   Short : reverse EMA cross up    OR  RSI back above level.
//   Either: position held >= time_stop_bars closed H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int seconds = PeriodSeconds(_Period);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      // --- Time stop ---
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_stop_bars > 0 && seconds > 0 && open_time > 0 &&
         TimeCurrent() - open_time >= (long)strategy_time_stop_bars * seconds)
         return true;

      // --- Signal exit (closed-bar reads) ---
      const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
      const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
      const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
      const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
      const double rsi_1      = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
      if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 ||
         ema_slow_2 <= 0.0 || rsi_1 <= 0.0)
         continue;

      const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 > ema_slow_1);
      const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 < ema_slow_1);

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(cross_down || rsi_1 < strategy_rsi_level)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         if(cross_up || rsi_1 > strategy_rsi_level)
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
