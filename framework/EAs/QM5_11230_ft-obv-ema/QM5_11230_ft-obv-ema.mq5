#property strict
#property version   "5.0"
#property description "QM5_11230 ft-obv-ema — EMA(20) cross + OBV direction confirmation (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11230 ft-obv-ema
// -----------------------------------------------------------------------------
// Source: Freqtrade community "TrendFollowingStrategy" (freqtrade/freqtrade-
//   strategies, commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4).
// Card: artifacts/cards_approved/QM5_11230_ft-obv-ema.md (g0_status APPROVED).
//
// Mechanics (M5 base TF, closed-bar reads at shift 1):
//   Trend STATE  : EMA(ema_period) on close, closed bar.
//   OBV          : computed in-EA from tick volume (no QM_OBV reader exists).
//                  bar-direction x tick volume, advanced ONE step per closed
//                  bar (no per-tick re-sum, no full-history loop):
//                    if close[1] > close[2]: obv += volume[1]
//                    if close[1] < close[2]: obv -= volume[1]
//                  g_obv = current OBV (through shift 1); g_obv_prev = prior.
//   Long EVENT   : close crosses up through EMA(20)  (close[2] <= ema[2] AND
//                  close[1] > ema[1]) AND OBV higher than prior bar OBV.
//   Short EVENT  : close crosses down through EMA(20) (close[2] >= ema[2] AND
//                  close[1] < ema[1]) AND OBV lower than prior bar OBV.
//   Stop         : 3.0 * ATR(14) emergency stop (V5 baseline; source -26.5%
//                  percentage stop is far wider, so the ATR stop is the tighter
//                  of the two per the card's "tighter of" instruction).
//   Take profit  : sl_atr_mult-derived RR target (deterministic ladder proxy
//                  for the non-monotonic Freqtrade ROI table).
//   Exit         : opposite EMA cross with confirming OBV direction (mirrors
//                  entry), in addition to the fixed SL/TP.
//   Spread guard : skip only a genuinely wide spread > spread_pct_of_stop of
//                  the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11230;
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
input int    strategy_ema_period        = 20;     // trend EMA period (close crosses this)
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 3.0;    // emergency stop distance = mult * ATR
input double strategy_tp_rr             = 1.5;    // take-profit reward-to-risk multiple
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// In-EA OBV state (no QM_OBV reader exists). Advanced ONE step per closed bar
// inside the closed-bar gate (Strategy_EntrySignal is called once per new bar
// by the framework). Both entry and exit read the cached values — never re-sum.
// -----------------------------------------------------------------------------
double   g_obv          = 0.0;   // OBV through the last closed bar (shift 1)
double   g_obv_prev     = 0.0;   // OBV through the bar before that (shift 2)
datetime g_obv_last_bar = 0;     // open-time of the closed bar OBV was advanced to

// Advance OBV by exactly ONE closed bar if a new bar has formed. Idempotent:
// re-entry on the same closed bar is a no-op. close[1]/volume[1] = the just-
// closed bar; compare close[1] vs close[2] for the bar direction.
void OBV_AdvanceClosedBar()
  {
   const datetime bar1_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar timestamp
   if(bar1_time <= 0)
      return;
   if(bar1_time == g_obv_last_bar)
      return; // already advanced to this closed bar

   const double close1 = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   const double vol1   = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar tick volume
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   g_obv_prev = g_obv;
   if(close1 > close2)
      g_obv += vol1;
   else if(close1 < close2)
      g_obv -= vol1;
   // close1 == close2 -> OBV unchanged (standard OBV convention).

   g_obv_last_bar = bar1_time;
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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate), so this is
// the single place OBV state is advanced once per closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Advance OBV exactly once for this new closed bar (single-consume, no re-sum).
   OBV_AdvanceClosedBar();

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend EMA at shift 1 and shift 2 (for the cross EVENT) ---
   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // OBV direction vs prior bar (cached, advanced above).
   const bool obv_up   = (g_obv > g_obv_prev);
   const bool obv_down = (g_obv < g_obv_prev);

   // --- Long EVENT: close crosses up through EMA + OBV rising ---
   const bool cross_up   = (close2 <= ema2 && close1 > ema1);
   // --- Short EVENT: close crosses down through EMA + OBV falling ---
   const bool cross_down = (close2 >= ema2 && close1 < ema1);

   if(cross_up && obv_up)
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
      req.reason = "obv_ema_cross_long";
      return true;
     }

   if(cross_down && obv_down)
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
      req.reason = "obv_ema_cross_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop / RR target. The
// opposite-cross defensive exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: opposite EMA cross with confirming OBV direction. Reads the
// OBV state cached by the entry hook (advanced once per closed bar) — no re-sum.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema1 = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema2 = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(ema1 <= 0.0 || ema2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const bool obv_up   = (g_obv > g_obv_prev);
   const bool obv_down = (g_obv < g_obv_prev);

   // Determine the direction of the open position to mirror the source's
   // "close long when close crosses below EMA" / "close short when above".
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   const bool cross_down = (close2 >= ema2 && close1 < ema1);
   const bool cross_up   = (close2 <= ema2 && close1 > ema1);

   // Close long on a down-cross confirmed by falling OBV.
   if(is_long && cross_down && obv_down)
      return true;
   // Close short on an up-cross confirmed by rising OBV.
   if(is_short && cross_up && obv_up)
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

   // Reset in-EA OBV accumulator for a clean run.
   g_obv          = 0.0;
   g_obv_prev     = 0.0;
   g_obv_last_bar = 0;

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
