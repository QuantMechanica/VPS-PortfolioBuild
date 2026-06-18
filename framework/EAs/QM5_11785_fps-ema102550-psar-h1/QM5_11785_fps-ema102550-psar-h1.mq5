#property strict
#property version   "5.0"
#property description "QM5_11785 fps-ema102550-psar-h1 — Forex Profit System: triple-EMA stack + PSAR flip trigger (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11785 fps-ema102550-psar-h1
// -----------------------------------------------------------------------------
// Source: 'Forex Profit System (FPS)', in *Forex Systems* (~2006), pp.5-7.
// Card: artifacts/cards_approved/QM5_11785_fps-ema102550-psar-h1.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one open position per magic):
//   Trend STATE  : EMA(10) > EMA(25) > EMA(50) (bullish stack) AND
//                  close[1] > EMA(10)         — full ribbon alignment.
//                  (mirror for the bearish stack / short.)
//   Trigger EVENT: PSAR FLIP in the trend direction — the SAR dot crosses from
//                  ABOVE price (shift 2) to BELOW price (shift 1) for a long
//                  (mirror for short). The EMA stack is a STATE; the SAR flip is
//                  the single fresh EVENT, so the two-cross-same-bar zero-trade
//                  trap is avoided (only ONE thing has to "just happen").
//   Stop         : entry -/+ sl_atr_mult * ATR(14)  (card factory default 2xATR;
//                  source places the stop just below EMA(50)).
//   Take profit  : entry +/- tp_atr_mult * ATR(14)  (card factory fallback cap
//                  4xATR; the real exit is the structural EMA/PSAR exit below).
//   Exit         : EITHER the closed-bar price crosses back through ALL THREE
//                  EMAs against the position (card primary exit) OR the PSAR
//                  flips against the position (card "whichever triggers first").
//   Spread guard : block only a genuinely WIDE spread (> spread_pct_of_stop of
//                  the ATR stop distance); fail-open on .DWX zero modeled spread.
//
// Symbols (all in dwx_symbol_matrix.csv — no porting needed):
//   EURUSD.DWX, GBPUSD.DWX, USDCHF.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11785;
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
input int    strategy_ema_fast_period   = 10;     // fast EMA (ribbon top / trigger line)
input int    strategy_ema_mid_period    = 25;     // mid EMA (ribbon middle)
input int    strategy_ema_slow_period   = 50;     // slow EMA (ribbon bottom)
input double strategy_sar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_sar_max           = 0.20;   // Parabolic SAR acceleration maximum
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult       = 4.0;    // target distance = mult * ATR (fallback cap)
input double strategy_spread_pct_of_stop = 15.0;  // block if spread > this % of stop distance

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

   // Stop-distance reference for the spread cap: the ATR stop distance.
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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG: ribbon stack 10>25>50, price above EMA10 (STATE) + SAR FLIP
   //     from above price (shift 2) to below price (shift 1) (EVENT). ---
   const bool stack_long    = (ema_fast > ema_mid && ema_mid > ema_slow && close1 > ema_fast);
   const bool sar_flip_bull = (sar_prev >= close2 && sar_now < close1);
   if(stack_long && sar_flip_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_ema_psar_long";
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
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "fps_ema_psar_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / target. The structural
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Exit: card primary = price crosses back through ALL THREE EMAs against the
// position; card alternative = PSAR flips against the position. "Whichever
// triggers first." State/event checks on the closed bar (shift 1).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
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

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0 || close1 <= 0.0)
      return false;

   // Primary exit: closed-bar price has crossed back through ALL THREE EMAs
   // against the position.
   const bool below_all = (close1 < ema_fast && close1 < ema_mid && close1 < ema_slow);
   const bool above_all = (close1 > ema_fast && close1 > ema_mid && close1 > ema_slow);
   if(is_long && below_all)
      return true;
   if(!is_long && above_all)
      return true;

   // Alternative exit: PSAR has flipped against the position (event on the
   // closed bar). For a long, SAR moves from below price (shift 2) to above
   // price (shift 1); mirror for a short.
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close2   = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_now <= 0.0 || sar_prev <= 0.0 || close2 <= 0.0)
      return false;

   const bool sar_flip_bear = (sar_prev <= close2 && sar_now > close1); // flip against a long
   const bool sar_flip_bull = (sar_prev >= close2 && sar_now < close1); // flip against a short
   if(is_long && sar_flip_bear)
      return true;
   if(!is_long && sar_flip_bull)
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
