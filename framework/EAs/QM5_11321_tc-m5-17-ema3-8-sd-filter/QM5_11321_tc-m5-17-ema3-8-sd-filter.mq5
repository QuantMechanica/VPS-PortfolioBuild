#property strict
#property version   "5.0"
#property description "QM5_11321 tc-m5-17-ema3-8-sd-filter — EMA3/8 trend stack + StdDev volatility filter (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11321 tc-m5-17-ema3-8-sd-filter
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         5 Min Trading System #17 (pp. 41-42). Local PDF (R1 PASS).
// Card: artifacts/cards_approved/QM5_11321_tc-m5-17-ema3-8-sd-filter.md
//       (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1/2):
//   TRIGGER EVENT (single, per bar): EMA(3) crosses EMA(8).
//       LONG  -> EMA3 crosses ABOVE EMA8  (ema3@2 <= ema8@2  &&  ema3@1 > ema8@1)
//       SHORT -> EMA3 crosses BELOW EMA8  (ema3@2 >= ema8@2  &&  ema3@1 < ema8@1)
//   Confirming STATES (must align on the trigger bar, shift 1):
//       - Parabolic SAR(step,max) below candle (LONG) / above candle (SHORT).
//       - MACD(12,26,9) main > 0 (LONG) / < 0 (SHORT).
//       - Stochastic(10,15,15) %K above %D (LONG) / below %D (SHORT). [STATE,
//         not a second fresh cross — avoids the two-event-same-bar zero trap.]
//       - StdDev(20) in MEDIUM or STRONG volatility regime for the pair class.
//   Exit (defensive, EVENT): EMA(3) crosses back to the opposite side of EMA(8).
//   Stop: recent swing low (LONG) / swing high (SHORT), structure lookback bars.
//
// .DWX invariants observed:
//   - Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread > cap blocks).
//   - No swap gating, no external-macro CSV, no MN1.
//   - Single trigger EVENT (EMA cross); SAR/MACD/Stoch/StdDev are STATES.
//   - StdDev thresholds are in PRICE units and selected by pair class (JPY vs
//     AUD/NZD vs other) per the card; configurable via setfile.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11321;
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
input int    strategy_ema_fast_period     = 3;       // fast EMA (trigger leg)
input int    strategy_ema_slow_period     = 8;       // slow EMA (trigger leg)
input double strategy_sar_step            = 0.02;    // Parabolic SAR step
input double strategy_sar_max             = 0.2;     // Parabolic SAR maximum
input int    strategy_macd_fast           = 12;      // MACD fast EMA
input int    strategy_macd_slow           = 26;      // MACD slow EMA
input int    strategy_macd_signal         = 9;       // MACD signal SMA
input int    strategy_stoch_k             = 10;      // Stochastic %K period
input int    strategy_stoch_d             = 15;      // Stochastic %D period
input int    strategy_stoch_slowing       = 15;      // Stochastic slowing
input int    strategy_stddev_period       = 20;      // StdDev period
// Volatility regime: trade only when StdDev(period) >= the MEDIUM floor for the
// pair class. The card defines (price units): AUD/NZD med 0.0005, JPY med 0.10,
// other med 0.010. strong_only=false admits MEDIUM+STRONG (card baseline);
// strong_only=true admits STRONG only (a P3 sweep variant). Thresholds are
// exposed so the setfile can carry the correct per-symbol value.
input double strategy_stddev_med_floor    = 0.010;   // MEDIUM-regime StdDev floor (price units)
input double strategy_stddev_strong_floor = 0.020;   // STRONG-regime StdDev floor (price units)
input bool   strategy_strong_only         = false;   // false=med+strong, true=strong-only
input int    strategy_swing_lookback      = 10;      // swing stop lookback (closed bars)
input double strategy_spread_pts_cap      = 20.0;    // skip if modeled spread > this many points

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// only a genuinely wide spread (> cap points, with ask>bid) blocks.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero quote

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double spread_price = ask - bid;
   const double cap_price    = strategy_spread_pts_cap * point;
   // Block ONLY a genuinely wide spread. Zero/negative modeled spread passes
   // (.DWX quotes ask==bid in the tester).
   if(ask > bid && spread_price > 0.0 && spread_price > cap_price)
      return true;

   return false;
  }

// Volatility regime gate. Returns true if StdDev(period) qualifies for the
// configured regime (MEDIUM+STRONG, or STRONG-only). StdDev is in price units.
bool Vol_RegimeOk(const double std_dev)
  {
   if(std_dev <= 0.0)
      return false;
   if(strategy_strong_only)
      return (std_dev >= strategy_stddev_strong_floor);
   return (std_dev >= strategy_stddev_med_floor);
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// One trigger EVENT (EMA3/8 cross) + confirming STATES on the trigger bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- EMA legs at shift 1 (signal bar) and shift 2 (prior bar) ---
   const double ema_f1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_s1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_f2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_s2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_f1 <= 0.0 || ema_s1 <= 0.0 || ema_f2 <= 0.0 || ema_s2 <= 0.0)
      return false;

   // TRIGGER EVENT: a fresh EMA3/8 cross on the signal bar (single event/bar).
   const bool cross_up   = (ema_f2 <= ema_s2 && ema_f1 >  ema_s1);
   const bool cross_down = (ema_f2 >= ema_s2 && ema_f1 <  ema_s1);
   if(!cross_up && !cross_down)
      return false;

   // --- Confirming STATES (read once at shift 1) ---
   const double sar1   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double macd1  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double stk1   = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double std1   = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double stddev = QM_StdDev(_Symbol, _Period, strategy_stddev_period, 1);

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read for SAR position
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read for SAR position
   if(high1 <= 0.0 || low1 <= 0.0 || sar1 <= 0.0)
      return false;

   // Volatility regime STATE — required for both directions.
   if(!Vol_RegimeOk(stddev))
      return false;

   if(cross_up)
     {
      // SAR below candle, MACD>0, Stoch %K above %D.
      if(!(sar1 < low1))     return false;
      if(!(macd1 > 0.0))     return false;
      if(!(stk1 > std1))     return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopStructure(_Symbol, QM_BUY, entry, strategy_swing_lookback);
      if(sl <= 0.0 || sl >= entry)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // managed by EMA-cross exit, no fixed TP
      req.reason = "ema38_stack_long";
      return true;
     }

   if(cross_down)
     {
      // SAR above candle, MACD<0, Stoch %K below %D.
      if(!(sar1 > high1))    return false;
      if(!(macd1 < 0.0))     return false;
      if(!(stk1 < std1))     return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopStructure(_Symbol, QM_SELL, entry, strategy_swing_lookback);
      if(sl <= 0.0 || sl <= entry)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ema38_stack_short";
      return true;
     }

   return false;
  }

// No active management beyond the structure stop; exit is the EMA-cross flip.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(3) crosses back to the opposite side of EMA(8).
// Direction-aware: close a LONG on a down-cross, a SHORT on an up-cross.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_f1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_s1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_f1 <= 0.0 || ema_s1 <= 0.0)
      return false;

   // Determine the open position's direction for this magic on this symbol.
   bool have_long = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
     }

   // Close LONG when EMA3 < EMA8; close SHORT when EMA3 > EMA8 (card exit rule).
   if(have_long && ema_f1 < ema_s1)
      return true;
   if(have_short && ema_f1 > ema_s1)
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
