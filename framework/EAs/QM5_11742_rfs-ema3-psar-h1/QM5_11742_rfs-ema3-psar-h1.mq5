#property strict
#property version   "5.0"
#property description "QM5_11742 rfs-ema3-psar-h1 — Triple-EMA(6/11/34) order + PSAR flip (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11742 rfs-ema3-psar-h1
// -----------------------------------------------------------------------------
// Source: Anonymous, "Parabolic SAR and EMA", Robo-forex Strategy Compilation
//         (robofx.com, ~2015), pp. 55-56.
// Card: artifacts/cards_approved/QM5_11742_rfs-ema3-psar-h1.md (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1/2):
//   Trend STATE  : Triple EMA ordered. Bullish = EMA(fast) > EMA(mid) > EMA(slow).
//                  Bearish = EMA(fast) < EMA(mid) < EMA(slow). A persistent STATE,
//                  not an event — no EMA cross required (avoids two-cross trap).
//   Trigger EVENT: Parabolic SAR FLIP — the single fresh event on the bar.
//                  Bullish flip: SAR[2] > Close[2] AND SAR[1] <= Close[1].
//                  Bearish flip: SAR[2] < Close[2] AND SAR[1] >= Close[1].
//   Entry        : trend STATE aligned with the SAR flip direction on the closed
//                  bar; framework opens at next-bar open (market send).
//   Stop         : entry +/- sl_atr_mult * ATR (factory default 2xATR).
//   Take profit  : entry +/- tp_atr_mult * ATR (factory safety cap 3xATR).
//   Exit (EVENT) : Parabolic SAR flips opposite (card option 2, factory default).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// One position per symbol/magic. Only the 5 Strategy_* hooks + Strategy inputs
// are EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11742;
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
input int    strategy_ema_fast_period   = 6;     // fastest EMA (trend order)
input int    strategy_ema_mid_period    = 11;    // medium EMA (trend order)
input int    strategy_ema_slow_period   = 34;    // slowest EMA (trend order)
input double strategy_sar_step          = 0.1;   // Parabolic SAR step (card)
input double strategy_sar_max           = 0.2;   // Parabolic SAR max (standard)
input int    strategy_atr_period        = 14;    // ATR period (stop / target)
input double strategy_sl_atr_mult       = 2.0;   // stop distance  = mult * ATR
input double strategy_tp_atr_mult       = 3.0;   // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
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

// Triple-EMA order STATE + Parabolic SAR flip EVENT. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate). One position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Triple-EMA order STATE (closed bar, shift 1) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_mid  = QM_EMA(_Symbol, _Period, strategy_ema_mid_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_mid <= 0.0 || ema_slow <= 0.0)
      return false;

   const bool bull_stack = (ema_fast > ema_mid && ema_mid > ema_slow);
   const bool bear_stack = (ema_fast < ema_mid && ema_mid < ema_slow);
   if(!bull_stack && !bear_stack)
      return false; // EMAs not cleanly ordered — no trade

   // --- Parabolic SAR flip EVENT (the single fresh trigger on this bar) ---
   const double sar_1   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_2   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_1 <= 0.0 || sar_2 <= 0.0 || close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   // Bullish flip: SAR was above price (bar 2), now at/below price (bar 1).
   const bool sar_flip_up   = (sar_2 > close_2 && sar_1 <= close_1);
   // Bearish flip: SAR was below price (bar 2), now at/above price (bar 1).
   const bool sar_flip_down = (sar_2 < close_2 && sar_1 >= close_1);

   QM_OrderType dir;
   if(bull_stack && sar_flip_up)
      dir = QM_BUY;
   else if(bear_stack && sar_flip_down)
      dir = QM_SELL;
   else
      return false;

   // --- Build entry. Framework sizes lots (no lots field). ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "ema3_psar_long" : "ema3_psar_short";
   return true;
  }

// No active management beyond the fixed ATR stop/target. SAR-flip exit lives
// in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// SAR-flip exit (card option 2, factory default): close when the Parabolic SAR
// flips against the open position. One event at shift 1 vs shift 2.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sar_1   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_2   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   const double close_1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(sar_1 <= 0.0 || sar_2 <= 0.0 || close_1 <= 0.0 || close_2 <= 0.0)
      return false;

   const bool sar_flip_up   = (sar_2 > close_2 && sar_1 <= close_1);
   const bool sar_flip_down = (sar_2 < close_2 && sar_1 >= close_1);

   // Determine the direction of the open position for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && sar_flip_down)
         return true;  // long open, SAR flipped down -> exit
      if(ptype == POSITION_TYPE_SELL && sar_flip_up)
         return true;  // short open, SAR flipped up -> exit
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
