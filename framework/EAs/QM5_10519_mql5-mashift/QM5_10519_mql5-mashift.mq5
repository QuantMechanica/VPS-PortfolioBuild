#property strict
#property version   "5.0"
#property description "QM5_10519 MQL5 MA Shift Puria — same-direction MA movement + MACD zero confirmation + MA distance"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10519 MA Shift Puria (mql5-mashift)
// -----------------------------------------------------------------------------
// Source: work2it / Sergey Deev "ma-shift Puria method", MQL5 CodeBase
//   https://www.mql5.com/en/code/19578  (b8b5125a-c67f-5bbc-baff-33456e08f5b2)
//
// Mechanic (H1 closed bars):
//   - The EA does NOT use fast/slow MA intersection. It uses their MOVEMENT in
//     one direction, confirmed by MACD crossing/holding its zero level, and by
//     the vertical distance between fast and slow MA measured in pips.
//   Long :
//     * Fast MA and Slow MA both moving UP   (MA[1] > MA[2] for both).
//     * MACD main confirmed ABOVE zero (>0 now, and a recent below->above
//       cross holds — state above zero).
//     * |FastMA[1] - SlowMA[1]| >= ma_shift_pips (as a price distance).
//   Short: mirror (both moving DOWN, MACD below zero, distance >= threshold).
//   Exit : SL = atr_sl_mult * ATR(atr_period), TP = tp_rr * R, plus close on a
//          full OPPOSITE signal.
//   One position per symbol/magic (framework single-entry path sizes lots).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10519;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Moving averages (same-direction movement signal). Source applies a Puria
// fast/slow pair on H1; default fast 6 / slow 14 keeps the original spirit.
input int    strategy_fast_ma_period    = 6;     // Fast MA period
input int    strategy_slow_ma_period    = 14;    // Slow MA period
// MACD zero-level confirmation. Classic 12/26/9 Puria confirmation.
input int    strategy_macd_fast         = 12;    // MACD fast EMA period
input int    strategy_macd_slow         = 26;    // MACD slow EMA period
input int    strategy_macd_signal       = 9;     // MACD signal period
// Minimum vertical distance between fast and slow MA, in pips.
input int    strategy_ma_shift_pips     = 5;     // Min |FastMA-SlowMA| in pips
// MACD "recent confirmed cross" lookback (bars). One side is the trigger
// state; we require the zero-cross to have happened within this window OR the
// MACD to remain on the confirmed side. Avoids requiring two same-bar events.
input int    strategy_macd_cross_lookback = 6;   // MACD zero-cross hold window
// Exit controls.
input int    strategy_atr_period        = 14;    // ATR period for stop
input double strategy_atr_sl_mult       = 1.5;   // SL = mult * ATR
input double strategy_tp_rr             = 1.5;   // TP = rr * risk

// -----------------------------------------------------------------------------
// Strategy helpers (closed-bar reads; shift 1 = last closed bar).
// -----------------------------------------------------------------------------

// MACD main is "confirmed above zero": positive now AND a below->above zero
// cross occurred within the lookback window OR it has simply held above zero.
// We treat "currently above zero" as the held state and additionally allow a
// fresh cross within the window. A single zero-level state is the trigger; the
// MA-direction + distance are the co-conditions (no two same-bar events).
bool MACD_ConfirmedAboveZero()
  {
   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, 1);
   if(macd_now <= 0.0)
      return false;
   // Held above zero across the lookback window, or crossed up within it.
   for(int s = 2; s <= strategy_macd_cross_lookback + 1; ++s)
     {
      const double v = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                    strategy_macd_fast, strategy_macd_slow,
                                    strategy_macd_signal, s);
      if(v <= 0.0)
         return true; // a below->above transition exists within the window
     }
   return true; // held strictly above zero across the window
  }

bool MACD_ConfirmedBelowZero()
  {
   const double macd_now = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                        strategy_macd_fast, strategy_macd_slow,
                                        strategy_macd_signal, 1);
   if(macd_now >= 0.0)
      return false;
   for(int s = 2; s <= strategy_macd_cross_lookback + 1; ++s)
     {
      const double v = QM_MACD_Main(_Symbol, PERIOD_CURRENT,
                                    strategy_macd_fast, strategy_macd_slow,
                                    strategy_macd_signal, s);
      if(v >= 0.0)
         return true;
     }
   return true;
  }

// Both MAs move up (read displaced bars via the reader's shift arg).
bool MAs_MovingUp()
  {
   const double fast_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_ma_period, 1);
   const double fast_2 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_ma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_ma_period, 1);
   const double slow_2 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_ma_period, 2);
   return (fast_1 > fast_2 && slow_1 > slow_2);
  }

bool MAs_MovingDown()
  {
   const double fast_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_ma_period, 1);
   const double fast_2 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_ma_period, 2);
   const double slow_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_ma_period, 1);
   const double slow_2 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_ma_period, 2);
   return (fast_1 < fast_2 && slow_1 < slow_2);
  }

// |FastMA - SlowMA| on the last closed bar >= ma_shift_pips (pip-scaled).
bool MA_DistanceMet()
  {
   const double fast_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_fast_ma_period, 1);
   const double slow_1 = QM_SMA(_Symbol, PERIOD_CURRENT, strategy_slow_ma_period, 1);
   const double dist   = MathAbs(fast_1 - slow_1);
   const double min_d  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_ma_shift_pips);
   return (dist >= min_d);
  }

bool LongSignal()
  {
   return (MAs_MovingUp() && MACD_ConfirmedAboveZero() && MA_DistanceMet());
  }

bool ShortSignal()
  {
   return (MAs_MovingDown() && MACD_ConfirmedBelowZero() && MA_DistanceMet());
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Only one position per magic for the V5 baseline.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const bool go_long  = LongSignal();
   const bool go_short = ShortSignal();
   if(go_long == go_short) // none, or (defensively) both → no trade
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);

   req.type   = side;
   req.price  = 0.0;   // market fill at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "mashift_long" : "mashift_short";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline: fixed SL/TP only; no break-even / trailing.
  }

bool Strategy_ExitSignal()
  {
   // Close on a full opposite signal.
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

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
      if(ptype == POSITION_TYPE_BUY && ShortSignal())
         return true;
      if(ptype == POSITION_TYPE_SELL && LongSignal())
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
