#property strict
#property version   "5.0"
#property description "QM5_11546 carter-t-m5-macd1226-stoch533-ema5oc — Stoch(5,3,3) OS-recovery trigger + MACD/EMA5(open vs close) states (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11546 carter-t-m5-macd1226-stoch533-ema5oc
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #1, self-published 2014. Card:
//   artifacts/cards_approved/QM5_11546_carter-t-m5-macd1226-stoch533-ema5oc.md
//   (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1):
//   Trigger EVENT (exactly one) :
//     LONG  — Stochastic %K recovers out of oversold: K[2] < os_level AND
//             K[1] >= os_level (a single fresh upward cross of the OS line).
//     SHORT — Stochastic %K falls out of overbought: K[2] > ob_level AND
//             K[1] <= ob_level.
//   Confirming STATES (currently-true, never a second event on the same bar):
//     - MACD momentum : LONG MACD_main[1] > MACD_main[2]   (bar-over-bar rising)
//                       SHORT MACD_main[1] < MACD_main[2]
//     - EMA5 micro-channel : LONG  EMA5(close)[1] > EMA5(open)[1]
//                            SHORT EMA5(close)[1] < EMA5(open)[1]
//     - Signal candle : LONG  close[1] > open[1] (bullish)
//                       SHORT close[1] < open[1] (bearish)
//   Stop          : fixed sl_pips (card 20p; P2 cap 25p) via QM_StopFixedPips.
//   No fixed TP   : the position is closed by the indicator exit below.
//   Indicator exit: EMA5(close) crosses back below EMA5(open) for a long
//                   (above for a short) — ONE cross event, exit only.
//   Spread guard  : block only a genuinely WIDE spread vs the stop distance.
//                   Fail-open on .DWX zero-modeled spread.
//   Friday entries: optionally suppressed (card filter "No Friday entry").
//
// Why this avoids the two-cross zero-trade trap: only the Stochastic OS/OB
// recovery is treated as an EVENT. MACD, EMA5(close/open) and the signal-candle
// colour are read as STATES (their current relationship), not as fresh crosses,
// so two cross EVENTS are never required on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11546;
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
input int    strategy_stoch_k           = 5;      // Stochastic %K period
input int    strategy_stoch_d           = 3;      // Stochastic %D period
input int    strategy_stoch_slow        = 3;      // Stochastic slowing
input double strategy_stoch_os          = 20.0;   // oversold line (long trigger)
input double strategy_stoch_ob          = 80.0;   // overbought line (short trigger)
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 1;      // MACD signal period (card: 1)
input int    strategy_ema_period        = 5;      // EMA period for open/close channel
input int    strategy_sl_pips           = 20;     // fixed stop distance in pips
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance
input bool   strategy_allow_short       = true;   // enable symmetric short side
input bool   strategy_no_friday_entry   = true;   // card filter: no new entry on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; signal work is on the closed bar.
// Fail-open on .DWX zero modeled spread (ask==bid in the tester).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
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

   // Card filter: no new entry on Friday (broker time).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Stochastic %K (closed bars). Trigger EVENT = recovery out of OS/OB. ---
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k_now < 0.0 || k_prev < 0.0)
      return false;

   // --- MACD main, bar-over-bar momentum STATE. ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1, PRICE_CLOSE);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 2, PRICE_CLOSE);

   // --- EMA5(close) vs EMA5(open) micro-channel STATE (closed bar). ---
   const double ema5c = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double ema5o = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_OPEN);
   if(ema5c <= 0.0 || ema5o <= 0.0)
      return false;

   // --- Signal-candle colour STATE (last closed bar). ---
   const double open1  = iOpen(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(open1 <= 0.0 || close1 <= 0.0)
      return false;

   // --- LONG: Stoch recovers out of oversold + MACD rising + bullish channel + bullish candle ---
   const bool long_trigger = (k_prev < strategy_stoch_os && k_now >= strategy_stoch_os);
   if(long_trigger &&
      macd_now > macd_prev &&        // momentum rising
      ema5c > ema5o &&               // micro-channel bullish
      close1 > open1)                // signal candle bullish
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — indicator exit closes the position
      req.reason = "carter_m5_stoch_recover_long";
      return true;
     }

   // --- SHORT: symmetric. ---
   if(strategy_allow_short)
     {
      const bool short_trigger = (k_prev > strategy_stoch_ob && k_now <= strategy_stoch_ob);
      if(short_trigger &&
         macd_now < macd_prev &&     // momentum falling
         ema5c < ema5o &&            // micro-channel bearish
         close1 < open1)             // signal candle bearish
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
         if(sl <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "carter_m5_stoch_recover_short";
         return true;
        }
     }

   return false;
  }

// Fixed stop only; no active trailing/BE. Indicator exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Indicator exit: EMA5(close) crosses back across EMA5(open) against the
// open position's direction. ONE cross event at shift 1 (uses closed bars 1/2).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double c_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_CLOSE);
   const double o_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1, PRICE_OPEN);
   const double c_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2, PRICE_CLOSE);
   const double o_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 2, PRICE_OPEN);
   if(c_now <= 0.0 || o_now <= 0.0 || c_prev <= 0.0 || o_prev <= 0.0)
      return false;

   // Determine direction of the open position for this magic.
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

   // Long exit: EMA5(close) crosses DOWN below EMA5(open).
   if(have_long)
     {
      const bool crossed_down = (c_prev >= o_prev && c_now < o_now);
      if(crossed_down)
         return true;
     }
   // Short exit: EMA5(close) crosses UP above EMA5(open).
   if(have_short)
     {
      const bool crossed_up = (c_prev <= o_prev && c_now > o_now);
      if(crossed_up)
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
