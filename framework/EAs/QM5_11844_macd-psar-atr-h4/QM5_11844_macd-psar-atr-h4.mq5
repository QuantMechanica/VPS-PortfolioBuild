#property strict
#property version   "5.0"
#property description "QM5_11844 macd-psar-atr-h4 — MACD zero-cross + PSAR confirm, ATR stop (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11844 macd-psar-atr-h4
// -----------------------------------------------------------------------------
// Source: Anon., 'MACD Trend Forex Trading Strategy With Parabolic SAR and ATR'
//         (Scribd ~2018). Card: artifacts/cards_approved/
//         QM5_11844_macd-psar-atr-h4.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar reads at shift 1; one position per magic):
//   Trigger EVENT : MACD(12,26,9) main line crosses zero (one event per bar).
//                     long  -> main[2] <= 0  AND  main[1] > 0
//                     short -> main[2] >= 0  AND  main[1] < 0
//   Confirm STATE : PSAR(0.02,0.2) aligned with the trade direction on the
//                   trigger bar (closed-bar shift 1).
//                     long  -> SAR[1] < close[1]   (dots below price)
//                     short -> SAR[1] > close[1]   (dots above price)
//   Stop          : QM_StopATR — entry -/+ sl_atr_mult * ATR(14).
//   Take profit   : QM_TakeRR — minimum 1:2 RR per the source (tp_rr default 2.0).
//   Trailing exit : PSAR trailing — SL chased to the current PSAR value each
//                   new closed bar once it is more protective than the live SL.
//   Defensive exit: PSAR flips against the open position -> close at market.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// The MACD zero-cross is the SINGLE trigger event. PSAR is a STATE, not a second
// event — this avoids the two-cross-same-bar zero-trade trap (build_ea rule #4).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11844;
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
input int    strategy_macd_fast         = 12;     // MACD fast EMA period
input int    strategy_macd_slow         = 26;     // MACD slow EMA period
input int    strategy_macd_signal       = 9;      // MACD signal period (unused by zero-cross trigger but kept canonical)
input double strategy_psar_step         = 0.02;   // Parabolic SAR acceleration step
input double strategy_psar_max          = 0.20;   // Parabolic SAR acceleration max
input int    strategy_atr_period        = 14;     // ATR period (stop sizing)
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 2.0;    // take-profit reward:risk (source min 1:2)
input bool   strategy_psar_trail        = true;   // trail SL to PSAR each new bar
input bool   strategy_psar_flip_exit    = true;   // close on PSAR flip against position
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry: MACD main-line zero-cross EVENT confirmed by aligned PSAR STATE.
// Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: MACD main line crosses zero (one event per bar) ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 2);

   const bool cross_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool cross_down = (macd_prev >= 0.0 && macd_now < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // --- Confirm STATE: PSAR aligned with the trade direction (closed bar) ---
   const double sar1   = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar1 <= 0.0 || close1 <= 0.0)
      return false;

   const bool psar_bull = (sar1 < close1); // dots below price
   const bool psar_bear = (sar1 > close1); // dots above price

   QM_OrderType side;
   if(cross_up && psar_bull)
      side = QM_BUY;
   else if(cross_down && psar_bear)
      side = QM_SELL;
   else
      return false; // cross fired but PSAR does not confirm the direction

   // --- Size the stop from ATR; take profit at the source's min 1:2 RR ---
   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_sl_atr_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "macd_psar_long" : "macd_psar_short";
   return true;
  }

// PSAR trailing stop: chase the SL toward the current PSAR value each new closed
// bar, only when PSAR is more protective than the live SL (never loosens it).
void Strategy_ManageOpenPosition()
  {
   if(!strategy_psar_trail)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(sar1 <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type   = PositionGetInteger(POSITION_TYPE);
      const double cur_sl    = PositionGetDouble(POSITION_SL);
      const double new_sl    = QM_TM_NormalizePrice(_Symbol, sar1);

      if(pos_type == POSITION_TYPE_BUY)
        {
         // tighten upward only, and only if PSAR is below price (still bullish)
         if(new_sl > cur_sl)
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
      else if(pos_type == POSITION_TYPE_SELL)
        {
         if(cur_sl <= 0.0 || new_sl < cur_sl)
            QM_TM_MoveSL(ticket, new_sl, "psar_trail");
        }
     }
  }

// Defensive exit: PSAR flips against the open position (one state read at shift 1).
bool Strategy_ExitSignal()
  {
   if(!strategy_psar_flip_exit)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sar1   = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar1 <= 0.0 || close1 <= 0.0)
      return false;

   const bool psar_bull = (sar1 < close1);
   const bool psar_bear = (sar1 > close1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && psar_bear)
         return true;
      if(pos_type == POSITION_TYPE_SELL && psar_bull)
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
