#property strict
#property version   "5.0"
#property description "QM5_11436 carter-t-sma150-rsi3-stoch-d1 — SMA150 trend + RSI(3) extreme + Stoch(8,3,3) cross mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11436 carter-t-sma150-rsi3-stoch-d1
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Multi-Timeframe Trading Systems" (self-published).
//         source_id b20a1c94-74f8-58a3-aeac-bfab2f1dbbf0. R1 CONDITIONAL.
// Card: artifacts/cards_approved/QM5_11436_carter-t-sma150-rsi3-stoch-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, all reads on CLOSED bars at shift >= 1):
//   Trend STATE      : close > SMA(150)  -> macro uptrend  (mirror for downtrend).
//   Oscillator STATE : RSI(3) deeply oversold (< 20) for long / overbought (>80) short.
//   Trigger EVENT    : Stochastic %K(8,3,3) crosses UP through %D from below 30 (long)
//                      / crosses DOWN through %D from above 70 (short).
//
//   The SMA150 trend and the RSI(3) extreme are STATES (level tests). The
//   Stochastic %K/%D cross is the single EVENT. Per the card NOTE this avoids the
//   "two-cross-same-bar zero-trade trap": two fresh crossovers almost never
//   coincide, so RSI is kept a state-level filter and ONLY the Stoch cross fires.
//
//   Stop  : tighter of structural swing (3-bar) stop OR entry -/+ ATR(14)*1.5.
//           "Tighter" = the stop price CLOSER to entry (higher for long, lower
//           for short). Hard-capped at strategy_stop_cap_pips (card: 150 pips).
//   Take  : entry +/- ATR(14)*3.0 (card: ~3x risk target).
//   Exit  : time stop — close after strategy_timeout_bars (5) closed bars if
//           neither SL nor TP hit (mean reversion should complete in 1-5 days).
//   Spread guard : fail-OPEN — block only a genuinely wide spread (.DWX quotes
//                  ask==bid, modeled spread 0; never block on zero spread).
//
// One position per magic. RISK_FIXED in backtest, RISK_PERCENT for live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11436;
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
input ENUM_TIMEFRAMES strategy_timeframe       = PERIOD_D1;  // card TF = D1
input int    strategy_sma_trend_period   = 150;   // SMA(150) macro trend STATE
input int    strategy_rsi_period         = 3;     // ultra-short RSI(3)
input double strategy_rsi_oversold       = 20.0;  // RSI(3) < this -> oversold STATE (long)
input double strategy_rsi_overbought     = 80.0;  // RSI(3) > this -> overbought STATE (short)
input int    strategy_stoch_k            = 8;     // Stochastic %K period
input int    strategy_stoch_d            = 3;     // Stochastic %D period
input int    strategy_stoch_slow         = 3;     // Stochastic slowing
input double strategy_stoch_lo           = 30.0;  // %K cross must be below this (long trigger zone)
input double strategy_stoch_hi           = 70.0;  // %K cross must be above this (short trigger zone)
input int    strategy_atr_period         = 14;    // ATR for stop / take
input double strategy_atr_stop_mult      = 1.5;   // ATR stop distance multiplier
input double strategy_atr_take_mult      = 3.0;   // ATR take-profit multiplier (~3R)
input int    strategy_swing_lookback     = 3;     // structural swing lookback (bars) for the stop
input int    strategy_stop_cap_pips      = 150;   // hard SL cap (card P2 cap)
input int    strategy_timeout_bars       = 5;     // close after N closed bars if no SL/TP
input bool   strategy_enable_shorts      = true;  // mirror shorts below SMA150
input double strategy_spread_pct_of_stop = 15.0;  // block only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Wrong-timeframe guard + fail-OPEN spread guard.
bool Strategy_NoTradeFilter()
  {
   // D1-native strategy: refuse to trade if attached to a non-D1 chart.
   if(_Period != strategy_timeframe)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Fail-OPEN: only a genuinely wide spread blocks; zero/negative passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Build the protective stop price: tighter (closer-to-entry) of the structural
// swing stop and the ATR stop, then hard-capped at strategy_stop_cap_pips.
double Strategy_StopPrice(const QM_OrderType side, const double entry, const double atr)
  {
   const double atr_stop = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_stop_mult);
   const double swing_stop = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);

   double stop = atr_stop;
   if(side == QM_BUY)
     {
      if(atr_stop <= 0.0 || atr_stop >= entry)
         return 0.0;
      // Tighter long stop = the HIGHER stop price (nearer to entry, smaller risk).
      if(swing_stop > 0.0 && swing_stop < entry && swing_stop > atr_stop)
         stop = swing_stop;
     }
   else
     {
      if(atr_stop <= entry)
         return 0.0;
      // Tighter short stop = the LOWER stop price (nearer to entry).
      if(swing_stop > entry && swing_stop < atr_stop)
         stop = swing_stop;
     }

   // Hard cap: never risk more than strategy_stop_cap_pips of distance.
   if(strategy_stop_cap_pips > 0)
     {
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_stop_cap_pips);
      if(cap_dist > 0.0)
        {
         if(side == QM_BUY)
           {
            const double capped = entry - cap_dist;       // farthest allowed long stop
            if(stop < capped)                              // beyond the cap -> pull in
               stop = capped;
           }
         else
           {
            const double capped = entry + cap_dist;        // farthest allowed short stop
            if(stop > capped)
               stop = capped;
           }
        }
     }

   return QM_StopRulesNormalizePrice(_Symbol, stop);
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Closed-bar reads (shift 1 = last closed bar, shift 2 = the one before).
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed-bar read
   const double sma_150 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double atr     = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double rsi_1   = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double k_1     = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k_2     = QM_Stoch_K(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   const double d_1     = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double d_2     = QM_Stoch_D(_Symbol, strategy_timeframe, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(close_1 <= 0.0 || sma_150 <= 0.0 || atr <= 0.0 || rsi_1 <= 0.0 ||
      k_1 <= 0.0 || d_1 <= 0.0)
      return false;

   // LONG: macro uptrend STATE + RSI(3) oversold STATE + Stoch %K cross-up EVENT.
   //   EVENT = %K crossed above %D on the prior closed bar (k_2 <= d_2 && k_1 > d_1),
   //           with the cross occurring in the oversold zone (k_1 < strategy_stoch_lo).
   const bool long_trend = (close_1 > sma_150);
   const bool long_rsi   = (rsi_1 < strategy_rsi_oversold);
   const bool long_event = (k_2 <= d_2 && k_1 > d_1 && k_1 < strategy_stoch_lo);
   if(long_trend && long_rsi && long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = Strategy_StopPrice(QM_BUY, entry, atr);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_take_mult);
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = (tp > entry ? tp : 0.0);
      req.reason = "carter_sma150_rsi3_stoch_long";
      return true;
     }

   // SHORT (mirror): macro downtrend STATE + RSI(3) overbought STATE + %K cross-down EVENT.
   if(strategy_enable_shorts)
     {
      const bool short_trend = (close_1 < sma_150);
      const bool short_rsi   = (rsi_1 > strategy_rsi_overbought);
      const bool short_event = (k_2 >= d_2 && k_1 < d_1 && k_1 > strategy_stoch_hi);
      if(short_trend && short_rsi && short_event)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = Strategy_StopPrice(QM_SELL, entry, atr);
         if(sl <= entry)
            return false;
         const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_take_mult);
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = (tp > 0.0 && tp < entry ? tp : 0.0);
         req.reason = "carter_sma150_rsi3_stoch_short";
         return true;
        }
     }

   return false;
  }

// Fixed ATR/structure stop + ATR take are set at entry; no active trail.
void Strategy_ManageOpenPosition()
  {
  }

// Rule exit: time stop — close after strategy_timeout_bars closed bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(strategy_timeout_bars <= 0)
      return false;

   const int seconds_per_bar = PeriodSeconds(strategy_timeframe);
   const datetime now = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(seconds_per_bar > 0 && opened > 0)
        {
         const long elapsed_seconds  = (long)(now - opened);
         const long timeout_seconds  = (long)strategy_timeout_bars * (long)seconds_per_bar;
         if(elapsed_seconds >= timeout_seconds)
            return true;
        }
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11436_carter-t-sma150-rsi3-stoch-d1\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
