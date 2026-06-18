#property strict
#property version   "5.0"
#property description "QM5_11506 carter-t-ema10-25-50-psar-m30 — Triple-EMA stack + PSAR flip trigger (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11506 carter-t-ema10-25-50-psar-m30
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//   Systems", System #1, self-published 2014.
// Card: artifacts/cards_approved/QM5_11506_carter-t-ema10-25-50-psar-m30.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one open position per magic):
//   Trend STATE  : EMA(10) > EMA(25) > EMA(50) (bullish stack) AND
//                  close[1] > EMA(10)         — full ribbon alignment.
//   Trigger EVENT: PSAR FLIP in the trend direction — the SAR dot crosses from
//                  ABOVE price (shift 2) to BELOW price (shift 1) for a long
//                  (mirror for short). The EMA stack is a STATE; the SAR flip is
//                  the single fresh EVENT, so the two-cross-same-bar zero-trade
//                  trap is avoided (only ONE thing has to "just happen").
//   Stop         : the current closed-bar SAR dot (shift 1), the standard
//                  Parabolic-SAR trailing stop. Capped at sl_cap_pips so a SAR
//                  dot that has drifted far from price cannot blow the risk.
//   Take profit  : sl_rr * SL distance via QM_TakeRR (default 2:1).
//   Defensive exit: opposite full EMA stack alignment (trend lost) closes.
//   Spread guard : block only a genuinely WIDE spread (> spread_pct_of_stop of
//                  the SAR stop distance); fail-open on .DWX zero modeled spread.
//   No-Friday-entry filter (card "No Friday entry").
//
// Symbols (all in dwx_symbol_matrix.csv — no porting needed):
//   EURUSD.DWX, GBPUSD.DWX, AUDUSD.DWX.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11506;
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
input int    strategy_ema_fast_period   = 10;     // fast EMA (ribbon top)
input int    strategy_ema_mid_period    = 25;     // mid EMA (ribbon middle)
input int    strategy_ema_slow_period   = 50;     // slow EMA (ribbon bottom)
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_max           = 0.20;   // Parabolic SAR acceleration maximum
input double strategy_sl_rr             = 2.0;    // take-profit R-multiple of stop distance
input int    strategy_sl_cap_pips       = 30;     // cap SAR stop distance (card P2 cap)
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance
input bool   strategy_no_friday_entry   = true;   // card: "No Friday entry"

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work lives in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop-distance reference for the spread cap: the SAR dot distance from the
   // closed-bar close, capped the same way the entry stop is capped.
   const double sar1  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar1 <= 0.0 || close1 <= 0.0)
      return false; // defer to entry gate — do not block on missing data

   double stop_distance = MathAbs(close1 - sar1);
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   if(cap > 0.0 && stop_distance > cap)
      stop_distance = cap;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Compute the SL price from the SAR dot, capped to strategy_sl_cap_pips.
double SarStopPrice(const QM_OrderType type, const double entry, const double sar1)
  {
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   double sl = sar1;
   if(type == QM_BUY)
     {
      // SAR sits below price for a long. If it drifted further than the cap,
      // pull the stop up to the cap distance.
      if(cap > 0.0 && (entry - sl) > cap)
         sl = entry - cap;
     }
   else
     {
      if(cap > 0.0 && (sl - entry) > cap)
         sl = entry + cap;
     }
   return QM_StopRulesNormalizePrice(_Symbol, sl);
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Card: "No Friday entry". Broker-time day-of-week of the closed bar.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- Triple EMA ribbon (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Parabolic SAR at the trigger bar (shift 1) and prior bar (shift 2) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close2   = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_now <= 0.0 || sar_prev <= 0.0 || close2 <= 0.0)
      return false;

   // --- LONG: ribbon stack 10>25>50, price above EMA10 (STATE) + SAR FLIP
   //     from above price (shift 2) to below price (shift 1) (EVENT). ---
   const bool stack_long   = (ema_fast > ema_mid && ema_mid > ema_slow && close1 > ema_fast);
   const bool sar_flip_bull = (sar_prev >= close2 && sar_now < close1);
   if(stack_long && sar_flip_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = SarStopPrice(QM_BUY, entry, sar_now);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_sl_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_ribbon_psar_long";
      return true;
     }

   // --- SHORT: ribbon stack 10<25<50, price below EMA10 (STATE) + SAR FLIP
   //     from below price (shift 2) to above price (shift 1) (EVENT). ---
   const bool stack_short   = (ema_fast < ema_mid && ema_mid < ema_slow && close1 < ema_fast);
   const bool sar_flip_bear = (sar_prev <= close2 && sar_now > close1);
   if(stack_short && sar_flip_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = SarStopPrice(QM_SELL, entry, sar_now);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_sl_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_ribbon_psar_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed SAR stop / RR target. Defensive
// exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: the opposite full EMA ribbon alignment (trend has flipped
// against the position). State check on the closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   // Determine the direction of the open position.
   bool is_long = false;
   bool found   = false;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   const bool stack_long  = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool stack_short = (ema_fast < ema_mid && ema_mid < ema_slow);

   // Close a long when the ribbon goes fully bearish; close a short on fully
   // bullish. (Opposite full stack = trend reversal against the position.)
   if(is_long && stack_short)
      return true;
   if(!is_long && stack_long)
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
